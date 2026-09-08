CREATE TABLE "public"."aicq_consents_v1" (
  "id"                   uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "participant_id"       uuid,
  "legacy_assessment_id" uuid,
  "consent_type"         text                     NOT NULL,
  "consent_version"      text                     NOT NULL,
  "accepted"             boolean                  NOT NULL,
  "accepted_at"          timestamp with time zone,
  "withdrawn_at"         timestamp with time zone,
  CONSTRAINT "aicq_consents_v1_legacy_assessment_id_fkey" FOREIGN KEY (legacy_assessment_id) REFERENCES public.aicq_assessments(id),
  CONSTRAINT "aicq_consents_v1_participant_id_fkey" FOREIGN KEY (participant_id) REFERENCES auth.users(id),
  CONSTRAINT "aicq_consents_v1_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."aicq_consents_v1"
  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "aicq_consent_v1_participant_insert" ON "public"."aicq_consents_v1"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((participant_id = auth.uid()));

CREATE POLICY "aicq_consent_v1_participant_read" ON "public"."aicq_consents_v1"
  FOR SELECT
  TO "authenticated"
  USING ((participant_id = auth.uid()));

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_consents_v1" TO "anon", "authenticated", "postgres", "service_role";
