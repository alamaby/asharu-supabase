-- Image worker cron — Bearer-from-Vault, pola tiruan social poster.
-- Worker: POST /api/image/generate (klaim 1 draft image pending per tick).
-- Aman by-default: worker no-op selama belum ada baris pending.
SELECT cron.schedule(
  'asharu-image-worker',
  '*/5 * * * *',
  $job$
    SELECT net.http_post(
      url := 'https://asharu.id/api/image/generate',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'asharu_cron_secret' ORDER BY created_at DESC LIMIT 1),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 280000
    );
  $job$
);
