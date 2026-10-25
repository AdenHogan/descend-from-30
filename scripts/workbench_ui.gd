extends CanvasLayer

# THE WORKBENCH (docs/SCRAP_UPGRADES.md) — opened at a maintenance room's bench. Pauses the game
# (like the journal / shop). Three tabs share one list of the weapons you carry:
#   UPGRADE — the next level: what it COSTS (scrap + any spare stripped for parts) and what it GIVES.
#             Lv2 is the plain first step (REINFORCED: nothing to choose); from Lv3 a weapon picks one of
#             two upgrades and earns tuning points. Past Legendary (Lv5) it's the HEIRLOOM forge:
#             scrap put in by instalments (it rides the weapon) and a door-crossing requirement.
#   TUNE    — spend the weapon's tuning points on its own stat sheet (stage with − / +, then "Set in
#             steel" — points, once set, are set). A legendary weapon can be renamed here.
#   SALVAGE — break carried items down for scrap (values in Salvage, action WorldState.salvage_item).
# All rules/costs/perks/stats live in WeaponUpgrades; the actions are WorldState.upgrade_weapon /
# tune_weapon / forge_heirloom / rename_weapon. Built in code (no .tscn). Close: ×, ESC, or Leave.
# LEDGER look (owner round 48j; scripts/ledger.gd): the bench is a sheet of ruled paper — the weapon list left of the red margin rule, the page right of it; the two choices are
# slips (ticked when chosen), tuning ranks are tally boxes, the player's notes are in their own hand. Same logic as before: every action below is unchanged.

const W := 820.0
const H := 480.0
const INK := Ledger.INK                       # inks on paper (these are also the bbcode colours)
const DIM := Ledger.INK_SOFT
const GOLD := Ledger.BLUE_INK                 # what the pen underlines: names, points
const BAD := Ledger.RED_INK
const GOOD := Ledger.GREEN_INK
const LEGEND := Ledger.GOLD_INK
const TEXT_SCALE := 1.22                      # the old sizes were set for a pixel font; Barlow at the same number reads smaller
const HEAD_SCALE := 1.38
const FORGE_STEP := 25                 # "Put in 25" at the heirloom forge
const RIGHT_X := 290.0
# The tune grid's columns (name | pips | - | + | effect) must add up, with the 4 gaps of 8, to no more than the right pane (W - RIGHT_X - 24 = 506) - tests/weapon_upgrade_test checks it.
const TUNE_NAME_W := 84.0
const TUNE_PIPS_W := 112.0
const TUNE_DESC_W := 222.0

var selected_slot: int = -1
var chosen_perk: String = ""
var staged: Dictionary = {}            # TUNE: {stat id: ranks staged but not yet set}
var _prev_paused := false

var _card: LedgerSheet = null
var _backdrop: TextureRect = null
var _scrap_label: Label = null
var _list: VBoxContainer = null
var _list_hint: Label = null
var _detail: RichTextLabel = null
var _perk_box: HBoxContainer = null
var _forge_box: VBoxContainer = null
var _cost_label: RichTextLabel = null
var _upgrade_btn: Button = null
var _msg: Label = null
var tab := "upgrade"                 # "upgrade" | "tune" | "salvage"
var _upgrade_page: Control = null
var _tune_page: Control = null
var _salvage_page: Control = null
var _salvage_grid: GridContainer = null
var _tune_col: VBoxContainer = null
var _tune_head: RichTextLabel = null
var _tune_explain: RichTextLabel = null
var _tune_grid: GridContainer = null
var _points_label: Label = null
var _set_btn: Button = null
var _name_row: HBoxContainer = null
var _name_edit: LineEdit = null
var _tab_up: Button = null
var _tab_tune: Button = null
var _tab_salv: Button = null
var _confirm_salvage: Object = null  # the item whose Break down was pressed once (confirm)


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_panel")      # Game._input closes a visible modal on ESC before the pause menu
	_backdrop = _make_backdrop()
	add_child(_backdrop)
	_card = LedgerSheet.new()
	_card.seed_value = 44
	_card.size = Vector2(W, H)
	_card.position = Vector2((1152.0 - W) * 0.5, maxf(8.0, (648.0 - H) * 0.5))
	_card.rule_first = 84.0
	_card.margin_x = 280.0
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)

	var title := _label("WORKBENCH", 22, INK, Ledger.font("head"))
	title.position = Vector2(24, 10)
	_card.add_child(title)
	_scrap_label = _label("", 22, Ledger.hand_ink(), Ledger.font("hand"))
	_scrap_label.position = Vector2(W - 250, 8)
	_scrap_label.size = Vector2(190, 40)
	_scrap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card.add_child(_scrap_label)
	var x := LedgerButton.new()
	x.text = "×"
	x.px = 24
	x.seed_value = 12
	x.position = Vector2(W - 46, 12)
	x.size = Vector2(32, 32)
	x.custom_minimum_size = Vector2(32, 32)
	x.pressed.connect(close)
	_card.add_child(x)

	_tab_up = _tab_button("UPGRADE", Vector2(236, 12))
	_tab_up.pressed.connect(func(): show_tab("upgrade"))
	_tab_tune = _tab_button("TUNE", Vector2(358, 12))
	_tab_tune.pressed.connect(func(): show_tab("tune"))
	_tab_salv = _tab_button("SALVAGE", Vector2(480, 12))
	_tab_salv.pressed.connect(func(): show_tab("salvage"))

	# The weapon list (shared by Upgrade + Tune).
	_list_hint = _label("YOUR WEAPONS", 12, DIM, Ledger.font("head"))
	_list_hint.position = Vector2(24, 62)
	_card.add_child(_list_hint)
	_list = VBoxContainer.new()
	_list.position = Vector2(24, 80)
	_list.size = Vector2(250, H - 150)
	_list.add_theme_constant_override("separation", 6)
	_card.add_child(_list)

	_upgrade_page = _page()
	_tune_page = _page()
	_salvage_page = _page()
	_build_upgrade_page()
	_build_tune_page()
	_build_salvage_page()

	var leave := LedgerButton.new()
	leave.text = "LEAVE"
	leave.seed_value = 33
	leave.position = Vector2(W - 322, H - 52)
	leave.size = Vector2(112, 38)
	leave.custom_minimum_size = Vector2(112, 38)
	leave.pressed.connect(close)
	_card.add_child(leave)
	_msg = _label("", 12, Ledger.hand_ink(), Ledger.font("hand"))
	_msg.position = Vector2(24, H - 50)
	_msg.size = Vector2(W - 360, 40)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(_msg)
	visible = false


