CREATE OR REPLACE FUNCTION public.aicq_score_practical_v1 (
  p_practical_submission_id uuid
)
  RETURNS numeric
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_submission jsonb;
    v_task_definition jsonb;
    v_correct_order jsonb;

    v_submitted text[];
    v_correct text[];

    v_pairwise_total integer := 0;
    v_pairwise_correct integer := 0;

    i integer;
    j integer;
    submitted_i integer;
    submitted_j integer;
    correct_i integer;
    correct_j integer;

    v_score numeric;
    v_evidence_id uuid;
BEGIN

    SELECT
        ps.ordered_steps,
        tv.task_definition
    INTO
        v_submission,
        v_task_definition
    FROM public.aicq_practical_submissions_v1 ps
    JOIN public.aicq_practical_task_versions_v1 tv
      ON tv.id = ps.task_version_id
    WHERE ps.id = p_practical_submission_id
      AND tv.status = 'PUBLISHED';


    IF NOT FOUND THEN
        RAISE EXCEPTION 'PRACTICAL_SUBMISSION_NOT_FOUND';
    END IF;


    v_correct_order :=
        v_task_definition->'correct_order';


    IF v_correct_order IS NULL
       OR jsonb_typeof(v_correct_order) <> 'array'
       OR jsonb_array_length(v_correct_order) <> 9 THEN
        RAISE EXCEPTION 'PRACTICAL_CORRECT_ORDER_INVALID';
    END IF;


    SELECT array_agg(value::text ORDER BY ord)
    INTO v_submitted
    FROM jsonb_array_elements_text(v_submission) WITH ORDINALITY x(value, ord);


    SELECT array_agg(value::text ORDER BY ord)
    INTO v_correct
    FROM jsonb_array_elements_text(v_correct_order) WITH ORDINALITY x(value, ord);


    /* --------------------------------------------------------
       Validate submitted steps are exactly the nine expected
       steps, with no duplicates.
       -------------------------------------------------------- */

    IF (
        SELECT COUNT(DISTINCT x)
        FROM unnest(v_submitted) x
    ) <> 9 THEN
        RAISE EXCEPTION 'PRACTICAL_DUPLICATE_OR_MISSING_STEPS';
    END IF;


    IF (
        SELECT COUNT(*)
        FROM unnest(v_submitted) x
        WHERE x = ANY(v_correct)
    ) <> 9 THEN
        RAISE EXCEPTION 'PRACTICAL_INVALID_STEP_SET';
    END IF;


    /* --------------------------------------------------------
       Evaluate all 36 unordered pairs.
       -------------------------------------------------------- */

    FOR i IN 1..8 LOOP

        FOR j IN (i+1)..9 LOOP

            v_pairwise_total := v_pairwise_total + 1;


            submitted_i := array_position(
                v_submitted,
                v_correct[i]
            );

            submitted_j := array_position(
                v_submitted,
                v_correct[j]
            );


            correct_i := i;
            correct_j := j;


            IF (
                submitted_i < submitted_j
                AND correct_i < correct_j
            )
            OR (
                submitted_i > submitted_j
                AND correct_i > correct_j
            ) THEN

                v_pairwise_correct :=
                    v_pairwise_correct + 1;

            END IF;

        END LOOP;

    END LOOP;


    v_score :=
        ROUND(
            (
                v_pairwise_correct::numeric
                / v_pairwise_total::numeric
            ) * 100,
            2
        );


    /* --------------------------------------------------------
       One evidence record per practical submission.
       -------------------------------------------------------- */

    IF EXISTS (
        SELECT 1
        FROM public.aicq_practical_evidence_v1
        WHERE practical_submission_id =
              p_practical_submission_id
    ) THEN

        SELECT score
        INTO v_score
        FROM public.aicq_practical_evidence_v1
        WHERE practical_submission_id =
              p_practical_submission_id
        ORDER BY created_at DESC
        LIMIT 1;

        RETURN v_score;

    END IF;


    INSERT INTO public.aicq_practical_evidence_v1 (
        practical_submission_id,
        evidence_version,
        evidence_data,
        score,
        created_at
    )
    VALUES (
        p_practical_submission_id,
        '1.0',
        jsonb_build_object(
            'scoring_model_version',
            'evidence-weighted-v3-kendall-practical',
            'pairwise_total',
            v_pairwise_total,
            'pairwise_correct',
            v_pairwise_correct,
            'pairwise_score',
            v_score
        ),
        v_score,
        now()
    )
    RETURNING id
    INTO v_evidence_id;


    RETURN v_score;

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_score_practical_v1"(uuid) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_score_practical_v1"(uuid) FROM PUBLIC;
