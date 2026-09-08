CREATE TABLE "public"."aicq_organizations" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "name"       text                     NOT NULL,
  "status"     text                     NOT NULL DEFAULT 'active'::text,
  "branding"   jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "settings"   jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_organizations_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."aicq_organizations"
  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "aicq_admin_insert_organizations" ON "public"."aicq_organizations"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (public.is_aicq_admin());

CREATE POLICY "aicq_admin_read_organizations" ON "public"."aicq_organizations"
  FOR SELECT
  TO "authenticated"
  USING (public.is_aicq_admin());

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_organizations" TO "anon", "authenticated", "postgres", "service_role";
