extends Node2D

# Visual cue for a barricaded stairwell: a small pile of crates/planks wedged
# across the opening. PURELY decorative — the pry action lives on the stairwell
# trigger behind it (stairwell.gd). Spawned by building_floors at each active
# stairwell and told its `choke_floor`; it then keeps itself visible ONLY while
# that stairwell is actually barricaded (is_stair_blocked), so the crates can
# never disagree with the block — they vanish the instant it's pried, and a dev
# F2 toggle shows/hides them live. z 0 (backdrop) so actors at z 1 pass in front.
#
# TEMPORARY ART: procedural crates. Keep the pile centred on x and rising from
# the origin (placed at floor level) so building_floors can keep placing it by
# the stairwell x. Size/tint/floor tunables are up top.

# A short, tidy pile — 2 crates wide, ~2 high with the top row offset — so it
# reads as "wedged in" without towering or sinking below the floor.
const CRATE_W := 46.0
const CRATE_H := 34.0
const COLS := 2

const CRATE := Color(0.40, 0.28, 0.16)
const CRATE_HI := Color(0.50, 0.36, 0.21)
const CRATE_LINE := Color(0.13, 0.09, 0.04)

var choke_floor: int = -1   # set by building_floors; -1 = always visible (tests)


func _ready() -> void:
	z_index = 0
	add_to_group("barricade_prop")
	_sync_visible()
	queue_redraw()


func _process(_delta: float) -> void:
	_sync_visible()


func _sync_visible() -> void:
	# Crates are shown iff this stairwell is really barricaded right now.
	visible = choke_floor < 0 or WorldState.is_stair_blocked(choke_floor)


func _draw() -> void:
	# Pile RISES from the origin (placed at floor level): bottom row sits at y=0,
	# a shorter top row is nudged sideways and up so the lower crates half-cover
	# it. Bottom row drawn last so it reads as the front of the pile.
	var step := CRATE_H * 0.6                      # row overlap
	# Draw the top row first, the bottom row last (front of the pile). Row 0 =
	# bottom (COLS wide), row 1 = top (COLS-1 wide, offset in).
	for pass_i in range(2):
		var r := 1 - pass_i                        # 1 (top) then 0 (bottom)
		var cols_here := COLS if r == 0 else COLS - 1
		var row_w := float(cols_here) * CRATE_W
		var base_x := -row_w / 2.0
		var top := -CRATE_H - float(r) * step
		for c in range(cols_here):
			var rect := Rect2(base_x + c * CRATE_W + 2.0, top + 2.0, CRATE_W - 4.0, CRATE_H - 4.0)
			draw_rect(rect, CRATE_HI if (r + c) % 2 == 0 else CRATE)
			draw_rect(rect, CRATE_LINE, false, 2.0)
			draw_line(Vector2(rect.position.x, rect.position.y + rect.size.y),
				Vector2(rect.position.x + rect.size.x, rect.position.y), CRATE_LINE, 1.5)
