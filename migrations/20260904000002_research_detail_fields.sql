-- Detail riset: tampilkan semua input user (topic, language, etc) - fix #2
ALTER TABLE public.content_research_sessions ADD COLUMN IF NOT EXISTS topic text;
ALTER TABLE public.content_research_sessions ADD COLUMN IF NOT EXISTS language text CHECK (language IS NULL OR language IN ('id','en','both'));
ALTER TABLE public.content_research_sessions ADD COLUMN IF NOT EXISTS target_category text;
ALTER TABLE public.content_research_sessions ADD COLUMN IF NOT EXISTS audience text;
ALTER TABLE public.content_research_sessions ADD COLUMN IF NOT EXISTS cta_style text;
ALTER TABLE public.content_research_sessions ADD COLUMN IF NOT EXISTS purpose text;
ALTER TABLE public.content_research_sessions ADD COLUMN IF NOT EXISTS constraints text;
ALTER TABLE public.content_research_sessions ADD COLUMN IF NOT EXISTS keywords text;
