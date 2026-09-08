CREATE TABLE "public"."aicq_forms" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid,
  "program_id"      uuid,
  "name"            text                     NOT NULL,
  "version"         text                     NOT NULL DEFAULT '1.0'::text,
  "type"            text                     NOT NULL DEFAULT 'fixed'::text,
  "item_count"      integer,
  "status"          text                     NOT NULL DEFAULT 'draft'::text,
  "blueprint"       jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "randomization"   jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "delivery_rules"  jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "published_at"    timestamp with time zone,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_forms_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_forms_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public.aicq_organizations(id),
  CONSTRAINT "aicq_forms_program_id_fkey" FOREIGN KEY (program_id) REFERENCES public.aicq_programs(id)
);

ALTER TABLE "public"."aicq_forms"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_aicq_forms_org ON public.aicq_forms USING btree (organization_id);

CREATE INDEX idx_aicq_forms_program ON public.aicq_forms USING btree (program_id);

CREATE POLICY "aicq_admin_insert_forms" ON "public"."aicq_forms"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (public.is_aicq_admin());

CREATE POLICY "aicq_admin_read_forms" ON "public"."aicq_forms"
  FOR SELECT
  TO "authenticated"
  USING (public.is_aicq_admin());

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_forms" TO "anon", "authenticated", "postgres", "service_role";