## The room dims round the page — a vignette that keeps the middle of the screen the world. It also stops clicks: the game is paused while the bench is open.
func _make_backdrop() -> TextureRect:
	var t := TextureRect.new()
	t.name = "Backdrop"
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.18), Color(0, 0, 0, 0.40), Color(0.02, 0.012, 0.008, 0.78)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 1.0)
	gt.width = 256
	gt.height = 144
	t.texture = gt
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	return t


func _px(n: int, head: bool = false) -> int:
	return int(round(n * (HEAD_SCALE if head else TEXT_SCALE)))


func _page() -> Control:
	var c := Control.new()
	c.size = Vector2(W, H)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(c)
	return c


func _rich(pos: Vector2, size: Vector2) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = false
	r.scroll_active = false
	r.position = pos
	r.size = size
	r.add_theme_font_override("normal_font", Ledger.font("body"))
	r.add_theme_font_override("bold_font", Ledger.font("head"))
	r.add_theme_font_size_override("normal_font_size", _px(12))
	r.add_theme_font_size_override("bold_font_size", _px(13, true))
	r.add_theme_color_override("default_color", INK)
	return r


## A rich-text block for a VBox: it wraps at `w` and is exactly as tall as its text.
func _flow_rich(w: float) -> RichTextLabel:
	var r := _rich(Vector2.ZERO, Vector2(w, 20))
	r.fit_content = true
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(w, 18)
	return r


func _build_upgrade_page() -> void:
	_detail = _rich(Vector2(RIGHT_X, 60), Vector2(W - RIGHT_X - 24, 118))
	_upgrade_page.add_child(_detail)
	_perk_box = HBoxContainer.new()
	_perk_box.position = Vector2(RIGHT_X, 184)
	_perk_box.size = Vector2(W - RIGHT_X - 24, 130)
	_perk_box.add_theme_constant_override("separation", 12)
	_upgrade_page.add_child(_perk_box)
	_forge_box = VBoxContainer.new()
	_forge_box.position = Vector2(RIGHT_X, 184)
	_forge_box.size = Vector2(W - RIGHT_X - 24, 130)
	_forge_box.add_theme_constant_override("separation", 8)
	_upgrade_page.add_child(_forge_box)
	_cost_label = _rich(Vector2(RIGHT_X, 324), Vector2(W - RIGHT_X - 24, 70))
	_cost_label.add_theme_font_size_override("normal_font_size", 13)
	_cost_label.add_theme_font_size_override("bold_font_size", _px(13, true))
	_upgrade_page.add_child(_cost_label)
	_upgrade_btn = LedgerButton.new()
	_upgrade_btn.text = "UPGRADE"
	_upgrade_btn.solid = true
	_upgrade_btn.seed_value = 36
	_upgrade_btn.position = Vector2(W - 194, H - 52)
	_upgrade_btn.size = Vector2(170, 38)
	_upgrade_btn.custom_minimum_size = Vector2(170, 38)
	_upgrade_btn.pressed.connect(func(): confirm())
	_upgrade_page.add_child(_upgrade_btn)


