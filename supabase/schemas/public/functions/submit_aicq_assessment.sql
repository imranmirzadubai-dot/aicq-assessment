CREATE OR REPLACE FUNCTION public.submit_aicq_assessment (
  p_payload jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_id uuid := gen_random_uuid();
  v_ref text;
  v_record jsonb := coalesce(p_payload->'record', '{}'::jsonb);
  v_participant jsonb := coalesce(v_record->'participant', '{}'::jsonb);
  v_q jsonb;
begin

  if p_payload is null
     or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Invalid submission payload';
  end if;

  if length(coalesce(v_participant->>'name','')) < 1
     or length(v_participant->>'name') > 200 then
    raise exception 'Invalid participant name';
  end if;

  if jsonb_typeof(v_record->'questions') <> 'array' then
    raise exception 'Missing question record';
  end if;

  if jsonb_array_length(v_record->'questions') < 1
     or jsonb_array_length(v_record->'questions') > 64 then
    raise exception 'Invalid question count';
  end if;

  v_ref := public.aicq_make_reference(v_id);

  insert into public.aicq_assessments (
    id,
    reference_code,
    integrity_sha256,
    aicq_version,
    question_bank_version,
    scoring_model_version,
    difficulty_framework_version,
    started_at,
    completed_at,
    participant_name,
    participant_age,
    participant_gender,
    participant_occupation,
    participant_experience,
    confidence,
    assessment_target,
    knowledge_score,
    practical_score,
    overall_score,
    competency_scores,
    evidence,
    full_record
  )
  values (
    v_id,
    v_ref,
    p_payload->>'integrity_sha256',
    coalesce(v_record->>'aicq_version','unknown'),
    coalesce(v_record->>'question_bank_version','unknown'),
    coalesce(v_record->>'scoring_model_version','unknown'),
    v_record->>'difficulty_framework_version',
    nullif(v_record->>'assessment_started_at','')::timestamptz,
    now(),
    v_participant->>'name',
    nullif(v_participant->>'age','')::integer,
    v_participant->>'gender',
    v_participant->>'occupation',
    nullif(v_participant->>'experience','')::integer,
    nullif(v_record->>'confidence','')::integer,
    nullif(v_record->>'assessment_target','')::integer,
    nullif(v_record->>'knowledge_score','')::integer,
    nullif(v_record->>'practical_score','')::integer,
    nullif(v_record->>'overall_score','')::integer,
    coalesce(v_record->'competency_scores','{}'::jsonb),
    coalesce(v_record->'evidence','{}'::jsonb),
    v_record
  );

  for v_q in
    select value
    from jsonb_array_elements(v_record->'questions')
  loop

    insert into public.aicq_responses (
      assessment_id,
      position,
      question_id,
      competency,
      sub_competency,
      difficulty,
      answer_index,
      skipped,
      correct,
      response_time_ms,
      option_order,
      selected_option
    )
    values (
      v_id,
      (v_q->>'position')::integer,
      v_q->>'id',
      v_q->>'competency',
      v_q->>'sub_competency',
      v_q->>'difficulty',

      case
        when (v_q->>'answer') is null
          or v_q->>'answer' = '-1'
        then null
        else (v_q->>'answer')::integer
      end,

      coalesce((v_q->>'skipped')::boolean,false),

      case
        when (v_q->>'answer') is null
          or v_q->>'answer' = '-1'
        then null
        else (
          (v_q->>'answer')::integer =
          (v_q->>'correct_index')::integer
        )
      end,

      nullif(
        (
          v_record->'question_telemetry'
          ->(v_q->>'id')
          ->>'duration_ms'
        ),
        ''
      )::integer,

      coalesce(v_q->'option_order','[]'::jsonb),

      case
        when (v_q->>'answer') is null
          or v_q->>'answer' = '-1'
        then null
        else v_q->'options'->(v_q->>'answer')::integer
      end
    );

  end loop;

  return jsonb_build_object(
    'assessment_id', v_id,
    'reference_code', v_ref
  );

end;
$function$;

GRANT EXECUTE ON FUNCTION "public"."submit_aicq_assessment"(jsonb) TO "anon", "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."submit_aicq_assessment"(jsonb) FROM PUBLIC;
