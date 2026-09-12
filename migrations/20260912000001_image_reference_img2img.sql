-- Image reference img2img Cloudflare fase 1 (2026-09-12)
-- Studio + review bisa generate berbasis gambar referensi (upload / histori)
-- memakai model SD img2img (@cf/runwayml/stable-diffusion-v1-5-img2img +
-- @cf/bytedance/stable-diffusion-xl-lightning). Non-destruktif, aditif saja:
-- 1) 3 kolom referensi di user_image_generations + content_draft_images
--    (storage path + public url + strength 0-1).
-- 2) Seed 2 model Cloudflare baru (is_default=false agar waterfall existing
--    tidak berubah; config.supports_reference=true = capability flag).
-- Storage reuse bucket existing (user-images / draft-images, prefix ref/),
-- tulis via service_role di server action — tanpa policy baru (service_role
-- bypass RLS; public read policy existing dipakai ulang).
-- Mask/inpainting TIDAK ikut (fase 2).

-- 1) Kolom referensi (nullable; NULL = text-to-image biasa)
ALTER TABLE public.user_image_generations
  ADD COLUMN IF NOT EXISTS reference_storage_path text NULL;
ALTER TABLE public.user_image_generations
  ADD COLUMN IF NOT EXISTS reference_public_url text NULL;
ALTER TABLE public.user_image_generations
  ADD COLUMN IF NOT EXISTS reference_strength numeric NULL
  CHECK (reference_strength IS NULL OR (reference_strength >= 0 AND reference_strength <= 1));

ALTER TABLE public.content_draft_images
  ADD COLUMN IF NOT EXISTS reference_storage_path text NULL;
ALTER TABLE public.content_draft_images
  ADD COLUMN IF NOT EXISTS reference_public_url text NULL;
ALTER TABLE public.content_draft_images
  ADD COLUMN IF NOT EXISTS reference_strength numeric NULL
  CHECK (reference_strength IS NULL OR (reference_strength >= 0 AND reference_strength <= 1));

-- 2) Seed 2 model img2img Cloudflare (non-default, supports_reference)
INSERT INTO public.image_models (provider_id, model_id, display_name, is_default, priority, config)
SELECT p.id, m.model_id, m.display_name, m.is_default, m.priority, m.config
FROM public.image_providers p
JOIN (VALUES
  ('cloudflare', '@cf/runwayml/stable-diffusion-v1-5-img2img',   'SD 1.5 Img2Img',  false, 21, '{"supports_reference": true}'::jsonb),
  ('cloudflare', '@cf/bytedance/stable-diffusion-xl-lightning', 'SDXL Lightning', false, 22, '{"supports_reference": true}'::jsonb)
) AS m(provider_slug, model_id, display_name, is_default, priority, config)
  ON m.provider_slug = p.slug
ON CONFLICT (provider_id, model_id) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  is_active = true,
  config = public.image_models.config || EXCLUDED.config;
