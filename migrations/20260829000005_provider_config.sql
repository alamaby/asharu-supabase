-- Provider-level config (e.g. Cloudflare account_id, which is part of the
-- endpoint URL but is an identifier, not a secret). Secrets stay in Vault.
ALTER TABLE public.llm_providers
  ADD COLUMN IF NOT EXISTS config jsonb NOT NULL DEFAULT '{}'::jsonb;
