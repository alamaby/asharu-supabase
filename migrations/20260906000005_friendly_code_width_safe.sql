-- Fix scrape gagal: duplicate friendly_code untuk produk ke-1000+.
-- Akar (diagnosis 2026-09-06): gen_friendly_code memakai
--   'ASH-' || lpad(nextval(...)::text, 3, '0')
-- dan lpad MEMOTONG string yang lebih panjang dari target ('1054'→'105'),
-- sehingga kode ≥1000 tabrakan dengan ASH-100..212. Sequence sendiri sehat
-- (terbakar cepat oleh speculative trigger tiap upsert massal — harmless gaps).
-- Fix: pertahankan format 3-digit di bawah 1000, tanpa padding di atasnya.
-- Resync sequence ke max+1 agar kode 3-digit terpakai dulu (213..999).

CREATE OR REPLACE FUNCTION public.gen_friendly_code()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v bigint;
BEGIN
  IF NEW.friendly_code IS NULL OR NEW.friendly_code = '' THEN
    v := nextval('public.affiliate_friendly_seq');
    NEW.friendly_code := 'ASH-' || CASE WHEN v < 1000 THEN lpad(v::text, 3, '0') ELSE v::text END;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- Resync ke max kode numerik (nilai burned yang rollback tak pernah ter-commit,
-- jadi 213..999 bebas dipakai; next = max+1). Burn spekulatif tiap upsert massal
-- tetap terjadi (harmless gaps) — follow-up: upsert hanya baris berubah.
SELECT setval(
  'public.affiliate_friendly_seq',
  (SELECT COALESCE(max((regexp_replace(friendly_code, '\D', '', 'g'))::int), 0) FROM public.affiliate_products),
  true
);
