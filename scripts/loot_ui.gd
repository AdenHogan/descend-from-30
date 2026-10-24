extends CanvasLayer

# Scavenge result panel — CENTRED, shows the item icon + name, and is taken by:
#   • double-clicking it, or
#   • dragging it onto your pack (the backpack button, bottom-right — there is no bar or hotbar), or
#   • pressing E / interact,
# and LEFT by walking away, by clicking anywhere in the world off the panel, or — stepped up at
# set-back furniture, where there's no walking — by any movement key (player.gd steps you down and
# calls leave()). Searching again re-opens it. No Take/Leave buttons. The panel must ALWAYS be
# leavable: a full inventory once trapped the player up at a bookshelf (owner playtest — S and clicks
# were both ignored while it was open, and the only other exit, walking, doesn't exist up there).
# Built in code so the layout is controlled here.

const REVEAL_TIME = 3.0
const EMPTY_REVEAL_FACTOR = 0.5        # a search that turns up nothing takes half as long (owner round 36g: "finding nothing takes too long")
const NOTHING_CLOSE_TIME = 1.6
const RingGeo := preload("res://scripts/ring_geo.gd")
const DRAG_THRESHOLD = 8.0
const DOUBLE_CLICK_TIME = 0.35
const PANEL_W = 300.0
const SEARCH_W = 220.0                 # the compact panel while a search runs (owner round 45: "the searching box is far too big")
const SCREEN_W = 1152.0
const SCREEN_H = 648.0

var reveal_timer = 0.0
var reveal_time = REVEAL_TIME          # this search's length (halved when the node holds nothing)
var is_revealing = false
var nothing_timer = 0.0
var current_item_id = ""
var current_key_target = ""
var current_anchor_name = ""
var current_apartment_id = ""
var anchor_node: Node = null
var has_item = false               # a takeable item is currently shown

# UI
var panel: PanelContainer = null
var icon: TextureRect = null
var name_label: Label = null
var hint_label: Label = null
var compare_label: RichTextLabel = null      # a found weapon's numbers, set beside the one in hand (ItemCompare)
var icon_row: CenterContainer = null
var search_bar: Control = null         # the filling bar shown while a search runs

# drag / double-click
var drag_armed = false
var drag_active = false
var drag_from = Vector2.ZERO
var ghost: TextureRect = null
var last_press_time = 0.0
var _center: CenterContainer = null
var _mouse_pos: Vector2 = Vector2.ZERO # the pointer as the last motion event reported it (a drag follows this — a touch drag has no cursor to poll)
var _shift: float = 0.0                # how far the panel has slid left to make room for the pack ring
const RING_GAP := 40.0                 # clear space between the panel and the ring
const PACK_SHIFT := 340.0              # (the ring takes the right ~320 px of the screen; the panel centres in the rest)


func _ready() -> void:
	layer = 3
	add_to_group("loot_ui")
	_build_ui()
	visible = false


## Leave the panel without taking anything (no-op when it isn't open). Safe from any state.
func leave() -> void:
	if visible:
		_close(false)


func _build_ui() -> void:
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_center = center

	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	style.border_color = Color(0.7, 0.68, 0.55, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	icon_row = CenterContainer.new()
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.custom_minimum_size = Vector2(PANEL_W - 32, 112)
	vbox.add_child(icon_row)
	icon = TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(112, 112)   # the 56px icon at exactly 2x
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_row.add_child(icon)

	name_label = Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.82))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(PANEL_W - 32, 0)
	vbox.add_child(name_label)

	compare_label = RichTextLabel.new()
	compare_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compare_label.bbcode_enabled = true
	compare_label.fit_content = true
	compare_label.scroll_active = false
	compare_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	compare_label.add_theme_font_size_override("normal_font_size", 14)
	compare_label.add_theme_color_override("default_color", Color(0.78, 0.82, 0.86))
	compare_label.custom_minimum_size = Vector2(PANEL_W - 32, 0)
	compare_label.visible = false
	vbox.add_child(compare_label)

	hint_label = Label.new()
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(PANEL_W - 32, 0)
	vbox.add_child(hint_label)

	search_bar = SearchBar.new()
	search_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	search_bar.custom_minimum_size = Vector2(SEARCH_W - 32, SearchBar.BAR_H)
	search_bar.visible = false
	vbox.add_child(search_bar)


