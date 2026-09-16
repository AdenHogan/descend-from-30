# Art reference sheets

Reference images of the **current placeholder rigs** at true in-game scale, feet aligned —
for the artist brief (`docs/ART_REQUIREMENTS.md`) and quick comparison. These are
generated, not hand-made; regenerate whenever the rigs change.

- `enemy_lineup.png` — Standard / Big / Crawler / Long Arm / Spitter, with the player for
  scale.
- `player_poses.png` — gun idle / sword idle / crouch / push.
- `frames/` — the raw trimmed frames + `manifest.json` the composer reads.

## Regenerate

```
godot --headless --script res://tools/gen_sprite_lineup.gd   # dump trimmed frames + manifest
python3 tools/compose_sprite_lineup.py                        # lay out the labelled sheets
```

(Needs Pillow: `pip install pillow`. The Godot step composites CPU-side, so it runs
headless with no display.)
