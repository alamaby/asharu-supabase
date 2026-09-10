ALTER TABLE public.image_style_presets
  ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '';

ALTER TABLE public.image_style_presets
  ADD COLUMN IF NOT EXISTS negative_prompt text NULL;

INSERT INTO public.image_style_presets
  (slug, display_name, description, prompt_suffix, negative_prompt)
VALUES
  (
    'manga',
    'Manga',
    'Ilustrasi komik Jepang dengan line art, screentone, ekspresi kuat, dan storytelling dramatis.',
    'Japanese manga-style commercial illustration, clean expressive ink linework, crisp black-and-white drawing, detailed screentone shading, dynamic composition, dramatic camera angle, expressive character reaction, strong visual storytelling, high contrast, polished manga panel aesthetic, accurate product proportions, the featured product clearly visible as the main focal point, professional advertising composition, highly detailed, vertical social media format',
    'blurry, photorealistic, watercolor, oil painting, flat vector, western superhero comic style, messy anatomy, distorted hands, deformed product, incorrect product proportions, unreadable packaging, excessive text, speech bubbles, watermark, logo distortion, low contrast'
  ),
  (
    'manga-shonen',
    'Manga Shonen',
    'Manga aksi berenergi tinggi untuk gadget, olahraga, otomotif, perkakas, dan produk dinamis.',
    'Energetic shonen manga advertising illustration, bold action lines, dramatic perspective, intense facial expression, powerful pose, high-contrast black ink, detailed screentones, explosive visual energy, the featured product presented as a powerful solution, accurate product design, polished commercial manga artwork',
    'blurry, photorealistic, watercolor, oil painting, flat vector, western superhero comic style, messy anatomy, distorted hands, deformed product, incorrect product proportions, unreadable packaging, excessive text, speech bubbles, watermark, logo distortion, low contrast'
  ),
  (
    'manga-shojo',
    'Manga Shojo',
    'Manga elegan dan lembut untuk skincare, fashion, aksesori, dekorasi, dan produk perempuan.',
    'Elegant shojo manga advertising illustration, delicate clean linework, soft screentone shading, sparkling highlights, graceful composition, expressive eyes, decorative flowers and light effects, the featured product displayed beautifully as the main focal point, refined and charming commercial manga aesthetic',
    'blurry, photorealistic, watercolor, oil painting, flat vector, western superhero comic style, messy anatomy, distorted hands, deformed product, incorrect product proportions, unreadable packaging, excessive text, speech bubbles, watermark, logo distortion, low contrast'
  ),
  (
    'manga-slice-of-life',
    'Manga Slice of Life',
    'Manga kehidupan sehari-hari yang hangat untuk produk rumah tangga, sekolah, dapur, dan kebutuhan harian.',
    'Warm slice-of-life manga illustration, relatable everyday setting, natural character expression, clean ink lines, balanced screentone shading, friendly visual storytelling, the featured product being used naturally, accurate product shape and function, approachable social media advertisement',
    'blurry, photorealistic, watercolor, oil painting, flat vector, western superhero comic style, messy anatomy, distorted hands, deformed product, incorrect product proportions, unreadable packaging, excessive text, speech bubbles, watermark, logo distortion, low contrast'
  ),
  (
    'manga-comedy-reaction',
    'Manga Comedy Reaction',
    'Adegan reaksi manga yang lucu dan ekspresif untuk hook, produk viral, produk unik, dan racun marketplace.',
    'Humorous manga reaction scene, exaggerated but family-friendly expression, energetic motion lines, comedic visual timing, bold ink outlines, high-contrast screentones, the featured product creating a surprising solution, clear product visibility, scroll-stopping social media composition',
    'blurry, photorealistic, watercolor, oil painting, flat vector, western superhero comic style, messy anatomy, distorted hands, deformed product, incorrect product proportions, unreadable packaging, excessive text, speech bubbles, watermark, logo distortion, low contrast'
  ),
  (
    'pencil-drawing',
    'Pencil Drawing',
    'Gambar pensil realistis yang detail, halus, dan terlihat sebagai karya final.',
    'Highly detailed graphite pencil drawing, refined realistic rendering, precise contours, smooth tonal gradients, controlled cross-hatching, carefully rendered highlights and shadows, realistic material textures, subtle off-white drawing paper texture, polished hand-drawn finish, the featured product clearly presented as the main focal point, accurate product proportions, professional commercial illustration, clean balanced composition, vertical social media format',
    'rough unfinished sketch, messy construction lines, charcoal, colored pencil, ink drawing, watercolor, digital painting, photorealistic photograph, distorted product, inaccurate geometry, excessively dark shading, dirty background, unreadable details, text, watermark, signature'
  ),
  (
    'pencil-drawing-realistic',
    'Realistic Graphite',
    'Gambar graphite realistis berkualitas museum untuk produk premium dan detail material.',
    'Realistic graphite pencil drawing, museum-quality hand-rendered illustration, precise outlines, smooth graphite gradients, detailed surface texture, realistic reflections translated into pencil shading, accurate product geometry, elegant negative space, premium editorial advertising composition',
    'rough unfinished sketch, messy construction lines, charcoal, colored pencil, ink drawing, watercolor, digital painting, photorealistic photograph, distorted product, inaccurate geometry, excessively dark shading, dirty background, unreadable details, text, watermark, signature'
  ),
  (
    'pencil-drawing-technical',
    'Technical Pencil Drawing',
    'Gambar teknis graphite untuk elektronik, perkakas, furnitur, dan detail konstruksi.',
    'Technical graphite pencil drawing of the featured product, precise structural details, accurate perspective and geometry, fine mechanical linework, controlled cross-hatching, subtle dimension indicators without text or numbers, clean white drawing paper, professional industrial design presentation',
    'rough unfinished sketch, messy construction lines, charcoal, colored pencil, ink drawing, watercolor, digital painting, photorealistic photograph, distorted product, inaccurate geometry, excessively dark shading, dirty background, unreadable details, text, watermark, signature'
  ),
  (
    'pencil-drawing-soft-lifestyle',
    'Soft Lifestyle Pencil Drawing',
    'Gambar pensil realistis yang lembut untuk produk rumah tangga, dekorasi, skincare, dan keluarga.',
    'Soft realistic pencil drawing of an everyday lifestyle scene, delicate graphite shading, warm human atmosphere, natural product interaction, clean hand-drawn contours, subtle paper grain, the featured product emphasized through light and composition, refined commercial illustration',
    'rough unfinished sketch, messy construction lines, charcoal, colored pencil, ink drawing, watercolor, digital painting, photorealistic photograph, distorted product, inaccurate geometry, excessively dark shading, dirty background, unreadable details, text, watermark, signature'
  ),
  (
    'pencil-drawing-product-portrait',
    'Product Portrait Pencil Drawing',
    'Potret produk graphite terpusat untuk cover postingan atau slide terakhir carousel.',
    'Refined graphite pencil product portrait, centered hero composition, highly detailed contours and material textures, smooth tonal shading, elegant cast shadow, minimal off-white paper background, accurate product proportions, premium hand-drawn advertising artwork',
    'rough unfinished sketch, messy construction lines, charcoal, colored pencil, ink drawing, watercolor, digital painting, photorealistic photograph, distorted product, inaccurate geometry, excessively dark shading, dirty background, unreadable details, text, watermark, signature'
  ),
  (
    'pencil-sketch',
    'Pencil Sketch',
    'Sketsa pensil spontan dengan garis eksploratif, construction lines, dan arsiran ringan.',
    'Expressive graphite pencil sketch, loose exploratory linework, visible construction lines, varied pencil pressure, quick gestural shading, natural cross-hatching, partially unfinished edges, authentic sketchbook paper texture, spontaneous hand-drawn character, the featured product clearly recognizable, accurate overall proportions, visually engaging commercial concept sketch, balanced social media composition',
    'fully rendered photorealism, polished digital illustration, smooth vector lines, ink drawing, charcoal, watercolor, heavy black shading, chaotic scribbles, unrecognizable product, incorrect proportions, distorted packaging, excessive construction lines, text, watermark, signature'
  ),
  (
    'pencil-sketch-rough-concept',
    'Rough Concept Sketch',
    'Sketsa konsep kasar untuk ide, rancangan produk, atau hook bagaimana kalau.',
    'Rough product concept pencil sketch, loose exploratory contours, visible construction lines, quick shading strokes, multiple subtle line attempts, authentic designer sketchbook aesthetic, the featured product clearly recognizable, dynamic commercial concept presentation',
    'fully rendered photorealism, polished digital illustration, smooth vector lines, ink drawing, charcoal, watercolor, heavy black shading, chaotic scribbles, unrecognizable product, incorrect proportions, distorted packaging, excessive construction lines, text, watermark, signature'
  ),
  (
    'pencil-sketch-clean',
    'Clean Pencil Sketch',
    'Sketsa graphite spontan tetapi terkendali, aman untuk konten affiliate.',
    'Clean graphite pencil sketch, loose yet controlled linework, subtle construction lines, light cross-hatching, clear product silhouette, natural paper texture, accurate product proportions, minimal background, polished enough for commercial social media content',
    'fully rendered photorealism, polished digital illustration, smooth vector lines, ink drawing, charcoal, watercolor, heavy black shading, chaotic scribbles, unrecognizable product, incorrect proportions, distorted packaging, excessive construction lines, text, watermark, signature'
  ),
  (
    'pencil-sketch-storyboard',
    'Storyboard Sketch',
    'Sketsa storyboard untuk carousel cara penggunaan atau urutan problem-solution.',
    'Storyboard-style pencil sketch showing the featured product in use, clear sequential visual storytelling, expressive gestures, loose graphite linework, simple environmental details, quick cross-hatching, readable actions without text, accurate product appearance, commercial concept art presentation',
    'fully rendered photorealism, polished digital illustration, smooth vector lines, ink drawing, charcoal, watercolor, heavy black shading, chaotic scribbles, unrecognizable product, incorrect proportions, distorted packaging, excessive construction lines, text, watermark, signature'
  ),
  (
    'pencil-sketch-annotated-designer',
    'Annotated Designer Sketch',
    'Sketsa desainer industrial dengan studi detail dan callout visual untuk menjelaskan fitur.',
    'Industrial designer pencil sketch of the featured product, precise main silhouette, loose supporting construction lines, small visual detail studies surrounding the main product, callout lines without words, material exploration, controlled graphite shading, clean sketchbook presentation',
    'fully rendered photorealism, polished digital illustration, smooth vector lines, ink drawing, charcoal, watercolor, heavy black shading, chaotic scribbles, unrecognizable product, incorrect proportions, distorted packaging, excessive construction lines, text, watermark, signature'
  )
ON CONFLICT (slug) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  description = EXCLUDED.description,
  prompt_suffix = EXCLUDED.prompt_suffix,
  negative_prompt = EXCLUDED.negative_prompt;
