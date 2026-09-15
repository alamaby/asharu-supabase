-- Automation riset harian → artikel (15 Sep 2026).
-- Non-destruktif, idempotent, configurable by table (pola social_post_configs /
-- image_gen_defaults). Dua tabel:
--   1) automation_configs  : singleton id=1; semua knob perilaku automation.
--   2) automation_runs     : 1 baris per hari (UNIQUE run_date), jejak run + status.
-- Worker: POST /api/automation/run (Bearer-from-Vault), dijadwalkan
-- terpisah oleh 20260915000004_automation_cron.sql.
-- Default AMAN: is_enabled=false → cron no-op sampai admin menyalakan.

------------------------------------------------------------
-- 1. automation_configs (singleton id=1)
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.automation_configs (
  id int PRIMARY KEY CHECK (id = 1),
  is_enabled boolean NOT NULL DEFAULT false,
  -- Jadwal lokal per timezone config
  schedule_hour int NOT NULL DEFAULT 10 CHECK (schedule_hour BETWEEN 0 AND 23),
  schedule_minute int NOT NULL DEFAULT 0 CHECK (schedule_minute BETWEEN 0 AND 59),
  timezone text NOT NULL DEFAULT 'Asia/Jakarta',
  -- Jendela toleransi: run hanya dibuat bila waktu lokal berada di
  -- [target, target + window). Mencegah run tengah malam bila admin baru
  -- menyalakan is_enabled setelah jam target lewat jauh.
  schedule_window_minutes int NOT NULL DEFAULT 180 CHECK (schedule_window_minutes BETWEEN 5 AND 1440),
  -- Sesi riset yang dibuat (mekanisme dua / produk-terpilih)
  mechanism text NOT NULL DEFAULT 'dua' CHECK (mechanism IN ('satu', 'dua')),
  platform_slugs text[] NOT NULL DEFAULT '{artikel,twitter,threads}',
  template_slug text REFERENCES public.research_templates(slug) ON DELETE SET NULL,
  max_topics int NOT NULL DEFAULT 1 CHECK (max_topics BETWEEN 1 AND 10),
  language text NOT NULL DEFAULT 'both' CHECK (language IN ('id', 'en', 'both')),
  tone text NOT NULL DEFAULT 'casual',
  audience text NOT NULL DEFAULT 'umum',
  purpose text NOT NULL DEFAULT 'membagikan informasi bermanfaat',
  cta_style text NOT NULL DEFAULT 'soft_sell',
  target_reply_count int NULL CHECK (target_reply_count IS NULL OR target_reply_count BETWEEN 1 AND 10),
  -- Pemilihan produk acak
  product_pool_size int NOT NULL DEFAULT 50 CHECK (product_pool_size BETWEEN 1 AND 500),
  product_category text NULL,
  -- Gate cover/visualisasi utama sebelum publish
  require_cover boolean NOT NULL DEFAULT true,
  cover_max_wait_minutes int NOT NULL DEFAULT 60 CHECK (cover_max_wait_minutes BETWEEN 5 AND 720),
  cover_max_attempts int NOT NULL DEFAULT 3 CHECK (cover_max_attempts BETWEEN 1 AND 10),
  -- Publish + notifikasi
  auto_publish_article boolean NOT NULL DEFAULT true,
  -- Retry otomatis dalam hari: bila true, sesi/run yang failed boleh dicoba
  -- ulang pada tick berikutnya (attempts < max_retry_attempts).
  max_retry_attempts int NOT NULL DEFAULT 3 CHECK (max_retry_attempts BETWEEN 0 AND 10),
  notify_on text NOT NULL DEFAULT 'both'
    CHECK (notify_on IN ('draft_ready', 'published', 'both', 'none')),
  notify_emails text[] NOT NULL DEFAULT '{}',
  email_from text NOT NULL DEFAULT 'Asharu <notifikasi@asharu.id>',
  email_reply_to text NULL,
  last_run_at timestamptz NULL,
  updated_by uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.automation_configs (id) VALUES (1)
ON CONFLICT (id) DO NOTHING;

------------------------------------------------------------
-- 2. automation_runs (1 baris per hari lokal)
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.automation_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  run_date date NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'session_created'
    CHECK (status IN (
      'session_created', 'developing', 'awaiting_cover',
      'publishing', 'published', 'notifying', 'completed', 'failed'
    )),
  config_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  product_id uuid NULL REFERENCES public.affiliate_products(id) ON DELETE SET NULL,
  session_id uuid NULL REFERENCES public.content_research_sessions(id) ON DELETE SET NULL,
  article_draft_id uuid NULL REFERENCES public.content_drafts(id) ON DELETE SET NULL,
  article_ids uuid[] NOT NULL DEFAULT '{}',
  cover_attempts int NOT NULL DEFAULT 0 CHECK (cover_attempts >= 0),
  cover_started_at timestamptz NULL,
  draft_ready_notified_at timestamptz NULL,
  published_at timestamptz NULL,
  notified_at timestamptz NULL,
  error_message text NULL,
  attempts int NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_automation_runs_status
  ON public.automation_runs (status, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_automation_runs_date
  ON public.automation_runs (run_date DESC);

------------------------------------------------------------
-- 3. RLS: admin-only (worker pakai service_role → bypass)
------------------------------------------------------------
ALTER TABLE public.automation_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.automation_runs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "automation_configs_admin" ON public.automation_configs;
CREATE POLICY "automation_configs_admin" ON public.automation_configs
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "automation_runs_admin" ON public.automation_runs;
CREATE POLICY "automation_runs_admin" ON public.automation_runs
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
