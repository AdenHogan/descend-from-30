extends CanvasLayer

# Scavenge: the SEARCH and its RESULT (owner round 48j: "maybe we don't even need the bar… the word searching literally can be the bar"; round 48l: "I like how searching is now in the game
# world. Let's put the box in the game world too, smaller, beside the node, when a player walks back up to a node they have searched but did not take" / "this hammer box is too much").
# While a search runs there is no panel at all: a small SEARCHING hangs above the node and its letters light S to G (scripts/search_word.gd), so the player and the room stay in view;
# when the last letter is lit it resolves where it hangs — and either the result tag appears BESIDE THE NODE (something found) or a one-line "Nothing." is said (nothing).
# The tag — small, dark glass with brass corners (scripts/lamp.gd), standing in the world beside the node it came from — says only what the player needs: the one-word kind, the name, a
# line of fact where there is one (where a key opens; how many rounds) and, for a weapon, ONLY the numbers that differ from the one in hand (at most two). It is taken by:
#   • pressing E / interact, or
#   • double-clicking it, or
#   • dragging it onto your pack (the backpack button, bottom-right — there is no bar or hotbar),
# and LEFT by walking away, by clicking anywhere in the world off the tag, or — stepped up at
# set-back furniture, where there's no walking — by any movement key (player.gd steps you down and
# calls leave()). Searching again re-opens it. No Take/Leave buttons. The panel must ALWAYS be
# leavable: a full inventory once trapped the player up at a bookshelf (owner playtest — S and clicks
# were both ignored while the loot panel was open, and the only other exit, walking, doesn't exist up there).
# WALKING BACK UP to a node that was searched but not emptied shows the SAME tag beside it with no press at all (the PREVIEW — not modal: nothing is locked, you can walk on, fight, anything);
# [interact] then takes it in that one press. Built in code so the layout is controlled here.

const REVEAL_TIME = 3.0
const EMPTY_REVEAL_FACTOR = 0.5        # a search that turns up nothing takes half as long (owner round 36g: "finding nothing takes too long")
const RingGeo := preload("res://scripts/ring_geo.gd")
const DRAG_THRESHOLD = 8.0
const DOUBLE_CLICK_TIME = 0.35
const PANEL_W = 300.0
const PAD := 14.0                      # the glass's margin round its contents
const ICON_BOX := 68.0                 # the 56-px icon at exactly 1x on a dark well
const TAG_GAP := 26.0                  # screen px between the node and the tag beside it
const TAG_MARGIN := 8.0                # the tag is kept this far inside the screen
const WORD_RISE := 34.0                # how far above the node the SEARCHING word hangs (screen px)
const SCREEN_W = 1152.0
const SCREEN_H = 648.0

var reveal_timer = 0.0
var reveal_time = REVEAL_TIME          # this search's length (halved when the node holds nothing)
var is_revealing = false
var current_item_id = ""
var current_key_target = ""
var current_anchor_name = ""
var current_apartment_id = ""
var anchor_node: Node = null
var has_item = false               # a takeable item is currently shown

# UI
var panel: PanelContainer = null       # the RESULT tag (hidden while a search runs)
var glass: LampGlass = null
var icon: TextureRect = null
var _land_tween: Tween = null
var name_label: Label = null
var kind_label: Label = null           # one word: what sort of thing it is
var fact_label: Label = null           # one line of fact under the name: where a key opens, how many rounds — empty for most things
var hint_label: Label = null           # the keys: "[E] TAKE"
var compare_label: LampRows = null     # a found weapon's numbers that DIFFER from the one in hand (ItemCompare), at most two rows
var icon_row: HBoxContainer = null
var search_word: SearchWord = null     # SEARCHING, lit S to G while a search runs
var _word_layer: CanvasLayer = null    # its own layer: it outlives this one's visibility for the beat it takes to resolve
var _last_lit: int = 0
var _preview: Dictionary = {}          # the PREVIEW tag (same parts as the result tag): shown beside a searched-but-not-taken node you walk back up to
var _preview_layer: CanvasLayer = null # its own layer, for the same reason as the word's: it shows while this one is closed
var _preview_node: Node = null
var _preview_sig: String = ""

