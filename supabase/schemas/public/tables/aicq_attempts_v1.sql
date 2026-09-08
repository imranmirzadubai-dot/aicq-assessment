CREATE TABLE "public"."aicq_attempts_v1" (
  "id"                              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "legacy_assessment_id"            uuid,
  "participant_id"                  uuid,
  "organization_id"                 uuid,
  "program_id"                      uuid,
  "assessment_version_id"           uuid,
  "form_version_id"                 uuid,
  "attempt_number"                  integer                  NOT NULL DEFAULT 1,
  "status"                          text                     NOT NULL DEFAULT 'CREATED'::text,
  "participant_name_snapshot"       text,
  "participant_age_snapshot"        integer,
  "participant_gender_snapshot"     text,
  "participant_occupation_snapshot" text,
  "participant_experience_snapshot" integer,
  "started_at"                      timestamp with time zone,
  "submitted_at"                    timestamp with time zone,
  "completed_at"                    timestamp with time zone,
  "created_at"                      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_attempts_v1_assessment_version_id_fkey" FOREIGN KEY (assessment_version_id) REFERENCES public.aicq_assessment_versions_v1(id),
  CONSTRAINT "aicq_attempts_v1_legacy_assessment_id_fkey" FOREIGN KEY (legacy_assessment_id) REFERENCES public.aicq_assessments(id),
  CONSTRAINT "aicq_attempts_v1_legacy_assessment_id_key" UNIQUE (legacy_assessment_id),
  CONSTRAINT "aicq_attempts_v1_participant_id_fkey" FOREIGN KEY (participant_id) REFERENCES auth.users(id),
  CONSTRAINT "aicq_attempts_v1_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_attempts_v1_status_check"
    CHECK
    ((status = ANY (ARRAY['CREATED'::text, 'STARTED'::text, 'IN_PROGRESS'::text, 'PAUSED'::text, 'SUBMITTED'::text, 'PROCESSING'::text, 'COMPLETED'::text, 'EXPIRED'::text,
    'CANCELLED'::text, 'ERROR'::text]))),
  CONSTRAINT "aicq_attempts_v1_form_version_id_fkey" FOREIGN KEY (form_version_id) REFERENCES public.aicq_form_versions_v1(id),
  CONSTRAINT "aicq_attempts_v1_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public.aicq_organizations(id),
  CONSTRAINT "aicq_attempts_v1_program_id_fkey" FOREIGN KEY (program_id) REFERENCES public.aicq_programs(id)
);

ALTER TABLE "public"."aicq_attempts_v1"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_aicq_attempts_v1_legacy_assessment ON public.aicq_attempts_v1 USING btree (legacy_assessment_id);

CREATE INDEX idx_aicq_attempts_v1_participant_created ON public.aicq_attempts_v1 USING btree (participant_id, created_at DESC);

CREATE POLICY "aicq_attempts_v1_admin_read" ON "public"."aicq_attempts_v1"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.aicq_admins ad
  WHERE (ad.user_id = auth.uid()))));

CREATE POLICY "aicq_attempts_v1_participant_read" ON "public"."aicq_attempts_v1"
  FOR SELECT
  TO "authenticated"
  USING ((participant_id = auth.uid()));

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_attempts_v1" TO "anon", "authenticated", "postgres", "service_role";
