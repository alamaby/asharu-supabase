-- Template camera angle visualisasi (2026-09-11)
-- Dropdown "Camera angle" di Studio + review (cover + per-reply): worker
-- auto-append angle_en ke prompt secara natural (", angle") agar user tidak
-- perlu mengetik angle manual. Non-destruktif: tabel baru + seed + RLS admin
-- (meniru image_subject_templates) + 3 kolom FK aditif (SET NULL).
-- Catatan: subjek (image_subject_templates) TIDAK punya kolom di
-- content_draft_images (hanya helper suggest); angle DIPUTUSKAN punya kolom
-- (user 2026-09-11: auditable) — asimetri ini disengaja.

CREATE TABLE IF NOT EXISTS public.image_camera_angles (
  slug text PRIMARY KEY,
  display_name text NOT NULL,
  angle_en text NOT NULL CHECK (char_length(angle_en) BETWEEN 10 AND 500),
  is_active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 100,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.image_camera_angles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "image_angles_admin" ON public.image_camera_angles;
CREATE POLICY "image_angles_admin" ON public.image_camera_angles
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

-- Picker user login (tiru image_subjects_user_read): baca yang aktif saja.
DROP POLICY IF EXISTS "image_angles_user_read" ON public.image_camera_angles;
CREATE POLICY "image_angles_user_read" ON public.image_camera_angles
  FOR SELECT TO authenticated USING (is_active = true);

-- Seed awal (disetujui user 2026-09-11). 5 pertama diterjemahkan faithful
-- ID→EN; 20 sisanya verbatim EN. Apostrof diluruskan (Bird's-eye).
INSERT INTO public.image_camera_angles (slug, display_name, angle_en, is_active, sort_order) VALUES
  ('eye-level-three-quarter',      'Eye-Level Three-Quarter',       'Eye-level three-quarter view, natural and elegant',              true, 10),
  ('subtle-low-angle-full-body',   'Subtle Low-Angle Full-Body',    'Subtle low-angle full-body shot, tall and confident look',       true, 20),
  ('three-quarter-rear-view',      'Three-Quarter Rear View',       'Three-quarter rear view, showcasing long hair and outfit',       true, 30),
  ('telephoto-medium-shot',        'Telephoto Medium Shot',         'Telephoto medium shot, premium fashion look',                    true, 40),
  ('wide-angle-walking-shot',      'Wide-Angle Walking Shot',       'Wide-angle walking shot, dynamic urban fashion',                 true, 50),
  ('high-angle-medium-closeup',    'High-Angle Medium Close-Up',    'High-angle medium close-up shot',                                true, 60),
  ('low-angle-three-quarter-body', 'Low-Angle Three-Quarter Body',  'Low-angle three-quarter body shot',                              true, 70),
  ('eye-level-side-profile',       'Eye-Level Side-Profile Medium', 'Eye-level side-profile medium shot',                             true, 80),
  ('high-angle-seated-full-body',  'High-Angle Seated Full-Body',   'High-angle seated full-body shot',                               true, 90),
  ('three-quarter-rear-full-body', 'Three-Quarter Rear Full-Body',  'Three-quarter rear-view full-body shot',                         true, 100),
  ('over-shoulder-medium-shot',    'Over-the-Shoulder Medium',      'Over-the-shoulder medium shot',                                  true, 110),
  ('front-telephoto-medium-shot',  'Front-Facing Telephoto Medium', 'Front-facing telephoto medium shot',                             true, 120),
  ('wide-angle-front-walking',     'Wide-Angle Front Walking',      'Wide-angle front-facing walking shot',                           true, 130),
  ('side-view-full-body-walking',  'Side-View Full-Body Walking',   'Side-view full-body walking shot',                               true, 140),
  ('high-angle-three-quarter',     'High-Angle Three-Quarter Body', 'High-angle three-quarter body shot',                             true, 150),
  ('ground-level-rear-walking',    'Ground-Level Rear Walking',     'Ground-level rear walking shot',                                 true, 160),
  ('closeup-three-quarter',        'Close-Up Three-Quarter',        'Close-up three-quarter portrait',                                true, 170),
  ('centered-symmetrical-front',   'Centered Symmetrical Front',    'Centered symmetrical front-view shot',                           true, 180),
  ('off-center-medium-full',       'Off-Center Medium Full',        'Off-center medium full shot',                                    true, 190),
  ('dutch-angle-three-quarter',    'Dutch-Angle Three-Quarter',     'Dutch-angle three-quarter body shot',                            true, 200),
  ('birds-eye-seated-lifestyle',   'Bird''s-Eye Seated Lifestyle', 'Bird''s-eye seated lifestyle shot',                             true, 210),
  ('wide-environmental-rear',      'Wide Environmental Rear-View',  'Wide environmental rear-view shot',                              true, 220),
  ('low-angle-side-profile-full',  'Low-Angle Side-Profile Full',   'Low-angle side-profile full-body shot',                          true, 230),
  ('over-shoulder-closeup',        'Over-the-Shoulder Close-Up',    'Over-the-shoulder close-up shot',                                true, 240),
  ('eye-level-candid-side',        'Eye-Level Candid Side-Angle',   'Eye-level candid side-angle shot',                               true, 250)
ON CONFLICT (slug) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  angle_en = EXCLUDED.angle_en,
  is_active = true,
  sort_order = EXCLUDED.sort_order;

-- Default studio (singleton id=1) + histori studio + histori draf review.
ALTER TABLE public.image_studio_config
  ADD COLUMN IF NOT EXISTS default_camera_slug text NULL
  REFERENCES public.image_camera_angles(slug) ON DELETE SET NULL;
ALTER TABLE public.user_image_generations
  ADD COLUMN IF NOT EXISTS camera_slug text NULL
  REFERENCES public.image_camera_angles(slug) ON DELETE SET NULL;
ALTER TABLE public.content_draft_images
  ADD COLUMN IF NOT EXISTS camera_slug text NULL
  REFERENCES public.image_camera_angles(slug) ON DELETE SET NULL;