# drag / double-click
var drag_armed = false
var drag_active = false
var drag_from = Vector2.ZERO
var ghost: TextureRect = null
var last_press_time = 0.0
var _host: Control = null
var _mouse_pos: Vector2 = Vector2.ZERO # the pointer as the last motion event reported it (a drag follows this — a touch drag has no cursor to poll)
const RING_GAP := 24.0                 # clear space between the tag and the pack ring that opens beside it


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
	_host = Control.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)

	# The result tag is a pane of dark glass (scripts/lamp.gd): the glass only draws, a margin holds the contents, so a tag that changes height — a found weapon with its numbers under it —
	# is still one pane whatever it holds. It is placed in the world beside the node (`_place_tag`), never in the middle of the screen.
	var parts: Dictionary = _make_tag(_host)
	panel = parts["panel"]
	glass = parts["glass"]
	icon = parts["icon"]
	icon_row = parts["icon_row"]
	kind_label = parts["kind"]
	name_label = parts["name"]
	fact_label = parts["fact"]
	compare_label = parts["compare"]
	hint_label = parts["hint"]

	# The PREVIEW tag: the same parts on a layer of its own, so it can stand beside a node while this layer is closed.
	_preview_layer = CanvasLayer.new()
	_preview_layer.layer = 3
	add_child(_preview_layer)
	var pv_host := Control.new()
	pv_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	pv_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_layer.add_child(pv_host)
	_preview = _make_tag(pv_host)

	# SEARCHING lives on a layer of its own, above this one.
	_word_layer = CanvasLayer.new()
	_word_layer.layer = 4
	add_child(_word_layer)
	search_word = SearchWord.new()
	_word_layer.add_child(search_word)


## One tag's parts, built under `host`: {panel, glass, icon, icon_row, kind, name, fact, compare, hint}. Hidden until something fills and shows it.
func _make_tag(host: Control) -> Dictionary:
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.custom_minimum_size = Vector2(PANEL_W, 0)
	tag.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	tag.visible = false
	host.add_child(tag)
	var gl := LampGlass.new()
	tag.add_child(gl)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(PAD))
	tag.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	pad.add_child(vbox)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)
	var well := PanelContainer.new()                    # the thing sits on a dark well with a thin brass-brown edge, as on the board
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.custom_minimum_size = Vector2(ICON_BOX, ICON_BOX)
	var well_style := StyleBoxFlat.new()
	well_style.bg_color = Lamp.WELL
	well_style.border_color = Lamp.EDGE
	well_style.set_border_width_all(1)
	well.add_theme_stylebox_override("panel", well_style)
	row.add_child(well)
	var pic := TextureRect.new()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.custom_minimum_size = Vector2(56, 56)           # the 56 px icon at exactly 1x
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	well.add_child(pic)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var kind := _lamp_label("", "label", Lamp.PX_LABEL - 2, Lamp.LABEL)
	col.add_child(kind)
	var nm := _lamp_label("", "head", Lamp.PX_NAME, Lamp.TEXT)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(PANEL_W - 2.0 * PAD - ICON_BOX - 12.0, 0)
	col.add_child(nm)
	var fact := _lamp_label("", "body", Lamp.PX_BODY - 2, Lamp.BODY)
	fact.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fact.custom_minimum_size = Vector2(PANEL_W - 2.0 * PAD - ICON_BOX - 12.0, 0)
	fact.visible = false
	col.add_child(fact)

	var cmp := LampRows.new()
	cmp.custom_minimum_size = Vector2(PANEL_W - 2.0 * PAD, 0)
	cmp.visible = false
	vbox.add_child(cmp)

	var hint := _lamp_label("", "label", Lamp.PX_LABEL, Lamp.BRASS)             # the keys, in brass: "[E]  TAKE"
	vbox.add_child(hint)
	return {"panel": tag, "glass": gl, "icon": pic, "icon_row": row, "kind": kind, "name": nm, "fact": fact, "compare": cmp, "hint": hint}


func _lamp_label(text: String, kind: String, px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Lamp.font(kind))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	return l


## Each time the panel opens: the name is bright again (a refused take turns it red).
func _restyle() -> void:
	name_label.add_theme_color_override("font_color", Lamp.TEXT)


func _set_icon(tex: Texture2D) -> void:
	icon.texture = tex


