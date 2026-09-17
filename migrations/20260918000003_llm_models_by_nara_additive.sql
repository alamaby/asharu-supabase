-- Tambah 10 model Bynara (naraya) — additive, reasoning_effort max.
-- 2026-09-18: non-destruktif (tanpa DELETE/disable). Model aktif lama tetap aktif
-- sesuai konfirmasi user; hanya dua baris lama nonaktif (ling-3.0-flash-fin-free,
-- nemotron-3.5-lightning-free) yang diaktifkan kembali via ON CONFLICT DO UPDATE.
-- nemotron-3-ultra lama (nonaktif) TIDAK disentuh — user konfirmasi model berbeda
-- dari nemotron-3-ultra-free. Priority 200..290, di bawah semua baris existing.
-- Runtime reasoning_effort diteruskan via model-config.ts + openai-compatible.ts.

INSERT INTO public.llm_models (provider_id, model_id, display_name, is_default, priority, is_active, config)
SELECT p.id, m.model_id, m.display_name, false, m.priority, true, m.config::jsonb
FROM public.llm_providers p JOIN (VALUES
  ('naraya','atria-dawn','Atria Dawn',200,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','ling-3.0-flash-fin-free','Ling 3.0 Flash Fin Free',210,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','ling-3.0-flash-sante-free','Ling 3.0 Flash Sante Free',220,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','ling-3.0-flash-vl-free','Ling 3.0 Flash VL Free',230,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','nemotron-3-super-free','Nemotron 3 Super Free',240,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','nemotron-3-ultra-free','Nemotron 3 Ultra Free',250,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','nemotron-3.5-lightning-free','Nemotron 3.5 Lightning Free',260,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','union-alpha','Union Alpha',270,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','glm-5.3-flash','GLM 5.3 Flash',280,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','gpt-5.6-luna','GPT 5.6 Luna',290,'{"reasoning":true,"reasoning_effort":"max"}')
) AS m(slug,model_id,display_name,priority,config) ON m.slug=p.slug
ON CONFLICT (provider_id, model_id) DO UPDATE SET
  priority=EXCLUDED.priority, config=EXCLUDED.config, is_active=true, display_name=EXCLUDED.display_name;
