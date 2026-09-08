CREATE TABLE "public"."aicq_user_profiles" (
  "user_id"         uuid                     NOT NULL,
  "email"           text,
  "display_name"    text,
  "organization_id" uuid,
  "role"            text                     NOT NULL DEFAULT 'Basic User'::text,
  "status"          text                     NOT NULL DEFAULT 'invited'::text,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_user_profiles_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public.aicq_organizations(id),
  CONSTRAINT "aicq_user_profiles_pkey" PRIMARY KEY (user_id),
  CONSTRAINT "aicq_user_profiles_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE "public"."aicq_user_profiles"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_aicq_user_profiles_org ON public.aicq_user_profiles USING btree (organization_id);

CREATE POLICY "aicq_admin_insert_user_profiles" ON "public"."aicq_user_profiles"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (public.is_aicq_admin());

CREATE POLICY "aicq_admin_read_user_profiles" ON "public"."aicq_user_profiles"
  FOR SELECT
  TO "authenticated"
  USING (public.is_aicq_admin());

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_user_profiles" TO "anon", "authenticated", "postgres", "service_role";
