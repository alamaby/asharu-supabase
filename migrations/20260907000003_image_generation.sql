-- Image generation pasca-development — configurable by table, non-destruktif.
-- Pola tiruan llm_* (providers/models/provider_keys) + llm_stage_defaults + social_*.
-- 1) image_providers: 5 seed (pixazo 10 → cloudflare 20 → pollinations 30 → gemini 40 → bynara 50).
-- 2) image_models: 1 model awal per provider (flux / flux-schnell / flux / nano-banana-2-lite / agnes-image-2.1).
-- 3) image_provider_keys: N key per provider (primary + backup), round-robin + circuit breaker di app.
-- 4) image_style_presets: photorealistic, anime, saas-illustration, flat-vector, cinematic.
-- 5) image_gen_defaults: 1 baris global (NULL provider/model = waterfall prioritas).
-- 6) sessions: per-session override (image_model_id + image_style_slug).
-- 7) content_draft_images: history generate per draft (1 selected).
-- 8) content_drafts.selected_image_id + social_post_queue.image_url (lampiran Threads).
-- 9) llm_stage_defaults: tambah stage image_prompt (prompt visual dari post utama).
-- 10) Storage bucket draft-images (publik read, tulis via service_role).
-- Key material TIDAK di kolom — hanya vault_secret_name + key_suffix audit (Vault by-name).

-- 1) Providers
CREATE TABLE IF NOT EXISTS public.image_providers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  display_name text NOT NULL,
  base_url text NOT NULL,
  priority int NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.image_providers (slug, display_name, base_url, priority, config) VALUES
  ('pixazo',       'Pixazo',               'https://gateway.pixazo.ai/flux-1-schnell/v1/getData',                          10, '{}'::jsonb),
  ('cloudflare',   'Cloudflare Workers AI','https://api.cloudflare.com/client/v4/accounts/{account_id}/ai/v1',             20, '{}'::jsonb),
  ('pollinations', 'Pollinations',         'https://gen.pollinations.ai/v1',                                               30, '{}'::jsonb),
  ('gemini',       'Google Gemini',        'https://generativelanguage.googleapis.com/v1beta',                             40, '{}'::jsonb),
  ('bynara',       'Bynara Images',        'https://api-images.bynara.id/v1',                                              50, '{}'::jsonb)
ON CONFLICT (slug) DO NOTHING;

-- 2) Models
CREATE TABLE IF NOT EXISTS public.image_models (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id uuid NOT NULL REFERENCES public.image_providers(id) ON DELETE CASCADE,
  model_id text NOT NULL,
  display_name text NOT NULL,
  is_default boolean NOT NULL DEFAULT false,
  priority int NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  usage_count int NOT NULL DEFAULT 0,
  failure_count int NOT NULL DEFAULT 0,
  last_used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider_id, model_id)
);

INSERT INTO public.image_models (provider_id, model_id, display_name, is_default, priority)
SELECT p.id, m.model_id, m.display_name, m.is_default, m.priority
FROM public.image_providers p
JOIN (VALUES
  ('pixazo',       'flux-1-schnell',                          'Flux 1 Schnell',            true,  10),
  ('cloudflare',   '@cf/black-forest-labs/flux-1-schnell',    'Flux 1 Schnell',            true,  20),
  ('pollinations', 'flux',                                    'Flux Schnell',              true,  30),
  ('gemini',       'gemini-3.1-flash-lite-image',             'Nano Banana 2 Lite',        true,  40),
  ('bynara',       'agnes-image-2.1-flash',                   'Agnes Image 2.1 Flash',     true,  50)
) AS m(provider_slug, model_id, display_name, is_default, priority)
  ON m.provider_slug = p.slug
ON CONFLICT (provider_id, model_id) DO NOTHING;

-- 3) Provider keys (multi-key per provider: primary + backup-N)
CREATE TABLE IF NOT EXISTS public.image_provider_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id uuid NOT NULL REFERENCES public.image_providers(id) ON DELETE CASCADE,
  vault_secret_id uuid,
  vault_secret_name text NOT NULL,
  key_hash text UNIQUE NOT NULL,
  key_suffix text NULL,
  label text NOT NULL DEFAULT 'primary',
  priority int NOT NULL DEFAULT 0,
  usage_count int NOT NULL DEFAULT 0,
  failure_count int NOT NULL DEFAULT 0,
  last_used_at timestamptz,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_image_keys_provider
  ON public.image_provider_keys (provider_id, priority) WHERE is_active = true;

