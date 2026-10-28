extends CanvasLayer

# THE WORKBENCH (docs/SCRAP_UPGRADES.md) — opened at a maintenance room's bench. Pauses the game
# (like the journal / shop). Three tabs share one list of the weapons you carry:
#   UPGRADE — the next level: what it NEEDS (scrap, any spare stripped for parts — each ticked or crossed against what you HAVE) and what it gives.
#             Lv2 is the plain first step (nothing to choose); from Lv3 a weapon picks one of two upgrades and earns tuning points.
#             Past Legendary (Lv5) it's the HEIRLOOM forge: scrap put in by instalments (it rides the weapon) and a door-crossing requirement.
#   TUNE    — spend the weapon's tuning points on its own stat sheet (stage with − / +, then "Set in steel" — points, once set, are set).
#             A legendary weapon can be renamed here.
#   SALVAGE — break carried items down for scrap (values in Salvage, action WorldState.salvage_item).
# All rules/costs/perks/stats live in WeaponUpgrades; the actions are WorldState.upgrade_weapon / tune_weapon / forge_heirloom / rename_weapon. Built in code (no .tscn).
# Close: ×, ESC.
# LAMPLIGHT look (owner round 48l: "a big UI disconnect. So many different font styles, colours, and types of text… too many longer bits of text which are small and tough to read… clear
# and concise"; "didn't we change this back to the black and gold version?"): the dark glass + brass kit of scripts/lamp.gd, ONE type scale (Lamp.PX_*), no handwriting, and ONE verb —
# UPGRADE — on the button, in the messages and on every page (the old button said REINFORCE / TEMPER where the rest said upgrade). A button that cannot act yet is drawn dim but stays
# pressable, and pressing it says why in red ("if I press, it doesn't say if I have enough scrap"). The logic below is the previous screen's, unchanged.

const W := 1000.0
const H := 560.0
const PAD := 28.0
const LEFT_W := 300.0
const RIGHT_X := 360.0
const RIGHT_W := W - RIGHT_X - PAD     # 612
const FORGE_STEP := 25                 # "Put in 25" at the heirloom forge
const BTN_W := 210.0
const BTN_H := 46.0
# The tune grid's columns (name | pips | − | + | effect) plus the 4 gaps of TUNE_GAP must fit the right pane (tests/weapon_upgrade_test checks it).
const TUNE_NAME_W := 130.0
const TUNE_PIPS_W := 150.0
const TUNE_BTN_W := 40.0
const TUNE_GAP := 10.0
const TUNE_DESC_W := RIGHT_W - TUNE_NAME_W - TUNE_PIPS_W - 2.0 * TUNE_BTN_W - 4.0 * TUNE_GAP
const TUNE_ROW_H := 44.0

var selected_slot: int = -1
var chosen_perk: String = ""
var staged: Dictionary = {}            # TUNE: {stat id: ranks staged but not yet set}
var _prev_paused := false

