-- Fix Cloudflare image base_url: Workers AI image endpoint = /ai/run/{model},
-- bukan /ai/v1/run/{model} (adapter menambah /run/{model} ke base_url ini).
-- Live probe 2026-09-11: /ai/v1 → 400 "No route for that URI"; /ai → 200 + base64.
-- Lihat migrasi 20260907000003_image_generation.sql baris 30 (seed regresi).
UPDATE public.image_providers
SET base_url = 'https://api.cloudflare.com/client/v4/accounts/{account_id}/ai',
    updated_at = now()
WHERE slug = 'cloudflare'
  AND base_url <> 'https://api.cloudflare.com/client/v4/accounts/{account_id}/ai';
