extends Control

# The QUICK WHEEL (owner round 26 — concept 4 of the UI mock-ups, The Last of Us / Hades): HOLD the
# wheel key (default Tab, rebindable) and the game slows to a crawl while a ring of your items opens
# round the player; point with the mouse, RELEASE to equip. Releasing in the middle (or with nothing
# under the pointer) cancels. It only ever equips — exactly what clicking the hotbar slot does — so
# using an item is still Q / double-click.
#
# Robustness (docs/CLAUDE.md rules): it can never strand the game in slow motion — every exit path
# (release, cancel, pause, death, a cutscene, the HUD hiding, the node leaving the tree) restores the
# time scale it found — and it refuses to open when it would fight another modal state.

const OPEN_TIME := 0.14                # real seconds for the ring to unfold
const SLOW_SCALE := 0.2
const RING_R := 124.0
const DISC := 76.0
const DISC_SEL := 92.0
const DEAD_ZONE := 40.0                # inside this radius of the centre = cancel
const STRIP_TOP := 528.0
const AMBER := Color(0.89, 0.647, 0.247, 1.0)
const ROOT_TEXT := Color(0.93, 0.89, 0.82, 1.0)

var is_open: bool = false
var entries: Array = []                # inventory slot indexes on the wheel, in ring order
var hover: int = -1                    # index INTO entries, or -1 for the middle / nothing
var centre: Vector2 = Vector2.ZERO
var mouse_override = null              # tests only: a Vector2 stands in for the pointer (headless has none)
var _prev_scale: float = 1.0
var _opened_ms: int = 0


func _ready() -> void:
	# ALWAYS: a pause (the menu, a tutorial beat) must be able to close the wheel and hand the time back
	# even though the tree isn't processing — otherwise a key released during a pause left it open.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	set_process(false)


func _exit_tree() -> void:
	# Never leave the game slowed if the HUD or this node goes away mid-hold.
	if is_open:
		Engine.time_scale = _prev_scale
		is_open = false


# ---------------------------------------------------------------- pure geometry (unit-tested)

## Which wedge a pointer offset (relative to the centre) is over, for n items laid out clockwise from
## the top; -1 inside the dead zone or with nothing to pick.
static func index_for(offset: Vector2, n: int, dead_zone: float = DEAD_ZONE) -> int:
	if n <= 0 or offset.length() < dead_zone:
		return -1
	var a: float = fposmod(atan2(offset.x, -offset.y), TAU)        # 0 = straight up, clockwise
	var wedge: float = TAU / float(n)
	return int(round(a / wedge)) % n


## Where item k of n sits on a ring of radius r about c (item 0 at the top, clockwise).
static func slot_position(c: Vector2, k: int, n: int, r: float = RING_R) -> Vector2:
	var a: float = -PI * 0.5 + float(k) * TAU / float(maxi(n, 1))
	return c + Vector2(cos(a), sin(a)) * r


# ---------------------------------------------------------------- opening rules

func build_entries() -> Array:
	var out: Array = []
	var cap: int = mini(WorldState.inventory.size(), WorldState.get_inventory_slots())
	for i in range(cap):
		if WorldState.get_instance_at(i) != null:
			out.append(i)
	return out


## Why the wheel can't open right now, or "" when it can. (A reason string, not a bool, so a test can
## say WHICH rule fired.)
func blocked_reason() -> String:
	if is_open:
		return "already open"
	if not HUD.visible:
		return "hud hidden"
	if get_tree().paused:
		return "paused"
	var p = get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		return "no player"
	for flag in ["is_dead", "is_dying", "is_cutscene", "escaping", "is_lashing", "is_listening"]:
		if bool(p.get(flag)):
			return flag
	for m in get_tree().get_nodes_in_group("modal_panel"):
		if is_instance_valid(m) and m.visible:
			return "a panel is open"
	for m in get_tree().get_nodes_in_group("loot_ui"):
		if is_instance_valid(m) and "visible" in m and m.visible:
			return "loot is open"
	if HUD.dialogue_panel != null and HUD.dialogue_panel.visible:
		return "dialogue"
	if HUD.character_panel != null and HUD.character_panel.visible:
		return "journal"
	return ""


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("item_wheel") and not event.is_echo():
		if open():
			get_viewport().set_input_as_handled()
	elif event.is_action_released("item_wheel") and is_open:
		close(true)
		get_viewport().set_input_as_handled()


