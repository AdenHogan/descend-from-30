class_name GunChoice
extends PanelContainer

## "WHICH GUN?" for found bullets (owner round 49f: "when you take to load, you have the choice available of which gun to load"). The found-item tag in loot_ui has its own copy of this
## question for a scavenge node; this is the same question for a BULLET PICKUP LYING ON THE FLOOR (world_drop.gd): the pockets cannot take the bundle and two or more guns carried
## could, so the first gun no longer takes them without asking. A small dark-glass panel hangs over the drop, one row a gun (the one in hand first) — the number key or a click loads it;
## Esc / the use key / a click anywhere else puts it away and nothing is taken. It only ASKS: the caller loads the gun it is told about (`chosen`).

signal chosen(gun)
signal closed

const MAX_ROWS := 3

var guns: Array = []
var _at_world := Vector2.ZERO
var _rows: Array = []


## The row's words — one source for both places that ask (loot_ui builds its rows from this too).
static func row_text(i: int, g) -> String:
	var tier: String = g.tier_tag()
	return "%d   %s%s   %d / %d" % [i + 1, g.get_display_name(), ("  " + tier) if tier != "" else "", g.mag_count, g.get_mag_cap()]


## Ask over the world point `at_world`. Returns the panel (null when there is nothing to ask — fewer than two guns — or no HUD to hang it on).
static func ask(candidates: Array, at_world: Vector2) -> GunChoice:
	if candidates.size() < 2 or HUD == null or not HUD.has_node("Control"):
		return null
	var c := GunChoice.new()
	c.guns = candidates.slice(0, MAX_ROWS)
	c._at_world = at_world
	HUD.get_node("Control").add_child(c)
	return c


func _ready() -> void:
	name = "GunChoice"
	add_to_group("hud_widget_extra")                       # a click on it is never a click in the world (HUD.pointer_over_widget)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var glass := LampGlass.new()
	add_child(glass)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	add_child(pad)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	pad.add_child(box)
	box.add_child(_label("WHICH GUN?", "head", Lamp.PX_LABEL, Lamp.BRASS))
	for i in range(guns.size()):
		var row := _label(row_text(i, guns[i]), "body", Lamp.PX_BODY, Lamp.TEXT)
		row.name = "Gun%d" % (i + 1)
		box.add_child(row)
		_rows.append(row)
	z_index = 20
	_place()
	call_deferred("_place")                                # the labels' real size settles a frame later
	Ledger.play("tick", -14.0)


func _label(text: String, kind: String, px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Lamp.font(kind))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	return l


func _process(_delta: float) -> void:
	_place()


func _place() -> void:
	reset_size()
	var p: Vector2 = get_viewport().get_canvas_transform() * (_at_world + Vector2(0, -34))
	position = Vector2(clampf(p.x - size.x * 0.5, 8.0, HUD.SCREEN_W - size.x - 8.0), clampf(p.y - size.y, 8.0, HUD.SCREEN_H - size.y - 8.0))


func row_at(pos: Vector2) -> int:
	for i in range(_rows.size()):
		var r: Control = _rows[i]
		if is_instance_valid(r) and r.get_global_rect().grow(4.0).has_point(pos):
			return i
	return -1


## Pick gun `i` (0-based): the caller is told, the panel goes.
func choose(i: int) -> void:
	if i < 0 or i >= guns.size():
		return
	var g = guns[i]
	close(false)
	if is_instance_valid(g):
		chosen.emit(g)


func close(announce := true) -> void:
	if is_queued_for_deletion():
		return
	remove_from_group("hud_widget_extra")
	queue_free()
	if announce:
		closed.emit()


func _input(event: InputEvent) -> void:
	if is_queued_for_deletion():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = int(event.keycode) - int(KEY_1)
		if k >= 0 and k < guns.size():
			get_viewport().set_input_as_handled()
			choose(k)
			return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("item_use"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var row := row_at(event.position)
		get_viewport().set_input_as_handled()                # the click that answers (or dismisses) the question is spent on it
		if row >= 0:
			choose(row)
		else:
			close()
