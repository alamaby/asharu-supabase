-- Content pipeline 4-tahap (2 Sep)
-- Persistent DB stages replacing single-pass processor.
-- Tables: content_research_sessions, content_research_topics,
-- content_research_logs. Extends content_drafts with research_topic_id,
-- affiliate_match_score/signals, affiliate_swap_history.
-- Drops strict one_injection CHECK (length=1) -> optional_injection
-- (length<=1) so admins can remove a product without breaking the row.
-- Adds RPC advance_research_stage (atomic state transition).
-- Reschedules pg_cron: research 10 min, legacy 5 min.

------------------------------------------------------------
-- 1. content_research_sessions
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.content_research_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN (
      'pending', 'discovering', 'verifying', 'scoring',
      'awaiting_selection', 'developing', 'completed', 'failed'
    )),
  target_location text,
  secondary_location text,
  audience_age text,
  audience_interests text[] DEFAULT '{}',
  platform_slug text REFERENCES public.platforms(slug),
  tone text,
  account_goal text,
  allowed_categories text[] DEFAULT '{}',
  excluded_categories text[] DEFAULT '{}',
  freshness_hours int NOT NULL DEFAULT 24,
  minimum_candidates int NOT NULL DEFAULT 12,
  minimum_score numeric NOT NULL DEFAULT 6.0,
  required_winners int NOT NULL DEFAULT 3,
  maximum_iterations int NOT NULL DEFAULT 3,
  current_stage_started_at timestamptz NOT NULL DEFAULT now(),
  error_message text,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_research_sessions_status
  ON public.content_research_sessions (status, current_stage_started_at);

------------------------------------------------------------
-- 2. content_research_topics
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.content_research_topics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.content_research_sessions(id) ON DELETE CASCADE,
  rank int,
  topic text NOT NULL,
  category text,
  why_now text,
  audience_relevance text,
  key_facts jsonb NOT NULL DEFAULT '[]'::jsonb,
  unique_angle text,
  hooks jsonb NOT NULL DEFAULT '[]'::jsonb,
  recommended_format text,
  recommended_platform text[] DEFAULT '{}',
  potential_risk text,
  verification_status text NOT NULL DEFAULT 'pending'
    CHECK (verification_status IN ('verified', 'unverified', 'rejected', 'pending')),
  sources jsonb NOT NULL DEFAULT '[]'::jsonb,
  score_breakdown jsonb NOT NULL DEFAULT '{}'::jsonb,
  final_score numeric,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'shortlisted', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_research_topics_session
  ON public.content_research_topics (session_id, rank);

------------------------------------------------------------
-- 3. content_research_logs
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.content_research_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.content_research_sessions(id) ON DELETE CASCADE,
  stage text NOT NULL,
  level text NOT NULL DEFAULT 'info' CHECK (level IN ('info', 'warn', 'error')),
  message text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_research_logs_session
  ON public.content_research_logs (session_id, created_at);

------------------------------------------------------------
-- 4. Extend content_drafts
------------------------------------------------------------
ALTER TABLE public.content_drafts
  ADD COLUMN IF NOT EXISTS research_topic_id uuid
    REFERENCES public.content_research_topics(id) ON DELETE SET NULL;

ALTER TABLE public.content_drafts
  ADD COLUMN IF NOT EXISTS affiliate_match_score int;

ALTER TABLE public.content_drafts
  ADD COLUMN IF NOT EXISTS affiliate_match_signals jsonb;

ALTER TABLE public.content_drafts
  ADD COLUMN IF NOT EXISTS affiliate_swap_history jsonb NOT NULL DEFAULT '[]'::jsonb;

-- Relax injection constraint: 0 or 1 (was exactly 1)
ALTER TABLE public.content_drafts DROP CONSTRAINT IF EXISTS one_injection;
ALTER TABLE public.content_drafts
  ADD CONSTRAINT optional_injection
  CHECK (jsonb_array_length(affiliate_injections) <= 1);

------------------------------------------------------------
-- 5. RPC: atomic stage transition
------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.advance_research_stage(p_session_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current text;
BEGIN
  SELECT status INTO v_current
    FROM public.content_research_sessions
   WHERE id = p_session_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RETURN 'not_found';
  END IF;
  -- Stamp current stage start so the cron job can pick the row up
  UPDATE public.content_research_sessions
     SET current_stage_started_at = now(),
         updated_at = now()
   WHERE id = p_session_id;
  RETURN v_current;
END;
$$;

REVOKE ALL ON FUNCTION public.advance_research_stage(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.advance_research_stage(uuid) TO service_role;

------------------------------------------------------------
-- 6. RLS
------------------------------------------------------------
ALTER TABLE public.content_research_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_research_topics  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_research_logs    ENABLE ROW LEVEL SECURITY;

-- Sessions: admin read/write; service_role bypasses
DROP POLICY IF EXISTS "research_sessions_admin_read"   ON public.content_research_sessions;
CREATE POLICY "research_sessions_admin_read"   ON public.content_research_sessions
  FOR SELECT TO authenticated USING (is_admin());
DROP POLICY IF EXISTS "research_sessions_admin_write"  ON public.content_research_sessions;
CREATE POLICY "research_sessions_admin_write"  ON public.content_research_sessions
  FOR UPDATE TO authenticated USING (is_admin());

-- Topics: admin read; service_role writes
DROP POLICY IF EXISTS "research_topics_admin_read"      ON public.content_research_topics;
CREATE POLICY "research_topics_admin_read"      ON public.content_research_topics
  FOR SELECT TO authenticated USING (is_admin());

-- Logs: admin read
DROP POLICY IF EXISTS "research_logs_admin_read"        ON public.content_research_logs;
CREATE POLICY "research_logs_admin_read"        ON public.content_research_logs
  FOR SELECT TO authenticated USING (is_admin());

------------------------------------------------------------
-- 7. pg_cron reschedule
--    - drop old 'process-content-requests' (5 min, x-vercel-cron header)
--    - create 'asharu-content-research' (10 min, Bearer from Vault)
--    - create 'asharu-content-legacy' (5 min, Bearer, old processor)
------------------------------------------------------------
SELECT cron.unschedule('process-content-requests') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'process-content-requests'
);

-- Research pipeline (10 min, /api/content/process)
SELECT cron.schedule(
  'asharu-content-research',
  '*/10 * * * *',
  $job$
    SELECT net.http_post(
      url := 'https://asharu.id/api/content/process',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'asharu_cron_secret' ORDER BY created_at DESC LIMIT 1),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 290000
    );
  $job$
);

-- Legacy direct content_requests (5 min, /api/content/process-legacy)
SELECT cron.schedule(
  'asharu-content-legacy',
  '*/5 * * * *',
  $job$
    SELECT net.http_post(
      url := 'https://asharu.id/api/content/process-legacy',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'asharu_cron_secret' ORDER BY created_at DESC LIMIT 1),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 55000
    );
  $job$
);
