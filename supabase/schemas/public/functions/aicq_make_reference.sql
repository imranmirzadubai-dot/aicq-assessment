CREATE OR REPLACE FUNCTION public.aicq_make_reference (
  p_id uuid
)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  select 'AICQ-' ||
    upper(substr(encode(sha256(convert_to(p_id::text, 'UTF8')), 'hex'),1,4))
    || '-' ||
    upper(substr(encode(sha256(convert_to((p_id::text || ':2'), 'UTF8')), 'hex'),1,4))
    || '-' ||
    upper(substr(encode(sha256(convert_to((p_id::text || ':3'), 'UTF8')), 'hex'),1,4));
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_make_reference"(uuid) TO PUBLIC, "anon", "authenticated", "postgres", "service_role";
