# Nexus-Bilder: Astra-Prompts

Ablauf wie bei Camp Everywhere:
1. Pascal erzeugt mit Astra zwei Bilder **ohne Text**. Sie kommen als `docs/art/header-art.png` (breit) und `docs/art/thumb-art.png` (16:9) ins Repo.
2. `python3 scripts/make_nexus_images.py` setzt den Titel „GOTHIC / LOCKPICKING“ und den Untertitel „Every Lock Has Its Combination“ links ins Bild. Das ergibt `docs/nexus-header.png` (1920×720) und `docs/nexus-thumb.png` (900×506).
3. Der Titel steht **links**, die linke Bildhälfte muss also ruhig und dunkel bleiben. Das Motiv kommt nach rechts.

## Header (breit, Seitenverhältnis 8:3, z. B. 2400×900)

> Dark medieval fantasy, cinematic close-up of an old iron padlock on a heavy weathered wooden chest, a thin steel lockpick inserted in the keyhole, a gloved hand turning it carefully. Warm candlelight from the right, deep shadows, dust in the air, rough wood grain, rusty iron fittings, subtle cold blue rim light. Gritty low-fantasy style like Gothic 2 and Kingdom Come, muted earthy colors, painterly realism. Subject placed on the right third of the image, the left half is dark empty wood and shadow. No text, no letters, no watermark.

## Thumbnail (16:9, z. B. 1600×900)

> Dark medieval fantasy, macro shot of a rusty iron lock with a keyhole on an old wooden door, a steel lockpick in the keyhole, one bright spark of candlelight on the metal, deep shadows around it. Gritty low-fantasy style like Gothic 2, muted brown and amber tones, painterly realism, strong contrast. Lock on the right side of the image, the top left corner dark and calm for a title. No text, no letters, no watermark.

Negativ-Prompt (falls Astra einen hat): `text, letters, logo, watermark, modern, sci-fi, bright colors, cartoon, blurry`
