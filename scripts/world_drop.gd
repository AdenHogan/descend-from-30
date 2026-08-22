extends Area2D

const PICKUP_RANGE = 40.0
const GLOW_RANGE = 80.0

var item_id: String = ""
var target_apartment: String = ""
var drop_key: String = ""
var amount: int = 0  # Bank Notes bundle size; 0 = roll default on pickup

var player: Node2D = null
var player_nearby: bool = false

@onready var proximity_label: Label = $ProximityLabel


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# The prompt is drawn by the HUD in SCREEN space (crisp, in-bounds), not by
	# this world-space Label — hide the old one entirely.
	proximity_label.visible = false
	add_to_group("world_drop")
	player = get_tree().get_first_node_in_group("player")


func _prompt_text() -> String:
	if target_apartment != "":
		return "Key — Apt " + target_apartment + "   [Click] Take"
	var item_data = ItemData.get_item(item_id)
	var display_name = item_data.get("name", "Item") if not item_data.is_empty() else "Item"
	return display_name + "   [Click] Take"


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		player_nearby = true
		HUD.show_world_prompt(self, _prompt_text(), global_position)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		HUD.hide_world_prompt(self)


func _input(event: InputEvent) -> void:
	if not player_nearby:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_mouse_over_orb():
			_try_pickup()


func _process(_delta: float) -> void:
	queue_redraw()
	if not player_nearby:
		return
	if Input.is_action_just_pressed("interact"):
		_try_pickup()


func _is_mouse_over_orb() -> bool:
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return false
	var cam = p.get_node_or_null("Camera2D")
	if cam == null:
		return false
	var mouse_world = cam.get_screen_center_position() + \
		(get_viewport().get_mouse_position() - get_viewport().get_visible_rect().size / 2) / cam.zoom
	return global_position.distance_to(mouse_world) <= PICKUP_RANGE


func _try_pickup() -> void:
	var added: bool
	if target_apartment != "":
		added = WorldState.add_key_to_inventory(target_apartment)
		if added:
			HUD.show_feedback("Key — Apt " + target_apartment + " picked up.")
			HUD.refresh_inventory()
		else:
			HUD.show_feedback("Inventory full.")
			return
	else:
		added = WorldState.add_to_inventory(item_id, amount)
		if added:
			var item_data = ItemData.get_item(item_id)
			HUD.show_feedback(item_data.get("name", "Item") + " picked up.")
			HUD.refresh_inventory()
		else:
			HUD.show_feedback("Inventory full.")
			return
	if drop_key != "":
		WorldState.remove_world_drop(drop_key)
	HUD.hide_world_prompt(self)
	queue_free()


func _exit_tree() -> void:
	# Freed while the player was still in range (scene change, etc.) — don't leave
	# the HUD prompt pointing at a gone item.
	if player_nearby:
		HUD.hide_world_prompt(self)


func _draw() -> void:
	# The wall-mounted fire extinguisher is a fixed FIXTURE — drawn always (not a
	# floor glow orb that only shows up close), so you can spot it across the corridor.
	if item_id == "036":
		_draw_extinguisher()
		return
	if player == null:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist > GLOW_RANGE:
		return
	var alpha = 1.0 - clamp((dist - PICKUP_RANGE) / (GLOW_RANGE - PICKUP_RANGE), 0.0, 1.0)
	if target_apartment != "":
		draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.85, 0.1, alpha))
	else:
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.65, 0.0, alpha))


func _draw_extinguisher() -> void:
	# A slim red canister with a white label band — taller and narrower than the
	# thrown can — sitting on a small wall bracket. Brightens when you're in range.
	var w := 11.0
	var h := 34.0
	var top := -18.0                       # body spans local y -18..16 (up on the wall)
	var glow := 0.0
	if player != null:
		var dist := global_position.distance_to(player.global_position)
		glow = 1.0 - clamp((dist - PICKUP_RANGE) / (GLOW_RANGE - PICKUP_RANGE), 0.0, 1.0)
	# wall bracket behind the canister
	draw_rect(Rect2(-w * 0.5 - 3.0, top + h - 7.0, w + 6.0, 4.0), Color(0.20, 0.20, 0.22))
	# red body
	draw_rect(Rect2(-w * 0.5, top, w, h), Color(0.82, 0.11, 0.11))
	# white label band
	draw_rect(Rect2(-w * 0.5, top + h * 0.34, w, h * 0.30), Color(0.95, 0.95, 0.95))
	# dark handle / nozzle on top
	draw_rect(Rect2(-2.0, top - 6.0, 4.0, 7.0), Color(0.13, 0.13, 0.13))
	# pickable highlight when near
	if glow > 0.0:
		draw_rect(Rect2(-w * 0.5, top, w, h), Color(1.0, 1.0, 1.0, 0.30 * glow), false, 2.0)
