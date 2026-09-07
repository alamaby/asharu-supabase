-- Perluasan image per-reply (opt-in, kecuali afiliasi) — non-destruktif.
-- 1) content_draft_images.post_index: 0 = main/cover, 1..n = replies.
--    Baris lama (tanpa post_index) = cover → di-backfill 0.
--    Unique selected diganti (draft_id, post_index) agar tiap post punya 1 selected.
-- 2) image_gen_defaults.image_mode: cover-only | per-reply-opt-in (kill-switch global).
-- 3) sessions + drafts: override mode per sesi/draf (nullable).
-- 4) social_post_queue.image_urls jsonb: { "<post_index>": "<public_url>" } per index.

-- 1) post_index
ALTER TABLE public.content_draft_images
  ADD COLUMN IF NOT EXISTS post_index int NOT NULL DEFAULT 0 CHECK (post_index >= 0);
UPDATE public.content_draft_images SET post_index = 0 WHERE post_index IS NULL;
DROP INDEX IF EXISTS uq_draft_images_selected;
CREATE UNIQUE INDEX IF NOT EXISTS uq_draft_images_selected_post
  ON public.content_draft_images (draft_id, post_index) WHERE status = 'selected';
CREATE INDEX IF NOT EXISTS idx_draft_images_draft_post
  ON public.content_draft_images (draft_id, post_index, created_at DESC);

-- 2) Mode global (singleton id=1 sudah ada)
ALTER TABLE public.image_gen_defaults
  ADD COLUMN IF NOT EXISTS image_mode text NOT NULL DEFAULT 'cover-only'
    CHECK (image_mode IN ('cover-only', 'per-reply-opt-in'));

-- 3) Override per sesi + per draf
ALTER TABLE public.content_research_sessions
  ADD COLUMN IF NOT EXISTS image_mode text NULL CHECK (image_mode IN ('cover-only', 'per-reply-opt-in'));
ALTER TABLE public.content_drafts
  ADD COLUMN IF NOT EXISTS image_mode text NULL CHECK (image_mode IN ('cover-only', 'per-reply-opt-in'));

-- 4) Antrean social per-index (aditif; image_url tunggal tetap dipakai fallback opener)
ALTER TABLE public.social_post_queue
  ADD COLUMN IF NOT EXISTS image_urls jsonb NULL;
