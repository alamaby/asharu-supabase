-- Artikel: tambah kolom category + tags untuk taksonomi listing (18 Sep 2026).
-- Non-destruktif, idempotent. RLS tidak berubah (anon tetap hanya status='published').
-- Backfill hanya artikel yang belum punya category (WHERE ... IS NULL) agar
-- kurasi manual yang ada tidak ditimpa scraper / pipeline.

ALTER TABLE public.articles
  ADD COLUMN IF NOT EXISTS category text;

ALTER TABLE public.articles
  ADD COLUMN IF NOT EXISTS tags text[] NOT NULL DEFAULT '{}';

ALTER TABLE public.articles
  DROP CONSTRAINT IF EXISTS articles_category_check;

ALTER TABLE public.articles
  ADD CONSTRAINT articles_category_check
    CHECK (category IS NULL OR category IN (
      'automotive', 'electronics', 'home-living',
      'fashion', 'sports-hobby', 'others'
    ));

CREATE INDEX IF NOT EXISTS idx_articles_cat_pub
  ON public.articles (locale, status, category, published_at DESC);

-- Backfill satu kali: ikut kategori produk afiliasi yang terhubung.
UPDATE public.articles a
SET category = p.category
FROM public.affiliate_products p
WHERE a.product_id = p.id
  AND a.category IS NULL;
