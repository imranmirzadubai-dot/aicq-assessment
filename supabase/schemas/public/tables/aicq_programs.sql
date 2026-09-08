CREATE TABLE "public"."aicq_programs" (
  "id"                uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id"   uuid,
  "name"              text                     NOT NULL,
  "version"           text                     NOT NULL DEFAULT '1.0'::text,
  "status"            text                     NOT NULL DEFAULT 'draft'::text,
  "target_population" text,
  "form_name"         text,
  "blueprint"         jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "updated_at"        timestamp with time zone NOT NULL DEFAULT now(),
  "created_at"        timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_programs_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public.aicq_organizations(id),
  CONSTRAINT "aicq_programs_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."aicq_programs"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_aicq_programs_org ON public.aicq_programs USING btree (organization_id);

CREATE POLICY "aicq_admin_insert_programs" ON "public"."aicq_programs"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (public.is_aicq_admin());

CREATE POLICY "aicq_admin_read_programs" ON "public"."aicq_programs"
  FOR SELECT
  TO "authenticated"
  USING (public.is_aicq_admin());

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_programs" TO "anon", "authenticated", "postgres", "service_role";
