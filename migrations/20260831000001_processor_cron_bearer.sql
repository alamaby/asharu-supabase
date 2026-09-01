-- SUPERSEDED (2 Sep 2026) — kept as a no-op for migration-history integrity.
--
-- Original purpose (P0 audit fix): stop accepting the spoofable
-- `x-vercel-cron` header and schedule pg_cron to send
-- `Authorization: Bearer <CRON_SECRET>` read from Vault.
--
-- The route-side change (Bearer-only via `isCronAuthorized`) is already
-- deployed in code. The cron scheduling itself is now owned by
-- 20260901000002_research_pipeline.sql, which schedules
-- `asharu-content-research` (*/10) and `asharu-content-legacy` (*/5) — both
-- read `asharu_cron_secret` from Vault and send the Bearer header.
--
-- This file therefore must NOT re-create the old `process-content-requests`
-- job (it would collide with the research endpoint). On dev databases where
-- the old job was already scheduled, we unschedule it here. On production
-- (where this migration was never applied) the unschedule is a harmless no-op.

SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'process-content-requests';