## A search is running: a small panel with just the word and a bar that fills across it; or it has finished: the full panel.
func _layout(searching: bool) -> void:
	var w: float = SEARCH_W if searching else PANEL_W
	panel.custom_minimum_size = Vector2(w, 0)
	name_label.custom_minimum_size = Vector2(w - 32, 0)
	name_label.add_theme_font_size_override("font_size", 16 if searching else 22)
	icon_row.visible = not searching
	hint_label.visible = not searching
	compare_label.visible = false
	search_bar.visible = searching
	panel.reset_size()           # a PanelContainer keeps its biggest size until told to shrink


func open(item_id: String, anchor_name: String, apartment_id: String) -> void:
	WorldState.loot_open = true
	is_revealing = false
	has_item = false
	nothing_timer = 0.0
	current_item_id = item_id
	current_anchor_name = anchor_name
	current_apartment_id = apartment_id
	current_key_target = ""
	anchor_node = get_tree().get_root().find_child(anchor_name, true, false)

	if WorldState.is_anchor_a_key(apartment_id, anchor_name):
		current_key_target = WorldState.get_anchor_key_target(apartment_id, anchor_name)
		current_item_id = WorldState.key_item_for(current_key_target)

	reveal_time = REVEAL_TIME * (EMPTY_REVEAL_FACTOR if current_item_id == "" or ItemData.get_item(current_item_id).is_empty() else 1.0)

	# Someone living here watches you go through their things (resident_npc.gd).
	get_tree().call_group("resident_npc", "on_scavenge", "start", apartment_id)
	if WorldState.is_anchor_searched(apartment_id, anchor_name):
		_reveal_item()
		visible = has_item                    # an empty one has already said so and closed itself
		return

	reveal_timer = 0.0
	is_revealing = true
	# The press starts it: the drawer opens, the glass tips, the screen goes dark NOW, while the bar fills (owner round 45c)
	if anchor_node != null and is_instance_valid(anchor_node) and anchor_node.has_method("on_search_begin"):
		anchor_node.on_search_begin()
	icon.texture = null
	name_label.text = "Searching"
	hint_label.text = ""
	_layout(true)
	search_bar.set_progress(0.0, reveal_time)
	visible = true


## What the player mutters over an empty search: a short line, stable per node (so re-searching reads the same).
const NOTHING_LINES := ["Nothing.", "Empty.", "Just dust.", "Nothing useful.", "Nothing here.", "Picked clean."]


static func nothing_line(apartment_id: String, anchor_name: String) -> String:
	return NOTHING_LINES[absi(hash(apartment_id + "/" + anchor_name)) % NOTHING_LINES.size()]


