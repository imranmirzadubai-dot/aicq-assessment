CREATE OR REPLACE FUNCTION public.aicq_score_attempt_v1 (
  p_attempt_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_attempt public.aicq_attempts_v1%ROWTYPE;

    v_evidence_id uuid;

    v_correct integer;
    v_answered integer;
    v_total integer;

    v_knowledge numeric;
    v_practical numeric;

    v_confidence numeric;

    v_overall numeric;

    v_scoring_version text :=
        'evidence-weighted-v3-kendall-practical';

    r RECORD;

    v_competency_score numeric;
    v_competency_result_id uuid;

    v_practical_submission_id uuid;
BEGIN

    SELECT *
    INTO v_attempt
    FROM public.aicq_attempts_v1
    WHERE id = p_attempt_id
    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'ATTEMPT_NOT_FOUND';
    END IF;


    IF v_attempt.status NOT IN (
        'SUBMITTED',
        'PROCESSING',
        'COMPLETED'
    ) THEN
        RAISE EXCEPTION 'ATTEMPT_NOT_READY_FOR_SCORING';
    END IF;


    /* --------------------------------------------------------
       Do not overwrite an existing authoritative evidence
       result.
       -------------------------------------------------------- */

    SELECT id
    INTO v_evidence_id
    FROM public.aicq_evidence_results_v1
    WHERE attempt_id = p_attempt_id
    ORDER BY created_at DESC
    LIMIT 1;


    IF v_evidence_id IS NOT NULL THEN

        SELECT
            jsonb_build_object(
                'ok', true,
                'code', 'ALREADY_SCORED',
                'attempt_id', p_attempt_id,
                'evidence_result_id', id,
                'knowledge_score', knowledge_score,
                'practical_score', practical_score,
                'overall_score', overall_score,
                'confidence_signal', confidence_signal,
                'scoring_version', scoring_version
            )
        INTO r
        FROM public.aicq_evidence_results_v1
        WHERE id = v_evidence_id;

        RETURN r;

    END IF;


    /* --------------------------------------------------------
       Knowledge/scenario score.
       Pilot rule:
       32 fixed F01 items.
       Skipped items contribute zero.
       -------------------------------------------------------- */

    SELECT COUNT(*)
    INTO v_total
    FROM public.aicq_form_items_v1 fi
    WHERE fi.form_version_id = v_attempt.form_version_id;


    SELECT COUNT(*)
    INTO v_answered
    FROM public.aicq_responses_v1 r
    WHERE r.attempt_id = p_attempt_id
      AND r.skipped = false;


    SELECT COUNT(*)
    INTO v_correct
    FROM public.aicq_responses_v1 r
    JOIN public.aicq_item_versions_v1 iv
      ON iv.id = r.item_version_id
    WHERE r.attempt_id = p_attempt_id
      AND r.skipped = false
      AND r.selected_option_id = iv.answer_key_option_id;


    IF v_total = 0 THEN
        RAISE EXCEPTION 'FORM_HAS_NO_ITEMS';
    END IF;


    v_knowledge :=
        ROUND(
            (
                v_correct::numeric
                / v_total::numeric
            ) * 100,
            2
        );


    /* --------------------------------------------------------
       Practical score.
       -------------------------------------------------------- */

    SELECT ps.id
    INTO v_practical_submission_id
    FROM public.aicq_practical_submissions_v1 ps
    WHERE ps.attempt_id = p_attempt_id
    ORDER BY ps.submitted_at DESC
    LIMIT 1;


    IF v_practical_submission_id IS NOT NULL THEN

        v_practical :=
            public.aicq_score_practical_v1(
                v_practical_submission_id
            );

    ELSE

        v_practical := 0;

    END IF;


    /* --------------------------------------------------------
       Confidence signal.
       Mean 1–5 converted to 0–100.

       IMPORTANT:
       It is descriptive only.
       It does not enter v_overall.
       -------------------------------------------------------- */

    SELECT
        ROUND(
            (
                AVG(c.confidence_value) / 5
            ) * 100,
            2
        )
    INTO v_confidence
    FROM public.aicq_confidence_responses_v1 c
    WHERE c.attempt_id = p_attempt_id;


    /* --------------------------------------------------------
       Provisional composite.
       70% knowledge + 30% practical.

       This remains a PILOT composite and is not a validated
       proficiency scale.
       -------------------------------------------------------- */

    v_overall :=
        ROUND(
            (
                v_knowledge * 0.70
            )
            +
            (
                v_practical * 0.30
            ),
            2
        );


    /* --------------------------------------------------------
       Evidence Result.
       -------------------------------------------------------- */

    INSERT INTO public.aicq_evidence_results_v1 (
        attempt_id,
        scoring_version,
        knowledge_score,
        practical_score,
        overall_score,
        confidence_signal,
        calculation_metadata,
        created_at
    )
    VALUES (
        p_attempt_id,
        v_scoring_version,
        v_knowledge,
        v_practical,
        v_overall,
        v_confidence,
        jsonb_build_object(
            'measurement_status',
            'PILOT_PROVISIONAL',

            'knowledge_rule',
            'correct_responses_divided_by_form_item_count',

            'knowledge_total_items',
            v_total,

            'knowledge_answered',
            v_answered,

            'knowledge_correct',
            v_correct,

            'practical_rule',
            'pairwise_precedence_agreement',

            'practical_scoring_model',
            'evidence-weighted-v3-kendall-practical',

            'knowledge_weight',
            0.70,

            'practical_weight',
            0.30,

            'confidence_is_score_modifier',
            false
        ),
        now()
    )
    RETURNING id
    INTO v_evidence_id;


    /* --------------------------------------------------------
       Competency results.
       Each F01 competency contains four items.
       Score = correct / form items assigned to competency.
       -------------------------------------------------------- */

    FOR r IN
        SELECT
            c.id AS competency_id,
            c.code AS competency_code,
            COUNT(fi.item_version_id) AS competency_items
        FROM public.aicq_form_items_v1 fi
        JOIN public.aicq_item_versions_v1 iv
          ON iv.id = fi.item_version_id
        JOIN public.aicq_sub_competencies_v1 sc
          ON sc.id = iv.sub_competency_id
        JOIN public.aicq_competencies_v1 c
          ON c.id = sc.competency_id
        WHERE fi.form_version_id = v_attempt.form_version_id
        GROUP BY c.id, c.code
        ORDER BY c.code
    LOOP

        SELECT
            ROUND(
                (
                    COUNT(*) FILTER (
                        WHERE r2.skipped = false
                          AND r2.selected_option_id =
                              iv2.answer_key_option_id
                    )::numeric
                    /
                    r.competency_items::numeric
                ) * 100,
                2
            )
        INTO v_competency_score
        FROM public.aicq_form_items_v1 fi2
        JOIN public.aicq_item_versions_v1 iv2
          ON iv2.id = fi2.item_version_id
        JOIN public.aicq_sub_competencies_v1 sc2
          ON sc2.id = iv2.sub_competency_id
        LEFT JOIN public.aicq_responses_v1 r2
          ON r2.item_version_id = iv2.id
         AND r2.attempt_id = p_attempt_id
        WHERE fi2.form_version_id = v_attempt.form_version_id
          AND sc2.competency_id = r.competency_id;


        INSERT INTO public.aicq_competency_results_v1 (
            evidence_result_id,
            competency_id,
            score,
            items_answered,
            evidence_count,
            metadata
        )
        SELECT
            v_evidence_id,
            r.competency_id,
            COALESCE(v_competency_score, 0),
            COUNT(rsp.id) FILTER (
                WHERE rsp.skipped = false
            ),
            COUNT(rsp.id),
            jsonb_build_object(
                'competency_code',
                r.competency_code,
                'items_in_form',
                r.competency_items,
                'scoring_rule',
                'correct_over_form_items',
                'pilot_status',
                'PROVISIONAL'
            )
        FROM public.aicq_form_items_v1 fi3
        JOIN public.aicq_item_versions_v1 iv3
          ON iv3.id = fi3.item_version_id
        JOIN public.aicq_sub_competencies_v1 sc3
          ON sc3.id = iv3.sub_competency_id
        LEFT JOIN public.aicq_responses_v1 rsp
          ON rsp.attempt_id = p_attempt_id
         AND rsp.item_version_id = iv3.id
        WHERE fi3.form_version_id = v_attempt.form_version_id
          AND sc3.competency_id = r.competency_id;


    END LOOP;


    /* --------------------------------------------------------
       Mark attempt complete only after evidence exists.
       -------------------------------------------------------- */

    UPDATE public.aicq_attempts_v1
    SET
        status = 'COMPLETED',
        completed_at = COALESCE(completed_at, now())
    WHERE id = p_attempt_id
      AND status IN ('SUBMITTED', 'PROCESSING');


    RETURN jsonb_build_object(
        'ok', true,
        'code', 'EVIDENCE_GENERATED',
        'attempt_id', p_attempt_id,
        'evidence_result_id', v_evidence_id,
        'knowledge_score', v_knowledge,
        'practical_score', v_practical,
        'overall_score', v_overall,
        'confidence_signal', v_confidence,
        'scoring_version', v_scoring_version
    );

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_score_attempt_v1"(uuid) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_score_attempt_v1"(uuid) FROM PUBLIC;