var _card: Control = null
var _backdrop: TextureRect = null
var _scrap_label: Label = null
var _list: VBoxContainer = null
var _list_hint: Label = null
var _w_name: Label = null              # the weapon's name and level, above the Upgrade and Tune pages
var _w_tier: Label = null
var _up_perks: Label = null
var _next_caption: Label = null
var _perk_box: HBoxContainer = null
var _forge_box: VBoxContainer = null
var _needs: LampNeeds = null
var _upgrade_btn: LampButton = null
var _msg: Label = null
var tab := "upgrade"                 # "upgrade" | "tune" | "salvage"
var _upgrade_page: Control = null
var _tune_page: Control = null
var _salvage_page: Control = null
var _salvage_grid: VBoxContainer = null
var _tune_grid: GridContainer = null
var _points_label: Label = null
var _set_btn: LampButton = null
var _name_row: HBoxContainer = null
var _name_edit: LineEdit = null
var _tab_up: LampButton = null
var _tab_tune: LampButton = null
var _tab_salv: LampButton = null
var _confirm_salvage: Object = null  # the item whose Break down was pressed once (confirm)
var _msg_kind := "hint"              # "hint" (the tab's own guidance) | "err" | "ok"


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_panel")      # Game._input closes a visible modal on ESC before the pause menu
	_backdrop = Lamp.backdrop()
	add_child(_backdrop)
	_card = Control.new()
	_card.name = "Card"
	_card.size = Vector2(W, H)
	_card.position = Vector2((1152.0 - W) * 0.5, maxf(8.0, (648.0 - H) * 0.5))
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	var glass := LampGlass.new()
	glass.corners = Lamp.ALL
	_card.add_child(glass)

	var title := Lamp.label("WORKBENCH", "head", Lamp.PX_TITLE, Lamp.TEXT)
	title.position = Vector2(PAD, 16)
	_card.add_child(title)
	var x := LampButton.new()
	x.text = "×"
	x.px = Lamp.PX_TITLE
	x.position = Vector2(W - PAD - 40.0, 14)
	x.size = Vector2(40, 40)
	x.custom_minimum_size = Vector2(40, 40)
	x.pressed.connect(close)
	_card.add_child(x)
	_scrap_label = Lamp.label("", "head", Lamp.PX_TITLE, Lamp.BRASS)
	_scrap_label.position = Vector2(W - PAD - 40.0 - 14.0 - 130.0, 14)
	_scrap_label.size = Vector2(130, 40)
	_scrap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card.add_child(_scrap_label)
	var scrap_cap := Lamp.label("SCRAP", "label", Lamp.PX_LABEL, Lamp.LABEL)
	scrap_cap.position = Vector2(W - PAD - 40.0 - 14.0 - 130.0 - 76.0, 14)
	scrap_cap.size = Vector2(70, 40)
	scrap_cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scrap_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card.add_child(scrap_cap)

	_tab_up = _tab_button("UPGRADE", Vector2(PAD, 66))
	_tab_up.pressed.connect(func(): show_tab("upgrade"))
	_tab_tune = _tab_button("TUNE", Vector2(PAD + 156.0, 66))
	_tab_tune.pressed.connect(func(): show_tab("tune"))
	_tab_salv = _tab_button("SALVAGE", Vector2(PAD + 312.0, 66))
	_tab_salv.pressed.connect(func(): show_tab("salvage"))
	var rule := ColorRect.new()
	rule.color = Lamp.EDGE_DIM
	rule.position = Vector2(PAD, 116)
	rule.size = Vector2(W - 2.0 * PAD, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(rule)

	# The weapon list (shared by Upgrade + Tune).
	_list_hint = Lamp.label("YOUR WEAPONS", "label", Lamp.PX_LABEL, Lamp.LABEL)
	_list_hint.position = Vector2(PAD, 128)
	_card.add_child(_list_hint)
	_list = VBoxContainer.new()
	_list.position = Vector2(PAD, 158)
	_list.size = Vector2(LEFT_W, H - 158.0 - 76.0)
	_list.add_theme_constant_override("separation", 8)
	_card.add_child(_list)

	# The name + level of the weapon shown (Upgrade + Tune).
	_w_name = Lamp.label("", "head", Lamp.PX_NAME, Lamp.TEXT)
	_w_name.position = Vector2(RIGHT_X, 124)
	_w_name.size = Vector2(RIGHT_W - 180.0, 36)
	_w_name.clip_text = true
	_card.add_child(_w_name)
	_w_tier = Lamp.label("", "label", Lamp.PX_LABEL, Lamp.LABEL)
	_w_tier.position = Vector2(RIGHT_X + RIGHT_W - 180.0, 128)
	_w_tier.size = Vector2(180, 30)
	_w_tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card.add_child(_w_tier)

	_upgrade_page = _page()
	_tune_page = _page()
	_salvage_page = _page()
	_build_upgrade_page()
	_build_tune_page()
	_build_salvage_page()

	_msg = Lamp.label("", "body", Lamp.PX_BODY, Lamp.SOFT, true)
	_msg.position = Vector2(PAD, H - 62.0)
	_msg.size = Vector2(W - 2.0 * PAD - BTN_W - 24.0, 52)
	_msg.custom_minimum_size = Vector2(_msg.size.x, 0)
	_card.add_child(_msg)
	visible = false


func _page() -> Control:
	var c := Control.new()
	c.size = Vector2(W, H)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(c)
	return c


func _tab_button(text: String, pos: Vector2) -> LampButton:
	var b := LampButton.new()
	b.text = text
	b.position = pos
	b.size = Vector2(146, 40)
	b.custom_minimum_size = Vector2(146, 40)
	b.toggle_mode = true
	_card.add_child(b)
	return b


func _build_upgrade_page() -> void:
	_up_perks = Lamp.label("", "body", Lamp.PX_BODY, Lamp.BODY, true)
	_up_perks.position = Vector2(RIGHT_X, 160)
	_up_perks.size = Vector2(RIGHT_W, 28)
	_up_perks.custom_minimum_size = Vector2(RIGHT_W, 0)
	_upgrade_page.add_child(_up_perks)
	_next_caption = Lamp.label("", "label", Lamp.PX_LABEL, Lamp.BRASS)
	_next_caption.position = Vector2(RIGHT_X, 192)
	_next_caption.size = Vector2(RIGHT_W, 24)
	_upgrade_page.add_child(_next_caption)
	_perk_box = HBoxContainer.new()
	_perk_box.position = Vector2(RIGHT_X, 220)
	_perk_box.size = Vector2(RIGHT_W, 200)
	_perk_box.add_theme_constant_override("separation", 14)
	_upgrade_page.add_child(_perk_box)
	_forge_box = VBoxContainer.new()
	_forge_box.position = Vector2(RIGHT_X, 220)
	_forge_box.size = Vector2(RIGHT_W, 200)
	_forge_box.add_theme_constant_override("separation", 10)
	_upgrade_page.add_child(_forge_box)
	_needs = LampNeeds.new()
	_needs.position = Vector2(RIGHT_X, 430)
	_needs.size = Vector2(RIGHT_W, 60)
	_upgrade_page.add_child(_needs)
	_upgrade_btn = LampButton.new()
	_upgrade_btn.text = "UPGRADE"
	_upgrade_btn.solid = true
	_upgrade_btn.px = Lamp.PX_NAME
	_upgrade_btn.position = Vector2(W - PAD - BTN_W, H - 62.0)
	_upgrade_btn.size = Vector2(BTN_W, BTN_H)
	_upgrade_btn.custom_minimum_size = Vector2(BTN_W, BTN_H)
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	_upgrade_page.add_child(_upgrade_btn)


func _build_tune_page() -> void:
	_points_label = Lamp.label("", "body", Lamp.PX_BODY, Lamp.BRASS)
	_points_label.position = Vector2(RIGHT_X, 162)
	_points_label.size = Vector2(300, 30)
	_tune_page.add_child(_points_label)
	_tune_grid = GridContainer.new()
	_tune_grid.columns = 5                 # name | pips | − | + | what a rank does
	_tune_grid.position = Vector2(RIGHT_X, 200)
	_tune_grid.add_theme_constant_override("h_separation", int(TUNE_GAP))
	_tune_grid.add_theme_constant_override("v_separation", 4)
	_tune_page.add_child(_tune_grid)
	_name_row = HBoxContainer.new()
	_name_row.position = Vector2(RIGHT_X + 330.0, 156)
	_name_row.add_theme_constant_override("separation", 8)
	_tune_page.add_child(_name_row)
	_name_row.add_child(Lamp.label("NAME", "label", Lamp.PX_LABEL, Lamp.LABEL))
	_name_edit = LineEdit.new()                      # a dark well with a brass caret, in the kit's own body face
	_name_edit.max_length = WeaponUpgrades.TITLE_MAX_LEN
	_name_edit.custom_minimum_size = Vector2(150, 36)
	_name_edit.add_theme_font_override("font", Lamp.font("body"))
	_name_edit.add_theme_font_size_override("font_size", Lamp.PX_BODY)
	_name_edit.add_theme_color_override("font_color", Lamp.TEXT)
	_name_edit.add_theme_color_override("caret_color", Lamp.BRASS_HI)
	var well := StyleBoxFlat.new()
	well.bg_color = Lamp.WELL
	well.border_color = Lamp.EDGE
	well.set_border_width_all(1)
	well.content_margin_left = 8
	_name_edit.add_theme_stylebox_override("normal", well)
	var lit := well.duplicate() as StyleBoxFlat
	lit.border_color = Lamp.BRASS
	_name_edit.add_theme_stylebox_override("focus", lit)
	_name_edit.text_submitted.connect(func(t): rename(t))
	_name_row.add_child(_name_edit)
	var nb := LampButton.new()
	nb.text = "RENAME"
	nb.custom_minimum_size = Vector2(112, 36)
	nb.pressed.connect(func(): rename(_name_edit.text))
	_name_row.add_child(nb)
	_set_btn = LampButton.new()
	_set_btn.text = "SET IN STEEL"
	_set_btn.solid = true
	_set_btn.px = Lamp.PX_NAME
	_set_btn.position = Vector2(W - PAD - BTN_W, H - 62.0)
	_set_btn.size = Vector2(BTN_W, BTN_H)
	_set_btn.custom_minimum_size = Vector2(BTN_W, BTN_H)
	_set_btn.pressed.connect(_on_set_pressed)
	_tune_page.add_child(_set_btn)


func _build_salvage_page() -> void:
	var shint := Lamp.label("Break things down for scrap. Worn ones give less.", "body", Lamp.PX_BODY, Lamp.SOFT)
	shint.position = Vector2(PAD, 128)
	_salvage_page.add_child(shint)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(PAD, 166)
	scroll.size = Vector2(W - 2.0 * PAD, H - 166.0 - 76.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_salvage_page.add_child(scroll)
	_salvage_grid = VBoxContainer.new()
	_salvage_grid.custom_minimum_size = Vector2(W - 2.0 * PAD - 12.0, 0)
	_salvage_grid.add_theme_constant_override("separation", 8)
	scroll.add_child(_salvage_grid)


func show_tab(which: String) -> void:
	tab = which
	_confirm_salvage = null
	staged = {}
	_clear_msg()
	refresh()


func open() -> void:
	_prev_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	_arrive()
	selected_slot = -1
	chosen_perk = ""
	staged = {}
	_clear_msg()
	tab = "upgrade"
	_confirm_salvage = null
	var slots := upgradable_slots()
	if not slots.is_empty():
		selected_slot = slots[0]
	refresh()


## The panel is set down on the bench: it settles a few px and the room dims behind it.
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
	_clear_msg()
	refresh()


func choose_perk(perk_id: String) -> void:
	chosen_perk = perk_id
	_clear_msg()
	refresh()


func _selected():
	return WorldState.get_instance_at(selected_slot) if selected_slot >= 0 else null


## A press on the button: it acts, or — dim, because something is missing — says what, in red, with a knock.
func _on_upgrade_pressed() -> void:
	if confirm() != "":
		_upgrade_btn.refuse()


func _on_set_pressed() -> void:
	if set_tuning() != "":
		_set_btn.refuse()


# Apply the next level. Returns "" on success, else why not (also shown at the foot of the panel).
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
	var pts := ""
	if inst.level > WeaponUpgrades.REINFORCE_LEVEL:
		pts = " +%d tuning points — spend them on TUNE." % WeaponUpgrades.POINTS_PER_LEVEL
	if not was_titled and inst.title != "":
		_say_ok("LEGENDARY. It has earned a name: \"%s\".%s" % [inst.title, pts])
	else:
		var perk_part := (" — " + perk_name) if perk_name != "" and inst.level != WeaponUpgrades.REINFORCE_LEVEL else ""
		if inst.level == WeaponUpgrades.REINFORCE_LEVEL:
			perk_part = " — Reinforced"
		_say_ok("Upgraded to %s%s.%s" % [_tier_word(inst, true), perk_part, pts])
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
		_say_ok("Upgraded to %s. Every stat can go one rank higher." % _tier_word(inst, true))
	else:
		_say_ok("Put in %d scrap. It stays in the weapon." % (inst.forge_paid - paid_before))
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
	_clear_msg()
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


# --- the foot line: the tab's own guidance, until something is said --------------------------
func _clear_msg() -> void:
	_msg_kind = "hint"
	if _msg != null:
		_msg.text = _hint_for_tab()
		_msg.add_theme_color_override("font_color", Lamp.SOFT)


## A refusal or an error: shown in red, returned to the caller (which reports non-empty = failed).
func _say(t: String) -> String:
	_msg_kind = "err"
	if _msg != null:
		_msg.text = t
		_msg.add_theme_color_override("font_color", Lamp.RED)
	return t


## A success line: shown in green, but the action still reports "" (success) to its caller.
func _say_ok(t: String) -> String:
	_msg_kind = "ok"
	if _msg != null:
		_msg.text = t
		_msg.add_theme_color_override("font_color", Lamp.GREEN)
	return ""


func _hint_for_tab() -> String:
	if tab == "tune":
		return "One point raises one stat, for good. Points come from upgrading, from Lv%d." % (WeaponUpgrades.REINFORCE_LEVEL + 1)
	return ""


func refresh() -> void:
	_scrap_label.text = str(WorldState.scrap)
	_tab_up.button_pressed = tab == "upgrade"
	_tab_tune.button_pressed = tab == "tune"
	_tab_salv.button_pressed = tab == "salvage"
	_upgrade_page.visible = tab == "upgrade"
	_tune_page.visible = tab == "tune"
	_salvage_page.visible = tab == "salvage"
	var weapons := tab != "salvage"
	_list.visible = weapons
	_list_hint.visible = weapons
	_w_name.visible = weapons
	_w_tier.visible = weapons
	if _msg_kind == "hint":
		_msg.text = _hint_for_tab()
	if tab == "salvage":
		_refresh_salvage()
		return
	_refresh_list()
	_refresh_head()
	if tab == "tune":
		_refresh_tune()
	else:
		_refresh_upgrade()


func _refresh_list() -> void:
	_clear(_list)
	for i in upgradable_slots():
		var inst = WorldState.inventory[i]
		var b := LampButton.new()
		b.text = inst.get_display_name()
		var pts: int = WeaponUpgrades.points_free(inst)
		b.tag = ("%d PT%s" % [pts, "" if pts == 1 else "S"]) if tab == "tune" and pts > 0 else inst.tier_tag().to_upper()
		b.toggle_mode = true
		b.button_pressed = i == selected_slot
		b.align_left = true
		b.custom_minimum_size = Vector2(LEFT_W, 48)
		b.pressed.connect(select_weapon.bind(i))
		_list.add_child(b)


## The weapon shown: its name (brass-gold once Legendary) and its level in a word.
func _refresh_head() -> void:
	var inst = _selected()
	if inst == null or not WeaponUpgrades.can_upgrade(inst.item_id):
		_w_name.text = "NO WEAPON" if upgradable_slots().is_empty() else "PICK A WEAPON"
		_w_name.add_theme_color_override("font_color", Lamp.DIM)
		_w_tier.text = ""
		return
	_w_name.text = inst.get_display_name()
	_w_name.add_theme_color_override("font_color", Lamp.BRASS_HI if inst.level >= WeaponUpgrades.LEGENDARY_LEVEL else Lamp.TEXT)
	_w_tier.text = _tier_word(inst, false)


## "LV 3" / "LEGENDARY" / "LEGENDARY +" — `mixed` gives "Lv 3" for a sentence.
func _tier_word(inst, mixed: bool) -> String:
	if inst.level < WeaponUpgrades.LEGENDARY_LEVEL:
		return ("Lv %d" if mixed else "LV %d") % inst.level
	var w: String = WeaponUpgrades.tier_name(inst.level)
	return w if mixed else w.to_upper()


func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _refresh_upgrade() -> void:
	_clear(_perk_box)
	_clear(_forge_box)
	_perk_box.visible = true
	_forge_box.visible = false
	_needs.set_rows([])
	_next_caption.text = ""
	_up_perks.text = ""
	_upgrade_btn.visible = true
	_upgrade_btn.looks_off = true
	var slots := upgradable_slots()
	if slots.is_empty():
		_up_perks.text = "Nothing here the bench can work on. Bring a gun, a blade, a bat or a hammer."
		return
	var inst = _selected()
	if inst == null or not WeaponUpgrades.can_upgrade(inst.item_id):
		_up_perks.text = "Pick a weapon on the left."
		return
	_up_perks.text = _perks_line(inst)
	if inst.level >= WeaponUpgrades.MAX_LEVEL:
		_next_caption.text = "FULLY UPGRADED"
		_upgrade_btn.visible = false
		return
	var chk: Dictionary = WeaponUpgrades.check(inst, WorldState.inventory, WorldState.scrap)
	if chk["heirloom"] and not chk["ok"]:
		_refresh_forge(inst)
		return
	var to: int = inst.level + 1
	var caption := "NEXT   LV %d" % to if to < WeaponUpgrades.LEGENDARY_LEVEL else "NEXT   " + WeaponUpgrades.tier_name(to).to_upper()
	if to > WeaponUpgrades.REINFORCE_LEVEL:
		caption += "   ·   +%d TUNING POINTS" % WeaponUpgrades.POINTS_PER_LEVEL
	_next_caption.text = caption
	var choices: Array = WeaponUpgrades.next_choices(inst)
	var k := 0
	for pid in choices:
		_perk_box.add_child(_perk_card(inst, pid, k))
		k += 1
	if choices.is_empty():
		if WeaponUpgrades.is_plain_step(to):
			var rd: Dictionary = WeaponUpgrades.perk(WeaponUpgrades.auto_perk(inst.item_id, to))
			_perk_box.add_child(_info_card("UPGRADE", String(rd.get("name", "Reinforced")), String(rd.get("desc", ""))))
		else:
			_perk_box.add_child(_info_card("UPGRADE", "Every special taken", "This level only gives it %d more tuning points." % WeaponUpgrades.POINTS_PER_LEVEL))
	# What it needs, ticked or crossed against what you have.
	var rows: Array = []
	var scrap_need: int = int(chk["scrap"])
	rows.append({"label": "SCRAP", "need": str(scrap_need), "have": "you have %d" % WorldState.scrap, "ok": WorldState.scrap >= scrap_need})
	if int(chk["feed_level"]) > 0:
		var fi: int = int(chk["feed_index"])
		rows.append({"label": "SPARE", "need": WeaponUpgrades.feed_short(inst, int(chk["feed_level"])),
			"have": ("your " + WorldState.inventory[fi].get_display_name()) if fi >= 0 else "none in your pack", "ok": fi >= 0})
	_needs.set_rows(rows)
	var needs_pick: bool = not choices.is_empty() and chosen_perk == ""
	_upgrade_btn.looks_off = not chk["ok"] or needs_pick
	if int(chk["feed_level"]) > 0 and _msg_kind == "hint":
		_msg.text = "The spare is broken down for parts."
	elif needs_pick and _msg_kind == "hint":
		_msg.text = "Pick one of the two."


## What the weapon already has, by name only — "Heavy Head · Door Breaker" (a long list stays one line; the numbers are on the cards when it matters).
func _perks_line(inst) -> String:
	var names: PackedStringArray = []
	for p in inst.perks:
		names.append(String(WeaponUpgrades.perk(p).get("name", p)))
	var line: String = " · ".join(names) if not names.is_empty() else "No upgrades yet."
	if inst.forged_by != "":
		var parts: PackedStringArray = inst.forged_by.split(":")
		line += "   (forged by %s%s)" % [WorldState.character_display_name(parts[0]), (", crossed the door %d×" % inst.crossings) if inst.crossings > 0 else ""]
	return line


## One of the two upgrades on offer: a dark card; click it to choose it (brass brackets and a CHOSEN tab); click the other and the choice moves.
func _perk_card(inst, pid: String, _index: int) -> Control:
	var d: Dictionary = WeaponUpgrades.perk(pid)
	var special: bool = WeaponUpgrades.is_mod(pid)
	var card := LampCard.new()
	card.name = "Card_" + pid
	card.custom_minimum_size = Vector2((RIGHT_W - 14.0) * 0.5, 200)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.held = pid == chosen_perk
	card.content.add_child(Lamp.label("A SPECIAL" if special else "AN UPGRADE", "label", Lamp.PX_LABEL, Lamp.BRASS_HI if special else Lamp.LABEL))
	var nm := Lamp.label(String(d.get("name", pid)), "head", Lamp.PX_NAME, Lamp.TEXT)
	nm.clip_text = true
	card.content.add_child(nm)
	var ds := Lamp.label(WeaponUpgrades.describe(inst, pid), "body", Lamp.PX_BODY, Lamp.BODY, true)
	ds.custom_minimum_size = Vector2(card.custom_minimum_size.x - 2.0 * card.margin, 0)
	card.content.add_child(ds)
	card.chosen.connect(choose_perk.bind(pid))
	return card


## A card with nothing to choose (the plain first step): the same look, no click.
func _info_card(caption: String, name_text: String, desc: String) -> Control:
	var card := LampCard.new()
	card.name = "Card_info"
	card.clickable = false
	card.custom_minimum_size = Vector2(RIGHT_W, 130)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.content.add_child(Lamp.label(caption, "label", Lamp.PX_LABEL, Lamp.LABEL))
	card.content.add_child(Lamp.label(name_text, "head", Lamp.PX_NAME, Lamp.TEXT))
	var ds := Lamp.label(desc, "body", Lamp.PX_BODY, Lamp.BODY, true)
	ds.custom_minimum_size = Vector2(RIGHT_W - 2.0 * card.margin, 0)
	card.content.add_child(ds)
	return card


# The heirloom forge: instalments + the crossing requirement.
func _refresh_forge(inst) -> void:
	_perk_box.visible = false
	_forge_box.visible = true
	var to: int = inst.level + 1
	var need: Dictionary = WeaponUpgrades.HEIRLOOM[to]
	var total: int = int(need["scrap"])
	_next_caption.text = "THE FORGE   ·   %s" % WeaponUpgrades.tier_name(to).to_upper()
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = total
	bar.value = mini(inst.forge_paid, total)
	bar.custom_minimum_size = Vector2(RIGHT_W, 22)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Lamp.BRASS
	var back := StyleBoxFlat.new()
	back.bg_color = Lamp.WELL
	back.border_color = Lamp.EDGE
	back.set_border_width_all(1)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	_forge_box.add_child(bar)
	var owed: int = total - inst.forge_paid
	_needs.set_rows([
		{"label": "SCRAP", "need": "%d put in" % total, "have": "%d in so far" % mini(inst.forge_paid, total), "ok": owed <= 0},
		{"label": "DOOR", "need": "carried out through the lobby door %d×" % int(need["crossings"]), "have": "done %d×" % inst.crossings, "ok": inst.crossings >= int(need["crossings"])},
	])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_forge_box.add_child(row)
	var b1 := LampButton.new()
	b1.custom_minimum_size = Vector2(170, 44)
	b1.text = "PUT IN %d" % mini(FORGE_STEP, maxi(owed, 0))
	b1.looks_off = owed <= 0 or WorldState.scrap <= 0
	b1.pressed.connect(func(): if forge(FORGE_STEP) != "": b1.refuse())
	row.add_child(b1)
	var b2 := LampButton.new()
	b2.custom_minimum_size = Vector2(260, 44)
	b2.text = "PUT IN ALL I CAN (%d)" % mini(WorldState.scrap, maxi(owed, 0))
	b2.looks_off = owed <= 0 or WorldState.scrap <= 0
	b2.pressed.connect(func(): if forge(owed) != "": b2.refuse())
	row.add_child(b2)
	_forge_box.add_child(Lamp.label("Scrap put in stays in the weapon — whoever carries it next can add more.", "body", Lamp.PX_BODY, Lamp.SOFT, true))
	# The tier completes the moment it's paid AND crossed (forge_heirloom) — no separate button.
	_upgrade_btn.visible = false


func _refresh_tune() -> void:
	_clear(_tune_grid)
	var inst = _selected()
	if inst == null or not WeaponUpgrades.can_upgrade(inst.item_id):
		_points_label.text = "Bring a weapon to tune."
		_set_btn.looks_off = true
		_name_row.visible = false
		return
	var staged_total := 0
	for id in staged:
		staged_total += int(staged[id])
	var earned: int = WeaponUpgrades.points_earned(inst)
	var free: int = WeaponUpgrades.points_free(inst) - staged_total
	if earned == 0:
		_points_label.text = "No tuning points yet."
	else:
		_points_label.text = "POINTS   %d free of %d%s" % [free, earned, ("   (%d staged)" % staged_total) if staged_total > 0 else ""]
	for id in WeaponUpgrades.stats_for(inst.item_id):
		var st: Dictionary = WeaponUpgrades.stat(id)
		var have: int = int(inst.tuning.get(id, 0))
		var add: int = int(staged.get(id, 0))
		var cap: int = WeaponUpgrades.cap_for(inst, id)
		var n := Lamp.label(String(st["name"]), "head", Lamp.PX_BODY, Lamp.TEXT)
		n.custom_minimum_size = Vector2(TUNE_NAME_W, TUNE_ROW_H)
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tune_grid.add_child(n)
		var pips := LampPips.new()                    # a rank is one box: filled = set, outlined = staged, empty = still to earn
		pips.box = 16.0
		pips.gap = 5.0
		pips.custom_minimum_size = Vector2(TUNE_PIPS_W, TUNE_ROW_H)
		pips.setup(have, add, cap)
		_tune_grid.add_child(pips)
		var minus := LampButton.new()
		minus.text = "−"
		minus.px = Lamp.PX_NAME
		minus.custom_minimum_size = Vector2(TUNE_BTN_W, 36)
		minus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		minus.looks_off = add <= 0
		minus.pressed.connect(stage_point.bind(id, -1))
		_tune_grid.add_child(minus)
		var plus := LampButton.new()
		plus.text = "+"
		plus.px = Lamp.PX_NAME
		plus.custom_minimum_size = Vector2(TUNE_BTN_W, 36)
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.looks_off = free <= 0 or have + add >= cap
		plus.pressed.connect(stage_point.bind(id, 1))
		_tune_grid.add_child(plus)
		var d := Lamp.label(String(st["desc"]), "body", Lamp.PX_LABEL, Lamp.SOFT, true)
		d.custom_minimum_size = Vector2(TUNE_DESC_W, TUNE_ROW_H)           # a rank's effect wraps inside the panel
		d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tune_grid.add_child(d)
	_set_btn.looks_off = staged_total <= 0
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
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		_salvage_grid.add_child(row)
		var n := Lamp.label(disp_name, "head", Lamp.PX_BODY, Lamp.BRASS_HI if inst.level >= WeaponUpgrades.LEGENDARY_LEVEL else Lamp.TEXT)
		n.custom_minimum_size = Vector2(330, 44)
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n.clip_text = true
		row.add_child(n)
		var st := Lamp.label(_condition(inst), "body", Lamp.PX_BODY, Lamp.SOFT)
		st.custom_minimum_size = Vector2(250, 44)
		st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(st)
		var b := LampButton.new()
		b.custom_minimum_size = Vector2(240, 44)
		var v: int = Salvage.value_of(inst)
		b.text = ("SURE?   +%d SCRAP" if _confirm_salvage == inst else "BREAK DOWN   +%d") % v
		if _confirm_salvage == inst:
			b.solid = true
		b.pressed.connect(salvage.bind(i))
		row.add_child(b)
	if not any:
		_salvage_grid.add_child(Lamp.label("Nothing you're carrying is worth breaking down.", "body", Lamp.PX_BODY, Lamp.DIM))


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
		_clear_msg()
		_say("Break down %s? Press again — it's gone for good." % inst.get_display_name())
		refresh()
		return 0
	_confirm_salvage = null
	var disp_name: String = inst.get_display_name()
	var got: int = WorldState.salvage_item(slot)
	if got > 0:
		_play_clank()
		_say_ok("%s broken down: +%d scrap." % [disp_name, got])
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
