-- Vault RPC wrappers exposed via PostgREST (public schema).
-- The `vault` schema itself is not exposed to PostgREST, so the JS client
-- cannot call vault.create_secret / read decrypted_secrets directly.
-- These SECURITY DEFINER wrappers bridge that gap, restricted to service_role.

CREATE OR REPLACE FUNCTION public.vault_create_secret(p_secret text, p_name text)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = vault, public
AS $$
  SELECT vault.create_secret(p_secret, p_name);
$$;

CREATE OR REPLACE FUNCTION public.vault_decrypt_secret(p_id uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = vault, public
AS $$
  SELECT decrypted_secret FROM vault.decrypted_secrets WHERE id = p_id;
$$;

-- Lock down: service_role only (the processor + seed scripts).
REVOKE ALL ON FUNCTION public.vault_create_secret(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.vault_decrypt_secret(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.vault_create_secret(text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.vault_decrypt_secret(uuid) TO service_role;