func _reveal_item() -> void:
	_layout(false)
	WorldState.mark_anchor_searched(current_apartment_id, current_anchor_name)
	get_tree().call_group("open_furniture", "on_searched", current_apartment_id, current_anchor_name)   # (already open since the press; a no-op then)
	is_revealing = false
	var item_data = ItemData.get_item(current_item_id)
	if current_item_id == "":
		# An empty search is a line, not a panel (owner round 48i: "if there is nothing found, we don't need a big empty inventory box that pops... the
		# player can say nothing in real time following the search, allowing us to just keep going"): close at once and say so in passing.
		icon.texture = null
		name_label.text = ""
		hint_label.text = ""
		has_item = false
		nothing_timer = 0.0
		HUD.show_feedback(nothing_line(current_apartment_id, current_anchor_name))
		_close(false)
		return
	if item_data.is_empty():
		icon.texture = null
		name_label.text = "Nothing found."
		hint_label.text = ""
		has_item = false
		nothing_timer = NOTHING_CLOSE_TIME
		_notify_anchor_closed(false)
		return
	has_item = true
	icon.texture = ItemData.get_texture(current_item_id)
	WorldState.note_item_seen(current_item_id)   # seeing it in the panel counts as found (codex)
	if current_key_target != "":
		name_label.text = WorldState.key_display(current_key_target)
	elif _is_cabinet_weapon():
		var inst = WorldState.gun_cabinet_weapon(current_apartment_id)
		name_label.text = inst.get_display_name() + "  ·  " + inst.tier_label()
	else:
		name_label.text = item_data["name"]
	hint_label.text = "Double-click, or drag onto your pack · walk away to leave"
	_show_compare(item_data)
	if _is_rounds() and not WorldState.guns_with_room().is_empty():
		hint_label.text = SettingsManager.localize("Drag onto your gun, or press [{item_use}], to load it · [{interact}] takes it")


## A weapon in the panel shows its numbers beside the one in hand, so the choice never needs the bag opened to compare (owner round 48i).
func _show_compare(item_data: Dictionary) -> void:
	compare_label.visible = false
	compare_label.text = ""
	if _is_cabinet_weapon() or current_key_target != "" or not item_data.get("is_weapon", false):
		return
	var inst := ItemInstance.new()
	inst.setup(current_item_id)
	var c: Dictionary = ItemCompare.card(inst, ItemCompare.held_weapon())
	if c.is_empty():
		return
	compare_label.text = ItemCompare.bbcode(c)
	compare_label.visible = true


## Where the pack ring's centre sits while it shares the screen with this panel: the pair (panel + a gap + ring) is centred on the
## screen, so neither is pushed out to an edge (owner round 36g: "the wheel is too far to the right… keep both relatively centre").
static func ring_centre_x(ring_half: float) -> float:
	var panel_right: float = SCREEN_W * 0.5 - PACK_SHIFT * 0.5 + PANEL_W * 0.5
	return panel_right + RING_GAP + ring_half


## A found item is waiting (nothing mid-search): the pack ring may open beside it to make room (owner round 36f).
func can_share_screen() -> bool:
	return visible and has_item and not is_revealing


func over_panel(pos: Vector2) -> bool:
	return visible and panel != null and panel.get_global_rect().has_point(pos)


## Is the pack ring up beside this panel?
func _pack_open() -> bool:
	return HUD.pack_wheel != null and is_instance_valid(HUD.pack_wheel) and HUD.pack_wheel.is_open


func _process(delta: float) -> void:
	if not visible:
		_shift = 0.0
		return
	# the panel slides left while the pack ring is up on the right
	var want: float = PACK_SHIFT if _pack_open() else 0.0
	_shift = lerpf(_shift, want, clampf(delta * 14.0, 0.0, 1.0))
	if absf(_shift - want) < 0.5:
		_shift = want
	if _center != null:
		_center.offset_right = -_shift

	# Walk away = leave. (Skip while actively dragging the item to a slot.)
	if not drag_active and anchor_node != null and is_instance_valid(anchor_node):
		var player = get_tree().get_first_node_in_group("player")
		if player != null:
			var dist = anchor_node.global_position.distance_to(player.global_position)
			if dist > anchor_node.INTERACT_DISTANCE * 1.5:
				_close(false)
				return

	if is_revealing:
		# Searching demands both hands: leaving scavenge / acting cancels it.
		if not WorldState.is_scavenge_mode:
			_close(false)
			return
		var searcher = get_tree().get_first_node_in_group("player")
		if searcher != null and (searcher.is_switching_mode or searcher.is_pushing or searcher.is_attacking):
			_close(false)
			return
		reveal_timer += delta
		search_bar.set_progress(reveal_timer, reveal_time)
		name_label.text = "Searching" + ".".repeat(1 + int(reveal_timer * 2.5) % 3)
		if reveal_timer >= reveal_time:
			_reveal_item()
		return

	# "Nothing found" auto-dismisses shortly.
	if not has_item and nothing_timer > 0.0:
		nothing_timer -= delta
		if nothing_timer <= 0.0:
			_close(false)
		return

	_update_drag()


