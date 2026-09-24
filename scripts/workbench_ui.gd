extends CanvasLayer

# THE WORKBENCH (docs/SCRAP_UPGRADES.md) — opened at a maintenance room's bench. Pauses the game
# (like the journal / shop). Three tabs share one list of the weapons you carry:
#   UPGRADE — the next level: its cost (scrap + any spare stripped for parts) and, for a weapon with
#             a tree, the Hades-style PICK ONE OF TWO. Past Legendary (Lv4) it's the HEIRLOOM forge:
#             scrap put in by instalments (it rides the weapon) and a door-crossing requirement.
#   TUNE    — spend the weapon's tuning points on its own stat sheet (stage with − / +, then "Set in
#             steel" — points, once set, are set). A legendary weapon can be renamed here.
#   SALVAGE — break carried items down for scrap (values in Salvage, action WorldState.salvage_item).
# All rules/costs/perks/stats live in WeaponUpgrades; the actions are WorldState.upgrade_weapon /
# tune_weapon / forge_heirloom / rename_weapon. Built in code (no .tscn). Close: ✕, ESC, or Leave.

const W := 820.0
const H := 480.0
const INK := Color(0.93, 0.90, 0.84)
const DIM := Color(0.62, 0.60, 0.56)
const GOLD := Color(1.0, 0.82, 0.30)
const BAD := Color(0.95, 0.45, 0.38)
const LEGEND := Color(1.0, 0.62, 0.25)
const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const FONT_BOLD := preload("res://assets/fonts/PixelOperator8-Bold.ttf")
const FORGE_STEP := 25                 # "Put in 25" at the heirloom forge
const RIGHT_X := 290.0

var selected_slot: int = -1
var chosen_perk: String = ""
var staged: Dictionary = {}            # TUNE: {stat id: ranks staged but not yet set}
var _prev_paused := false

var _card: Panel = null
var _scrap_label: Label = null
var _list: VBoxContainer = null
var _list_hint: Label = null
var _detail: RichTextLabel = null
var _perk_box: HBoxContainer = null
var _forge_box: VBoxContainer = null
var _cost_label: Label = null
var _upgrade_btn: Button = null
var _msg: Label = null
var tab := "upgrade"                 # "upgrade" | "tune" | "salvage"
var _upgrade_page: Control = null
var _tune_page: Control = null
var _salvage_page: Control = null
var _salvage_grid: GridContainer = null
var _tune_head: RichTextLabel = null
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
	_card.position = Vector2((1152.0 - W) * 0.5, maxf(8.0, (648.0 - 120.0 - H) * 0.5 + 10.0))
	add_child(_card)

	var title := _label("WORKBENCH", 22, GOLD, FONT_BOLD)
	title.position = Vector2(24, 16)
	_card.add_child(title)
	_scrap_label = _label("", 14, INK)
	_scrap_label.position = Vector2(W - 230, 22)
	_scrap_label.size = Vector2(170, 20)
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card.add_child(_scrap_label)
	var x := Button.new()
	x.text = "✕"
	x.position = Vector2(W - 44, 12)
	x.size = Vector2(30, 30)
	x.pressed.connect(close)
	_card.add_child(x)

	_tab_up = _tab_button("Upgrade", Vector2(220, 16))
	_tab_up.pressed.connect(func(): show_tab("upgrade"))
	_tab_tune = _tab_button("Tune", Vector2(340, 16))
	_tab_tune.pressed.connect(func(): show_tab("tune"))
	_tab_salv = _tab_button("Salvage", Vector2(460, 16))
	_tab_salv.pressed.connect(func(): show_tab("salvage"))

	# The weapon list (shared by Upgrade + Tune).
	_list_hint = _label("Your weapons", 12, DIM)
	_list_hint.position = Vector2(24, 60)
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

	var leave := Button.new()
	leave.text = "Leave"
	leave.position = Vector2(W - 310, H - 52)
	leave.size = Vector2(100, 36)
	leave.pressed.connect(close)
	_card.add_child(leave)
	_msg = _label("", 12, GOLD)
	_msg.position = Vector2(24, H - 44)
	_msg.size = Vector2(W - 350, 34)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(_msg)
	visible = false


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
	r.add_theme_font_override("normal_font", FONT)
	r.add_theme_font_override("bold_font", FONT_BOLD)
	r.add_theme_font_size_override("normal_font_size", 12)
	r.add_theme_font_size_override("bold_font_size", 13)
	r.add_theme_color_override("default_color", INK)
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
	_cost_label = _label("", 13, INK)
	_cost_label.position = Vector2(RIGHT_X, 324)
	_cost_label.size = Vector2(W - RIGHT_X - 24, 70)
	_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrade_page.add_child(_cost_label)
	_upgrade_btn = Button.new()
	_upgrade_btn.text = "Upgrade"
	_upgrade_btn.position = Vector2(W - 194, H - 52)
	_upgrade_btn.size = Vector2(170, 36)
	_upgrade_btn.pressed.connect(func(): confirm())
	_upgrade_page.add_child(_upgrade_btn)


