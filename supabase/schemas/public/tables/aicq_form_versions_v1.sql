CREATE TABLE "public"."aicq_form_versions_v1" (
  "id"                    uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "legacy_form_id"        uuid,
  "form_code"             text                     NOT NULL,
  "version"               text                     NOT NULL,
  "assessment_version_id" uuid,
  "adaptive"              boolean                  NOT NULL DEFAULT false,
  "status"                text                     NOT NULL DEFAULT 'DRAFT'::text,
  "published_at"          timestamp with time zone,
  CONSTRAINT "aicq_form_versions_v1_assessment_version_id_fkey" FOREIGN KEY (assessment_version_id) REFERENCES public.aicq_assessment_versions_v1(id),
  CONSTRAINT "aicq_form_versions_v1_form_code_version_key" UNIQUE (form_code, VERSION),
  CONSTRAINT "aicq_form_versions_v1_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_form_versions_v1_status_check" CHECK ((status = ANY (ARRAY['DRAFT'::text, 'REVIEW'::text, 'APPROVED'::text, 'PUBLISHED'::text, 'ARCHIVED'::text]))),
  CONSTRAINT "aicq_form_versions_v1_legacy_form_id_fkey" FOREIGN KEY (legacy_form_id) REFERENCES public.aicq_forms(id)
);

ALTER TABLE "public"."aicq_form_versions_v1"
  ENABLE ROW LEVEL SECURITY;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_form_versions_v1" TO "anon", "authenticated", "postgres", "service_role";
