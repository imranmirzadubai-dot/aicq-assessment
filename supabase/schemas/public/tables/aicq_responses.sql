CREATE TABLE "public"."aicq_responses" (
  "id"               bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  "assessment_id"    uuid                     NOT NULL,
  "position"         integer                  NOT NULL,
  "question_id"      text                     NOT NULL,
  "competency"       text                     NOT NULL,
  "sub_competency"   text,
  "difficulty"       text,
  "answer_index"     integer,
  "skipped"          boolean                  NOT NULL DEFAULT false,
  "correct"          boolean,
  "response_time_ms" integer,
  "option_order"     jsonb,
  "selected_option"  text,
  "created_at"       timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_responses_assessment_id_fkey" FOREIGN KEY (assessment_id) REFERENCES public.aicq_assessments(id) ON DELETE CASCADE,
  CONSTRAINT "aicq_responses_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."aicq_responses"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX aicq_responses_assessment_idx ON public.aicq_responses USING btree (assessment_id);

CREATE INDEX aicq_responses_question_idx ON public.aicq_responses USING btree (question_id);

CREATE POLICY "AICQ admins can read responses" ON "public"."aicq_responses"
  FOR SELECT
  TO "authenticated"
  USING (( SELECT private.is_aicq_admin() AS is_aicq_admin));

CREATE POLICY "aicq admins read responses" ON "public"."aicq_responses"
  FOR SELECT
  TO "authenticated"
  USING (public.is_aicq_admin());

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_responses" TO "postgres", "service_role";

REVOKE ALL ON TABLE "public"."aicq_responses" FROM "authenticated";

GRANT SELECT ON TABLE "public"."aicq_responses" TO "authenticated";
