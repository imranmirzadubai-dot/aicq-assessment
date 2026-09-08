CREATE OR REPLACE FUNCTION public.aicq_import_frozen_bank_v1 (
  p_bank jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_item jsonb;
    v_option jsonb;

    v_item_id text;
    v_item_version text;
    v_competency text;
    v_sub_competency text;

    v_competency_id uuid;
    v_sub_competency_id uuid;
    v_item_version_id uuid;
    v_option_id uuid;

    v_correct_index integer;
    v_option_index integer;

    v_inserted_items integer := 0;
    v_inserted_options integer := 0;

    v_existing_id uuid;
    v_option_count integer;

BEGIN

    -- ========================================================
    -- BANK HEADER VALIDATION
    -- ========================================================

    IF p_bank IS NULL THEN
        RAISE EXCEPTION 'BANK_PAYLOAD_NULL';
    END IF;

    IF p_bank->>'question_bank_version'
       <> 'AICQ-v1.25-frozen-content-remediated-96'
    THEN
        RAISE EXCEPTION
            'BANK_VERSION_INVALID: %',
            p_bank->>'question_bank_version';
    END IF;

    IF jsonb_array_length(
        COALESCE(p_bank->'items','[]'::jsonb)
    ) <> 96
    THEN
        RAISE EXCEPTION 'BANK_ITEM_COUNT_INVALID';
    END IF;


    -- ========================================================
    -- IMPORT EACH ITEM
    -- ========================================================

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_bank->'items')
    LOOP

        v_item_id :=
            v_item->>'id';

        v_item_version :=
            v_item->>'version';

        v_competency :=
            v_item->>'competency';

        v_sub_competency :=
            v_item->>'sub_competency';

        v_correct_index :=
            (v_item->>'correct_index')::integer;


        -- ----------------------------------------------------
        -- Required fields
        -- ----------------------------------------------------

        IF COALESCE(v_item_id,'') = ''
        THEN
            RAISE EXCEPTION 'ITEM_ID_MISSING';
        END IF;

        IF COALESCE(v_item_version,'') = ''
        THEN
            RAISE EXCEPTION
                'ITEM_VERSION_MISSING: %',
                v_item_id;
        END IF;

        IF COALESCE(v_item->>'stem','') = ''
        THEN
            RAISE EXCEPTION
                'ITEM_STEM_MISSING: %',
                v_item_id;
        END IF;

        IF v_correct_index NOT BETWEEN 0 AND 3
        THEN
            RAISE EXCEPTION
                'CORRECT_INDEX_INVALID: %',
                v_item_id;
        END IF;


        -- ----------------------------------------------------
        -- Exactly four options
        -- ----------------------------------------------------

        v_option_count :=
            jsonb_array_length(
                COALESCE(
                    v_item->'options',
                    '[]'::jsonb
                )
            );

        IF v_option_count <> 4
        THEN
            RAISE EXCEPTION
                'OPTION_COUNT_INVALID: % = %',
                v_item_id,
                v_option_count;
        END IF;


        -- ----------------------------------------------------
        -- Competency
        -- ----------------------------------------------------

        SELECT c.id
        INTO v_competency_id
        FROM public.aicq_competencies_v1 c
        WHERE c.framework_version = 'AICQ-FW-1.0'
          AND lower(trim(c.name))
              = lower(trim(v_competency))
        LIMIT 1;

        IF v_competency_id IS NULL
        THEN
            RAISE EXCEPTION
                'COMPETENCY_NOT_FOUND: % / %',
                v_item_id,
                v_competency;
        END IF;


        -- ----------------------------------------------------
        -- Sub-competency
        --
        -- First exact case-insensitive match.
        -- Then normalized punctuation/spacing match.
        -- ----------------------------------------------------

        SELECT sc.id
        INTO v_sub_competency_id
        FROM public.aicq_sub_competencies_v1 sc
        WHERE sc.competency_id = v_competency_id
          AND lower(trim(sc.name))
              = lower(trim(v_sub_competency))
        LIMIT 1;

        IF v_sub_competency_id IS NULL
        THEN

            SELECT sc.id
            INTO v_sub_competency_id
            FROM public.aicq_sub_competencies_v1 sc
            WHERE sc.competency_id = v_competency_id
              AND lower(
                    regexp_replace(
                        trim(sc.name),
                        '[^a-z0-9]+',
                        '',
                        'gi'
                    )
                  )
                  =
                  lower(
                    regexp_replace(
                        trim(v_sub_competency),
                        '[^a-z0-9]+',
                        '',
                        'gi'
                    )
                  )
            LIMIT 1;

        END IF;

        IF v_sub_competency_id IS NULL
        THEN
            RAISE EXCEPTION
                'SUB_COMPETENCY_NOT_FOUND: % / %',
                v_item_id,
                v_sub_competency;
        END IF;


        -- ----------------------------------------------------
        -- Existing item/version
        -- ----------------------------------------------------

        SELECT id
        INTO v_existing_id
        FROM public.aicq_item_versions_v1
        WHERE item_code = v_item_id
          AND version = v_item_version
        LIMIT 1;

        IF v_existing_id IS NOT NULL
        THEN
            v_item_version_id := v_existing_id;

        ELSE

            -- IMPORTANT:
            -- DRAFT is intentional.
            -- "PILOT" is not an allowed status in this table.

            INSERT INTO public.aicq_item_versions_v1 (
                item_code,
                version,
                sub_competency_id,
                cognitive_demand,
                evidence_type,
                stem,
                status,
                metadata
            )
            VALUES (
                v_item_id,
                v_item_version,
                v_sub_competency_id,
                v_item->>'cognitive_demand',
                v_item->>'type',
                v_item->>'stem',
                'DRAFT',
                jsonb_build_object(
                    'source',
                        'AICQ_v1_25_Frozen_Pilot_Bank.json',
                    'aicq_version',
                        p_bank->>'aicq_version',
                    'question_bank_version',
                        p_bank->>'question_bank_version',
                    'source_competency',
                        v_item->>'competency',
                    'source_sub_competency',
                        v_item->>'sub_competency',
                    'observable_behavior',
                        v_item->>'observable_behavior',
                    'difficulty',
                        v_item->>'difficulty',
                    'source_rationale',
                        v_item->>'rationale',
                    'source_note',
                        v_item->>'source_note',
                    'source_status',
                        v_item->>'status',
                    'content_status',
                        v_item->>'content_status',
                    'psychometric_status',
                        v_item->>'psychometric_status',
                    'revision_status',
                        v_item->>'revision_status'
                )
            )
            RETURNING id
            INTO v_item_version_id;

            v_inserted_items :=
                v_inserted_items + 1;

        END IF;


        -- ====================================================
        -- OPTIONS
        -- ====================================================

        FOR v_option_index IN 0..3
        LOOP

            SELECT id
            INTO v_option_id
            FROM public.aicq_item_options_v1
            WHERE item_version_id = v_item_version_id
              AND option_index = v_option_index
            LIMIT 1;

            IF v_option_id IS NULL
            THEN

                INSERT INTO public.aicq_item_options_v1 (
                    item_version_id,
                    option_code,
                    option_text,
                    option_index,
                    metadata
                )
                VALUES (
                    v_item_version_id,
                    chr(65 + v_option_index),
                    v_item->'options'->>v_option_index,
                    v_option_index,
                    jsonb_build_object(
                        'source_item_id',
                            v_item_id,
                        'source_option_index',
                            v_option_index
                    )
                )
                RETURNING id
                INTO v_option_id;

                v_inserted_options :=
                    v_inserted_options + 1;

            END IF;


            -- -----------------------------------------------
            -- Store answer key ONLY in server-side item record
            -- -----------------------------------------------

            IF v_option_index = v_correct_index
            THEN

                UPDATE public.aicq_item_versions_v1
                SET answer_key_option_id = v_option_id
                WHERE id = v_item_version_id;

            END IF;

        END LOOP;

    END LOOP;


    -- ========================================================
    -- FINAL INTEGRITY CHECK
    -- ========================================================

    IF (
        SELECT count(*)
        FROM public.aicq_item_versions_v1
        WHERE item_code IN (
            SELECT value->>'id'
            FROM jsonb_array_elements(p_bank->'items')
        )
        AND version IN (
            SELECT value->>'version'
            FROM jsonb_array_elements(p_bank->'items')
        )
    ) <> 96
    THEN
        RAISE EXCEPTION
            'FINAL_ITEM_COUNT_FAILED';
    END IF;


    IF (
        SELECT count(*)
        FROM public.aicq_item_options_v1 io
        JOIN public.aicq_item_versions_v1 iv
          ON iv.id = io.item_version_id
        WHERE iv.item_code IN (
            SELECT value->>'id'
            FROM jsonb_array_elements(p_bank->'items')
        )
        AND iv.version IN (
            SELECT value->>'version'
            FROM jsonb_array_elements(p_bank->'items')
        )
    ) <> 384
    THEN
        RAISE EXCEPTION
            'FINAL_OPTION_COUNT_FAILED';
    END IF;


    RETURN jsonb_build_object(
        'status',
            'SUCCESS',
        'items_inserted',
            v_inserted_items,
        'options_inserted',
            v_inserted_options,
        'items_validated',
            96,
        'options_validated',
            384
    );

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_import_frozen_bank_v1"(jsonb) TO PUBLIC, "anon", "authenticated", "postgres", "service_role";
