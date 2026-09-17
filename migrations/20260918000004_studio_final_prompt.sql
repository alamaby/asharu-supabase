-- Studio riwayat: snapshot prompt final terkirim ke model (2026-09-17)
-- Setiap record Riwayat Generate perlu info Preset style / Template subjek /
-- Camera angle / Aspek rasio + full teks prompt yang dikirim ke model.
-- Slug + display_name di-resolve di UI dari katalog aktif; prompt final TIDAK
-- bisa direkonstruksi live (katalog bisa berubah) sehingga di-snapshot worker.
-- Non-destruktif, aditif saja:
-- 1) 2 kolom nullable di user_image_generations (NULL = pending / data lama).
--    Worker mengisi saat ready maupun failed (audit prompt yang dicoba).
-- 2) Tanpa perubahan RLS/index (select * existing ikut membaca kolom baru).
-- Backfill TIDAK dilakukan (katalog mungkin sudah berubah, berisiko menulis
-- sejarah palsu) — UI menampilkan fallback prompt input untuk data lama.

ALTER TABLE public.user_image_generations
  ADD COLUMN IF NOT EXISTS final_prompt text NULL
  CHECK (final_prompt IS NULL OR char_length(final_prompt) <= 4000);
ALTER TABLE public.user_image_generations
  ADD COLUMN IF NOT EXISTS final_negative text NULL
  CHECK (final_negative IS NULL OR char_length(final_negative) <= 1000);
