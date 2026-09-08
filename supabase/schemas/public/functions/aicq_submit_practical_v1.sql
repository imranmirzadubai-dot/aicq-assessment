CREATE OR REPLACE FUNCTION public.aicq_submit_practical_v1 (
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
DECLARE
    v_attempt_status text;
    v_task_status text;
    v_submission_id uuid;
BEGIN

    IF p_attempt_id IS NULL THEN
        RAISE EXCEPTION 'ATTEMPT_ID_REQUIRED';
    END IF;

    IF p_task_version_id IS NULL THEN
        RAISE EXCEPTION 'TASK_VERSION_ID_REQUIRED';
    END IF;


    SELECT status
    INTO v_attempt_status
    FROM public.aicq_attempts_v1
    WHERE id = p_attempt_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ATTEMPT_NOT_FOUND';
    END IF;


    IF v_attempt_status NOT IN (
        'STARTED',
        'IN_PROGRESS',
        'PAUSED'
    ) THEN
        RAISE EXCEPTION 'ATTEMPT_NOT_ACTIVE';
    END IF;


    SELECT status
    INTO v_task_status
    FROM public.aicq_practical_task_versions_v1
    WHERE id = p_task_version_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'TASK_VERSION_NOT_FOUND';
    END IF;


    IF v_task_status <> 'PUBLISHED' THEN
        RAISE EXCEPTION 'TASK_VERSION_NOT_PUBLISHED';
    END IF;


    IF p_ordered_steps IS NULL
       OR jsonb_typeof(p_ordered_steps) <> 'array' THEN
        RAISE EXCEPTION 'ORDERED_STEPS_MUST_BE_ARRAY';
    END IF;


    IF jsonb_array_length(p_ordered_steps) <> 9 THEN
        RAISE EXCEPTION 'PRACTICAL_REQUIRES_9_STEPS';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM public.aicq_practical_submissions_v1
        WHERE attempt_id = p_attempt_id
    ) THEN
        RAISE EXCEPTION 'PRACTICAL_ALREADY_SUBMITTED';
    END IF;


    INSERT INTO public.aicq_practical_submissions_v1 (
        attempt_id,
        task_version_id,
        ordered_steps,
        submission_data,
        submitted_at,
        created_at
    )
    VALUES (
        p_attempt_id,
        p_task_version_id,
        p_ordered_steps,
        COALESCE(p_submission_data, '{}'::jsonb),
        now(),
        now()
    )
    RETURNING id
    INTO v_submission_id;


    RETURN jsonb_build_object(
        'ok', true,
        'code', 'PRACTICAL_SUBMITTED',
        'practical_submission_id', v_submission_id,
        'attempt_id', p_attempt_id
    );

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_submit_practical_v1"(uuid, uuid, jsonb, jsonb) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_submit_practical_v1"(uuid, uuid, jsonb, jsonb) FROM PUBLIC;
