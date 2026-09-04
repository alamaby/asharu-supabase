-- Research cron 5min — restored 2026-09-05 to match remote schema_migrations
-- Original migration applied 2026-09-02 05:59 UTC via MCP; file was missing locally.
SELECT cron.alter_job(job_id => 3, schedule => '*/5 * * * *');