func _build_tune_page() -> void:
	_tune_head = _rich(Vector2(RIGHT_X, 60), Vector2(W - RIGHT_X - 24, 52))
	_tune_page.add_child(_tune_head)
	_points_label = _label("", 13, GOLD, FONT_BOLD)
	_points_label.position = Vector2(RIGHT_X, 114)
	_tune_page.add_child(_points_label)
	_tune_grid = GridContainer.new()
	_tune_grid.columns = 5                 # name | pips | − | + | what a rank does
	_tune_grid.position = Vector2(RIGHT_X, 138)
	_tune_grid.add_theme_constant_override("h_separation", 8)
	_tune_grid.add_theme_constant_override("v_separation", 4)
	_tune_page.add_child(_tune_grid)
	_name_row = HBoxContainer.new()
	_name_row.position = Vector2(RIGHT_X, H - 96)
	_name_row.add_theme_constant_override("separation", 8)
	_tune_page.add_child(_name_row)
	var nl := _label("Its name:", 12, LEGEND)
	_name_row.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.max_length = WeaponUpgrades.TITLE_MAX_LEN
	_name_edit.custom_minimum_size = Vector2(220, 28)
	_name_edit.add_theme_font_override("font", FONT)
	_name_edit.add_theme_font_size_override("font_size", 12)
	_name_edit.text_submitted.connect(func(t): rename(t))
	_name_row.add_child(_name_edit)
	var nb := Button.new()
	nb.text = "Rename"
	nb.custom_minimum_size = Vector2(90, 28)
	nb.pressed.connect(func(): rename(_name_edit.text))
	_name_row.add_child(nb)
	_set_btn = Button.new()
	_set_btn.text = "Set in steel"
	_set_btn.position = Vector2(W - 194, H - 52)
	_set_btn.size = Vector2(170, 36)
	_set_btn.pressed.connect(func(): set_tuning())
	_tune_page.add_child(_set_btn)


func _build_salvage_page() -> void:
	var shint := _label("Break things down for scrap. Junk is worth a little; worn items give less.", 12, DIM)
	shint.position = Vector2(24, 60)
	_salvage_page.add_child(shint)
	_salvage_grid = GridContainer.new()
	_salvage_grid.columns = 3
	_salvage_grid.position = Vector2(24, 88)
	_salvage_grid.add_theme_constant_override("h_separation", 16)
	_salvage_grid.add_theme_constant_override("v_separation", 6)
	_salvage_page.add_child(_salvage_grid)


func _tab_button(text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(110, 30)
	b.toggle_mode = true
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 13)
	_card.add_child(b)
	return b


func show_tab(which: String) -> void:
	tab = which
	_confirm_salvage = null
	staged = {}
	_msg.text = ""
	refresh()


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
	staged = {}
	_msg.text = ""
	tab = "upgrade"
	_confirm_salvage = null
	var slots := upgradable_slots()
	if not slots.is_empty():
		selected_slot = slots[0]
	refresh()


