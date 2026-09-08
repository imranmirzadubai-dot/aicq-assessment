CREATE TABLE "public"."aicq_bank_imports_v1" (
  "id"                    uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id"       uuid,
  "assessment_code"       text                     NOT NULL,
  "question_bank_version" text                     NOT NULL,
  "source_filename"       text,
  "source_sha256"         text,
  "payload"               jsonb                    NOT NULL,
  "item_count"            integer                  NOT NULL DEFAULT 0,
  "option_count"          integer                  NOT NULL DEFAULT 0,
  "validation_status"     text                     NOT NULL DEFAULT 'PENDING'::text,
  "validation_errors"     jsonb                    NOT NULL DEFAULT '[]'::jsonb,
  "validation_warnings"   jsonb                    NOT NULL DEFAULT '[]'::jsonb,
  "imported_by"           uuid,
  "validated_at"          timestamp with time zone,
  "promoted_at"           timestamp with time zone,
  "created_at"            timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "aicq_bank_imports_v1_imported_by_fkey" FOREIGN KEY (imported_by) REFERENCES auth.users(id),
  CONSTRAINT "aicq_bank_imports_v1_pkey" PRIMARY KEY (id),
  CONSTRAINT "aicq_bank_imports_v1_validation_status_check"
    CHECK ((validation_status = ANY (ARRAY['PENDING'::text, 'VALID'::text, 'INVALID'::text, 'PROMOTED'::text, 'REJECTED'::text]))),
  CONSTRAINT "aicq_bank_imports_v1_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public.aicq_organizations(id)
);

ALTER TABLE "public"."aicq_bank_imports_v1"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_aicq_bank_imports_created ON public.aicq_bank_imports_v1 USING btree (created_at DESC);

CREATE INDEX idx_aicq_bank_imports_status ON public.aicq_bank_imports_v1 USING btree (validation_status);

CREATE INDEX idx_aicq_bank_imports_version ON public.aicq_bank_imports_v1 USING btree (question_bank_version);

CREATE TRIGGER trg_aicq_bank_import_immutable
  BEFORE DELETE OR UPDATE ON public.aicq_bank_imports_v1
  FOR EACH ROW
  EXECUTE FUNCTION public.aicq_prevent_promoted_bank_import_mutation_v1();

CREATE POLICY "aicq_bank_imports_admin_insert" ON "public"."aicq_bank_imports_v1"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.aicq_admins a
  WHERE (a.user_id = auth.uid()))));

CREATE POLICY "aicq_bank_imports_admin_read" ON "public"."aicq_bank_imports_v1"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.aicq_admins a
  WHERE (a.user_id = auth.uid()))));

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."aicq_bank_imports_v1" TO "anon", "authenticated", "postgres", "service_role";

COMMENT ON TABLE "public"."aicq_bank_imports_v1" IS 'AICQ Pilot bank staging and validation layer. Frozen source banks must pass validation before promotion into immutable item versions.';
