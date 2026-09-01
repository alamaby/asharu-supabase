-- Read a Vault secret by NAME (2 Sep 2026).
--
-- The existing `vault_decrypt_secret(p_id uuid)` reads by id, and
-- `vault.decrypted_secrets` is not exposed via PostgREST — so the app cannot
-- look up a secret by name. This wrapper closes that gap for non-pooled
-- secrets (e.g. `tavily_api_key`) that live in Vault for rotation via the
-- Dashboard, mirroring the LLM-key pattern.
--
-- Returns the newest secret with the given name (ORDER BY created_at DESC),
-- so rotation = create a new Vault entry with the same name; the old one can
-- be deleted in Dashboard → Vault.
--
-- Restricted to service_role (same posture as the other vault_* wrappers).

CREATE OR REPLACE FUNCTION public.vault_decrypt_secret_by_name(p_name text)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = vault, public
AS $$
  SELECT decrypted_secret
    FROM vault.decrypted_secrets
   WHERE name = p_name
   ORDER BY created_at DESC
   LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.vault_decrypt_secret_by_name(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.vault_decrypt_secret_by_name(text) TO service_role;
