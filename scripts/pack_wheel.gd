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
const HEADROOM_PX := 60.0               # screen px between the kneeling player's origin and the ring's bottom edge
const SCREEN_LIMIT := 640.0             # rings are kept on screen (there is no bottom strip to stay clear of)

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
var _last_hover: int = -2               # the wedge the pointer was on last frame (a tick when it moves onto an item)
var menu_k: int = -1                    # right-click menu: the wedge it's for, or -1 when closed
var menu_pos: Vector2 = Vector2.ZERO    # its top-left (screen px)
var menu_rows: Array = []               # [label, action] — action one of "equip" / "use" / "drop"
var pad_row: int = 0                    # gamepad: the highlighted row of the open menu
var _pad_k: int = -1                    # gamepad: the wedge the right stick last pointed at (it stays chosen)
var _pad_latch: bool = false            # the stick must return to the middle before it steps a menu row again
var pad_override = null                 # tests only: a Vector2 stands in for the right stick
const PAD_DEAD := 0.55
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
	# GAMEPAD: the right stick points at a wedge; A equips it (or runs the menu row), X opens its menu.
	if menu_k >= 0 and event.is_action_pressed("ui_accept") and SettingsManager.last_device == "pad":
		choose(pad_row)
		get_viewport().set_input_as_handled()
		return
	if _pad_k >= 0 and hover == _pad_k and SettingsManager.last_device == "pad" and menu_k < 0 and not event.is_echo():
		if event.is_action_pressed("ui_accept"):
			equip_at(_pad_k)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("attack") and _slot_inst(_pad_k) != null:
			open_menu(_pad_k)
			pad_row = 0
			get_viewport().set_input_as_handled()
			return
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
	var loot = loot_panel()
	if loot != null and loot.over_panel(pos):
		loot.swap_in(self, from)          # onto the found item: make room if it needs it, then take it
		return
	if HUD.body_ring != null and HUD.body_ring.is_open and HUD.body_ring.on_ring(pos):
		HUD.body_ring.put(int(slots[from]))     # onto the body's ring: lay it on them (owner round 48i)
		return
	if dropping_out(pos):
		drop_at(from, HUD.drop_dir_for(pos, centre.x))      # it falls out the way it was dragged (owner round 48h)
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
	Ledger.play("tick", -16.0, 0.1)
	var at: Vector2 = RingGeo.slot_position(centre, k, slots.size(), RING_R)
	var right: bool = at.x >= centre.x
	var h: float = MENU_ROW_H * menu_rows.size() + 8.0
	var y: float = clampf(at.y - h * 0.5, 4.0, SCREEN_LIMIT - h)
	var xr: float = at.x + DISC * 0.5 + 6.0
	var xl: float = at.x - DISC * 0.5 - 6.0 - MENU_W
	# The found-item panel sits ABOVE this ring (its own, higher layer): a menu opened under it was half hidden (owner round 48i: "menu and item overlap"). The menu
	# takes the side of the slot the panel is NOT on - and, if neither side is clear, goes above or below the slot.
	var avoid := Rect2()
	var lp = loot_panel()
	if lp != null and lp.visible and lp.panel != null:
		avoid = (lp.panel as Control).get_global_rect().grow(6.0)
	var order: Array = [xr, xl] if right else [xl, xr]
	for cx in order:
		var px: float = clampf(cx, 4.0, HUD.SCREEN_W - MENU_W - 4.0)
		if not avoid.intersects(Rect2(Vector2(px, y), Vector2(MENU_W, h))):
			menu_pos = Vector2(px, y)
			return
	var px2: float = clampf(at.x - MENU_W * 0.5, 4.0, HUD.SCREEN_W - MENU_W - 4.0)
	for cy in [at.y - DISC * 0.5 - 6.0 - h, at.y + DISC * 0.5 + 6.0]:
		var py: float = clampf(cy, 4.0, SCREEN_LIMIT - h)
		if not avoid.intersects(Rect2(Vector2(px2, py), Vector2(MENU_W, h))):
			menu_pos = Vector2(px2, py)
			return
	menu_pos = Vector2(clampf(order[0], 4.0, HUD.SCREEN_W - MENU_W - 4.0), y)


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
	# Bullets onto the gun (or the gun onto the bullets) LOAD it - the same rule as the hotbar drag (WorldState.ammo_gun_pair).
	var gun: ItemInstance = WorldState.ammo_gun_pair(_slot_inst(from), _slot_inst(to))
	if gun != null:
		var res: Dictionary = WorldState.load_gun_from_pack(gun)
		HUD.show_feedback(String(res["msg"]))
		return {"ok": int(res["loaded"]) > 0, "name": "", "why": String(res["msg"]), "loaded": int(res["loaded"])}
	# The same medical item onto itself: pour the units across (up to three a slot).
	var moved: int = WorldState.merge_medical_slots(int(slots[from]), int(slots[to]))
	if moved > 0:
		HUD.show_feedback("Stacked.")
		return {"ok": true, "name": "", "why": "", "merged": moved}
	var r: Dictionary = Crafting.craft(int(slots[from]), int(slots[to]))
	if bool(r.get("ok", false)):
		HUD.show_feedback("Crafted: %s." % String(r["name"]))
		Ledger.play("tape", -10.0)
	elif String(r.get("why", "")) != "":
		HUD.show_feedback(String(r["why"]))
		Ledger.play("deny", -13.0, 0.3)
	return r