func _build_tune_page() -> void:
	# ONE column lays the page out top to bottom (each block takes the height its text needs), so nothing can sit on top of anything else.
	var col_w: float = W - RIGHT_X - 24
	_tune_col = VBoxContainer.new()
	_tune_col.position = Vector2(RIGHT_X, 56)
	_tune_col.size = Vector2(col_w, H - 160)
	_tune_col.add_theme_constant_override("separation", 6)
	_tune_page.add_child(_tune_col)
	_tune_head = _flow_rich(col_w)
	_tune_col.add_child(_tune_head)
	_tune_explain = _flow_rich(col_w)
	_tune_explain.add_theme_font_size_override("normal_font_size", _px(11))
	_tune_explain.add_theme_color_override("default_color", DIM)
	_tune_col.add_child(_tune_explain)
	_points_label = _label("", 13, GOLD, Ledger.font("head"))
	_points_label.custom_minimum_size = Vector2(col_w, 20)
	_points_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tune_col.add_child(_points_label)
	_tune_grid = GridContainer.new()
	_tune_grid.columns = 5                 # name | pips | − | + | what a rank does
	_tune_grid.add_theme_constant_override("h_separation", 8)
	_tune_grid.add_theme_constant_override("v_separation", 4)
	_tune_col.add_child(_tune_grid)
	_name_row = HBoxContainer.new()
	_name_row.position = Vector2(RIGHT_X, H - 96)
	_name_row.add_theme_constant_override("separation", 8)
	_tune_page.add_child(_name_row)
	var nl := _label("ITS NAME", 12, LEGEND, Ledger.font("head"))
	_name_row.add_child(nl)
	_name_edit = LineEdit.new()                      # written in the player's hand on a ruled line
	_name_edit.max_length = WeaponUpgrades.TITLE_MAX_LEN
	_name_edit.custom_minimum_size = Vector2(220, 32)
	_name_edit.add_theme_font_override("font", Ledger.font("hand"))
	_name_edit.add_theme_font_size_override("font_size", int(round(14 * Ledger.hand_scale())))
	_name_edit.add_theme_color_override("font_color", Ledger.hand_ink())
	_name_edit.add_theme_color_override("caret_color", Ledger.hand_ink())
	var line := StyleBoxFlat.new()
	line.bg_color = Color(0, 0, 0, 0)
	line.border_color = Ledger.INK_SOFT
	line.border_width_bottom = 2
	line.content_margin_left = 4
	_name_edit.add_theme_stylebox_override("normal", line)
	_name_edit.add_theme_stylebox_override("focus", line)
	_name_edit.text_submitted.connect(func(t): rename(t))
	_name_row.add_child(_name_edit)
	var nb := LedgerButton.new()
	nb.text = "RENAME"
	nb.px = 16
	nb.seed_value = 37
	nb.custom_minimum_size = Vector2(100, 32)
	nb.pressed.connect(func(): rename(_name_edit.text))
	_name_row.add_child(nb)
	_set_btn = LedgerButton.new()
	_set_btn.text = "SET IN STEEL"
	_set_btn.solid = true
	_set_btn.seed_value = 38
	_set_btn.position = Vector2(W - 194, H - 52)
	_set_btn.size = Vector2(170, 38)
	_set_btn.custom_minimum_size = Vector2(170, 38)
	_set_btn.pressed.connect(func(): set_tuning())
	_tune_page.add_child(_set_btn)


func _build_salvage_page() -> void:
	var shint := _label("Break things down for scrap. Junk is worth a little; worn items give less.", 12, DIM)
	shint.position = Vector2(24, 62)
	_salvage_page.add_child(shint)
	_salvage_grid = GridContainer.new()
	_salvage_grid.columns = 3
	_salvage_grid.position = Vector2(24, 88)
	_salvage_grid.add_theme_constant_override("h_separation", 16)
	_salvage_grid.add_theme_constant_override("v_separation", 6)
	_salvage_page.add_child(_salvage_grid)


func _tab_button(text: String, pos: Vector2) -> Button:
	var b := LedgerButton.new()
	b.text = text
	b.px = 17
	b.seed_value = 50 + int(pos.x) % 7
	b.position = pos
	b.size = Vector2(112, 32)
	b.custom_minimum_size = Vector2(112, 32)
	b.toggle_mode = true
	_card.add_child(b)
	return b


func show_tab(which: String) -> void:
	tab = which
	_confirm_salvage = null
	staged = {}
	_msg.text = ""
	refresh()


