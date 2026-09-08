CREATE TABLE "public"."aicq_submission_idempotency_v1" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "attempt_id"     uuid                     NOT NULL,
  "submission_key" text                     NOT NULL,
  "request_hash"   text                     NOT NULL,
  "created_at"     timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_submission_idempotency_unique" UNIQUE (attempt_id, submission_key),
  CONSTRAINT "aicq_submission_idempotency_v1_attempt_id_fkey" FOREIGN KEY (attempt_id) REFERENCES public.aicq_attempts_v1(id),
  CONSTRAINT "aicq_submission_idempotency_v1_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."aicq_submission_idempotency_v1"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_aicq_submission_idempotency_attempt ON public.aicq_submission_idempotency_v1 USING btree (attempt_id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
  ON TABLE "public"."aicq_submission_idempotency_v1"
  TO "anon", "authenticated", "postgres", "service_role";