## Is a screen point on the ring (the band + the middle) — a click there is the ring's, not the world's.
func on_ring(pos: Vector2) -> bool:
	return (pos - centre).length() <= RING_R + DISC_SEL * 0.5 + 6.0


## The ring, or its open right-click menu: everything a pointer here belongs to (HUD.pointer_over_widget reads it).
func owns_point(pos: Vector2) -> bool:
	if on_ring(pos):
		return true
	return menu_k >= 0 and Rect2(menu_pos, Vector2(MENU_W, MENU_ROW_H * menu_rows.size() + 8.0)).has_point(pos)


## The scavenge panel sharing the screen (an item found, waiting to be taken), or null. The pack opens BESIDE it: panel left, ring right.
func loot_panel():
	for m in get_tree().get_nodes_in_group("loot_ui"):
		if is_instance_valid(m) and m.visible and m.has_method("can_share_screen") and m.can_share_screen():
			return m
	return null


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
	Ledger.play("pen", -15.0, 0.1)                        # the circle round it, drawn with a pen
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
func drop_at(k: int, dir_x: float = 0.0) -> void:
	if _slot_inst(k) == null:
		return
	Ledger.play("page", -12.0, 0.1)
	HUD.discard_slot(int(slots[k]), dir_x)


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
	_pad_tick()
	if hover != _last_hover:
		if hover >= 0 and _slot_inst(hover) != null and drag_k < 0:
			Ledger.play("tick", -24.0, 0.05)
		_last_hover = hover
	# the item under a drag is gone (used up, dropped…): the drag is over
	if (drag_k >= 0 or _press_k >= 0) and _slot_inst(maxi(drag_k, _press_k)) == null:
		_press_k = -1
		drag_k = -1
	if menu_k >= 0 and _slot_inst(menu_k) == null:
		close_menu()
	queue_redraw()


