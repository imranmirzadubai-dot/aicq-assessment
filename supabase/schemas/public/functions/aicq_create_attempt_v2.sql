CREATE OR REPLACE FUNCTION public.aicq_create_attempt_v2 (
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
  RETURNS TABLE (
    attempt_id            uuid,
    assessment_version_id uuid,
    form_version_id       uuid,
    attempt_number        integer,
    status                text
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$

DECLARE
    v_assessment_definition_id uuid;
    v_assessment_version_id uuid;
    v_form_version_id uuid;
    v_form_status text;
    v_form_assessment_version_id uuid;
    v_attempt_number integer;
BEGIN

    -- --------------------------------------------------------
    -- 1. Resolve assessment definition
    -- --------------------------------------------------------

    SELECT ad.id
    INTO v_assessment_definition_id
    FROM public.aicq_assessment_definitions AS ad
    WHERE ad.assessment_code = p_assessment_code
    LIMIT 1;

    IF v_assessment_definition_id IS NULL THEN
        RAISE EXCEPTION 'ASSESSMENT_NOT_FOUND';
    END IF;


    -- --------------------------------------------------------
    -- 2. Resolve assessment version
    -- --------------------------------------------------------

    SELECT av.id
    INTO v_assessment_version_id
    FROM public.aicq_assessment_versions_v1 AS av
    WHERE av.assessment_definition_id = v_assessment_definition_id
      AND av.version = '1.0'
    LIMIT 1;

    IF v_assessment_version_id IS NULL THEN
        RAISE EXCEPTION 'ASSESSMENT_VERSION_NOT_FOUND';
    END IF;


    -- --------------------------------------------------------
    -- 3. Resolve exact form version
    -- --------------------------------------------------------

    SELECT
        fv.id,
        fv.status,
        fv.assessment_version_id
    INTO
        v_form_version_id,
        v_form_status,
        v_form_assessment_version_id
    FROM public.aicq_form_versions_v1 AS fv
    WHERE fv.form_code = p_form_code
      AND fv.version = p_form_version
    LIMIT 1;

    IF v_form_version_id IS NULL THEN
        RAISE EXCEPTION 'FORM_VERSION_NOT_FOUND';
    END IF;


    -- --------------------------------------------------------
    -- 4. Verify assessment/form lineage
    -- --------------------------------------------------------

    IF v_form_assessment_version_id IS DISTINCT FROM v_assessment_version_id THEN
        RAISE EXCEPTION 'FORM_ASSESSMENT_MISMATCH';
    END IF;


    -- --------------------------------------------------------
    -- 5. Participant attempts require published form
    -- --------------------------------------------------------

    IF v_form_status <> 'PUBLISHED' THEN
        RAISE EXCEPTION 'FORM_NOT_PUBLISHED';
    END IF;


    -- --------------------------------------------------------
    -- 6. Published F01 must contain exactly 32 items
    -- --------------------------------------------------------

    IF (
        SELECT count(*)
        FROM public.aicq_form_items_v1 AS fi
        WHERE fi.form_version_id = v_form_version_id
    ) <> 32 THEN
        RAISE EXCEPTION 'FORM_ITEM_COUNT_INVALID';
    END IF;


    -- --------------------------------------------------------
    -- 7. Every referenced item version must be published
    -- --------------------------------------------------------

    IF EXISTS (
        SELECT 1
        FROM public.aicq_form_items_v1 AS fi
        JOIN public.aicq_item_versions_v1 AS iv
          ON iv.id = fi.item_version_id
        WHERE fi.form_version_id = v_form_version_id
          AND iv.status <> 'PUBLISHED'
    ) THEN
        RAISE EXCEPTION 'ITEM_VERSION_NOT_PUBLISHED';
    END IF;


    -- --------------------------------------------------------
    -- 8. Determine attempt number
    -- --------------------------------------------------------

    IF p_participant_id IS NULL THEN

        v_attempt_number := 1;

    ELSE

        SELECT COALESCE(MAX(a.attempt_number), 0) + 1
        INTO v_attempt_number
        FROM public.aicq_attempts_v1 AS a
        WHERE a.participant_id = p_participant_id
          AND a.assessment_version_id = v_assessment_version_id;

    END IF;


    -- --------------------------------------------------------
    -- 9. Create attempt
    -- --------------------------------------------------------

    RETURN QUERY
    INSERT INTO public.aicq_attempts_v1 (
        participant_id,
        organization_id,
        program_id,
        assessment_version_id,
        form_version_id,
        attempt_number,
        status,
        participant_name_snapshot,
        participant_age_snapshot,
        participant_gender_snapshot,
        participant_occupation_snapshot,
        participant_experience_snapshot,
        created_at
    )
    VALUES (
        p_participant_id,
        p_organization_id,
        p_program_id,
        v_assessment_version_id,
        v_form_version_id,
        v_attempt_number,
        'CREATED',
        p_participant_name,
        p_participant_age,
        p_participant_gender,
        p_participant_occupation,
        p_participant_experience,
        now()
    )
    RETURNING
        aicq_attempts_v1.id,
        aicq_attempts_v1.assessment_version_id,
        aicq_attempts_v1.form_version_id,
        aicq_attempts_v1.attempt_number,
        aicq_attempts_v1.status;

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_create_attempt_v2"(text, text, text, uuid, uuid, uuid, text, integer, text, text, integer) TO "postgres";

REVOKE ALL ON FUNCTION "public"."aicq_create_attempt_v2"(text, text, text, uuid, uuid, uuid, text, integer, text, text, integer) FROM PUBLIC;