func _label(text: String, size: int, col: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	var f: Font = font if font != null else Ledger.font("body")
	var head: bool = f == Ledger.font("head")
	var hand: bool = font != null and not head and f != Ledger.font("body") and f != Ledger.font("typed")
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", int(round(size * (Ledger.hand_scale() * 1.1 if hand else (HEAD_SCALE if head else TEXT_SCALE)))))
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func open() -> void:
	_prev_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	_arrive()
	selected_slot = -1
	chosen_perk = ""
	staged = {}
	_msg.text = ""
	tab = "upgrade"
	_confirm_salvage = null
	var slots := upgradable_slots()
	if not slots.is_empty():
		selected_slot = slots[0]
	refresh()


## The sheet is set down on the bench: it settles a few px and the room dims behind it.
func _arrive() -> void:
	Ledger.play("sheet", -7.0)
	var base_y := maxf(8.0, (648.0 - H) * 0.5)
	_card.position.y = base_y + 14.0
	_card.modulate.a = 0.0
	_backdrop.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_card, "position:y", base_y, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_card, "modulate:a", 1.0, 0.18)
	t.tween_property(_backdrop, "modulate:a", 1.0, 0.30)


func close() -> void:
	if not visible:
		return
	Ledger.play("page", -12.0)
	visible = false
	get_tree().paused = _prev_paused


# Inventory slots holding a weapon the bench can rework, in slot order.
func upgradable_slots() -> Array:
	var out := []
	for i in WorldState.inventory.size():
		if WeaponUpgrades.can_upgrade(WorldState.inventory[i].item_id):
			out.append(i)
	return out


func select_weapon(slot: int) -> void:
	selected_slot = slot
	chosen_perk = ""
	staged = {}
	_msg.text = ""
	refresh()


func choose_perk(perk_id: String) -> void:
	chosen_perk = perk_id
	refresh()


func _selected():
	return WorldState.get_instance_at(selected_slot) if selected_slot >= 0 else null


# Apply the next level. Returns "" on success, else why not (also shown on the card).
func confirm() -> String:
	if selected_slot < 0:
		return _say("Pick a weapon first.")
	var inst = _selected()
	if inst == null:
		return _say("Pick a weapon first.")
	var choices: Array = WeaponUpgrades.next_choices(inst)
	if not choices.is_empty() and chosen_perk == "":
		return _say("Pick one of the two upgrades.")
	var was_titled: bool = inst.title != ""
	var err: String = WorldState.upgrade_weapon(selected_slot, chosen_perk)
	if err != "":
		return _say(err)
	# The feed copy may have sat BEFORE the target, shifting its slot — find it again.
	selected_slot = WorldState.inventory.find(inst)
	var perk_name: String = String(WeaponUpgrades.perk(chosen_perk).get("name", "")) if chosen_perk != "" else ""
	chosen_perk = ""
	_play_clank()
	refresh()
	var pts := "you got %d tuning points to spend on the Tune tab" % WeaponUpgrades.POINTS_PER_LEVEL
	if inst.level == WeaponUpgrades.REINFORCE_LEVEL:
		pts = "tougher and harder-hitting. The next upgrade gives you a pick of two and your first tuning points"
	if not was_titled and inst.title != "":
		_say("LEGENDARY. It has earned a name: \"%s\" (rename it on the Tune tab) - %s." % [inst.title, pts])
	else:
		_say("%s is now %s%s - %s." % [inst.get_display_name(), WeaponUpgrades.tier_name(inst.level),
			(" (" + perk_name + ")") if perk_name != "" and inst.level != WeaponUpgrades.REINFORCE_LEVEL else "", pts])
	return ""


# HEIRLOOM: put up to `amount` scrap into the selected legendary weapon's next tier.
func forge(amount: int) -> String:
	var inst = _selected()
	if inst == null:
		return _say("Pick a weapon first.")
	var before: int = inst.level
	var paid_before: int = inst.forge_paid
	var err: String = WorldState.forge_heirloom(selected_slot, amount)
	if err != "":
		return _say(err)
	_play_clank()
	refresh()
	if inst.level > before:
		_say("%s is now %s. Every stat can go one higher." % [inst.get_display_name(), WeaponUpgrades.tier_name(inst.level)])
	else:
		_say("Put %d scrap into it. It's in the weapon now — it goes where the weapon goes." % (inst.forge_paid - paid_before))
	return ""


# --- TUNE ------------------------------------------------------------------------------
func stage_point(stat_id: String, delta: int) -> void:
	var inst = _selected()
	if inst == null:
		return
	var n: int = maxi(0, int(staged.get(stat_id, 0)) + delta)
	var trial := staged.duplicate()
	trial[stat_id] = n
	if delta > 0 and WeaponUpgrades.tuning_error(inst, trial) != "":
		_say(WeaponUpgrades.tuning_error(inst, trial))
		return
	staged = trial
	_msg.text = ""
	refresh()


func set_tuning() -> String:
	var inst = _selected()
	if inst == null:
		return _say("Pick a weapon first.")
	var err: String = WorldState.tune_weapon(selected_slot, staged)
	if err != "":
		return _say(err)
	staged = {}
	_play_clank()
	refresh()
	return _say_ok("Set in steel. It's yours.")


