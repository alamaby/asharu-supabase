-- LLM configurable by table + 9 Bynara models (round-robin + max reasoning fallback)
-- 2026-09-03: semua provider/model kini configurable via priority/is_active/last_used_at/config
-- Bynara = naraya slug (router.bynara.id). Model IDs exact sesuai request.

-- 1) llm_models: tambah kolom untuk RR & reasoning
ALTER TABLE public.llm_models ADD COLUMN IF NOT EXISTS priority int NOT NULL DEFAULT 100;
ALTER TABLE public.llm_models ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;
ALTER TABLE public.llm_models ADD COLUMN IF NOT EXISTS last_used_at timestamptz;
ALTER TABLE public.llm_models ADD COLUMN IF NOT EXISTS config jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE public.llm_models ADD COLUMN IF NOT EXISTS usage_count int NOT NULL DEFAULT 0;
ALTER TABLE public.llm_models ADD COLUMN IF NOT EXISTS failure_count int NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_llm_models_provider_priority ON public.llm_models(provider_id, priority, last_used_at);

-- 2) llm_call_logs: log lengkap untuk UI admin
ALTER TABLE public.llm_call_logs ADD COLUMN IF NOT EXISTS stage text;
ALTER TABLE public.llm_call_logs ADD COLUMN IF NOT EXISTS request_messages jsonb;
ALTER TABLE public.llm_call_logs ADD COLUMN IF NOT EXISTS response_text text;
ALTER TABLE public.llm_call_logs ADD COLUMN IF NOT EXISTS key_id uuid REFERENCES public.llm_provider_keys(id) ON DELETE SET NULL;
ALTER TABLE public.llm_call_logs ADD COLUMN IF NOT EXISTS provider_id uuid REFERENCES public.llm_providers(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_llm_logs_created ON public.llm_call_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_llm_logs_provider ON public.llm_call_logs(provider_slug, model_id);
CREATE INDEX IF NOT EXISTS idx_llm_logs_request ON public.llm_call_logs(request_id);

-- 3) seed 9 Bynara exact, priority sesuai list 10..90, reasoning max
INSERT INTO public.llm_models (provider_id, model_id, display_name, is_default, priority, is_active, config)
SELECT p.id, m.model_id, m.display_name, false, m.priority, true, m.config::jsonb
FROM public.llm_providers p JOIN (VALUES
  ('naraya','agnes-2.5-flash','Agnes 2.5 Flash',10,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','mistral-medium-3-5','Mistral Medium 3.5',20,'{"reasoning":false}'),
  ('naraya','qwen3.8-27b','Qwen3.8 27B',30,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','stepfun-3.7-flash','StepFun 3.7 Flash',40,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','deepseek-v4-flash-free','DeepSeek V4 Flash Free',50,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','glm-5.3-flash-free','GLM 5.3 Flash Free',60,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','glm-5.3-free','GLM 5.3 Free',70,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','qwen3.8-flash-free','Qwen3.8 Flash Free',80,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','glm-5.2-promo','GLM 5.2 Promo',90,'{"reasoning":true,"reasoning_effort":"max"}')
) AS m(slug,model_id,display_name,priority,config) ON m.slug=p.slug
ON CONFLICT (provider_id, model_id) DO UPDATE SET priority=EXCLUDED.priority, config=EXCLUDED.config, is_active=true;

-- 4) pastikan model lama naraya tidak jadi default yang menghalangi RR (tetap aktif tapi priority 100+)
UPDATE public.llm_models SET priority = 110 WHERE model_id = 'nemotron-3-ultra' AND provider_id = (SELECT id FROM public.llm_providers WHERE slug='naraya');
UPDATE public.llm_models SET priority = 111 WHERE model_id = 'minimax-m3-free' AND provider_id = (SELECT id FROM public.llm_providers WHERE slug='naraya');
UPDATE public.llm_models SET priority = 112 WHERE model_id = 'deepseek-v4-flash' AND provider_id = (SELECT id FROM public.llm_providers WHERE slug='naraya');

-- 5) RPC helper: fetch ordered models (priority -> last_used -> failure) - optional, app does ORDER BY directly
