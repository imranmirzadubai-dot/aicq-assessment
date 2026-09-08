CREATE TABLE "public"."aicq_jobs" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid,
  "type"            text                     NOT NULL,
  "status"          text                     NOT NULL DEFAULT 'queued'::text,
  "progress"        integer                  NOT NULL DEFAULT 0,
  "started_at"      timestamp with time zone,
  "completed_at"    timestamp with time zone,
  "error_message"   text,
  "details"         jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT "aicq_jobs_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_jobs_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public.aicq_organizations(id)
);

ALTER TABLE "public"."aicq_jobs"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_aicq_jobs_org ON public.aicq_jobs USING btree (organization_id);

CREATE INDEX idx_aicq_jobs_status ON public.aicq_jobs USING btree (status);

CREATE POLICY "aicq_admin_insert_jobs" ON "public"."aicq_jobs"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (public.is_aicq_admin());

CREATE POLICY "aicq_admin_read_jobs" ON "public"."aicq_jobs"
  FOR SELECT
  TO "authenticated"
  USING (public.is_aicq_admin());

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_jobs" TO "anon", "authenticated", "postgres", "service_role";
