CREATE TABLE "public"."aicq_item_options_v1" (
  "id"              uuid    NOT NULL DEFAULT gen_random_uuid(),
  "item_version_id" uuid    NOT NULL,
  "option_code"     text    NOT NULL,
  "option_text"     text    NOT NULL,
  "option_index"    integer,
  "metadata"        jsonb   NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT "aicq_item_options_v1_item_version_id_option_code_key" UNIQUE (item_version_id, option_code),
  CONSTRAINT "aicq_item_options_v1_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."aicq_item_options_v1"
  ENABLE ROW LEVEL SECURITY;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_item_options_v1" TO "anon", "authenticated", "postgres", "service_role";
