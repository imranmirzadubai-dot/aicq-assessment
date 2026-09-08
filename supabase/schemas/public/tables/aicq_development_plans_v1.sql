CREATE TABLE "public"."aicq_development_plans_v1" (
  "id"                  uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "attempt_id"          uuid                     NOT NULL,
  "development_version" text                     NOT NULL,
  "created_at"          timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_development_plans_v1_attempt_id_fkey" FOREIGN KEY (attempt_id) REFERENCES public.aicq_attempts_v1(id),
  CONSTRAINT "aicq_development_plans_v1_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."aicq_development_plans_v1"
  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "aicq_development_v1_participant_read" ON "public"."aicq_development_plans_v1"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.aicq_attempts_v1 a
  WHERE ((a.id = aicq_development_plans_v1.attempt_id) AND (a.participant_id = auth.uid())))));

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_development_plans_v1" TO "anon", "authenticated", "postgres", "service_role";
