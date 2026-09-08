CREATE OR REPLACE FUNCTION public.aicq_record_confidence_v1 (
  p_attempt_id      uuid,
  p_item_version_id uuid,
  p_confidence      numeric
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_attempt_status text;
    v_id uuid;
BEGIN

    IF p_attempt_id IS NULL
       OR p_item_version_id IS NULL THEN
        RAISE EXCEPTION 'CONFIDENCE_IDENTIFIERS_REQUIRED';
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


    /* Pilot confidence scale: 1–5. */

    IF p_confidence IS NULL
       OR p_confidence < 1
       OR p_confidence > 5 THEN
        RAISE EXCEPTION 'CONFIDENCE_OUT_OF_RANGE';
    END IF;


    IF NOT EXISTS (
        SELECT 1
        FROM public.aicq_responses_v1 r
        WHERE r.attempt_id = p_attempt_id
          AND r.item_version_id = p_item_version_id
    ) THEN
        RAISE EXCEPTION 'CONFIDENCE_REQUIRES_RESPONSE';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM public.aicq_confidence_responses_v1 c
        WHERE c.attempt_id = p_attempt_id
          AND c.item_version_id = p_item_version_id
    ) THEN
        RAISE EXCEPTION 'CONFIDENCE_ALREADY_RECORDED';
    END IF;


    INSERT INTO public.aicq_confidence_responses_v1 (
        attempt_id,
        item_version_id,
        confidence_value,
        recorded_at
    )
    VALUES (
        p_attempt_id,
        p_item_version_id,
        p_confidence,
        now()
    )
    RETURNING id
    INTO v_id;


    RETURN jsonb_build_object(
        'ok', true,
        'code', 'CONFIDENCE_RECORDED',
        'confidence_response_id', v_id,
        'attempt_id', p_attempt_id,
        'item_version_id', p_item_version_id
    );

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_record_confidence_v1"(uuid, uuid, numeric) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_record_confidence_v1"(uuid, uuid, numeric) FROM PUBLIC;
