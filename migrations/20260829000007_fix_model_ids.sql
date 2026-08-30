-- Fix seeded model ids:
-- 1. naraya router model ids have no "naraya/" prefix (that was opencode's format).
-- 2. gemini-1.5-flash is retired on v1beta; use gemini-2.5-flash.
UPDATE public.llm_models
SET model_id = replace(model_id, 'naraya/', '')
WHERE provider_id = (SELECT id FROM public.llm_providers WHERE slug = 'naraya');

UPDATE public.llm_models
SET model_id = 'gemini-2.5-flash'
WHERE provider_id = (SELECT id FROM public.llm_providers WHERE slug = 'gemini')
  AND model_id = 'gemini-1.5-flash';
