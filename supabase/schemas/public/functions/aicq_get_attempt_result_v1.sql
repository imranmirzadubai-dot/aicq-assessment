CREATE OR REPLACE FUNCTION public.aicq_get_attempt_result_v1 (
  p_attempt_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_result jsonb;
BEGIN

    SELECT jsonb_build_object(
        'ok', true,
        'attempt_id', e.attempt_id,
        'evidence_result_id', e.id,
        'scoring_version', e.scoring_version,
        'knowledge_score', e.knowledge_score,
        'practical_score', e.practical_score,
        'overall_score', e.overall_score,
        'confidence_signal', e.confidence_signal,
        'competencies',
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'competency_id', cr.competency_id,
                        'competency_code', c.code,
                        'competency_name', c.name,
                        'score', cr.score,
                        'items_answered', cr.items_answered,
                        'evidence_count', cr.evidence_count
                    )
                    ORDER BY c.code
                )
                FROM public.aicq_competency_results_v1 cr
                JOIN public.aicq_competencies_v1 c
                  ON c.id = cr.competency_id
                WHERE cr.evidence_result_id = e.id
            ),
            '[]'::jsonb
        ),
        'calculation_metadata', e.calculation_metadata,
        'created_at', e.created_at
    )
    INTO v_result
    FROM public.aicq_evidence_results_v1 e
    WHERE e.attempt_id = p_attempt_id
    ORDER BY e.created_at DESC
    LIMIT 1;


    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'RESULT_NOT_AVAILABLE',
            'attempt_id', p_attempt_id
        );
    END IF;


    RETURN v_result;

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_get_attempt_result_v1"(uuid) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_get_attempt_result_v1"(uuid) FROM PUBLIC;
