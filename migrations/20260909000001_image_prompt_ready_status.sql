-- Reasoning-only cover — 2026-09-09
-- Status baru 'prompt_ready' di content_draft_images: draf prompt hasil reasoning
-- LLM otomatis (TANPA generate image) agar user cek/edit prompt di review
-- sebelum memutuskan Generate. Worker: pending tanpa prompt → prompt_ready;
-- pending dengan prompt (custom user) → generate seperti biasa.
-- Non-destruktif: CHECK diperluas, tanpa ubah baris/index yang ada.

ALTER TABLE public.content_draft_images DROP CONSTRAINT IF EXISTS content_draft_images_status_check;
ALTER TABLE public.content_draft_images
  ADD CONSTRAINT content_draft_images_status_check CHECK (status IN (
    'pending', 'prompt_ready', 'ready', 'failed', 'selected'
  ));
