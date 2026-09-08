CREATE OR REPLACE FUNCTION public.aicq_get_attempt_item_v1 (
  p_attempt_id uuid,
  p_position   integer
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_item_id uuid;
  v_item_code text;
  v_item_version text;
  v_stem text;
  v_existing_order jsonb;
  v_options jsonb;
BEGIN

  SELECT
    iv.id,
    iv.item_code,
    iv.version,
    iv.stem
  INTO
    v_item_id,
    v_item_code,
    v_item_version,
    v_stem
  FROM public.aicq_attempts_v1 a
  JOIN public.aicq_form_versions_v1 fv
    ON fv.id = a.form_version_id
  JOIN public.aicq_form_items_v1 fi
    ON fi.form_version_id = fv.id
   AND fi.position = p_position
  JOIN public.aicq_item_versions_v1 iv
    ON iv.id = fi.item_version_id
  WHERE a.id = p_attempt_id
    AND fv.status = 'PUBLISHED'
    AND iv.status = 'PUBLISHED';

  IF v_item_id IS NULL THEN
    RAISE EXCEPTION 'ITEM_NOT_FOUND';
  END IF;

  /*
   * Reuse the presentation order if this item has already
   * been delivered for this attempt.
   */
  SELECT rp.option_order
  INTO v_existing_order
  FROM public.aicq_response_presentations_v1 rp
  WHERE rp.attempt_id = p_attempt_id
    AND rp.item_version_id = v_item_id
  LIMIT 1;

  IF v_existing_order IS NOT NULL THEN

    SELECT jsonb_agg(
      jsonb_build_object(
        'id', io.id,
        'code', io.option_code,
        'text', io.option_text
      )
      ORDER BY array_position(
        ARRAY(
          SELECT jsonb_array_elements_text(v_existing_order)
        ),
        io.id::text
      )
    )
    INTO v_options
    FROM public.aicq_item_options_v1 io
    WHERE io.item_version_id = v_item_id;

  ELSE

    /*
     * First delivery:
     * cryptographically unpredictable database-side ordering.
     * The answer key is never returned.
     */
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', io.id,
        'code', io.option_code,
        'text', io.option_text
      )
      ORDER BY gen_random_uuid()
    )
    INTO v_options
    FROM public.aicq_item_options_v1 io
    WHERE io.item_version_id = v_item_id;

    /*
     * Persist the exact presented order so that the evidence
     * record remains reproducible.
     */
    INSERT INTO public.aicq_response_presentations_v1 (
      attempt_id,
      item_version_id,
      presentation_sequence,
      option_order,
      displayed_at
    )
    VALUES (
      p_attempt_id,
      v_item_id,
      p_position,
      (
        SELECT jsonb_agg(
          io.id
          ORDER BY gen_random_uuid()
        )
        FROM public.aicq_item_options_v1 io
        WHERE io.item_version_id = v_item_id
      ),
      now()
    )
    ON CONFLICT (attempt_id, item_version_id)
    DO NOTHING;

    /*
     * If the insert raced another request, retrieve the
     * authoritative stored presentation order.
     */
    SELECT rp.option_order
    INTO v_existing_order
    FROM public.aicq_response_presentations_v1 rp
    WHERE rp.attempt_id = p_attempt_id
      AND rp.item_version_id = v_item_id
    LIMIT 1;

    IF v_existing_order IS NOT NULL THEN
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', io.id,
          'code', io.option_code,
          'text', io.option_text
        )
        ORDER BY array_position(
          ARRAY(
            SELECT jsonb_array_elements_text(v_existing_order)
          ),
          io.id::text
        )
      )
      INTO v_options
      FROM public.aicq_item_options_v1 io
      WHERE io.item_version_id = v_item_id;
    END IF;

  END IF;

  RETURN jsonb_build_object(
    'item_id', v_item_code,
    'item_version', v_item_version,
    'item_version_id', v_item_id,
    'position', p_position,
    'stem', v_stem,
    'options', COALESCE(v_options, '[]'::jsonb)
  );

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_get_attempt_item_v1"(uuid, integer) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_get_attempt_item_v1"(uuid, integer) FROM PUBLIC;
