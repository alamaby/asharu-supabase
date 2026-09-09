-- Template riset — 2026-09-09
-- Katalog template struktur konten (config-by-table): user memilih 1 template
-- opsional saat membuat riset baru; NULL = Bebas (tanpa struktur khusus).
-- discovery_hint dipakai tahap discovering; development_hint dipakai developing.
-- Non-destruktif: tabel baru + 1 kolom nullable + seed 6 template.

CREATE TABLE IF NOT EXISTS public.research_templates (
  slug text PRIMARY KEY,
  display_name text NOT NULL,
  description text NOT NULL DEFAULT '',
  discovery_hint text NOT NULL DEFAULT '',
  development_hint text NOT NULL DEFAULT '',
  is_active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 100,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.research_templates (slug, display_name, description, discovery_hint, development_hint, sort_order) VALUES
  ('problem-solution', 'Problem–Solution',
    'Masalah → Dampak → Produk sebagai solusi → CTA',
    'Prioritaskan topik berupa MASALAH nyata audiens (keluhan, pain point) yang solusinya bisa berupa produk/layanan — setiap topik harus memungkinkan alur Masalah → Dampak → Produk sebagai solusi → CTA.',
    'TEMPLATE problem-solution: susun thread dengan alur Masalah (main: hook pain yang relatable) → Dampak (reply awal: akibat bila dibiarkan) → Produk sebagai solusi (reply tengah + affiliate) → CTA (reply akhir: ajakan mencoba).',
    10),
  ('before-after', 'Before–After',
    'Sebelum menggunakan → Setelah menggunakan → Bukti → CTA',
    'Prioritaskan topik yang memungkinkan kontras SEBELUM vs SESUDAH memakai sesuatu (transformasi, hasil nyata) — topik harus memungkinkan bukti hasil.',
    'TEMPLATE before-after: alur Sebelum menggunakan (main + reply awal: kondisi lama yang kurang) → Setelah menggunakan (reply tengah: perubahan + affiliate sebagai penyebab) → Bukti (detail hasil) → CTA.',
    20),
  ('product-comparison', 'Product Comparison',
    'Produk A vs Produk B → cocok untuk siapa → kelebihan utama → rekomendasi',
    'Prioritaskan topik perbandingan (A vs B, pilihan sulit, mana yang cocok) — topik harus memungkinkan pembahasan 2 opsi + rekomendasi tegas.',
    'TEMPLATE product-comparison: alur Produk A vs Produk B (main: pertanyaan pilihan) → Cocok untuk siapa (reply awal: profil pengguna tiap opsi) → Kelebihan utama tiap opsi (reply tengah + affiliate untuk opsi rekomendasi) → Rekomendasi tegas + CTA.',
    30),
  ('top-product-list', 'Top Product List',
    'N produk terbaik → urutan per kebutuhan → kelas harga',
    'Prioritaskan topik daftar/rekomendasi (N terbaik, pilihan sesuai kebutuhan) yang memungkinkan ranking berdasarkan kebutuhan dan kelas harga.',
    'TEMPLATE top-product-list: alur N produk terbaik untuk kebutuhan X (main) → urutan berdasarkan kebutuhan audiens (tiap reply = 1 kandidat + kapan cocok) → kelas harga → affiliate untuk juara + CTA.',
    40),
  ('product-education', 'Product Education',
    'Fungsi produk → cara memilih → kesalahan umum → rekomendasi',
    'Prioritaskan topik edukatif (fungsi, cara memilih, kesalahan umum) — topik harus memungkinkan penjelasan yang berakhir pada rekomendasi produk.',
    'TEMPLATE product-education: alur Apa fungsi produk (main) → Cara memilih yang benar (reply awal) → Kesalahan umum yang harus dihindari (reply tengah) → Rekomendasi produk + affiliate + CTA.',
    50),
  ('promotion-urgency', 'Promotion & Urgency',
    'Diskon → voucher → periode promo → benefit → CTA',
    'Prioritaskan topik yang cocok dibungkus promo (diskon, voucher, periode terbatas, benefit) — topik harus memungkinkan urgensi jujur tanpa klaim fiktif.',
    'TEMPLATE promotion-urgency: alur Promo/diskon (main: hook penawaran) → Voucher & periode promo (reply awal) → Benefit produk (reply tengah + affiliate) → CTA urgensi. Jangan mengarang angka diskon/harga — hanya sebut promo bila ada di fakta/produk.',
    60)
ON CONFLICT (slug) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  description = EXCLUDED.description,
  discovery_hint = EXCLUDED.discovery_hint,
  development_hint = EXCLUDED.development_hint,
  sort_order = EXCLUDED.sort_order;

ALTER TABLE public.content_research_sessions
  ADD COLUMN IF NOT EXISTS template_slug text REFERENCES public.research_templates(slug) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_sessions_template ON public.content_research_sessions(template_slug);

ALTER TABLE public.research_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "research_templates_read" ON public.research_templates;
CREATE POLICY "research_templates_read" ON public.research_templates
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "research_templates_admin" ON public.research_templates;
CREATE POLICY "research_templates_admin" ON public.research_templates
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
