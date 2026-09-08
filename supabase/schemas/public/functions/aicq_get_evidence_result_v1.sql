CREATE OR REPLACE FUNCTION public.aicq_get_evidence_result_v1 (
  p_attempt_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_evidence jsonb;
  v_competencies jsonb;
  v_interpretation jsonb;
  v_development jsonb;
BEGIN
  SELECT jsonb_build_object(
    'id', er.id,
    'attempt_id', er.attempt_id,
    'scoring_version', er.scoring_version,
    'knowledge_score', er.knowledge_score,
    'practical_score', er.practical_score,
    'overall_score', er.overall_score,
    'confidence_signal', er.confidence_signal,
    'calculation_metadata', er.calculation_metadata
  )
  INTO v_evidence
  FROM public.aicq_evidence_results_v1 er
  WHERE er.attempt_id = p_attempt_id
  ORDER BY er.created_at DESC
  LIMIT 1;

  IF v_evidence IS NULL THEN
    RETURN jsonb_build_object(
      'status','NOT_READY',
      'attempt_id',p_attempt_id
    );
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'competency_id', cr.competency_id,
        'code', c.code,
        'name', c.name,
        'score', cr.score,
        'items_answered', cr.items_answered,
        'evidence_count', cr.evidence_count,
        'metadata', cr.metadata
      ) ORDER BY c.code
    ),
    '[]'::jsonb
  )
  INTO v_competencies
  FROM public.aicq_competency_results_v1 cr
  JOIN public.aicq_competencies_v1 c
    ON c.id = cr.competency_id
  WHERE cr.evidence_result_id = (v_evidence->>'id')::uuid;

  SELECT jsonb_build_object(
    'interpretation_version', i.interpretation_version,
    'strengths', i.strengths,
    'opportunities', i.opportunities,
    'priority_patterns', i.priority_patterns,
    'evidence_notes', i.evidence_notes
  )
  INTO v_interpretation
  FROM public.aicq_interpretations_v1 i
  WHERE i.attempt_id = p_attempt_id
  ORDER BY i.created_at DESC
  LIMIT 1;

  SELECT jsonb_build_object(
    'development_version', dp.development_version,
    'actions', COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'priority', da.priority,
            'competency_id', da.competency_id,
            'learning_objective', da.learning_objective,
            'sequence', da.sequence,
            'practice_activity', da.practice_activity,
            'application_activity', da.application_activity,
            'control_activity', da.control_activity,
            'reassessment_activity', da.reassessment_activity
          ) ORDER BY da.priority
        )
        FROM public.aicq_development_actions_v1 da
        WHERE da.development_plan_id = dp.id
      ),
      '[]'::jsonb
    )
  )
  INTO v_development
  FROM public.aicq_development_plans_v1 dp
  WHERE dp.attempt_id = p_attempt_id
  ORDER BY dp.created_at DESC
  LIMIT 1;

  RETURN jsonb_build_object(
    'status','COMPLETED',
    'evidence',v_evidence,
    'competencies',v_competencies,
    'interpretation',COALESCE(v_interpretation,'{}'::jsonb),
    'development',COALESCE(v_development,'{}'::jsonb)
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_get_evidence_result_v1"(uuid) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_get_evidence_result_v1"(uuid) FROM PUBLIC;
