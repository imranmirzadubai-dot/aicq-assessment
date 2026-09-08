CREATE OR REPLACE FUNCTION public.aicq_record_response_v1 (
  p_attempt_id            uuid,
  p_item_version_id       uuid,
  p_selected_option_id    uuid,
  p_skipped               boolean DEFAULT false,
  p_response_time_ms      integer DEFAULT NULL::integer,
  p_presentation_sequence integer DEFAULT NULL::integer,
  p_option_order          jsonb   DEFAULT NULL::jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_attempt_status text;
    v_item_status text;
    v_form_id uuid;
    v_item_in_form boolean;
    v_response_id uuid;
BEGIN

    IF p_attempt_id IS NULL THEN
        RAISE EXCEPTION 'ATTEMPT_ID_REQUIRED';
    END IF;

    IF p_item_version_id IS NULL THEN
        RAISE EXCEPTION 'ITEM_VERSION_ID_REQUIRED';
    END IF;


    /* --------------------------------------------------------
       Attempt must still be active.
       -------------------------------------------------------- */

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


    /* --------------------------------------------------------
       Item must be published.
       -------------------------------------------------------- */

    SELECT status
    INTO v_item_status
    FROM public.aicq_item_versions_v1
    WHERE id = p_item_version_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ITEM_VERSION_NOT_FOUND';
    END IF;

    IF v_item_status <> 'PUBLISHED' THEN
        RAISE EXCEPTION 'ITEM_VERSION_NOT_PUBLISHED';
    END IF;


    /* --------------------------------------------------------
       Item must belong to the attempt's published form.
       -------------------------------------------------------- */

    SELECT a.form_version_id
    INTO v_form_id
    FROM public.aicq_attempts_v1 a
    WHERE a.id = p_attempt_id;

    SELECT EXISTS (
        SELECT 1
        FROM public.aicq_form_items_v1 fi
        JOIN public.aicq_form_versions_v1 fv
          ON fv.id = fi.form_version_id
        WHERE fi.form_version_id = v_form_id
          AND fi.item_version_id = p_item_version_id
          AND fv.status = 'PUBLISHED'
    )
    INTO v_item_in_form;

    IF NOT v_item_in_form THEN
        RAISE EXCEPTION 'ITEM_NOT_IN_ATTEMPT_FORM';
    END IF;


    /* --------------------------------------------------------
       Selected option must belong to the item.
       Skipped responses have no selected option.
       -------------------------------------------------------- */

    IF p_skipped = false THEN

        IF p_selected_option_id IS NULL THEN
            RAISE EXCEPTION 'SELECTED_OPTION_REQUIRED';
        END IF;

        IF NOT EXISTS (
            SELECT 1
            FROM public.aicq_item_options_v1 io
            WHERE io.id = p_selected_option_id
              AND io.item_version_id = p_item_version_id
        ) THEN
            RAISE EXCEPTION 'OPTION_NOT_IN_ITEM';
        END IF;

    END IF;


    IF p_response_time_ms IS NOT NULL
       AND p_response_time_ms < 0 THEN
        RAISE EXCEPTION 'INVALID_RESPONSE_TIME';
    END IF;


    /* --------------------------------------------------------
       Raw responses are immutable.
       Duplicate item response is rejected.
       -------------------------------------------------------- */

    IF EXISTS (
        SELECT 1
        FROM public.aicq_responses_v1 r
        WHERE r.attempt_id = p_attempt_id
          AND r.item_version_id = p_item_version_id
    ) THEN
        RAISE EXCEPTION 'RESPONSE_ALREADY_RECORDED';
    END IF;


    INSERT INTO public.aicq_responses_v1 (
        attempt_id,
        item_version_id,
        selected_option_id,
        skipped,
        response_time_ms,
        answered_at
    )
    VALUES (
        p_attempt_id,
        p_item_version_id,
        CASE
            WHEN p_skipped THEN NULL
            ELSE p_selected_option_id
        END,
        COALESCE(p_skipped, false),
        p_response_time_ms,
        now()
    )
    RETURNING id
    INTO v_response_id;


    /* --------------------------------------------------------
       Presentation is stored separately.
       -------------------------------------------------------- */

    IF p_presentation_sequence IS NOT NULL
       OR p_option_order IS NOT NULL THEN

        INSERT INTO public.aicq_response_presentations_v1 (
            attempt_id,
            item_version_id,
            presentation_sequence,
            option_order,
            displayed_at
        )
        VALUES (
            p_attempt_id,
            p_item_version_id,
            p_presentation_sequence,
            p_option_order,
            now()
        )
        ON CONFLICT (
            attempt_id,
            item_version_id
        )
        DO NOTHING;

    END IF;


    RETURN jsonb_build_object(
        'ok', true,
        'code', 'RESPONSE_RECORDED',
        'response_id', v_response_id,
        'attempt_id', p_attempt_id,
        'item_version_id', p_item_version_id
    );

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_record_response_v1"(uuid, uuid, uuid, boolean, integer, integer, jsonb) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_record_response_v1"(uuid, uuid, uuid, boolean, integer, integer, jsonb) FROM PUBLIC;
