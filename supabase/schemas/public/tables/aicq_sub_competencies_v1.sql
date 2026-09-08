CREATE TABLE "public"."aicq_sub_competencies_v1" (
  "id"            uuid NOT NULL DEFAULT gen_random_uuid(),
  "competency_id" uuid NOT NULL,
  "code"          text NOT NULL,
  "name"          text NOT NULL,
  "definition"    text,
  CONSTRAINT "aicq_sub_competencies_v1_competency_id_code_key" UNIQUE (competency_id, code),
  CONSTRAINT "aicq_sub_competencies_v1_competency_id_fkey" FOREIGN KEY (competency_id) REFERENCES public.aicq_competencies_v1(id),
  CONSTRAINT "aicq_sub_competencies_v1_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."aicq_sub_competencies_v1"
  ENABLE ROW LEVEL SECURITY;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_sub_competencies_v1" TO "anon", "authenticated", "postgres", "service_role";
