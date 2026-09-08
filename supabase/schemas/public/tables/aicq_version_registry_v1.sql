CREATE TABLE "public"."aicq_version_registry_v1" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "component_type" text                     NOT NULL,
  "component_id"   text                     NOT NULL,
  "version"        text                     NOT NULL,
  "status"         text                     NOT NULL,
  "published_at"   timestamp with time zone,
  "retired_at"     timestamp with time zone,
  "metadata"       jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT "aicq_version_registry_v1_component_type_component_id_versio_key" UNIQUE (component_type, component_id, VERSION),
  CONSTRAINT "aicq_version_registry_v1_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."aicq_version_registry_v1"
  ENABLE ROW LEVEL SECURITY;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_version_registry_v1" TO "anon", "authenticated", "postgres", "service_role";
