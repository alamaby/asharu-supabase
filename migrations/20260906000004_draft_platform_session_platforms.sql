-- 1 draf per topik per platform (non-destruktif, nullable semua).
-- 1) content_drafts.platform_slug: sesi multi/'all' kini hasilkan N draf per topik.
--    Backfill: draf dari sesi platform spesifik → slug sesi; sisanya (sesi 'all'
--    lama, mis. 815c8df8) → 'all' sebagai arsip agnostik.
-- 2) content_research_sessions.platform_slugs: pilihan multi-checkbox form.
--    platform_slug dipertahankan (sesi lama + sesi 1-platform).

ALTER TABLE public.content_drafts
  ADD COLUMN IF NOT EXISTS platform_slug text REFERENCES public.platforms(slug) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_drafts_topic_platform
  ON public.content_drafts (research_topic_id, platform_slug);

ALTER TABLE public.content_research_sessions
  ADD COLUMN IF NOT EXISTS platform_slugs text[] NOT NULL DEFAULT '{}';

-- Baris arsip 'all' (nonaktif: tidak ikut ekspansi platform aktif, hanya label
-- draf agnostik warisan). is_active=false agar query ekspansi tak berubah.
INSERT INTO public.platforms (slug, display_name, max_chars, is_active)
VALUES ('all', 'Semua Platform (arsip)', NULL, false)
ON CONFLICT (slug) DO NOTHING;

-- Backfill draf dari sesi platform spesifik
UPDATE public.content_drafts d
   SET platform_slug = s.platform_slug
  FROM public.content_research_topics t
  JOIN public.content_research_sessions s ON s.id = t.session_id
 WHERE d.research_topic_id = t.id
   AND d.platform_slug IS NULL
   AND s.platform_slug IS NOT NULL;

-- Sisa (sesi 'all'/agnostik lama) → 'all'
UPDATE public.content_drafts d
   SET platform_slug = 'all'
 WHERE d.platform_slug IS NULL
   AND d.research_topic_id IS NOT NULL;
