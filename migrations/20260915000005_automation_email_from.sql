-- Ganti default from-address email automation ke domain alamaby.com (15 Sep 2026).
-- Non-destruktif: hanya mengubah DEFAULT kolom dan memperbarui baris singleton
-- bila nilainya masih default lama (tidak menimpa kustomisasi admin).
ALTER TABLE public.automation_configs
  ALTER COLUMN email_from SET DEFAULT 'Asharu <updates@alamaby.com>';

UPDATE public.automation_configs
   SET email_from = 'Asharu <updates@alamaby.com>',
       updated_at = now()
 WHERE id = 1
   AND email_from = 'Asharu <notifikasi@asharu.id>';
