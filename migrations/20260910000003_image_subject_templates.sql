-- Template subjek visualisasi (2026-09-10)
-- Dropdown "Template subjek" di review (cover + per-reply): tombol "Siapkan prompt
-- awal" mengekstrak scene dari postingan via LLM lalu digabung dengan subject_en.
-- Non-destruktif: tabel baru + seed + RLS admin (meniru image_style_presets).

CREATE TABLE IF NOT EXISTS public.image_subject_templates (
  slug text PRIMARY KEY,
  display_name text NOT NULL,
  subject_en text NOT NULL CHECK (char_length(subject_en) BETWEEN 10 AND 500),
  is_active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 100,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.image_subject_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "image_subjects_admin" ON public.image_subject_templates;
CREATE POLICY "image_subjects_admin" ON public.image_subject_templates
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

-- Seed bawaan (disetujui user 2026-09-10)
INSERT INTO public.image_subject_templates (slug, display_name, subject_en, is_active, sort_order)
VALUES (
  'wanita-muda-modis',
  'Wanita Muda Modis',
  'A beautiful young woman with warm yellow langsat skin and long hair, wearing fitted, highly fashionable clothing',
  true,
  10
)
ON CONFLICT (slug) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  subject_en = EXCLUDED.subject_en,
  is_active = true,
  sort_order = EXCLUDED.sort_order;
