-- Fix Cloudflare Workers AI endpoint: the run path is /ai/run/{model},
-- not /ai/v1. The provider appends /run/{model} to this base_url.
UPDATE public.llm_providers
SET base_url = 'https://api.cloudflare.com/client/v4/accounts/{account_id}/ai'
WHERE slug = 'cloudflare';
