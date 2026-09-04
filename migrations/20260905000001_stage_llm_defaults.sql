-- Per-stage LLM provider/model overrides — 2026-09-05
-- - llm_stage_defaults: global admin defaults (1 row per stage)
-- - content_research_sessions: per-session overrides (nullable, FK → llm_models)
-- - content_drafts: audit last regen_affiliate model
-- Stages: idea_generation, discovering, verifying, scoring, developing, regen_affiliate
-- Fallback: NULL = use existing global waterfall (priority/last_used_at)

-- 1) Global defaults table (admin only)
CREATE TABLE IF NOT EXISTS public.llm_stage_defaults (
  stage text PRIMARY KEY CHECK (stage IN (
    'idea_generation', 'discovering', 'verifying', 'scoring', 'developing', 'regen_affiliate'
  )),
  provider_id uuid REFERENCES public.llm_providers(id) ON DELETE SET NULL,
  model_id uuid REFERENCES public.llm_models(id) ON DELETE SET NULL,
  -- provider_id and model_id must both be set or both NULL (no half-pin)
  CHECK ((provider_id IS NULL) = (model_id IS NULL)),
  updated_by uuid REFERENCES auth.users(id),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Ensure exactly 6 rows exist (NULL = global waterfall)
INSERT INTO public.llm_stage_defaults (stage, provider_id, model_id)
VALUES
  ('idea_generation', NULL, NULL),
  ('discovering', NULL, NULL),
  ('verifying', NULL, NULL),
  ('scoring', NULL, NULL),
  ('developing', NULL, NULL),
  ('regen_affiliate', NULL, NULL)
ON CONFLICT (stage) DO NOTHING;

-- RLS: admin read/write; service_role bypasses
ALTER TABLE public.llm_stage_defaults ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "stage_defaults_admin_read" ON public.llm_stage_defaults;
CREATE POLICY "stage_defaults_admin_read" ON public.llm_stage_defaults
  FOR SELECT TO authenticated USING (is_admin());
DROP POLICY IF EXISTS "stage_defaults_admin_write" ON public.llm_stage_defaults;
CREATE POLICY "stage_defaults_admin_write" ON public.llm_stage_defaults
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

-- 2) Per-session overrides — nullable; FK SET NULL so deleting a model doesn't break history
ALTER TABLE public.content_research_sessions
  ADD COLUMN IF NOT EXISTS idea_generation_model_id uuid REFERENCES public.llm_models(id) ON DELETE SET NULL;
ALTER TABLE public.content_research_sessions
  ADD COLUMN IF NOT EXISTS discovering_model_id uuid REFERENCES public.llm_models(id) ON DELETE SET NULL;
ALTER TABLE public.content_research_sessions
  ADD COLUMN IF NOT EXISTS verifying_model_id uuid REFERENCES public.llm_models(id) ON DELETE SET NULL;
ALTER TABLE public.content_research_sessions
  ADD COLUMN IF NOT EXISTS scoring_model_id uuid REFERENCES public.llm_models(id) ON DELETE SET NULL;
ALTER TABLE public.content_research_sessions
  ADD COLUMN IF NOT EXISTS developing_model_id uuid REFERENCES public.llm_models(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_sessions_idea_gen_model ON public.content_research_sessions(idea_generation_model_id);
CREATE INDEX IF NOT EXISTS idx_sessions_discovering_model ON public.content_research_sessions(discovering_model_id);
CREATE INDEX IF NOT EXISTS idx_sessions_verifying_model ON public.content_research_sessions(verifying_model_id);
CREATE INDEX IF NOT EXISTS idx_sessions_scoring_model ON public.content_research_sessions(scoring_model_id);
CREATE INDEX IF NOT EXISTS idx_sessions_developing_model ON public.content_research_sessions(developing_model_id);

-- 3) Audit last regen model on drafts (for review regen)
ALTER TABLE public.content_drafts
  ADD COLUMN IF NOT EXISTS last_regen_model_id uuid REFERENCES public.llm_models(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_drafts_last_regen_model ON public.content_drafts(last_regen_model_id);