func _update_drag() -> void:
	if not drag_armed:
		return
	var mouse: Vector2 = _mouse_pos
	if not drag_active:
		if mouse.distance_to(drag_from) > DRAG_THRESHOLD:
			_start_drag()
	elif ghost != null:
		ghost.position = mouse - Vector2(28, 28)


func _start_drag() -> void:
	drag_active = true
	ghost = TextureRect.new()
	ghost.texture = icon.texture
	ghost.custom_minimum_size = Vector2(56, 56)
	ghost.size = Vector2(56, 56)
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.modulate = Color(1, 1, 1, 0.85)
	add_child(ghost)


func _end_drag(take: bool) -> void:
	drag_armed = false
	drag_active = false
	if ghost != null:
		ghost.queue_free()
		ghost = null
	if take:
		_take()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
		_mouse_pos = event.position
	# A click in the world, off the panel (and not on the hotbar, where you make room): leave,
	# and let the click go on through to click-to-move / click-to-scavenge. Any state — searching,
	# "nothing found", an item shown, "inventory full".
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and not drag_active and not HUD.pointer_over_widget(event.position) and not panel.get_global_rect().has_point(event.position):
		_close(false)
		return
	if is_revealing or not has_item:
		return
	# E / interact takes.
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_take()
		return
	# The use key loads a carried gun straight from found bullets (owner round 48h: "drag or press my buttons to autoload the gun").
	if event.is_action_pressed("item_use") and _is_rounds():
		var guns: Array = WorldState.guns_with_room()
		if not guns.is_empty():
			get_viewport().set_input_as_handled()
			load_gun(guns[0])
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var now = Time.get_ticks_msec() / 1000.0
			if now - last_press_time < DOUBLE_CLICK_TIME:
				get_viewport().set_input_as_handled()
				_take()
				return
			last_press_time = now
			# Arm a drag from anywhere on the panel.
			if panel.get_global_rect().has_point(event.position):
				drag_armed = true
				drag_from = event.position
				get_viewport().set_input_as_handled()
		else:
			# Release: a drag that ended over the pack takes it.
			if drag_active:
				var ring = HUD.pack_wheel
				var on_ring: bool = ring != null and is_instance_valid(ring) and ring.is_open and ring.on_ring(event.position)
				if on_ring:
					# dropped on the pack ring: into the bag — onto an item with the bag full, that item is put down to make room
					var k: int = RingGeo.index_for(event.position - ring.centre, ring.slots.size(), ring.DEAD_ZONE)
					_end_drag(false)
					swap_in(ring, k, true)
				else:
					_end_drag(HUD.inventory_drop_rect().has_point(event.position))
				get_viewport().set_input_as_handled()
			else:
				drag_armed = false


## Take the found item, first putting wedge `k` of the ring down if the bag is full (and `k` holds something). Used both ways:
## the item dragged onto the ring (`from_panel`, k = the wedge it landed on) and a ring item dragged onto the panel.
func swap_in(ring, k: int, from_panel: bool = false) -> void:
	if not has_item or is_revealing:
		return
	# Found bullets dropped on a GUN load it - and never put the gun down to make room for bullets that are for it.
	if _is_rounds() and k >= 0 and ring != null and WorldState.is_gun_instance(ring._slot_inst(k)):
		var g = ring._slot_inst(k)
		if g.get_mag_cap() - g.mag_count > 0 and not g.is_depleted:
			load_gun(g)
		else:
			HUD.show_feedback("Magazine full." if not g.is_depleted else "That gun is broken.")
		return
	if _take():
		return
	if k >= 0 and ring != null and ring._slot_inst(k) != null:
		ring.drop_at(k)        # the bag was full: put that one down at the feet…
		_take()                # …and the found item goes in


