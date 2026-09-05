-- Owner self-retry: user dapat membaca sesi miliknya (created_by) untuk halaman status.
-- Non-destruktif: tambah policy baca owner, tanpa ubah policy admin.
DROP POLICY IF EXISTS "research_sessions_owner_read" ON public.content_research_sessions;
CREATE POLICY "research_sessions_owner_read" ON public.content_research_sessions
  FOR SELECT TO authenticated USING (created_by = auth.uid());
DROP POLICY IF EXISTS "research_logs_owner_read" ON public.content_research_logs;
CREATE POLICY "research_logs_owner_read" ON public.content_research_logs
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.content_research_sessions s WHERE s.id = session_id AND s.created_by = auth.uid())
  );
DROP POLICY IF EXISTS "research_topics_owner_read" ON public.content_research_topics;
CREATE POLICY "research_topics_owner_read" ON public.content_research_topics
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.content_research_sessions s WHERE s.id = session_id AND s.created_by = auth.uid())
  );
