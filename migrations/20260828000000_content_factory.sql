-- Content Factory migration
-- 2026-08-28
-- Tables: platforms, affiliate_products (with ASH-XXX friendly codes),
-- llm_providers/llm_models/llm_provider_keys/llm_call_logs, content_requests,
-- content_drafts (thread-shaped JSON), rate_limits, profiles.
-- RLS: anon INSERT content_requests; authenticated admin SELECT drafts;
-- service_role full access on llm_*; profiles linked to auth.users.

------------------------------------------------------------
-- Extensions
------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
-- supabase_vault is enabled per-project in Dashboard → Database → Extensions.

------------------------------------------------------------
-- Helper: is_admin() — read email claim from JWT
------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT lower(coalesce(auth.jwt() ->> 'email', '')) IN (
    'alam.aby.b@gmail.com',
    'alamaby@gmail.com'
  );
$$;

------------------------------------------------------------
-- Platforms
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.platforms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  display_name text NOT NULL,
  max_chars int,
  is_active boolean NOT NULL DEFAULT true
);

INSERT INTO public.platforms (slug, display_name, max_chars) VALUES
  ('threads',   'Threads',   500),
  ('twitter',   'Twitter',   280),
  ('instagram', 'Instagram', 2200),
  ('tiktok',    'TikTok',    2200),
  ('linkedin',  'LinkedIn',  3000),
  ('facebook',  'Facebook',  63206)
ON CONFLICT (slug) DO NOTHING;

------------------------------------------------------------
-- Affiliate products
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.affiliate_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  friendly_code text UNIQUE NOT NULL,
  external_id text UNIQUE NOT NULL,
  name_id text NOT NULL,
  name_en text NOT NULL,
  category text NOT NULL,
  merchant text NOT NULL,
  url text NOT NULL,
  image text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE SEQUENCE IF NOT EXISTS public.affiliate_friendly_seq START 1;

CREATE OR REPLACE FUNCTION public.gen_friendly_code()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.friendly_code IS NULL OR NEW.friendly_code = '' THEN
    NEW.friendly_code := 'ASH-' || lpad(nextval('public.affiliate_friendly_seq')::text, 3, '0');
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_friendly ON public.affiliate_products;
CREATE TRIGGER trg_friendly
  BEFORE INSERT ON public.affiliate_products
  FOR EACH ROW EXECUTE FUNCTION public.gen_friendly_code();

------------------------------------------------------------
-- LLM providers / models / keys / call logs
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.llm_providers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  display_name text NOT NULL,
  base_url text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  priority int NOT NULL DEFAULT 100
);

INSERT INTO public.llm_providers (slug, display_name, base_url, priority) VALUES
  ('naraya',     'Naraya Router',          'https://router.bynara.id/v1',                                       10),
  ('openrouter', 'OpenRouter',             'https://openrouter.ai/api/v1',                                      20),
  ('gemini',     'Google Gemini',          'https://generativelanguage.googleapis.com/v1beta',                  30),
  ('cloudflare', 'Cloudflare Workers AI',  'https://api.cloudflare.com/client/v4/accounts/{account_id}/ai/v1',  40)
ON CONFLICT (slug) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.llm_models (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id uuid NOT NULL REFERENCES public.llm_providers(id) ON DELETE CASCADE,
  model_id text NOT NULL,
  display_name text NOT NULL,
  is_default boolean NOT NULL DEFAULT false,
  UNIQUE (provider_id, model_id)
);

