-- Rate limit atomik: satu statement INSERT ... ON CONFLICT DO UPDATE sehingga
-- pola check-then-increment (SELECT count → UPDATE count+1) tidak lagi bisa
-- dilewati oleh dua request paralel (dua-duanya membaca count=4, dua-duanya
-- lolos, dua-duanya menulis 5).
--
-- Semantik (disengaja): SETIAP panggilan mengonsumsi satu slot, termasuk
-- percobaan yang berakhir gagal validasi. Batasnya mengikat pada laju request
-- per IP, bukan pada laju sukses — pengganti pola lama "increment hanya saat
-- sukses" yang bocor lewat request paralel.
--
-- SECURITY DEFINER + search_path dikunci, dan EXECUTE hanya untuk service_role:
-- route/server action memanggilnya lewat service client (RLS di-bypass), jadi
-- anon/authenticated tidak butuh (dan tidak boleh) memanggilnya langsung.
CREATE OR REPLACE FUNCTION public.consume_rate_limit(
  p_ip text,
  p_scope text,
  p_limit int,
  p_window_minutes int DEFAULT 60
)
RETURNS TABLE (allowed boolean, count int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_limit IS NULL OR p_limit < 1 THEN
    RAISE EXCEPTION 'consume_rate_limit: p_limit harus >= 1';
  END IF;
  IF p_window_minutes IS NULL OR p_window_minutes < 1 THEN
    RAISE EXCEPTION 'consume_rate_limit: p_window_minutes harus >= 1';
  END IF;

  RETURN QUERY
  INSERT INTO public.rate_limits AS rl (ip, scope, window_start, count)
  VALUES (p_ip, p_scope, now(), 1)
  ON CONFLICT (ip, scope) DO UPDATE
    SET count = CASE
          WHEN rl.window_start <= now() - make_interval(mins => p_window_minutes) THEN 1
          ELSE rl.count + 1
        END,
        window_start = CASE
          WHEN rl.window_start <= now() - make_interval(mins => p_window_minutes) THEN now()
          ELSE rl.window_start
        END
  RETURNING (rl.count <= p_limit) AS allowed, rl.count AS count;
END;
$$;

COMMENT ON FUNCTION public.consume_rate_limit(text, text, int, int) IS
  'Fixed-window rate limit atomik per (ip, scope). Mengembalikan allowed=false saat count melewati p_limit. service_role only.';

REVOKE ALL ON FUNCTION public.consume_rate_limit(text, text, int, int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_rate_limit(text, text, int, int) FROM anon;
REVOKE ALL ON FUNCTION public.consume_rate_limit(text, text, int, int) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.consume_rate_limit(text, text, int, int) TO service_role;

-- Pemangkas tabel rate_limits: baris yang window-nya sudah lama lewat tidak
-- dipakai lagi (pemanggil berikutnya akan reset lewat ON CONFLICT), tapi tetap
-- menumpuk. Dipanggil dari cron cleanup harian (/api/lab/cleanup).
CREATE OR REPLACE FUNCTION public.cleanup_expired_rate_limits(p_older_than_minutes int DEFAULT 1440)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  deleted int;
BEGIN
  DELETE FROM public.rate_limits
  WHERE window_start <= now() - make_interval(mins => GREATEST(p_older_than_minutes, 60));
  GET DIAGNOSTICS deleted = ROW_COUNT;
  RETURN deleted;
END;
$$;

COMMENT ON FUNCTION public.cleanup_expired_rate_limits(int) IS
  'Hapus baris rate_limits dengan window_start lebih lama dari p_older_than_minutes (min 60). service_role only.';

REVOKE ALL ON FUNCTION public.cleanup_expired_rate_limits(int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cleanup_expired_rate_limits(int) FROM anon;
REVOKE ALL ON FUNCTION public.cleanup_expired_rate_limits(int) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_expired_rate_limits(int) TO service_role;
