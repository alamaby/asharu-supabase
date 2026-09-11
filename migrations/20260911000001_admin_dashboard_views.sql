-- View agregasi dasbor admin TailAdmin (2026-09-11)
-- Latar: dasbor butuh tren + funnel + pemakaian LLM + statistik visual tanpa
-- membebani query ad-hoc per halaman. Non-destruktif: hanya CREATE VIEW +
-- GRANT, tanpa ubah tabel/kolom/data. Mengikuti pola v_llm_provider_models
-- (security_invoker + GRANT SELECT ke authenticated; RLS tabel dasar berlaku,
-- Tanpa secret: tidak ada kolom kunci/token mentah yang ikut.

-- 1) Tren harian 30 hari: permintaan + draf (perlu review / disetujui)
CREATE OR REPLACE VIEW public.v_admin_content_daily
WITH (security_invoker = true) AS
SELECT
  d.hari,
  (SELECT count(*) FROM public.content_requests r
    WHERE (r.created_at AT TIME ZONE 'UTC')::date = d.hari) AS permintaan,
  (SELECT count(*) FROM public.content_drafts x
    WHERE (x.created_at AT TIME ZONE 'UTC')::date = d.hari) AS draf,
  (SELECT count(*) FROM public.content_drafts x
    WHERE (x.created_at AT TIME ZONE 'UTC')::date = d.hari
      AND x.status = 'needs_review') AS perlu_review,
  (SELECT count(*) FROM public.content_drafts x
    WHERE (x.created_at AT TIME ZONE 'UTC')::date = d.hari
      AND x.status = 'approved') AS disetujui
FROM (SELECT generate_series(
  (now() AT TIME ZONE 'UTC')::date - 29,
  (now() AT TIME ZONE 'UTC')::date,
  interval '1 day'
)::date AS hari) d
ORDER BY d.hari;

COMMENT ON VIEW public.v_admin_content_daily IS 'Tren harian 30 hari: permintaan + draf + perlu_review + disetujui (UTC). security_invoker: RLS admin berlaku.';
GRANT SELECT ON public.v_admin_content_daily TO authenticated;

-- 2) Funnel sesi riset per status
CREATE OR REPLACE VIEW public.v_admin_research_funnel
WITH (security_invoker = true) AS
SELECT
  s.status,
  count(*) AS jumlah,
  max(s.updated_at) AS updated_terakhir
FROM public.content_research_sessions s
GROUP BY s.status
ORDER BY jumlah DESC;

COMMENT ON VIEW public.v_admin_research_funnel IS 'Distribusi status sesi riset + pembaruan terakhir. security_invoker: RLS admin berlaku.';
GRANT SELECT ON public.v_admin_research_funnel TO authenticated;

-- 3) Pemakaian LLM harian 14 hari: volume, sukses, token, latensi
CREATE OR REPLACE VIEW public.v_admin_llm_usage_daily
WITH (security_invoker = true) AS
SELECT
  d.hari,
  (SELECT count(*) FROM public.llm_call_logs l
    WHERE (l.created_at AT TIME ZONE 'UTC')::date = d.hari) AS panggilan,
  (SELECT round(100.0 * count(*) FILTER (WHERE l.http_status = 200) / NULLIF(count(*), 0), 1)
    FROM public.llm_call_logs l
    WHERE (l.created_at AT TIME ZONE 'UTC')::date = d.hari) AS sukses_pct,
  (SELECT coalesce(sum(l.prompt_tokens), 0) FROM public.llm_call_logs l
    WHERE (l.created_at AT TIME ZONE 'UTC')::date = d.hari) AS token_masuk,
  (SELECT coalesce(sum(l.completion_tokens), 0) FROM public.llm_call_logs l
    WHERE (l.created_at AT TIME ZONE 'UTC')::date = d.hari) AS token_keluar,
  (SELECT round(avg(l.latency_ms)) FROM public.llm_call_logs l
    WHERE (l.created_at AT TIME ZONE 'UTC')::date = d.hari AND l.http_status = 200) AS rerata_latensi_ms
FROM (SELECT generate_series(
  (now() AT TIME ZONE 'UTC')::date - 13,
  (now() AT TIME ZONE 'UTC')::date,
  interval '1 day'
)::date AS hari) d
ORDER BY d.hari;

COMMENT ON VIEW public.v_admin_llm_usage_daily IS 'Pemakaian LLM harian 14 hari: volume + sukses% + token + latensi (UTC). security_invoker: RLS admin berlaku.';
GRANT SELECT ON public.v_admin_llm_usage_daily TO authenticated;

-- 4) Statistik gambar draf per provider + status
CREATE OR REPLACE VIEW public.v_admin_image_stats
WITH (security_invoker = true) AS
SELECT
  coalesce(i.provider_slug, '(tanpa provider)') AS provider,
  i.status,
  count(*) AS jumlah,
  max(i.created_at) AS terakhir
FROM public.content_draft_images i
GROUP BY i.provider_slug, i.status
ORDER BY jumlah DESC;

COMMENT ON VIEW public.v_admin_image_stats IS 'Sebaran gambar draf per provider + status. security_invoker: RLS admin berlaku.';
GRANT SELECT ON public.v_admin_image_stats TO authenticated;
