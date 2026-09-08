CREATE OR REPLACE FUNCTION public.aicq_validate_form_publication_v1 (
  p_form_code    text,
  p_form_version text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_form_id uuid;
    v_assessment_version_id uuid;
    v_form_status text;
    v_assessment_status text;
    v_item_count integer;
    v_distinct_positions integer;
    v_distinct_items integer;
    v_unpublished_items integer;
    v_invalid_option_counts integer;
    v_missing_keys integer;
    v_multiple_keys integer;
BEGIN

    IF p_form_code IS NULL OR p_form_code = '' THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_CODE_REQUIRED'
        );
    END IF;

    IF p_form_version IS NULL OR p_form_version = '' THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_VERSION_REQUIRED'
        );
    END IF;

    SELECT
        fv.id,
        fv.assessment_version_id,
        fv.status
    INTO
        v_form_id,
        v_assessment_version_id,
        v_form_status
    FROM public.aicq_form_versions_v1 fv
    WHERE fv.form_code = p_form_code
      AND fv.version = p_form_version;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_NOT_FOUND',
            'form_code', p_form_code,
            'form_version', p_form_version
        );
    END IF;

    IF v_assessment_version_id IS NULL THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'ASSESSMENT_VERSION_REQUIRED',
            'form_status', v_form_status
        );
    END IF;

    SELECT av.status
    INTO v_assessment_status
    FROM public.aicq_assessment_versions_v1 av
    WHERE av.id = v_assessment_version_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'ASSESSMENT_VERSION_NOT_FOUND',
            'form_status', v_form_status
        );
    END IF;

    -- A form can only become participant-deliverable when its
    -- parent assessment version is itself published.
    IF v_assessment_status <> 'PUBLISHED' THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'ASSESSMENT_VERSION_NOT_PUBLISHED',
            'form_status', v_form_status,
            'assessment_status', v_assessment_status
        );
    END IF;

    SELECT count(*)
    INTO v_item_count
    FROM public.aicq_form_items_v1 fi
    WHERE fi.form_version_id = v_form_id;

    SELECT count(DISTINCT fi.position)
    INTO v_distinct_positions
    FROM public.aicq_form_items_v1 fi
    WHERE fi.form_version_id = v_form_id;

    SELECT count(DISTINCT fi.item_version_id)
    INTO v_distinct_items
    FROM public.aicq_form_items_v1 fi
    WHERE fi.form_version_id = v_form_id;

    IF v_item_count <> 32 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_ITEM_COUNT_INVALID',
            'item_count', v_item_count,
            'expected', 32
        );
    END IF;

    IF v_distinct_positions <> 32 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_POSITIONS_INVALID',
            'distinct_positions', v_distinct_positions,
            'expected', 32
        );
    END IF;

    IF v_distinct_items <> 32 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_DUPLICATE_ITEMS',
            'distinct_items', v_distinct_items,
            'expected', 32
        );
    END IF;

    -- Every item must be in the published state.
    SELECT count(*)
    INTO v_unpublished_items
    FROM public.aicq_form_items_v1 fi
    JOIN public.aicq_item_versions_v1 iv
      ON iv.id = fi.item_version_id
    WHERE fi.form_version_id = v_form_id
      AND iv.status <> 'PUBLISHED';

    IF v_unpublished_items <> 0 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'ITEMS_NOT_PUBLISHED',
            'unpublished_items', v_unpublished_items
        );
    END IF;

    -- Every item must have exactly four options.
    SELECT count(*)
    INTO v_invalid_option_counts
    FROM public.aicq_form_items_v1 fi
    JOIN public.aicq_item_options_v1 io
      ON io.item_version_id = fi.item_version_id
    WHERE fi.form_version_id = v_form_id
    GROUP BY fi.item_version_id
    HAVING count(*) <> 4;

    -- NULL means no group failed.
    IF v_invalid_option_counts IS NOT NULL THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'ITEM_OPTION_COUNT_INVALID'
        );
    END IF;

    -- Every item must have exactly one answer key.
    SELECT count(*)
    INTO v_missing_keys
    FROM public.aicq_form_items_v1 fi
    JOIN public.aicq_item_versions_v1 iv
      ON iv.id = fi.item_version_id
    WHERE fi.form_version_id = v_form_id
      AND iv.answer_key_option_id IS NULL;

    IF v_missing_keys <> 0 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'ANSWER_KEY_MISSING',
            'missing_keys', v_missing_keys
        );
    END IF;

    SELECT count(*)
    INTO v_multiple_keys
    FROM public.aicq_form_items_v1 fi
    JOIN public.aicq_item_versions_v1 iv
      ON iv.id = fi.item_version_id
    JOIN public.aicq_item_options_v1 io
      ON io.item_version_id = iv.id
    WHERE fi.form_version_id = v_form_id
      AND io.id = iv.answer_key_option_id;

    IF v_multiple_keys <> 32 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'ANSWER_KEY_INVALID',
            'valid_keys', v_multiple_keys,
            'expected', 32
        );
    END IF;

    -- Ensure positions are exactly 1..32.
    IF EXISTS (
        SELECT 1
        FROM generate_series(1,32) g(position)
        WHERE NOT EXISTS (
            SELECT 1
            FROM public.aicq_form_items_v1 fi
            WHERE fi.form_version_id = v_form_id
              AND fi.position = g.position
        )
    ) THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_POSITION_SEQUENCE_INVALID'
        );
    END IF;

    RETURN jsonb_build_object(
        'ok', true,
        'code', 'FORM_PUBLICATION_READY',
        'form_id', v_form_id,
        'assessment_version_id', v_assessment_version_id,
        'form_status', v_form_status,
        'assessment_status', v_assessment_status,
        'item_count', v_item_count
    );