## The panel arrives: it fades up and settles from a hair large (a tenth of a second), with a soft tick.
func _land(sound: String) -> void:
	Ledger.play(sound, -14.0, 0.12)
	panel.pivot_offset = panel.size * 0.5
	if _land_tween != null and _land_tween.is_valid():
		_land_tween.kill()
	panel.scale = Vector2(1.03, 1.03)
	panel.modulate.a = 0.0
	_land_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_land_tween.tween_property(panel, "scale", Vector2.ONE, 0.12)
	_land_tween.tween_property(panel, "modulate:a", 1.0, 0.10)


## The result tag shows (a search finished or the node was already searched), or hides (a search is running). Shown, it stands beside its node.
func _show_panel(on: bool) -> void:
	panel.visible = on
	if on:
		panel.reset_size()           # a PanelContainer keeps its biggest size until told to shrink
		_place_tag(panel, anchor_node)


## Stand `tag` in the world beside `node` — to its right, or to its left when the right would leave the screen — a little above its middle, kept inside the screen (screen px via the canvas
## transform, never current_scene). With no node it stands beside the player instead, never in the middle of the screen.
func _place_tag(tag: PanelContainer, node: Node) -> void:
	var src: Node2D = node as Node2D if node != null and is_instance_valid(node) else null
	if src == null:
		src = get_tree().get_first_node_in_group("player") as Node2D
	var sz: Vector2 = tag.size
	var at := Vector2(SCREEN_W * 0.5, SCREEN_H * 0.4)
	if src != null:
		at = get_viewport().get_canvas_transform() * src.global_position
	var x: float = at.x + TAG_GAP
	if x + sz.x > SCREEN_W - TAG_MARGIN:
		x = at.x - TAG_GAP - sz.x
	tag.position = Vector2(clampf(x, TAG_MARGIN, maxf(TAG_MARGIN, SCREEN_W - sz.x - TAG_MARGIN)), clampf(at.y - sz.y * 0.5 - 6.0, TAG_MARGIN, maxf(TAG_MARGIN, SCREEN_H - sz.y - TAG_MARGIN)))


## `node` = the scavenge node being searched (the SEARCHING word hangs over it); without it the node is looked up by name.
func open(item_id: String, anchor_name: String, apartment_id: String, node: Node = null) -> void:
	# Pressed on a node whose tag was ALREADY standing beside it: the tag said "[E] TAKE", so that one press takes it.
	var quick: bool = node != null and is_instance_valid(node) and preview_showing_for(node)
	WorldState.loot_open = true
	is_revealing = false
	has_item = false
	current_item_id = item_id
	current_anchor_name = anchor_name
	current_apartment_id = apartment_id
	current_key_target = ""
	anchor_node = node if node != null and is_instance_valid(node) else get_tree().get_root().find_child(anchor_name, true, false)

	if WorldState.is_anchor_a_key(apartment_id, anchor_name):
		current_key_target = WorldState.get_anchor_key_target(apartment_id, anchor_name)
		current_item_id = WorldState.key_item_for(current_key_target)

	reveal_time = REVEAL_TIME * (EMPTY_REVEAL_FACTOR if current_item_id == "" or ItemData.get_item(current_item_id).is_empty() else 1.0)

	# Someone living here watches you go through their things (resident_npc.gd).
	get_tree().call_group("resident_npc", "on_scavenge", "start", apartment_id)
	_restyle()
	if WorldState.is_anchor_searched(apartment_id, anchor_name):
		_hide_preview()
		_reveal_item()
		visible = has_item                    # an empty one has already said so and closed itself
		if quick and has_item:
			_take()                            # (a full pack leaves the tag up saying MAKE ROOM, exactly as a second press always did)
		return

	reveal_timer = 0.0
	is_revealing = true
	# The press starts it: the drawer opens, the glass tips, the screen goes dark NOW, while the word fills (owner round 45c)
	if anchor_node != null and is_instance_valid(anchor_node) and anchor_node.has_method("on_search_begin"):
		anchor_node.on_search_begin()
	_set_icon(null)
	name_label.text = ""
	hint_label.text = ""
	kind_label.text = ""
	_show_panel(false)                       # no panel while it runs: SEARCHING is the whole readout, and the room stays in view
	_last_lit = 0
	search_word.begin()
	_place_word()
	visible = true


## What the player mutters over an empty search: a short line, stable per node (so re-searching reads the same).
const NOTHING_LINES := ["Nothing.", "Empty.", "Just dust.", "Nothing useful.", "Nothing here.", "Picked clean."]


