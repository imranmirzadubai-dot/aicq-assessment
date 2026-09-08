CREATE OR REPLACE FUNCTION public.aicq_reject_v1_submitted_attempt_mutation()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if exists (
    select 1
    from public.aicq_attempts_v1 a
    where a.id = coalesce(new.attempt_id, old.attempt_id)
      and a.status in ('SUBMITTED','PROCESSING','COMPLETED')
  ) then
    raise exception 'ATTEMPT_IMMUTABLE';
  end if;
  return coalesce(new, old);
end;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_reject_v1_submitted_attempt_mutation"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";
