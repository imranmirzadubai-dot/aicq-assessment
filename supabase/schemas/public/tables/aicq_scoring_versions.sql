CREATE TABLE "public"."aicq_scoring_versions" (
  "id"                 uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id"    uuid,
  "version"            text                     NOT NULL,
  "assessment_version" text,
  "status"             text                     NOT NULL DEFAULT 'draft'::text,
  "knowledge_weight"   numeric,
  "practical_weight"   numeric,
  "parameters"         jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "created_at"         timestamp with time zone NOT NULL DEFAULT now(),
  "approved_at"        timestamp with time zone,
  CONSTRAINT "aicq_scoring_versions_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public.aicq_organizations(id),
  CONSTRAINT "aicq_scoring_versions_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."aicq_scoring_versions"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_aicq_scoring_org ON public.aicq_scoring_versions USING btree (organization_id);

CREATE POLICY "aicq_admin_insert_scoring_versions" ON "public"."aicq_scoring_versions"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (public.is_aicq_admin());

CREATE POLICY "aicq_admin_read_scoring_versions" ON "public"."aicq_scoring_versions"
  FOR SELECT
  TO "authenticated"
  USING (public.is_aicq_admin());

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_scoring_versions" TO "anon", "authenticated", "postgres", "service_role";