static func nothing_line(apartment_id: String, anchor_name: String) -> String:
	return NOTHING_LINES[absi(hash(apartment_id + "/" + anchor_name)) % NOTHING_LINES.size()]


func _reveal_item() -> void:
	WorldState.mark_anchor_searched(current_apartment_id, current_anchor_name)
	get_tree().call_group("open_furniture", "on_searched", current_apartment_id, current_anchor_name)   # (already open since the press; a no-op then)
	is_revealing = false
	var item_data = ItemData.get_item(current_item_id)
	if current_item_id == "" or item_data.is_empty():
		# An empty search is a line, not a panel (owner round 48i: "if there is nothing found, we don't need a big empty inventory box that pops... the
		# player can say nothing in real time following the search, allowing us to just keep going"): the word goes grey and sinks, the player says so in passing.
		search_word.resolve(false)
		_set_icon(null)
		name_label.text = ""
		hint_label.text = ""
		has_item = false
		HUD.show_feedback(nothing_line(current_apartment_id, current_anchor_name))
		_close(false)
		return
	search_word.resolve(true)                # the word flares and lifts away as the tag arrives
	has_item = true
	WorldState.note_item_seen(current_item_id)   # seeing it in the tag counts as found (codex)
	var parts := _tag_parts()
	_fill_tag(parts, current_item_id, current_key_target, current_apartment_id, current_anchor_name)
	if _is_rounds() and not WorldState.guns_with_room().is_empty():
		hint_label.text = SettingsManager.localize("[{interact}]  TAKE      [{item_use}]  LOAD")
	_show_panel(true)
	visible = true
	_land("tick")


func _tag_parts() -> Dictionary:
	return {"panel": panel, "icon": icon, "kind": kind_label, "name": name_label, "fact": fact_label, "hint": hint_label, "compare": compare_label}


## Fill a tag (the result's or the preview's) for one thing, with only what the player needs (owner round 48l: "this hammer box is too much… simplify this information to what the player
## needs"): the one-word kind, the name, a line of fact where there is one, for a weapon only the numbers that DIFFER from the one in hand, and the key to press. Items of a kind
## are the same as each other (no per-item stats yet), so a table of their numbers would be the same table every time.
func _fill_tag(parts: Dictionary, item_id: String, key_target: String, apt: String, anchor: String) -> void:
	var d: Dictionary = ItemData.get_item(item_id)
	var cabinet: bool = _is_cabinet_anchor_weapon(apt, anchor, item_id)
	parts["icon"].texture = ItemData.get_texture(item_id)
	parts["kind"].text = "KEY" if key_target != "" else Lamp.kind_word(d)
	var nm: Label = parts["name"]
	nm.add_theme_color_override("font_color", Lamp.TEXT)
	var fact: String = ""
	var fact_col: Color = Lamp.BODY
	if key_target != "":
		nm.text = WorldState.key_name(key_target)
		fact = WorldState.key_where(key_target)
		if WorldState.key_is_dead(key_target):
			fact += " — no cabinet there now"
			fact_col = Lamp.RED
	elif cabinet:
		var inst = WorldState.gun_cabinet_weapon(apt)
		nm.text = inst.get_display_name() + "  ·  " + inst.tier_label()
	else:
		nm.text = d["name"]
		if d.get("is_ammo", false):
			var n: int = WorldState.get_anchor_amount(apt, anchor)
			if n > 0:
				fact = "%d rounds" % n
	var fl: Label = parts["fact"]
	fl.text = fact
	fl.visible = fact != ""
	fl.add_theme_color_override("font_color", fact_col)
	parts["hint"].text = SettingsManager.localize("[{interact}]  TAKE")
	_fill_compare(parts["compare"], d, item_id, key_target, cabinet)


## A found weapon shows ONLY the numbers that differ from the one in hand — at most two, "VS KNIFE" over them — so the choice needs no bag open and no table of figures (owner round 48i, 48l).
func _fill_compare(rows_node: LampRows, d: Dictionary, item_id: String, key_target: String, cabinet: bool) -> void:
	rows_node.visible = false
	rows_node.set_card({})
	if cabinet or key_target != "" or not d.get("is_weapon", false):
		return
	var inst := ItemInstance.new()
	inst.setup(item_id)
	var c: Dictionary = ItemCompare.card(inst, ItemCompare.held_weapon())
	if c.is_empty() or String(c["vs"]) == "":
		return
	var differing: Array = []
	for r in c["rows"]:
		if String(r["delta"]) != "":
			differing.append(r)
	if differing.is_empty():
		return
	rows_node.set_card({"rows": differing.slice(0, 2), "vs": c["vs"]})
	rows_node.visible = true


