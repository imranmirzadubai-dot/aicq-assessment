CREATE OR REPLACE FUNCTION public.aicq_get_participant_session_v1 (
  p_token_hash text
)
  RETURNS TABLE (
    session_id uuid,
    attempt_id uuid,
    expires_at timestamp with time zone,
    revoked_at timestamp with time zone
  )
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
    select
        s.id,
        s.attempt_id,
        s.expires_at,
        s.revoked_at
    from public.aicq_participant_sessions_v1 s
    where s.token_hash = lower(p_token_hash)
    limit 1
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_get_participant_session_v1"(text) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_get_participant_session_v1"(text) FROM PUBLIC;
