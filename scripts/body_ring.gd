extends Control

# THE BODY RING (owner round 48i — "corpse recovery with two inventory rings side by side, drag items across, Arc Raiders style"; docs/BACKPACK.md "Looting a body").
# Searching a fallen character's body opens the player's own pack ring (the player kneels - pack_wheel / player.begin_pack) and, to the LEFT of it, THIS ring: what is still on the
# body. Real time, like the pack: a hit slams both shut. Nothing here owns game state - the body's contents live in WorldState.player_corpses[key], every move is one
# WorldState call (take_body_item / put_body_item / take_body_all) that either happens whole or says why not and leaves everything where it was, so closing at ANY moment (a hit,
# Esc, a scene change, a death) can neither lose an item nor duplicate one.
#   - click an item, or drag it onto the pack ring  = take it (the pack must have room: "Your pack is full." and it stays on the body);
#   - drag one of your items onto this ring          = lay it on the body (up to WorldState.MAX_BODY_ITEMS);
#   - click the middle                               = take everything that fits (notes and scrap always: they need no slot);
#   - Esc / the pack key / a click out in the world  = the pack's own close (it stands up, this ring goes with it).
# A pad or a player with only pockets has no ring to read this with: they keep the old "take everything that fits" (player_corpse.gd).

const PW := preload("res://scripts/pack_wheel.gd")
const RingGeo := preload("res://scripts/ring_geo.gd")

const GAP := 14.0                       # screen px between the two rings' outer edges
const MIN_SLOTS := 4                    # the ring always shows at least this many wedges (empties faint), so its shape is steady

var is_open: bool = false               # showing (the pack is open AND a body is being searched)
var key: String = ""                    # the player_corpses key of the body being searched ("" = none)
var centre: Vector2 = Vector2.ZERO
var hover: int = -1                     # wedge under the pointer, or -1 (the middle / nothing)
var drag_k: int = -1                    # wedge being dragged (a press that moved), or -1
var mouse_override = null               # tests only: a Vector2 stands in for the pointer
var _press_k: int = -1
var _press_pos: Vector2 = Vector2.ZERO
var _mouse: Vector2 = Vector2.ZERO
var _opened_ms: int = 0
var _insts: Array = []                  # one ItemInstance per wedge, null for an empty wedge
var _slots: int = MIN_SLOTS


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	set_process(true)


# ---------------------------------------------------------------- opening / closing

## Begin searching the body `body_key`: kneel (the pack opens) and show this ring beside it. False = the caller keeps the old grab-all path
## (no pack, a pad in use, something already open...).
func begin(body_key: String) -> bool:
	if not WorldState.player_corpses.has(body_key):
		return false
	if SettingsManager.last_device == "pad":
		return false                    # no pad control on this ring yet
	var hud_pack = HUD.pack_wheel
	if hud_pack == null or not WorldState.has_backpack:
		return false
	if String(hud_pack.blocked_reason()) != "":
		return false
	var p = get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p) or not p.has_method("begin_pack"):
		return false
	if not bool(p.begin_pack()):
		return false
	key = body_key                      # the ring itself appears once the pack's "open" phase starts (_process)
	return true


## Is a body search under way (kneeling or open)? The pack ring asks, to sit beside this one instead of over the player.
func wants_pair() -> bool:
	return key != ""


## Where the PAIR of rings sit: [pack centre x, body centre x] for a player at screen x `px` — side by side, kept on screen, each `half` px from its middle edge.
func pair_x(px: float, half: float) -> Array:
	var reach: float = 2.0 * half + GAP * 0.5 + 2.0                  # the midpoint keeps a whole ring (2 x half) and half the gap clear of each screen edge
	var m: float = clampf(px, reach, HUD.SCREEN_W - reach)
	return [m + half + GAP * 0.5, m - half - GAP * 0.5]


func close() -> void:
	key = ""
	_hide()


func _hide() -> void:
	is_open = false
	visible = false
	hover = -1
	drag_k = -1
	_press_k = -1
	_insts = []


# ---------------------------------------------------------------- the contents

## Rebuild one ItemInstance per wedge from the body's records (a few dictionaries: cheap enough every frame).
func _refresh() -> void:
	var recs: Array = WorldState.body_items(key)
	_slots = maxi(MIN_SLOTS, recs.size())
	_insts = []
	for i in range(_slots):
		_insts.append(WorldState.instance_from_dict(recs[i]) if i < recs.size() else null)


func inst_at(k: int):
	if k < 0 or k >= _insts.size():
		return null
	return _insts[k]


