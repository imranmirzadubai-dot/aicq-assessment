CREATE OR REPLACE FUNCTION public.aicq_get_practical_task_v1()
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v jsonb;
BEGIN
  SELECT jsonb_build_object(
    'task_version_id', tv.id,
    'task_code', t.task_code,
    'version', tv.version,
    'task_definition',
      (tv.task_definition - 'correct_order')
  )
  INTO v
  FROM public.aicq_practical_task_versions_v1 tv
  JOIN public.aicq_practical_tasks_v1 t
    ON t.id = tv.task_id
  WHERE t.task_code = 'AICQ-P1-PRACTICAL-V3'
    AND tv.version = '1.0'
    AND tv.status = 'PUBLISHED';

  IF v IS NULL THEN
    RAISE EXCEPTION 'PRACTICAL_TASK_NOT_PUBLISHED';
  END IF;

  RETURN v;
END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_get_practical_task_v1"() TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_get_practical_task_v1"() FROM PUBLIC;
