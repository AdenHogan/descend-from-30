extends Control

# The BACKPACK RING (owner round 26 — "click the pack, the player bends down and opens their backpack,
# then a wheel for inventory opens with live gameplay underneath so you can still be attacked";
# docs/BACKPACK.md). The whole bag on a ring (geometry: ring_geo.gd), in REAL TIME:
#   • the player kneels first (player.begin_pack: kneel → open → stand); the ring only exists while the
#     player is in the "open" phase, so it is purely a VIEW of that state and can never desync from it;
#   • every slot is on the ring (empty ones faint) so its shape is stable;
#   • click = equip / put away; RIGHT-CLICK = a small menu of what you can do with it (equip / use / drop —
#     owner round 33); DRAG it OFF the ring and let go = drop it at your feet (also Delete);
#     Esc / the pack key / the centre / a click anywhere off the ring = close and stand;
#   • DRAG one item onto another to CRAFT / MERGE them (owner round 30 — Crafting.RECIPES: a bottle + torn clothes = a Molotov,
#     three clothes = rope): while you drag, every item it can combine with glows green (one that's only part of a recipe glows
#     red and the middle says what's missing); drop it on one to do it. A press that never moves is still a plain click;
#   • the world is NOT slowed, and a hit slams it shut (player.receive_hit → end_pack).
# Robustness: nothing here owns state that could strand the game — no time scale, no pause. If the
# player leaves the "open" phase for ANY reason (a hit, a cutscene, death, a scene change) the ring is
# simply gone next frame.

const RingGeo := preload("res://scripts/ring_geo.gd")

const OPEN_TIME := 0.16
const RING_R := 100.0
const DISC := 66.0
const DISC_SEL := 80.0
const DEAD_ZONE := 36.0
const DRAG_START_PX := 8.0              # a press that moves this far becomes a drag (below it, a click)
const GOOD := Color(0.45, 0.9, 0.4, 1.0)
const BAD := Color(0.9, 0.32, 0.28, 1.0)
const HEADROOM_PX := 60.0               # screen px between the kneeling player's origin and the ring's bottom edge
const SCREEN_LIMIT := 640.0             # rings are kept on screen (there is no bottom strip to stay clear of)
const AMBER := Color(0.89, 0.647, 0.247, 1.0)
const ROOT_TEXT := Color(0.93, 0.89, 0.82, 1.0)
const DIM_TEXT := Color(0.64, 0.61, 0.53)

var is_open: bool = false               # the ring is showing (player in the "open" phase)
var slots: Array = []                   # inventory slot indexes on the ring, in ring order (empties too)
var hover: int = -1                     # index INTO slots, or -1 for the middle / nothing
var centre: Vector2 = Vector2.ZERO
var mouse_override = null               # tests only: a Vector2 stands in for the pointer
var _opened_ms: int = 0
var _press_k: int = -1                  # wedge (index into slots) the left button went down on, or -1
var _press_pos: Vector2 = Vector2.ZERO
var drag_k: int = -1                    # wedge being dragged (a press that moved), or -1
var _mouse: Vector2 = Vector2.ZERO      # the pointer as of the last frame (the drag ghost follows it)
var menu_k: int = -1                    # right-click menu: the wedge it's for, or -1 when closed
var menu_pos: Vector2 = Vector2.ZERO    # its top-left (screen px)
var menu_rows: Array = []               # [label, action] — action one of "equip" / "use" / "drop"
const MENU_W := 118.0
const MENU_ROW_H := 22.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	set_process(true)


# ---------------------------------------------------------------- opening / closing

## Why the pack can't be opened right now, or "" when it can.
func blocked_reason() -> String:
	var r: String = RingGeo.ui_block_reason(get_tree())
	if r != "":
		return r
	var p = get_tree().get_first_node_in_group("player")
	return String(p.pack_blocked_reason()) if p.has_method("pack_blocked_reason") else "no pack"


