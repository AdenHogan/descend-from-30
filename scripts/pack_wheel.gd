extends Control

# The BACKPACK RING (owner round 26 — "click the pack, the player bends down and opens their backpack,
# then a wheel for inventory opens with live gameplay underneath so you can still be attacked";
# docs/BACKPACK.md). Built on the quick wheel: the same ring geometry (QuickWheel.index_for /
# slot_position) — but where the quick wheel slows time and only equips on release, this one is the
# whole bag, in REAL TIME:
#   • the player kneels first (player.begin_pack: kneel → open → stand); the ring only exists while the
#     player is in the "open" phase, so it is purely a VIEW of that state and can never desync from it;
#   • every slot is on the ring (empty ones faint) so its shape is stable;
#   • click = equip / put away, right-click = use (a bandage from the bag), Delete = drop it at your feet,
#     Esc / the pack key / the centre / anywhere off the ring = close and stand;
#   • the world is NOT slowed, and a hit slams it shut (player.receive_hit → end_pack).
# Robustness: nothing here owns state that could strand the game — no time scale, no pause. If the
# player leaves the "open" phase for ANY reason (a hit, a cutscene, death, a scene change) the ring is
# simply gone next frame.

const QuickWheel := preload("res://scripts/quick_wheel.gd")

const OPEN_TIME := 0.16
const RING_R := 118.0
const DISC := 70.0
const DISC_SEL := 86.0
const DEAD_ZONE := 36.0
const STRIP_TOP := 528.0
const AMBER := Color(0.89, 0.647, 0.247, 1.0)
const ROOT_TEXT := Color(0.93, 0.89, 0.82, 1.0)
const DIM_TEXT := Color(0.64, 0.61, 0.53)

var is_open: bool = false               # the ring is showing (player in the "open" phase)
var slots: Array = []                   # inventory slot indexes on the ring, in ring order (empties too)
var hover: int = -1                     # index INTO slots, or -1 for the middle / nothing
var centre: Vector2 = Vector2.ZERO
var mouse_override = null               # tests only: a Vector2 stands in for the pointer
var _opened_ms: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	set_process(true)


# ---------------------------------------------------------------- opening / closing

## Why the pack can't be opened right now, or "" when it can.
func blocked_reason() -> String:
	var r: String = QuickWheel.ui_block_reason(get_tree())
	if r != "":
		return r
	var qw = HUD.quick_wheel
	if qw != null and is_instance_valid(qw) and qw.is_open:
		return "the quick wheel is open"
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
	if event is InputEventMouseButton and event.pressed:
		var pos: Vector2 = event.position
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if not on_ring(pos):
				if pos.y < STRIP_TOP:             # a click out in the world: put the pack away
					p.end_pack(false)
					get_viewport().set_input_as_handled()
				return                            # the hotbar strip keeps its own clicks
			var i: int = QuickWheel.index_for(pos - centre, slots.size(), DEAD_ZONE)
			if i < 0:
				p.end_pack(false)                 # the middle = done
			elif event.button_index == MOUSE_BUTTON_LEFT:
				equip_at(i)
			else:
				use_at(i)
			get_viewport().set_input_as_handled()


## Is a screen point on the ring (the band + the middle) — a click there is the ring's, not the world's.
func on_ring(pos: Vector2) -> bool:
	return (pos - centre).length() <= RING_R + DISC_SEL * 0.5 + 6.0


func _slot_inst(k: int):
	if k < 0 or k >= slots.size():
		return null
	var slot: int = int(slots[k])
	return WorldState.get_instance_at(slot) if slot < WorldState.inventory.size() else null


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
	hover = QuickWheel.index_for(mouse - centre, slots.size(), DEAD_ZONE)
	queue_redraw()


func build_slots() -> Array:
	var out: Array = []
	var cap: int = mini(WorldState.inventory.size(), WorldState.get_inventory_slots())
	for i in range(cap):
		out.append(i)
	return out


func _show(p: Node) -> void:
	slots = build_slots()
	# FLOATING ABOVE the kneeling player (so the bend-down and the open pack stay visible below it),
	# clamped to the screen and clear of the hotbar strip.
	var half: float = RING_R + DISC_SEL * 0.5 + 10.0
	var s: Vector2 = get_viewport().get_canvas_transform() * (p.global_position + Vector2(0, -60.0 - half))
	centre = Vector2(clampf(s.x, half, HUD.SCREEN_W - half), clampf(s.y, half, maxf(half, STRIP_TOP - half - 8.0)))
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
	for k in range(n):
		var slot: int = int(slots[k])
		var inst = WorldState.get_instance_at(slot) if slot < WorldState.inventory.size() else null
		var pos: Vector2 = QuickWheel.slot_position(centre, k, n, r)
		var on: bool = k == hover
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
	if inst_h != null:
		var c: Dictionary = HUD.item_tip_content(inst_h)
		_text(font, centre + Vector2(-cw * 0.5, -22), String(c["title"]).to_upper(), 16, Color(1.0, 0.85, 0.4) if c.get("legendary", false) else ROOT_TEXT, cw, HORIZONTAL_ALIGNMENT_CENTER)
		var stats: Array = c["stats"]
		for i in range(mini(stats.size(), 2)):
			_text(font, centre + Vector2(-cw * 0.5, 0 + i * 16), String(stats[i]), 12, Color(0.75, 0.79, 0.84), cw, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_text(font, centre + Vector2(-cw * 0.5, -6), "YOUR PACK", 15, ROOT_TEXT, cw, HORIZONTAL_ALIGNMENT_CENTER)
		_text(font, centre + Vector2(-cw * 0.5, 14), "click here to close", 12, DIM_TEXT, cw, HORIZONTAL_ALIGNMENT_CENTER)
	var hint_y: float = maxf(centre.y - RING_R - DISC_SEL * 0.5 - 8.0, 16.0)      # a line over the ring
	_text(font, Vector2(centre.x - 250.0, hint_y), "click equip  ·  right-click use  ·  Del drop  ·  Esc close  ·  the world keeps moving", 12, DIM_TEXT, 500.0, HORIZONTAL_ALIGNMENT_CENTER)