func close() -> void:
	if not visible:
		return
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
	var perk_name: String = WeaponUpgrades.perk(chosen_perk).get("name", "") if chosen_perk != "" else ""
	chosen_perk = ""
	_play_clank()
	refresh()
	var pts := "+%d tuning points" % WeaponUpgrades.POINTS_PER_LEVEL
	if not was_titled and inst.title != "":
		_say("LEGENDARY. It has earned a name: \"%s\". %s — rename it on the Tune tab." % [inst.title, pts])
	else:
		_say("%s is now %s%s — %s." % [inst.get_display_name(), WeaponUpgrades.tier_name(inst.level),
			(" (" + perk_name + ")") if perk_name != "" else "", pts])
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
		var b := Button.new()
		var tag: String = inst.tier_tag()
		var pts: int = WeaponUpgrades.points_free(inst)
		b.text = "%s%s%s" % [inst.get_display_name(), ("   " + tag) if tag != "" else "", ("  (%d pt)" % pts) if pts > 0 else ""]
		b.clip_text = true
		b.toggle_mode = true
		b.button_pressed = i == selected_slot
		b.custom_minimum_size = Vector2(250, 34)
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 11)
		if inst.level >= WeaponUpgrades.LEGENDARY_LEVEL:
			b.add_theme_color_override("font_color", LEGEND)
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
		_cost_label.text = ""
		_upgrade_btn.disabled = true
		return
	var inst = _selected()
	if inst == null or not WeaponUpgrades.can_upgrade(inst.item_id):
		_detail.text = "Pick a weapon."
		_cost_label.text = ""
		_upgrade_btn.disabled = true
		return
	var txt := _header_bbcode(inst)
	if inst.perks.is_empty():
		txt += "\n[color=#%s]No perks yet.[/color]" % DIM.to_html(false)
	for p in inst.perks:
		var d: Dictionary = WeaponUpgrades.perk(p)
		txt += "\n[color=#%s]✔ %s[/color] — %s" % [GOLD.to_html(false), d.get("name", p), d.get("desc", "")]
	_detail.text = txt
	if inst.level >= WeaponUpgrades.MAX_LEVEL:
		_cost_label.text = "Legendary +++. There is nothing more the bench can do — only you."
		_cost_label.add_theme_color_override("font_color", LEGEND)
		_upgrade_btn.disabled = true
		return
	var chk: Dictionary = WeaponUpgrades.check(inst, WorldState.inventory, WorldState.scrap)
	if chk["heirloom"]:
		_refresh_forge(inst, chk)
		return
	var choices: Array = WeaponUpgrades.next_choices(inst)
	for pid in choices:
		var d: Dictionary = WeaponUpgrades.perk(pid)
		var card := Button.new()
		card.toggle_mode = true
		card.button_pressed = pid == chosen_perk
		card.custom_minimum_size = Vector2((W - RIGHT_X - 36) * 0.5, 124)
		card.text = "%s\n\n%s" % [d.get("name", pid), d.get("desc", "")]
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_override("font", FONT)
		card.add_theme_font_size_override("font_size", 12)
		card.pressed.connect(choose_perk.bind(pid))
		_perk_box.add_child(card)
	if choices.is_empty():
		var l := _label("No perk tree for this one (yet) — every level still gives it %d tuning points to make it your own." % WeaponUpgrades.POINTS_PER_LEVEL, 12, DIM)
		l.custom_minimum_size = Vector2(W - RIGHT_X - 24, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_perk_box.add_child(l)
	var to: int = inst.level + 1
	var cost := "%s costs %d scrap" % [WeaponUpgrades.tier_name(to), chk["scrap"]]
	if chk["feed_level"] > 0:
		cost += " + %s (stripped for parts)" % WeaponUpgrades.feed_label(inst, chk["feed_level"])
	cost += ".  +%d tuning points." % WeaponUpgrades.POINTS_PER_LEVEL
	if to == WeaponUpgrades.LEGENDARY_LEVEL:
		cost += "  It becomes LEGENDARY and earns a name."
	if not chk["ok"]:
		cost += "\n" + chk["reason"]
	_cost_label.text = cost
	_cost_label.add_theme_color_override("font_color", INK if chk["ok"] else BAD)
	_upgrade_btn.text = "Upgrade"
	_upgrade_btn.visible = true
	_upgrade_btn.disabled = not chk["ok"] or (not choices.is_empty() and chosen_perk == "")


# The heirloom forge: instalments + the crossing requirement.
func _refresh_forge(inst, chk: Dictionary) -> void:
	var to: int = inst.level + 1
	var need: Dictionary = WeaponUpgrades.HEIRLOOM[to]
	var total: int = int(need["scrap"])
	var head := _label("THE HEIRLOOM FORGE — %s" % WeaponUpgrades.tier_name(to), 13, LEGEND, FONT_BOLD)
	_forge_box.add_child(head)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = total
	bar.value = mini(inst.forge_paid, total)
	bar.custom_minimum_size = Vector2(W - RIGHT_X - 24, 18)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = LEGEND
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.25, 0.21, 0.18)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	_forge_box.add_child(bar)
	var info := _label("Scrap put in: %d / %d      Crossed the lobby door: %d / %d" % [inst.forge_paid, total, inst.crossings, int(need["crossings"])], 12, INK)
	_forge_box.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_forge_box.add_child(row)
	var owed: int = total - inst.forge_paid
	var b1 := Button.new()
	b1.text = "Put in %d" % mini(FORGE_STEP, maxi(owed, 0))
	b1.disabled = owed <= 0 or WorldState.scrap <= 0
	b1.pressed.connect(forge.bind(FORGE_STEP))
	row.add_child(b1)
	var b2 := Button.new()
	b2.text = "Put in all I can (%d)" % mini(WorldState.scrap, maxi(owed, 0))
	b2.disabled = owed <= 0 or WorldState.scrap <= 0
	b2.pressed.connect(forge.bind(owed))
	row.add_child(b2)
	var why := "Scrap put in stays IN the weapon — whoever carries it next can add more. Lose the weapon, lose it all."
	if inst.crossings < int(need["crossings"]):
		why += "\nIt can only become %s once it has been left by the lobby door and carried into a later game %d time%s." % [
			WeaponUpgrades.tier_name(to), int(need["crossings"]), "" if int(need["crossings"]) == 1 else "s"]
	_cost_label.text = why
	_cost_label.add_theme_color_override("font_color", DIM)
	# The tier completes the moment it's paid AND crossed (forge_heirloom) — no separate button.
	_upgrade_btn.visible = false


