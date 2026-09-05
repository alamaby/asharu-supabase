-- Resync llm_models: 7 Bynara (naraya) + 9 OpenRouter aktif, sisanya is_active=false
-- 2026-09-05: non-destruktif (tanpa DELETE) agar histori llm_call_logs + FK llm_stage_defaults aman.
-- Priority = urutan list user. Reasoning max: semua 7 naraya + nano-reasoning openrouter.

-- 1) Naraya upsert 7 (ID tanpa prefix, per 20260829000007_fix_model_ids)
INSERT INTO public.llm_models (provider_id, model_id, display_name, is_default, priority, is_active, config)
SELECT p.id, m.model_id, m.display_name, false, m.priority, true, m.config::jsonb
FROM public.llm_providers p JOIN (VALUES
  ('naraya','agnes-2.5-flash','Agnes 2.5 Flash',10,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','laguna-s-2.1','Laguna S 2.1',20,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','longcat-2.0-free','LongCat 2.0 Free',30,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','minimax-m3-free','MiniMax M3 Free',40,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','muse-spark-1.2-contributor-free','Muse Spark 1.2 Contributor Free',50,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','qwen3.8-27b','Qwen3.8 27B',60,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','stepfun-3.7-flash','StepFun 3.7 Flash',70,'{"reasoning":true,"reasoning_effort":"max"}')
) AS m(slug,model_id,display_name,priority,config) ON m.slug=p.slug
ON CONFLICT (provider_id, model_id) DO UPDATE SET
  priority=EXCLUDED.priority, config=EXCLUDED.config, is_active=true, display_name=EXCLUDED.display_name;

-- 2) Disable model naraya di luar 7 list
UPDATE public.llm_models SET is_active = false
WHERE provider_id = (SELECT id FROM public.llm_providers WHERE slug = 'naraya')
  AND model_id NOT IN (
    'agnes-2.5-flash','laguna-s-2.1','longcat-2.0-free','minimax-m3-free',
    'muse-spark-1.2-contributor-free','qwen3.8-27b','stepfun-3.7-flash'
  );

-- 3) OpenRouter upsert 9 (ID exact dengan prefix org/model + :free)
INSERT INTO public.llm_models (provider_id, model_id, display_name, is_default, priority, is_active, config)
SELECT p.id, m.model_id, m.display_name, false, m.priority, true, m.config::jsonb
FROM public.llm_providers p JOIN (VALUES
  ('openrouter','inclusionai/ling-3.0-flash-sante:free','Ling 3.0 Flash Sante Free',10,'{"reasoning":false}'),
  ('openrouter','poolside/laguna-s-2.1:free','Laguna S 2.1 Free',20,'{"reasoning":false}'),
  ('openrouter','poolside/laguna-xs-2.1:free','Laguna XS 2.1 Free',30,'{"reasoning":false}'),
  ('openrouter','cohere/north-mini-code:free','North Mini Code Free',40,'{"reasoning":false}'),
  ('openrouter','z-ai/glm-5.2:free','GLM 5.2 Free',50,'{"reasoning":false}'),
  ('openrouter','nvidia/nemotron-3-ultra-550b-a55b:free','Nemotron 3 Ultra 550B Free',60,'{"reasoning":false}'),
  ('openrouter','minimax/minimax-m3:free','MiniMax M3 Free',70,'{"reasoning":false}'),
  ('openrouter','nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free','Nemotron 3 Nano Reasoning Free',80,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('openrouter','google/gemma-4-31b-it:free','Gemma 4 31B IT Free',90,'{"reasoning":false}')
) AS m(slug,model_id,display_name,priority,config) ON m.slug=p.slug
ON CONFLICT (provider_id, model_id) DO UPDATE SET
  priority=EXCLUDED.priority, config=EXCLUDED.config, is_active=true, display_name=EXCLUDED.display_name;

-- 4) Disable model openrouter di luar 9 list (termasuk openai/gpt-4o-mini lama)
UPDATE public.llm_models SET is_active = false
WHERE provider_id = (SELECT id FROM public.llm_providers WHERE slug = 'openrouter')
  AND model_id NOT IN (
    'inclusionai/ling-3.0-flash-sante:free','poolside/laguna-s-2.1:free','poolside/laguna-xs-2.1:free',
    'cohere/north-mini-code:free','z-ai/glm-5.2:free','nvidia/nemotron-3-ultra-550b-a55b:free',
    'minimax/minimax-m3:free','nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free','google/gemma-4-31b-it:free'
  );
