CREATE TABLE "public"."aicq_ai_registry" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid,
  "name"            text                     NOT NULL,
  "purpose"         text,
  "risk_level"      text,
  "owner"           text,
  "status"          text                     NOT NULL DEFAULT 'draft'::text,
  "model_version"   text,
  "provenance"      jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "risk_assessment" jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "human_oversight" jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "updated_at"      timestamp with time zone NOT NULL DEFAULT now(),
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_ai_registry_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_ai_registry_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public.aicq_organizations(id)
);

ALTER TABLE "public"."aicq_ai_registry"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_aicq_ai_registry_org ON public.aicq_ai_registry USING btree (organization_id);

CREATE POLICY "aicq_admin_insert_ai_registry" ON "public"."aicq_ai_registry"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (public.is_aicq_admin());

CREATE POLICY "aicq_admin_read_ai_registry" ON "public"."aicq_ai_registry"
  FOR SELECT
  TO "authenticated"
  USING (public.is_aicq_admin());

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_ai_registry" TO "anon", "authenticated", "postgres", "service_role";
