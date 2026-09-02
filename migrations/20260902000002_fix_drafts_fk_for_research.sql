-- Fix: allow research pipeline drafts with sessionId in request_id
-- Sesi riset completed tapi 0 draf karena FK 23503 silent.
-- Idempotent, non-destructive, retains RLS.
ALTER TABLE public.content_drafts DROP CONSTRAINT IF EXISTS content_drafts_request_id_fkey;
ALTER TABLE public.content_drafts ALTER COLUMN request_id DROP NOT NULL;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='drafts_has_link') THEN
    ALTER TABLE public.content_drafts
      ADD CONSTRAINT drafts_has_link CHECK (request_id IS NOT NULL OR research_topic_id IS NOT NULL);
  END IF;
END $$;