func open() -> bool:
	if blocked_reason() != "":
		return false
	entries = build_entries()
	if entries.is_empty():
		HUD.show_feedback("Nothing to draw.")
		return false
	var p = get_tree().get_first_node_in_group("player")
	var s: Vector2 = get_viewport().get_canvas_transform() * (p.global_position + Vector2(0, -40))
	var half: float = RING_R + DISC_SEL * 0.5 + 10.0
	centre = Vector2(clampf(s.x, half, HUD.SCREEN_W - half),
		clampf(s.y, half, maxf(half, STRIP_TOP - half - 8.0)))
	hover = entries.find(HUD.selected_slot)          # start on what's in hand
	_prev_scale = Engine.time_scale
	Engine.time_scale = SLOW_SCALE
	_opened_ms = Time.get_ticks_msec()
	is_open = true
	visible = true
	set_process(true)
	queue_redraw()
	return true


## Close the wheel. commit = equip what the pointer is on (release); false = cancel.
func close(commit: bool) -> void:
	if not is_open:
		return
	Engine.time_scale = _prev_scale
	is_open = false
	visible = false
	set_process(false)
	if commit and hover >= 0 and hover < entries.size():
		var slot: int = int(entries[hover])
		if slot != HUD.selected_slot and slot < WorldState.inventory.size():
			HUD.select_slot(slot)               # the same call clicking the hotbar makes (announces it too)
	hover = -1
	entries = []


