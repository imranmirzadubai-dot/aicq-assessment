CREATE TABLE "public"."aicq_practical_evidence_v1" (
  "id"                      uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "practical_submission_id" uuid                     NOT NULL,
  "evidence_version"        text                     NOT NULL,
  "evidence_data"           jsonb                    NOT NULL,
  "score"                   numeric,
  "created_at"              timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_practical_evidence_v1_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_practical_evidence_v1_practical_submission_id_fkey" FOREIGN KEY (practical_submission_id) REFERENCES public.aicq_practical_submissions_v1(id) ON DELETE CASCADE
);

ALTER TABLE "public"."aicq_practical_evidence_v1"
  ENABLE ROW LEVEL SECURITY;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_practical_evidence_v1" TO "anon", "authenticated", "postgres", "service_role";
