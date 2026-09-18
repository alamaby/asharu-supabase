-- Observabilitas pg_cron untuk admin (2026-09-16).
--
-- Mengapa RPC: schema `cron`/`net` TIDAK diekspos PostgREST dan role
-- authenticated/service_role tidak punya USAGE di schema `cron`
-- (terverifikasi 2026-09-16). Maka satu-satunya jalur baca dari aplikasi
-- adalah fungsi SECURITY DEFINER milik postgres (punya USAGE cron+net).
--
-- Mengapa TIDAK pakai is_admin() di dalam fungsi: halaman memanggil RPC
-- dengan service key (auth.uid() = null -> is_admin() selalu false).
-- Pengaman = GRANT EXECUTE hanya ke service_role + guard isAdmin() di page.
--
-- CATATAN DATA:
-- - `cron.job_run_details.return_message` untuk job pg_net SELALU "1 row"
--   (hasil SELECT net.http_post), jadi tidak informatif. Detail HTTP diambil
--   dari `net._http_response` yang di-join best-effort via
--   headers->>'x-matched-path' = path job + jendela waktu [-5s, +30s].
-- - `net._http_response` hanya menahan ~6 jam (pg_net.ttl). Run lebih tua
--   tetap tampil, kolom http_* = NULL. UI WAJIB menampilkannya sebagai
--   "detail HTTP kedaluwarsa", bukan error.
-- - JANGAN kembalikan `cron.job.command` mentah — hanya path turunannya.

CREATE OR REPLACE FUNCTION public.admin_cron_jobs()
RETURNS TABLE (
  jobid bigint,
  jobname text,
  schedule text,
  active boolean,
  command_path text,
  last_start timestamptz,
  last_end timestamptz,
  last_status text,
  last_return_message text,
  run_count bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $func$
  SELECT
    j.jobid,
    j.jobname,
    j.schedule,
    j.active,
    substring(j.command from 'https?://[^/'']+(/[^'']*)') AS command_path,
    (SELECT d.start_time FROM cron.job_run_details d
       WHERE d.jobid = j.jobid ORDER BY d.start_time DESC LIMIT 1) AS last_start,
    (SELECT d.end_time FROM cron.job_run_details d
       WHERE d.jobid = j.jobid ORDER BY d.start_time DESC LIMIT 1) AS last_end,
    (SELECT d.status FROM cron.job_run_details d
       WHERE d.jobid = j.jobid ORDER BY d.start_time DESC LIMIT 1) AS last_status,
    (SELECT d.return_message FROM cron.job_run_details d
       WHERE d.jobid = j.jobid ORDER BY d.start_time DESC LIMIT 1) AS last_return_message,
    (SELECT count(*) FROM cron.job_run_details d WHERE d.jobid = j.jobid) AS run_count
  FROM cron.job j
  ORDER BY j.jobname;
$func$;

REVOKE ALL ON FUNCTION public.admin_cron_jobs() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_cron_jobs() TO service_role;
COMMENT ON FUNCTION public.admin_cron_jobs() IS 'Daftar pg_cron + ringkasan run terakhir. service_role only.';

CREATE OR REPLACE FUNCTION public.admin_cron_runs(p_jobid bigint, p_limit int DEFAULT 50)
RETURNS TABLE (
  runid bigint,
  status text,
  return_message text,
  start_time timestamptz,
  end_time timestamptz,
  duration_ms numeric,
  http_status int,
  http_timed_out boolean,
  http_error text,
  http_body text,
  http_created timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $func$
  WITH job_path AS (
    SELECT substring(cj.command from 'https?://[^/'']+(/[^'']*)') AS path
    FROM cron.job cj
    WHERE cj.jobid = p_jobid
  )
  SELECT
    d.runid,
    d.status,
    d.return_message,
    d.start_time,
    d.end_time,
    CASE WHEN d.end_time IS NULL THEN NULL
         ELSE round(extract(epoch from (d.end_time - d.start_time)) * 1000)
    END AS duration_ms,
    r.status_code AS http_status,
    r.timed_out AS http_timed_out,
    r.error_msg AS http_error,
    left(r.content, 2000) AS http_body,
    r.created AS http_created
  FROM cron.job_run_details d
  CROSS JOIN job_path
  LEFT JOIN LATERAL (
    SELECT resp.status_code, resp.timed_out, resp.error_msg, resp.content, resp.created
    FROM net._http_response resp
    WHERE resp.created BETWEEN d.start_time - interval '5 seconds'
                           AND d.start_time + interval '30 seconds'
      AND resp.headers ->> 'x-matched-path' = job_path.path
    ORDER BY resp.created ASC
    LIMIT 1
  ) r ON true
  WHERE d.jobid = p_jobid
  ORDER BY d.start_time DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
$func$;

REVOKE ALL ON FUNCTION public.admin_cron_runs(bigint, int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_cron_runs(bigint, int) TO service_role;
COMMENT ON FUNCTION public.admin_cron_runs(bigint, int) IS 'N run terakhir per cron job + respons HTTP best-effort (TTL pg_net ~6 jam). service_role only.';
