CREATE TABLE "public"."aicq_participant_sessions_v1" (
  "id"                      uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "attempt_id"              uuid                     NOT NULL,
  "token_hash"              text                     NOT NULL,
  "issued_at"               timestamp with time zone NOT NULL DEFAULT now(),
  "expires_at"              timestamp with time zone NOT NULL,
  "last_seen_at"            timestamp with time zone,
  "revoked_at"              timestamp with time zone,
  "created_ip_hash"         text,
  "created_user_agent_hash" text,
  "metadata"                jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT "aicq_participant_sessions_v1_attempt_id_fkey" FOREIGN KEY (attempt_id) REFERENCES public.aicq_attempts_v1(id),
  CONSTRAINT "aicq_participant_sessions_v1_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_participant_sessions_v1_token_hash_key" UNIQUE (token_hash),
  CONSTRAINT "participant_session_expiry_ck" CHECK ((expires_at > issued_at))
);

ALTER TABLE "public"."aicq_participant_sessions_v1"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_aicq_participant_sessions_active ON public.aicq_participant_sessions_v1 USING btree (token_hash)
  WHERE (revoked_at IS NULL);

CREATE INDEX idx_aicq_participant_sessions_attempt ON public.aicq_participant_sessions_v1 USING btree (attempt_id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
  ON TABLE "public"."aicq_participant_sessions_v1"
  TO "anon", "authenticated", "postgres", "service_role";
