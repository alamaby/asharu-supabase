-- Studio generate image untuk user login (2026-09-11)
-- Menu baru /studio: user pilih provider/model/subjek/style/aspek; antre via worker;
-- histori prompt + hasil 30 hari; semuanya configurable by table.
-- Non-destruktif, aditif saja:
-- 1) image_aspect_ratios: katalog rasio (ganti CHECK hardcoded di image_gen_defaults)
-- 2) image_studio_config: singleton id=1 (retention_days, daily_limit, default pilihan, max prompt, polling)
-- 3) user_image_generations: histori per user (owner RLS) + expires_at
-- 4) Storage bucket user-images (public read, tulis via service_role/worker)
-- 5) Cron: asharu-studio-worker (*/5) + asharu-studio-cleanup (harian 02:00 WIB ~ 19:00 UTC)
-- Key material TIDAK di kolom — reuse image_provider_keys + Vault by-name.

-- 1) Katalog aspek rasio
CREATE TABLE IF NOT EXISTS public.image_aspect_ratios (
  slug text PRIMARY KEY,
  display_name text NOT NULL,
  width int NOT NULL DEFAULT 1024 CHECK (width > 0),
  height int NOT NULL DEFAULT 1024 CHECK (height > 0),
  sort_order int NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.image_aspect_ratios (slug, display_name, width, height, sort_order) VALUES
  ('1:1',  'Square (1:1)',    1024, 1024, 10),
  ('16:9', 'Landscape (16:9)', 1344,  768, 20),
  ('9:16', 'Portrait (9:16)',   768, 1344, 30),
  ('4:3',  'Landscape (4:3)',  1152,  864, 40),
  ('3:4',  'Portrait (3:4)',    864, 1152, 50)
ON CONFLICT (slug) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  width = EXCLUDED.width,
  height = EXCLUDED.height,
  sort_order = EXCLUDED.sort_order,
  is_active = true;

-- 2) Config studio (singleton id=1; NULL = Auto/waterfall)
CREATE TABLE IF NOT EXISTS public.image_studio_config (
  id int PRIMARY KEY CHECK (id = 1),
  retention_days int NOT NULL DEFAULT 30 CHECK (retention_days BETWEEN 1 AND 365),
  daily_limit int NULL DEFAULT 20 CHECK (daily_limit IS NULL OR daily_limit BETWEEN 1 AND 1000),
  default_provider_id uuid NULL REFERENCES public.image_providers(id) ON DELETE SET NULL,
  default_model_id uuid NULL REFERENCES public.image_models(id) ON DELETE SET NULL,
  CHECK ((default_provider_id IS NULL) = (default_model_id IS NULL)),
  default_style_slug text NULL REFERENCES public.image_style_presets(slug) ON DELETE SET NULL,
  default_subject_slug text NULL REFERENCES public.image_subject_templates(slug) ON DELETE SET NULL,
  default_aspect_slug text NOT NULL DEFAULT '1:1' REFERENCES public.image_aspect_ratios(slug) ON DELETE RESTRICT,
  max_prompt_length int NOT NULL DEFAULT 500 CHECK (max_prompt_length BETWEEN 10 AND 2000),
  allow_empty_prompt boolean NOT NULL DEFAULT false,
  polling_interval_sec int NOT NULL DEFAULT 10 CHECK (polling_interval_sec BETWEEN 3 AND 120),
  updated_by uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.image_studio_config (id) VALUES (1)
ON CONFLICT (id) DO NOTHING;

-- 3) Histori generate per user
CREATE TABLE IF NOT EXISTS public.user_image_generations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  image_prompt text NOT NULL CHECK (char_length(image_prompt) BETWEEN 10 AND 2000),
  negative_prompt text NULL CHECK (negative_prompt IS NULL OR char_length(negative_prompt) <= 500),
  provider_id uuid NULL REFERENCES public.image_providers(id) ON DELETE SET NULL,
  model_id uuid NULL REFERENCES public.image_models(id) ON DELETE SET NULL,
  style_slug text NULL REFERENCES public.image_style_presets(slug) ON DELETE SET NULL,
  subject_slug text NULL REFERENCES public.image_subject_templates(slug) ON DELETE SET NULL,
  aspect_slug text NOT NULL DEFAULT '1:1' REFERENCES public.image_aspect_ratios(slug) ON DELETE RESTRICT,
  provider_slug text NOT NULL DEFAULT '',
  model_slug text NOT NULL DEFAULT '',
  storage_path text NULL,
  public_url text NULL,
  width int NULL,
  height int NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'ready', 'failed')),
  last_error text NULL,
  attempts int NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  llm_meta jsonb NULL,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_user_images_owner
  ON public.user_image_generations (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_images_pending
  ON public.user_image_generations (status, created_at ASC) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_user_images_expiry
  ON public.user_image_generations (expires_at ASC);

-- 4) Bucket publik untuk hasil studio (tulis via service_role/worker)
INSERT INTO storage.buckets (id, name, public)
VALUES ('user-images', 'user-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- RLS
ALTER TABLE public.image_aspect_ratios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.image_studio_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_image_generations ENABLE ROW LEVEL SECURITY;

-- Aspek: admin tulis; authenticated read yang aktif (picker user login)
DROP POLICY IF EXISTS "image_aspects_admin" ON public.image_aspect_ratios;
CREATE POLICY "image_aspects_admin" ON public.image_aspect_ratios
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "image_aspects_user_read" ON public.image_aspect_ratios;
CREATE POLICY "image_aspects_user_read" ON public.image_aspect_ratios
  FOR SELECT TO authenticated USING (is_active = true);

-- Config studio: admin only (tiru image_gen_defaults)
DROP POLICY IF EXISTS "image_studio_config_admin" ON public.image_studio_config;
CREATE POLICY "image_studio_config_admin" ON public.image_studio_config
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

-- Histori: owner read/insert; update/delete owner ditolak (hanya service_role/admin)
-- agar status/hasil hanya ditulis worker. Delete oleh owner dilayani via server
-- action (service_role) agar file Storage ikut terhapus atomik.
DROP POLICY IF EXISTS "user_images_owner_read" ON public.user_image_generations;
CREATE POLICY "user_images_owner_read" ON public.user_image_generations
  FOR SELECT TO authenticated USING (auth.uid() = user_id OR is_admin());
DROP POLICY IF EXISTS "user_images_owner_insert" ON public.user_image_generations;
CREATE POLICY "user_images_owner_insert" ON public.user_image_generations
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "user_images_admin" ON public.user_image_generations;
CREATE POLICY "user_images_admin" ON public.user_image_generations
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "user_images_service" ON public.user_image_generations;
CREATE POLICY "user_images_service" ON public.user_image_generations
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Storage: public read untuk bucket user-images (tiru draft-images)
DROP POLICY IF EXISTS "user_images_public_read" ON storage.objects;
CREATE POLICY "user_images_public_read" ON storage.objects
  FOR SELECT TO anon, authenticated USING (bucket_id = 'user-images');

-- Perluas katalog read-only untuk picker user login (tanpa secret):
-- providers/models/styles/subjects aktif boleh dibaca authenticated (non-admin),
-- tulis tetap admin. Keys tetap no-read (kecuali service_role).
DROP POLICY IF EXISTS "image_providers_user_read" ON public.image_providers;
CREATE POLICY "image_providers_user_read" ON public.image_providers
  FOR SELECT TO authenticated USING (is_active = true);
DROP POLICY IF EXISTS "image_models_user_read" ON public.image_models;
CREATE POLICY "image_models_user_read" ON public.image_models
  FOR SELECT TO authenticated USING (is_active = true);
DROP POLICY IF EXISTS "image_styles_user_read" ON public.image_style_presets;
CREATE POLICY "image_styles_user_read" ON public.image_style_presets
  FOR SELECT TO authenticated USING (is_active = true);
DROP POLICY IF EXISTS "image_subjects_user_read" ON public.image_subject_templates;
CREATE POLICY "image_subjects_user_read" ON public.image_subject_templates
  FOR SELECT TO authenticated USING (is_active = true);

-- 5) Cron worker + cleanup (Bearer-from-Vault, tiru asharu-image-worker)
SELECT cron.schedule(
  'asharu-studio-worker',
  '*/5 * * * *',
  $job$
    SELECT net.http_post(
      url := 'https://asharu.id/api/studio/process',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'asharu_cron_secret' ORDER BY created_at DESC LIMIT 1),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 280000
    );
  $job$
);

-- Cleanup harian 19:00 UTC (= 02:00 WIB): hapus row + file Storage expired.
-- App membaca image_studio_config.retention_days secara live.
SELECT cron.schedule(
  'asharu-studio-cleanup',
  '0 19 * * *',
  $job$
    SELECT net.http_post(
      url := 'https://asharu.id/api/studio/cleanup',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'asharu_cron_secret' ORDER BY created_at DESC LIMIT 1),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 280000
    );
  $job$
);
