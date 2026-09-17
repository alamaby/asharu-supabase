-- Chat Lab: flag has_error di batches untuk pagination + filter DB (2026-09-17)
-- Latar: filter status (ok/error) dihitung dari runs sehingga tak bisa difilter
-- di DB; pagination butuh count akurat + semua filter di DB. Kolom denormalisasi
-- diisi app saat insert; backfill menutup data lama.
-- Non-destruktif, aditif saja (tanpa ubah RLS/index lama).

ALTER TABLE public.chat_lab_batches
  ADD COLUMN IF NOT EXISTS has_error boolean NOT NULL DEFAULT false;

-- Backfill: batch yang punya min. 1 run error.
UPDATE public.chat_lab_batches b
SET has_error = true
WHERE EXISTS (
  SELECT 1 FROM public.chat_lab_runs r
  WHERE r.batch_id = b.id AND r.error IS NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_chat_lab_batches_owner_error
  ON public.chat_lab_batches (user_id, has_error, created_at DESC);
