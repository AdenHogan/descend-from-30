extends CanvasLayer

# Merchant shop screen (docs/STORE_DESIGN.md steps 4-5), in the LEDGER look (owner round 48j; scripts/ledger.gd): one sheet of ruled paper on the desk. The visit's offer of three is
# three slips taped to the page; taking one stamps it, the other two are set aside, and the choice is written into the book. The wares are a ruled column; a purchase is signed for
# (a first press circles it, the second stamps SOLD). Everything is the same logic as before — only what you see and hear changed: `_on_take_upgrade` / `_on_buy_pressed` /
# `_on_sell_pressed` do exactly what they did (the bots and the tests call them directly); the stamp is the CLICK's flourish, played just before they run.

const SCREEN_W = 1152.0
const SCREEN_H = 648.0
const PANEL_W = 960.0
const PANEL_H = 584.0
const STAMP_BEAT := 0.55                    # seconds the stamp sits on a taken slip before the page moves on

# Each band is an INK on the ledger (a printed ledger has no neon): plain, blue pen, and the dark gold of a thing worth a second look.
const BAND_COLORS = {
	"common": Ledger.INK,
	"quality": Ledger.BLUE_INK,
	"legendary": Ledger.GOLD_INK,
}

var current_floor: int = 0
var stock: Array = []
var money_label: Label = null
var dialogue_label: Label = null
var rows_box: VBoxContainer = null
var buy_buttons: Array = []
var pending_confirm: int = -1
var sell_box: VBoxContainer = null
var sell_buttons: Array = []
var pending_sell_confirm: int = -1
# Upgrades tab (step 6): the offer of three (pick one) leads the visit; shop is the
# errand. Tab bar lets you flip back to review owned upgrades.
var shop_content: VBoxContainer = null
var upgrades_box: VBoxContainer = null
var tab_shop_btn: Button = null
var tab_upg_btn: Button = null
var active_tab: String = "shop"
var refuse_armed: bool = false

var sheet: LedgerSheet = null
var backdrop: TextureRect = null
var floor_label: Label = null
var _refuse_btn: Button = null
var _stamping: String = ""                   # the perk id whose slip is being stamped (clicks are ignored until the beat ends)
var _fresh_sold: int = -1                     # the ware just bought: its SOLD stamp is pressed live, not shown already down
var _stamps: Dictionary = {}                  # ware index -> its LedgerStamp, so a fresh sale can be pressed
var _first_open: bool = true


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	# the room goes dim round the page: a vignette, not a flat wash — the middle of the screen stays the world
	backdrop = TextureRect.new()
	backdrop.name = "Backdrop"
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.10), Color(0.02, 0.012, 0.008, 0.62)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.46)
	gt.fill_to = Vector2(1.0, 1.0)
	gt.width = 256
	gt.height = 144
	backdrop.texture = gt
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.size = Vector2(SCREEN_W, SCREEN_H)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	sheet = LedgerSheet.new()
	sheet.name = "Panel"
	sheet.seed_value = 20
	sheet.position = Vector2((SCREEN_W - PANEL_W) / 2.0, 30)
	sheet.size = Vector2(PANEL_W, PANEL_H)
	sheet.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	sheet.rule_first = 118.0
	sheet.margin_x = 80.0
	add_child(sheet)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 104)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	sheet.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# the head of the page: the merchant's name printed, the floor and the player's notes in the player's own hand
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	vbox.add_child(header)

	var title = Ledger.label("MERCHANT", "head", 46, Ledger.INK)
	header.add_child(title)

	floor_label = Ledger.label("", "hand", 24, Ledger.hand_ink())
	floor_label.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(floor_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)

	var notes_box = VBoxContainer.new()                 # the player's notes: a small printed word over a number in their own hand
	notes_box.add_theme_constant_override("separation", -4)
	header.add_child(notes_box)
	var notes_head = Ledger.label("NOTES", "head", 16, Ledger.INK_SOFT)
	notes_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	notes_box.add_child(notes_head)
	money_label = Ledger.label("", "hand", 36, Ledger.hand_ink())
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	notes_box.add_child(money_label)

	dialogue_label = Ledger.label("", "typed", 15, Ledger.INK_SOFT, true)
	# Wrap within the page — a long line (the handoff gift) must never stretch the shop off-screen.
	dialogue_label.custom_minimum_size = Vector2(PANEL_W - 190, 0)
	vbox.add_child(dialogue_label)

	# tabs: two ruled boxes, the one you are on inked in
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	vbox.add_child(tabs)
	tab_upg_btn = _tab_button("THE OFFER", "upgrades")
	tabs.add_child(tab_upg_btn)
	tab_shop_btn = _tab_button("WARES", "shop")
	tabs.add_child(tab_shop_btn)

	var rule = LedgerRule.new()
	rule.seed_value = 8
	rule.double = true
	vbox.add_child(rule)

	# Upgrades tab content
	upgrades_box = VBoxContainer.new()
	upgrades_box.add_theme_constant_override("separation", 10)
	upgrades_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(upgrades_box)

	# Shop tab content (wares + sell)
	shop_content = VBoxContainer.new()
	shop_content.add_theme_constant_override("separation", 6)
	shop_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(shop_content)

	rows_box = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 2)
	rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_content.add_child(rows_box)

	var rule2 = LedgerRule.new()
	rule2.seed_value = 12
	shop_content.add_child(rule2)
	sell_box = VBoxContainer.new()
	sell_box.add_theme_constant_override("separation", 2)
	shop_content.add_child(sell_box)

	var foot = HBoxContainer.new()
	vbox.add_child(foot)
	var foot_sp = Control.new()
	foot_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot_sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(foot_sp)
	var close_btn = LedgerButton.new()
	close_btn.text = "LEAVE"
	close_btn.custom_minimum_size = Vector2(140, 40)
	close_btn.seed_value = 31
	close_btn.pressed.connect(close)
	foot.add_child(close_btn)


