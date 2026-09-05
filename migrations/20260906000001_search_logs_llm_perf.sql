-- Fix riset 815c8df8: log search generik + kolom perf LLM (non-destruktif)
-- search_call_logs generik via provider_slug (tavily/serper/brave/exa future-proof).
-- llm_call_logs: total_tokens, finish_reason, is_fallback untuk dashboard performa.

-- 1) llm_call_logs perf columns
ALTER TABLE public.llm_call_logs ADD COLUMN IF NOT EXISTS total_tokens int;
ALTER TABLE public.llm_call_logs ADD COLUMN IF NOT EXISTS finish_reason text;
ALTER TABLE public.llm_call_logs ADD COLUMN IF NOT EXISTS is_fallback boolean NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS idx_llm_logs_session ON public.llm_call_logs(session_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_llm_logs_stage ON public.llm_call_logs(stage, created_at DESC);

-- 2) search_call_logs (generik, bukan tavily_* agar ganti provider aman)
CREATE TABLE IF NOT EXISTS public.search_call_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid REFERENCES public.content_research_sessions(id) ON DELETE CASCADE,
  provider_slug text NOT NULL DEFAULT 'tavily',
  operation text NOT NULL DEFAULT 'search' CHECK (operation IN ('search', 'extract')),
  queries jsonb NOT NULL DEFAULT '[]'::jsonb,
  query_count int NOT NULL DEFAULT 0,
  latency_ms int,
  result_count int,
  http_status int,
  error text,
  request_payload jsonb,
  response_summary jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_search_logs_session ON public.search_call_logs(session_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_search_logs_provider ON public.search_call_logs(provider_slug, created_at DESC);

ALTER TABLE public.search_call_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "search_logs_admin_read" ON public.search_call_logs;
CREATE POLICY "search_logs_admin_read" ON public.search_call_logs
  FOR SELECT TO authenticated USING (is_admin());
DROP POLICY IF EXISTS "search_logs_no_read" ON public.search_call_logs;
CREATE POLICY "search_logs_no_read" ON public.search_call_logs
  FOR SELECT TO anon USING (false);
