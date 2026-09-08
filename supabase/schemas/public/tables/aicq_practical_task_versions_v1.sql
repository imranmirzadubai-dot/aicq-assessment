CREATE TABLE "public"."aicq_practical_task_versions_v1" (
  "id"              uuid  NOT NULL DEFAULT gen_random_uuid(),
  "task_id"         uuid  NOT NULL,
  "version"         text  NOT NULL,
  "task_definition" jsonb NOT NULL,
  "status"          text  NOT NULL DEFAULT 'DRAFT'::text,
  CONSTRAINT "aicq_practical_task_versions_v1_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_practical_task_versions_v1_task_id_version_key" UNIQUE (task_id, VERSION),
  CONSTRAINT "aicq_practical_task_versions_v1_task_id_fkey" FOREIGN KEY (task_id) REFERENCES public.aicq_practical_tasks_v1(id)
);

ALTER TABLE "public"."aicq_practical_task_versions_v1"
  ENABLE ROW LEVEL SECURITY;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
  ON TABLE "public"."aicq_practical_task_versions_v1"
  TO "anon", "authenticated", "postgres", "service_role";
