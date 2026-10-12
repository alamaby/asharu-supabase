-- Test verifikasi post-migration pg_cron CPU savings:
-- Memastikan jadwal cron sesuai target penghematan CPU.
-- Expected:
-- asharu-automation-run: */15 * * * *
-- asharu-content-legacy: */5 * * * *
-- asharu-content-research: */5 * * * *
-- asharu-error-digest: */15 * * * *
-- asharu-image-worker: */5 * * * *
-- asharu-social-poster: */15 * * * *
-- asharu-studio-worker: */10 * * * *

SELECT jobname, schedule
FROM cron.job
WHERE jobname IN (
  'asharu-automation-run',
  'asharu-content-legacy',
  'asharu-content-research',
  'asharu-error-digest',
  'asharu-image-worker',
  'asharu-social-poster',
  'asharu-studio-worker'
)
ORDER BY jobname;
