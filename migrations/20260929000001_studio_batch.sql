-- Studio Batch Generate Image (2026-09-29)
-- Menu /studio/batch: user paste/upload file teks berisi prompt generate image
-- yang dipisah double newline; satu batch di-enqueue sekaligus dengan setting
-- shared; worker FIFO existing (/api/studio/process */5) memproses satu-per-satu.
-- Non-destruktif, aditif saja:
-- 1) image_studio_config.max_batch_prompts: knob cap prompt per batch (default 50).
-- 2) studio_batches: grup batch milik user (name + settings snapshot jsonb).
-- 3) user_image_generations.batch_id: FK nullable ke studio_batches
--    (NULL = generate single dari /studio seperti sekarang; ON DELETE CASCADE).
-- 4) RLS studio_batches: owner read + owner insert + admin all + service all
--    (anak tetap ditulis user via policy insert lama pada user_image_generations).
-- Catatan: batch row persist setelah anak expired (jejak audit);
-- cleanup expired tidak menghapus baris batch.
-- Key material TIDAK ditambahkan — reuse alur image_provider_keys + Vault yang ada.

-- 1) Knob cap batch di config studio (configurable by table, cek 1–50)
ALTER TABLE public.image_studio_config
  ADD COLUMN IF NOT EXISTS max_batch_prompts int NOT NULL DEFAULT 50
  CHECK (max_batch_prompts BETWEEN 1 AND 50);

-- 2) Tabel grup batch
CREATE TABLE IF NOT EXISTS public.studio_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NULL CHECK (name IS NULL OR char_length(name) <= 120),
  settings jsonb NOT NULL DEFAULT '{}'::jsonb,
  total int NOT NULL CHECK (total BETWEEN 1 AND 50),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_studio_batches_owner
  ON public.studio_batches (user_id, created_at DESC);

-- 3) Anak batch (FK nullable; baris single tetap batch_id NULL)
ALTER TABLE public.user_image_generations
  ADD COLUMN IF NOT EXISTS batch_id uuid NULL
  REFERENCES public.studio_batches(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_user_images_batch
  ON public.user_image_generations (batch_id, created_at ASC)
  WHERE batch_id IS NOT NULL;

-- 4) RLS studio_batches (tiru pola user_image_generations)
ALTER TABLE public.studio_batches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "studio_batches_owner_read" ON public.studio_batches;
CREATE POLICY "studio_batches_owner_read" ON public.studio_batches
  FOR SELECT TO authenticated USING (auth.uid() = user_id OR is_admin());

DROP POLICY IF EXISTS "studio_batches_owner_insert" ON public.studio_batches;
CREATE POLICY "studio_batches_owner_insert" ON public.studio_batches
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "studio_batches_admin" ON public.studio_batches;
CREATE POLICY "studio_batches_admin" ON public.studio_batches
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "studio_batches_service" ON public.studio_batches;
CREATE POLICY "studio_batches_service" ON public.studio_batches
  FOR ALL TO service_role USING (true) WITH CHECK (true);
