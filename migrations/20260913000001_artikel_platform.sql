-- Artikel sebagai platform riset baru + tabel publikasi artikel (SEO)
-- Non-destructive, idempotent. RLS: publik baca yang published saja,
-- tulis hanya admin (service_role bypass seperti tabel lain).
-- Draf artikel menyimpan konten penuh di content_drafts.article_draft
-- (generated_thread diisi minimal yang valid agar CHECK thread_shape
-- dan list review lama tidak pecah).

------------------------------------------------------------
-- 1. Seed platform artikel (long-form, tanpa batas karakter)
------------------------------------------------------------
INSERT INTO public.platforms (slug, display_name, max_chars, is_active)
VALUES ('artikel', 'Artikel', NULL, true)
ON CONFLICT (slug) DO NOTHING;

------------------------------------------------------------
-- 2. Kolom draf artikel di content_drafts
------------------------------------------------------------
ALTER TABLE public.content_drafts
  ADD COLUMN IF NOT EXISTS article_draft jsonb;

------------------------------------------------------------
-- 3. Tabel articles (1 baris = 1 bahasa, slug unik per locale)
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.articles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL,
  locale text NOT NULL CHECK (locale IN ('id', 'en')),
  title text NOT NULL CHECK (char_length(title) BETWEEN 10 AND 200),
  excerpt text NOT NULL CHECK (char_length(excerpt) BETWEEN 50 AND 500),
  body_md text NOT NULL CHECK (char_length(body_md) BETWEEN 500 AND 20000),
  faq jsonb NOT NULL DEFAULT '[]'::jsonb,
  cover_image_url text,
  affiliate_url text,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'published', 'archived')),
  draft_id uuid REFERENCES public.content_drafts(id) ON DELETE SET NULL,
  session_id uuid REFERENCES public.content_research_sessions(id) ON DELETE SET NULL,
  topic_id uuid REFERENCES public.content_research_topics(id) ON DELETE SET NULL,
  product_id uuid REFERENCES public.affiliate_products(id) ON DELETE SET NULL,
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (locale, slug),
  UNIQUE (draft_id, locale)
);

CREATE INDEX IF NOT EXISTS idx_articles_published
  ON public.articles (locale, status, published_at DESC);

------------------------------------------------------------
-- 4. RLS
------------------------------------------------------------
ALTER TABLE public.articles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "articles_public_read" ON public.articles;
CREATE POLICY "articles_public_read" ON public.articles
  FOR SELECT TO anon, authenticated USING (status = 'published');

DROP POLICY IF EXISTS "articles_admin_write" ON public.articles;
CREATE POLICY "articles_admin_write" ON public.articles
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
