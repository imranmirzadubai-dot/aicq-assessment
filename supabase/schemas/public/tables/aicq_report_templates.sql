CREATE TABLE "public"."aicq_report_templates" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id"  uuid,
  "name"             text                     NOT NULL,
  "version"          text                     NOT NULL,
  "status"           text                     NOT NULL DEFAULT 'draft'::text,
  "locked_master"    boolean                  NOT NULL DEFAULT false,
  "layout_reference" text,
  "wording_config"   jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "data_mapping"     jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "renderer_version" text,
  "created_at"       timestamp with time zone NOT NULL DEFAULT now(),
  "approved_at"      timestamp with time zone,
  CONSTRAINT "aicq_report_templates_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public.aicq_organizations(id),
  CONSTRAINT "aicq_report_templates_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."aicq_report_templates"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_aicq_report_templates_org ON public.aicq_report_templates USING btree (organization_id);

CREATE POLICY "aicq_admin_insert_report_templates" ON "public"."aicq_report_templates"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (public.is_aicq_admin());

CREATE POLICY "aicq_admin_read_report_templates" ON "public"."aicq_report_templates"
  FOR SELECT
  TO "authenticated"
  USING (public.is_aicq_admin());

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_report_templates" TO "anon", "authenticated", "postgres", "service_role";
