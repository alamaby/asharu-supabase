-- 5 model image Cloudflare baru: FLUX.2 (klein-4b/9b, dev) + Leonardo (phoenix-1.0, lucid-origin) — 2026-09-17
-- Menu Studio + visualisasi draft konten (cover + per-reply manual). Non-destruktif, aditif saja:
-- 1) 5 kolom advanced nullable di user_image_generations + content_draft_images
--    (guidance/steps/seed/req_width/req_height; NULL = Auto/tidak diisi).
--    Worker: Auto (non-pin) di-clamp maks 1024px / 25 steps (cost guard);
--    pin manual boleh sampai maks model. Audit nilai efektif di llm_meta.
-- 2) Seed 5 model Cloudflare (SEMUa is_default=false agar default global tetap
--    flux-1-schnell + waterfall existing tidak berubah):
--    - flux-2-klein-4b  (23): distilled ultra-cepat, generate+edit, single-ref
--    - flux-2-klein-9b  (24): 9B params, multi-ref (dipakai single-ref dulu)
--    - flux-2-dev       (25): fotorealistik detail, pin kualitas
--    - phoenix-1.0      (26): prompt adherence + render teks, MANUAL only
--    - lucid-origin     (27): adaptif/HD/product-mockup, MANUAL only
--    Input Flux-2 opaque (docs: multipart required, field tak terekspos) —
--    adapter pakai FormData primary + fallback JSON 1x khusus HTTP 400;
--    override eksplisit via config.transport (multipart|json|auto).
--    Phoenix output biner image/jpeg; Lucid JSON {image} TANPA negative_prompt
--    (negative dilipat "Avoid: ..."). Phoenix/Lucid text_capable=true agar
--    suffix style "no text" dikecualikan worker.
-- Key material TIDAK di kolom — reuse image_provider_keys Vault cloudflare.
-- Priority 23-27 = setelah SD img2img (21-22), sebelum provider lain.
-- Backfill TIDAK dilakukan (kolom nullable; UI fallback Auto untuk data lama).

-- 1) Kolom advanced (nullable; NULL = Auto)
ALTER TABLE public.user_image_generations
  ADD COLUMN IF NOT EXISTS guidance numeric NULL
  CHECK (guidance IS NULL OR (guidance >= 0 AND guidance <= 10));
ALTER TABLE public.user_image_generations
  ADD COLUMN IF NOT EXISTS steps int NULL
  CHECK (steps IS NULL OR (steps >= 1 AND steps <= 50));
ALTER TABLE public.user_image_generations
  ADD COLUMN IF NOT EXISTS seed bigint NULL
  CHECK (seed IS NULL OR seed >= 0);
ALTER TABLE public.user_image_generations
  ADD COLUMN IF NOT EXISTS req_width int NULL
  CHECK (req_width IS NULL OR (req_width >= 256 AND req_width <= 2500));
ALTER TABLE public.user_image_generations
  ADD COLUMN IF NOT EXISTS req_height int NULL
  CHECK (req_height IS NULL OR (req_height >= 256 AND req_height <= 2500));

ALTER TABLE public.content_draft_images
  ADD COLUMN IF NOT EXISTS guidance numeric NULL
  CHECK (guidance IS NULL OR (guidance >= 0 AND guidance <= 10));
ALTER TABLE public.content_draft_images
  ADD COLUMN IF NOT EXISTS steps int NULL
  CHECK (steps IS NULL OR (steps >= 1 AND steps <= 50));
ALTER TABLE public.content_draft_images
  ADD COLUMN IF NOT EXISTS seed bigint NULL
  CHECK (seed IS NULL OR seed >= 0);
ALTER TABLE public.content_draft_images
  ADD COLUMN IF NOT EXISTS req_width int NULL
  CHECK (req_width IS NULL OR (req_width >= 256 AND req_width <= 2500));
ALTER TABLE public.content_draft_images
  ADD COLUMN IF NOT EXISTS req_height int NULL
  CHECK (req_height IS NULL OR (req_height >= 256 AND req_height <= 2500));

-- 2) Seed 5 model Cloudflare baru (non-default; config = capability + default aman)
INSERT INTO public.image_models (provider_id, model_id, display_name, is_default, priority, config)
SELECT p.id, m.model_id, m.display_name, m.is_default, m.priority, m.config
FROM public.image_providers p
JOIN (VALUES
  ('cloudflare', '@cf/black-forest-labs/flux-2-klein-4b', 'Flux 2 Klein 4B (Cepat)',  false, 23, '{"supports_reference": true, "transport": "auto", "image_field": "image", "steps_field": "steps"}'::jsonb),
  ('cloudflare', '@cf/black-forest-labs/flux-2-klein-9b', 'Flux 2 Klein 9B',          false, 24, '{"supports_reference": true, "transport": "auto", "image_field": "image", "steps_field": "steps"}'::jsonb),
  ('cloudflare', '@cf/black-forest-labs/flux-2-dev',      'Flux 2 Dev (Kualitas)',   false, 25, '{"supports_reference": true, "transport": "auto", "image_field": "image", "steps_field": "steps"}'::jsonb),
  ('cloudflare', '@cf/leonardo/phoenix-1.0',              'Phoenix 1.0 (Teks Akurat)', false, 26, '{"supports_reference": false, "text_capable": true, "guidance_default": 2, "steps_default": 20, "max_steps": 50, "max_dim": 2048, "negative_mode": "native", "output": "binary"}'::jsonb),
  ('cloudflare', '@cf/leonardo/lucid-origin',            'Lucid Origin (HD)',       false, 27, '{"supports_reference": false, "text_capable": true, "guidance_default": 4.5, "steps_default": 20, "max_steps": 40, "max_dim": 2500, "negative_mode": "fold", "output": "json"}'::jsonb)
) AS m(provider_slug, model_id, display_name, is_default, priority, config)
  ON m.provider_slug = p.slug
ON CONFLICT (provider_id, model_id) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  is_active = true,
  config = public.image_models.config || EXCLUDED.config;
