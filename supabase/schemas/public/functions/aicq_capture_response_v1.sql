CREATE OR REPLACE FUNCTION public.aicq_capture_response_v1 (
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
    v_response_id UUID;
    v_presentation_exists BOOLEAN;
BEGIN

    /*
     * --------------------------------------------------------
     * 1. Attempt must still be active.
     * --------------------------------------------------------
     */

    IF NOT EXISTS (
        SELECT 1
        FROM public.aicq_attempts_v1
        WHERE id = p_attempt_id
          AND status IN (
              'STARTED',
              'IN_PROGRESS',
              'PAUSED'
          )
    ) THEN

        RAISE EXCEPTION
            'ATTEMPT_NOT_ACTIVE';

    END IF;


    /*
     * --------------------------------------------------------
     * 2. Item must belong to the attempt's published form.
     * --------------------------------------------------------
     */

    IF NOT EXISTS (
        SELECT 1
        FROM public.aicq_form_items_v1 fi

        JOIN public.aicq_attempts_v1 a
          ON a.form_version_id =
             fi.form_version_id

        JOIN public.aicq_form_versions_v1 fv
          ON fv.id =
             a.form_version_id

        WHERE a.id =
              p_attempt_id

          AND fi.item_version_id =
              p_item_version_id

          AND fv.status =
              'PUBLISHED'
    ) THEN

        RAISE EXCEPTION
            'ITEM_NOT_IN_ATTEMPT';

    END IF;


    /*
     * --------------------------------------------------------
     * 3. Non-skipped response requires an option.
     * --------------------------------------------------------
     */

    IF NOT p_skipped
       AND p_selected_option_id IS NULL THEN

        RAISE EXCEPTION
            'OPTION_REQUIRED';

    END IF;


    /*
     * --------------------------------------------------------
     * 4. If an option was selected, verify that the option
     *    belongs to this exact item version.
     *
     *    This prevents submitting an arbitrary UUID.
     * --------------------------------------------------------
     */

    IF NOT p_skipped THEN

        IF NOT EXISTS (
            SELECT 1
            FROM public.aicq_item_options_v1 io
            WHERE io.id =
                  p_selected_option_id

              AND io.item_version_id =
                  p_item_version_id
        ) THEN

            RAISE EXCEPTION
                'OPTION_NOT_IN_ITEM';

        END IF;

    END IF;


    /*
     * --------------------------------------------------------
     * 5. The presentation MUST already exist.
     *
     *    It is created by aicq_get_attempt_item_v1().
     *
     *    The browser is NOT trusted to create or modify it.
     * --------------------------------------------------------
     */

    SELECT EXISTS (
        SELECT 1
        FROM public.aicq_response_presentations_v1 rp
        WHERE rp.attempt_id =
              p_attempt_id

          AND rp.item_version_id =
              p_item_version_id
    )
    INTO v_presentation_exists;


    IF NOT v_presentation_exists THEN

        RAISE EXCEPTION
            'PRESENTATION_NOT_FOUND';

    END IF;


    /*
     * --------------------------------------------------------
     * 6. Store raw response evidence.
     *
     *    IMPORTANT:
     *
     *    No correctness calculation occurs here.
     *
     *    No answer key is exposed.
     * --------------------------------------------------------
     */

    INSERT INTO public.aicq_responses_v1 (
        attempt_id,
        item_version_id,
        selected_option_id,
        skipped,
        response_time_ms
    )
    VALUES (
        p_attempt_id,
        p_item_version_id,
        p_selected_option_id,
        p_skipped,
        p_response_time_ms
    )

    ON CONFLICT (
        attempt_id,
        item_version_id
    )

    DO UPDATE SET

        selected_option_id =
            excluded.selected_option_id,

        skipped =
            excluded.skipped,

        response_time_ms =
            excluded.response_time_ms,

        answered_at =
            now()

    RETURNING id
    INTO v_response_id;


    /*
     * --------------------------------------------------------
     * 7. DO NOT update response_presentations_v1 here.
     *
     *    The server-generated presentation is authoritative.
     *
     *    The following browser-controlled values are
     *    intentionally ignored:
     *
     *      p_presentation_sequence
     *      p_option_order
     * --------------------------------------------------------
     */


    RETURN jsonb_build_object(
        'response_id',
        v_response_id,

        'accepted',
        true
    );

END;

$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_capture_response_v1"(uuid, uuid, uuid, boolean, integer, integer, jsonb) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_capture_response_v1"(uuid, uuid, uuid, boolean, integer, integer, jsonb) FROM PUBLIC;
