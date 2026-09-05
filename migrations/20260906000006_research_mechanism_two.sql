-- Mekanisme riset kedua (product-first), non-destruktif.
-- 1) sessions.mechanism: 'satu' (topik dulu, default legacy) | 'dua' (produk dulu).
-- 2) session_products: 1-2 produk pilihan user per sesi mekanisme dua.
-- 3) drafts.product_id: produk tetap per draf (audit + idempotensi 3-kunci).

ALTER TABLE public.content_research_sessions
  ADD COLUMN IF NOT EXISTS mechanism text NOT NULL DEFAULT 'satu'
    CHECK (mechanism IN ('satu', 'dua'));

CREATE TABLE IF NOT EXISTS public.content_research_session_products (
  session_id uuid NOT NULL REFERENCES public.content_research_sessions(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.affiliate_products(id) ON DELETE RESTRICT,
  position int NOT NULL DEFAULT 0,
  PRIMARY KEY (session_id, product_id)
);
CREATE INDEX IF NOT EXISTS idx_session_products_session
  ON public.content_research_session_products (session_id, position);

ALTER TABLE public.content_drafts
  ADD COLUMN IF NOT EXISTS product_id uuid REFERENCES public.affiliate_products(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_drafts_product
  ON public.content_drafts (product_id);

ALTER TABLE public.content_research_session_products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "session_products_admin_read" ON public.content_research_session_products;
CREATE POLICY "session_products_admin_read" ON public.content_research_session_products
  FOR SELECT TO authenticated USING (is_admin());
DROP POLICY IF EXISTS "session_products_owner_read" ON public.content_research_session_products;
CREATE POLICY "session_products_owner_read" ON public.content_research_session_products
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.content_research_sessions s WHERE s.id = session_id AND s.created_by = auth.uid())
  );
DROP POLICY IF EXISTS "session_products_no_read" ON public.content_research_session_products;
CREATE POLICY "session_products_no_read" ON public.content_research_session_products
  FOR SELECT TO anon USING (false);
