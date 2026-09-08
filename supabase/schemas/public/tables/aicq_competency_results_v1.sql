CREATE TABLE "public"."aicq_competency_results_v1" (
  "id"                 uuid    NOT NULL DEFAULT gen_random_uuid(),
  "evidence_result_id" uuid    NOT NULL,
  "competency_id"      uuid    NOT NULL,
  "score"              numeric,
  "items_answered"     integer,
  "evidence_count"     integer,
  "metadata"           jsonb   NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT "aicq_competency_results_v1_competency_id_fkey" FOREIGN KEY (competency_id) REFERENCES public.aicq_competencies_v1(id),
  CONSTRAINT "aicq_competency_results_v1_evidence_result_id_competency_id_key" UNIQUE (evidence_result_id, competency_id),
  CONSTRAINT "aicq_competency_results_v1_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_competency_results_v1_evidence_result_id_fkey" FOREIGN KEY (evidence_result_id) REFERENCES public.aicq_evidence_results_v1(id) ON DELETE CASCADE
);

ALTER TABLE "public"."aicq_competency_results_v1"
  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "aicq_competency_v1_participant_read" ON "public"."aicq_competency_results_v1"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM (public.aicq_evidence_results_v1 e
     JOIN public.aicq_attempts_v1 a ON ((a.id = e.attempt_id)))
  WHERE ((e.id = aicq_competency_results_v1.evidence_result_id) AND (a.participant_id = auth.uid())))));

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_competency_results_v1" TO "anon", "authenticated", "postgres", "service_role";
