CREATE OR REPLACE FUNCTION private.is_aicq_admin()
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select exists (
    select 1
    from private.aicq_admins a
    where a.user_id = (select auth.uid())
  );
$function$;

GRANT EXECUTE ON FUNCTION "private"."is_aicq_admin"() TO "authenticated", "postgres";

REVOKE ALL ON FUNCTION "private"."is_aicq_admin"() FROM PUBLIC;
