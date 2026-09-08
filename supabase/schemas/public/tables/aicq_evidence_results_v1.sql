CREATE TABLE "public"."aicq_evidence_results_v1" (
  "id"                   uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "attempt_id"           uuid                     NOT NULL,
  "scoring_version"      text                     NOT NULL,
  "knowledge_score"      numeric,
  "practical_score"      numeric,
  "overall_score"        numeric,
  "confidence_signal"    numeric,
  "calculation_metadata" jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "created_at"           timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_evidence_results_v1_attempt_id_fkey" FOREIGN KEY (attempt_id) REFERENCES public.aicq_attempts_v1(id),
  CONSTRAINT "aicq_evidence_results_v1_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."aicq_evidence_results_v1"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_aicq_evidence_results_v1_attempt ON public.aicq_evidence_results_v1 USING btree (attempt_id, created_at DESC);

CREATE POLICY "aicq_evidence_v1_admin_read" ON "public"."aicq_evidence_results_v1"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.aicq_admins ad
  WHERE (ad.user_id = auth.uid()))));

CREATE POLICY "aicq_evidence_v1_participant_read" ON "public"."aicq_evidence_results_v1"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.aicq_attempts_v1 a
  WHERE ((a.id = aicq_evidence_results_v1.attempt_id) AND (a.participant_id = auth.uid())))));

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_evidence_results_v1" TO "anon", "authenticated", "postgres", "service_role";
