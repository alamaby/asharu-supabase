-- Consolidate admin auth (1 Sep)
-- Closes P2 audit #12: profiles.is_admin becomes the single source of truth
-- for admin membership. Hardcoded email lists are removed from:
--   - public.is_admin()   (used by RLS policies)
--   - public.handle_new_user()  (auto-creates profile on signup)
--
-- Bootstrap: existing admin accounts (whose profiles exist or will be
-- re-created) are flipped to is_admin=true. Idempotent.
--
-- Note: profiles SELECT policy is "id = auth.uid() OR is_admin()", so the
-- self-evaluating form below can read its own row without RLS recursion.

------------------------------------------------------------
-- 1. is_admin() now reads profiles
------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
     WHERE id = auth.uid() AND is_admin = true
  );
$$;

------------------------------------------------------------
-- 2. handle_new_user() defaults is_admin=false
-- Admin elevation is done declaratively (e.g. by an existing admin
-- running UPDATE profiles SET is_admin = true WHERE email = ...) — never
-- via a hardcoded list in the codebase.
------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, is_admin)
  VALUES (NEW.id, NEW.email, false)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Trigger already exists from 20260828000000_content_factory.sql; the
-- CREATE OR REPLACE above is enough to swap the function body.

------------------------------------------------------------
-- 3. Bootstrap existing admins (idempotent)
-- These two emails were hardcoded in the previous is_admin() and
-- handle_new_user() bodies, so they implicitly had admin access. Mirror
-- that intent in profiles so their access does not regress.
------------------------------------------------------------
INSERT INTO public.profiles (id, email, is_admin)
SELECT au.id, au.email, true
  FROM auth.users au
 WHERE lower(au.email) IN (
       'alam.aby.b@gmail.com',
       'alamaby@gmail.com'
     )
ON CONFLICT (id) DO UPDATE
   SET is_admin = EXCLUDED.is_admin;
