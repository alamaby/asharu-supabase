-- Cron automation riset harian (Bearer-from-Vault, pola tiruan
-- asharu-social-poster / asharu-image-worker).
-- Worker: POST /api/automation/run. Job berjalan tiap 5 menit, TAPI worker
-- sendiri mem-gate ke jam lokal config (automation_configs.schedule_hour /
-- schedule_minute / timezone) dan 1 run per hari (UNIQUE automation_runs.run_date),
-- sehingga tidak perlu mengubah jadwal pg_cron saat jam config diubah.
-- Aman by-default: worker no-op selama automation_configs.is_enabled = false.
SELECT cron.schedule(
  'asharu-automation-run',
  '*/5 * * * *',
  $job$
    SELECT net.http_post(
      url := 'https://asharu.id/api/automation/run',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'asharu_cron_secret' ORDER BY created_at DESC LIMIT 1),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 290000
    );
  $job$
);