func body_name() -> String:
	if not key.is_valid_int():
		return "THE FALLEN"
	return String(WorldState.character_display_name(WorldState.run_character(int(key)))).to_upper()


# ---------------------------------------------------------------- doing things

## Take wedge k into the pack (one item, whole or not at all).
func take(k: int) -> Dictionary:
	if inst_at(k) == null:
		return {"ok": false, "name": "", "why": ""}
	var r: Dictionary = WorldState.take_body_item(key, k)
	if bool(r["ok"]):
		HUD.show_feedback("Took %s." % String(r["name"]))
	elif String(r["why"]) != "":
		HUD.show_feedback(String(r["why"]))
	return r


## The middle: everything that fits.
func take_all() -> Dictionary:
	var s: Dictionary = WorldState.take_body_all(key)
	var bits: Array = []
	if int(s.get("notes", 0)) > 0:
		bits.append("%d notes" % int(s["notes"]))
	if int(s.get("scrap", 0)) > 0:
		bits.append("%d scrap" % int(s["scrap"]))
	if int(s.get("items_taken", 0)) > 0:
		bits.append("%d item%s" % [int(s["items_taken"]), "" if int(s["items_taken"]) == 1 else "s"])
	var left: bool = int(s.get("items_left", 0)) > 0 or int(s.get("notes_left", 0)) > 0
	if bits.is_empty() and left:
		HUD.show_feedback("Your pack is full.", true)
	elif not bits.is_empty():
		HUD.show_feedback("Took " + ", ".join(bits) + (". Your pack is full - the rest stays." if left else "."))
	return s


## One of the player's own items (inventory slot) laid on the body.
func put(slot: int) -> Dictionary:
	var r: Dictionary = WorldState.put_body_item(key, slot)
	if bool(r["ok"]):
		HUD.show_feedback("Left %s on the body." % String(r["name"]))
	elif String(r["why"]) != "":
		HUD.show_feedback(String(r["why"]))
	return r


# ---------------------------------------------------------------- geometry

func on_ring(pos: Vector2) -> bool:
	return is_open and (pos - centre).length() <= PW.RING_R + PW.DISC_SEL * 0.5 + 6.0


func owns_point(pos: Vector2) -> bool:
	return on_ring(pos)


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseMotion:
		if _press_k >= 0 and drag_k < 0 and (event.position - _press_pos).length() >= PW.DRAG_START_PX:
			drag_k = _press_k
		if drag_k >= 0:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _press_k >= 0:
			_finish_press(event.position)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		var pos: Vector2 = event.position
		if not on_ring(pos):
			return                                  # not ours: the pack's own handling (a click in the world puts the pack away)
		var i: int = RingGeo.index_for(pos - centre, _slots, PW.DEAD_ZONE)
		if i < 0:
			take_all()                              # the middle
		elif event.button_index == MOUSE_BUTTON_LEFT and inst_at(i) != null:
			_press_k = i                            # take on release - unless it turns into a drag
			_press_pos = pos
			drag_k = -1
		get_viewport().set_input_as_handled()


## The left button came up: a plain click takes the item; a drag takes it only when it was let go on the pack ring (anywhere else it just stays on the body).
func _finish_press(pos: Vector2) -> void:
	var from: int = _press_k
	var dragging: bool = drag_k >= 0
	_press_k = -1
	drag_k = -1
	if not dragging:
		var to: int = RingGeo.index_for(pos - centre, _slots, PW.DEAD_ZONE) if on_ring(pos) else -1
		if to == from:
			take(from)
		return
	var pack = HUD.pack_wheel
	if pack != null and pack.is_open and pack.on_ring(pos):
		take(from)


# ---------------------------------------------------------------- per frame

func _process(_delta: float) -> void:
	if key == "":
		if is_open:
			_hide()
		return
	var p = get_tree().get_first_node_in_group("player")
	var phase: String = str(p.get("pack_phase")) if p != null and is_instance_valid(p) and p.get("pack_phase") != null else ""
	var pack = HUD.pack_wheel
	if p == null or not is_instance_valid(p) or phase == "" or pack == null:
		close()                                      # the pack is closed (stood up, slammed shut, scene change): this ring goes with it
		return
	if not WorldState.player_corpses.has(key):
		close()                                      # the body is empty and gone
		return
	var want: bool = phase == "open" and pack.is_open and HUD.visible and not get_tree().paused
	if want and not is_open:
		_show(pack)
	elif not want and is_open:
		_hide()
	if not is_open:
		return
	centre = Vector2(pack.centre.x - 2.0 * (PW.RING_R + PW.DISC_SEL * 0.5 + 10.0) - GAP, pack.centre.y)      # always just left of the pack ring
	_refresh()
	var mouse: Vector2 = mouse_override if mouse_override is Vector2 else get_viewport().get_mouse_position()
	_mouse = mouse
	hover = RingGeo.index_for(mouse - centre, _slots, PW.DEAD_ZONE) if on_ring(mouse) else -1
	if (drag_k >= 0 or _press_k >= 0) and inst_at(maxi(drag_k, _press_k)) == null:
		_press_k = -1
		drag_k = -1
	queue_redraw()