func _refresh_tune() -> void:
	_clear(_tune_grid)
	var inst = _selected()
	if inst == null or not WeaponUpgrades.can_upgrade(inst.item_id):
		_tune_head.text = "[color=#%s]Bring a weapon to tune.[/color]" % DIM.to_html(false)
		_points_label.text = ""
		_set_btn.disabled = true
		_name_row.visible = false
		return
	_tune_head.text = _header_bbcode(inst)
	var staged_total := 0
	for id in staged:
		staged_total += int(staged[id])
	var free: int = WeaponUpgrades.points_free(inst) - staged_total
	_points_label.text = "Points to spend: %d%s        (each rank:)" % [free, ("   (%d staged)" % staged_total) if staged_total > 0 else ""]
	if WeaponUpgrades.points_earned(inst) == 0:
		_points_label.text = "Upgrade it once to earn tuning points."
	for id in WeaponUpgrades.stats_for(inst.item_id):
		var st: Dictionary = WeaponUpgrades.stat(id)
		var have: int = int(inst.tuning.get(id, 0))
		var add: int = int(staged.get(id, 0))
		var cap: int = WeaponUpgrades.cap_for(inst, id)
		var n := _label(String(st["name"]), 12, INK, FONT_BOLD)
		n.custom_minimum_size = Vector2(96, 26)
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tune_grid.add_child(n)
		var pips := RichTextLabel.new()
		pips.bbcode_enabled = true
		pips.fit_content = false
		pips.scroll_active = false
		pips.custom_minimum_size = Vector2(120, 26)
		pips.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pips.add_theme_font_override("normal_font", FONT)
		pips.add_theme_font_size_override("normal_font_size", 12)
		pips.text = "[color=#%s]%s[/color][color=#%s]%s[/color][color=#%s]%s[/color]" % [
			GOLD.to_html(false), "# ".repeat(have), LEGEND.to_html(false), "+ ".repeat(add),
			DIM.to_html(false), "- ".repeat(maxi(0, cap - have - add))]
		_tune_grid.add_child(pips)
		var minus := Button.new()
		minus.text = "-"
		minus.custom_minimum_size = Vector2(28, 24)
		minus.disabled = add <= 0
		minus.pressed.connect(stage_point.bind(id, -1))
		_tune_grid.add_child(minus)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(28, 24)
		plus.disabled = free <= 0 or have + add >= cap
		plus.pressed.connect(stage_point.bind(id, 1))
		_tune_grid.add_child(plus)
		var d := _label(String(st["desc"]), 11, DIM)
		d.custom_minimum_size = Vector2(0, 24)
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
		var name: String = inst.get_display_name()
		if inst.count > 1:
			name += "  x%d" % inst.count
		if inst.level > 1:
			name += "  " + inst.tier_label()
		var n := _label(name, 12, LEGEND if inst.level >= WeaponUpgrades.LEGENDARY_LEVEL else INK, FONT_BOLD)
		n.custom_minimum_size = Vector2(290, 0)
		_salvage_grid.add_child(n)
		var st := _label(_condition(inst), 12, DIM)
		st.custom_minimum_size = Vector2(210, 0)
		_salvage_grid.add_child(st)
		var b := Button.new()
		b.custom_minimum_size = Vector2(210, 30)
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 12)
		var v: int = Salvage.value_of(inst)
		b.text = ("Confirm?  +%d scrap" if _confirm_salvage == inst else "Break down  +%d") % v
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
	var name: String = inst.get_display_name()
	var got: int = WorldState.salvage_item(slot)
	if got > 0:
		_play_clank()
		_say("%s broken down: +%d scrap." % [name, got])
	refresh()
	return got


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
