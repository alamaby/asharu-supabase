-- 20260922000002 — error_digest_cron
-- Menambah moment 'error_digest' ke automation_email_log CHECK constraint
-- sehingga log digest tercatat bersama log email automation lainnya.
-- Juga menjadwalkan pg_cron job 'asharu-error-digest' tiap 5 menit
-- menembak POST /api/notifications/error-digest (Bearer-from-Vault).

DO $$
DECLARE
  _constraint_name text;
BEGIN
  SELECT conname INTO _constraint_name
  FROM pg_constraint
  WHERE conrelid = 'automation_email_log'::regclass
    AND contype = 'c';

  IF _constraint_name IS NOT NULL THEN
    EXECUTE format(
      'ALTER TABLE public.automation_email_log DROP CONSTRAINT IF EXISTS %I;
       ALTER TABLE public.automation_email_log ADD CONSTRAINT %I CHECK (moment IN (''draft_ready'', ''published'', ''failure'', ''test'', ''error_digest''))',
      _constraint_name, _constraint_name
    );
  END IF;
END
$$;

DO $$
DECLARE
  _job_count integer;
BEGIN
  SELECT count(*) INTO _job_count
  FROM cron.job
  WHERE jobname = 'asharu-error-digest';

  IF _job_count = 1 THEN
    -- Job sudah ada — do nothing untuk hindari duplikat bila migration berulang.
    RETURN;
  END IF;

  PERFORM cron.schedule(
    'asharu-error-digest',
    '*/5 * * * *',
    $job$
      SELECT net.http_post(
        url := 'https://asharu.id/api/notifications/error-digest',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'asharu_cron_secret' ORDER BY created_at DESC LIMIT 1),
          'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 55000
      );
    $job$
  );
END
$$;