func _tab_button(label: String, tab: String) -> Button:
	var b := LedgerButton.new()
	b.text = label
	b.px = 18
	b.custom_minimum_size = Vector2(150, 34)
	b.seed_value = 41 if tab == "shop" else 40
	b.pressed.connect(func(): _show_tab(tab, true))
	return b


func open(floor_num: int, greeting: String) -> void:
	current_floor = floor_num
	stock = WorldState.get_merchant_stock(floor_num)
	dialogue_label.text = "\"" + greeting + "\""
	# Something left for this character by one who got out (the handoff) — hinted up front, handed
	# over once this visit's upgrade is settled.
	if WorldState.handoff_pending() and not WorldState.is_upgrade_offer_resolved(floor_num):
		dialogue_label.text += "\nSomething was left for you by the lobby door. It is yours once you have chosen."
	floor_label.text = "Floor %d%s" % [floor_num, "" if WorldState.is_upgrade_offer_resolved(floor_num) else " — first visit"]
	floor_label.add_theme_font_override("font", Ledger.font("hand"))      # the hand follows the run's character
	floor_label.add_theme_color_override("font_color", Ledger.hand_ink())
	money_label.add_theme_font_override("font", Ledger.font("hand"))
	money_label.add_theme_color_override("font_color", Ledger.hand_ink())
	pending_confirm = -1
	refuse_armed = false
	_stamping = ""
	_fresh_sold = -1
	_refresh()
	# The upgrade offer leads the visit until it is settled, then the shop.
	_show_tab("upgrades" if not WorldState.is_upgrade_offer_resolved(floor_num) else "shop", false)
	visible = true
	_arrive()


