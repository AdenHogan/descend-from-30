extends PanelContainer

# DEV MENU (F1) — one consolidated panel for all the dev/god-mode tools, so we're not
# juggling eight function keys (and never touch F8, which the Godot editor steals as
# "Stop" and closes the running game). Press F1 to open/close; the tree pauses while
# it's up. Toggles apply instantly; anything that needs a choice opens a sub-panel of
# buttons. Item-spawn (was F1) and floor-warp (was F6) are opened from here now.
# Gated by DEV_MODE — flip it off (with player.gd's) for release.

const DEV_MODE = true
const SCREEN_W = 1152.0
const SCREEN_H = 648.0

var _title: Label = null
var _list: VBoxContainer = null
var _in_sub: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # must work while the tree is paused
	visible = false
	custom_minimum_size = Vector2(300, 0)
	position = Vector2(SCREEN_W / 2 - 150, 90)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	_title = Label.new()
	_title.text = "DEV TOOLS"
	_title.add_theme_font_size_override("font_size", 16)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	root.add_child(_list)


func _input(event: InputEvent) -> void:
	if not DEV_MODE:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F1:
		if visible:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()
	elif visible and event.keycode == KEY_ESCAPE:
		if _in_sub:
			_show_main()               # a sub-panel: Esc goes back to the main list
		else:
			_close()
		get_viewport().set_input_as_handled()


func _open() -> void:
	visible = true
	get_tree().paused = true
	_show_main()


func _close() -> void:
	visible = false
	_in_sub = false
	get_tree().paused = false


func _btn(label: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	_list.add_child(b)


func _clear() -> void:
	# Remove from the tree NOW (so the panel never shows the old + new buttons together,
	# and counts are synchronous) but defer the actual free — _clear runs from inside a
	# button's own `pressed` callback, so freeing that button synchronously would be unsafe.
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _show_main() -> void:
	_in_sub = false
	_title.text = "DEV TOOLS  (F1)"
	_clear()
	var god_on: bool = WorldState.god_mode
	_btn("God Mode: %s" % ("ON" if god_on else "OFF"), _toggle_god)
	var stair_on: bool = WorldState.dev_force_stair_enemies
	_btn("Force Stair Enemies: %s" % ("ON" if stair_on else "OFF"), _toggle_stair_enemies)
	_btn("Set Health ▸", _sub_health)
	_btn("Set Run (time of day) ▸", _sub_run)
	_btn("Floor Hazard ▸", _sub_hazard)
	_btn("Wallet + 500 Bank Notes", _wallet)
	_btn("Toggle Tutorial (reloads Floor 30)", _tutorial)
	_btn("Warp to Floor…", _open_warp)
	_btn("Spawn Item…", _open_item)
	_btn("Close (F1)", _close)


func _show_sub(title: String, options: Array) -> void:
	_in_sub = true
	_title.text = title
	_clear()
	for opt in options:                # opt = [label, Callable]
		_btn(String(opt[0]), opt[1])
	_btn("◂ Back", _show_main)


# --- toggles (stay in the menu, refresh the label) ---------------------------
func _toggle_god() -> void:
	var p = _player()
	if p != null and p.has_method("dev_toggle_god"):
		p.dev_toggle_god()
	else:
		WorldState.god_mode = not WorldState.god_mode
	_show_main()


func _toggle_stair_enemies() -> void:
	WorldState.dev_force_stair_enemies = not WorldState.dev_force_stair_enemies
	_show_main()


func _wallet() -> void:
	var p = _player()
	if p != null and p.has_method("dev_wallet_cash"):
		p.dev_wallet_cash()


# --- sub-panels --------------------------------------------------------------
func _sub_health() -> void:
	var opts := []
	var names := ["HEALTHY", "HURT", "INJURED", "WOUNDED", "SEVERELY WOUNDED", "DYING"]
	for i in range(names.size()):
		var idx := i
		opts.append([names[i], func(): _set_health(idx)])
	_show_sub("SET HEALTH", opts)


func _set_health(idx: int) -> void:
	var p = _player()
	if p != null and p.has_method("dev_set_health_state"):
		p.dev_set_health_state(idx)
	_show_main()


func _sub_run() -> void:
	_show_sub("SET RUN", [
		["Run 1 — Morning", func(): _set_run(1)],
		["Run 2 — Afternoon", func(): _set_run(2)],
		["Run 3 — Night", func(): _set_run(3)],
	])


func _set_run(run: int) -> void:
	# Rebuilds the floor — close the menu (unpause) first so the deferred reload runs.
	_close()
	var p = _player()
	if p != null and p.has_method("dev_set_run"):
		p.dev_set_run(run)


func _sub_hazard() -> void:
	_show_sub("FLOOR HAZARD", [
		["Off (seed defaults)", func(): _set_hazard(WorldState.DEV_HAZARD_NONE)],
		["Barricade", func(): _set_hazard(WorldState.DEV_HAZARD_BARRICADE)],
		["Fire lv1 (LIGHT)", func(): _set_hazard(WorldState.DEV_HAZARD_FIRE)],
		["Fire lv2 (BLAZE)", func(): _set_hazard(WorldState.DEV_HAZARD_FIRE2)],
		["Fire lv3 (CHARRED)", func(): _set_hazard(WorldState.DEV_HAZARD_FIRE3)],
	])


func _set_hazard(mode: int) -> void:
	_close()                           # unpause so the floor rebuild runs
	var p = _player()
	if p != null and p.has_method("dev_apply_hazard"):
		p.dev_apply_hazard(mode)


func _tutorial() -> void:
	_close()
	var p = _player()
	if p != null and p.has_method("dev_toggle_tutorial"):
		p.dev_toggle_tutorial()


func _open_warp() -> void:
	_close()                           # hand pause over to the prompt
	var w = get_tree().get_first_node_in_group("dev_warp_prompt")
	if w != null and w.has_method("open"):
		w.open()


func _open_item() -> void:
	_close()
	var it = get_tree().get_first_node_in_group("dev_item_prompt")
	if it != null and it.has_method("open"):
		it.open()
