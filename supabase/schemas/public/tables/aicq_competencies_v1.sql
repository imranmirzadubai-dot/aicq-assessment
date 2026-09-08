CREATE TABLE "public"."aicq_competencies_v1" (
  "id"                uuid NOT NULL DEFAULT gen_random_uuid(),
  "framework_version" text NOT NULL,
  "code"              text NOT NULL,
  "name"              text NOT NULL,
  "definition"        text NOT NULL,
  "status"            text NOT NULL DEFAULT 'DRAFT'::text,
  CONSTRAINT "aicq_competencies_v1_framework_version_code_key" UNIQUE (framework_version, code),
  CONSTRAINT "aicq_competencies_v1_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."aicq_competencies_v1"
  ENABLE ROW LEVEL SECURITY;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_competencies_v1" TO "anon", "authenticated", "postgres", "service_role";
