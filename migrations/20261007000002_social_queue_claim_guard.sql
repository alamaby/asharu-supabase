-- Klaim antrean poster sosial: `claimed_at` membuat klaim bisa diaudit dan
-- baris 'posting' yang basi bisa diambil kembali oleh reaper.
--
-- Latar: worker (/api/social/post) diklaim via UPDATE ... WHERE status='queued'
-- (atomik di Postgres, hanya satu penulis yang menang). Sebelum ini tidak ada
-- kolom waktu klaim, sehingga invocation yang mati setelah klaim meninggalkan
-- baris 'posting' selamanya: klaim mensyaratkan status='queued', jadi baris itu
-- tidak pernah dipungut lagi dan thread-nya tidak pernah terkirim.
--
-- Reaper (di route, lihat reapStaleClaims) mengembalikan baris 'posting' yang
-- lebih tua dari ambang ke 'queued' agar tick berikutnya melanjutkan dari
-- social_post_logs (resume per post index, tanpa duplikasi).
ALTER TABLE public.social_post_queue
  ADD COLUMN IF NOT EXISTS claimed_at timestamptz NULL;

COMMENT ON COLUMN public.social_post_queue.claimed_at IS
  'Waktu klaim terakhir oleh worker (status=posting). NULL saat queued/posted/failed. Dipakai reaper untuk mendeteksi klaim basi.';

-- Index parsial untuk reaper: cari baris 'posting' yang basi.
CREATE INDEX IF NOT EXISTS idx_social_queue_stale_claims
  ON public.social_post_queue (claimed_at)
  WHERE status = 'posting';
