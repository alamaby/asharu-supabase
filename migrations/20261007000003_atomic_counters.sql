-- Counter usage/failure ATOMIK untuk pool key & model (LLM + image).
--
-- Sebelumnya kode melakukan SELECT usage_count → UPDATE usage_count = current+1.
-- Dua proses paralel (worker image + tick cron riset) membaca nilai yang sama,
-- sehingga satu kenaikan hilang: statistik round-robin jadi salah dan ambang
-- circuit breaker (failure_count > 5) baru tercapai jauh lebih lambat dari
-- seharusnya.
--
-- Dua fungsi generik dengan ALLOWLIST nama tabel. Nama tabel tidak pernah
-- disisipkan sebagai identifier mentah: divalidasi dulu, lalu diformat dengan
-- %I. Kolomnya identik di keempat tabel (usage_count/failure_count/last_used_at/
-- is_active), jadi satu implementasi cukup untuk LLM dan image.
--
-- Perlindungan: SECURITY DEFINER + search_path dikunci + EXECUTE hanya untuk
-- service_role (pemanggil memakai service client; anon/authenticated dilarang).

CREATE OR REPLACE FUNCTION public.increment_usage_counter(p_table text, p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_table NOT IN ('llm_provider_keys', 'llm_models', 'image_provider_keys', 'image_models') THEN
    RAISE EXCEPTION 'increment_usage_counter: tabel counter tidak diizinkan: %', p_table;
  END IF;

  EXECUTE format(
    'UPDATE public.%I SET usage_count = usage_count + 1, last_used_at = now() WHERE id = $1',
    p_table
  ) USING p_id;
END;
$$;

COMMENT ON FUNCTION public.increment_usage_counter(text, uuid) IS
  'Atomik: usage_count = usage_count + 1 + last_used_at. Allowlist tabel pool key/model (LLM + image). service_role only.';

CREATE OR REPLACE FUNCTION public.increment_failure_counter(
  p_table text,
  p_id uuid,
  p_threshold int DEFAULT 5
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  new_count int;
BEGIN
  IF p_table NOT IN ('llm_provider_keys', 'llm_models', 'image_provider_keys', 'image_models') THEN
    RAISE EXCEPTION 'increment_failure_counter: tabel counter tidak diizinkan: %', p_table;
  END IF;
  IF p_threshold IS NULL OR p_threshold < 1 THEN
    RAISE EXCEPTION 'increment_failure_counter: p_threshold harus >= 1';
  END IF;

  EXECUTE format(
    'UPDATE public.%I
        SET failure_count = failure_count + 1,
            is_active = CASE WHEN failure_count + 1 > $2 THEN false ELSE is_active END
      WHERE id = $1
      RETURNING failure_count',
    p_table
  ) INTO new_count USING p_id, p_threshold;

  RETURN new_count;
END;
$$;

COMMENT ON FUNCTION public.increment_failure_counter(text, uuid, int) IS
  'Atomik: failure_count + 1, dan is_active=false saat hasilnya melewati p_threshold. Mengembalikan failure_count baru. service_role only.';

REVOKE ALL ON FUNCTION public.increment_usage_counter(text, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.increment_failure_counter(text, uuid, int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.increment_usage_counter(text, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.increment_failure_counter(text, uuid, int) TO service_role;
