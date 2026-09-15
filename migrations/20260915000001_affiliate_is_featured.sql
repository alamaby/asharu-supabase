-- M1.1: affiliate is_featured + featured index + backfill top-6 (DB-only migration, Opsi 3).
-- Non-destructive: kolom baru dengan default false; tidak mengubah data existing
-- kecuali backfill 6 featured pertama urutan scrape file saat ini.
--
-- Asumsi (diverifikasi): trigger trg_friendly/trg_friendly sudah mengatur
-- friendly_code + updated_at; kolom is_featured belum ada.
-- Kolom baru otomatis termasuk dalam SELECT anon via policy affiliate_read
-- (USING (true) — tidak perlu policy tambahan).

-- 1) Tambah kolom boolean, default false (seluruh baris existing tetap valid).
ALTER TABLE public.affiliate_products
  ADD COLUMN is_featured boolean NOT NULL DEFAULT false;

-- 2) Index partial: hanya baris aktif yang featured, dipakai homepage + picker.
CREATE INDEX IF NOT EXISTS idx_affiliate_products_active_featured
  ON public.affiliate_products (is_featured)
  WHERE is_active = true;

-- 3) Backfill: 6 produk pertama urutan scrape file src/data/affiliate-products.ts.
--    external_id = linkId, tanpa prefix "affiliate-" (mapper scrape:
--    src/data/affiliate-products.ts: affiliate-<linkId> → DB external_id=linkId).
UPDATE public.affiliate_products
  SET is_featured = true
  WHERE external_id IN (
    '42373719', -- affiliate-42373719 (urutan scrape ke-1)
    '42373661', -- urutan ke-2
    '42373431', -- urutan ke-3
    '42373422', -- urutan ke-4
    '42373396', -- urutan ke-5
    '42373392'  -- urutan ke-6
  );

-- NOTE: backfill harus tepat 6. Jika migrasi dijalankan ulang setelah data
-- berubah, nilainya bisa tidak sesuai urutan file baru — gunakan query
-- verifikasi (M1.1 verify) untuk konfirmasi.
