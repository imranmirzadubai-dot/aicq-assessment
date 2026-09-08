CREATE OR REPLACE FUNCTION public.aicq_validate_bank_import_v1 (
  p_import_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$

DECLARE
    v_import public.aicq_bank_imports_v1%ROWTYPE;

    v_item jsonb;
    v_option jsonb;

    v_errors jsonb := '[]'::jsonb;
    v_warnings jsonb := '[]'::jsonb;

    v_items integer := 0;
    v_options integer := 0;

    v_key_a integer := 0;
    v_key_b integer := 0;
    v_key_c integer := 0;
    v_key_d integer := 0;

    v_correct_index integer;
    v_option_count integer;

    v_competency text;
    v_sub_competency text;

    v_competency_exists boolean;
    v_sub_exists boolean;

BEGIN

    SELECT *
    INTO v_import
    FROM public.aicq_bank_imports_v1
    WHERE id = p_import_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Bank import % does not exist',
            p_import_id;
    END IF;

    IF v_import.validation_status = 'PROMOTED' THEN
        RAISE EXCEPTION
            'Bank import % has already been promoted',
            p_import_id;
    END IF;


    -- ========================================================
    -- BANK HEADER
    -- ========================================================

    IF COALESCE(
        v_import.payload->>'question_bank_version',
        ''
    ) <> v_import.question_bank_version THEN

        v_errors := v_errors || jsonb_build_array(
            jsonb_build_object(
                'code', 'BANK_VERSION_MISMATCH',
                'message',
                'Payload question_bank_version does not match staging record.'
            )
        );

    END IF;


    IF jsonb_typeof(v_import.payload->'items')
       IS DISTINCT FROM 'array' THEN

        v_errors := v_errors || jsonb_build_array(
            jsonb_build_object(
                'code', 'ITEM_ARRAY_MISSING',
                'message',
                'Bank payload must contain an items array.'
            )
        );

    ELSE

        v_items :=
            jsonb_array_length(v_import.payload->'items');

    END IF;


    -- ========================================================
    -- ITEM VALIDATION
    -- ========================================================

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(
            COALESCE(
                v_import.payload->'items',
                '[]'::jsonb
            )
        )
    LOOP

        -- ----------------------------------------------------
        -- Item ID
        -- ----------------------------------------------------

        IF COALESCE(v_item->>'id','') = '' THEN

            v_errors := v_errors || jsonb_build_array(
                jsonb_build_object(
                    'code', 'ITEM_ID_MISSING',
                    'message', 'Item is missing id.'
                )
            );

            CONTINUE;

        END IF;


        -- ----------------------------------------------------
        -- Four options
        -- ----------------------------------------------------

        v_option_count :=
            jsonb_array_length(
                COALESCE(
                    v_item->'options',
                    '[]'::jsonb
                )
            );

        v_options := v_options + v_option_count;

        IF v_option_count <> 4 THEN

            v_errors := v_errors || jsonb_build_array(
                jsonb_build_object(
                    'code', 'OPTION_COUNT',
                    'item_id', v_item->>'id',
                    'message',
                    'Item must contain exactly four options.',
                    'actual',
                    v_option_count
                )
            );

        END IF;


        -- ----------------------------------------------------
        -- Correct index
        -- ----------------------------------------------------

        BEGIN
            v_correct_index :=
                (v_item->>'correct_index')::integer;
        EXCEPTION WHEN OTHERS THEN
            v_correct_index := -1;
        END;

        IF v_correct_index NOT BETWEEN 0 AND 3 THEN

            v_errors := v_errors || jsonb_build_array(
                jsonb_build_object(
                    'code', 'INVALID_CORRECT_INDEX',
                    'item_id', v_item->>'id',
                    'message',
                    'correct_index must be 0, 1, 2, or 3.'
                )
            );

        ELSE

            CASE v_correct_index
                WHEN 0 THEN v_key_a := v_key_a + 1;
                WHEN 1 THEN v_key_b := v_key_b + 1;
                WHEN 2 THEN v_key_c := v_key_c + 1;
                WHEN 3 THEN v_key_d := v_key_d + 1;
            END CASE;

        END IF;


        -- ----------------------------------------------------
        -- Required fields
        -- ----------------------------------------------------

        IF COALESCE(v_item->>'version','') = '' THEN

            v_errors := v_errors || jsonb_build_array(
                jsonb_build_object(
                    'code', 'ITEM_VERSION_MISSING',
                    'item_id', v_item->>'id'
                )
            );

        END IF;


        IF COALESCE(v_item->>'stem','') = '' THEN

            v_errors := v_errors || jsonb_build_array(
                jsonb_build_object(
                    'code', 'ITEM_STEM_MISSING',
                    'item_id', v_item->>'id'
                )
            );

        END IF;


        -- ----------------------------------------------------
        -- Competency
        -- ----------------------------------------------------

        v_competency :=
            v_item->>'competency';

        SELECT EXISTS (
            SELECT 1
            FROM public.aicq_competencies_v1 c
            WHERE c.framework_version = 'AICQ-FW-1.0'
              AND c.name = v_competency
        )
        INTO v_competency_exists;

        IF NOT v_competency_exists THEN

            v_errors := v_errors || jsonb_build_array(
                jsonb_build_object(
                    'code', 'COMPETENCY_NOT_FOUND',
                    'item_id', v_item->>'id',
                    'competency', v_competency
                )
            );

        END IF;


        -- ----------------------------------------------------
        -- Sub-competency
        -- ----------------------------------------------------

        v_sub_competency :=
            v_item->>'sub_competency';

        SELECT EXISTS (
            SELECT 1
            FROM public.aicq_sub_competencies_v1 sc
            JOIN public.aicq_competencies_v1 c
              ON c.id = sc.competency_id
            WHERE c.framework_version = 'AICQ-FW-1.0'
              AND c.name = v_competency
              AND lower(trim(sc.name))
                    = lower(trim(v_sub_competency))
        )
        INTO v_sub_exists;

        IF NOT v_sub_exists THEN

            v_warnings := v_warnings || jsonb_build_array(
                jsonb_build_object(
                    'code', 'SUB_COMPETENCY_MAPPING_REQUIRED',
                    'item_id', v_item->>'id',
                    'source_label', v_sub_competency
                )
            );

        END IF;


        -- ----------------------------------------------------
        -- Option text
        -- ----------------------------------------------------

        FOR v_option IN
            SELECT value
            FROM jsonb_array_elements(
                COALESCE(
                    v_item->'options',
                    '[]'::jsonb
                )
            )
        LOOP

            IF jsonb_typeof(v_option) <> 'string'
               OR length(trim(v_option #>> '{}')) = 0 THEN

                v_errors := v_errors || jsonb_build_array(
                    jsonb_build_object(
                        'code', 'INVALID_OPTION_TEXT',
                        'item_id', v_item->>'id'
                    )
                );

            END IF;

        END LOOP;

    END LOOP;


    -- ========================================================
    -- BANK-LEVEL COUNTS
    -- ========================================================

    IF v_items <> 96 THEN

        v_errors := v_errors || jsonb_build_array(
            jsonb_build_object(
                'code', 'ITEM_COUNT',
                'expected', 96,
                'actual', v_items
            )
        );

    END IF;


    IF v_options <> 384 THEN

        v_errors := v_errors || jsonb_build_array(
            jsonb_build_object(
                'code', 'OPTION_COUNT_TOTAL',
                'expected', 384,
                'actual', v_options
            )
        );

    END IF;


    -- ========================================================
    -- KEY DISTRIBUTION
    -- ========================================================

    IF v_key_a <> 24
       OR v_key_b <> 24
       OR v_key_c <> 24
       OR v_key_d <> 24 THEN

        v_warnings := v_warnings || jsonb_build_array(
            jsonb_build_object(
                'code', 'KEY_DISTRIBUTION',
                'A', v_key_a,
                'B', v_key_b,
                'C', v_key_c,
                'D', v_key_d,
                'expected_each', 24
            )
        );

    END IF;


    -- ========================================================
    -- SAVE RESULT
    -- ========================================================

    UPDATE public.aicq_bank_imports_v1
    SET
        item_count = v_items,
        option_count = v_options,
        validation_errors = v_errors,
        validation_warnings = v_warnings,
        validation_status =
            CASE
                WHEN jsonb_array_length(v_errors) = 0
                THEN 'VALID'
                ELSE 'INVALID'
            END,
        validated_at = now()
    WHERE id = p_import_id;


    RETURN jsonb_build_object(
        'import_id', p_import_id,
        'status',
        CASE
            WHEN jsonb_array_length(v_errors) = 0
            THEN 'VALID'
            ELSE 'INVALID'
        END,
        'items', v_items,
        'options', v_options,
        'key_distribution',
        jsonb_build_object(
            'A', v_key_a,
            'B', v_key_b,
            'C', v_key_c,
            'D', v_key_d
        ),
        'errors', v_errors,
        'warnings', v_warnings
    );

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_validate_bank_import_v1"(uuid) TO "anon", "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_validate_bank_import_v1"(uuid) FROM PUBLIC;
