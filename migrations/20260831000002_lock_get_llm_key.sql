-- P1 (audit 2026-08-30): get_llm_key() is SECURITY DEFINER and returns the
-- Vault secret or the plaintext fallback column value. It was created without
-- a REVOKE, so PUBLIC could execute it via PostgREST RPC — a secret oracle.
-- Lock it down to service_role, mirroring the vault RPC wrappers (0003/0004).

REVOKE ALL ON FUNCTION public.get_llm_key(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_llm_key(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.get_llm_key(uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.get_llm_key(uuid) TO service_role;
