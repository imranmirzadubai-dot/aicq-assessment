CREATE TABLE "public"."aicq_assessment_definitions" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "assessment_code" text                     NOT NULL,
  "name"            text                     NOT NULL,
  "description"     text,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_assessment_definitions_assessment_code_key" UNIQUE (assessment_code),
  CONSTRAINT "aicq_assessment_definitions_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."aicq_assessment_definitions"
  ENABLE ROW LEVEL SECURITY;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_assessment_definitions" TO "anon", "authenticated", "postgres", "service_role";
