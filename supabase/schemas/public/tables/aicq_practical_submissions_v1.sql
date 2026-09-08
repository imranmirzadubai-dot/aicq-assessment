CREATE TABLE "public"."aicq_practical_submissions_v1" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "attempt_id"      uuid                     NOT NULL,
  "task_version_id" uuid                     NOT NULL,
  "ordered_steps"   jsonb                    NOT NULL,
  "submission_data" jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "submitted_at"    timestamp with time zone,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_practical_submissions_v1_attempt_id_fkey" FOREIGN KEY (attempt_id) REFERENCES public.aicq_attempts_v1(id) ON DELETE CASCADE,
  CONSTRAINT "aicq_practical_submissions_v1_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_practical_submissions_v1_task_version_id_fkey" FOREIGN KEY (task_version_id) REFERENCES public.aicq_practical_task_versions_v1(id)
);

ALTER TABLE "public"."aicq_practical_submissions_v1"
  ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER trg_aicq_v1_practical_immutable
  BEFORE DELETE OR UPDATE ON public.aicq_practical_submissions_v1
  FOR EACH ROW
  EXECUTE FUNCTION public.aicq_reject_v1_submitted_attempt_mutation();

CREATE POLICY "aicq_practical_v1_participant_insert" ON "public"."aicq_practical_submissions_v1"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.aicq_attempts_v1 a
  WHERE
    ((a.id = aicq_practical_submissions_v1.attempt_id) AND (a.participant_id = auth.uid()) AND (a.status = ANY (ARRAY['STARTED'::text, 'IN_PROGRESS'::text, 'PAUSED'::text]))))));

CREATE POLICY "aicq_practical_v1_participant_read" ON "public"."aicq_practical_submissions_v1"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.aicq_attempts_v1 a
  WHERE ((a.id = aicq_practical_submissions_v1.attempt_id) AND (a.participant_id = auth.uid())))));

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
  ON TABLE "public"."aicq_practical_submissions_v1"
  TO "anon", "authenticated", "postgres", "service_role";