func _take() -> bool:
	WorldState.interaction_handled = true
	if current_item_id == "":
		_close(true)
		return true
	var added: bool
	var cabinet := _is_cabinet_weapon()
	if current_key_target != "":
		added = WorldState.add_key_to_inventory(current_key_target)
	elif cabinet:
		# The gun cabinet's Lv3 gun: the built instance, not a plain new one.
		added = WorldState.add_instance_to_inventory(WorldState.gun_cabinet_weapon(current_apartment_id))
	elif _is_rounds():
		return _take_rounds()
	else:
		var amount = WorldState.get_anchor_amount(current_apartment_id, current_anchor_name)
		added = WorldState.add_to_inventory(current_item_id, amount)
	if added:
		_finish_taken(cabinet)
		return true
	else:
		name_label.text = "Inventory full"
		hint_label.text = "Drag something off the ring (or onto this) to make room." if _pack_open() else "Open your pack and make room."
		return false


## The found thing is in the pack now: the node is spent, the journal counts it, the panel closes.
func _finish_taken(cabinet: bool) -> void:
	if cabinet:
		WorldState.note_gun_cabinet_taken(current_apartment_id)
		get_tree().call_group("gun_cabinet_art", "refresh")
	WorldState.clear_anchor_item(current_apartment_id, current_anchor_name)
	WorldState.note_scavenge(current_apartment_id)   # journal stats: items + apartments looted
	get_tree().call_group("resident_npc", "on_scavenge", "take", current_apartment_id)
	HUD.refresh_inventory()
	_close(true)


## The node holds bullets (not a key, not the cabinet's gun).
func _is_rounds() -> bool:
	return has_item and current_key_target == "" and current_item_id != "" and ItemData.get_item(current_item_id).get("is_ammo", false)


## How many bullets this node holds: the amount the room recorded, else the bundle its seed rolls.
func _rounds_here() -> int:
	var amount: int = WorldState.get_anchor_amount(current_apartment_id, current_anchor_name)
	return amount if amount > 0 else _roll_ammo_bundle()


## Found bullets: into the pockets if they all fit, else into the magazine of a gun carried (owner round 48h); what fits nowhere stays on the node.
func _take_rounds() -> bool:
	var res: Dictionary = WorldState.take_found_ammo(current_item_id, _rounds_here())
	if int(res["left"]) <= 0:
		if str(res["msg"]) != "":
			HUD.show_feedback(str(res["msg"]))
		_finish_taken(false)
		return true
	if int(res["to_gun"]) + int(res["to_pack"]) > 0:
		_rounds_left(int(res["left"]), str(res["msg"]))
	else:
		name_label.text = "Inventory full"
		hint_label.text = "Drag something off the ring (or onto this) to make room." if _pack_open() else "Open your pack and make room."
	return false


## Load `gun` straight from the found bullets, no pocket needed. The rest stays on the node.
func load_gun(gun) -> bool:
	var here: int = _rounds_here()
	var res: Dictionary = WorldState.load_found_rounds(here, gun)
	var put: int = int(res["n"])
	if put <= 0:
		HUD.show_feedback("Magazine full.")
		return false
	var msg := "Loaded %d — mag %d/%d." % [put, gun.mag_count, gun.get_mag_cap()]
	if here - put <= 0:
		HUD.show_feedback(msg)
		_finish_taken(false)
	else:
		_rounds_left(here - put, msg)
	return true


