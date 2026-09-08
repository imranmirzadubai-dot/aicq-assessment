CREATE OR REPLACE FUNCTION public.aicq_get_attempt_v1 (
  p_attempt_id uuid
)
  RETURNS jsonb
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select jsonb_build_object(
    'attempt_id',id,
    'assessment_version_id',assessment_version_id,
    'form_version_id',form_version_id,
    'status',status,
    'attempt_number',attempt_number
  )
  from public.aicq_attempts_v1 where id=p_attempt_id
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_get_attempt_v1"(uuid) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_get_attempt_v1"(uuid) FROM PUBLIC;
