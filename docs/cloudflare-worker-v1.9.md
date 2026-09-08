# AICQ Foundation Worker v1.9

Complete replacement Worker for `aicq-foundation-api`.

This version calls the dedicated Supabase API wrapper:

`aicq_api_create_attempt_v1(text,text,text,uuid,uuid,uuid,text,integer,text,text,integer)`

The wrapper internally calls the confirmed canonical `aicq_create_attempt_v1`
function, avoiding the overloaded RPC at the PostgREST boundary.

All other participant routes remain attempt-scoped and session-protected.

Required Cloudflare secrets:
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY

Participant origin:
- https://aicq-assessment.imranmirzadubai.workers.dev
