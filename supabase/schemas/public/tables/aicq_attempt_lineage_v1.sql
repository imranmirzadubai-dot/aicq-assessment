CREATE TABLE "public"."aicq_attempt_lineage_v1" (
  "attempt_id"             uuid                     NOT NULL,
  "foundation_version"     text                     NOT NULL,
  "application_version"    text,
  "framework_version"      text                     NOT NULL,
  "assessment_version"     text,
  "bank_version"           text,
  "form_version"           text,
  "scoring_version"        text,
  "practical_version"      text,
  "interpretation_version" text,
  "development_version"    text,
  "report_version"         text,
  "captured_at"            timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_attempt_lineage_v1_pkey" PRIMARY KEY (attempt_id),
  CONSTRAINT "aicq_attempt_lineage_v1_attempt_id_fkey" FOREIGN KEY (attempt_id) REFERENCES public.aicq_attempts_v1(id) ON DELETE CASCADE
);

ALTER TABLE "public"."aicq_attempt_lineage_v1"
  ENABLE ROW LEVEL SECURITY;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_attempt_lineage_v1" TO "anon", "authenticated", "postgres", "service_role";
