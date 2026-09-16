# Drop the 5 in-game screenshots here (exact filenames)

The PDF builder (`tools/build_art_brief_pdf.py`) embeds these if present, else draws a
labelled placeholder box. Save the pasted screenshots as:

- `title.png`        — Title screen (mood/tone target)
- `menu.png`         — Save-slot / Play menu (UI style)
- `settings.png`     — Controls / Settings screen (UI style)
- `run1_morning.png` — Run 1 (Morning) corridor combat: healthy portrait, sword equipped
- `run2_afternoon.png` — Run 2 (Afternoon) apartment interior: modular room, wounded, gun

Then: `python3 tools/build_art_brief_pdf.py`