func _show(pack: Control) -> void:
	var half: float = PW.RING_R + PW.DISC_SEL * 0.5 + 10.0
	centre = Vector2(pack.centre.x - 2.0 * half - GAP, pack.centre.y)
	_opened_ms = Time.get_ticks_msec()
	hover = -1
	drag_k = -1
	_press_k = -1
	is_open = true
	visible = true
	_refresh()
	Ledger.play("sheet", -16.0, 0.2)
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _open_t() -> float:
	var t: float = clampf(float(Time.get_ticks_msec() - _opened_ms) / 1000.0 / PW.OPEN_TIME, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _draw() -> void:
	if not is_open:
		return
	var t: float = _open_t()
	var n: int = _slots
	# The same dark ring as the pack's (scripts/lamp.gd), in cool steel instead of brass, so the body's ring is never taken for the pack's.
	var r: float = PW.RING_R * (0.55 + 0.45 * t)
	Lamp.ring_base(self, centre, (PW.RING_R + PW.DISC) * 1.05 * (0.6 + 0.4 * t), r, t, Lamp.STEEL.darkened(0.45))
	var pack_hot: bool = drag_k >= 0 and HUD.pack_wheel != null and HUD.pack_wheel.is_open and HUD.pack_wheel.on_ring(_mouse)
	var order: Array = []
	for k in range(n):
		if k != hover:
			order.append(k)
	if hover >= 0 and hover < n:
		order.append(hover)
	for k in order:
		var inst = inst_at(k)
		var on: bool = k == hover
		var side: float = (PW.DISC_SEL if on and inst != null else PW.DISC) * (0.7 + 0.3 * t)
		var pos: Vector2 = RingGeo.slot_position(centre, k, n, r)
		var rect := Rect2((pos - Vector2(side, side) * 0.5).round(), Vector2(side, side))
		if k == drag_k:
			Lamp.dashed_rect(self, rect, Lamp.fade(Lamp.STEEL.darkened(0.3), 0.8 * t))
		else:
			Lamp.slot(self, rect, inst, {"on": on, "t": t, "accent": Lamp.STEEL, "lit": Lamp.STEEL.lightened(0.25)})
	# The middle: one small readout — what the pointer is on, or what the middle does.
	var inst_h = inst_at(hover)
	var notes_left: int = int(WorldState.player_corpses.get(key, {}).get("notes", 0))
	var lines: Array = []
	if drag_k >= 0 and inst_at(drag_k) != null:
		lines = [{"big": "TAKE", "col": Lamp.GREEN}] if pack_hot else [{"title": inst_at(drag_k).get_display_name()}]
	elif inst_h != null:
		lines = Lamp.item_lines(inst_h)
	else:
		var empty: bool = true
		for i2 in _insts:
			if i2 != null:
				empty = false
		lines = [{"word": "EMPTY" if empty and notes_left <= 0 else "LOOT", "col": Lamp.DIM if empty and notes_left <= 0 else Lamp.STEEL}]
		if notes_left > 0:
			lines.append({"note": "%d notes" % notes_left, "col": Lamp.GREEN})
	Lamp.info(self, centre, lines, t, Lamp.STEEL)
	if drag_k >= 0:
		var di = inst_at(drag_k)
		if di != null:
			var dtex: Texture2D = ItemData.get_texture(di.item_id)
			if dtex != null:
				draw_texture_rect(dtex, Rect2(_mouse - Vector2(22, 20), Vector2(56, 56)), false, Color(0.0, 0.0, 0.0, 0.34))
				draw_texture_rect(dtex, Rect2(_mouse - Vector2(28, 28), Vector2(56, 56)), false, Color(1, 1, 1, 0.94))
	# whose body this is: their name on a steel tab over the ring
	var hy: float = centre.y - (PW.RING_R + PW.DISC) * 1.05 - 6.0
	if hy - 7.0 < 4.0:
		hy = centre.y + (PW.RING_R + PW.DISC) * 1.05 + 6.0
	Lamp.tab(self, Vector2(centre.x, hy), body_name(), Lamp.STEEL, t)