END;
$function$;

CREATE OR REPLACE FUNCTION public.aicq_validate_form_publication_v1 (
  p_form_version_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_form_code text;
    v_form_version text;
    v_form_status text;
    v_assessment_version_id uuid;

    v_item_count integer;
    v_distinct_item_count integer;
    v_distinct_position_count integer;

    v_unpublished_items integer;
    v_invalid_option_counts integer;
    v_missing_answer_keys integer;
    v_invalid_answer_keys integer;
BEGIN

    IF p_form_version_id IS NULL THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_VERSION_ID_REQUIRED'
        );
    END IF;


    /* --------------------------------------------------------
       Resolve form
       -------------------------------------------------------- */

    SELECT
        fv.form_code,
        fv.version,
        fv.status,
        fv.assessment_version_id
    INTO
        v_form_code,
        v_form_version,
        v_form_status,
        v_assessment_version_id
    FROM public.aicq_form_versions_v1 fv
    WHERE fv.id = p_form_version_id;


    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_NOT_FOUND'
        );
    END IF;


    /* --------------------------------------------------------
       Published forms are immutable.
       A second publication request is not an error in data,
       but it is not permitted to mutate the published object.
       -------------------------------------------------------- */

    IF v_form_status = 'PUBLISHED' THEN
        RETURN jsonb_build_object(
            'ok', true,
            'code', 'ALREADY_PUBLISHED',
            'form_code', v_form_code,
            'form_version', v_form_version
        );
    END IF;


    /* --------------------------------------------------------
       Assessment relationship must exist
       -------------------------------------------------------- */

    IF v_assessment_version_id IS NULL THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_ASSESSMENT_VERSION_REQUIRED',
            'form_code', v_form_code,
            'form_version', v_form_version
        );
    END IF;


    IF NOT EXISTS (
        SELECT 1
        FROM public.aicq_assessment_versions_v1 av
        WHERE av.id = v_assessment_version_id
    ) THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'ASSESSMENT_VERSION_NOT_FOUND',
            'form_code', v_form_code,
            'form_version', v_form_version
        );
    END IF;


    /* --------------------------------------------------------
       Item / position integrity
       -------------------------------------------------------- */

    SELECT COUNT(*)
    INTO v_item_count
    FROM public.aicq_form_items_v1 fi
    WHERE fi.form_version_id = p_form_version_id;


    SELECT COUNT(DISTINCT fi.item_version_id)
    INTO v_distinct_item_count
    FROM public.aicq_form_items_v1 fi
    WHERE fi.form_version_id = p_form_version_id;


    SELECT COUNT(DISTINCT fi.position)
    INTO v_distinct_position_count
    FROM public.aicq_form_items_v1 fi
    WHERE fi.form_version_id = p_form_version_id;


    IF v_item_count <> 32 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_ITEM_COUNT_INVALID',
            'expected', 32,
            'actual', v_item_count,
            'form_code', v_form_code,
            'form_version', v_form_version
        );
    END IF;


    IF v_distinct_item_count <> 32 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_DUPLICATE_ITEMS',
            'expected', 32,
            'actual', v_distinct_item_count
        );
    END IF;


    IF v_distinct_position_count <> 32 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_DUPLICATE_POSITIONS',
            'expected', 32,
            'actual', v_distinct_position_count
        );
    END IF;


    IF EXISTS (
        SELECT 1
        FROM public.aicq_form_items_v1 fi
        WHERE fi.form_version_id = p_form_version_id
          AND fi.position NOT BETWEEN 1 AND 32
    ) THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_POSITION_OUT_OF_RANGE'
        );
    END IF;


    /* --------------------------------------------------------
       Every item version must be PUBLISHED.
       -------------------------------------------------------- */

    SELECT COUNT(*)
    INTO v_unpublished_items
    FROM public.aicq_form_items_v1 fi
    JOIN public.aicq_item_versions_v1 iv
      ON iv.id = fi.item_version_id
    WHERE fi.form_version_id = p_form_version_id
      AND iv.status <> 'PUBLISHED';


    IF v_unpublished_items > 0 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_HAS_UNPUBLISHED_ITEMS',
            'count', v_unpublished_items
        );
    END IF;


    /* --------------------------------------------------------
       Every item must have exactly four options.
       -------------------------------------------------------- */

    SELECT COUNT(*)
    INTO v_invalid_option_counts
    FROM public.aicq_form_items_v1 fi
    JOIN public.aicq_item_versions_v1 iv
      ON iv.id = fi.item_version_id
    LEFT JOIN (
        SELECT
            item_version_id,
            COUNT(*) AS option_count
        FROM public.aicq_item_options_v1
        GROUP BY item_version_id
    ) o
      ON o.item_version_id = iv.id
    WHERE fi.form_version_id = p_form_version_id
      AND COALESCE(o.option_count, 0) <> 4;


    IF v_invalid_option_counts > 0 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_INVALID_OPTION_COUNTS',
            'count', v_invalid_option_counts
        );
    END IF;


    /* --------------------------------------------------------
       Every item must have exactly one valid answer key.
       -------------------------------------------------------- */

    SELECT COUNT(*)
    INTO v_missing_answer_keys
    FROM public.aicq_form_items_v1 fi
    JOIN public.aicq_item_versions_v1 iv
      ON iv.id = fi.item_version_id
    WHERE fi.form_version_id = p_form_version_id
      AND iv.answer_key_option_id IS NULL;


    IF v_missing_answer_keys > 0 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_MISSING_ANSWER_KEYS',
            'count', v_missing_answer_keys
        );
    END IF;


    SELECT COUNT(*)
    INTO v_invalid_answer_keys
    FROM public.aicq_form_items_v1 fi
    JOIN public.aicq_item_versions_v1 iv
      ON iv.id = fi.item_version_id
    LEFT JOIN public.aicq_item_options_v1 io
      ON io.id = iv.answer_key_option_id
     AND io.item_version_id = iv.id
    WHERE fi.form_version_id = p_form_version_id
      AND io.id IS NULL;


    IF v_invalid_answer_keys > 0 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_INVALID_ANSWER_KEYS',
            'count', v_invalid_answer_keys
        );
    END IF;


    /* --------------------------------------------------------
       All publication gates passed.
       -------------------------------------------------------- */

    RETURN jsonb_build_object(
        'ok', true,
        'code', 'FORM_PUBLICATION_READY',
        'form_code', v_form_code,
        'form_version', v_form_version,
        'item_count', v_item_count,
        'assessment_version_id', v_assessment_version_id
    );

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_validate_form_publication_v1"(text, text) TO "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."aicq_validate_form_publication_v1"(uuid) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_validate_form_publication_v1"(text, text) FROM PUBLIC;

REVOKE ALL ON FUNCTION "public"."aicq_validate_form_publication_v1"(uuid) FROM PUBLIC;
