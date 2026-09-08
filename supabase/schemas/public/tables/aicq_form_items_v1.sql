CREATE TABLE "public"."aicq_form_items_v1" (
  "id"              uuid    NOT NULL DEFAULT gen_random_uuid(),
  "form_version_id" uuid    NOT NULL,
  "item_version_id" uuid    NOT NULL,
  "position"        integer NOT NULL,
  CONSTRAINT "aicq_form_items_v1_form_version_id_item_version_id_key" UNIQUE (form_version_id, item_version_id),
  CONSTRAINT "aicq_form_items_v1_form_version_id_position_key" UNIQUE (form_version_id, "position"),
  CONSTRAINT "aicq_form_items_v1_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_form_items_v1_form_version_id_fkey" FOREIGN KEY (form_version_id) REFERENCES public.aicq_form_versions_v1(id) ON DELETE CASCADE,
  CONSTRAINT "aicq_form_items_v1_item_version_id_fkey" FOREIGN KEY (item_version_id) REFERENCES public.aicq_item_versions_v1(id)
);

ALTER TABLE "public"."aicq_form_items_v1"
  ENABLE ROW LEVEL SECURITY;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_form_items_v1" TO "anon", "authenticated", "postgres", "service_role";
