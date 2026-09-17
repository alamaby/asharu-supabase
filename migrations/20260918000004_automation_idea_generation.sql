-- Tahap ideation workflow otomatis (17 Sep 2026).
-- Dua knob di automation_configs (singleton id=1):
--   1) idea_generation_enabled : default FALSE (konservatif — perilaku
--      existing tak berubah sampai admin menyalakan).
--   2) idea_product_search     : default TRUE (riset mekanisme Tavily;
--      false = LLM-only dari nama produk, hemat quota search).
-- Runner membaca via service_role (bypass RLS); policy admin existing
-- ("automation_configs_admin") otomatis mencakup kolom baru.
-- Non-destruktif, idempotent.

ALTER TABLE public.automation_configs
  ADD COLUMN IF NOT EXISTS idea_generation_enabled boolean NOT NULL DEFAULT false;

ALTER TABLE public.automation_configs
  ADD COLUMN IF NOT EXISTS idea_product_search boolean NOT NULL DEFAULT true;
