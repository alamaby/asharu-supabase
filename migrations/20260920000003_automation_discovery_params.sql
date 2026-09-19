-- 20260920000003 — discovery params global + per-slot
-- Menambah knob discovery yang sebelumnya hardcoded / ambigu di runner.
-- Global: NOT NULL ber-default konservatif (perilaku existing tak berubah).
-- Slot: NULL-warisi; merge dilakukan di kode (schedules.ts mergeSlotParams).

ALTER TABLE public.automation_configs
  ADD COLUMN IF NOT EXISTS maximum_iterations int NOT NULL DEFAULT 1 CHECK (maximum_iterations BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS minimum_score numeric NULL CHECK (minimum_score IS NULL OR minimum_score BETWEEN 0 AND 100),
  ADD COLUMN IF NOT EXISTS minimum_candidates int NULL CHECK (minimum_candidates IS NULL OR minimum_candidates BETWEEN 1 AND 50),
  ADD COLUMN IF NOT EXISTS freshness_hours int NULL CHECK (freshness_hours IS NULL OR freshness_hours BETWEEN 1 AND 720);

ALTER TABLE public.automation_schedules
  ADD COLUMN IF NOT EXISTS maximum_iterations int NULL CHECK (maximum_iterations IS NULL OR maximum_iterations BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS minimum_score numeric NULL CHECK (minimum_score IS NULL OR minimum_score BETWEEN 0 AND 100),
  ADD COLUMN IF NOT EXISTS minimum_candidates int NULL CHECK (minimum_candidates IS NULL OR minimum_candidates BETWEEN 1 AND 50),
  ADD COLUMN IF NOT EXISTS freshness_hours int NULL CHECK (freshness_hours IS NULL OR freshness_hours BETWEEN 1 AND 720),
  ADD COLUMN IF NOT EXISTS cover_max_wait_minutes int NULL CHECK (cover_max_wait_minutes IS NULL OR cover_max_wait_minutes BETWEEN 5 AND 720),
  ADD COLUMN IF NOT EXISTS cover_max_attempts int NULL CHECK (cover_max_attempts IS NULL OR cover_max_attempts BETWEEN 1 AND 10),
  ADD COLUMN IF NOT EXISTS max_retry_attempts int NULL CHECK (max_retry_attempts IS NULL OR max_retry_attempts BETWEEN 0 AND 10),
  ADD COLUMN IF NOT EXISTS language text NULL,
  ADD COLUMN IF NOT EXISTS tone text NULL,
  ADD COLUMN IF NOT EXISTS audience text NULL,
  ADD COLUMN IF NOT EXISTS purpose text NULL,
  ADD COLUMN IF NOT EXISTS cta_style text NULL,
  ADD COLUMN IF NOT EXISTS target_reply_count int NULL CHECK (target_reply_count IS NULL OR target_reply_count BETWEEN 1 AND 10),
  ADD COLUMN IF NOT EXISTS template_slug text NULL REFERENCES public.research_templates(slug) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS idea_generation_enabled boolean NULL,
  ADD COLUMN IF NOT EXISTS idea_product_search boolean NULL,
  ADD COLUMN IF NOT EXISTS email_from text NULL,
  ADD COLUMN IF NOT EXISTS email_reply_to text NULL;