## The right stick (or the test stand-in).
func pad_stick() -> Vector2:
	if pad_override is Vector2:
		return pad_override
	return Vector2(Input.get_joy_axis(SettingsManager.last_pad_id if SettingsManager.last_pad_id >= 0 else 0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(SettingsManager.last_pad_id if SettingsManager.last_pad_id >= 0 else 0, JOY_AXIS_RIGHT_Y))


## Gamepad selection: the right stick picks a wedge (it STAYS picked when the stick returns to the middle, so A can
## then equip it); with the menu open it steps the rows instead. Only while a pad is the device in use.
func _pad_tick() -> void:
	if SettingsManager.last_device != "pad":
		_pad_k = -1
		return
	var st: Vector2 = pad_stick()
	if menu_k >= 0:
		if absf(st.y) < PAD_DEAD:
			_pad_latch = false
		elif not _pad_latch and menu_rows.size() > 0:
			_pad_latch = true
			pad_row = clampi(pad_row + (1 if st.y > 0.0 else -1), 0, menu_rows.size() - 1)
		return
	if st.length() >= PAD_DEAD:
		var i: int = RingGeo.index_for(st.normalized() * (DEAD_ZONE + 40.0), slots.size(), DEAD_ZONE)
		if i >= 0:
			_pad_k = i
	if _pad_k >= slots.size():
		_pad_k = -1
	if _pad_k >= 0:
		hover = _pad_k


## True while a pad is choosing something on the ring — A then equips it rather than standing the player up.
func pad_selecting() -> bool:
	return is_open and SettingsManager.last_device == "pad" and (menu_k >= 0 or (_pad_k >= 0 and hover == _pad_k))


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
	if HUD.body_ring != null and HUD.body_ring.wants_pair():
		centre.x = float(HUD.body_ring.pair_x(s.x, half)[0])        # searching a body: this ring on the right, the body's on the left (body_ring.gd)
	if loot_panel() != null:
		# opened beside a found item (the inventory was full): the panel slides left and the ring sits just right of it — the pair centred on the screen
		centre = Vector2(loot_panel().ring_centre_x(half), clampf(HUD.SCREEN_H * 0.5, half, maxf(half, SCREEN_LIMIT - half)))
	hover = -1
	_last_hover = -2
	_pad_k = -1
	_opened_ms = Time.get_ticks_msec()
	is_open = true
	visible = true
	Ledger.play("sheet", -14.0, 0.2)                    # the pack's flap, the things inside shifting
	queue_redraw()


func _hide() -> void:
	_last_hover = -2
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


func _draw() -> void:
	if not is_open or slots.is_empty():
		return
	var t: float = _open_t()
	var n: int = slots.size()
	# The pack lies open on a dark shade (the world stays lit and moving beyond it) and every slot is a paper TAG on it — the look the loot panel and the merchant share (scripts/ledger_ring.gd).
	LedgerRing.shade(self, centre, (RING_R + DISC) * 1.05 * (0.6 + 0.4 * t), t)
	var r: float = RING_R * (0.55 + 0.45 * t)
	var pen: Color = Ledger.hand_ink()
	var plans := {}                     # while dragging: wedge -> Crafting.plan with the dragged item
	if drag_k >= 0:
		for k2 in range(n):
			if k2 != drag_k and _slot_inst(k2) != null:
				var pl: Dictionary = Crafting.plan(int(slots[drag_k]), int(slots[k2]))
				var ld: ItemInstance = WorldState.ammo_gun_pair(_slot_inst(drag_k), _slot_inst(k2))
				if ld != null:
					var full: bool = ld.mag_count >= ld.get_mag_cap()
					pl = {"ok": not full and WorldState.get_ammo_total() > 0, "name": "LOAD THE GUN", "why": "Magazine full." if full else "No bullets to load.", "load": true}
				if not pl.is_empty():
					plans[k2] = pl
	var in_hand: Array = []             # [centre, slot] — the "in hand" labels go on last, over the neighbouring tags
	for k in range(n):
		var slot: int = int(slots[k])
		var inst = WorldState.get_instance_at(slot) if slot >= 0 and slot < WorldState.inventory.size() else null
		var pos: Vector2 = RingGeo.slot_position(centre, k, n, r)
		var on: bool = k == hover
		if slot == LOCKED_SLOT:
			_draw_locked(pos, DISC * 0.5 * (0.7 + 0.3 * t), t)
			continue
		if k == drag_k:
			LedgerRing.dashed(self, pos, DISC * 0.5, Color(Ledger.PAPER.r, Ledger.PAPER.g, Ledger.PAPER.b, 0.5 * t))
			continue                    # lifted: only its pencilled outline stays where it was
		var held: bool = slot == HUD.selected_slot and inst != null
		var rad: float = (DISC_SEL if on and inst != null else DISC) * 0.5 * (0.7 + 0.3 * t)
		if inst == null:
			LedgerRing.dashed(self, pos, rad * 0.8, Color(Ledger.PAPER.r, Ledger.PAPER.g, Ledger.PAPER.b, 0.30 * t))
			LedgerRing.text(self, "typed", pos + Vector2(-rad, 4.0), str(slot + 1), 12, Color(Ledger.PAPER.r, Ledger.PAPER.g, Ledger.PAPER.b, 0.34 * t), rad * 2.0)
			continue
		LedgerRing.tag(self, pos, rad, 11 + slot, 1.0 if on else 0.0, t)
		var c: Vector2 = pos + Vector2(0, -4.0 if on else 0.0)
		var tex: Texture2D = ItemData.get_texture(inst.item_id)
		if tex != null:
			var broken: bool = inst.is_depleted and inst.get_max_durability() > 0
			draw_texture_rect(tex, Rect2(c - Vector2(25, 24), Vector2(56, 56)), false, Color(0.12, 0.07, 0.02, 0.26))           # the thing lies on the tag: its shadow
			draw_texture_rect(tex, Rect2(c - Vector2(28, 28), Vector2(56, 56)), false, Color(0.5, 0.4, 0.4, 1.0) if broken else Color(1, 1, 1, 1))
		LedgerRing.text(self, "typed", c + Vector2(-rad * 0.78, -rad * 0.42), str(slot + 1), 10, Ledger.INK_FAINT, 14.0, HORIZONTAL_ALIGNMENT_LEFT)
		if held:
			LedgerRing.pen_circle(self, c, rad - 4.0, Color(pen.r, pen.g, pen.b, 0.92 * t), 100 + slot)       # the one in hand is circled
			var out_dir: Vector2 = (pos - centre).normalized() if pos.distance_to(centre) > 1.0 else Vector2.DOWN
			in_hand.append(c + out_dir * (rad + 13.0) - Vector2(0, 8.0))        # the label sits on the OUTER side of its tag, clear of the slip in the middle
		if plans.has(k):
			var good: bool = bool(plans[k]["ok"])
			var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 1000.0 * 7.0)
			var ink: Color = Ledger.GREEN_INK if good else Ledger.RED_INK
			LedgerRing.pen_circle(self, c, rad - 2.0, Color(ink.r, ink.g, ink.b, 0.6 + 0.35 * pulse), 200 + slot, 2.6)
		var max_d: int = inst.get_max_durability()
		if max_d > 1 and not inst.is_depleted:
			var bw: float = rad * 1.1
			LedgerRing.gauge(self, Vector2(c.x - bw * 0.5, c.y + rad * 0.78), bw, clampf(float(inst.current_durability) / float(max_d), 0.0, 1.0), slot)
		if inst.count > 1:
			LedgerRing.text(self, "typed", c + Vector2(rad * 0.1, rad * 0.62), "x%d" % inst.count, 12, Ledger.INK, rad * 0.8, HORIZONTAL_ALIGNMENT_RIGHT)
	for hp2 in in_hand:
		LedgerRing.plate(self, "hand", hp2, "in hand", 12, Ledger.INK, 300, false, t)
	# The middle: a slip of paper — what the pointer is on, or the pack's own header.
	var inst_h = _slot_inst(hover)
	var lines: Array = []
	if drag_k >= 0:
		var inst_d = _slot_inst(drag_k)
		var dn: String = String(inst_d.get_data().get("name", "")).to_upper() if inst_d != null else ""
		if plans.has(hover):
			var hp: Dictionary = plans[hover]
			if bool(hp["ok"]):
				lines = [{"kind": "hand", "text": "drop to load" if bool(hp.get("load", false)) else "drop to craft", "px": 13, "col": Ledger.GREEN_INK},
					{"kind": "head", "text": String(hp["name"]).to_upper(), "px": 17, "col": Ledger.INK}]
			else:
				lines = [{"kind": "hand", "text": "not yet", "px": 13, "col": Ledger.RED_INK}, {"kind": "body", "text": String(hp["why"]), "px": 12, "col": Ledger.INK_SOFT}]
		elif dropping_out(_mouse):
			lines = [{"kind": "hand", "text": "let go to drop", "px": 13, "col": Ledger.RED_INK}, {"kind": "head", "text": dn, "px": 16, "col": Ledger.INK}]
		else:
			lines = [{"kind": "head", "text": dn, "px": 16, "col": Ledger.INK}, {"kind": "hand", "text": "drop it on something", "px": 12, "col": Ledger.INK_SOFT},
				{"kind": "hand", "text": "to combine them", "px": 12, "col": Ledger.INK_SOFT}]
	elif is_locked(hover):
		lines = [{"kind": "head", "text": "LOCKED", "px": 17, "col": Ledger.INK_SOFT}, {"kind": "body", "text": "a pack upgrade", "px": 12, "col": Ledger.INK_SOFT},
			{"kind": "body", "text": "opens this slot", "px": 12, "col": Ledger.INK_SOFT}]
	elif hover >= 0 and inst_h == null:
		lines = [{"kind": "head", "text": "EMPTY", "px": 16, "col": Ledger.INK_SOFT}]
	elif inst_h != null:
		var c2: Dictionary = HUD.item_tip_content(inst_h)
		var cmp: Dictionary = ItemCompare.card(inst_h, ItemCompare.held_weapon())        # a weapon that isn't the one in hand: its numbers against it
		lines = [{"kind": "head", "text": String(c2["title"]).to_upper(), "px": 17, "col": Ledger.GOLD_INK if c2.get("legendary", false) else Ledger.INK}]
		if cmp.is_empty() or String(cmp["vs"]) == "":
			var stats: Array = c2["stats"]
			for i in range(mini(stats.size(), 2)):
				lines.append({"kind": "body", "text": String(stats[i]), "px": 12, "col": Ledger.INK_SOFT})
		else:
			var rows: Array = cmp["rows"]
			for i in range(mini(rows.size(), 4)):
				var crow: Dictionary = rows[i]
				lines.append({"row": true, "label": crow["label"], "value": crow["text"], "delta": crow["delta"], "tone": crow["tone"]})
	else:
		lines = [{"kind": "head", "text": "YOUR PACK", "px": 17, "col": Ledger.INK}, {"kind": "hand", "text": "click here to close", "px": 12, "col": Ledger.INK_SOFT}]
	LedgerRing.card(self, centre, lines, 77, Ledger.PAPER_SLIP, 124.0, t)
	if drag_k >= 0:
		var di = _slot_inst(drag_k)
		if di != null:
			var dtex: Texture2D = ItemData.get_texture(di.item_id)
			if dtex != null:
				var out: bool = dropping_out(_mouse)
				draw_texture_rect(dtex, Rect2(_mouse - Vector2(22, 20), Vector2(56, 56)), false, Color(0.0, 0.0, 0.0, 0.30))               # held up off the table: a shadow under it
				draw_texture_rect(dtex, Rect2(_mouse - Vector2(28, 28), Vector2(56, 56)), false, Color(1.0, 0.7, 0.65, 0.85) if out else Color(1, 1, 1, 0.92))
	_draw_menu()
	# The help line LAST, on its own strip of paper clear above the ring (owner round 33: it ran behind the top item).
	LedgerRing.plate(self, "body", Vector2(centre.x, hint_top()), hint_text(), 12, Ledger.INK_SOFT, 21, false, t, 560.0, HUD.SCREEN_W)


