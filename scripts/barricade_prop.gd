extends Node2D

# Visual cue for a barricaded stairwell: a rough stack of crates/planks wedged
# across the opening. PURELY decorative — the pry action lives on the stairwell
# trigger behind it (see stairwell.gd). Spawned by building_floors for any blocked
# stairwell (both the up and down steps), so F2 barricade mode shows one on every
# floor. Lives at z 0 (corridor backdrop, like dynamic door art) so actors at
# z 1 pass in front of it.
#
# TEMPORARY ART: procedurally drawn crates. Swap for a real sprite later — keep
# it centred on the node origin so building_floors can keep placing it by the
# stairwell x. Size/tint tunables are up top.

const STACK_W := 92.0        # roughly a stairwell opening wide
const STACK_H := 118.0       # stacked height across the opening
const COLS := 2
const ROWS := 3

const CRATE := Color(0.40, 0.28, 0.16)
const CRATE_HI := Color(0.50, 0.36, 0.21)
const CRATE_LINE := Color(0.13, 0.09, 0.04)


func _ready() -> void:
	z_index = 0
	add_to_group("barricade_prop")
	queue_redraw()


func _draw() -> void:
	# A piled stack filling the opening, centred on the origin. Alternate rows are
	# nudged sideways so it reads as "wedged in", not a tidy grid.
	var bw := STACK_W / float(COLS)
	var bh := STACK_H / float(ROWS)
	for r in range(ROWS):
		var row_shift := (bw * 0.18) if (r % 2 == 1) else 0.0
		for c in range(COLS):
			var x := -STACK_W / 2.0 + c * bw + row_shift
			var y := -STACK_H / 2.0 + r * bh
			var rect := Rect2(x + 2.0, y + 2.0, bw - 4.0, bh - 4.0)
			draw_rect(rect, CRATE_HI if (r + c) % 2 == 0 else CRATE)
			draw_rect(rect, CRATE_LINE, false, 2.0)
			# A diagonal plank slash across each crate for a barricaded look.
			draw_line(Vector2(rect.position.x, rect.position.y + rect.size.y),
				Vector2(rect.position.x + rect.size.x, rect.position.y), CRATE_LINE, 1.5)