## The pack button / key: kneel to it, or — already at it — get up.
func toggle() -> bool:
	var p = get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p) or not p.has_method("begin_pack"):
		return false
	var phase: String = String(p.pack_phase)
	if phase == "kneel" or phase == "open":
		p.end_pack(false)
		return true
	if phase != "":
		return false                    # already standing up
	if not WorldState.has_backpack:
		HUD.show_feedback("You don't have a pack.")
		return false
	if blocked_reason() != "":
		return false
	return bool(p.begin_pack())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_pack") and not event.is_echo():
		if toggle():
			get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	var p = get_tree().get_first_node_in_group("player")
	if menu_k >= 0 and _menu_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		p.end_pack(false)                   # Esc closes the pack, not the game
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_DELETE or event.physical_keycode == KEY_DELETE:
			if hover >= 0:
				drop_hovered()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		if _press_k >= 0 and drag_k < 0 and (event.position - _press_pos).length() >= DRAG_START_PX:
			drag_k = _press_k
		if drag_k >= 0:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _press_k >= 0:
			_finish_press(event.position)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		var pos: Vector2 = event.position
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if not on_ring(pos):
				if not HUD.pointer_over_widget(pos):   # a click out in the world: put the pack away
					p.end_pack(false)
					get_viewport().set_input_as_handled()
				return                            # a HUD widget keeps its own clicks
			var i: int = RingGeo.index_for(pos - centre, slots.size(), DEAD_ZONE)
			if i < 0:
				p.end_pack(false)                 # the middle = done
			elif event.button_index == MOUSE_BUTTON_LEFT:
				if _slot_inst(i) != null:
					_press_k = i                  # equip on release — unless it turns into a drag
					_press_pos = pos
					drag_k = -1
			else:
				open_menu(i)
			get_viewport().set_input_as_handled()


## The left button came up: a drag drops onto the wedge under it (craft) — or, let go OFF the ring, drops the
## item at your feet; a press that never moved is the plain click (equip).
func _finish_press(pos: Vector2) -> void:
	var from: int = _press_k
	var dragging: bool = drag_k >= 0
	_press_k = -1
	drag_k = -1
	var to: int = RingGeo.index_for(pos - centre, slots.size(), DEAD_ZONE) if on_ring(pos) else -1
	if not dragging:
		if to == from:
			equip_at(from)
		return
	if dropping_out(pos):
		drop_at(from)
		return
	if to >= 0 and to != from:
		craft_onto(from, to)


## A drag let go here throws the item out of the pack: anywhere off the ring that isn't on a HUD widget.
func dropping_out(pos: Vector2) -> bool:
	return not on_ring(pos) and not HUD.pointer_over_widget(pos)


# ---------------------------------------------------------------- the right-click menu

## Right-click on an item: what you can do with it, beside its slot.
func open_menu(k: int) -> void:
	var inst = _slot_inst(k)
	if inst == null:
		close_menu()
		return
	var d: Dictionary = inst.get_data()
	menu_rows = []
	var held: bool = int(slots[k]) == HUD.selected_slot
	menu_rows.append(["Put away" if held else "Equip", "equip"])
	if _usable(d):
		menu_rows.append(["Use", "use"])
	menu_rows.append(["Drop", "drop"])
	menu_k = k
	var at: Vector2 = RingGeo.slot_position(centre, k, slots.size(), RING_R)
	var right: bool = at.x >= centre.x
	var h: float = MENU_ROW_H * menu_rows.size() + 8.0
	var x: float = at.x + DISC * 0.5 + 6.0 if right else at.x - DISC * 0.5 - 6.0 - MENU_W
	menu_pos = Vector2(clampf(x, 4.0, HUD.SCREEN_W - MENU_W - 4.0), clampf(at.y - h * 0.5, 4.0, SCREEN_LIMIT - h))


func close_menu() -> void:
	menu_k = -1
	menu_rows = []


## Things you'd USE from the bag (bandages, painkillers, loading rounds, a cold pack…) — not a weapon, key or junk.
func _usable(d: Dictionary) -> bool:
	for f in ["is_weapon", "is_key", "is_junk", "is_money", "is_scrap"]:
		if d.get(f, false) and not d.get("is_throwable", false):
			return false
	return true