func rename(text: String) -> String:
	var err: String = WorldState.rename_weapon(selected_slot, text)
	if err != "":
		return _say(err)
	refresh()
	return _say_ok("It answers to \"%s\" now." % _selected().title)


func _say(t: String) -> String:
	if _msg != null:
		_msg.text = t
	return t


# A success line: shown, but the action still reports "" (success) to its caller.
func _say_ok(t: String) -> String:
	_say(t)
	return ""


func refresh() -> void:
	_scrap_label.text = "SCRAP  %d" % WorldState.scrap
	_scrap_label.add_theme_font_override("font", Ledger.font("hand"))       # the hand follows the run's character
	_scrap_label.add_theme_color_override("font_color", Ledger.hand_ink())
	_msg.add_theme_font_override("font", Ledger.font("hand"))
	_msg.add_theme_color_override("font_color", Ledger.hand_ink())
	_tab_up.button_pressed = tab == "upgrade"
	_tab_tune.button_pressed = tab == "tune"
	_tab_salv.button_pressed = tab == "salvage"
	_upgrade_page.visible = tab == "upgrade"
	_tune_page.visible = tab == "tune"
	_salvage_page.visible = tab == "salvage"
	_list.visible = tab != "salvage"
	_list_hint.visible = tab != "salvage"
	if tab == "salvage":
		_refresh_salvage()
		return
	_refresh_list()
	if tab == "tune":
		_refresh_tune()
	else:
		_refresh_upgrade()


func _refresh_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for i in upgradable_slots():
		var inst = WorldState.inventory[i]
		var b := LedgerButton.new()
		var tag: String = inst.tier_tag()
		var pts: int = WeaponUpgrades.points_free(inst)
		b.text = "%s%s%s" % [inst.get_display_name(), ("   " + tag) if tag != "" else "", ("  · %d pt%s" % [pts, "" if pts == 1 else "s"]) if pts > 0 else ""]
		b.toggle_mode = true
		b.button_pressed = i == selected_slot
		b.align_left = true
		b.px = 16
		b.seed_value = 80 + i
		b.custom_minimum_size = Vector2(250, 36)
		if inst.level >= WeaponUpgrades.LEGENDARY_LEVEL:
			b.ink = LEGEND
		b.pressed.connect(select_weapon.bind(i))
		_list.add_child(b)


func _header_bbcode(inst) -> String:
	var col: Color = LEGEND if inst.level >= WeaponUpgrades.LEGENDARY_LEVEL else INK
	var txt := "[b][color=#%s]%s[/color][/b]  —  %s" % [col.to_html(false), inst.get_display_name(),
		WeaponUpgrades.tier_name(inst.level) if inst.level > 1 else "Lv1"]
	if inst.forged_by != "":
		var parts: PackedStringArray = inst.forged_by.split(":")
		var who: String = WorldState.character_display_name(parts[0])
		var run: int = int(parts[1]) if parts.size() > 1 else 0
		txt += "\n[color=#%s]Forged by %s, %s%s.[/color]" % [DIM.to_html(false), who,
			WorldState.run_name(run).to_lower() if run > 0 else "", (" · crossed the door %d×" % inst.crossings) if inst.crossings > 0 else ""]
	return txt


