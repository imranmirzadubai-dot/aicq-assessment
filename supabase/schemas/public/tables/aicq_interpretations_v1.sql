CREATE TABLE "public"."aicq_interpretations_v1" (
  "id"                     uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "attempt_id"             uuid                     NOT NULL,
  "evidence_result_id"     uuid                     NOT NULL,
  "interpretation_version" text                     NOT NULL,
  "strengths"              jsonb                    NOT NULL DEFAULT '[]'::jsonb,
  "opportunities"          jsonb                    NOT NULL DEFAULT '[]'::jsonb,
  "priority_patterns"      jsonb                    NOT NULL DEFAULT '[]'::jsonb,
  "evidence_notes"         jsonb                    NOT NULL DEFAULT '[]'::jsonb,
  "created_at"             timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_interpretations_v1_attempt_id_fkey" FOREIGN KEY (attempt_id) REFERENCES public.aicq_attempts_v1(id),
  CONSTRAINT "aicq_interpretations_v1_evidence_result_id_fkey" FOREIGN KEY (evidence_result_id) REFERENCES public.aicq_evidence_results_v1(id),
  CONSTRAINT "aicq_interpretations_v1_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."aicq_interpretations_v1"
  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "aicq_interpretation_v1_participant_read" ON "public"."aicq_interpretations_v1"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.aicq_attempts_v1 a
  WHERE ((a.id = aicq_interpretations_v1.attempt_id) AND (a.participant_id = auth.uid())))));

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_interpretations_v1" TO "anon", "authenticated", "postgres", "service_role";
