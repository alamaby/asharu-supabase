-- Add timezone + locale preference to profiles.
-- Allows users to set their display timezone (IANA) and locale override.
-- Defaults: app falls back to device TZ, then Asia/Jakarta.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS timezone text,
  ADD COLUMN IF NOT EXISTS locale_pref text CHECK (locale_pref IS NULL OR locale_pref IN ('id', 'en'));

-- Self-update policy: a user can update their own timezone/locale_pref.
-- Admin can also update (covered by existing profiles_admin_write).
DROP POLICY IF EXISTS "profiles_self_update" ON public.profiles;
CREATE POLICY "profiles_self_update" ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid() OR is_admin())
  WITH CHECK (id = auth.uid() OR is_admin());
