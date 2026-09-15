-- M1.2: bucket public affiliate-images + policy.
-- Public read untuk rendering kartu produk (anonClient di halaman publik);
-- tulis hanya via service_role (bypass RLS) oleh scraper cron.
-- Tiru pola draft-images / user-images (lihat 20260907000003 / 20260911000002).

INSERT INTO storage.buckets (id, name, public)
  VALUES ('affiliate-images', 'affiliate-images', true)
  ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "affiliate_images_public_read" ON storage.objects;
CREATE POLICY "affiliate_images_public_read" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'affiliate-images');
