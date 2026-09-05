-- Resync llm_models cloudflare: 10 model unik aktif, sisanya is_active=false
-- 2026-09-05: non-destruktif (tanpa DELETE). Duplikat dari list user sudah dihilangkan
-- (gemma-4-26b-a4b-it, qwen3-30b-a3b-fp8, gpt-oss-120b masing-masing muncul 2x).
-- Semua config reasoning=false: provider Cloudflare (providers/cloudflare.ts)
-- tidak meneruskan reasoning_effort ke Workers AI.

-- 1) Upsert 10 unik (priority = urutan tulis)
INSERT INTO public.llm_models (provider_id, model_id, display_name, is_default, priority, is_active, config)
SELECT p.id, m.model_id, m.display_name, false, m.priority, true, m.config::jsonb
FROM public.llm_providers p JOIN (VALUES
  ('cloudflare','@cf/google/gemma-4-26b-a4b-it','Gemma 4 26B IT',10,'{"reasoning":false}'),
  ('cloudflare','@cf/qwen/qwen3-30b-a3b-fp8','Qwen3 30B FP8',20,'{"reasoning":false}'),
  ('cloudflare','@cf/openai/gpt-oss-120b','GPT OSS 120B',30,'{"reasoning":false}'),
  ('cloudflare','@cf/mistralai/mistral-small-3.1-24b-instruct','Mistral Small 3.1 24B',40,'{"reasoning":false}'),
  ('cloudflare','@cf/meta/llama-3.3-70b-instruct-fp8-fast','Llama 3.3 70B FP8 Fast',50,'{"reasoning":false}'),
  ('cloudflare','@cf/aisingapore/gemma-sea-lion-v4-27b-it','Gemma Sea Lion v4 27B',60,'{"reasoning":false}'),
  ('cloudflare','@cf/deepseek-ai/deepseek-r1-distill-qwen-32b','DeepSeek R1 Distill Qwen 32B',70,'{"reasoning":false}'),
  ('cloudflare','@cf/qwen/qwq-32b','QwQ 32B',80,'{"reasoning":false}'),
  ('cloudflare','@cf/nvidia/nemotron-3-120b-a12b','Nemotron 3 120B',90,'{"reasoning":false}'),
  ('cloudflare','@cf/meta/llama-4-scout-17b-16e-instruct','Llama 4 Scout 17B',100,'{"reasoning":false}')
) AS m(slug,model_id,display_name,priority,config) ON m.slug=p.slug
ON CONFLICT (provider_id, model_id) DO UPDATE SET
  priority=EXCLUDED.priority, config=EXCLUDED.config, is_active=true, display_name=EXCLUDED.display_name;

-- 2) Disable model cloudflare di luar 10 list (termasuk llama-3.1-8b lama)
UPDATE public.llm_models SET is_active = false
WHERE provider_id = (SELECT id FROM public.llm_providers WHERE slug = 'cloudflare')
  AND model_id NOT IN (
    '@cf/google/gemma-4-26b-a4b-it','@cf/qwen/qwen3-30b-a3b-fp8','@cf/openai/gpt-oss-120b',
    '@cf/mistralai/mistral-small-3.1-24b-instruct','@cf/meta/llama-3.3-70b-instruct-fp8-fast',
    '@cf/aisingapore/gemma-sea-lion-v4-27b-it','@cf/deepseek-ai/deepseek-r1-distill-qwen-32b',
    '@cf/qwen/qwq-32b','@cf/nvidia/nemotron-3-120b-a12b','@cf/meta/llama-4-scout-17b-16e-instruct'
  );
