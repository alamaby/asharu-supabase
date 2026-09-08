-- Enhance image prompt stage — 2026-09-08
-- Tambah stage 'enhance_image_prompt' (LLM polish prompt user di review, side-by-side)
-- ke llm_stage_defaults agar bisa di-pin via Admin → LLM → Stage Defaults.
-- Non-destruktif: CHECK diperluas, seed 1 row NULL (= global waterfall).

ALTER TABLE public.llm_stage_defaults DROP CONSTRAINT IF EXISTS llm_stage_defaults_stage_check;
ALTER TABLE public.llm_stage_defaults
  ADD CONSTRAINT llm_stage_defaults_stage_check CHECK (stage IN (
    'idea_generation', 'discovering', 'verifying', 'scoring', 'developing', 'regen_affiliate', 'image_prompt', 'enhance_image_prompt'
  ));
INSERT INTO public.llm_stage_defaults (stage, provider_id, model_id)
VALUES ('enhance_image_prompt', NULL, NULL)
ON CONFLICT (stage) DO NOTHING;
