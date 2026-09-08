CREATE OR REPLACE FUNCTION public.aicq_publish_form_v1 (
  p_form_code    text,
  p_form_version text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_validation jsonb;
    v_form_id uuid;
    v_now timestamptz := now();
    v_published_items integer;
BEGIN

    -- Lock the form row during publication.
    SELECT fv.id
    INTO v_form_id
    FROM public.aicq_form_versions_v1 fv
    WHERE fv.form_code = p_form_code
      AND fv.version = p_form_version
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'FORM_NOT_FOUND';
    END IF;

    -- Idempotent behavior.
    IF EXISTS (
        SELECT 1
        FROM public.aicq_form_versions_v1
        WHERE id = v_form_id
          AND status = 'PUBLISHED'
    ) THEN
        RETURN jsonb_build_object(
            'ok', true,
            'code', 'ALREADY_PUBLISHED',
            'form_id', v_form_id
        );
    END IF;

    -- --------------------------------------------------------
    -- Publish the exact item versions belonging to this form.
    -- They are still subject to all structural checks below.
    -- --------------------------------------------------------

    UPDATE public.aicq_item_versions_v1 iv
    SET status = 'PUBLISHED'
    WHERE iv.id IN (
        SELECT fi.item_version_id
        FROM public.aicq_form_items_v1 fi
        WHERE fi.form_version_id = v_form_id
    )
      AND iv.status IN ('DRAFT','REVIEW','APPROVED');

    GET DIAGNOSTICS v_published_items = ROW_COUNT;

    -- --------------------------------------------------------
    -- Re-run the full gate AFTER item publication.
    -- --------------------------------------------------------

    v_validation :=
        public.aicq_validate_form_publication_v1(
            p_form_code,
            p_form_version
        );

    IF COALESCE((v_validation->>'ok')::boolean, false) = false THEN
        RAISE EXCEPTION '%',
            COALESCE(
                v_validation->>'code',
                'FORM_PUBLICATION_VALIDATION_FAILED'
            );
    END IF;

    UPDATE public.aicq_form_versions_v1
    SET
        status = 'PUBLISHED',
        published_at = COALESCE(published_at, v_now)
    WHERE id = v_form_id;

    RETURN jsonb_build_object(
        'ok', true,
        'code', 'FORM_PUBLISHED',
        'form_id', v_form_id,
        'form_code', p_form_code,
        'form_version', p_form_version,
        'published_items', v_published_items,
        'published_at', v_now
    );

END;
$function$;

CREATE OR REPLACE FUNCTION public.aicq_publish_form_v1 (
  p_form_version_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_validation jsonb;
    v_status text;
    v_published_at timestamptz;
BEGIN

    IF p_form_version_id IS NULL THEN
        RAISE EXCEPTION 'FORM_VERSION_ID_REQUIRED';
    END IF;


    /* Lock the form row so publication cannot race. */

    SELECT fv.status
    INTO v_status
    FROM public.aicq_form_versions_v1 fv
    WHERE fv.id = p_form_version_id
    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'FORM_NOT_FOUND';
    END IF;


    IF v_status = 'PUBLISHED' THEN
        SELECT fv.published_at
        INTO v_published_at
        FROM public.aicq_form_versions_v1 fv
        WHERE fv.id = p_form_version_id;

        RETURN jsonb_build_object(
            'ok', true,
            'code', 'ALREADY_PUBLISHED',
            'form_version_id', p_form_version_id,
            'published_at', v_published_at
        );
    END IF;


    /* Run complete publication gate. */

    v_validation :=
        public.aicq_validate_form_publication_v1(
            p_form_version_id
        );


    IF COALESCE((v_validation->>'ok')::boolean, false) = false THEN
        RAISE EXCEPTION '%',
            COALESCE(
                v_validation->>'code',
                'FORM_PUBLICATION_BLOCKED'
            );
    END IF;


    /* Publish atomically. */

    UPDATE public.aicq_form_versions_v1
    SET
        status = 'PUBLISHED',
        published_at = COALESCE(published_at, now())
    WHERE id = p_form_version_id
    RETURNING published_at
    INTO v_published_at;


    RETURN jsonb_build_object(
        'ok', true,
        'code', 'FORM_PUBLISHED',
        'form_version_id', p_form_version_id,
        'published_at', v_published_at
    );

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_publish_form_v1"(text, text) TO "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."aicq_publish_form_v1"(uuid) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_publish_form_v1"(text, text) FROM PUBLIC;

REVOKE ALL ON FUNCTION "public"."aicq_publish_form_v1"(uuid) FROM PUBLIC;
