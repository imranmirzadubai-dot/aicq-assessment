CREATE OR REPLACE FUNCTION public.aicq_start_attempt_v1 (
  p_attempt_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_eligibility jsonb;
    v_result jsonb;
BEGIN

    IF p_attempt_id IS NULL THEN
        RAISE EXCEPTION 'ATTEMPT_ID_REQUIRED';
    END IF;


    v_eligibility :=
        public.aicq_check_attempt_session_eligibility_v1(
            p_attempt_id
        );


    IF COALESCE((v_eligibility->>'ok')::boolean, false) = false THEN
        RAISE EXCEPTION '%',
            COALESCE(
                v_eligibility->>'code',
                'ATTEMPT_NOT_STARTABLE'
            );
    END IF;


    UPDATE public.aicq_attempts_v1
    SET
        status = 'IN_PROGRESS',
        started_at = COALESCE(started_at, now())
    WHERE id = p_attempt_id
      AND status IN (
          'CREATED',
          'STARTED',
          'PAUSED'
      );


    IF NOT FOUND THEN
        RAISE EXCEPTION 'ATTEMPT_NOT_STARTABLE';
    END IF;


    SELECT jsonb_build_object(
        'attempt_id', a.id,
        'status', a.status,
        'started_at', a.started_at
    )
    INTO v_result
    FROM public.aicq_attempts_v1 a
    WHERE a.id = p_attempt_id;


    RETURN v_result;

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_start_attempt_v1"(uuid) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_start_attempt_v1"(uuid) FROM PUBLIC;
