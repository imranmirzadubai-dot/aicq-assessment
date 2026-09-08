CREATE TABLE "public"."aicq_admins" (
  "user_id"    uuid                     NOT NULL,
  "role"       text                     NOT NULL DEFAULT 'Platform Owner'::text,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_admins_pkey" PRIMARY KEY (user_id),
  CONSTRAINT "aicq_admins_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE "public"."aicq_admins"
  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin can read own membership" ON "public"."aicq_admins"
  FOR SELECT
  TO "authenticated"
  USING ((user_id = auth.uid()));

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_admins" TO "authenticated", "postgres", "service_role";
