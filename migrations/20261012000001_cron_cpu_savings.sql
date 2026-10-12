-- 20261012000001_cron_cpu_savings: jarangkan poller idle, research tetap */5.
-- ROLLBACK (manual, bila latensi >15 mnt tidak diterima):
-- DO $$
-- BEGIN
--   IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'asharu-automation-run') THEN
--     PERFORM cron.alter_job(job_id => (SELECT jobid FROM cron.job WHERE jobname='asharu-automation-run'), schedule => '*/5 * * * *');
--   END IF;
--   IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'asharu-error-digest') THEN
--     PERFORM cron.alter_job(job_id => (SELECT jobid FROM cron.job WHERE jobname='asharu-error-digest'), schedule => '*/5 * * * *');
--   END IF;
--   IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'asharu-social-poster') THEN
--     PERFORM cron.alter_job(job_id => (SELECT jobid FROM cron.job WHERE jobname='asharu-social-poster'), schedule => '*/5 * * * *');
--   END IF;
--   IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'asharu-studio-worker') THEN
--     PERFORM cron.alter_job(job_id => (SELECT jobid FROM cron.job WHERE jobname='asharu-studio-worker'), schedule => '*/5 * * * *');
--   END IF;
-- END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'asharu-automation-run') THEN
    PERFORM cron.alter_job(job_id => (SELECT jobid FROM cron.job WHERE jobname='asharu-automation-run'), schedule => '*/15 * * * *');
  END IF;

  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'asharu-error-digest') THEN
    PERFORM cron.alter_job(job_id => (SELECT jobid FROM cron.job WHERE jobname='asharu-error-digest'), schedule => '*/15 * * * *');
  END IF;

  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'asharu-social-poster') THEN
    PERFORM cron.alter_job(job_id => (SELECT jobid FROM cron.job WHERE jobname='asharu-social-poster'), schedule => '*/15 * * * *');
  END IF;

  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'asharu-studio-worker') THEN
    PERFORM cron.alter_job(job_id => (SELECT jobid FROM cron.job WHERE jobname='asharu-studio-worker'), schedule => '*/10 * * * *');
  END IF;
END $$;

-- SENGAJA TIDAK DIUBAH: asharu-content-research, asharu-content-legacy, asharu-image-worker (tetap */5 sampai M3 terverifikasi).
