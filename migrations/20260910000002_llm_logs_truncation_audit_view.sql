-- Audit keterpotongan output LLM + view gabungan provider→model (2026-09-10)
-- Latar: 10+ log gemini HTTP 200 terpotong tengah JSON. Dua mekanisme:
-- (a) thinkingLevel HIGH menghabiskan maxOutputTokens kecil (idea/image 500-900)
--     → MAX_TOKENS dengan belasan token terlihat; (b) response_text di-slice 8000
--     di app ( developing/verifying) — hanya preview log yang terpotong.
-- Non-destruktif: ADD COLUMN + view + GRANT, tanpa ubah data.
-- Diterapkan langsung ke production via MCP (keputusan user 2026-09-10).

-- 1) Kolom audit di llm_call_logs (diisi app mulai kode 2026-09-10)
ALTER TABLE public.llm_call_logs
  ADD COLUMN IF NOT EXISTS response_truncated boolean NOT NULL DEFAULT false;
ALTER TABLE public.llm_call_logs
  ADD COLUMN IF NOT EXISTS thought_tokens integer NULL;
COMMENT ON COLUMN public.llm_call_logs.response_truncated IS 'true bila finishReason = MAX_TOKENS/LENGTH (output dipenggal limit, bukan berhenti wajar)';
COMMENT ON COLUMN public.llm_call_logs.thought_tokens IS 'Token thinking/reasoning (Gemini thoughtsTokenCount); NULL bila tak diketahui';
CREATE INDEX IF NOT EXISTS idx_llm_logs_truncated
  ON public.llm_call_logs (provider_slug, created_at) WHERE response_truncated;

-- 2) View gabungan provider + model: urutan, fallback/default, kunci, pin stage, kesehatan 7 hari
-- Tanpa secret (api_key_encrypted/vault_secret_id tidak ikut — hanya hitung kunci aktif).
CREATE OR REPLACE VIEW public.v_llm_provider_models
WITH (security_invoker = true) AS
SELECT
  p.priority AS provider_urutan,
  p.slug AS provider,
  p.display_name AS provider_nama,
  p.is_active AS provider_aktif,
  m.priority AS model_urutan,
  m.model_id,
  m.display_name AS model_nama,
  m.is_active AS model_aktif,
  m.is_default AS model_default,
  m.usage_count,
  m.failure_count,
  m.last_used_at,
  m.config,
  (SELECT count(*) FROM public.llm_provider_keys k
    WHERE k.provider_id = p.id AND k.is_active) AS kunci_aktif,
  (SELECT string_agg(s.stage, ', ' ORDER BY s.stage) FROM public.llm_stage_defaults s
    WHERE s.model_id = m.id) AS stage_terpin,
  (SELECT count(*) FROM public.llm_call_logs l
    WHERE l.provider_slug = p.slug AND l.model_id = m.model_id
      AND l.created_at > now() - interval '7 days') AS panggilan_7h,
  (SELECT round(100.0 * count(*) FILTER (WHERE l.http_status = 200) / NULLIF(count(*), 0), 1)
    FROM public.llm_call_logs l
    WHERE l.provider_slug = p.slug AND l.model_id = m.model_id
      AND l.created_at > now() - interval '7 days') AS sukses_pct_7h,
  (SELECT count(*) FROM public.llm_call_logs l
    WHERE l.provider_slug = p.slug AND l.model_id = m.model_id
      AND l.response_truncated AND l.created_at > now() - interval '7 days') AS terpotong_7h,
  (SELECT round(avg(l.latency_ms)) FROM public.llm_call_logs l
    WHERE l.provider_slug = p.slug AND l.model_id = m.model_id
      AND l.http_status = 200 AND l.created_at > now() - interval '7 days') AS rerata_latensi_ms,
  (SELECT l.error FROM public.llm_call_logs l
    WHERE l.provider_slug = p.slug AND l.model_id = m.model_id AND l.error IS NOT NULL
    ORDER BY l.created_at DESC LIMIT 1) AS error_terakhir
FROM public.llm_providers p
JOIN public.llm_models m ON m.provider_id = p.id
ORDER BY p.priority, m.priority;

COMMENT ON VIEW public.v_llm_provider_models IS 'Daftar provider→model + urutan waterfall + kunci + pin stage + kesehatan 7 hari. security_invoker: RLS admin berlaku.';
GRANT SELECT ON public.v_llm_provider_models TO authenticated;
