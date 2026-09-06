-- Style preset UGC-POV: ilustrasi bergaya konten buatan pengguna (bukan cinematic).
-- Ciri: pencahayaan seadanya, kualitas kamera mediocre, POV sudut pandang pertama.
-- Dipakai worker sebagai style_suffix (hint LLM image_prompt + akhiran prompt final)
-- dan muncul otomatis di picker review (dibaca dinamis dari tabel).
INSERT INTO public.image_style_presets (slug, display_name, prompt_suffix) VALUES
  ('ugc-pov', 'UGC POV',
   'amateur user-generated content photo, first-person point of view, shot on an old phone camera, poor flat lighting, mediocre camera quality, slightly grainy and imperfect, candid everyday moment, no text, no watermark')
ON CONFLICT (slug) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  prompt_suffix = EXCLUDED.prompt_suffix;
