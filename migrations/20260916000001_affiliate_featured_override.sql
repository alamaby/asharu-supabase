-- Lapisan kurasi featured admin (2026-09-16).
--
-- Latar: scraper harian (`scripts/scrape-affiliate.mjs:157,214`) menulis
-- `is_featured = index < 6` dan CI (`.github/workflows/scrape-affiliate.yml:82`)
-- menggagalkan bila featured != 6. Keduanya SENGAJA tidak disentuh.
-- Layer override ini membuat kurasi admin tahan scrape:
--   featured_override = true  -> paksa featured (rank 0)
--   featured_override = NULL  -> ikut scraper (rank 1 bila is_featured)
--   featured_override = false -> paksa non-featured (rank 2)
-- Tampilan featured publik = 6 teratas dari ORDER BY featured_rank, created_at DESC.
--
-- Non-destruktif: hanya ADD COLUMN + index; NULL = perilaku lama.

ALTER TABLE public.affiliate_products
  ADD COLUMN featured_override boolean NULL,
  ADD COLUMN featured_override_at timestamptz NULL;

ALTER TABLE public.affiliate_products
  ADD COLUMN featured_rank smallint GENERATED ALWAYS AS (
    CASE
      WHEN featured_override IS TRUE  THEN 0
      WHEN featured_override IS FALSE THEN 2
      WHEN is_featured                THEN 1
      ELSE 2
    END
  ) STORED;

COMMENT ON COLUMN public.affiliate_products.featured_override IS
  'Kurasi admin: true=paksa featured, false=paksa non-featured, null=ikut scraper (is_featured).';
COMMENT ON COLUMN public.affiliate_products.featured_override_at IS
  'Kapan override dipasang admin (dipakai auto-swap: override-true tertua dilepas dulu).';
COMMENT ON COLUMN public.affiliate_products.featured_rank IS
  'Rank kurasi (generated): 0=admin, 1=default scraper, 2=non-featured. Display = ORDER BY featured_rank, created_at DESC LIMIT 6.';

CREATE INDEX IF NOT EXISTS idx_affiliate_products_featured_rank
  ON public.affiliate_products (featured_rank, created_at DESC)
  WHERE is_active = true;
