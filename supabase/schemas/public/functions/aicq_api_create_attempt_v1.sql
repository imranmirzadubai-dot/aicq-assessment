CREATE OR REPLACE FUNCTION public.aicq_api_create_attempt_v1 (
  p_assessment_code        text    DEFAULT 'AICQ-P1'::text,
  p_form_code              text    DEFAULT 'AICQ-P1-F01'::text,
  p_form_version           text    DEFAULT '1.0'::text,
  p_participant_id         uuid    DEFAULT NULL::uuid,
  p_organization_id        uuid    DEFAULT NULL::uuid,
  p_program_id             uuid    DEFAULT NULL::uuid,
  p_participant_name       text    DEFAULT NULL::text,
  p_participant_age        integer DEFAULT NULL::integer,
  p_participant_gender     text    DEFAULT NULL::text,
  p_participant_occupation text    DEFAULT NULL::text,
  p_participant_experience integer DEFAULT NULL::integer
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_result record;
BEGIN

    SELECT *
    INTO v_result
    FROM public.aicq_create_attempt_v1(
        p_assessment_code::text,
        p_form_code::text,
        p_form_version::text,
        p_participant_id::uuid,
        p_organization_id::uuid,
        p_program_id::uuid,
        p_participant_name::text,
        p_participant_age::integer,
        p_participant_gender::text,
        p_participant_occupation::text,
        p_participant_experience::integer
    );

    IF v_result.attempt_id IS NULL THEN
        RAISE EXCEPTION 'ATTEMPT_CREATION_FAILED';
    END IF;

    RETURN jsonb_build_object(
        'attempt_id', v_result.attempt_id,
        'assessment_version_id', v_result.assessment_version_id,
        'form_version_id', v_result.form_version_id,
        'attempt_number', v_result.attempt_number,
        'status', v_result.status
    );

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_api_create_attempt_v1"(text, text, text, uuid, uuid, uuid, text, integer, text, text, integer) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_api_create_attempt_v1"(text, text, text, uuid, uuid, uuid, text, integer, text, text, integer) FROM PUBLIC;
