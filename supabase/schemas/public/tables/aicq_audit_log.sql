CREATE TABLE "public"."aicq_audit_log" (
  "id"              bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  "actor_user_id"   uuid,
  "organization_id" uuid,
  "action"          text                     NOT NULL,
  "entity_type"     text,
  "entity_id"       text,
  "result"          text,
  "details"         jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT "aicq_audit_log_actor_user_id_fkey" FOREIGN KEY (actor_user_id) REFERENCES auth.users(id),
  CONSTRAINT "aicq_audit_log_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_audit_log_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public.aicq_organizations(id)
);

ALTER TABLE "public"."aicq_audit_log"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_aicq_audit_actor ON public.aicq_audit_log USING btree (actor_user_id);

CREATE INDEX idx_aicq_audit_created ON public.aicq_audit_log USING btree (created_at DESC);

CREATE POLICY "aicq_admin_read_audit_log" ON "public"."aicq_audit_log"
  FOR SELECT
  TO "authenticated"
  USING (public.is_aicq_admin());

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_audit_log" TO "anon", "authenticated", "postgres", "service_role";
