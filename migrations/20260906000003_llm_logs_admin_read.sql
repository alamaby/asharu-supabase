-- Fix "LLM terakhir (0)" di detail riset admin: llm_call_logs hanya punya
-- policy no_read untuk anon/authenticated, sehingga halaman admin yang baca
-- via user-JWT (createSupabaseServer) selalu dapat 0 baris. Tambah read khusus
-- admin, konsisten dengan search_call_logs / research_*.
-- Non-destruktif: policy no_read untuk anon tetap dipertahankan.
DROP POLICY IF EXISTS "llm_call_logs_admin_read" ON public.llm_call_logs;
CREATE POLICY "llm_call_logs_admin_read" ON public.llm_call_logs
  FOR SELECT TO authenticated USING (is_admin());
