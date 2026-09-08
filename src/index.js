const BASE_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "x-content-type-options": "nosniff",
  "referrer-policy": "no-referrer",
  "content-security-policy": "default-src 'none'; frame-ancestors 'none'"
};

const rid = () => crypto.randomUUID();

function headers(env) {
  return {
    ...BASE_HEADERS,
    "access-control-allow-origin": env.ALLOWED_ORIGIN || "",
    "access-control-allow-credentials": "true",
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "access-control-allow-headers": "Authorization,Content-Type,Idempotency-Key",
    "vary": "Origin"
  };
}

function out(status, payload, requestId, env) {
  return new Response(
    JSON.stringify({
      ok: status < 400,
      request_id: requestId,
      ...payload
    }),
    {
      status,
      headers: {
        ...headers(env),
        "x-request-id": requestId
      }
    }
  );
}

class E extends Error {
  constructor(status, code, message, details = null) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

function cleanBaseUrl(value) {
  return String(value || "").trim().replace(/\/+$/, "");
}

function b64(bytes) {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function makeToken() {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return b64(bytes);
}

async function sha256(value) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(String(value ?? ""))
  );

  return [...new Uint8Array(digest)]
    .map(x => x.toString(16).padStart(2, "0"))
    .join("");
}

async function readJson(response) {
  const text = await response.text();

  if (!text) return null;

  try {
    return JSON.parse(text);
  } catch {
    return { raw_response: text };
  }
}

/*
 * Server-side Supabase REST helper.
 *
 * Important:
 * - Uses the service-role key only inside the Worker.
 * - Does not expose that key to the participant.
 * - Sends RPC arguments as a single JSON object.
 * - Preserves the upstream response body for diagnostics.
 */
async function db(env, path, init = {}) {
  const base = cleanBaseUrl(env.SUPABASE_URL);

  if (!base) {
    throw new E(500, "SERVER_CONFIGURATION_ERROR", "SUPABASE_URL is not configured.");
  }

  if (!env.SUPABASE_SERVICE_ROLE_KEY) {
    throw new E(500, "SERVER_CONFIGURATION_ERROR", "SUPABASE_SERVICE_ROLE_KEY is not configured.");
  }

  const requestHeaders = {
    "apikey": env.SUPABASE_SERVICE_ROLE_KEY,
    "authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
    "content-type": "application/json",
    "accept": "application/json",
    ...(init.headers || {})
  };

  const response = await fetch(`${base}${path}`, {
    ...init,
    headers: requestHeaders
  });

  const payload = await readJson(response);

  if (!response.ok) {
    throw new E(
      response.status >= 400 && response.status < 500 ? 400 : 502,
      "SUPABASE_HTTP_ERROR",
      `Supabase returned HTTP ${response.status}.`,
      {
        supabase_http_status: response.status,
        supabase_code: payload?.code || payload?.error_code || null,
        supabase_message:
          payload?.message ||
          payload?.error_description ||
          payload?.error ||
          null,
        supabase_details: payload?.details || null,
        supabase_hint: payload?.hint || null,
        supabase_raw_response: payload?.raw_response || null
      }
    );
  }

  return payload;
}

