-- Tambah 4 model Bynara (naraya) reasoning max — additive (2026-09-27).
-- Non-destruktif: tanpa DELETE/disable. Priority 300..330, di bawah semua
-- baris existing (paling tinggi 290 dari migrasi 20260918000003).
-- runtime reasoning_effort diteruskan via model-config.ts + openai-compatible.ts.
-- space-bunny-alpha & space-bunny-alpha-bynara adalah dua model berbeda
-- sesuai request user (bukan alias).

INSERT INTO public.llm_models (provider_id, model_id, display_name, is_default, priority, is_active, config)
SELECT p.id, m.model_id, m.display_name, false, m.priority, true, m.config::jsonb
FROM public.llm_providers p JOIN (VALUES
  ('naraya','agnes-3-flash','Agnes 3 Flash',300,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','longcat-2.5','LongCat 2.5',310,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','space-bunny-alpha','Space Bunny Alpha',320,'{"reasoning":true,"reasoning_effort":"max"}'),
  ('naraya','space-bunny-alpha-bynara','Space Bunny Alpha Bynara',330,'{"reasoning":true,"reasoning_effort":"max"}')
) AS m(slug,model_id,display_name,priority,config) ON m.slug=p.slug
ON CONFLICT (provider_id, model_id) DO UPDATE SET
  priority=EXCLUDED.priority, config=EXCLUDED.config, is_active=true, display_name=EXCLUDED.display_name;
