CREATE TABLE "public"."aicq_item_versions_v1" (
  "id"                   uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "legacy_item_id"       uuid,
  "item_code"            text                     NOT NULL,
  "version"              text                     NOT NULL,
  "sub_competency_id"    uuid,
  "cognitive_demand"     text,
  "evidence_type"        text,
  "stem"                 text                     NOT NULL,
  "status"               text                     NOT NULL DEFAULT 'DRAFT'::text,
  "answer_key_option_id" uuid,
  "metadata"             jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "created_at"           timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_item_versions_v1_item_code_version_key" UNIQUE (item_code, VERSION),
  CONSTRAINT "aicq_item_versions_v1_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_item_versions_v1_legacy_item_id_fkey" FOREIGN KEY (legacy_item_id) REFERENCES public.aicq_items(id),
  CONSTRAINT "aicq_item_versions_v1_sub_competency_id_fkey" FOREIGN KEY (sub_competency_id) REFERENCES public.aicq_sub_competencies_v1(id)
);

ALTER TABLE "public"."aicq_item_versions_v1"
  ENABLE ROW LEVEL SECURITY;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_item_versions_v1" TO "anon", "authenticated", "postgres", "service_role";
