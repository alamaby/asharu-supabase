-- Resync llm_models: 5 Gemini + 6 Bynara (naraya) aktif, sisanya is_active=false
-- 2026-09-10: non-destruktif (tanpa DELETE) agar histori llm_call_logs + FK llm_stage_defaults aman.
-- Priority = urutan list user. Reasoning max untuk semua 11 (Gemini kini forward
-- reasoning_effort via generationConfig.thinkingConfig di providers/gemini.ts).

-- 1) Gemini upsert 5 (ID tanpa prefix, strip "gemini/" di gemini.ts)
INSERT INTO public.llm_models (provider_id, model_id, display_name, is_default, priority, is_active, config)
SELECT p.id, m.model_id, m.display_name, false, m.priority, true, m.config::jsonb
FROM public.llm_providers p JOIN (VALUES
  ('gemini','gemini-3.8-flash','Gemini 3.8 Flash',10,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('gemini','gemini-3.7-flash','Gemini 3.7 Flash',20,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('gemini','gemini-3.6-flash','Gemini 3.6 Flash',30,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('gemini','gemini-3.5-flash','Gemini 3.5 Flash',40,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('gemini','gemini-3.5-flash-lite','Gemini 3.5 Flash Lite',50,'{"reasoning":true,"reasoning_effort":"max"}')
) AS m(slug,model_id,display_name,priority,config) ON m.slug=p.slug
ON CONFLICT (provider_id, model_id) DO UPDATE SET
  priority=EXCLUDED.priority, config=EXCLUDED.config, is_active=true, display_name=EXCLUDED.display_name;

-- 2) Disable model gemini di luar 5 list
UPDATE public.llm_models SET is_active = false
WHERE provider_id = (SELECT id FROM public.llm_providers WHERE slug = 'gemini')
  AND model_id NOT IN (
    'gemini-3.8-flash','gemini-3.7-flash','gemini-3.6-flash',
    'gemini-3.5-flash','gemini-3.5-flash-lite'
  );

-- 3) Naraya (Bynara router) upsert 6 (ID tanpa prefix)
INSERT INTO public.llm_models (provider_id, model_id, display_name, is_default, priority, is_active, config)
SELECT p.id, m.model_id, m.display_name, false, m.priority, true, m.config::jsonb
FROM public.llm_providers p JOIN (VALUES
  ('naraya','agnes-2.5-flash','Agnes 2.5 Flash',10,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','laguna-s-2.1','Laguna S 2.1',20,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','ling-3.0-flash-fin-free','Ling 3.0 Flash Fin Free',30,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','longcat-2.0-free','LongCat 2.0 Free',40,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','nemotron-3.5-lightning-free','Nemotron 3.5 Lightning Free',50,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','stepfun-3.7-flash','StepFun 3.7 Flash',60,'{"reasoning":true,"reasoning_effort":"max"}')
) AS m(slug,model_id,display_name,priority,config) ON m.slug=p.slug
ON CONFLICT (provider_id, model_id) DO UPDATE SET
  priority=EXCLUDED.priority, config=EXCLUDED.config, is_active=true, display_name=EXCLUDED.display_name;

-- 4) Disable model naraya di luar 6 list (termasuk minimax-m3-free,
-- muse-spark-1.2-contributor-free, qwen3.8-27b dari resync 2026-09-05)
UPDATE public.llm_models SET is_active = false
WHERE provider_id = (SELECT id FROM public.llm_providers WHERE slug = 'naraya')
  AND model_id NOT IN (
    'agnes-2.5-flash','laguna-s-2.1','ling-3.0-flash-fin-free',
    'longcat-2.0-free','nemotron-3.5-lightning-free','stepfun-3.7-flash'
  );
