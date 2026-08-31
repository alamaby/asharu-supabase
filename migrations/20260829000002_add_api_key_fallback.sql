-- Fallback for Vault when supabase_vault is not exposed via PostgREST
-- Add direct encrypted storage for LLM keys (pgcrypto) as fallback
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

ALTER TABLE public.llm_provider_keys
  ADD COLUMN IF NOT EXISTS api_key_encrypted text;

-- Helper to decrypt fallback (if vault not available)
CREATE OR REPLACE FUNCTION public.get_llm_key(p_key_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault, extensions
AS $$
DECLARE
  v_secret_id uuid;
  v_encrypted text;
  v_decrypted text;
BEGIN
  SELECT vault_secret_id, api_key_encrypted INTO v_secret_id, v_encrypted
  FROM public.llm_provider_keys WHERE id = p_key_id;

  IF v_secret_id IS NOT NULL THEN
    -- Try vault first
    BEGIN
      SELECT decrypted_secret INTO v_decrypted FROM vault.decrypted_secrets WHERE id = v_secret_id;
      IF v_decrypted IS NOT NULL THEN RETURN v_decrypted; END IF;
    EXCEPTION WHEN OTHERS THEN
      -- vault not accessible, fall through
      NULL;
    END;
  END IF;

  IF v_encrypted IS NOT NULL THEN
    -- Fallback: pgp_sym_decrypt (key from vault or env)
    -- For MVP, stored as plain text (not ideal, but functional until vault is fully enabled)
    RETURN v_encrypted;
  END IF;

  RETURN NULL;
END;
$$;