func _is_cabinet_anchor_weapon(apt: String, anchor: String, item_id: String) -> bool:
	return anchor == WorldState.GUN_CABINET_ANCHOR and item_id == WorldState.CABINET_WEAPON and WorldState.gun_cabinet_state(apt) in ["open", "smashed"]


## Kept for callers / tests that fill the result tag directly: the same numbers rule as `_fill_compare`.
func _show_compare(item_data: Dictionary) -> void:
	_fill_compare(compare_label, item_data, current_item_id, current_key_target, _is_cabinet_weapon())


## SEARCHING hangs a little above the node being searched (screen px, via the canvas transform — never current_scene), kept on the screen. If the node is somehow unknown it hangs over the
## player instead — never in the middle of the screen, away from anything.
func _place_word() -> void:
	var src: Node2D = anchor_node as Node2D if anchor_node != null and is_instance_valid(anchor_node) else null
	if src == null:
		src = get_tree().get_first_node_in_group("player") as Node2D
	var at := Vector2(SCREEN_W * 0.5, SCREEN_H * 0.3)
	if src != null:
		at = get_viewport().get_canvas_transform() * src.global_position - Vector2(0, WORD_RISE if src == anchor_node else WORD_RISE * 3.0)
	search_word.position = Vector2(clampf(at.x, 80.0, SCREEN_W - 80.0), clampf(at.y, 30.0, SCREEN_H - 90.0)) - search_word.size * 0.5


## Where the pack ring's centre sits while it shares the screen with the tag: `base` (above the kneeling player) when that already clears the tag, else pushed along the row to the side of the
## tag with room — right of it, or left — and, if neither has, up or down. The ring never covers the thing it was opened to make room for (owner round 36g / 48l).
func ring_centre(ring_half: float, base: Vector2) -> Vector2:
	if panel == null or not panel.visible:
		return base
	var r := Rect2(panel.position, panel.size).grow(RING_GAP)
	var nearest := Vector2(clampf(base.x, r.position.x, r.end.x), clampf(base.y, r.position.y, r.end.y))
	if nearest.distance_to(base) >= ring_half:
		return base
	for cx in [r.end.x + ring_half, r.position.x - ring_half]:
		if cx >= ring_half and cx <= SCREEN_W - ring_half:
			return Vector2(cx, base.y)
	for cy in [r.end.y + ring_half, r.position.y - ring_half]:
		if cy >= ring_half and cy <= SCREEN_H - ring_half:
			return Vector2(base.x, cy)
	return base


## A found item is waiting (nothing mid-search): the pack ring may open beside it to make room (owner round 36f).
func can_share_screen() -> bool:
	return visible and has_item and not is_revealing


func over_panel(pos: Vector2) -> bool:
	return visible and panel != null and panel.visible and panel.get_global_rect().has_point(pos)


## Is the pack ring up beside this panel?
func _pack_open() -> bool:
	return HUD.pack_wheel != null and is_instance_valid(HUD.pack_wheel) and HUD.pack_wheel.is_open


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_hide_preview()                 # a paused game shows no tag (a dialogue, the journal)


func _process(delta: float) -> void:
	if not visible:
		_update_preview()
		return
	_hide_preview()                      # the real tag (or the search) takes over from the preview
	panel.pivot_offset = panel.size * 0.5
	if panel.visible:
		_place_tag(panel, anchor_node)   # it follows the node as the camera moves

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
		search_word.set_progress(reveal_timer, reveal_time)
		var lit: int = search_word.lit_letters()
		if lit > _last_lit:                                                      # a very quiet tick as each letter comes on
			_last_lit = lit
			Ledger.play("tick", -29.0, 0.05)
		_place_word()
		if reveal_timer >= reveal_time:
			_reveal_item()
		return

	_update_drag()