func menu_row_at(pos: Vector2) -> int:
	if menu_k < 0:
		return -1
	var r := Rect2(menu_pos + Vector2(0, 4), Vector2(MENU_W, MENU_ROW_H * menu_rows.size()))
	if not r.has_point(pos):
		return -1
	return int((pos.y - r.position.y) / MENU_ROW_H)


## Run a menu row (tests call this too).
func choose(row: int) -> void:
	if row < 0 or row >= menu_rows.size() or menu_k < 0:
		return
	var k: int = menu_k
	var what: String = String(menu_rows[row][1])
	close_menu()
	match what:
		"equip": equip_at(k)
		"use": use_at(k)
		"drop": drop_at(k)


## While the menu is up it owns the mouse: a row runs, anything else just closes it (the click isn't passed on).
func _menu_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		close_menu()
		return true
	if event is InputEventMouseButton and event.pressed:
		var row: int = menu_row_at(event.position)
		if row >= 0 and event.button_index == MOUSE_BUTTON_LEFT:
			choose(row)
			return true
		close_menu()
		# a right-click on another item re-opens the menu for that one
		if event.button_index == MOUSE_BUTTON_RIGHT and on_ring(event.position):
			var i: int = RingGeo.index_for(event.position - centre, slots.size(), DEAD_ZONE)
			if i >= 0:
				open_menu(i)
		return true
	return false


## Drop wedge `from` onto wedge `to`: merge them if a recipe says so, else say why not. Returns Crafting's result.
func craft_onto(from: int, to: int) -> Dictionary:
	if _slot_inst(from) == null or _slot_inst(to) == null:
		return {"ok": false, "name": "", "why": ""}
	var r: Dictionary = Crafting.craft(int(slots[from]), int(slots[to]))
	if bool(r.get("ok", false)):
		HUD.show_feedback("Crafted: %s." % String(r["name"]))
	elif String(r.get("why", "")) != "":
		HUD.show_feedback(String(r["why"]))
	return r


## Is a screen point on the ring (the band + the middle) — a click there is the ring's, not the world's.
func on_ring(pos: Vector2) -> bool:
	return (pos - centre).length() <= RING_R + DISC_SEL * 0.5 + 6.0


func _slot_inst(k: int):
	if k < 0 or k >= slots.size():
		return null
	var slot: int = int(slots[k])
	return WorldState.get_instance_at(slot) if slot >= 0 and slot < WorldState.inventory.size() else null


const LOCKED_SLOT := -1                 # the ring's marker for the slot a pack upgrade opens
const MAX_RING_SLOTS := 6               # the most a pack holds (WorldState.get_inventory_slots caps at 6)


func is_locked(k: int) -> bool:
	return k >= 0 and k < slots.size() and int(slots[k]) == LOCKED_SLOT


## Left-click: equip it, or put it away when it's already in hand (the hotbar's own toggle).
func equip_at(k: int) -> void:
	if _slot_inst(k) == null:
		return
	HUD.select_slot(int(slots[k]))


## Right-click: use it — from the bag, on your knees. Throwing and the extinguisher need you on your feet.
func use_at(k: int) -> void:
	var inst = _slot_inst(k)
	if inst == null:
		return
	var d: Dictionary = inst.get_data()
	if d.get("is_throwable", false) or d.get("is_extinguisher", false):
		HUD.show_feedback("Stand up first.")
		return
	var p = get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("use_item"):
		p.use_item(int(slots[k]))


func drop_hovered() -> void:
	drop_at(hover)


## Delete: drop it at your feet (it goes to the world, never lost — the hotbar's own discard).
func drop_at(k: int) -> void:
	if _slot_inst(k) == null:
		return
	HUD.discard_slot(int(slots[k]))


# ---------------------------------------------------------------- per-frame