## The locked slot: a darker, plainer tag with a padlock in ink — always there until the upgrade, so the pack's true size is never a secret.
func _draw_locked(pos: Vector2, rad: float, t: float) -> void:
	LedgerRing.tag(self, pos, rad * 0.9, 61, 0.0, t, Ledger.PAPER.darkened(0.42))
	LedgerRing.padlock(self, pos + Vector2(0, -2), Color(Ledger.INK.r, Ledger.INK.g, Ledger.INK.b, 0.85 * t))
	LedgerRing.text(self, "typed", pos + Vector2(-rad, rad * 0.5 + 6.0), "LOCKED", 9, Color(Ledger.INK.r, Ledger.INK.g, Ledger.INK.b, 0.7 * t), rad * 2.0)


const HINT_PAD := "{right stick} choose  ·  {interact} equip  ·  {attack} options  ·  {push} close"


## The help line for the device in use (the keyboard one is HINT; a pad gets its own buttons).
func hint_text() -> String:
	if SettingsManager.last_device == "pad":
		return HINT_PAD.replace("{right stick}", "R-stick").replace("{interact}", SettingsManager.action_text("interact")) \
			.replace("{attack}", SettingsManager.action_text("attack")).replace("{push}", SettingsManager.action_text("push"))
	return HINT