func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _refresh_upgrade() -> void:
	_clear(_perk_box)
	_clear(_forge_box)
	_upgrade_btn.visible = true
	var slots := upgradable_slots()
	if slots.is_empty():
		_detail.text = "[color=#%s]Nothing here the bench can rework. Bring a weapon — a gun, a blade, a bat or a hammer.[/color]" % DIM.to_html(false)
		_set_cost("")
		_upgrade_btn.disabled = true
		return
	var inst = _selected()
	if inst == null or not WeaponUpgrades.can_upgrade(inst.item_id):
		_detail.text = "Pick a weapon."
		_set_cost("")
		_upgrade_btn.disabled = true
		return
	var txt := _header_bbcode(inst)
	if inst.perks.is_empty():
		txt += "\n[color=#%s]No perks yet.[/color]" % DIM.to_html(false)
	var compact: bool = inst.perks.size() > 2      # a long list: names (+ live chance) only, so it fits
	var parts: PackedStringArray = []
	for p in inst.perks:
		var d: Dictionary = WeaponUpgrades.perk(p)
		var col: Color = LEGEND if WeaponUpgrades.is_mod(p) else GOLD
		if compact:
			var pct := ""
			if WeaponUpgrades.mod_chance(inst, p) > 0.0 and WeaponUpgrades.mod_chance(inst, p) < 1.0:
				pct = " %d%%" % int(round(WeaponUpgrades.mod_chance(inst, p) * 100.0))
			parts.append("[color=#%s]✔ %s%s[/color]" % [col.to_html(false), d.get("name", p), pct])
		else:
			txt += "\n[color=#%s]✔ %s[/color] — %s" % [col.to_html(false), d.get("name", p), WeaponUpgrades.describe(inst, p)]
	if compact:
		txt += "\n" + "   ".join(parts)
	_detail.text = txt
	if inst.level >= WeaponUpgrades.MAX_LEVEL:
		_set_cost("[color=#%s]Legendary +++. There is nothing more the bench can do — only you.[/color]" % LEGEND.to_html(false))
		_upgrade_btn.disabled = true
		return
	var chk: Dictionary = WeaponUpgrades.check(inst, WorldState.inventory, WorldState.scrap)
	if chk["heirloom"] and not chk["ok"]:
		_refresh_forge(inst, chk)
		return
	var choices: Array = WeaponUpgrades.next_choices(inst)
	var k := 0
	for pid in choices:
		_perk_box.add_child(_perk_slip(inst, pid, k))
		k += 1
	if choices.is_empty():
		var msg := "It already has every special the bench knows — this level gives it %d more tuning points." % WeaponUpgrades.POINTS_PER_LEVEL
		var ink := DIM
		if WeaponUpgrades.is_plain_step(inst.level + 1):
			var rd: Dictionary = WeaponUpgrades.perk(WeaponUpgrades.auto_perk(inst.item_id, inst.level + 1))
			msg = "REINFORCE\n\n%s\n\nNothing to choose: the first step is the same for every weapon, and cheap - a taste of what the bench can do. From Lv%d each upgrade lets you pick one of two specials and earns %d tuning points to spend on the Tune tab." % [
				rd.get("desc", ""), WeaponUpgrades.REINFORCE_LEVEL + 1, WeaponUpgrades.POINTS_PER_LEVEL]
			ink = INK
		var l := _label(msg, 12, ink)
		l.custom_minimum_size = Vector2(W - RIGHT_X - 24, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_perk_box.add_child(l)
	var to: int = inst.level + 1
	# TWO plain lines, never mixed: what it COSTS (scrap, a spare) and what it GIVES. ("+2 tuning points" beside the price once read as a
	# second thing to pay - owner round 48i: "it says you need 50 scrap and 2 tuning points, but tuning needs an upgrade first".)
	var costs := "%d scrap" % chk["scrap"]
	if chk["heirloom"]:
		costs = "paid in full, and carried through the door"
	if chk["feed_level"] > 0:
		costs += "  +  %s (stripped for parts)" % WeaponUpgrades.feed_label(inst, chk["feed_level"])
	var cost := "[b][color=#%s]COSTS[/color][/b]  %s\n[b][color=#%s]GIVES[/color][/b]  %s" % [BAD.to_html(false), costs, GOOD.to_html(false), WeaponUpgrades.gives_text(inst)]
	if not chk["ok"]:
		cost += "\n[color=#%s]%s[/color]" % [BAD.to_html(false), chk["reason"]]
	_set_cost(cost)
	_upgrade_btn.text = "TEMPER" if chk["heirloom"] else ("REINFORCE" if to == WeaponUpgrades.REINFORCE_LEVEL else "UPGRADE")
	_upgrade_btn.visible = true
	_upgrade_btn.disabled = not chk["ok"] or (not choices.is_empty() and chosen_perk == "")


## One of the two upgrades on offer: a slip taped to the page. Click it to tick it (it stays lifted, with a pen tick in its corner); click the other and the tick moves.
func _perk_slip(inst, pid: String, index: int) -> Control:
	var d: Dictionary = WeaponUpgrades.perk(pid)
	var special: bool = WeaponUpgrades.is_mod(pid)
	var slip := LedgerSlip.new()
	slip.name = "Slip_" + pid
	slip.seed_value = 300 + index * 19 + pid.hash() % 40
	slip.tilt_deg = [-0.6, 0.5][index % 2]
	slip.margin = 12
	slip.custom_minimum_size = Vector2((W - RIGHT_X - 36) * 0.5, 130)
	slip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	slip.content.add_child(box)
	box.add_child(_label("A SPECIAL" if special else "AN UPGRADE", 11, LEGEND if special else DIM, Ledger.font("head")))
	var nm := _label(String(d.get("name", pid)), 17, INK, Ledger.font("head"))
	box.add_child(nm)
	slip.underline_target = nm
	var ds := _label(WeaponUpgrades.describe(inst, pid), 12, INK)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(slip.custom_minimum_size.x - 2.0 * slip.margin - 6.0, 0)
	ds.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(ds)
	slip.held = pid == chosen_perk
	var hit := Button.new()                           # the whole slip is the click target
	hit.flat = true
	hit.focus_mode = Control.FOCUS_ALL
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for sb in ["normal", "hover", "pressed", "focus", "disabled"]:
		hit.add_theme_stylebox_override(sb, StyleBoxEmpty.new())
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.pressed.connect(choose_perk.bind(pid))
	slip.add_child(hit)
	return slip


func _set_cost(bbcode: String) -> void:
	_cost_label.text = bbcode


# The heirloom forge: instalments + the crossing requirement.
func _refresh_forge(inst, _chk: Dictionary) -> void:
	var to: int = inst.level + 1
	var need: Dictionary = WeaponUpgrades.HEIRLOOM[to]
	var total: int = int(need["scrap"])
	var head := _label("THE HEIRLOOM FORGE — %s" % WeaponUpgrades.tier_name(to), 13, LEGEND, Ledger.font("head"))
	_forge_box.add_child(head)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = total
	bar.value = mini(inst.forge_paid, total)
	bar.custom_minimum_size = Vector2(W - RIGHT_X - 24, 18)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(LEGEND.r, LEGEND.g, LEGEND.b, 0.85)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.45, 0.36, 0.22, 0.18)
	back.border_color = Ledger.INK_SOFT
	back.set_border_width_all(1)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	_forge_box.add_child(bar)
	var info := _label("Scrap put in: %d / %d      Crossed the lobby door: %d / %d" % [inst.forge_paid, total, inst.crossings, int(need["crossings"])], 12, INK)
	_forge_box.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_forge_box.add_child(row)
	var owed: int = total - inst.forge_paid
	var b1 := LedgerButton.new()
	b1.custom_minimum_size = Vector2(150, 34)
	b1.px = 17
	b1.text = "PUT IN %d" % mini(FORGE_STEP, maxi(owed, 0))
	b1.disabled = owed <= 0 or WorldState.scrap <= 0
	b1.pressed.connect(forge.bind(FORGE_STEP))
	row.add_child(b1)
	var b2 := LedgerButton.new()
	b2.custom_minimum_size = Vector2(230, 34)
	b2.px = 17
	b2.seed_value = 9
	b2.text = "PUT IN ALL I CAN (%d)" % mini(WorldState.scrap, maxi(owed, 0))
	b2.disabled = owed <= 0 or WorldState.scrap <= 0
	b2.pressed.connect(forge.bind(owed))
	row.add_child(b2)
	var why := "Scrap put in stays IN the weapon — whoever carries it next can add more. Lose the weapon, lose it all."
	if inst.crossings < int(need["crossings"]):
		why += "\nIt can only become %s once it has been left by the lobby door and carried into a later game %d time%s." % [
			WeaponUpgrades.tier_name(to), int(need["crossings"]), "" if int(need["crossings"]) == 1 else "s"]
	_set_cost("[color=#%s]%s[/color]" % [DIM.to_html(false), why])
	# The tier completes the moment it's paid AND crossed (forge_heirloom) — no separate button.
	_upgrade_btn.visible = false