func _process(_delta: float) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		if is_open:
			_hide()
		return
	# Anything that takes the player out of play stands them up (the wheel is only a view of the
	# player's pack phase, so it must also hand them back to the world).
	var phase: String = str(p.get("pack_phase")) if p.get("pack_phase") != null else ""
	if phase != "" and (bool(p.get("is_dead")) or bool(p.get("is_dying")) or bool(p.get("is_cutscene")) or bool(p.get("escaping"))):
		p.end_pack(true)
		phase = ""
	var want: bool = phase == "open" and not get_tree().paused and HUD.visible
	if want and not is_open:
		_show(p)
	elif not want and is_open:
		_hide()
	if not is_open:
		return
	slots = build_slots()
	var mouse: Vector2 = mouse_override if mouse_override is Vector2 else get_viewport().get_mouse_position()
	_mouse = mouse
	hover = RingGeo.index_for(mouse - centre, slots.size(), DEAD_ZONE)
	# the item under a drag is gone (used up, dropped…): the drag is over
	if (drag_k >= 0 or _press_k >= 0) and _slot_inst(maxi(drag_k, _press_k)) == null:
		_press_k = -1
		drag_k = -1
	if menu_k >= 0 and _slot_inst(menu_k) == null:
		close_menu()
	queue_redraw()


## EVERY slot the pack has — filled or empty — plus the LOCKED one (LOCKED_SLOT) until the upgrade opens it (owner round 33:
## "when you don't have any items in your bag, opening the bag doesn't show a wheel. We still need a wheel even if empty. When
## you drop items, the wheel should not lessen in number of slots… so players can identify that there is always a locked slot
## unless the upgrade is collected"). Items fill from slot 0, so slot i is empty when i >= inventory.size().
func build_slots() -> Array:
	var out: Array = []
	var cap: int = WorldState.get_inventory_slots()
	for i in range(cap):
		out.append(i)
	if cap < MAX_RING_SLOTS:
		out.append(LOCKED_SLOT)
	return out


func _show(p: Node) -> void:
	slots = build_slots()
	# FLOATING ABOVE the kneeling player (so the bend-down and the open pack stay visible below it),
	# clamped to the screen and clear of the hotbar strip.
	var half: float = RING_R + DISC_SEL * 0.5 + 10.0
	# (the offset is in SCREEN px — the camera zooms the world, so a world-unit offset would be miles off)
	var s: Vector2 = get_viewport().get_canvas_transform() * p.global_position + Vector2(0, -(HEADROOM_PX + half))
	centre = Vector2(clampf(s.x, half, HUD.SCREEN_W - half), clampf(s.y, half, maxf(half, SCREEN_LIMIT - half)))
	hover = -1
	_opened_ms = Time.get_ticks_msec()
	is_open = true
	visible = true
	queue_redraw()


func _hide() -> void:
	is_open = false
	visible = false
	hover = -1
	slots = []
	_press_k = -1
	drag_k = -1
	close_menu()


# ---------------------------------------------------------------- drawing

