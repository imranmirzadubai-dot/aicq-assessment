CREATE TABLE "public"."aicq_report_records" (
  "id"                    uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id"       uuid,
  "participant_reference" text,
  "assessment_id"         uuid,
  "template_version"      text,
  "scoring_version"       text,
  "data_snapshot_hash"    text,
  "renderer_version"      text,
  "pdf_hash"              text,
  "status"                text                     NOT NULL DEFAULT 'staging'::text,
  "generated_at"          timestamp with time zone NOT NULL DEFAULT now(),
  "released_at"           timestamp with time zone,
  CONSTRAINT "aicq_report_records_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public.aicq_organizations(id),
  CONSTRAINT "aicq_report_records_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."aicq_report_records"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_aicq_report_records_assessment ON public.aicq_report_records USING btree (assessment_id);

CREATE INDEX idx_aicq_report_records_org ON public.aicq_report_records USING btree (organization_id);

CREATE POLICY "aicq_admin_insert_report_records" ON "public"."aicq_report_records"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (public.is_aicq_admin());

CREATE POLICY "aicq_admin_read_report_records" ON "public"."aicq_report_records"
  FOR SELECT
  TO "authenticated"
  USING (public.is_aicq_admin());

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_report_records" TO "anon", "authenticated", "postgres", "service_role";
