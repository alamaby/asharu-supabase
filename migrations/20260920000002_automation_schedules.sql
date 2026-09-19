-- 20260920000002 — automation_schedules + slot_key di automation_runs
-- Mengubah pola "1 slot/hari" menjadi N slot per hari.
-- Urutan penting: tabel slot dibuat dulu (seed dari config), lalu
-- kolom slot_key ditambahkan di runs SEBELUM constraint UNIQUE baru,
-- agar tidak gagal pada database berisi data existing.
--
-- weekdays bitmask: bit0=Senin ... bit6=Minggu, 127 = tiap hari.
-- Contoh: Senin–Jumat = 31, Sabtu+Minggu = 96.

------------------------------------------------------------
-- 1. Tabel automation_schedules (slot harian)
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.automation_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_key text NOT NULL UNIQUE CHECK (slot_key ~ '^[a-z0-9-]{1,32}$'),
  label text NOT NULL DEFAULT '',
  hour int NOT NULL CHECK (hour BETWEEN 0 AND 23),
  minute int NOT NULL DEFAULT 0 CHECK (minute BETWEEN 0 AND 59),
  weekdays smallint NOT NULL DEFAULT 127 CHECK (weekdays BETWEEN 0 AND 127),
  is_enabled boolean NOT NULL DEFAULT true,
  window_minutes int NULL CHECK (window_minutes IS NULL OR window_minutes BETWEEN 5 AND 720),
  priority int NOT NULL DEFAULT 0,
  -- Override per slot: NULL = warisi global (diisi Fase 3).
  platform_slugs text[] NULL,
  max_topics int NULL CHECK (max_topics IS NULL OR max_topics BETWEEN 1 AND 10),
  product_pool_size int NULL CHECK (product_pool_size IS NULL OR product_pool_size BETWEEN 1 AND 500),
  product_category text NULL,
  auto_publish_article boolean NULL,
  require_cover boolean NULL,
  notify_on text NULL CHECK (notify_on IS NULL OR notify_on IN ('draft_ready','published','both','none')),
  notify_emails text[] NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.automation_schedules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "automation_schedules_admin" ON public.automation_schedules;
CREATE POLICY "automation_schedules_admin" ON public.automation_schedules
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

------------------------------------------------------------
-- 2. Seed jadwal singleton existing → slot 'default'
--    Agar instalasi pre-migrasi tetap berjalan tanpa perubahan perilaku.
------------------------------------------------------------
INSERT INTO public.automation_schedules (slot_key, label, hour, minute, weekdays, is_enabled, priority)
SELECT 'default', 'Jadwal utama (migrasi)', schedule_hour, schedule_minute, 127, is_enabled, 0
FROM public.automation_configs
WHERE id = 1
ON CONFLICT (slot_key) DO NOTHING;

------------------------------------------------------------
-- 3. Kolom slot_key di automation_runs + backfill sebelum constraint baru
------------------------------------------------------------
ALTER TABLE public.automation_runs
  ADD COLUMN IF NOT EXISTS slot_key text NOT NULL DEFAULT 'default';

UPDATE public.automation_runs SET slot_key = 'default' WHERE slot_key IS NULL OR slot_key = '';

------------------------------------------------------------
-- 4. Ganti UNIQUE(run_date) → UNIQUE(run_date, slot_key)
--    Pitfall: nama constraint bawaan bisa berbeda. Drop dulu berdasarkan
--    pola *run_date_key* bila ada, baru tambah yang baru.
------------------------------------------------------------
DO $$
BEGIN
  -- Drop UNIQUE lama berdasarkan run_date (nama eksak bergantung versi pg).
  ALTER TABLE public.automation_runs DROP CONSTRAINT IF EXISTS automation_runs_run_date_key;
  ALTER TABLE public.automation_runs DROP CONSTRAINT IF EXISTS automation_runs_run_date_fkey;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.automation_runs'::regclass
      AND conname = 'automation_runs_date_slot_key'
  ) THEN
    ALTER TABLE public.automation_runs
      ADD CONSTRAINT automation_runs_date_slot_key UNIQUE (run_date, slot_key);
  END IF;
END $$;
