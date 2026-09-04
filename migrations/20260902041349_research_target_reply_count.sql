-- Research target reply count — restored 2026-09-05 to match remote schema_migrations
-- Original migration applied 2026-09-02 04:13 UTC via MCP; file was missing locally.
ALTER TABLE content_research_sessions
  ADD COLUMN target_reply_count integer;

COMMENT ON COLUMN content_research_sessions.target_reply_count IS
  'Target jumlah reply untuk Threads/Twitter. NULL = pakai default platform (threads/twitter=6, lainnya=1).';