## The page is set down on the desk: it settles a few px and the room dims behind it. A touch of sound; nothing that waits on the player.
func _arrive() -> void:
	Ledger.play("sheet", -7.0)
	var base_y := 30.0
	sheet.position.y = base_y + 14.0
	sheet.modulate.a = 0.0
	backdrop.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(sheet, "position:y", base_y, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(sheet, "modulate:a", 1.0, 0.18)
	t.tween_property(backdrop, "modulate:a", 1.0, 0.32)
	_first_open = false


func _show_tab(tab: String, user: bool = false) -> void:
	if user and tab == active_tab:
		return
	if user:
		Ledger.play("page", -9.0)
	active_tab = tab
	refuse_armed = false
	upgrades_box.visible = tab == "upgrades"
	shop_content.visible = tab == "shop"
	tab_upg_btn.solid = tab == "upgrades"
	tab_shop_btn.solid = tab == "shop"
	sheet.ruled = tab == "upgrades"                # the slips lie on ruled paper; the wares column rules itself
	sheet.queue_redraw()
	tab_upg_btn.queue_redraw()
	tab_shop_btn.queue_redraw()
	if tab == "upgrades":
		_refresh_upgrades()
		return
	if WorldState.is_upgrade_offer_resolved(current_floor):
		_give_handoff_gift()                  # the gift follows the upgrade pick


# THE GIFT (owner): after the visit's upgrade, the shopkeeper hands over what an escaped character
# left behind — free. What doesn't fit stays with him for a later visit (never lost).
func _give_handoff_gift() -> Dictionary:
	if not WorldState.handoff_pending():
		return {"given": [], "kept": []}
	var res: Dictionary = WorldState.collect_handoff_gifts()
	var lines: Array = []
	if not res["given"].is_empty():
		lines.append("Left by the lobby door by someone who got out: %s. Free." % ", ".join(res["given"]))
		HUD.refresh_inventory()
		HUD.show_feedback("Gift: " + ", ".join(res["given"]))
	if not res["kept"].is_empty():
		lines.append("Your pockets are full. The %s waits here until you have room." % ", ".join(res["kept"]))
	dialogue_label.text = "\n".join(lines)
	_refresh()
	return res


func close() -> void:
	if visible:
		Ledger.play("page", -12.0)
	visible = false
	pending_confirm = -1
	_stamping = ""


func _refresh_upgrades() -> void:
	for child in upgrades_box.get_children():
		child.queue_free()
	_refuse_btn = null

	if WorldState.is_upgrade_offer_resolved(current_floor):
		_render_owned_upgrades()
		return

	var offer: Array = WorldState.get_upgrade_offer(current_floor)
	var intro = Ledger.label("", "head", 19, Ledger.RED_INK)
	if offer.is_empty():
		intro.text = "NOTHING LEFT TO OFFER"
		upgrades_box.add_child(intro)
		_add_upgrade_button("CONTINUE TO THE WARES", func(): WorldState.resolve_upgrade_offer(current_floor, ""); _show_tab("shop"))
		return
	intro.text = "TAKE ONE OF THREE  ·  IT STAYS WITH YOU THROUGH THE WHOLE DESCENT"
	upgrades_box.add_child(intro)

	var cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 22)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upgrades_box.add_child(cards)
	var k := 0
	for id in offer:
		cards.add_child(_make_upgrade_card(id, k))
		k += 1

	# Refusal is a live choice (drawbacks make skipping sometimes right).
	var refuse = LedgerButton.new()
	refuse.custom_minimum_size = Vector2(190, 36)
	refuse.text = "TAKE NONE"
	refuse.px = 17
	refuse.ink = Ledger.INK_SOFT
	refuse.seed_value = 52
	refuse.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	refuse.pressed.connect(_on_refuse)
	upgrades_box.add_child(refuse)
	_refuse_btn = refuse


## The word printed on a slip: how rare the perk is, or that it costs you something. (Rarity is the merchant's own weight `w` — docs/PERKS.md.)
static func rarity_word(up: Dictionary) -> String:
	if up.get("drawback", false):
		return "TRADE-OFF"
	if up.get("kind", "") == "boon":
		return "A GOOD TURN"
	var w := int(up.get("w", 3))
	if w >= 4:
		return "COMMON"
	if w == 3:
		return "UNCOMMON"
	return "RARE"


static func rarity_ink(up: Dictionary) -> Color:
	if up.get("drawback", false):
		return Ledger.RED_INK
	var w := int(up.get("w", 3))
	if up.get("kind", "") == "boon" or w == 3:
		return Ledger.BLUE_INK
	if w <= 2:
		return Ledger.GOLD_INK
	return Ledger.INK_SOFT


func _make_upgrade_card(id: String, index: int = 0) -> Control:
	var up: Dictionary = Progression.perk_info(id)
	var slip := LedgerSlip.new()
	slip.name = "Slip_" + id
	slip.seed_value = 100 + index * 17 + id.hash() % 50
	slip.tilt_deg = [-0.8, 0.5, -0.4][index % 3]
	slip.custom_minimum_size = Vector2(250, 262)
	slip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	slip.content.add_child(box)
	var ink := rarity_ink(up)
	var tag = Ledger.label(rarity_word(up), "head", 15, ink)
	box.add_child(tag)
	var name_l = Ledger.label(String(up.get("name", id)), "head", 34, Ledger.INK)
	box.add_child(name_l)
	slip.underline_target = name_l
	var desc = Ledger.label(String(up.get("desc", "")), "body", 17, Ledger.INK, true)
	desc.custom_minimum_size = Vector2(slip.custom_minimum_size.x - 2.0 * slip.margin - 6.0, 0)    # a wrapping label needs a width to measure its height against
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc)
	var take = LedgerButton.new()
	take.text = "TAKE"
	take.px = 20
	take.seed_value = 60 + index
	take.pressed.connect(func(): _on_card_chosen(id, slip))
	box.add_child(take)
	var stamp := LedgerStamp.new()
	stamp.word = "TAKEN"
	stamp.px = 36
	stamp.seed_value = 10 + index
	stamp.tilt_deg = -8.0 + 3.0 * index
	stamp.centre = Vector2(0.5, 0.66)
	stamp.name = "Stamp"
	stamp.set_anchors_preset(Control.PRESET_FULL_RECT)
	slip.add_child(stamp)
	return slip


