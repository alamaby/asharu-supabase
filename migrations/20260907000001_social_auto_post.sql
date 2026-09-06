-- Social auto-post (Threads tahap awal), non-destruktif, configurable by table.
-- Pola tiruan llm_stage_defaults: master accounts + global configs + queue + logs.
-- 1) social_accounts: 1 baris awal threads/@asharu.id (is_active=false sampai Fase 0 token siap).
-- 2) social_post_configs: 1 baris per platform (PK platform_slug), master switch + jadwal.
-- 3) social_post_queue: antrean terjadwal, idempoten per (draft_id, platform_slug).
-- 4) social_post_logs: audit per post dalam thread (opener + tiap reply).
-- Token long-lived TIDAK disimpan di kolom — hanya vault_secret_name (Vault by-name).

-- 1) Accounts
CREATE TABLE IF NOT EXISTS public.social_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  platform_slug text NOT NULL REFERENCES public.platforms(slug) ON DELETE RESTRICT,
  handle text NOT NULL DEFAULT '@asharu.id',
  threads_user_id text NULL,
  vault_secret_name text NOT NULL DEFAULT 'threads_access_token_asharu_id',
  token_suffix text NULL,
  scopes text[] NOT NULL DEFAULT '{threads_basic,threads_content_publish,threads_manage_replies}',
  token_expires_at timestamptz NULL,
  grant_expires_at timestamptz NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'disabled', 'token_expired')),
  priority int NOT NULL DEFAULT 10,
  is_active boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (platform_slug, handle)
);
CREATE INDEX IF NOT EXISTS idx_social_accounts_platform
  ON public.social_accounts (platform_slug, priority) WHERE is_active = true;

-- 2) Global configs per platform
CREATE TABLE IF NOT EXISTS public.social_post_configs (
  platform_slug text PRIMARY KEY REFERENCES public.platforms(slug) ON DELETE RESTRICT,
  is_enabled boolean NOT NULL DEFAULT false,
  auto_queue_on_approve boolean NOT NULL DEFAULT true,
  default_lang text NOT NULL DEFAULT 'id' CHECK (default_lang IN ('id', 'en')),
  allow_lang_override boolean NOT NULL DEFAULT true,
  daily_cap int NOT NULL DEFAULT 25 CHECK (daily_cap > 0 AND daily_cap <= 250),
  post_window_start time NOT NULL DEFAULT '07:00',
  post_window_end time NOT NULL DEFAULT '21:00',
  min_interval_minutes int NOT NULL DEFAULT 30 CHECK (min_interval_minutes >= 5),
  account_id uuid NULL REFERENCES public.social_accounts(id) ON DELETE SET NULL,
  updated_by uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Seed: threads disabled-default (aman sampai Fase 0 token siap)
INSERT INTO public.social_accounts (platform_slug, handle, vault_secret_name, is_active, priority, status)
VALUES ('threads', '@asharu.id', 'threads_access_token_asharu_id', false, 10, 'active')
ON CONFLICT (platform_slug, handle) DO NOTHING;

INSERT INTO public.social_post_configs (platform_slug, is_enabled, auto_queue_on_approve, default_lang, allow_lang_override, daily_cap, post_window_start, post_window_end, min_interval_minutes)
VALUES ('threads', false, true, 'id', true, 25, '07:00', '21:00', 30)
ON CONFLICT (platform_slug) DO NOTHING;

-- Pin seed account ke config (hanya bila config belum pin manual)
UPDATE public.social_post_configs c
SET account_id = a.id
FROM public.social_accounts a
WHERE c.platform_slug = 'threads' AND a.platform_slug = 'threads' AND a.handle = '@asharu.id'
  AND c.account_id IS NULL;

-- 3) Queue
CREATE TABLE IF NOT EXISTS public.social_post_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  draft_id uuid NOT NULL REFERENCES public.content_drafts(id) ON DELETE CASCADE,
  platform_slug text NOT NULL REFERENCES public.platforms(slug) ON DELETE RESTRICT,
  account_id uuid NULL REFERENCES public.social_accounts(id) ON DELETE SET NULL,
  lang text NOT NULL DEFAULT 'id' CHECK (lang IN ('id', 'en')),
  scheduled_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued', 'posting', 'posted', 'failed', 'canceled')),
  attempts int NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  last_error text NULL,
  idempotency_key text NOT NULL UNIQUE,
  posted_at timestamptz NULL,
  posted_url text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (draft_id, platform_slug)
);
CREATE INDEX IF NOT EXISTS idx_social_queue_due
  ON public.social_post_queue (status, scheduled_at) WHERE status = 'queued';
CREATE INDEX IF NOT EXISTS idx_social_queue_draft
  ON public.social_post_queue (draft_id);

-- 4) Logs per post dalam thread
CREATE TABLE IF NOT EXISTS public.social_post_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  queue_id uuid NOT NULL REFERENCES public.social_post_queue(id) ON DELETE CASCADE,
  draft_id uuid NOT NULL REFERENCES public.content_drafts(id) ON DELETE CASCADE,
  post_index int NOT NULL DEFAULT 0 CHECK (post_index >= 0),
  container_id text NULL,
  threads_media_id text NULL,
  status text NOT NULL DEFAULT 'created'
    CHECK (status IN ('created', 'published', 'failed')),
  error_code text NULL,
  quota_usage int NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_social_logs_queue
  ON public.social_post_logs (queue_id, post_index);
CREATE INDEX IF NOT EXISTS idx_social_logs_draft
  ON public.social_post_logs (draft_id);

-- RLS: admin read/write; service_role bypasses (worker). Anon: no access.
ALTER TABLE public.social_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_post_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_post_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_post_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "social_accounts_admin" ON public.social_accounts;
CREATE POLICY "social_accounts_admin" ON public.social_accounts
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "social_configs_admin" ON public.social_post_configs;
CREATE POLICY "social_configs_admin" ON public.social_post_configs
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "social_queue_admin" ON public.social_post_queue;
CREATE POLICY "social_queue_admin" ON public.social_post_queue
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "social_logs_admin" ON public.social_post_logs;
CREATE POLICY "social_logs_admin" ON public.social_post_logs
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
