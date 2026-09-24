extends CanvasLayer

# THE WORKBENCH (docs/SCRAP_UPGRADES.md) — opened at a maintenance room's bench. Pauses the game
# (like the journal / shop), lists the weapons you carry that the bench can rework, and for the
# one you pick shows its perks so far, the cost of the next level (scrap + any spare copy it
# strips for parts) and the Hades-style PICK ONE OF TWO for that level. Confirm → the weapon
# levels up and keeps every perk it had. All rules/costs/perks live in WeaponUpgrades; the action
# itself is WorldState.upgrade_weapon. Built in code (no .tscn). Close: ✕, ESC, or Leave.

const W := 780.0
const H := 440.0
const INK := Color(0.93, 0.90, 0.84)
const DIM := Color(0.62, 0.60, 0.56)
const GOLD := Color(1.0, 0.82, 0.30)
const BAD := Color(0.95, 0.45, 0.38)
const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const FONT_BOLD := preload("res://assets/fonts/PixelOperator8-Bold.ttf")

var selected_slot: int = -1
var chosen_perk: String = ""
var _prev_paused := false

var _card: Panel = null
var _scrap_label: Label = null
var _list: VBoxContainer = null
var _detail: RichTextLabel = null
var _perk_box: HBoxContainer = null
var _cost_label: Label = null
var _upgrade_btn: Button = null
var _msg: Label = null


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_panel")      # Game._input closes a visible modal on ESC before the pause menu
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_card = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.11, 0.10, 0.97)
	sb.border_color = Color(0.55, 0.38, 0.22)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	_card.add_theme_stylebox_override("panel", sb)
	_card.size = Vector2(W, H)
	_card.position = Vector2((1152.0 - W) * 0.5, (648.0 - 120.0 - H) * 0.5 + 10.0)
	add_child(_card)

	var title := _label("WORKBENCH", 22, GOLD, FONT_BOLD)
	title.position = Vector2(24, 16)
	_card.add_child(title)
	_scrap_label = _label("", 14, INK)
	_scrap_label.position = Vector2(W - 260, 22)
	_scrap_label.size = Vector2(200, 20)
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card.add_child(_scrap_label)
	var x := Button.new()
	x.text = "✕"
	x.position = Vector2(W - 44, 12)
	x.size = Vector2(30, 30)
	x.pressed.connect(close)
	_card.add_child(x)

	var hint := _label("Your weapons", 12, DIM)
	hint.position = Vector2(24, 58)
	_card.add_child(hint)
	_list = VBoxContainer.new()
	_list.position = Vector2(24, 78)
	_list.size = Vector2(230, H - 110)
	_list.add_theme_constant_override("separation", 6)
	_card.add_child(_list)

	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = false
	_detail.scroll_active = false
	_detail.position = Vector2(276, 58)
	_detail.size = Vector2(W - 300, 120)
	_detail.add_theme_font_override("normal_font", FONT)
	_detail.add_theme_font_override("bold_font", FONT_BOLD)
	_detail.add_theme_font_size_override("normal_font_size", 13)
	_detail.add_theme_font_size_override("bold_font_size", 13)
	_detail.add_theme_color_override("default_color", INK)
	_card.add_child(_detail)

	_perk_box = HBoxContainer.new()
	_perk_box.position = Vector2(276, 186)
	_perk_box.size = Vector2(W - 300, 130)
	_perk_box.add_theme_constant_override("separation", 12)
	_card.add_child(_perk_box)

	_cost_label = _label("", 13, INK)
	_cost_label.position = Vector2(276, 326)
	_cost_label.size = Vector2(W - 300, 36)
	_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(_cost_label)

	_upgrade_btn = Button.new()
	_upgrade_btn.text = "Upgrade"
	_upgrade_btn.position = Vector2(W - 184, H - 56)
	_upgrade_btn.size = Vector2(160, 36)
	_upgrade_btn.pressed.connect(func(): confirm())
	_card.add_child(_upgrade_btn)
	var leave := Button.new()
	leave.text = "Leave"
	leave.position = Vector2(W - 300, H - 56)
	leave.size = Vector2(100, 36)
	leave.pressed.connect(close)
	_card.add_child(leave)
	_msg = _label("", 12, GOLD)
	_msg.position = Vector2(24, H - 46)
	_msg.size = Vector2(W - 340, 20)
	_card.add_child(_msg)
	visible = false


