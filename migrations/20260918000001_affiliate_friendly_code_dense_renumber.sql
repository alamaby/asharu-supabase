-- Migration: Affiliate friendly_code dense renumber + burn-stop generator
-- Date: 2026-09-18
-- Purpose: rapatkan ASH-XXX menjadi urut 1..N sesuai urutan produk ditambahkan,
--          hentikan sequence burn dari speculative BEFORE INSERT trigger,
--          jaga keotentikan snapshot draf via tabel pemetaan.
--
-- Asumsi:
--   - affiliate_products.friendly_code UNIQUE, external_id UNIQUE.
--   - Scraper nanti akan kirim friendly_code eksplisit per external_id baru
--     (MAX+1 per batch). Trigger hanya mem-backup bila NULL (writer lain).
--   - Workflow scrape sudah pakai concurrency group per `scrape-affiliate.yml`.
--
-- Rollback (jika gagal sebelum commit):
--   SELECT rollback_old FROM affiliate_friendly_remap ORDER BY row_number;
--   DROP FUNCTION gen_friendly_code();
--   DROP TRIGGER trg_friendly ON affiliate_products;
--   DROP TABLE affiliate_friendly_remap;
--   DROP SEQUENCE IF EXISTS affiliate_friendly_seq;

BEGIN;

------------------------------------------------------------
-- 1. Cegah scrape berjalan saat migrasi (exclusive lock pada tabel).
------------------------------------------------------------
LOCK TABLE public.affiliate_products IN EXCLUSIVE MODE;
-- NOTE: jika ada transaksi open yang memegang SHARE/ROW SHARE, LOCK ini akan
-- menuggu. Workflow scrape punya concurrency.group = scrape-affiliate sehingga
-- tidak ada transaksi scraper lain yang beririsan secara normal.

------------------------------------------------------------
-- 2. Buat tabel reman permanen (dipakai UI & rollback manual).
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.affiliate_friendly_remap (
  id              bigserial PRIMARY KEY,
  row_number      bigint NOT NULL,            -- urutan saat renumber (1..N aktif)
  old_code        text NOT NULL,
  new_code        text NOT NULL,
  external_id     text NOT NULL UNIQUE
);

CREATE INDEX IF NOT EXISTS idx_affiliate_friendly_remap_old_code
  ON public.affiliate_friendly_remap (old_code);
CREATE INDEX IF NOT EXISTS idx_affiliate_friendly_remap_new_code
  ON public.affiliate_friendly_remap (new_code);

------------------------------------------------------------
-- 3. Hitung pemetaan via temp table (urut created_at, external_id ASC).
--    Produk aktif = 1..N; produk nonaktif nanti dipindahkan ke range pensiun.
------------------------------------------------------------
DROP TABLE IF EXISTS public._affiliate_renumber_tmp;
CREATE TEMP TABLE public._affiliate_renumber_tmp AS
WITH ranked AS (
  SELECT
    id,
    friendly_code,
    external_id,
    ROW_NUMBER() OVER (
      PARTITION BY is_active
      ORDER BY created_at, external_id
    ) AS rn,
    COUNT(*) OVER (PARTITION BY is_active) AS cnt
  FROM public.affiliate_products
)
SELECT
  id,
  friendly_code AS old_code,
  CASE
    WHEN is_active THEN 'ASH-' || LPAD(rn::text, 3, '0')
    ELSE 'ASH-' || LPAD((cnt + rn)::text, 4, '0')  -- nonaktif → range 1000+
  END AS new_code
FROM ranked
ORDER BY created_at, external_id;

------------------------------------------------------------
-- 4. Apply renumber + simpan ke remap (UPSERT).
------------------------------------------------------------
WITH mapped AS (
  SELECT id, old_code, new_code, external_id
  FROM public._affiliate_renumber_tmp
)
UPDATE public.affiliate_products ap
SET friendly_code = m.new_code,
    updated_at    = now()
FROM mapped m
WHERE m.id = ap.id
  AND m.new_code <> ap.friendly_code;

