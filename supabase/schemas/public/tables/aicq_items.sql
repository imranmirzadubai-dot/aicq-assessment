CREATE TABLE "public"."aicq_items" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid,
  "item_code"       text                     NOT NULL,
  "competency"      text,
  "sub_competency"  text,
  "difficulty"      numeric,
  "evidence_level"  text,
  "status"          text                     NOT NULL DEFAULT 'draft'::text,
  "version"         text                     NOT NULL DEFAULT '1.0'::text,
  "item_payload"    jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "used_in_count"   integer                  NOT NULL DEFAULT 0,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_items_organization_id_item_code_version_key" UNIQUE (organization_id, item_code, VERSION),
  CONSTRAINT "aicq_items_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_items_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public.aicq_organizations(id)
);

ALTER TABLE "public"."aicq_items"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_aicq_items_org ON public.aicq_items USING btree (organization_id);

CREATE POLICY "aicq_admin_insert_items" ON "public"."aicq_items"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (public.is_aicq_admin());

CREATE POLICY "aicq_admin_read_items" ON "public"."aicq_items"
  FOR SELECT
  TO "authenticated"
  USING (public.is_aicq_admin());

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_items" TO "anon", "authenticated", "postgres", "service_role";
