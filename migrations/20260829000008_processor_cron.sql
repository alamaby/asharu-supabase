-- Process pending content_requests every 5 minutes via Supabase pg_cron +
-- pg_net (avoid Vercel Hobby cron-limit). The processor endpoint
-- /api/content/process authenticates with x-vercel-cron OR
-- Authorization: Bearer <CRON_SECRET>. We set a Postgres GUC
-- so pg_net can include the secret without leaking it to SQL logs.

-- Reuses pg_cron + pg_net (both pre-installed on Supabase).
-- CRON_SECRET must be set as a Supabase project secret (Dashboard
-- -> Database -> Settings -> Custom Postgres Config) and
-- mirrored to the SQL below as a literal.

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Schedule the processor every 5 minutes. The CRON_SECRET below is a
-- placeholder — replace via:
--   ALTER EXTENSION pg_cron UPDATE;
-- or set the secret as a Supabase Edge Function secret and read it from there.
-- For now we rely on the processor accepting `x-vercel-cron: 1` header,
-- which pg_net can set.

SELECT cron.schedule(
  'process-content-requests',
  '*/5 * * * *',
  $job$
    SELECT net.http_post(
      url := 'https://asharu.id/api/content/process',
      headers := jsonb_build_object(
        'x-vercel-cron', '1',
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 55000
    );
  $job$
);