func _open_t() -> float:
	var t: float = clampf(float(Time.get_ticks_msec() - _opened_ms) / 1000.0 / OPEN_TIME, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _text(font: Font, pos: Vector2, s: String, size: int, col: Color, width: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string_outline(font, pos, s, align, width, size, 4, Color(0, 0, 0, 0.9))
	draw_string(font, pos, s, align, width, size, col)


func _draw() -> void:
	if not is_open or slots.is_empty():
		return
	var t: float = _open_t()
	var n: int = slots.size()
	var font: Font = get_theme_default_font()
	# The world stays lit and moving: only a thin shade behind the ring so it reads.
	draw_circle(centre, (RING_R + DISC) * 1.05 * (0.6 + 0.4 * t), Color(0.02, 0.02, 0.03, 0.34 * t))
	var r: float = RING_R * (0.55 + 0.45 * t)
	var band: float = DISC + 20.0
	draw_arc(centre, r, 0.0, TAU, 128, Color(0.075, 0.07, 0.085, 0.72 * t), band, true)
	draw_arc(centre, r + band * 0.5, 0.0, TAU, 128, Color(0.89, 0.647, 0.247, 0.3 * t), 2.0, true)
	draw_arc(centre, r - band * 0.5, 0.0, TAU, 128, Color(0.29, 0.275, 0.32, t), 2.0, true)
	var wedge: float = TAU / float(n)
	if hover >= 0:
		var a: float = -PI * 0.5 + float(hover) * wedge
		draw_arc(centre, r, a - wedge * 0.5 + 0.03, a + wedge * 0.5 - 0.03, 32, Color(0.89, 0.647, 0.247, 0.2 * t), band, true)
	var plans := {}                     # while dragging: wedge -> Crafting.plan with the dragged item
	if drag_k >= 0:
		for k2 in range(n):
			if k2 != drag_k and _slot_inst(k2) != null:
				var pl: Dictionary = Crafting.plan(int(slots[drag_k]), int(slots[k2]))
				if not pl.is_empty():
					plans[k2] = pl
	for k in range(n):
		var slot: int = int(slots[k])
		var inst = WorldState.get_instance_at(slot) if slot >= 0 and slot < WorldState.inventory.size() else null
		var pos: Vector2 = RingGeo.slot_position(centre, k, n, r)
		var on: bool = k == hover
		if slot == LOCKED_SLOT:
			_draw_locked(pos, DISC * 0.5 * (0.7 + 0.3 * t), t, font)
			continue
		if plans.has(k):
			var good: bool = bool(plans[k]["ok"])
			var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 1000.0 * 7.0)
			draw_circle(pos, DISC * 0.5 + 9.0, Color(GOOD if good else BAD, 0.16 + 0.12 * pulse))
			draw_arc(pos, DISC * 0.5 + 7.0, 0.0, TAU, 40, Color(GOOD if good else BAD, 0.85), 3.0, true)
		if k == drag_k:
			draw_arc(pos, DISC * 0.5, 0.0, TAU, 40, Color(0.89, 0.647, 0.247, 0.45), 2.0, true)
			continue                    # lifted: only its outline stays where it was
		var held: bool = slot == HUD.selected_slot and inst != null
		var rad: float = (DISC_SEL if on and inst != null else DISC) * 0.5 * (0.7 + 0.3 * t)
		if inst == null:
			draw_arc(pos, rad * 0.8, 0.0, TAU, 32, Color(0.29, 0.275, 0.32, 0.55 * t), 2.0, true)
			_text(font, pos + Vector2(-rad, 4.0), str(slot + 1), 12, Color(0.4, 0.38, 0.34, t), rad * 2.0, HORIZONTAL_ALIGNMENT_CENTER)
			continue
		draw_circle(pos, rad, Color(0.2, 0.16, 0.1, 0.96) if on or held else Color(0.13, 0.125, 0.145, 0.96))
		draw_arc(pos, rad, 0.0, TAU, 40, AMBER if on else (Color(0.89, 0.647, 0.247, 0.55) if held else Color(0.29, 0.275, 0.32, 1.0)), 4.0 if on else 2.0, true)
		var tex: Texture2D = ItemData.get_texture(inst.item_id)
		if tex != null:
			var broken: bool = inst.is_depleted and inst.get_max_durability() > 0
			draw_texture_rect(tex, Rect2(pos - Vector2(28, 28), Vector2(56, 56)), false, Color(0.5, 0.4, 0.4, 1.0) if broken else Color(1, 1, 1, 1))
		_text(font, pos + Vector2(-rad + 4.0, -rad + 16.0), str(slot + 1), 12, AMBER if on else DIM_TEXT)
		if held:
			_text(font, pos + Vector2(-rad, rad + 12.0), "IN HAND", 10, AMBER, rad * 2.0, HORIZONTAL_ALIGNMENT_CENTER)
		var max_d: int = inst.get_max_durability()
		if max_d > 1 and not inst.is_depleted:
			var ratio: float = clampf(float(inst.current_durability) / float(max_d), 0.0, 1.0)
			var bw: float = rad * 1.1
			var by: float = pos.y + rad * 0.72
			draw_rect(Rect2(pos.x - bw * 0.5, by, bw, 3.0), Color(0, 0, 0, 1))
			draw_rect(Rect2(pos.x - bw * 0.5, by, bw * ratio, 3.0), Color(0.3, 0.8, 0.3) if ratio > 0.3 else Color(0.9, 0.25, 0.22))
		if inst.count > 1:
			_text(font, pos + Vector2(rad * 0.15, rad * 0.62), "x%d" % inst.count, 12, ROOT_TEXT, rad * 0.8, HORIZONTAL_ALIGNMENT_RIGHT)
	# The middle: what the pointer is on, or the pack's own header.
	var inst_h = _slot_inst(hover)
	var cw: float = 176.0
	if drag_k >= 0:
		var inst_d = _slot_inst(drag_k)
		var dn: String = String(inst_d.get_data().get("name", "")).to_upper() if inst_d != null else ""
		if plans.has(hover):
			var hp: Dictionary = plans[hover]
			if bool(hp["ok"]):
				_text(font, centre + Vector2(-cw * 0.5, -22), "DROP TO CRAFT", 12, GOOD, cw, HORIZONTAL_ALIGNMENT_CENTER)
				_text(font, centre + Vector2(-cw * 0.5, 0), String(hp["name"]).to_upper(), 16, ROOT_TEXT, cw, HORIZONTAL_ALIGNMENT_CENTER)
			else:
				_text(font, centre + Vector2(-cw * 0.5, -22), "NOT YET", 12, BAD, cw, HORIZONTAL_ALIGNMENT_CENTER)
				_text(font, centre + Vector2(-cw * 0.5, 0), String(hp["why"]), 13, ROOT_TEXT, cw, HORIZONTAL_ALIGNMENT_CENTER)
		elif dropping_out(_mouse):
			_text(font, centre + Vector2(-cw * 0.5, -22), "LET GO TO DROP", 12, BAD, cw, HORIZONTAL_ALIGNMENT_CENTER)
			_text(font, centre + Vector2(-cw * 0.5, 0), dn, 14, ROOT_TEXT, cw, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			_text(font, centre + Vector2(-cw * 0.5, -22), dn, 14, ROOT_TEXT, cw, HORIZONTAL_ALIGNMENT_CENTER)
			_text(font, centre + Vector2(-cw * 0.5, 0), "drop it on something to combine", 12, DIM_TEXT, cw, HORIZONTAL_ALIGNMENT_CENTER)
	elif is_locked(hover):
		_text(font, centre + Vector2(-cw * 0.5, -22), "LOCKED", 16, DIM_TEXT, cw, HORIZONTAL_ALIGNMENT_CENTER)
		_text(font, centre + Vector2(-cw * 0.5, 0), "a pack upgrade opens", 12, Color(0.75, 0.79, 0.84), cw, HORIZONTAL_ALIGNMENT_CENTER)
		_text(font, centre + Vector2(-cw * 0.5, 16), "this slot", 12, Color(0.75, 0.79, 0.84), cw, HORIZONTAL_ALIGNMENT_CENTER)
	elif hover >= 0 and inst_h == null:
		_text(font, centre + Vector2(-cw * 0.5, -6), "EMPTY", 15, DIM_TEXT, cw, HORIZONTAL_ALIGNMENT_CENTER)
	elif inst_h != null:
		var c: Dictionary = HUD.item_tip_content(inst_h)
		_text(font, centre + Vector2(-cw * 0.5, -22), String(c["title"]).to_upper(), 16, Color(1.0, 0.85, 0.4) if c.get("legendary", false) else ROOT_TEXT, cw, HORIZONTAL_ALIGNMENT_CENTER)
		var stats: Array = c["stats"]
		for i in range(mini(stats.size(), 2)):
			_text(font, centre + Vector2(-cw * 0.5, 0 + i * 16), String(stats[i]), 12, Color(0.75, 0.79, 0.84), cw, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_text(font, centre + Vector2(-cw * 0.5, -6), "YOUR PACK", 15, ROOT_TEXT, cw, HORIZONTAL_ALIGNMENT_CENTER)
		_text(font, centre + Vector2(-cw * 0.5, 14), "click here to close", 12, DIM_TEXT, cw, HORIZONTAL_ALIGNMENT_CENTER)
	if drag_k >= 0:
		var di = _slot_inst(drag_k)
		if di != null:
			var dtex: Texture2D = ItemData.get_texture(di.item_id)
			if dtex != null:
				var out: bool = dropping_out(_mouse)
				draw_texture_rect(dtex, Rect2(_mouse - Vector2(28, 28), Vector2(56, 56)), false,
					Color(1.0, 0.6, 0.55, 0.75) if out else Color(1, 1, 1, 0.85))
	_draw_menu(font)
	# The help line LAST, on its own plate clear above the ring (owner round 33: it ran behind the top item).
	var hw: float = font.get_string_size(HINT, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 20.0
	var hy: float = hint_top()
	draw_rect(Rect2(centre.x - hw * 0.5, hy, hw, 20.0), Color(0.03, 0.03, 0.04, 0.82 * t))
	_text(font, Vector2(centre.x - hw * 0.5, hy + 14.0), HINT, 12, DIM_TEXT, hw, HORIZONTAL_ALIGNMENT_CENTER)


## The locked slot: a dark disc with a padlock — always there until the upgrade, so the pack's true size is never a secret.
func _draw_locked(pos: Vector2, rad: float, t: float, font: Font) -> void:
	draw_circle(pos, rad * 0.86, Color(0.05, 0.05, 0.06, 0.85 * t))
	draw_arc(pos, rad * 0.86, 0.0, TAU, 32, Color(0.29, 0.275, 0.32, 0.8 * t), 2.0, true)
	var lc := Color(0.55, 0.52, 0.47, t)
	draw_arc(pos + Vector2(0, -3), 6.0, PI, TAU, 16, lc, 2.5, true)                 # the shackle
	draw_rect(Rect2(pos + Vector2(-8, -3), Vector2(16, 12)), lc)                     # the body
	draw_circle(pos + Vector2(0, 2), 1.8, Color(0.05, 0.05, 0.06, t))                 # the keyhole
	_text(font, pos + Vector2(-rad, rad * 0.86 + 12.0), "LOCKED", 10, Color(0.5, 0.48, 0.44, t), rad * 2.0, HORIZONTAL_ALIGNMENT_CENTER)


const HINT := "click equip  ·  right-click options  ·  drag onto an item to craft  ·  drag out to drop  ·  Esc close"

## The help line's top edge: above the ring's shade, or under it when the ring sits against the top of the screen.
func hint_top() -> float:
	var shade_top: float = centre.y - (RING_R + DISC) * 1.05
	if shade_top - 26.0 >= 4.0:
		return shade_top - 26.0
	return centre.y + (RING_R + DISC) * 1.05 + 6.0


func _draw_menu(font: Font) -> void:
	if menu_k < 0:
		return
	var h: float = MENU_ROW_H * menu_rows.size() + 8.0
	draw_rect(Rect2(menu_pos, Vector2(MENU_W, h)), Color(0.07, 0.065, 0.08, 0.96))
	draw_rect(Rect2(menu_pos, Vector2(MENU_W, h)), AMBER, false, 2.0)
	var hov: int = menu_row_at(_mouse)
	for i in range(menu_rows.size()):
		var y: float = menu_pos.y + 4.0 + MENU_ROW_H * i
		if i == hov:
			draw_rect(Rect2(menu_pos.x + 3.0, y, MENU_W - 6.0, MENU_ROW_H), Color(0.89, 0.647, 0.247, 0.25))
		var col: Color = BAD if String(menu_rows[i][1]) == "drop" else ROOT_TEXT
		_text(font, Vector2(menu_pos.x + 12.0, y + 16.0), String(menu_rows[i][0]), 13, col)
