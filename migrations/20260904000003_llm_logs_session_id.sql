-- LLM logs: link ke research sessions + bebaskan request_id (2026-09-04)
--
-- Akar masalah: llm_call_logs.request_id ber-FK ke content_requests(id),
-- sedangkan pipeline riset mengirim requestId = research session id dan
-- generateIdea mengirim 'idea-<timestamp>' (bukan UUID). Semua insert log
-- gagal diam-diam sejak pipeline riset aktif (2 Sep) — halaman LLM Logs
-- berhenti di 1 Sep 2026. FK di-drop; request_id tetap dipakai jalur legacy
-- (content_requests id valid); sesi riset dicatat di kolom baru session_id.

ALTER TABLE public.llm_call_logs
  DROP CONSTRAINT IF EXISTS llm_call_logs_request_id_fkey;

ALTER TABLE public.llm_call_logs
  ADD COLUMN IF NOT EXISTS session_id uuid
    REFERENCES public.content_research_sessions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_llm_logs_session
  ON public.llm_call_logs (session_id, created_at DESC);
