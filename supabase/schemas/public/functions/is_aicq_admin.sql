CREATE OR REPLACE FUNCTION public.is_aicq_admin()
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1
    from public.aicq_admins
    where user_id = auth.uid()
  );
$function$;

GRANT EXECUTE ON FUNCTION "public"."is_aicq_admin"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";
