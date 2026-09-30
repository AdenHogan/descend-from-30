extends RefCounted
class_name PackArt

# THE RUCKSACK — one pixel drawing shared by the HUD pack button, the backpack lying on the floor and the
# item icon (owner round 27: the old code-drawn button "looks like a Polaroid camera"). 16x20 art pixels:
# a grab loop, a domed lid with two tan webbing straps and brass buckles, a front pocket with a zip, and
# a bottle pocket each side. Drawn once into a texture (nearest-filtered by the callers) and cached.
# Regenerate/adjust by editing ROWS (each letter is a PALETTE key; "." is clear).

const W := 16
const H := 20
const PALETTE := {
	"o": Color8(22, 18, 14),
	"g": Color8(92, 108, 62),
	"G": Color8(60, 71, 43),
	"l": Color8(132, 150, 92),
	"s": Color8(44, 36, 30),
	"b": Color8(222, 190, 92),
	"p": Color8(74, 88, 52),
	"P": Color8(50, 60, 37),
	"z": Color8(200, 192, 158),
	"h": Color8(168, 186, 120),
	"d": Color8(70, 82, 48),
	"t": Color8(170, 138, 84),
	"T": Color8(120, 94, 56),
}
const ROWS := [
	"......oooo......",
	"......o..o......",
	"......o..o......",
	"....oooooooo....",
	"...olllggggGo...",
	"..olgtTgggtTGo..",
	"..olgtTgggtTGo..",
	"..olgtTgggtTGo..",
	"..olgtTgggtTGo..",
	"..oPPtTgggtTPo..",
	"..olgbbPPPbbGo..",
	"..ooobbooobboo..",
	"..olllllllllGo..",
	".pglppppppppGgP.",
	".pglzzzzzzzzGgP.",
	".pglPPPPPPPPGgP.",
	".pglppppppppGgP.",
	".ogGGGGGGGGGGgo.",
	"..oooooooooooo..",
	"................"
]

static var _tex: ImageTexture = null


static func texture() -> ImageTexture:
	if _tex == null:
		var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
		for y in range(H):
			var row: String = ROWS[y]
			for x in range(W):
				var k: String = row[x]
				if PALETTE.has(k):
					img.set_pixel(x, y, PALETTE[k])
		_tex = ImageTexture.create_from_image(img)
	return _tex
