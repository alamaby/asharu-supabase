-- 20260922000001 — error_digest_queue
-- Menyediakan queue event error integrasi (error_events) dan konfigurasi
-- notifikasi per kategori (error_notification_configs). Semua error
-- dari 8 kategori dicatat ke sini lalu diringkas jadi satu email digest
-- tiap jendela waktu. Best-effort write; kegagalan insert tidak mengubah
-- alur utama apa pun.

CREATE TABLE IF NOT EXISTS public.error_notification_configs (
  category text PRIMARY KEY CHECK (category IN (
    'tavily', 'llm', 'research', 'automation', 'scrape', 'cron_api', 'resend', 'image'
  )),
  is_enabled boolean NOT NULL DEFAULT true,
  digest_window_minutes int NOT NULL DEFAULT 30 CHECK (digest_window_minutes BETWEEN 5 AND 1440),
  notify_emails text[] NULL,
  last_digest_at timestamptz NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.error_notification_configs (category) VALUES
  ('tavily'), ('llm'), ('research'), ('automation'),
  ('scrape'), ('cron_api'), ('resend'), ('image')
ON CONFLICT (category) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.error_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category text NOT NULL CHECK (category IN (
    'tavily', 'llm', 'research', 'automation', 'scrape', 'cron_api', 'resend', 'image'
  )),
  source text NOT NULL,
  severity text NOT NULL DEFAULT 'error' CHECK (severity IN ('warning', 'error', 'critical')),
  stage text NULL,
  message text NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  session_id uuid NULL,
  run_id uuid NULL,
  fingerprint text NOT NULL DEFAULT '',
  notified_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_error_events_unnotified
  ON public.error_events (category, created_at) WHERE notified_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_error_events_fingerprint
  ON public.error_events (category, fingerprint);

ALTER TABLE public.error_notification_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.error_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "error_notification_configs_admin" ON public.error_notification_configs;
CREATE POLICY "error_notification_configs_admin" ON public.error_notification_configs
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "error_events_admin" ON public.error_events;
CREATE POLICY "error_events_admin" ON public.error_events
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
