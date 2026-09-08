CREATE TABLE "public"."aicq_assessments" (
  "id"                           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "reference_code"               text                     NOT NULL,
  "integrity_sha256"             text,
  "aicq_version"                 text                     NOT NULL,
  "question_bank_version"        text                     NOT NULL,
  "scoring_model_version"        text                     NOT NULL,
  "difficulty_framework_version" text,
  "started_at"                   timestamp with time zone,
  "completed_at"                 timestamp with time zone NOT NULL DEFAULT now(),
  "participant_name"             text                     NOT NULL,
  "participant_age"              integer,
  "participant_gender"           text,
  "participant_occupation"       text,
  "participant_experience"       integer,
  "confidence"                   integer,
  "assessment_target"            integer,
  "knowledge_score"              integer,
  "practical_score"              integer,
  "overall_score"                integer,
  "competency_scores"            jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "evidence"                     jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "full_record"                  jsonb                    NOT NULL,
  "created_at"                   timestamp with time zone NOT NULL DEFAULT now(),
  "is_test"                      boolean                  NOT NULL DEFAULT false,
  CONSTRAINT "aicq_assessments_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_assessments_reference_code_key" UNIQUE (reference_code)
);

ALTER TABLE "public"."aicq_assessments"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX aicq_assessments_created_at_idx ON public.aicq_assessments USING btree (created_at DESC);

CREATE INDEX aicq_assessments_is_test_idx ON public.aicq_assessments USING btree (is_test);

CREATE INDEX aicq_assessments_overall_idx ON public.aicq_assessments USING btree (overall_score);

CREATE POLICY "AICQ admins can read assessments" ON "public"."aicq_assessments"
  FOR SELECT
  TO "authenticated"
  USING (( SELECT private.is_aicq_admin() AS is_aicq_admin));

CREATE POLICY "aicq admins read assessments" ON "public"."aicq_assessments"
  FOR SELECT
  TO "authenticated"
  USING (public.is_aicq_admin());

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_assessments" TO "postgres", "service_role";

REVOKE ALL ON TABLE "public"."aicq_assessments" FROM "authenticated";

GRANT SELECT ON TABLE "public"."aicq_assessments" TO "authenticated";
