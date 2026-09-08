CREATE OR REPLACE FUNCTION public.aicq_capture_practical_submission_v1 (
  p_attempt_id      uuid,
  p_task_version_id uuid,
  p_ordered_steps   jsonb,
  p_submission_data jsonb DEFAULT '{}'::jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare rid uuid;
begin
  if not exists(select 1 from public.aicq_attempts_v1 where id=p_attempt_id and status in ('STARTED','IN_PROGRESS','PAUSED'))
    then raise exception 'ATTEMPT_NOT_ACTIVE'; end if;
  if jsonb_typeof(p_ordered_steps) <> 'array' then raise exception 'ORDERED_STEPS_INVALID'; end if;

  insert into public.aicq_practical_submissions_v1(
    attempt_id,task_version_id,ordered_steps,submission_data,submitted_at
  )
  values(p_attempt_id,p_task_version_id,p_ordered_steps,p_submission_data,now())
  returning id into rid;
  return jsonb_build_object('practical_submission_id',rid,'accepted',true);
end $function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_capture_practical_submission_v1"(uuid, uuid, jsonb, jsonb) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_capture_practical_submission_v1"(uuid, uuid, jsonb, jsonb) FROM PUBLIC;
