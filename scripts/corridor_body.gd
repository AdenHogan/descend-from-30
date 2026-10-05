extends Area2D

# A SEARCHABLE body lying in a corridor (owner: corridor bodies "aren't searchable yet" — the flats' dead
# already are, room.gd `_setup_dead_bodies`). The body itself is baked decal art (corridor_decals
# `dead_plan`); this invisible Area2D sits over it on the walking lane. [E] (or a click on it) goes
# through the pockets: a line, then whatever `WorldState.dead_body_loot` seeded (often nothing).
# Searched state is the same anchor memory the flats use, keyed per floor, so a body is only ever
# searched once — and an item that doesn't fit in the pack STAYS on the body (never destroyed).

var floor_num: int = 0
var body_name: String = ""        # "cdead_<plan index>" — stable as the plan's prefix grows
var half_width: float = 40.0
var player: Node2D = null
var player_nearby: bool = false


func apartment_key() -> String:
	return "corridor_f%d" % floor_num


func is_searched() -> bool:
	return WorldState.is_anchor_searched(apartment_key(), body_name)


func _ready() -> void:
	add_to_group("corridor_body")
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(half_width * 2.0, 70.0)
	cs.shape = shape
	cs.position = Vector2(0, -20)
	add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_searched():
		player = body
		player_nearby = true
		HUD.show_world_prompt(self, "Body   [{interact}] Search", global_position)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		HUD.hide_world_prompt(self)


func _process(_delta: float) -> void:
	if player_nearby and Input.is_action_just_pressed("interact"):
		search()


func _input(event: InputEvent) -> void:
	if player_nearby and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and _is_mouse_over_body():
		search()


func _is_mouse_over_body() -> bool:
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return false
	var cam = p.get_node_or_null("Camera2D")
	if cam == null:
		return false
	var mouse_world = cam.get_screen_center_position() + \
		(get_viewport().get_mouse_position() - get_viewport().get_visible_rect().size / 2) / cam.zoom
	return absf(mouse_world.x - global_position.x) <= half_width and absf(mouse_world.y - (global_position.y - 20.0)) <= 60.0


## Go through the pockets. Returns what happened: "done" (searched — possibly empty), "full"
## (an item is there but the pack can't take it: nothing changes), or "already".
func search() -> String:
	if is_searched():
		return "already"
	var loot: Dictionary = WorldState.dead_body_loot(apartment_key(), body_name)
	var item: String = str(loot.get("item", ""))
	if item != "" and not WorldState.add_to_inventory(item):
		HUD.show_feedback("There's something in their pockets — but yours are full.")
		return "full"
	WorldState.mark_anchor_searched(apartment_key(), body_name)
	if item == "":
		HUD.show_feedback(WorldState.dead_search_line(body_name) + " Nothing.")
	else:
		HUD.show_feedback(WorldState.dead_search_line(body_name) + " You take the %s." % str(ItemData.get_item(item).get("name", "item")).to_lower())
	player_nearby = false
	HUD.hide_world_prompt(self)
	return "done"


func _exit_tree() -> void:
	if player_nearby:
		HUD.hide_world_prompt(self)
