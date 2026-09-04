-- Review fixes for per-stage LLM (2026-09-05) — non-destructive
-- P0-01 warn FK guard alternative (app-side), P1-16/20 updated_by, indexes, CHECK doc
-- All IF NOT EXISTS / DROP IF EXISTS so re-run safe.

-- 1) llm_stage_defaults.updated_by → ON DELETE SET NULL (P1-20)
-- Add FK constraint with correct ON DELETE if missing; drop old without clause first.
DO $$
BEGIN
  -- Drop any existing FK without ON DELETE SET NULL by name discovery
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'llm_stage_defaults_updated_by_fkey') THEN
    ALTER TABLE public.llm_stage_defaults DROP CONSTRAINT llm_stage_defaults_updated_by_fkey;
  END IF;
END $$;
ALTER TABLE public.llm_stage_defaults
  ADD CONSTRAINT llm_stage_defaults_updated_by_fkey
  FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

-- updated_at auto-touch trigger (P2-14, manual set still works)
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;
DROP TRIGGER IF EXISTS trg_llm_stage_defaults_updated_at ON public.llm_stage_defaults;
CREATE TRIGGER trg_llm_stage_defaults_updated_at
  BEFORE UPDATE ON public.llm_stage_defaults
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- Additional indexes for SET NULL cascade perf (P2-02)
CREATE INDEX IF NOT EXISTS idx_stage_defaults_provider ON public.llm_stage_defaults(provider_id);
CREATE INDEX IF NOT EXISTS idx_stage_defaults_model ON public.llm_stage_defaults(model_id);
CREATE INDEX IF NOT EXISTS idx_stage_defaults_updated_by ON public.llm_stage_defaults(updated_by);

-- Document: content_research_logs.session_id warn with null sessionId is app-guarded (P0-01)
COMMENT ON TABLE public.llm_stage_defaults IS 'Global per-stage LLM defaults. NULL model_id = global waterfall. App guards: pinned model must be is_active; content_research_logs warn only when session_id not null.';
