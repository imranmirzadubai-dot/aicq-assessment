CREATE OR REPLACE FUNCTION public.aicq_capture_confidence_v1 (
  p_attempt_id      uuid,
  p_confidence      numeric,
  p_item_version_id uuid    DEFAULT NULL::uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare rid uuid;
begin
  if p_confidence is null or p_confidence < 0 or p_confidence > 100 then
    raise exception 'CONFIDENCE_INVALID'; end if;
  if not exists(select 1 from public.aicq_attempts_v1 where id=p_attempt_id and status in ('STARTED','IN_PROGRESS','PAUSED'))
    then raise exception 'ATTEMPT_NOT_ACTIVE'; end if;

  insert into public.aicq_confidence_responses_v1(attempt_id,item_version_id,confidence_value)
  values(p_attempt_id,p_item_version_id,p_confidence) returning id into rid;
  return jsonb_build_object('confidence_response_id',rid,'accepted',true);
end $function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_capture_confidence_v1"(uuid, numeric, uuid) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_capture_confidence_v1"(uuid, numeric, uuid) FROM PUBLIC;
