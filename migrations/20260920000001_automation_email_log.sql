-- 20260920000001 — automation_email_log
-- Menjebak setiap percobaan kirim email automation (draft_ready / published / failure / test)
-- supaya operator bisa melihat di /admin/automation kenapa email kosong/gagal tanpa perlu
-- Resend Dashboard. Best-effort write dari runner; kegagalan insert TIDAK menggagalkan tick.
--
-- Pola RLS = admin-only (sama dengan automation_runs_admin di migrasi 20260915000003).

CREATE TABLE IF NOT EXISTS public.automation_email_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id uuid NULL REFERENCES public.automation_runs(id) ON DELETE CASCADE,
  run_date date NULL,
  slot_key text NULL,
  moment text NOT NULL CHECK (moment IN ('draft_ready', 'published', 'failure', 'test')),
  recipients text[] NOT NULL DEFAULT '{}',
  ok boolean NOT NULL DEFAULT false,
  skipped boolean NOT NULL DEFAULT false,
  resend_id text NULL,
  error text NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_automation_email_log_run
  ON public.automation_email_log (run_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_automation_email_log_date
  ON public.automation_email_log (run_date DESC);

ALTER TABLE public.automation_email_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "automation_email_log_admin" ON public.automation_email_log;
CREATE POLICY "automation_email_log_admin" ON public.automation_email_log
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