const HINT := "click equip  ·  right-click options  ·  drag onto an item to craft  ·  drag out to drop  ·  Esc close"

## The help line's top edge: above the ring's shade, or under it when the ring sits against the top of the screen.
func hint_top() -> float:
	var shade_top: float = centre.y - (RING_R + DISC) * 1.05
	if shade_top - 26.0 >= 4.0:
		return shade_top - 26.0
	return centre.y + (RING_R + DISC) * 1.05 + 6.0


## The right-click menu is a slip of paper too; the row under the pointer gets a pen line under it (a drop is in red ink).
func _draw_menu() -> void:
	if menu_k < 0:
		return
	var h: float = MENU_ROW_H * menu_rows.size() + 8.0
	LedgerRing.slip(self, Rect2(menu_pos, Vector2(MENU_W, h)), 91, Ledger.PAPER_SLIP, false)
	var hov: int = pad_row if SettingsManager.last_device == "pad" else menu_row_at(_mouse)
	for i in range(menu_rows.size()):
		var y: float = menu_pos.y + 4.0 + MENU_ROW_H * i
		var drop_row: bool = String(menu_rows[i][1]) == "drop"
		var col: Color = Ledger.RED_INK if drop_row else Ledger.INK
		LedgerRing.text(self, "typed", Vector2(menu_pos.x + 12.0, y + 16.0), String(menu_rows[i][0]), 13, col, MENU_W - 24.0, HORIZONTAL_ALIGNMENT_LEFT)
		if i == hov:
			draw_polyline(Ledger.pen_line(Vector2(menu_pos.x + 10.0, y + MENU_ROW_H - 3.0), Vector2(menu_pos.x + MENU_W - 10.0, y + MENU_ROW_H - 3.0), 30 + i, 0.8), Color(col.r, col.g, col.b, 0.75), 1.5, true)
