-- Compose studio prompt stage — 2026-09-18
-- Stage 'compose_studio_prompt' (konsolidasi LLM final-prompt Studio di worker,
-- worker-only; tombol Enhance tetap 'enhance_image_prompt').
-- Non-destruktif: CHECK diperluas, seed 1 row NULL (= global waterfall).

ALTER TABLE public.llm_stage_defaults DROP CONSTRAINT IF EXISTS llm_stage_defaults_stage_check;
ALTER TABLE public.llm_stage_defaults
  ADD CONSTRAINT llm_stage_defaults_stage_check CHECK (stage IN (
    'idea_generation', 'discovering', 'verifying', 'scoring', 'developing', 'regen_affiliate', 'image_prompt', 'enhance_image_prompt', 'compose_studio_prompt'
  ));
INSERT INTO public.llm_stage_defaults (stage, provider_id, model_id)
VALUES ('compose_studio_prompt', NULL, NULL)
ON CONFLICT (stage) DO NOTHING;