## The click: stamp the slip, set the other two aside, then let the page move on. The choice itself is `_on_take_upgrade` (unchanged); this is only its flourish.
func _on_card_chosen(id: String, slip: LedgerSlip) -> void:
	if _stamping != "":
		return
	_stamping = id
	var stamp := slip.get_node_or_null("Stamp") as LedgerStamp
	if stamp != null:
		stamp.play(sheet)
	for sib in slip.get_parent().get_children():
		if sib != slip and sib is Control:
			var t := create_tween().set_parallel(true)
			t.tween_property(sib, "modulate:a", 0.28, 0.3).set_delay(0.12)
			t.tween_property(sib, "scale", Vector2(0.96, 0.96), 0.3).set_delay(0.12)
	await get_tree().create_timer(STAMP_BEAT).timeout
	if visible and _stamping == id:
		_stamping = ""
		_on_take_upgrade(id)


func _on_take_upgrade(id: String) -> void:
	WorldState.resolve_upgrade_offer(current_floor, id)
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		HUD.update_stamina(WorldState.stamina, WorldState.get_max_stamina())
	HUD.refresh_inventory()
	HUD.show_feedback("Upgrade: " + String(Progression.perk_info(id).get("name", id)))
	_show_tab("shop")
	Ledger.play("pen", -9.0)                       # the choice is written down
	floor_label.text = "Floor %d — %s" % [current_floor, String(Progression.perk_info(id).get("name", id))]


func _on_refuse() -> void:
	if not refuse_armed:
		refuse_armed = true
		if _refuse_btn != null:
			_refuse_btn.text = "TAKE NONE — SURE?"
			_refuse_btn.ink = Ledger.RED_INK
			_refuse_btn.queue_redraw()
		HUD.show_feedback("Click again to take none of them.")
		return
	WorldState.resolve_upgrade_offer(current_floor, "")
	_show_tab("shop")


func _render_owned_upgrades() -> void:
	var header = Ledger.label("ACQUIRED THIS DESCENT", "head", 19, Ledger.RED_INK)
	upgrades_box.add_child(header)
	if WorldState.active_upgrades.is_empty():
		var none = Ledger.label("(none yet)", "hand", 20, Ledger.hand_ink())
		upgrades_box.add_child(none)
	for id in WorldState.active_upgrades:
		var up: Dictionary = Progression.perk_info(id)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		upgrades_box.add_child(row)
		row.add_child(Ledger.label(String(up.get("name", id)), "head", 22, Ledger.INK))
		row.add_child(Ledger.label(String(up.get("desc", "")), "body", 16, Ledger.INK_SOFT))


func _add_upgrade_button(text: String, cb: Callable) -> void:
	var b = LedgerButton.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 38)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	upgrades_box.add_child(b)


func _refresh() -> void:
	for child in rows_box.get_children():
		child.queue_free()
	buy_buttons.clear()
	_stamps.clear()

	for i in range(stock.size()):
		var entry = stock[i]
		var item_data = ItemData.get_item(entry["item_id"])
		var ink: Color = BAND_COLORS.get(entry["band"], Ledger.INK)

		var holder = MarginContainer.new()               # the line and, over it, a stamp if it is sold
		rows_box.add_child(holder)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		holder.add_child(row)

		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(56, 56)     # the icon 1:1 (it's drawn 56x56)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = ItemData.get_texture(entry["item_id"])
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

		var text_box = VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_theme_constant_override("separation", 0)
		row.add_child(text_box)

		var name_label = Ledger.label(String(item_data.get("name", "???")), "head", 24, ink)
		text_box.add_child(name_label)

		var desc_label = Ledger.label(String(item_data.get("description", "")), "body", 14, Ledger.INK_SOFT, true)
		text_box.add_child(desc_label)

		var price_label = Ledger.label(str(int(entry["price"])), "typed", 22, ink)
		price_label.custom_minimum_size = Vector2(64, 0)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(price_label)

		var buy_btn = LedgerButton.new()
		buy_btn.custom_minimum_size = Vector2(104, 34)
		buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy_btn.px = 18
		buy_btn.seed_value = 70 + i
		if entry["sold"]:
			buy_btn.text = "SOLD"
			buy_btn.disabled = true
		else:
			buy_btn.text = "BUY"
			buy_btn.pressed.connect(_on_buy_pressed.bind(i))
		row.add_child(buy_btn)
		buy_buttons.append(buy_btn)
		# a sold line is crossed out and stamped; one sold just now is stamped in front of the player
		if entry["sold"]:
			var stamp := LedgerStamp.new()
			stamp.word = "SOLD"
			stamp.px = 26
			stamp.seed_value = 30 + i
			stamp.tilt_deg = -4.0
			holder.add_child(stamp)
			_stamps[i] = stamp
			if i == _fresh_sold:
				_fresh_sold = -1
				stamp.play.call_deferred(sheet)
			else:
				stamp.set_down.call_deferred()
			name_label.add_theme_color_override("font_color", Ledger.INK_FAINT)
			price_label.add_theme_color_override("font_color", Ledger.INK_FAINT)
		if i < stock.size() - 1:
			var rl = LedgerRule.new()
			rl.seed_value = 200 + i
			rl.colour = Ledger.INK_FAINT
			rows_box.add_child(rl)

	_refresh_sell_section()
	_update_money_label()