-- 4) Style presets
CREATE TABLE IF NOT EXISTS public.image_style_presets (
  slug text PRIMARY KEY,
  display_name text NOT NULL,
  prompt_suffix text NOT NULL DEFAULT '',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.image_style_presets (slug, display_name, prompt_suffix) VALUES
  ('photorealistic',   'Photorealistic',      'photorealistic, natural lighting, high detail, no text, no watermark'),
  ('anime',            'Anime',               'anime style illustration, vibrant, clean lines, no text, no watermark'),
  ('saas-illustration','SaaS Illustration',   'flat saas illustration, soft gradients, minimal shapes, no text, no watermark'),
  ('flat-vector',      'Flat Vector',         'flat vector art, bold shapes, limited palette, no text, no watermark'),
  ('cinematic',        'Cinematic',           'cinematic still, dramatic lighting, shallow depth of field, no text, no watermark')
ON CONFLICT (slug) DO NOTHING;

-- 5) Global defaults (singleton id=1; NULL provider/model = waterfall prioritas)
CREATE TABLE IF NOT EXISTS public.image_gen_defaults (
  id int PRIMARY KEY CHECK (id = 1),
  provider_id uuid REFERENCES public.image_providers(id) ON DELETE SET NULL,
  model_id uuid REFERENCES public.image_models(id) ON DELETE SET NULL,
  CHECK ((provider_id IS NULL) = (model_id IS NULL)),
  style_slug text REFERENCES public.image_style_presets(slug) ON DELETE SET NULL,
  aspect text NOT NULL DEFAULT '1:1' CHECK (aspect IN ('1:1', '16:9', '9:16', '4:3', '3:4')),
  updated_by uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.image_gen_defaults (id, provider_id, model_id, style_slug, aspect)
VALUES (1, NULL, NULL, 'photorealistic', '1:1')
ON CONFLICT (id) DO NOTHING;

-- 6) Per-session overrides
ALTER TABLE public.content_research_sessions
  ADD COLUMN IF NOT EXISTS image_model_id uuid REFERENCES public.image_models(id) ON DELETE SET NULL;
ALTER TABLE public.content_research_sessions
  ADD COLUMN IF NOT EXISTS image_style_slug text REFERENCES public.image_style_presets(slug) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_sessions_image_model ON public.content_research_sessions(image_model_id);

-- 7) Draft images (history; tepat 1 selected per draft via partial unique index)
CREATE TABLE IF NOT EXISTS public.content_draft_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  draft_id uuid NOT NULL REFERENCES public.content_drafts(id) ON DELETE CASCADE,
  image_prompt text NOT NULL,
  negative_prompt text NULL,
  style_slug text NULL REFERENCES public.image_style_presets(slug) ON DELETE SET NULL,
  provider_slug text NOT NULL,
  model_id text NOT NULL,
  key_suffix text NULL,
  storage_path text NULL,
  public_url text NULL,
  width int NULL,
  height int NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'ready', 'failed', 'selected')),
  last_error text NULL,
  attempts int NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  llm_meta jsonb NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_draft_images_draft
  ON public.content_draft_images (draft_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_draft_images_selected
  ON public.content_draft_images (draft_id) WHERE status = 'selected';

-- 8) Draft → selected image + queue → image attachment (aditif, nullable)
ALTER TABLE public.content_drafts
  ADD COLUMN IF NOT EXISTS selected_image_id uuid REFERENCES public.content_draft_images(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_drafts_selected_image ON public.content_drafts(selected_image_id);

ALTER TABLE public.social_post_queue
  ADD COLUMN IF NOT EXISTS image_url text NULL;

-- 9) LLM stage image_prompt (prompt visual dari post utama)
ALTER TABLE public.llm_stage_defaults DROP CONSTRAINT IF EXISTS llm_stage_defaults_stage_check;
ALTER TABLE public.llm_stage_defaults
  ADD CONSTRAINT llm_stage_defaults_stage_check CHECK (stage IN (
    'idea_generation', 'discovering', 'verifying', 'scoring', 'developing', 'regen_affiliate', 'image_prompt'
  ));
INSERT INTO public.llm_stage_defaults (stage, provider_id, model_id)
VALUES ('image_prompt', NULL, NULL)
ON CONFLICT (stage) DO NOTHING;

-- 10) Storage bucket publik (read publik; tulis via service_role)
INSERT INTO storage.buckets (id, name, public)
VALUES ('draft-images', 'draft-images', true)
ON CONFLICT (id) DO NOTHING;

-- RLS: admin read/write; service_role bypasses (worker). Anon: read hanya via storage policy.
ALTER TABLE public.image_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.image_models ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.image_provider_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.image_style_presets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.image_gen_defaults ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_draft_images ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "image_providers_admin" ON public.image_providers;
CREATE POLICY "image_providers_admin" ON public.image_providers
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "image_models_admin" ON public.image_models;
CREATE POLICY "image_models_admin" ON public.image_models
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "image_keys_no_read" ON public.image_provider_keys;
CREATE POLICY "image_keys_no_read" ON public.image_provider_keys FOR SELECT TO anon, authenticated USING (false);
DROP POLICY IF EXISTS "image_keys_service" ON public.image_provider_keys;
CREATE POLICY "image_keys_service" ON public.image_provider_keys
  FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "image_styles_admin" ON public.image_style_presets;
CREATE POLICY "image_styles_admin" ON public.image_style_presets
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "image_defaults_admin" ON public.image_gen_defaults;
CREATE POLICY "image_defaults_admin" ON public.image_gen_defaults
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "draft_images_admin" ON public.content_draft_images;
CREATE POLICY "draft_images_admin" ON public.content_draft_images
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "draft_images_public_read" ON storage.objects;
CREATE POLICY "draft_images_public_read" ON storage.objects
  FOR SELECT TO anon, authenticated USING (bucket_id = 'draft-images');
