-- P1 (audit 2026-08-30): llm_provider_keys.api_key_encrypted held API keys in
-- PLAIN TEXT as the pre-Vault fallback. Migrate any remaining plaintext rows
-- into Supabase Vault and clear the column.
--
-- Non-destructive: the column is NOT dropped here — it is left in place
-- holding NULLs; drop it in a follow-up migration once production is verified.
-- Runs as postgres (migration runner / SQL editor), which may call
-- vault.create_secret() directly and bypasses RLS on llm_provider_keys.

-- Rows that already have a Vault secret must not keep plaintext leftovers.
UPDATE public.llm_provider_keys
   SET api_key_encrypted = NULL
 WHERE vault_secret_id IS NOT NULL
   AND api_key_encrypted IS NOT NULL;

-- Rows with only plaintext: create the Vault secret, link it, clear plaintext.
DO $$
DECLARE
  r RECORD;
  v_secret_id uuid;
BEGIN
  FOR r IN
    SELECT id, key_hash, api_key_encrypted
    FROM public.llm_provider_keys
    WHERE api_key_encrypted IS NOT NULL
      AND api_key_encrypted <> ''
      AND vault_secret_id IS NULL
  LOOP
    v_secret_id := vault.create_secret(r.api_key_encrypted, 'llm_migrated_' || r.key_hash);
    UPDATE public.llm_provider_keys
       SET vault_secret_id = v_secret_id,
           api_key_encrypted = NULL
     WHERE id = r.id;
    RAISE NOTICE 'Migrated key % to Vault (%)', r.key_hash, v_secret_id;
  END LOOP;
END;
$$;