func _refresh_tune() -> void:
	_clear(_tune_grid)
	var inst = _selected()
	if inst == null or not WeaponUpgrades.can_upgrade(inst.item_id):
		_tune_head.text = "[color=#%s]Bring a weapon to tune.[/color]" % DIM.to_html(false)
		_tune_explain.text = ""
		_points_label.text = ""
		_set_btn.disabled = true
		_name_row.visible = false
		return
	_tune_head.text = _header_bbcode(inst)
	var staged_total := 0
	for id in staged:
		staged_total += int(staged[id])
	var earned: int = WeaponUpgrades.points_earned(inst)
	var free: int = WeaponUpgrades.points_free(inst) - staged_total
	var first_pick: int = WeaponUpgrades.REINFORCE_LEVEL + 1
	# What a tuning point IS and where it comes from - said every time, in plain words.
	if earned == 0:
		_tune_explain.text = "[b]Tuning points[/b] are earned by upgrading. This weapon has none yet: reinforce it on the Upgrade tab (Lv%d, cheap), then upgrade it again - from Lv%d every upgrade gives %d points to spend here." % [
			WeaponUpgrades.REINFORCE_LEVEL, first_pick, WeaponUpgrades.POINTS_PER_LEVEL]
		_points_label.text = "No tuning points yet (they start at Lv%d)." % first_pick
	else:
		_tune_explain.text = "[b]Tuning points[/b]: every upgrade from Lv%d gives %d. Each point is one rank of a stat below - a permanent bonus for this weapon. Stage ranks with + / -, then press Set in steel; set points can't be moved." % [first_pick, WeaponUpgrades.POINTS_PER_LEVEL]
		_points_label.text = "Points to spend: %d of %d%s" % [free, earned, ("   (%d staged)" % staged_total) if staged_total > 0 else ""]
	for id in WeaponUpgrades.stats_for(inst.item_id):
		var st: Dictionary = WeaponUpgrades.stat(id)
		var have: int = int(inst.tuning.get(id, 0))
		var add: int = int(staged.get(id, 0))
		var cap: int = WeaponUpgrades.cap_for(inst, id)
		var n := _label(String(st["name"]), 12, INK, Ledger.font("head"))
		n.custom_minimum_size = Vector2(TUNE_NAME_W, 26)
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tune_grid.add_child(n)
		var pips := LedgerPips.new()                    # a rank is one tally box: inked = set, hatched = staged, empty = still to earn
		pips.box = 13.0
		pips.gap = 4.0
		pips.custom_minimum_size = Vector2(TUNE_PIPS_W, 26)
		pips.setup(have, add, cap)
		_tune_grid.add_child(pips)
		var minus := LedgerButton.new()
		minus.text = "-"
		minus.px = 20
		minus.seed_value = 14
		minus.custom_minimum_size = Vector2(28, 24)
		minus.disabled = add <= 0
		minus.pressed.connect(stage_point.bind(id, -1))
		_tune_grid.add_child(minus)
		var plus := LedgerButton.new()
		plus.text = "+"
		plus.px = 20
		plus.seed_value = 15
		plus.custom_minimum_size = Vector2(28, 24)
		plus.disabled = free <= 0 or have + add >= cap
		plus.pressed.connect(stage_point.bind(id, 1))
		_tune_grid.add_child(plus)
		var d := _label(String(st["desc"]), 11, DIM)
		d.custom_minimum_size = Vector2(TUNE_DESC_W, 24)           # a rank's effect wraps inside the card (it ran off the edge at one line)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tune_grid.add_child(d)
	_set_btn.disabled = staged_total <= 0
	var legendary: bool = inst.level >= WeaponUpgrades.LEGENDARY_LEVEL
	_name_row.visible = legendary
	if legendary and not _name_edit.has_focus():
		_name_edit.text = inst.title


