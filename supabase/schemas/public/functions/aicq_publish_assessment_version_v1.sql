CREATE OR REPLACE FUNCTION public.aicq_publish_assessment_version_v1 (
  p_assessment_code    text,
  p_assessment_version text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_validation jsonb;
    v_definition_id uuid;
    v_version_id uuid;
BEGIN

    SELECT ad.id
    INTO v_definition_id
    FROM public.aicq_assessment_definitions ad
    WHERE ad.assessment_code = p_assessment_code;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ASSESSMENT_NOT_FOUND';
    END IF;


    SELECT av.id
    INTO v_version_id
    FROM public.aicq_assessment_versions_v1 av
    WHERE av.assessment_definition_id = v_definition_id
      AND av.version = p_assessment_version
    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'ASSESSMENT_VERSION_NOT_FOUND';
    END IF;


    v_validation :=
        public.aicq_validate_assessment_publication_v1(
            p_assessment_code,
            p_assessment_version
        );


    IF COALESCE(
        (v_validation->>'ok')::boolean,
        false
    ) = false THEN

        RAISE EXCEPTION '%',
            COALESCE(
                v_validation->>'code',
                'ASSESSMENT_PUBLICATION_VALIDATION_FAILED'
            );

    END IF;


    UPDATE public.aicq_assessment_versions_v1
    SET status = 'PUBLISHED'
    WHERE id = v_version_id;


    RETURN jsonb_build_object(
        'ok', true,
        'code', 'ASSESSMENT_VERSION_PUBLISHED',
        'assessment_version_id', v_version_id,
        'assessment_code', p_assessment_code,
        'assessment_version', p_assessment_version
    );

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_publish_assessment_version_v1"(text, text) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_publish_assessment_version_v1"(text, text) FROM PUBLIC;
