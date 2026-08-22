extends Node2D

# A placeholder "held" fire-extinguisher canister drawn in the player's hands while they
# spray — a stopgap until there's real hold-item art. A small red/white canister with a
# short black nozzle pointing the way the player faces. Added as a child of the player, it
# frees itself after the spray. Cosmetic, no collision.

var direction: float = 1.0     # +1 faces right, -1 faces left (set before add_child)
var life: float = 1.15
var _t: float = 0.0


func _ready() -> void:
	z_index = 2                # in front of the player body
	scale.x = -1.0 if direction < 0.0 else 1.0   # draw toward +x; flip for a left spray


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()


func _draw() -> void:
	# Small canister held at the hands, nozzle jutting forward (+x in local space). Kept
	# compact so it reads as held at the side, not covering the body.
	var w := 5.0
	var h := 12.0
	var top := -6.0
	draw_rect(Rect2(-w * 0.5, top, w, h), Color(0.82, 0.11, 0.11))          # red body
	draw_rect(Rect2(-w * 0.5, top + h * 0.42, w, h * 0.26), Color(0.95, 0.95, 0.95))  # white label band
	draw_rect(Rect2(-1.5, top - 3.0, 3.0, 4.0), Color(0.13, 0.13, 0.13))    # valve on top
	# short hose/nozzle pointing forward
	draw_rect(Rect2(w * 0.5 - 1.0, top + 1.0, 7.0, 2.0), Color(0.13, 0.13, 0.13))
