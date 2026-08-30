-- Vault delete wrapper for seed-script rollback (service_role only).
CREATE OR REPLACE FUNCTION public.vault_delete_secret(p_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = vault, public
AS $$
  DELETE FROM vault.secrets WHERE id = p_id;
$$;

REVOKE ALL ON FUNCTION public.vault_delete_secret(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.vault_delete_secret(uuid) TO service_role;