async function rpc(env, functionName, args) {
  return db(env, `/rest/v1/rpc/${encodeURIComponent(functionName)}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "accept": "application/json",
      "prefer": "return=representation"
    },
    body: JSON.stringify(args)
  });
}

async function parseBody(request) {
  try {
    return await request.json();
  } catch {
    throw new E(400, "INVALID_JSON", "Request body must be valid JSON.");
  }
}

function validateAttemptBody(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw new E(400, "INVALID_BODY", "Request body must be a JSON object.");
  }

  if (
    body.participant_age != null &&
    (!Number.isInteger(body.participant_age) ||
      body.participant_age < 0 ||
      body.participant_age > 130)
  ) {
    throw new E(
      400,
      "INVALID_PARTICIPANT_AGE",
      "participant_age must be an integer between 0 and 130."
    );
  }

  if (
    body.participant_experience != null &&
    (!Number.isInteger(body.participant_experience) ||
      body.participant_experience < 0 ||
      body.participant_experience > 100)
  ) {
    throw new E(
      400,
      "INVALID_PARTICIPANT_EXPERIENCE",
      "participant_experience must be an integer between 0 and 100."
    );
  }

  const forbidden = [
    "correct",
    "is_correct",
    "answer_key",
    "answer_key_option_id",
    "source_key",
    "score",
    "knowledge_score",
    "practical_score",
    "overall_score",
    "competency_scores"
  ];

  for (const key of forbidden) {
    if (Object.prototype.hasOwnProperty.call(body, key)) {
      throw new E(
        400,
        "FORBIDDEN_CLIENT_FIELD",
        `Client field '${key}' is not accepted.`
      );
    }
  }
}

async function auth(request, env, attemptId) {
  const authorization = request.headers.get("authorization") || "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);

  if (!match) {
    throw new E(
      401,
      "PARTICIPANT_SESSION_REQUIRED",
      "Participant session required."
    );
  }

  const token = match[1].trim();

  if (!token || token.length < 20) {
    throw new E(
      401,
      "PARTICIPANT_SESSION_INVALID",
      "Invalid participant session."
    );
  }

  const sessionRows = await rpc(
    env,
    "aicq_get_participant_session_v1",
    {
      p_token_hash: await sha256(token)
    }
  );

  const session = Array.isArray(sessionRows)
    ? sessionRows[0]
    : sessionRows;

  if (!session) {
    throw new E(
      401,
      "PARTICIPANT_SESSION_INVALID",
      "Invalid participant session."
    );
  }

  if (session.revoked_at) {
    throw new E(
      401,
      "PARTICIPANT_SESSION_REVOKED",
      "Participant session revoked."
    );
  }

  if (
    session.expires_at &&
    new Date(session.expires_at).getTime() <= Date.now()
  ) {
    throw new E(
      401,
      "PARTICIPANT_SESSION_EXPIRED",
      "Participant session expired."
    );
  }

  if (String(session.attempt_id) !== String(attemptId)) {
    throw new E(
      403,
      "PARTICIPANT_ATTEMPT_MISMATCH",
      "Session is bound to another attempt."
    );
  }

  return session;
}

async function createParticipantSession(request, env, attemptId) {
  const sessionToken = makeToken();
  const expiresAt = new Date(Date.now() + 3 * 60 * 60 * 1000).toISOString();

  await rpc(
    env,
    "aicq_create_participant_session_v1",
    {
      p_attempt_id: attemptId,
      p_token_hash: await sha256(sessionToken),
      p_expires_at: expiresAt,
      p_created_ip_hash: await sha256(
        request.headers.get("CF-Connecting-IP") || ""
      ),
      p_created_user_agent_hash: await sha256(
        request.headers.get("User-Agent") || ""
      )
    }
  );

  return {
    attempt_id: attemptId,
    session_token: sessionToken,
    expires_at: expiresAt
  };
}

async function protectedRpc(request, env, attemptId, functionName, args = {}) {
  await auth(request, env, attemptId);

  return rpc(env, functionName, {
    p_attempt_id: attemptId,
    ...args
  });
}

function mapDatabaseError(error) {
  if (!(error instanceof E)) return error;

  const details = error.details || {};
  const upstreamMessage =
    details.supabase_message ||
    details.supabase_raw_response ||
    error.message;

  const normalized = String(upstreamMessage || "").toUpperCase();

  const statusMap = {
    FORM_NOT_PUBLISHED: 409,
    FORM_CONTAINS_UNPUBLISHED_ITEMS: 409,
    FORM_ITEM_COUNT_INVALID: 409,
    ASSESSMENT_NOT_FOUND: 404,
    ASSESSMENT_VERSION_NOT_FOUND: 404,
    ASSESSMENT_VERSION_NOT_PUBLISHED: 409,
    FORM_VERSION_NOT_FOUND: 404,
    ATTEMPT_NOT_FOUND: 404,
    ATTEMPT_NOT_STARTABLE: 409,
    ATTEMPT_NOT_ACTIVE: 409,
    ATTEMPT_NOT_SUBMITTED: 409,
    RESPONSE_ALREADY_RECORDED: 409,
    CONFIDENCE_ALREADY_RECORDED: 409,
    PRACTICAL_ALREADY_SUBMITTED: 409,
    RESULT_NOT_AVAILABLE: 404,
    ITEM_VERSION_NOT_PUBLISHED: 409,
    TASK_VERSION_NOT_PUBLISHED: 409,
    PARTICIPANT_SESSION_INVALID: 401,
    PARTICIPANT_SESSION_REQUIRED: 401,
    PARTICIPANT_SESSION_EXPIRED: 401,
    PARTICIPANT_SESSION_REVOKED: 401,
    ATTEMPT_NOT_ELIGIBLE: 409
  };

  for (const [code, status] of Object.entries(statusMap)) {
    if (normalized.includes(code)) {
      return new E(status, code, code, error.details);
    }
  }

  return error;
}

async function handleCreateAttempt(request, env, requestId) {
  const body = await parseBody(request);
  validateAttemptBody(body);

  /*
   * This is the confirmed live Supabase signature:
   *
   * aicq_api_create_attempt_v1(
   *   text,text,text,uuid,uuid,uuid,text,integer,text,text,integer
   * )
   *
   * Keep every argument name exact.
   */
  const args = {
    p_assessment_code:
      body.assessment_code != null ? String(body.assessment_code) : "AICQ-P1",

    p_form_code:
      body.form_code != null ? String(body.form_code) : "AICQ-P1-F01",

    p_form_version:
      body.form_version != null ? String(body.form_version) : "1.0",

    p_participant_id:
      body.participant_id != null ? body.participant_id : null,

    p_organization_id:
      body.organization_id != null ? body.organization_id : null,

    p_program_id:
      body.program_id != null ? body.program_id : null,

    p_participant_name:
      body.participant_name != null ? String(body.participant_name) : null,

    p_participant_age:
      body.participant_age != null ? body.participant_age : null,

    p_participant_gender:
      body.participant_gender != null ? String(body.participant_gender) : null,

    p_participant_occupation:
      body.participant_occupation != null
        ? String(body.participant_occupation)
        : null,

    p_participant_experience:
      body.participant_experience != null
        ? body.participant_experience
        : null
  };

  const created = await rpc(
    env,
    "aicq_api_create_attempt_v1",
    args
  );

  /*
   * The dedicated API wrapper returns a single JSONB object.
   * PostgREST may still wrap scalar JSONB results in a JSON value,
   * so accept both the object and a one-element array defensively.
   */
  const rowCandidate = Array.isArray(created)
    ? created[0]
    : created;

  const row =
    typeof rowCandidate === "string"
      ? JSON.parse(rowCandidate)
      : rowCandidate;

  if (!row?.attempt_id) {
    throw new E(
      502,
      "ATTEMPT_CREATION_FAILED",
      "Supabase did not return an attempt.",
      {
        returned_type: typeof rowCandidate,
        returned_value: rowCandidate ?? null
      }
    );
  }

  const session = await createParticipantSession(
    request,
    env,
    row.attempt_id
  );

  return out(
    201,
    {
      attempt: row,
      session
    },
    requestId,
    env
  );
}

export default {
  async fetch(request, env) {
    const requestId = rid();

    try {
      if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
        throw new E(
          500,
          "SERVER_CONFIGURATION_ERROR",
          "API is not configured."
        );
      }

      const url = new URL(request.url);
      const path = url.pathname.split("/").filter(Boolean);

      if (request.method === "OPTIONS") {
        return new Response(null, {
          status: 204,
          headers: headers(env)
        });
      }

      if (url.pathname === "/health") {
        return out(
          200,
          {
            service: "aicq-foundation",
            version: "1.9",
            status: "ok"
          },
          requestId,
          env
        );
      }

      if (path[0] !== "v1") {
        throw new E(404, "NOT_FOUND", "Route not found.");
      }

      /*
       * POST /v1/attempts
       */
      if (
        path[1] === "attempts" &&
        path.length === 2 &&
        request.method === "POST"
      ) {
        return await handleCreateAttempt(request, env, requestId);
      }

      /*
       * Everything below this point is attempt-scoped and requires
       * the opaque participant session token.
       */
      if (path[1] === "attempts" && path[2]) {
        const attemptId = path[2];

        /*
         * GET /v1/attempts/:id
         */
        if (
          path.length === 3 &&
          request.method === "GET"
        ) {
          const attempt = await protectedRpc(
            request,
            env,
            attemptId,
            "aicq_get_attempt_v1"
          );

          return out(
            200,
            { attempt },
            requestId,
            env
          );
        }

        /*
         * POST /v1/attempts/:id/start
         */
        if (
          path[3] === "start" &&
          path.length === 4 &&
          request.method === "POST"
        ) {
          const result = await protectedRpc(
            request,
            env,
            attemptId,
            "aicq_start_attempt_v1"
          );

          return out(
            200,
            { result },
            requestId,
            env
          );
        }

        /*
         * GET /v1/attempts/:id/items/:position
         */
        if (
          path[3] === "items" &&
          path[4] &&
          path.length === 5 &&
          request.method === "GET"
        ) {
          const position = Number(path[4]);

          if (!Number.isInteger(position) || position < 1 || position > 32) {
            throw new E(
              400,
              "INVALID_ITEM_POSITION",
              "Item position must be an integer from 1 to 32."
            );
          }

          const item = await protectedRpc(
            request,
            env,
            attemptId,
            "aicq_get_attempt_item_v1",
            {
              p_position: position
            }
          );

          return out(
            200,
            { item },
            requestId,
            env
          );
        }

        /*
         * POST /v1/attempts/:id/responses
         */
        if (
          path[3] === "responses" &&
          path.length === 4 &&
          request.method === "POST"
        ) {
          const body = await parseBody(request);

          const forbidden = [
            "correct",
            "is_correct",
            "answer_key",
            "answer_key_option_id",
            "source_key",
            "score"
          ];

          for (const key of forbidden) {
            if (Object.prototype.hasOwnProperty.call(body, key)) {
              throw new E(
                400,
                "FORBIDDEN_CLIENT_FIELD",
                `Client field '${key}' is not accepted.`
              );
            }
          }

          if (
            body.item_version_id == null ||
            typeof body.item_version_id !== "string"
          ) {
            throw new E(
              400,
              "ITEM_VERSION_ID_REQUIRED",
              "item_version_id is required."
            );
          }

          const result = await protectedRpc(
            request,
            env,
            attemptId,
            "aicq_record_response_v1",
            {
              p_item_version_id: body.item_version_id,
              p_selected_option_id:
                body.selected_option_id != null
                  ? body.selected_option_id
                  : null,
              p_skipped: body.skipped === true,
              p_response_time_ms:
                Number.isInteger(body.response_time_ms)
                  ? body.response_time_ms
                  : null,
              p_presentation_sequence:
                body.presentation_sequence != null
                  ? body.presentation_sequence
                  : null,
              p_option_order:
                Array.isArray(body.option_order)
                  ? body.option_order
                  : null
            }
          );

          return out(
            200,
            { result },
            requestId,
            env
          );
        }

        /*
         * POST /v1/attempts/:id/confidence
         */
        if (
          path[3] === "confidence" &&
          path.length === 4 &&
          request.method === "POST"
        ) {
          const body = await parseBody(request);

          if (
            body.confidence == null ||
            !Number.isInteger(body.confidence) ||
            body.confidence < 1 ||
            body.confidence > 5
          ) {
            throw new E(
              400,
              "INVALID_CONFIDENCE",
              "confidence must be an integer from 1 to 5."
            );
          }

          const result = await protectedRpc(
            request,
            env,
            attemptId,
            "aicq_record_confidence_v1",
            {
              p_confidence: body.confidence,
              p_item_version_id:
                body.item_version_id != null
                  ? body.item_version_id
                  : null
            }
          );

          return out(
            200,
            { result },
            requestId,
            env
          );
        }

        /*
         * POST /v1/attempts/:id/practical
         */
        if (
          path[3] === "practical" &&
          path.length === 4 &&
          request.method === "POST"
        ) {
          const body = await parseBody(request);

          if (!Array.isArray(body.ordered_steps)) {
            throw new E(
              400,
              "INVALID_ORDERED_STEPS",
              "ordered_steps must be an array."
            );
          }

          const result = await protectedRpc(
            request,
            env,
            attemptId,
            "aicq_capture_practical_submission_v1",
            {
              p_task_version_id:
                body.task_version_id != null
                  ? body.task_version_id
                  : null,
              p_ordered_steps: body.ordered_steps,
              p_submission_data:
                body.submission_data != null
                  ? body.submission_data
                  : {}
            }
          );

          return out(
            200,
            { result },
            requestId,
            env
          );
        }

        /*
         * POST /v1/attempts/:id/submit
         */
        if (
          path[3] === "submit" &&
          path.length === 4 &&
          request.method === "POST"
        ) {
          const idempotencyKey =
            request.headers.get("Idempotency-Key") || "";

          if (!idempotencyKey || idempotencyKey.length < 8) {
            throw new E(
              400,
              "IDEMPOTENCY_KEY_REQUIRED",
              "Idempotency-Key header is required."
            );
          }

          await auth(request, env, attemptId);

          const requestBody = await request.text();
          const requestHash = await sha256(requestBody);

          const result = await rpc(
            env,
            "aicq_submit_attempt_v1",
            {
              p_attempt_id: attemptId,
              p_submission_key: idempotencyKey,
              p_request_hash: requestHash
            }
          );

          return out(
            200,
            { result },
            requestId,
            env
          );
        }

        /*
         * GET /v1/attempts/:id/result
         */
        if (
          path[3] === "result" &&
          path.length === 4 &&
          request.method === "GET"
        ) {
          const result = await protectedRpc(
            request,
            env,
            attemptId,
            "aicq_get_attempt_result_v1"
          );

          return out(
            200,
            { result },
            requestId,
            env
          );
        }
      }

      throw new E(404, "NOT_FOUND", "Route not found.");
    } catch (rawError) {
      const error = mapDatabaseError(rawError);

      const status =
        Number.isInteger(error?.status)
          ? error.status
          : 500;

      return out(
        status,
        {
          error: {
            code: error?.code || "INTERNAL_ERROR",
            message:
              error?.message ||
              "Unexpected server error.",
            ...(error?.details
              ? { details: error.details }
              : {})
          }
        },
        requestId,
        env
      );
    }
  }
};
