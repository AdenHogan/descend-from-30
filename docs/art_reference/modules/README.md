# Room-module art mockups

Pixel-art mockups for the six apartment modules (320 x 144, native 1:1, nearest filtering), drawn by
code so they're regenerable and exactly on the module geometry:

- `tools/art/pixlib.py` — the tiny drawing kit (+ the module constants: wall/floor seam y 100,
  room floor line 128 / feet 129, the two runtime window boxes to keep clear).
- `tools/art/<module>.py` — one script per module. Run `python3 tools/art/living_room.py` →
  `assets/rooms/living_room.png` (the in-game texture) + `living_room_x4.png` here (a 4x preview).

Rules each module follows (docs/ART_REQUIREMENTS.md): flat / neutrally lit (the engine lights it),
soft contact shadows only; every scavenge anchor (`Marker2D` in the module scene) sits ON a piece of
furniture; nothing tall in the runtime window boxes L (50..94, 34..86) / R (226..270, 34..86);
furniture bases in front of the seam, never below the floor line 128.

The module scene shows the art as an `Art` Sprite2D over the old ColorRect; the ColorRect's Label is
hidden but KEPT (room.gd reads its text for the room type).

Status: living room done (see `living_room_ingame_*.png` for morning / afternoon / night renders).
Bedroom, kitchen, bathroom, study, dining room: to do in the same style.