func _refresh_sell_section() -> void:
	for child in sell_box.get_children():
		child.queue_free()
	sell_buttons.clear()
	pending_sell_confirm = -1

	var remaining = WorldState.get_sales_remaining(current_floor)
	var header = Ledger.label("", "head", 17, Ledger.INK_SOFT)
	if remaining <= 0:
		header.text = "SELLING  —  \"Not in a position to buy more right now.\""
		sell_box.add_child(header)
		return
	header.text = "SELLING  —  the merchant will take %d more item%s this visit" % [remaining, "" if remaining == 1 else "s"]
	sell_box.add_child(header)

	for i in range(WorldState.inventory.size()):
		var instance = WorldState.get_instance_at(i)
		var price = WorldState.get_sell_price(instance.item_id)
		if price <= 0:
			sell_buttons.append(null)
			continue
		if ItemData.get_item(instance.item_id).get("is_ammo", false):
			price *= instance.count
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		sell_box.add_child(row)
		var name_label = Ledger.label(instance.get_display_name(), "body", 16, Ledger.INK)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var price_label = Ledger.label(str(price), "typed", 16, Ledger.GREEN_INK)
		row.add_child(price_label)
		var btn = LedgerButton.new()
		btn.text = "SELL"
		btn.px = 16
		btn.seed_value = 90 + i
		btn.custom_minimum_size = Vector2(84, 28)
		btn.pressed.connect(_on_sell_pressed.bind(i))
		row.add_child(btn)
		sell_buttons.append(btn)


func _on_sell_pressed(slot_index: int) -> void:
	if pending_sell_confirm != slot_index:
		if pending_sell_confirm >= 0 and pending_sell_confirm < sell_buttons.size() \
				and sell_buttons[pending_sell_confirm] != null:
			sell_buttons[pending_sell_confirm].text = "SELL"
		pending_sell_confirm = slot_index
		if slot_index < sell_buttons.size() and sell_buttons[slot_index] != null:
			sell_buttons[slot_index].text = "SURE?"
		return
	pending_sell_confirm = -1
	if WorldState.sell_item(slot_index, current_floor):
		HUD.show_feedback("Sold.")
		Ledger.play("notes", -9.0)
	_refresh_sell_section()
	_update_money_label()


func _update_money_label() -> void:
	money_label.text = str(WorldState.get_money_total())


func _on_buy_pressed(index: int) -> void:
	# Two-click confirm: first press arms the purchase, second commits it.
	if pending_confirm != index:
		if pending_confirm >= 0 and pending_confirm < buy_buttons.size() and \
				not buy_buttons[pending_confirm].disabled:
			buy_buttons[pending_confirm].text = "BUY"
		pending_confirm = index
		buy_buttons[index].text = "SIGN?"
		return

	pending_confirm = -1
	var entry = stock[index]
	var price = int(entry["price"])

	if WorldState.get_money_total() < price:
		HUD.show_feedback("Not enough notes.")
		buy_buttons[index].text = "BUY"
		if buy_buttons[index].has_method("refuse"):
			buy_buttons[index].refuse()
		return
	if not WorldState.add_to_inventory(entry["item_id"]):
		HUD.show_feedback("Inventory full.")
		buy_buttons[index].text = "BUY"
		if buy_buttons[index].has_method("refuse"):
			buy_buttons[index].refuse()
		return

	WorldState.spend_money(price)
	WorldState.mark_shop_item_sold(current_floor, index)
	HUD.refresh_inventory()
	var item_data = ItemData.get_item(entry["item_id"])
	HUD.show_feedback(item_data.get("name", "Item") + " purchased.")
	Ledger.play("notes", -8.0)
	_fresh_sold = index
	_refresh()
