-- Foreign keys in a cross-table reference cycle are split out of their
-- table's file: each file loads atomically, so keeping them inline would
-- deadlock the loader (every file would need a table another pending file
-- creates). These statements apply once all referenced tables exist.

ALTER TABLE "public"."aicq_item_options_v1"
  ADD CONSTRAINT "aicq_item_options_v1_item_version_id_fkey" FOREIGN KEY (item_version_id) REFERENCES public.aicq_item_versions_v1(id) ON DELETE CASCADE;