func _process(_delta: float) -> void:
	if not is_open:
		return
	# Anything that takes the player out of play cancels it — and gives the time back.
	var p = get_tree().get_first_node_in_group("player")
	if get_tree().paused or not HUD.visible or p == null or not is_instance_valid(p) \
			or bool(p.get("is_dead")) or bool(p.get("is_dying")) or bool(p.get("is_cutscene")) or bool(p.get("escaping")):
		close(false)
		return
	# The bag can change under us (a drop, a pickup): keep the ring honest.
	var fresh: Array = build_entries()
	if fresh != entries:
		var held: int = int(entries[hover]) if hover >= 0 and hover < entries.size() else -1
		entries = fresh
		if entries.is_empty():
			close(false)
			return
		hover = entries.find(held)
	var mouse: Vector2 = mouse_override if mouse_override is Vector2 else get_viewport().get_mouse_position()
	hover = index_for(mouse - centre, entries.size())
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _open_t() -> float:
	var t: float = clampf(float(Time.get_ticks_msec() - _opened_ms) / 1000.0 / OPEN_TIME, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _text(font: Font, pos: Vector2, s: String, size: int, col: Color, width: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string_outline(font, pos, s, align, width, size, 4, Color(0, 0, 0, 0.9))
	draw_string(font, pos, s, align, width, size, col)


func _draw() -> void:
	if not is_open or entries.is_empty():
		return
	var t: float = _open_t()
	var n: int = entries.size()
	var font: Font = get_theme_default_font()
	# The world dims and falls away; the ring unfolds from the middle.
	draw_rect(Rect2(Vector2.ZERO, Vector2(HUD.SCREEN_W, HUD.SCREEN_H)), Color(0.02, 0.02, 0.03, 0.5 * t))
	var r: float = RING_R * (0.55 + 0.45 * t)
	var band: float = DISC + 26.0
	draw_arc(centre, r, 0.0, TAU, 128, Color(0.075, 0.07, 0.085, 0.82 * t), band, true)
	draw_arc(centre, r + band * 0.5, 0.0, TAU, 128, Color(0.89, 0.647, 0.247, 0.28 * t), 2.0, true)
	draw_arc(centre, r - band * 0.5, 0.0, TAU, 128, Color(0.29, 0.275, 0.32, t), 2.0, true)
	var wedge: float = TAU / float(n)
	if hover >= 0:
		var a: float = -PI * 0.5 + float(hover) * wedge
		draw_arc(centre, r, a - wedge * 0.5 + 0.03, a + wedge * 0.5 - 0.03, 32, Color(0.89, 0.647, 0.247, 0.22 * t), band, true)
	for k in range(n):
		var slot: int = int(entries[k])
		var inst = WorldState.get_instance_at(slot)
		if inst == null:
			continue
		var pos: Vector2 = slot_position(centre, k, n, r)
		var on: bool = k == hover
		var held: bool = slot == HUD.selected_slot
		var rad: float = (DISC_SEL if on else DISC) * 0.5 * (0.7 + 0.3 * t)
		draw_circle(pos, rad, Color(0.2, 0.16, 0.1, 0.96) if on or held else Color(0.13, 0.125, 0.145, 0.96))
		draw_arc(pos, rad, 0.0, TAU, 40, AMBER if on else (Color(0.89, 0.647, 0.247, 0.55) if held else Color(0.29, 0.275, 0.32, 1.0)), 4.0 if on else 2.0, true)
		var tex: Texture2D = ItemData.get_texture(inst.item_id)
		if tex != null:
			var broken: bool = inst.is_depleted and inst.get_max_durability() > 0
			draw_texture_rect(tex, Rect2(pos - Vector2(28, 28), Vector2(56, 56)), false, Color(0.5, 0.4, 0.4, 1.0) if broken else Color(1, 1, 1, 1))
		_text(font, pos + Vector2(-rad + 4.0, -rad + 16.0), str(slot + 1), 12, AMBER if on else Color(0.64, 0.61, 0.53))
		var max_d: int = inst.get_max_durability()
		if max_d > 1 and not inst.is_depleted:
			var ratio: float = clampf(float(inst.current_durability) / float(max_d), 0.0, 1.0)
			var bw: float = rad * 1.1
			var by: float = pos.y + rad * 0.72
			draw_rect(Rect2(pos.x - bw * 0.5, by, bw, 3.0), Color(0, 0, 0, 1))
			draw_rect(Rect2(pos.x - bw * 0.5, by, bw * ratio, 3.0), Color(0.3, 0.8, 0.3) if ratio > 0.3 else Color(0.9, 0.25, 0.22))
		if inst.count > 1:
			_text(font, pos + Vector2(rad * 0.15, rad * 0.62), "x%d" % inst.count, 12, ROOT_TEXT, rad * 0.8, HORIZONTAL_ALIGNMENT_RIGHT)
	# The middle: what the pointer is on, or a nudge.
	var inst_h = WorldState.get_instance_at(int(entries[hover])) if hover >= 0 else null
	var cw: float = 190.0
	if inst_h != null:
		var c: Dictionary = HUD.item_tip_content(inst_h)
		_text(font, centre + Vector2(-cw * 0.5, -22), String(c["title"]).to_upper(), 17, Color(1.0, 0.85, 0.4) if c.get("legendary", false) else ROOT_TEXT, cw, HORIZONTAL_ALIGNMENT_CENTER)
		var stats: Array = c["stats"]
		for i in range(mini(stats.size(), 2)):
			_text(font, centre + Vector2(-cw * 0.5, 0 + i * 16), String(stats[i]), 12, Color(0.75, 0.79, 0.84), cw, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_text(font, centre + Vector2(-cw * 0.5, -6), "CHOOSE", 15, ROOT_TEXT, cw, HORIZONTAL_ALIGNMENT_CENTER)
		_text(font, centre + Vector2(-cw * 0.5, 14), "release here to cancel", 12, Color(0.64, 0.61, 0.53), cw, HORIZONTAL_ALIGNMENT_CENTER)
	var hint_y: float = minf(centre.y + RING_R + DISC_SEL * 0.5 + 30.0, STRIP_TOP - 8.0)
	_text(font, Vector2(centre.x - 240.0, hint_y), "point to choose  ·  release to equip  ·  time slows", 12, Color(0.64, 0.61, 0.53), 480.0, HORIZONTAL_ALIGNMENT_CENTER)