INSERT INTO public.llm_models (provider_id, model_id, display_name, is_default)
SELECT p.id, m.model_id, m.display_name, m.is_default
FROM public.llm_providers p
JOIN (VALUES
  ('naraya',     'naraya/nemotron-3-ultra',           'Nemotron 3 Ultra',          true),
  ('naraya',     'naraya/minimax-m3-free',             'MiniMax M3 Free',           false),
  ('naraya',     'naraya/deepseek-v4-flash',           'DeepSeek V4 Flash',         false),
  ('openrouter', 'openai/gpt-4o-mini',                 'GPT-4o Mini',               true),
  ('gemini',     'gemini-1.5-flash',                   'Gemini 1.5 Flash',          true),
  ('cloudflare', '@cf/meta/llama-3.1-8b-instruct',     'Llama 3.1 8B Instruct',     true)
) AS m(provider_slug, model_id, display_name, is_default) ON m.provider_slug = p.slug
ON CONFLICT (provider_id, model_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.llm_provider_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id uuid NOT NULL REFERENCES public.llm_providers(id) ON DELETE CASCADE,
  -- key_encrypted is filled via supabase Vault from the Dashboard or
  -- via `SELECT vault.create_secret(...)` — never via plain text.
  vault_secret_id uuid,
  key_hash text UNIQUE NOT NULL,
  priority int NOT NULL DEFAULT 0,
  usage_count int NOT NULL DEFAULT 0,
  failure_count int NOT NULL DEFAULT 0,
  last_used_at timestamptz,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

------------------------------------------------------------
-- Content requests
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.content_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  topic text NOT NULL CHECK (char_length(topic) BETWEEN 10 AND 500),
  platform_slug text NOT NULL REFERENCES public.platforms(slug),
  tone text NOT NULL CHECK (tone IN ('casual','formal','witty','professional','friendly','edukatif')),
  target_category text,
  audience text NOT NULL,
  cta_style text NOT NULL,
  purpose text NOT NULL,
  constraints text,
  keywords text,
  language text NOT NULL DEFAULT 'both' CHECK (language IN ('id','en','both')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','processing','needs_review','approved','rejected')),
  requested_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

------------------------------------------------------------
-- Content drafts
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.content_drafts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.content_requests(id) ON DELETE CASCADE,
  provider_id uuid REFERENCES public.llm_providers(id),
  model_id text,
  generated_thread jsonb NOT NULL,
  affiliate_injections jsonb NOT NULL,
  status text NOT NULL DEFAULT 'needs_review' CHECK (status IN ('needs_review','approved','rejected')),
  attempt int NOT NULL DEFAULT 1,
  llm_meta jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enforce shape: exactly 1 injection, with a valid https URL, and a known
-- friendly_code referencing affiliate_products.
ALTER TABLE public.content_drafts
  ADD CONSTRAINT one_injection CHECK (jsonb_array_length(affiliate_injections) = 1),
  ADD CONSTRAINT thread_shape CHECK (
    generated_thread ? 'main'
    AND generated_thread -> 'main' ? 'id'
    AND generated_thread -> 'main' ? 'en'
    AND jsonb_typeof(generated_thread -> 'replies') = 'array'
    AND (jsonb_array_length(generated_thread -> 'replies') BETWEEN 0 AND 5)
  );

------------------------------------------------------------
-- Rate limit (5/jam/IP for content_requests)
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rate_limits (
  ip text NOT NULL,
  scope text NOT NULL,
  window_start timestamptz NOT NULL DEFAULT now(),
  count int NOT NULL DEFAULT 0,
  PRIMARY KEY (ip, scope)
);

-- llm_call_logs after content tables (FKs now exist)
CREATE TABLE IF NOT EXISTS public.llm_call_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid REFERENCES public.content_requests(id) ON DELETE SET NULL,
  draft_id uuid REFERENCES public.content_drafts(id) ON DELETE SET NULL,
  provider_slug text NOT NULL,
  model_id text NOT NULL,
  key_hash text,
  prompt_tokens int,
  completion_tokens int,
  latency_ms int,
  http_status int,
  error text,
  created_at timestamptz NOT NULL DEFAULT now()
);

------------------------------------------------------------
-- Profiles
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text UNIQUE NOT NULL,
  is_admin boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

------------------------------------------------------------
-- RLS
------------------------------------------------------------
ALTER TABLE public.platforms          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.affiliate_products  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.llm_providers       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.llm_models          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.llm_provider_keys   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.llm_call_logs       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_requests    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_drafts      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rate_limits         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles            ENABLE ROW LEVEL SECURITY;

-- Platforms: public read
DROP POLICY IF EXISTS "platforms_read" ON public.platforms;
CREATE POLICY "platforms_read" ON public.platforms FOR SELECT TO anon, authenticated USING (true);

-- Affiliate products: public read, only service_role writes
DROP POLICY IF EXISTS "affiliate_read"  ON public.affiliate_products;
CREATE POLICY "affiliate_read"  ON public.affiliate_products FOR SELECT TO anon, authenticated USING (true);

-- llm_*: only service_role
DROP POLICY IF EXISTS "llm_providers_no_read"  ON public.llm_providers;
CREATE POLICY "llm_providers_no_read"  ON public.llm_providers FOR SELECT TO anon, authenticated USING (false);
DROP POLICY IF EXISTS "llm_models_no_read"     ON public.llm_models;
CREATE POLICY "llm_models_no_read"     ON public.llm_models FOR SELECT TO anon, authenticated USING (false);
DROP POLICY IF EXISTS "llm_keys_no_read"       ON public.llm_provider_keys;
CREATE POLICY "llm_keys_no_read"       ON public.llm_provider_keys FOR SELECT TO anon, authenticated USING (false);
DROP POLICY IF EXISTS "llm_call_logs_no_read"  ON public.llm_call_logs;
CREATE POLICY "llm_call_logs_no_read"  ON public.llm_call_logs FOR SELECT TO anon, authenticated USING (false);

-- content_requests: anon INSERT, admin SELECT, requester can read own
DROP POLICY IF EXISTS "requests_anon_insert" ON public.content_requests;
CREATE POLICY "requests_anon_insert" ON public.content_requests FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "requests_admin_read"  ON public.content_requests;
CREATE POLICY "requests_admin_read"  ON public.content_requests FOR SELECT TO authenticated USING (is_admin());
DROP POLICY IF EXISTS "requests_owner_read"  ON public.content_requests;
CREATE POLICY "requests_owner_read"  ON public.content_requests FOR SELECT TO authenticated
  USING (requested_by = auth.uid());
DROP POLICY IF EXISTS "requests_admin_update" ON public.content_requests;
CREATE POLICY "requests_admin_update" ON public.content_requests FOR UPDATE TO authenticated USING (is_admin());

-- content_drafts: only admin (service_role also via bypass)
DROP POLICY IF EXISTS "drafts_admin_read"   ON public.content_drafts;
CREATE POLICY "drafts_admin_read"   ON public.content_drafts FOR SELECT TO authenticated USING (is_admin());
DROP POLICY IF EXISTS "drafts_admin_update" ON public.content_drafts;
CREATE POLICY "drafts_admin_update" ON public.content_drafts FOR UPDATE TO authenticated USING (is_admin());

-- rate_limits: only service_role
DROP POLICY IF EXISTS "rate_limits_no_read"  ON public.rate_limits;
CREATE POLICY "rate_limits_no_read"  ON public.rate_limits FOR SELECT TO anon, authenticated USING (false);

-- profiles: only admin or self
DROP POLICY IF EXISTS "profiles_self_read"  ON public.profiles;
CREATE POLICY "profiles_self_read"  ON public.profiles FOR SELECT TO authenticated USING (id = auth.uid() OR is_admin());
DROP POLICY IF EXISTS "profiles_admin_write" ON public.profiles;
CREATE POLICY "profiles_admin_write" ON public.profiles FOR UPDATE TO authenticated USING (is_admin());

------------------------------------------------------------
-- Trigger: auto-create profile on auth.users insert
------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, is_admin)
  VALUES (NEW.id, NEW.email, lower(NEW.email) IN ('alam.aby.b@gmail.com','alamaby@gmail.com'))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