## Part of the bundle went into a gun / the pack: say so, and what remains on the node.
func _rounds_left(left: int, msg: String) -> void:
	WorldState.set_anchor_amount(current_apartment_id, current_anchor_name, left)
	HUD.show_feedback(msg)
	HUD.refresh_inventory()
	name_label.text = "%s x%d" % [ItemData.get_item(current_item_id).get("name", "Bullets"), left]
	hint_label.text = "The pack is full — drag something off the ring to make room for the rest." if _pack_open() else "The pack is full — make room for the rest."


# The anchor is an opened gun cabinet still holding its weapon.
func _is_cabinet_weapon() -> bool:
	return current_anchor_name == WorldState.GUN_CABINET_ANCHOR \
		and current_item_id == WorldState.CABINET_WEAPON \
		and WorldState.gun_cabinet_state(current_apartment_id) in ["open", "smashed"]


func _roll_ammo_bundle() -> int:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "ammobundle" + current_apartment_id + current_anchor_name)
	var weights = [30, 22, 16, 12, 9, 7, 4]  # sizes 2..8
	var roll = rng.randi() % 100
	var acc = 0
	for i in range(weights.size()):
		acc += weights[i]
		if roll < acc:
			return i + 2
	return 2


func _close(item_taken: bool) -> void:
	_end_drag(false)
	is_revealing = false
	has_item = false
	visible = false
	WorldState.loot_open = false
	_notify_anchor_closed(item_taken)
	anchor_node = null
	current_key_target = ""
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("restore_stance"):
		player.restore_stance()


func _notify_anchor_closed(item_taken: bool) -> void:
	if anchor_node != null and is_instance_valid(anchor_node) and anchor_node.has_method("on_loot_closed"):
		anchor_node.on_loot_closed(item_taken)


## The search bar (owner round 45: "add an opaque bar to fill the box horizontally, just like similar bars for force door effects"): the
## same warm look as the barricade's board bar — a dark opaque track in a bronze frame, an amber fill that grows left to right with a
## brighter, pulsing leading edge, a highlight that sweeps along the fill, and a tick every tenth so the pace of the search reads.
class SearchBar extends Control:
	const BAR_H := 14.0
	var elapsed := 0.0
	var total := 1.0
	var _t := 0.0

	func set_progress(done: float, of: float) -> void:
		elapsed = clampf(done, 0.0, maxf(of, 0.001))
		total = maxf(of, 0.001)
		queue_redraw()

	func fraction() -> float:
		return clampf(elapsed / total, 0.0, 1.0)

	func _process(delta: float) -> void:
		if visible:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.04, 0.035, 1.0))                        # opaque track
		var inner := Rect2(2, 2, w - 4, h - 4)
		draw_rect(inner, Color(0.16, 0.13, 0.10, 1.0))
		var fill := inner.size.x * fraction()
		if fill >= 1.0:
			draw_rect(Rect2(inner.position, Vector2(fill, inner.size.y)), Color(0.95, 0.66, 0.28, 1.0))
			var pulse := 0.65 + 0.35 * sin(_t * 12.0)                                      # the leading edge breathes
			draw_rect(Rect2(inner.position.x + fill - 3.0, inner.position.y, 3.0, inner.size.y), Color(1.0, 0.86, 0.5, pulse))
			var sweep := fmod(_t * 60.0, maxf(fill, 1.0) + 12.0) - 12.0                    # a highlight running along the fill
			var sx := clampf(sweep, 0.0, fill)
			var ex := clampf(sweep + 12.0, 0.0, fill)
			if ex > sx:
				draw_rect(Rect2(inner.position.x + sx, inner.position.y, ex - sx, 2.0), Color(1.0, 0.92, 0.66, 0.55))
		for i in range(1, 10):                                                              # tenths
			var tx := inner.position.x + inner.size.x * float(i) / 10.0
			draw_rect(Rect2(tx, inner.position.y, 1.0, inner.size.y), Color(0.05, 0.04, 0.035, 0.55))
		draw_rect(Rect2(0, 0, w, h), Color(0.62, 0.46, 0.30, 1.0), false, 1.0)               # bronze frame
