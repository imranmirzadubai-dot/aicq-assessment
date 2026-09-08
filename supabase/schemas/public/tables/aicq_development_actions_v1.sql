CREATE TABLE "public"."aicq_development_actions_v1" (
  "id"                    uuid    NOT NULL DEFAULT gen_random_uuid(),
  "development_plan_id"   uuid    NOT NULL,
  "competency_id"         uuid,
  "priority"              integer NOT NULL,
  "learning_objective"    text    NOT NULL,
  "sequence"              jsonb   NOT NULL,
  "practice_activity"     text,
  "application_activity"  text,
  "control_activity"      text,
  "reassessment_activity" text,
  CONSTRAINT "aicq_development_actions_v1_competency_id_fkey" FOREIGN KEY (competency_id) REFERENCES public.aicq_competencies_v1(id),
  CONSTRAINT "aicq_development_actions_v1_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_development_actions_v1_development_plan_id_fkey" FOREIGN KEY (development_plan_id) REFERENCES public.aicq_development_plans_v1(id) ON DELETE CASCADE
);

ALTER TABLE "public"."aicq_development_actions_v1"
  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "aicq_development_actions_v1_participant_read" ON "public"."aicq_development_actions_v1"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM (public.aicq_development_plans_v1 d
     JOIN public.aicq_attempts_v1 a ON ((a.id = d.attempt_id)))
  WHERE ((d.id = aicq_development_actions_v1.development_plan_id) AND (a.participant_id = auth.uid())))));

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_development_actions_v1" TO "anon", "authenticated", "postgres", "service_role";