INSERT INTO public.affiliate_friendly_remap (row_number, old_code, new_code, external_id)
SELECT rn, old_code, new_code, external_id
FROM public._affiliate_renumber_tmp
ON CONFLICT (external_id) DO UPDATE SET
  old_code   = EXCLUDED.old_code,
  new_code   = EXCLUDED.new_code,
  row_number = EXCLUDED.row_number;

------------------------------------------------------------
-- 5. Ganti trigger function — nol sequence burn.
--    Jika friendly_code dikosongkan (NULL/empty), hitung MAX+1.
--    Batas 9999 (4 digit) agar lpad tetap konsisten.
------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.gen_friendly_code()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_max   bigint;
  v_next  bigint;
BEGIN
  IF NEW.friendly_code IS NULL OR NEW.friendly_code = '' THEN
    -- Hitung MAX numerik saat ini + 1. Single-writer workflow membuatnya aman;
    -- collision hanya mungkin bila ada concurrent insert tanpa coordination.
    SELECT COALESCE(
      max((regexp_replace(friendly_code, '\D', '', 'g'))::bigint), 0
    ) INTO v_max
    FROM public.affiliate_products;
    v_next := v_max + 1;
    IF v_next > 9999 THEN
      RAISE EXCEPTION 'affiliate_friendly_seq exhausted at % (max=%), cannot assign ASH-%',
        v_next, v_max, v_next;
    END IF;
    NEW.friendly_code := 'ASH-' || CASE WHEN v_next < 1000 THEN lpad(v_next::text, 3, '0') ELSE v_next::text END;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- Re-attach trigger. (Baris di-update dengan explicit friendly_code, trigger
-- tetap jalan — IF branch skip → hanya updated_at di-set.)
DROP TRIGGER IF EXISTS trg_friendly ON public.affiliate_products;
CREATE TRIGGER trg_friendly
  BEFORE INSERT ON public.affiliate_products
  FOR EACH ROW EXECUTE FUNCTION public.gen_friendly_code();

------------------------------------------------------------
-- 6. Drop sequence lama (tidak dipakai lagi).
------------------------------------------------------------
DROP SEQUENCE IF EXISTS public.affiliate_friendly_seq;

------------------------------------------------------------
-- 7. Verifikasi inline — abort transaction bila salah satu gagal.
------------------------------------------------------------
DO $$
DECLARE
  v_count      bigint;
  v_gap        bigint;
  v_featured   bigint;
  v_broken     bigint;
BEGIN
  SELECT count(*) INTO v_count FROM public.affiliate_products WHERE is_active = true;
  SELECT count(*) INTO v_featured FROM public.affiliate_products WHERE is_active = true AND is_featured = true;
  SELECT count(*) INTO v_broken FROM public.affiliate_products WHERE is_active = true AND (image IS NULL OR image = '');
  -- Cek gap numerik aktif (1..v_count harus ada semua).
  WITH nums AS (SELECT generate_series(1, v_count) AS n)
  SELECT count(*) INTO v_gap
    FROM nums n
    LEFT JOIN public.affiliate_products ap ON n.n = (regexp_replace(ap.friendly_code, '\D', '', 'g'))::bigint
    WHERE ap.id IS NULL;
  IF v_gap != 0 THEN
    RAISE EXCEPTION 'dense renumber FAILED: masih ada % gap di range aktif 1..%', v_gap, v_count;
  END IF;
  IF v_featured != 6 THEN
    RAISE EXCEPTION 'featured count wrong: expected 6, got %', v_featured;
  END IF;
  IF v_broken > 0 THEN
    RAISE WARNING 'product with missing image after renumber: %', v_broken;
  END IF;
  RAISE NOTICE 'renumber OK: % aktif, featured=%, gap=%', v_count, v_featured, v_gap;
END $$;

------------------------------------------------------------
-- 8. Hapus temp table (otomatis drop di akhir transaksi; eksplisit untuk clean).
------------------------------------------------------------
DROP TABLE IF EXISTS public._affiliate_renumber_tmp;

COMMIT;
