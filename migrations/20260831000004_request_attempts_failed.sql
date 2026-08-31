-- P1 (audit 2026-08-30): failed content_requests were reset to 'pending'
-- forever (no attempt cap) — a permanently-failing request was retried by the
-- cron every 5 minutes, burning LLM calls on every pass. Add an attempts
-- counter and a terminal 'failed' status; the processor enforces the cap (3).

ALTER TABLE public.content_requests
  ADD COLUMN IF NOT EXISTS attempts int NOT NULL DEFAULT 0;

ALTER TABLE public.content_requests
  DROP CONSTRAINT content_requests_status_check;

ALTER TABLE public.content_requests
  ADD CONSTRAINT content_requests_status_check
  CHECK (status IN ('pending', 'processing', 'needs_review', 'approved', 'rejected', 'failed'));
