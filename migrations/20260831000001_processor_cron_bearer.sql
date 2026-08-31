-- P0 fix (audit 2026-08-30): the processor endpoint no longer accepts the
-- spoofable `x-vercel-cron` header — it now requires
-- `Authorization: Bearer <CRON_SECRET>`.
--
-- The secret is read from Supabase Vault (name: `asharu_cron_secret`) so it
-- never lives in this migration file. Seed it once with:
--   node --env-file=.env.local scripts/seed-cron-secret.mjs
-- and set the SAME value as `CRON_SECRET` in the Vercel env for this project.
--
-- Rotation: create a new Vault secret with the same name (cron picks the
-- newest via ORDER BY created_at DESC); delete stale entries in
-- Dashboard → Database → Vault.

-- Drop the previous header-only job if present (no-op when missing).
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'process-content-requests';

SELECT cron.schedule(
  'process-content-requests',
  '*/5 * * * *',
  $job$
    SELECT net.http_post(
      url := 'https://asharu.id/api/content/process',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || COALESCE(
          (SELECT decrypted_secret
             FROM vault.decrypted_secrets
            WHERE name = 'asharu_cron_secret'
            ORDER BY created_at DESC
            LIMIT 1),
          ''
        ),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 55000
    );
  $job$
);
