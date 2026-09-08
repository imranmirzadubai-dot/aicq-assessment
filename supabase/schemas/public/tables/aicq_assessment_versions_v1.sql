CREATE TABLE "public"."aicq_assessment_versions_v1" (
  "id"                       uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "assessment_definition_id" uuid                     NOT NULL,
  "version"                  text                     NOT NULL,
  "framework_version"        text,
  "form_version"             text,
  "status"                   text                     NOT NULL DEFAULT 'DRAFT'::text,
  "published_at"             timestamp with time zone,
  "created_at"               timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_assessment_versions_v1_assessment_definition_id_fkey" FOREIGN KEY (assessment_definition_id) REFERENCES public.aicq_assessment_definitions(id),
  CONSTRAINT "aicq_assessment_versions_v1_assessment_definition_id_versio_key" UNIQUE (assessment_definition_id, VERSION),
  CONSTRAINT "aicq_assessment_versions_v1_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_assessment_versions_v1_status_check" CHECK ((status = ANY (ARRAY['DRAFT'::text, 'REVIEW'::text, 'APPROVED'::text, 'PUBLISHED'::text, 'ARCHIVED'::text])))
);

ALTER TABLE "public"."aicq_assessment_versions_v1"
  ENABLE ROW LEVEL SECURITY;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_assessment_versions_v1" TO "anon", "authenticated", "postgres", "service_role";
