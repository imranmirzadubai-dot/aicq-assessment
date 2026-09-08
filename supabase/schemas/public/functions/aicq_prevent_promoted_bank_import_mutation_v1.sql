CREATE OR REPLACE FUNCTION public.aicq_prevent_promoted_bank_import_mutation_v1()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
BEGIN

    IF OLD.validation_status = 'PROMOTED' THEN
        RAISE EXCEPTION
            'Promoted bank import % is immutable',
            OLD.id;
    END IF;

    RETURN NEW;

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_prevent_promoted_bank_import_mutation_v1"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";