# ---------------------------------------------------------------------------------------------------------------------------------- the preview: walking back up to a searched node
## The node whose tag should stand beside it right now: the nearest scavenge node in reach that was searched and still holds something. Nothing while the real tag / a search is up (`visible`), the
## pack ring is open, or the player is busy: the preview is only ever a glance, never a lock.
func preview_target() -> Node:
	if visible or WorldState.loot_open or not WorldState.is_scavenge_mode or get_tree().paused:
		return null
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player) or player.is_dead or player.is_dying or player.is_cutscene or player.is_switching_mode or str(player.pack_phase) != "":
		return null
	if _pack_open():
		return null
	var best: Node = null
	var best_d := 1.0e9
	for a in get_tree().get_nodes_in_group("scavenge_anchor"):
		if not is_instance_valid(a) or not a.visible or not bool(a.get("is_in_range")) or a.has_meta("ruin_scrap"):
			continue
		if not holds_takeable(a):
			continue
		var d: float = a.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


## A searched node that still holds something the player can take (a locked cabinet's gun is behind glass: not yet).
static func holds_takeable(a: Node) -> bool:
	var apt: String = String(a.get("apartment_id"))
	var nm: String = String(a.name)
	if not WorldState.is_anchor_searched(apt, nm):
		return false
	if WorldState.is_anchor_a_key(apt, nm):
		return true
	var item: String = WorldState.get_anchor_item(apt, nm)
	if item == "":
		return false
	if nm == WorldState.GUN_CABINET_ANCHOR:
		return WorldState.gun_cabinet_state(apt) in ["open", "smashed"]
	return true


func _update_preview() -> void:
	var want: Node = preview_target()
	if want == null:
		_hide_preview()
		return
	var apt: String = String(want.get("apartment_id"))
	var nm: String = String(want.name)
	var key_target := ""
	var item_id: String = WorldState.get_anchor_item(apt, nm)
	if WorldState.is_anchor_a_key(apt, nm):
		key_target = WorldState.get_anchor_key_target(apt, nm)
		item_id = WorldState.key_item_for(key_target)
	var sig := "%d|%s|%s|%d|%d" % [want.get_instance_id(), item_id, key_target, WorldState.get_anchor_amount(apt, nm), HUD.selected_slot]
	var tag: PanelContainer = _preview["panel"]
	if want != _preview_node or sig != _preview_sig or not tag.visible:
		var fresh: bool = want != _preview_node or not tag.visible
		_preview_node = want
		_preview_sig = sig
		_fill_tag(_preview, item_id, key_target, apt, nm)
		tag.visible = true
		tag.reset_size()
		if fresh:
			tag.pivot_offset = tag.size * 0.5
			tag.modulate.a = 0.0
			create_tween().tween_property(tag, "modulate:a", 1.0, 0.12)
	_place_tag(tag, want)


func _hide_preview() -> void:
	if _preview.is_empty():
		return
	_preview["panel"].visible = false
	_preview_node = null
	_preview_sig = ""


## Is the preview standing beside a node right now? (tests / the interactable)
func preview_showing_for(node: Node) -> bool:
	return not _preview.is_empty() and _preview["panel"].visible and _preview_node == node


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
			and not drag_active and not HUD.pointer_over_widget(event.position) and not over_panel(event.position):
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
		_say_full("Drag something off the ring (or onto this) to make room." if _pack_open() else "Open your pack and make room.")
		return false


## The pockets can't take it: the name turns red and the keys line says what to do (two words), with a knock.
func _say_full(_hint: String) -> void:
	name_label.text = "Inventory full"
	name_label.add_theme_color_override("font_color", Lamp.RED)
	hint_label.text = "MAKE ROOM"
	Ledger.play("deny", -12.0, 0.4)


## The found thing is in the pack now: the node is spent, the journal counts it, the panel closes.
func _finish_taken(cabinet: bool) -> void:
	if cabinet:
		WorldState.note_gun_cabinet_taken(current_apartment_id)
		get_tree().call_group("gun_cabinet_art", "refresh")
	WorldState.clear_anchor_item(current_apartment_id, current_anchor_name)
	WorldState.note_scavenge(current_apartment_id)   # journal stats: items + apartments looted
	get_tree().call_group("resident_npc", "on_scavenge", "take", current_apartment_id)
	HUD.refresh_inventory()
	Ledger.play("tick", -12.0)
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
		_say_full("Drag something off the ring (or onto this) to make room." if _pack_open() else "Open your pack and make room.")
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
	Ledger.play("tick", -14.0)
	hint_label.text = "MAKE ROOM"


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
	if not search_word.resolving:
		search_word.cancel()                 # a search walked away from: the word goes at once (one that finished is allowed its beat)
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