func _label(text: String, size: int, col: Color, font: Font = FONT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func open() -> void:
	_prev_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	selected_slot = -1
	chosen_perk = ""
	_msg.text = ""
	var slots := upgradable_slots()
	if not slots.is_empty():
		selected_slot = slots[0]
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _prev_paused


# Inventory slots holding a weapon the bench can rework (has a tree), in slot order.
func upgradable_slots() -> Array:
	var out := []
	for i in WorldState.inventory.size():
		if WeaponUpgrades.has_tree(WorldState.inventory[i].item_id):
			out.append(i)
	return out


func select_weapon(slot: int) -> void:
	selected_slot = slot
	chosen_perk = ""
	_msg.text = ""
	refresh()


func choose_perk(perk_id: String) -> void:
	chosen_perk = perk_id
	refresh()


# Apply the chosen upgrade. Returns "" on success, else why not (also shown on the card).
func confirm() -> String:
	if selected_slot < 0:
		return _say("Pick a weapon first.")
	if chosen_perk == "":
		return _say("Pick one of the two upgrades.")
	var inst = WorldState.get_instance_at(selected_slot)
	var name: String = inst.get_display_name() if inst != null else "It"
	var perk_name: String = WeaponUpgrades.perk(chosen_perk).get("name", chosen_perk)
	var err: String = WorldState.upgrade_weapon(selected_slot, chosen_perk)
	if err != "":
		return _say(err)
	# The feed copy may have sat BEFORE the target, shifting its slot — find it again.
	selected_slot = WorldState.inventory.find(inst)
	chosen_perk = ""
	_play_clank()
	refresh()
	_say("%s is now Lv%d — %s." % [name, inst.level, perk_name])
	return ""


func _say(t: String) -> String:
	if _msg != null:
		_msg.text = t
	return t


func refresh() -> void:
	_scrap_label.text = "SCRAP  %d" % WorldState.scrap
	for c in _list.get_children():
		c.queue_free()
	for c in _perk_box.get_children():
		c.queue_free()
	var slots := upgradable_slots()
	if slots.is_empty():
		_detail.text = "[color=#%s]Nothing here the bench can rework. Bring a [b]gun[/b] or a [b]hammer[/b].[/color]" % DIM.to_html(false)
		_cost_label.text = ""
		_upgrade_btn.disabled = true
		return
	for i in slots:
		var inst = WorldState.inventory[i]
		var b := Button.new()
		b.text = "%s   Lv%d" % [inst.get_display_name(), inst.level]
		b.toggle_mode = true
		b.button_pressed = i == selected_slot
		b.custom_minimum_size = Vector2(230, 34)
		b.pressed.connect(select_weapon.bind(i))
		_list.add_child(b)
	var inst = WorldState.get_instance_at(selected_slot) if selected_slot >= 0 else null
	if inst == null or not WeaponUpgrades.has_tree(inst.item_id):
		_detail.text = "Pick a weapon."
		_cost_label.text = ""
		_upgrade_btn.disabled = true
		return
	var txt := "[b]%s[/b]  —  Lv%d / %d" % [inst.get_display_name(), inst.level, WeaponUpgrades.MAX_LEVEL]
	if inst.perks.is_empty():
		txt += "\n[color=#%s]No upgrades yet.[/color]" % DIM.to_html(false)
	for p in inst.perks:
		var d: Dictionary = WeaponUpgrades.perk(p)
		txt += "\n[color=#%s]✔ %s[/color] — %s" % [GOLD.to_html(false), d.get("name", p), d.get("desc", "")]
	_detail.text = txt
	var choices: Array = WeaponUpgrades.next_choices(inst)
	if choices.is_empty():
		_cost_label.text = "Fully upgraded — nothing more the bench can do."
		_cost_label.add_theme_color_override("font_color", DIM)
		_upgrade_btn.disabled = true
		return
	for pid in choices:
		var d: Dictionary = WeaponUpgrades.perk(pid)
		var card := Button.new()
		card.toggle_mode = true
		card.button_pressed = pid == chosen_perk
		card.custom_minimum_size = Vector2((W - 312) * 0.5, 124)
		card.text = "%s\n\n%s" % [d.get("name", pid), d.get("desc", "")]
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_override("font", FONT)
		card.add_theme_font_size_override("font_size", 12)
		card.pressed.connect(choose_perk.bind(pid))
		_perk_box.add_child(card)
	var chk: Dictionary = WeaponUpgrades.check(inst, WorldState.inventory, WorldState.scrap)
	var cost := "Lv%d costs %d scrap" % [inst.level + 1, chk["scrap"]]
	if chk["feed_level"] > 0:
		cost += " + a spare Lv%d %s (stripped for parts)" % [chk["feed_level"], inst.get_display_name()]
	if not chk["ok"]:
		cost += "\n" + chk["reason"]
	_cost_label.text = cost
	_cost_label.add_theme_color_override("font_color", INK if chk["ok"] else BAD)
	_upgrade_btn.disabled = not chk["ok"] or chosen_perk == ""


func _play_clank() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = preload("res://assets/audio/doors/metalLatch.ogg")
	p.volume_db = -6.0
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
