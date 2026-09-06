-- Social poster cron (Threads tahap awal) — Bearer-from-Vault, pola tiruan research pipeline.
-- Worker: POST /api/social/post (klaim 1 antrean jatuh tempo per tick).
-- Aman by-default: worker no-op selama social_post_configs.is_enabled = false.
SELECT cron.schedule(
  'asharu-social-poster',
  '*/5 * * * *',
  $job$
    SELECT net.http_post(
      url := 'https://asharu.id/api/social/post',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'asharu_cron_secret' ORDER BY created_at DESC LIMIT 1),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 280000
    );
  $job$
);
