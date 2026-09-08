CREATE OR REPLACE FUNCTION public.aicq_validate_assessment_publication_v1 (
  p_assessment_code    text,
  p_assessment_version text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_definition_id uuid;
    v_version_id uuid;
    v_status text;
    v_framework_version text;

    v_form_count integer;
    v_form_id uuid;
    v_form_code text;
    v_form_version text;
    v_form_status text;
BEGIN

    -- --------------------------------------------------------
    -- Resolve assessment definition
    -- --------------------------------------------------------

    SELECT ad.id
    INTO v_definition_id
    FROM public.aicq_assessment_definitions ad
    WHERE ad.assessment_code = p_assessment_code;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'ASSESSMENT_NOT_FOUND'
        );
    END IF;


    -- --------------------------------------------------------
    -- Resolve exact assessment version
    -- --------------------------------------------------------

    SELECT
        av.id,
        av.status,
        av.framework_version
    INTO
        v_version_id,
        v_status,
        v_framework_version
    FROM public.aicq_assessment_versions_v1 av
    WHERE av.assessment_definition_id = v_definition_id
      AND av.version = p_assessment_version;


    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'ASSESSMENT_VERSION_NOT_FOUND'
        );
    END IF;


    -- --------------------------------------------------------
    -- Already published = valid/idempotent
    -- --------------------------------------------------------

    IF v_status = 'PUBLISHED' THEN
        RETURN jsonb_build_object(
            'ok', true,
            'code', 'ALREADY_PUBLISHED',
            'assessment_version_id', v_version_id
        );
    END IF;


    -- --------------------------------------------------------
    -- Valid lifecycle states
    -- --------------------------------------------------------

    IF v_status NOT IN ('DRAFT','REVIEW','APPROVED') THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'ASSESSMENT_VERSION_NOT_PUBLISHABLE',
            'status', v_status
        );
    END IF;


    -- --------------------------------------------------------
    -- Framework reference required
    -- --------------------------------------------------------

    IF v_framework_version IS NULL
       OR trim(v_framework_version) = '' THEN

        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FRAMEWORK_VERSION_REQUIRED'
        );

    END IF;


    -- --------------------------------------------------------
    -- Resolve forms using the REAL relationship.
    --
    -- Do NOT use assessment_versions.form_version as a join
    -- key. The authoritative relationship is:
    --
    -- form_versions.assessment_version_id
    --             ↓
    -- assessment_versions.id
    -- --------------------------------------------------------

    SELECT count(*)
    INTO v_form_count
    FROM public.aicq_form_versions_v1 fv
    WHERE fv.assessment_version_id = v_version_id;


    IF v_form_count = 0 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'FORM_VERSION_NOT_FOUND',
            'assessment_version_id', v_version_id
        );
    END IF;


    -- An assessment version must not ambiguously point to
    -- multiple forms in this Pilot 1 publication model.
    IF v_form_count > 1 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'MULTIPLE_FORMS_FOR_ASSESSMENT_VERSION',
            'assessment_version_id', v_version_id,
            'form_count', v_form_count
        );
    END IF;


    SELECT
        fv.id,
        fv.form_code,
        fv.version,
        fv.status
    INTO
        v_form_id,
        v_form_code,
        v_form_version,
        v_form_status
    FROM public.aicq_form_versions_v1 fv
    WHERE fv.assessment_version_id = v_version_id;


    -- --------------------------------------------------------
    -- Assessment publication does not require the form to
    -- already be published.
    --
    -- Correct dependency:
    --
    -- Assessment Version PUBLISHED
    --          ↓
    -- Form Version PUBLISHED
    --          ↓
    -- Item Versions PUBLISHED
    -- --------------------------------------------------------

    RETURN jsonb_build_object(
        'ok', true,
        'code', 'ASSESSMENT_PUBLICATION_READY',
        'assessment_version_id', v_version_id,
        'assessment_status', v_status,
        'framework_version', v_framework_version,
        'form_id', v_form_id,
        'form_code', v_form_code,
        'form_version', v_form_version,
        'form_status', v_form_status
    );

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_validate_assessment_publication_v1"(text, text) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_validate_assessment_publication_v1"(text, text) FROM PUBLIC;
