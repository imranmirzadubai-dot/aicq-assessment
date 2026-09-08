CREATE TABLE "public"."aicq_confidence_responses_v1" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "attempt_id"       uuid                     NOT NULL,
  "item_version_id"  uuid,
  "confidence_value" numeric                  NOT NULL,
  "recorded_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_confidence_responses_v1_attempt_id_fkey" FOREIGN KEY (attempt_id) REFERENCES public.aicq_attempts_v1(id) ON DELETE CASCADE,
  CONSTRAINT "aicq_confidence_responses_v1_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_confidence_responses_v1_item_version_id_fkey" FOREIGN KEY (item_version_id) REFERENCES public.aicq_item_versions_v1(id)
);

ALTER TABLE "public"."aicq_confidence_responses_v1"
  ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER trg_aicq_v1_confidence_immutable
  BEFORE DELETE OR UPDATE ON public.aicq_confidence_responses_v1
  FOR EACH ROW
  EXECUTE FUNCTION public.aicq_reject_v1_submitted_attempt_mutation();

CREATE POLICY "aicq_confidence_v1_participant_insert" ON "public"."aicq_confidence_responses_v1"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.aicq_attempts_v1 a
  WHERE ((a.id = aicq_confidence_responses_v1.attempt_id) AND (a.participant_id = auth.uid()) AND (a.status = ANY (ARRAY['STARTED'::text, 'IN_PROGRESS'::text, 'PAUSED'::text]))))));

CREATE POLICY "aicq_confidence_v1_participant_read" ON "public"."aicq_confidence_responses_v1"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.aicq_attempts_v1 a
  WHERE ((a.id = aicq_confidence_responses_v1.attempt_id) AND (a.participant_id = auth.uid())))));

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
  ON TABLE "public"."aicq_confidence_responses_v1"
  TO "anon", "authenticated", "postgres", "service_role";
