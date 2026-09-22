-- 20260922000003 — automation_product_blackout
-- Menambah kolom product_repeat_blackout_days untuk mengontrol interval blackout produk
-- agar tidak dipilih ulang dalam N hari terakhir.
--
-- automation_configs: kolom global (DEFAULT 14, CHECK 0-90)
-- automation_schedules: kolom override per-slot (NULL = warisi global, CHECK 0-90)
-- Tanpa RLS baru (policy FOR ALL existing sudah mencakup semua kolom).
-- Idempotent dengan IF NOT EXISTS.

ALTER TABLE public.automation_configs
  ADD COLUMN IF NOT EXISTS product_repeat_blackout_days int NOT NULL DEFAULT 14
  CHECK (product_repeat_blackout_days BETWEEN 0 AND 90);

ALTER TABLE public.automation_schedules
  ADD COLUMN IF NOT EXISTS product_repeat_blackout_days int NULL
  CHECK (product_repeat_blackout_days IS NULL OR product_repeat_blackout_days BETWEEN 0 AND 90);
