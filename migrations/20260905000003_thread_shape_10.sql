-- Fix thread_shape drift: allow up to 10 replies (align with threadSchema.max(10))
-- Root cause sesi 4e03bde2 + f7c91699: developing minta EXACTLY 7 replies
-- (6 konten + 1 affiliate, development.ts CONTENT_REPLIES/TOTAL_REPLIES)
-- tapi CHECK lama batasi <=5 → draft insert 23514 thread_shape → session failed.
-- Non-destructive, idempotent, retains RLS. Sesi sukses 641956c7 lolos
-- hanya karena LLM saat itu hasilkan 2-3 replies.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'thread_shape') THEN
    ALTER TABLE public.content_drafts DROP CONSTRAINT thread_shape;
  END IF;
END $$;
ALTER TABLE public.content_drafts
  ADD CONSTRAINT thread_shape CHECK (
    (generated_thread ? 'main')
    AND ((generated_thread -> 'main') ? 'id')
    AND ((generated_thread -> 'main') ? 'en')
    AND (jsonb_typeof(generated_thread -> 'replies') = 'array')
    AND (
      (jsonb_array_length(generated_thread -> 'replies') >= 0)
      AND (jsonb_array_length(generated_thread -> 'replies') <= 10)
    )
  );
COMMENT ON CONSTRAINT thread_shape ON public.content_drafts IS 'Align with threadSchema.max(10): Threads/Twitter/all TOTAL_REPLIES=7 (6 konten + 1 affiliate). Fix 4e03bde2/f7c91699.';
