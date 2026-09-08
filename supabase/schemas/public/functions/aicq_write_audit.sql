CREATE OR REPLACE FUNCTION public.aicq_write_audit (
  p_action      text,
  p_entity_type text,
  p_entity_id   text,
  p_details     jsonb DEFAULT '{}'::jsonb
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  insert into public.aicq_audit_log(
    actor_user_id,
    action,
    entity_type,
    entity_id,
    result,
    details
  )
  values(
    auth.uid(),
    p_action,
    p_entity_type,
    p_entity_id,
    'success',
    coalesce(p_details, '{}'::jsonb)
  );
end;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_write_audit"(text, text, text, jsonb) TO "anon", "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_write_audit"(text, text, text, jsonb) FROM PUBLIC;
