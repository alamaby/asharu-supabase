-- Reasoning LLM stage image_prompt (non-destruktif, aditif).
-- Menyimpan visual_strategy (before/after/bridge) + hook_keywords +
-- contradiction_check + justification agar reviewer bisa audit kenapa
-- visual tertentu dipilih (kasus 6d9658e9: pain-hook vs After visual).
-- LLM tidak dikirim reasoning ke provider image; hanya image_prompt.

ALTER TABLE public.content_draft_images
  ADD COLUMN IF NOT EXISTS reasoning jsonb NULL;

CREATE INDEX IF NOT EXISTS idx_draft_images_reasoning_strategy
  ON public.content_draft_images ((reasoning->>'visual_strategy'))
  WHERE reasoning IS NOT NULL;
