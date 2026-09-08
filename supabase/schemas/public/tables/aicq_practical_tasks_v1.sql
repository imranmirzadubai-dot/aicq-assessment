CREATE TABLE "public"."aicq_practical_tasks_v1" (
  "id"        uuid NOT NULL DEFAULT gen_random_uuid(),
  "task_code" text NOT NULL,
  "name"      text NOT NULL,
  CONSTRAINT "aicq_practical_tasks_v1_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_practical_tasks_v1_task_code_key" UNIQUE (task_code)
);

ALTER TABLE "public"."aicq_practical_tasks_v1"
  ENABLE ROW LEVEL SECURITY;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_practical_tasks_v1" TO "anon", "authenticated", "postgres", "service_role";
