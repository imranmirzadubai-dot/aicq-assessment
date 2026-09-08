CREATE OR REPLACE FUNCTION public.aicq_submit_attempt_v1 (
  p_attempt_id     uuid,
  p_submission_key text,
  p_request_hash   text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    a RECORD;
    existing RECORD;
    v_id UUID;
BEGIN

    IF p_submission_key IS NULL
       OR length(p_submission_key) < 16 THEN
        RAISE EXCEPTION 'IDEMPOTENCY_KEY_INVALID';
    END IF;

    IF p_request_hash IS NULL
       OR length(p_request_hash) <> 64 THEN
        RAISE EXCEPTION 'REQUEST_HASH_INVALID';
    END IF;


    -- Lock the attempt so concurrent submissions cannot
    -- modify the same attempt simultaneously.

    SELECT *
    INTO a
    FROM public.aicq_attempts_v1
    WHERE id = p_attempt_id
    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'ATTEMPT_NOT_FOUND';
    END IF;


    -- Check whether this submission key was already used.

    SELECT *
    INTO existing
    FROM public.aicq_submission_idempotency_v1
    WHERE attempt_id = p_attempt_id
      AND submission_key = p_submission_key
    FOR UPDATE;


    IF FOUND THEN

        IF existing.request_hash <> p_request_hash THEN
            RAISE EXCEPTION
                'IDEMPOTENCY_KEY_REUSE_MISMATCH';
        END IF;

        RETURN jsonb_build_object(
            'accepted', true,
            'duplicate', true,
            'attempt_id', p_attempt_id,
            'submission_id', existing.id
        );

    END IF;


    -- Only active attempts may be submitted.

    IF a.status NOT IN (
        'STARTED',
        'IN_PROGRESS',
        'PAUSED'
    ) THEN
        RAISE EXCEPTION 'ATTEMPT_NOT_SUBMITTABLE';
    END IF;


    -- Record idempotency key before final state transition.

    INSERT INTO public.aicq_submission_idempotency_v1 (
        attempt_id,
        submission_key,
        request_hash
    )
    VALUES (
        p_attempt_id,
        p_submission_key,
        p_request_hash
    )
    RETURNING id INTO v_id;


    -- Permanently move the attempt to SUBMITTED.

    UPDATE public.aicq_attempts_v1
    SET
        status = 'SUBMITTED',
        submitted_at = COALESCE(
            submitted_at,
            now()
        )
    WHERE id = p_attempt_id;


    RETURN jsonb_build_object(
        'accepted', true,
        'duplicate', false,
        'attempt_id', p_attempt_id,
        'submission_id', v_id
    );

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_submit_attempt_v1"(uuid, text, text) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_submit_attempt_v1"(uuid, text, text) FROM PUBLIC;
