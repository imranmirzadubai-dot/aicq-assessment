CREATE OR REPLACE FUNCTION public.aicq_check_attempt_session_eligibility_v1 (
  p_attempt_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_attempt_status text;
    v_form_status text;
    v_form_assessment_version_id uuid;
    v_attempt_assessment_version_id uuid;
BEGIN

    SELECT
        a.status,
        a.assessment_version_id,
        fv.status,
        fv.assessment_version_id
    INTO
        v_attempt_status,
        v_attempt_assessment_version_id,
        v_form_status,
        v_form_assessment_version_id
    FROM public.aicq_attempts_v1 a
    JOIN public.aicq_form_versions_v1 fv
      ON fv.id = a.form_version_id
    WHERE a.id = p_attempt_id;


    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'ATTEMPT_NOT_FOUND'
        );
    END IF;


    IF v_form_assessment_version_id IS DISTINCT FROM
       v_attempt_assessment_version_id THEN

        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_ASSESSMENT_MISMATCH',
            'status', v_attempt_status,
            'form_status', v_form_status
        );

    END IF;


    IF v_form_status <> 'PUBLISHED' THEN

        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_NOT_PUBLISHED',
            'status', v_attempt_status,
            'form_status', v_form_status
        );

    END IF;


    IF v_attempt_status IN (
        'CREATED',
        'STARTED',
        'IN_PROGRESS',
        'PAUSED'
    ) THEN

        RETURN jsonb_build_object(
            'ok', true,
            'status', v_attempt_status,
            'form_status', v_form_status
        );

    END IF;


    RETURN jsonb_build_object(
        'ok', false,
        'code', 'ATTEMPT_NOT_ELIGIBLE',
        'status', v_attempt_status,
        'form_status', v_form_status
    );

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_check_attempt_session_eligibility_v1"(uuid) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_check_attempt_session_eligibility_v1"(uuid) FROM PUBLIC;
