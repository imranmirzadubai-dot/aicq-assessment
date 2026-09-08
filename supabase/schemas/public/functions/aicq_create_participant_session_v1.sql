CREATE OR REPLACE FUNCTION public.aicq_create_participant_session_v1 (
  p_attempt_id              uuid,
  p_token_hash              text,
  p_expires_at              timestamp with time zone,
  p_created_ip_hash         text,
  p_created_user_agent_hash text
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_session_id uuid;
    v_eligibility jsonb;
BEGIN

    IF p_attempt_id IS NULL THEN
        RAISE EXCEPTION 'ATTEMPT_ID_REQUIRED';
    END IF;


    IF p_token_hash IS NULL
       OR p_token_hash !~ '^[0-9a-fA-F]{64}$' THEN

        RAISE EXCEPTION 'SESSION_TOKEN_HASH_INVALID';

    END IF;


    IF p_expires_at IS NULL
       OR p_expires_at <= now() THEN

        RAISE EXCEPTION 'SESSION_EXPIRY_INVALID';

    END IF;


    v_eligibility :=
        public.aicq_check_attempt_session_eligibility_v1(
            p_attempt_id
        );


    IF COALESCE(
        (v_eligibility->>'ok')::boolean,
        false
    ) = false THEN

        RAISE EXCEPTION '%',
            COALESCE(
                v_eligibility->>'code',
                'ATTEMPT_NOT_ELIGIBLE'
            );

    END IF;


    INSERT INTO public.aicq_participant_sessions_v1 (
        attempt_id,
        token_hash,
        expires_at,
        created_ip_hash,
        created_user_agent_hash
    )
    VALUES (
        p_attempt_id,
        lower(p_token_hash),
        p_expires_at,
        p_created_ip_hash,
        p_created_user_agent_hash
    )
    RETURNING id
    INTO v_session_id;


    RETURN v_session_id;

END;
$function$;

GRANT EXECUTE ON FUNCTION "public"."aicq_create_participant_session_v1"(uuid, text, timestamp WITH time zone, text, text) TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."aicq_create_participant_session_v1"(uuid, text, timestamp WITH time zone, text, text) FROM PUBLIC;
