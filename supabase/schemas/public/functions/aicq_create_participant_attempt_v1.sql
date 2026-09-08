CREATE OR REPLACE FUNCTION public.aicq_create_participant_attempt_v1 (
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
    v_assessment_version_status text;

    v_form_version_id uuid;
    v_form_status text;
    v_form_assessment_version_id uuid;

    v_item_count integer;
    v_unpublished_items integer;
    v_invalid_option_items integer;
    v_missing_key_items integer;

    v_attempt_number integer;

BEGIN

    -- ========================================================
    -- BASIC INPUT VALIDATION
    -- ========================================================

    IF p_assessment_code IS NULL OR btrim(p_assessment_code) = '' THEN
        RAISE EXCEPTION 'ASSESSMENT_CODE_REQUIRED';
    END IF;

    IF p_form_code IS NULL OR btrim(p_form_code) = '' THEN
        RAISE EXCEPTION 'FORM_CODE_REQUIRED';
    END IF;

    IF p_form_version IS NULL OR btrim(p_form_version) = '' THEN
        RAISE EXCEPTION 'FORM_VERSION_REQUIRED';
    END IF;


    -- ========================================================
    -- RESOLVE ASSESSMENT DEFINITION
    -- ========================================================

    SELECT
        ad.id
    INTO
        v_assessment_definition_id
    FROM public.aicq_assessment_definitions AS ad
    WHERE ad.assessment_code = p_assessment_code
    LIMIT 1;

    IF v_assessment_definition_id IS NULL THEN
        RAISE EXCEPTION 'ASSESSMENT_NOT_FOUND';
    END IF;


    -- ========================================================
    -- RESOLVE PUBLISHED ASSESSMENT VERSION
    -- ========================================================

    SELECT
        av.id,
        av.status
    INTO
        v_assessment_version_id,
        v_assessment_version_status
    FROM public.aicq_assessment_versions_v1 AS av
    WHERE av.assessment_definition_id = v_assessment_definition_id
      AND av.version = '1.0'
    LIMIT 1;

    IF v_assessment_version_id IS NULL THEN
        RAISE EXCEPTION 'ASSESSMENT_VERSION_NOT_FOUND';
    END IF;

    IF v_assessment_version_status <> 'PUBLISHED' THEN
        RAISE EXCEPTION 'ASSESSMENT_VERSION_NOT_PUBLISHED';
    END IF;


    -- ========================================================
    -- RESOLVE FORM VERSION
    -- ========================================================

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


    -- ========================================================
    -- FORM MUST BELONG TO THIS ASSESSMENT VERSION
    -- ========================================================

    IF v_form_assessment_version_id IS DISTINCT FROM v_assessment_version_id THEN
        RAISE EXCEPTION 'FORM_ASSESSMENT_MISMATCH';
    END IF;


    -- ========================================================
    -- FORM MUST BE PUBLISHED
    -- ========================================================

    IF v_form_status <> 'PUBLISHED' THEN
        RAISE EXCEPTION 'FORM_NOT_PUBLISHED';
    END IF;


    -- ========================================================
    -- FORM CONTENT INTEGRITY
    --
    -- F01 Pilot 1 must contain exactly 32 items.
    -- ========================================================

    SELECT count(*)
    INTO v_item_count
    FROM public.aicq_form_items_v1 AS fi
    WHERE fi.form_version_id = v_form_version_id;

    IF v_item_count <> 32 THEN
        RAISE EXCEPTION 'FORM_ITEM_COUNT_INVALID';
    END IF;


    -- ========================================================
    -- EVERY ITEM VERSION MUST BE PUBLISHED
    -- ========================================================

    SELECT count(*)
    INTO v_unpublished_items
    FROM public.aicq_form_items_v1 AS fi
    JOIN public.aicq_item_versions_v1 AS iv
      ON iv.id = fi.item_version_id
    WHERE fi.form_version_id = v_form_version_id
      AND iv.status <> 'PUBLISHED';

    IF v_unpublished_items > 0 THEN
        RAISE EXCEPTION 'ITEM_VERSION_NOT_PUBLISHED';
    END IF;


    -- ========================================================
    -- EVERY ITEM MUST HAVE EXACTLY FOUR OPTIONS
    -- ========================================================

    SELECT count(*)
    INTO v_invalid_option_items
    FROM (
        SELECT
            iv.id
        FROM public.aicq_form_items_v1 AS fi
        JOIN public.aicq_item_versions_v1 AS iv
          ON iv.id = fi.item_version_id
        LEFT JOIN public.aicq_item_options_v1 AS io
          ON io.item_version_id = iv.id
        WHERE fi.form_version_id = v_form_version_id
        GROUP BY iv.id
        HAVING count(io.id) <> 4
    ) AS invalid_items;

    IF v_invalid_option_items > 0 THEN
        RAISE EXCEPTION 'ITEM_OPTION_COUNT_INVALID';
    END IF;


    -- ========================================================
    -- EVERY ITEM MUST HAVE EXACTLY ONE ANSWER KEY
    -- ========================================================

    SELECT count(*)
    INTO v_missing_key_items
    FROM public.aicq_form_items_v1 AS fi
    JOIN public.aicq_item_versions_v1 AS iv
      ON iv.id = fi.item_version_id
    WHERE fi.form_version_id = v_form_version_id
      AND iv.answer_key_option_id IS NULL;

    IF v_missing_key_items > 0 THEN
        RAISE EXCEPTION 'ITEM_ANSWER_KEY_MISSING';
    END IF;


    -- ========================================================
    -- DETERMINE ATTEMPT NUMBER
    --
    -- Anonymous attempts start at 1.
    -- Authenticated participants increment independently.
    -- ========================================================

    IF p_participant_id IS NULL THEN

        v_attempt_number := 1;

    ELSE

        SELECT
            COALESCE(MAX(a.attempt_number), 0) + 1
        INTO
            v_attempt_number
        FROM public.aicq_attempts_v1 AS a
        WHERE a.participant_id = p_participant_id
          AND a.assessment_version_id = v_assessment_version_id;

    END IF;


    -- ========================================================
    -- CREATE ATTEMPT
    -- ========================================================

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
        participant_experience_snapshot
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
        p_participant_experience
    )
    RETURNING
        id,
        assessment_version_id,
        form_version_id,
        attempt_number,
        status;

END;

$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_create_participant_attempt_v1"(text, text, text, uuid, uuid, uuid, text, integer, text, text, integer) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_create_participant_attempt_v1"(text, text, text, uuid, uuid, uuid, text, integer, text, text, integer) FROM PUBLIC;
