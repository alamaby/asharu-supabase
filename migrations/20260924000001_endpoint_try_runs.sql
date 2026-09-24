-- Endpoint Try: riwayat eksperimen endpoint OpenAI/Anthropic arbitrer tanpa menyimpan key (2026-09-24)
-- Tab baru /lab/try: user login input baseUrl+kind+apiKey, list model, chat/streaming via proxy.
-- Tidak ada kolom key — hanya base_url (bukan secret) + snapshot metrik untuk observabilitas user.
-- Non-destruktif, aditif saja; reuse chat_lab_config.retention_days untuk retention (dibaca app).
-- Cron cleanup digabung ke /api/lab/cleanup yang sudah ada.

CREATE TABLE IF NOT EXISTS public.endpoint_try_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_kind text NOT NULL CHECK (provider_kind IN ('openai', 'anthropic')),
  base_url text NOT NULL CHECK (char_length(base_url) BETWEEN 10 AND 500),
  model text NOT NULL CHECK (char_length(model) BETWEEN 1 AND 200),
  system_prompt text NULL CHECK (system_prompt IS NULL OR char_length(system_prompt) <= 2000),
  user_prompt text NOT NULL CHECK (char_length(user_prompt) BETWEEN 10 AND 4000),
  temperature numeric NULL CHECK (temperature IS NULL OR (temperature >= 0 AND temperature <= 2)),
  max_tokens int NULL CHECK (max_tokens IS NULL OR (max_tokens BETWEEN 1 AND 4000)),
  prompt_tokens int NULL CHECK (prompt_tokens IS NULL OR prompt_tokens >= 0),
  completion_tokens int NULL CHECK (completion_tokens IS NULL OR completion_tokens >= 0),
  total_tokens int NULL CHECK (total_tokens IS NULL OR total_tokens >= 0),
  latency_ms int NULL CHECK (latency_ms IS NULL OR latency_ms >= 0),
  tokens_per_sec numeric NULL CHECK (tokens_per_sec IS NULL OR tokens_per_sec >= 0),
  finish_reason text NULL,
  error text NULL,
  request_messages jsonb NULL,
  response_text text NULL,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (error IS NOT NULL OR response_text IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_endpoint_try_runs_owner
  ON public.endpoint_try_runs (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_endpoint_try_runs_expiry
  ON public.endpoint_try_runs (expires_at ASC);

ALTER TABLE public.endpoint_try_runs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "endpoint_try_runs_owner_read" ON public.endpoint_try_runs;
CREATE POLICY "endpoint_try_runs_owner_read" ON public.endpoint_try_runs
  FOR SELECT TO authenticated USING (auth.uid() = user_id OR is_admin());

DROP POLICY IF EXISTS "endpoint_try_runs_owner_insert" ON public.endpoint_try_runs;
CREATE POLICY "endpoint_try_runs_owner_insert" ON public.endpoint_try_runs
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "endpoint_try_runs_admin" ON public.endpoint_try_runs;
CREATE POLICY "endpoint_try_runs_admin" ON public.endpoint_try_runs
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "endpoint_try_runs_service" ON public.endpoint_try_runs;
CREATE POLICY "endpoint_try_runs_service" ON public.endpoint_try_runs
  FOR ALL TO service_role USING (true) WITH CHECK (true);
