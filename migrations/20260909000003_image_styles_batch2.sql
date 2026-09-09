-- Batch style review konten — 2026-09-09
-- 1) Rename 'UGC POV' → 'UGC' (slug tetap 'ugc-pov' agar FK history aman);
--    suffix dibersihkan dari frasa first-person POV agar POV diatur dari teks prompt.
-- 2) Tambah 28 preset: editorial, hero-ad, lifestyle, problem/solution,
--    before-after, exploded/cutaway, 3D/clay/paper/isometric/blueprint,
--    lab, macro, floating, miniature, surreal, retro, scrapbook, doodle,
--    callout, comparison, infographic, checklist, proof-first, testimonial,
--    unboxing flatlay, scale comparison.
-- 3) Aturan teks: suffix umum tetap 'no text, no watermark'; khusus 7 style
--    berbasis teks/label, klausa no-text diganti 'minimal short text labels
--    allowed' (risiko teks gibberish khas AI image diterima user).
-- Non-destruktif: UPDATE display/suffix 1 baris + INSERT re-runnable.

UPDATE public.image_style_presets
SET display_name = 'UGC',
    prompt_suffix = 'amateur user-generated content photo, shot on an old phone camera, poor flat lighting, mediocre camera quality, slightly grainy and imperfect, candid everyday moment, no text, no watermark'
WHERE slug = 'ugc-pov';

INSERT INTO public.image_style_presets (slug, display_name, prompt_suffix) VALUES
  ('editorial-magazine', 'Editorial Magazine',
   'premium editorial magazine product photography, dramatic studio lighting, sophisticated minimal composition, product as hero, elegant lighting, luxury typography space, high-fashion advertising aesthetic, clean background, vertical social media format, minimal short text labels allowed'),
  ('product-hero-ad', 'Product Hero Advertisement',
   'billboard-style product hero advertisement, giant product centered as the sole focus, dramatic lighting, solid brand-color background, empty space for headline and CTA, ultra clean, no text, no watermark'),
  ('lifestyle-contextual', 'Lifestyle Contextual',
   'product shown in real everyday use in a natural lifestyle setting, relatable scene helping buyers picture it in their life, warm natural lighting, realistic context, no text, no watermark'),
  ('problem-vs-solution', 'Problem vs Solution',
   'split-scene realistic comparison, left side problem before using the product, right side solution after using the product, same angle and lighting both sides, honest realistic contrast, no exaggerated claims, no text, no watermark'),
  ('before-after-transformation', 'Before and After Transformation',
   'strong visual transformation diptych, left messy before state, right tidy organized after state, realistic believable change, dramatic but honest, no text, no watermark'),
  ('exploded-view', 'Exploded View',
   'technical exploded view of the product, internal components floating separated in mid-air, precise engineering layout, modern premium technical aesthetic, dark clean background, no text, no watermark'),
  ('cutaway-technical', 'Cutaway Technical Illustration',
   'cutaway illustration with transparent product shell revealing how it works inside, technical detail, clean engineering style, soft studio lighting, no text, no watermark'),
  ('3d-product-render', '3D Product Rendering',
   'professional 3D advertising render, glossy surfaces with soft rounded forms, premium studio lighting, smooth reflections, floating composition, clean background, no text, no watermark'),
  ('clay-render', 'Claymation / Clay Render',
   'cute claymation style, product and environment look handmade from clay, soft matte textures, playful friendly look, pastel palette, family-friendly, no text, no watermark'),
  ('paper-cutout', 'Paper Cutout',
   'layered paper cutout illustration, stacked paper shapes with visible depth and shadows, handcrafted eco feel, warm palette, no text, no watermark'),
  ('isometric-illustration', 'Isometric Illustration',
   'isometric illustration of product and environment from an isometric angle, package contents and features shown in one scene, clean geometric style, soft colors, no text, no watermark'),
  ('technical-blueprint', 'Technical Blueprint',
   'technical blueprint drawing style, white line work on deep blue background, measurement lines and component annotations, engineering schematic aesthetic, accurate generic details only, no text, no watermark'),
  ('scientific-laboratory', 'Scientific Laboratory',
   'product presented in a modern laboratory atmosphere, glass surfaces and lab equipment, tested high-tech impression, cool clean lighting, no medical symbols, no text, no watermark'),
  ('macro-detail', 'Macro Detail',
   'extreme macro close-up of one key product texture or detail, razor-sharp focus, shallow depth of field, dramatic side lighting revealing surface quality, no text, no watermark'),
  ('floating-product', 'Floating Product Composition',
   'product levitating mid-air surrounded by floating ingredients and accessories, dynamic advertising composition, dramatic lighting, clean background, suitable for cover and thumbnail, no text, no watermark'),
  ('miniature-world', 'Miniature World',
   'giant product surrounded by tiny miniature people using and building it, surprising scale contrast, humorous scroll-stopping scene, bright playful lighting, no text, no watermark'),
  ('surreal-advertising', 'Surreal Advertising',
   'surreal imaginative advertising scene, product in an impossible dreamlike situation, fantastical scale and setting for attention, vivid colors, not a factual product claim, no text, no watermark'),
  ('retro-advertising', 'Retro Advertising',
   'retro advertising poster aesthetic, vintage print texture with bold retro palette, nostalgic composition, product as hero, stylish throwback feel, no text, no watermark'),
  ('scrapbook-collage', 'Scrapbook / Collage',
   'scrapbook collage style, layered paper scraps with stickers and tape texture, slightly imperfect human handmade feel, warm casual arrangement, Gen-Z aesthetic, no text, no watermark'),
  ('hand-drawn-doodle', 'Hand-Drawn Doodle',
   'product photo with playful hand-drawn doodle overlays, circles arrows stars and short handwritten-style notes, personal casual review feel, minimal short text labels allowed'),
  ('feature-callout', 'Feature Callout',
   'product centered with thin callout lines pointing at features, clean advertising layout with space for labels, bright studio lighting, minimal short text labels allowed'),
  ('comparison-card', 'Comparison Card',
   'clean two-option comparison card layout, side-by-side product zones with space for price capacity and best-for rows, neutral background, minimal short text labels allowed'),
  ('infographic-guide', 'Infographic Product Guide',
   'compact single-image infographic guide layout, pictogram zones for who-it-is-for problem features usage and cautions, flat vector style, minimal short text labels allowed'),
  ('product-checklist', 'Product Checklist',
   'checklist-style buying guide visual with checkbox zones and product as recommended pick, clean helpful layout, minimal short text labels allowed'),
  ('proof-first-visual', 'Proof-First Visual',
   'evidence-led composition with zones for ratings detail shots and test snapshots, trustworthy review aesthetic, realistic lighting, minimal short text labels allowed'),
  ('testimonial-poster', 'Testimonial Poster',
   'customer testimonial poster layout with large quote zone and product as supporting element, warm trustworthy design, minimal short text labels allowed'),
  ('unboxing-flatlay', 'Unboxing Flat Lay',
   'top-down flat lay of full package contents neatly arranged, main product with cables manual bonus and accessories, clean bright background, e-commerce unboxing aesthetic, no text, no watermark'),
  ('scale-comparison', 'Scale Comparison',
   'product placed next to a familiar everyday object for scale, true-to-size realistic presentation, neutral background, catalog-clarity lighting, no text, no watermark')
ON CONFLICT (slug) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  prompt_suffix = EXCLUDED.prompt_suffix;