# --- SALVAGE ---------------------------------------------------------------------------
func _refresh_salvage() -> void:
	_clear(_salvage_grid)
	var any := false
	for i in WorldState.inventory.size():
		var inst = WorldState.inventory[i]
		if not Salvage.can_salvage(inst):
			continue
		any = true
		var disp_name: String = inst.get_display_name()
		if inst.count > 1:
			disp_name += "  x%d" % inst.count
		if inst.level > 1:
			disp_name += "  " + inst.tier_label()
		var n := _label(disp_name, 12, LEGEND if inst.level >= WeaponUpgrades.LEGENDARY_LEVEL else INK, Ledger.font("head"))
		n.custom_minimum_size = Vector2(290, 0)
		_salvage_grid.add_child(n)
		var st := _label(_condition(inst), 12, DIM)
		st.custom_minimum_size = Vector2(210, 0)
		_salvage_grid.add_child(st)
		var b := LedgerButton.new()
		b.custom_minimum_size = Vector2(210, 32)
		b.px = 16
		b.seed_value = 60 + i
		var v: int = Salvage.value_of(inst)
		b.text = ("SURE?  +%d SCRAP" if _confirm_salvage == inst else "BREAK DOWN  +%d") % v
		b.pressed.connect(salvage.bind(i))
		_salvage_grid.add_child(b)
	if not any:
		var none := _label("Nothing you're carrying is worth breaking down.", 13, DIM)
		_salvage_grid.add_child(none)


func _condition(inst) -> String:
	if inst.get_data().get("is_junk", false):
		return "junk"
	if inst.is_depleted:
		return "broken"
	var max_d: int = inst.get_max_durability()
	var t := ""
	if max_d > 0 and not inst.get_data().get("single_use", false):
		t = "%d/%d durability" % [inst.current_durability, max_d]
	if inst.is_damaged:
		t += ("  " if t != "" else "") + "damaged"
	return t


# Break the item in `slot` down. Anything but junk takes two presses (arm, then confirm).
# Returns the scrap gained (0 = armed / nothing).
func salvage(slot: int) -> int:
	var inst = WorldState.get_instance_at(slot)
	if inst == null or not Salvage.can_salvage(inst):
		return 0
	var blocked: String = WorldState.salvage_blocker(slot)
	if blocked != "":
		_confirm_salvage = null
		_say(blocked)
		refresh()
		return 0
	if Salvage.needs_confirm(inst) and _confirm_salvage != inst:
		_confirm_salvage = inst
		_say("Break down %s? It's gone for good." % inst.get_display_name())
		refresh()
		return 0
	_confirm_salvage = null
	var disp_name: String = inst.get_display_name()
	var got: int = WorldState.salvage_item(slot)
	if got > 0:
		_play_clank()
		_say("%s broken down: +%d scrap." % [disp_name, got])
	refresh()
	return got


func _play_clank() -> void:
	Ledger.play("pen", -10.0)                           # what was done is written down; the clank is the bench itself
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
