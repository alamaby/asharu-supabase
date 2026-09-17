-- Tambah provider ciora (Universal AI Gateway) + 10 model aktif
-- 2026-09-17: non-destruktif (tanpa DELETE) agar histori llm_call_logs + FK llm_stage_defaults aman.
-- Ciora = OpenAI-compatible (POST {base_url}/chat/completions, auth Bearer) —
-- runtime lewat OpenAICompatibleProvider via providerFromRow (completion.ts), tanpa kelas baru.
-- Priority 5 = paling depan (naraya 10, openrouter 20, gemini 30, cloudflare 40).
-- Semua 10 model reasoning max (keputusan user 2026-09-17); knob per-model tetap
-- bisa diubah dari admin tanpa migrasi baru. Model IDs exact sesuai request.

-- 1) Upsert provider ciora
INSERT INTO public.llm_providers (slug, display_name, base_url, priority)
VALUES ('ciora', 'Ciora Gateway', 'https://ciora.id/v1', 5)
ON CONFLICT (slug) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  base_url = EXCLUDED.base_url,
  priority = EXCLUDED.priority,
  is_active = true;

-- 2) Upsert 10 model ciora (priority = urutan list user)
INSERT INTO public.llm_models (provider_id, model_id, display_name, is_default, priority, is_active, config)
SELECT p.id, m.model_id, m.display_name, false, m.priority, true, m.config::jsonb
FROM public.llm_providers p JOIN (VALUES
  ('ciora','nex-agi/nex-n2.5','Nex N2.5',10,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('ciora','inclusionai/ling-3.0-flash-vl','Ling 3.0 Flash VL',20,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('ciora','poolside/laguna-s-2.1-free','Laguna S 2.1 Free',30,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('ciora','z-ai/glm-5.3-flash','GLM 5.3 Flash',40,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('ciora','qwen/qwen3.6-35b-a3b','Qwen3.6 35B A3B',50,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('ciora','step-3.7-flash','Step 3.7 Flash',60,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('ciora','ciora-ai-free','Ciora AI Free',70,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('ciora','cohere/north-mini-code-free','North Mini Code Free',80,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('ciora','ciora-vision-free','Ciora Vision Free',90,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('ciora','ciora-coding-free','Ciora Coding Free',100,'{"reasoning":true,"reasoning_effort":"max"}')
) AS m(slug,model_id,display_name,priority,config) ON m.slug = p.slug
ON CONFLICT (provider_id, model_id) DO UPDATE SET
  priority = EXCLUDED.priority, config = EXCLUDED.config, is_active = true, display_name = EXCLUDED.display_name;
