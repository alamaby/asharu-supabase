-- Chat Lab: uji provider/model chat untuk user login (2026-09-17)
-- Menu baru /lab: 1 prompt -> 1-3 target paralel (non-streaming fase 1),
-- respons side-by-side + metrik token/latency/speed/throughput + histori
-- per-user 30 hari + log detail + chart statistik. Studio tetap khusus image.
-- Non-destruktif, aditif saja:
-- 1) chat_lab_config: singleton id=1 (retention, daily_limit, max_targets, default temp/max_tokens)
-- 2) chat_lab_batches: 1 baris = 1 submit komparasi milik user
-- 3) chat_lab_runs: 1 baris = 1 target dalam batch (snapshot slug + metrik)
-- 4) Cron: asharu-lab-cleanup (harian 02:00 WIB ~ 19:00 UTC)
-- Key material TIDAK di kolom — reuse llm_provider_keys + Vault by-name.
-- Setiap run juga tercatat di llm_call_logs (stage='chat_lab') oleh app.

-- 1) Config lab (singleton id=1)
CREATE TABLE IF NOT EXISTS public.chat_lab_config (
  id int PRIMARY KEY CHECK (id = 1),
  retention_days int NOT NULL DEFAULT 30 CHECK (retention_days BETWEEN 1 AND 365),
  daily_limit int NULL DEFAULT 50 CHECK (daily_limit IS NULL OR daily_limit BETWEEN 1 AND 1000),
  max_targets int NOT NULL DEFAULT 3 CHECK (max_targets BETWEEN 1 AND 5),
  default_temperature numeric NULL DEFAULT 0.7 CHECK (default_temperature IS NULL OR (default_temperature >= 0 AND default_temperature <= 2)),
  default_max_tokens int NOT NULL DEFAULT 1000 CHECK (default_max_tokens BETWEEN 1 AND 8000),
  updated_by uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.chat_lab_config (id) VALUES (1)
ON CONFLICT (id) DO NOTHING;

-- 2) Batch komparasi per user
CREATE TABLE IF NOT EXISTS public.chat_lab_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  system_prompt text NULL CHECK (system_prompt IS NULL OR char_length(system_prompt) <= 2000),
  user_prompt text NOT NULL CHECK (char_length(user_prompt) BETWEEN 10 AND 4000),
  temperature numeric NULL CHECK (temperature IS NULL OR (temperature >= 0 AND temperature <= 2)),
  max_tokens int NULL CHECK (max_tokens IS NULL OR (max_tokens BETWEEN 1 AND 8000)),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_chat_lab_batches_owner
  ON public.chat_lab_batches (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_lab_batches_expiry
  ON public.chat_lab_batches (expires_at ASC);

-- 3) Run per target dalam batch
CREATE TABLE IF NOT EXISTS public.chat_lab_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id uuid NOT NULL REFERENCES public.chat_lab_batches(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_id uuid NULL REFERENCES public.llm_providers(id) ON DELETE SET NULL,
  model_id uuid NULL REFERENCES public.llm_models(id) ON DELETE SET NULL,
  provider_slug text NOT NULL DEFAULT '',
  model_slug text NOT NULL DEFAULT '',
  prompt_tokens int NULL CHECK (prompt_tokens IS NULL OR prompt_tokens >= 0),
  completion_tokens int NULL CHECK (completion_tokens IS NULL OR completion_tokens >= 0),
  total_tokens int NULL CHECK (total_tokens IS NULL OR total_tokens >= 0),
  thought_tokens int NULL CHECK (thought_tokens IS NULL OR thought_tokens >= 0),
  latency_ms int NULL CHECK (latency_ms IS NULL OR latency_ms >= 0),
  tokens_per_sec numeric NULL CHECK (tokens_per_sec IS NULL OR tokens_per_sec >= 0),
  -- Fase 2 streaming (SSE): TTFT + inter-token. Fase 1 selalu NULL.
  ttft_ms int NULL CHECK (ttft_ms IS NULL OR ttft_ms >= 0),
  finish_reason text NULL,
  is_fallback boolean NOT NULL DEFAULT false,
  response_truncated boolean NOT NULL DEFAULT false,
  http_status int NULL,
  error text NULL,
  request_messages jsonb NULL,
  response_text text NULL,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (error IS NOT NULL OR response_text IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS idx_chat_lab_runs_batch
  ON public.chat_lab_runs (batch_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_chat_lab_runs_owner
  ON public.chat_lab_runs (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_lab_runs_expiry
  ON public.chat_lab_runs (expires_at ASC);
CREATE INDEX IF NOT EXISTS idx_chat_lab_runs_provider
  ON public.chat_lab_runs (provider_slug, model_slug, created_at DESC);

-- RLS
ALTER TABLE public.chat_lab_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_lab_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_lab_runs ENABLE ROW LEVEL SECURITY;

-- Config: admin only (tiru image_studio_config)
DROP POLICY IF EXISTS "chat_lab_config_admin" ON public.chat_lab_config;
CREATE POLICY "chat_lab_config_admin" ON public.chat_lab_config
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

-- Batches: owner read/insert; tulis status hanya service_role/admin.
-- Delete owner dilayani via server action (service_role) agar runs ikut CASCADE atomik.
DROP POLICY IF EXISTS "chat_lab_batches_owner_read" ON public.chat_lab_batches;
CREATE POLICY "chat_lab_batches_owner_read" ON public.chat_lab_batches
  FOR SELECT TO authenticated USING (auth.uid() = user_id OR is_admin());
DROP POLICY IF EXISTS "chat_lab_batches_owner_insert" ON public.chat_lab_batches;
CREATE POLICY "chat_lab_batches_owner_insert" ON public.chat_lab_batches
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "chat_lab_batches_admin" ON public.chat_lab_batches;
CREATE POLICY "chat_lab_batches_admin" ON public.chat_lab_batches
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "chat_lab_batches_service" ON public.chat_lab_batches;
CREATE POLICY "chat_lab_batches_service" ON public.chat_lab_batches
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Runs: pola sama dengan batches
DROP POLICY IF EXISTS "chat_lab_runs_owner_read" ON public.chat_lab_runs;
CREATE POLICY "chat_lab_runs_owner_read" ON public.chat_lab_runs
  FOR SELECT TO authenticated USING (auth.uid() = user_id OR is_admin());
DROP POLICY IF EXISTS "chat_lab_runs_owner_insert" ON public.chat_lab_runs;
CREATE POLICY "chat_lab_runs_owner_insert" ON public.chat_lab_runs
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "chat_lab_runs_admin" ON public.chat_lab_runs;
CREATE POLICY "chat_lab_runs_admin" ON public.chat_lab_runs
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "chat_lab_runs_service" ON public.chat_lab_runs;
CREATE POLICY "chat_lab_runs_service" ON public.chat_lab_runs
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 4) Cleanup harian 19:00 UTC (= 02:00 WIB): hapus batch expired (runs CASCADE).
-- App membaca chat_lab_config.retention_days secara live saat insert.
SELECT cron.schedule(
  'asharu-lab-cleanup',
  '0 19 * * *',
  $job$
    SELECT net.http_post(
      url := 'https://asharu.id/api/lab/cleanup',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'asharu_cron_secret' ORDER BY created_at DESC LIMIT 1),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 120000
    );
  $job$
);
