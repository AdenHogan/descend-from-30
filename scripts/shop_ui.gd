extends CanvasLayer

# Merchant shop screen (docs/STORE_DESIGN.md steps 4-5), in the LAMPLIGHT look (owner round 48l; scripts/lamp.gd): dark glass with brass corners and the kit's one type scale — the same
# look as the workbench, the rings and the found-item tag, no handwriting. The visit's offer of three is three cards; choosing one lights it (brass brackets, a CHOSEN tab), the other two
# are set aside and, a beat later, the choice is made. The wares are one row each (icon, name, one line about it, price, BUY) with the things you can SELL beside them; a purchase is
# confirmed with a second press (BUY -> SURE?). Everything is the same logic as before — only what you see and hear changed: `_on_take_upgrade` / `_on_buy_pressed` / `_on_sell_pressed` do
# exactly what they did (the bots and the tests call them directly); the lit card is the CLICK's flourish, played just before they run.

const SCREEN_W = 1152.0
const SCREEN_H = 648.0
const PANEL_W = 1040.0
const PANEL_H = 600.0
const PAD := 36.0
const STAMP_BEAT := 0.55                    # seconds a chosen card sits lit before the page moves on
const WARES_W := 620.0                      # the wares column; the sell column takes the rest
const ROW_H := 60.0
const SELL_ROW_H := 40.0

# The band of a ware sets its name's colour: plain cream, brass, bright brass (the kit has no neon; green / red only ever mean better / worse).
const BAND_COLORS = {
	"common": Lamp.TEXT,
	"quality": Lamp.BRASS,
	"legendary": Lamp.BRASS_HI,
}

var current_floor: int = 0
var stock: Array = []
var money_label: Label = null
var dialogue_label: Label = null
var detail_label: Label = null
var rows_box: VBoxContainer = null
var buy_buttons: Array = []
var pending_confirm: int = -1
var sell_box: VBoxContainer = null
var sell_buttons: Array = []
var pending_sell_confirm: int = -1
# Upgrades tab (step 6): the offer of three (pick one) leads the visit; shop is the
# errand. Tab bar lets you flip back to review owned upgrades.
var shop_content: HBoxContainer = null
var upgrades_box: VBoxContainer = null
var tab_shop_btn: LampButton = null
var tab_upg_btn: LampButton = null
var active_tab: String = "shop"
var refuse_armed: bool = false

var sheet: Control = null
var backdrop: TextureRect = null
var floor_label: Label = null
var _refuse_btn: LampButton = null
var _stamping: String = ""                   # the perk id whose card is being lit (clicks are ignored until the beat ends)
var _fresh_sold: int = -1                     # the ware just bought: its row dims live, not already dim
var _first_open: bool = true


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	backdrop = Lamp.backdrop()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE        # the shop never paused the game; the world stays clickable round it
	add_child(backdrop)

	sheet = Control.new()
	sheet.name = "Panel"
	sheet.position = Vector2((SCREEN_W - PANEL_W) / 2.0, 30)
	sheet.size = Vector2(PANEL_W, PANEL_H)
	sheet.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sheet)
	var glass := LampGlass.new()
	glass.corners = Lamp.ALL
	sheet.add_child(glass)

	# the head: the merchant, the floor, the player's notes; the two tabs on the same line
	var title := Lamp.label("MERCHANT", "head", Lamp.PX_TITLE, Lamp.TEXT)
	title.position = Vector2(PAD, 16)
	sheet.add_child(title)
	floor_label = Lamp.label("", "label", Lamp.PX_LABEL, Lamp.LABEL)
	floor_label.position = Vector2(PAD, 56)
	sheet.add_child(floor_label)
	tab_upg_btn = _tab_button("THE OFFER", "upgrades", Vector2(300, 18))
	tab_shop_btn = _tab_button("WARES", "shop", Vector2(456, 18))
	var close_btn := LampButton.new()
	close_btn.text = "×"
	close_btn.px = Lamp.PX_TITLE
	close_btn.position = Vector2(PANEL_W - PAD - 40.0, 16)
	close_btn.size = Vector2(40, 40)
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(close)
	sheet.add_child(close_btn)
	money_label = Lamp.label("", "head", Lamp.PX_TITLE, Lamp.BRASS)
	money_label.position = Vector2(PANEL_W - PAD - 40.0 - 14.0 - 130.0, 16)
	money_label.size = Vector2(130, 40)
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sheet.add_child(money_label)
	var notes_cap := Lamp.label("NOTES", "label", Lamp.PX_LABEL, Lamp.LABEL)
	notes_cap.position = Vector2(PANEL_W - PAD - 40.0 - 14.0 - 130.0 - 76.0, 16)
	notes_cap.size = Vector2(70, 40)
	notes_cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notes_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sheet.add_child(notes_cap)

	dialogue_label = Lamp.label("", "body", Lamp.PX_BODY, Lamp.SOFT, true)
	dialogue_label.position = Vector2(PAD, 80)
	dialogue_label.size = Vector2(PANEL_W - 2.0 * PAD, 24)
	dialogue_label.custom_minimum_size = Vector2(PANEL_W - 2.0 * PAD, 0)       # wrap within the panel — a long line (the handoff gift) must never stretch the shop off-screen
	sheet.add_child(dialogue_label)
	var rule := ColorRect.new()
	rule.color = Lamp.EDGE_DIM
	rule.position = Vector2(PAD, 124)
	rule.size = Vector2(PANEL_W - 2.0 * PAD, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(rule)

	# Upgrades tab content
	upgrades_box = VBoxContainer.new()
	upgrades_box.position = Vector2(PAD, 140)
	upgrades_box.size = Vector2(PANEL_W - 2.0 * PAD, PANEL_H - 140.0 - 24.0)
	upgrades_box.add_theme_constant_override("separation", 14)
	sheet.add_child(upgrades_box)

	# Shop tab content: the wares on the left, what you can sell on the right
	shop_content = HBoxContainer.new()
	shop_content.position = Vector2(PAD, 136)
	shop_content.size = Vector2(PANEL_W - 2.0 * PAD, PANEL_H - 136.0 - 20.0)
	shop_content.add_theme_constant_override("separation", 28)
	sheet.add_child(shop_content)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	shop_content.add_child(left)
	rows_box = VBoxContainer.new()
	rows_box.custom_minimum_size = Vector2(WARES_W, 0)
	rows_box.add_theme_constant_override("separation", 3)
	left.add_child(rows_box)
	detail_label = Lamp.label("", "body", Lamp.PX_BODY, Lamp.BODY, true)          # the whole description of the ware under the pointer (the rows keep one line each)
	detail_label.custom_minimum_size = Vector2(WARES_W, 52)
	left.add_child(detail_label)
	sell_box = VBoxContainer.new()
	sell_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_box.add_theme_constant_override("separation", 6)
	shop_content.add_child(sell_box)


func _tab_button(label: String, tab: String, pos: Vector2) -> LampButton:
	var b := LampButton.new()
	b.text = label
	b.position = pos
	b.size = Vector2(146, 40)
	b.custom_minimum_size = Vector2(146, 40)
	b.toggle_mode = true
	b.pressed.connect(func(): _show_tab(tab, true))
	sheet.add_child(b)
	return b


func open(floor_num: int, greeting: String) -> void:
	current_floor = floor_num
	stock = WorldState.get_merchant_stock(floor_num)
	dialogue_label.text = "\"" + greeting + "\""
	# Something left for this character by one who got out (the handoff) — hinted up front, handed
	# over once this visit's upgrade is settled.
	if WorldState.handoff_pending() and not WorldState.is_upgrade_offer_resolved(floor_num):
		dialogue_label.text += "\nSomething was left for you by the lobby door. It is yours once you have chosen."
	floor_label.text = ("FLOOR %d%s" % [floor_num, "" if WorldState.is_upgrade_offer_resolved(floor_num) else "   ·   FIRST VISIT"])
	pending_confirm = -1
	refuse_armed = false
	_stamping = ""
	_fresh_sold = -1
	_refresh()
	# The upgrade offer leads the visit until it is settled, then the shop.
	_show_tab("upgrades" if not WorldState.is_upgrade_offer_resolved(floor_num) else "shop", false)
	visible = true
	_arrive()


## The panel arrives: it settles a few px and the room dims behind it. A touch of sound; nothing that waits on the player.
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
	tab_upg_btn.button_pressed = tab == "upgrades"
	tab_shop_btn.button_pressed = tab == "shop"
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


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _refresh_upgrades() -> void:
	_clear(upgrades_box)
	_refuse_btn = null

	if WorldState.is_upgrade_offer_resolved(current_floor):
		_render_owned_upgrades()
		return

	var offer: Array = WorldState.get_upgrade_offer(current_floor)
	var intro := Lamp.label("", "label", Lamp.PX_LABEL, Lamp.BRASS)
	if offer.is_empty():
		intro.text = "NOTHING LEFT TO OFFER"
		upgrades_box.add_child(intro)
		_add_upgrade_button("CONTINUE TO THE WARES", func(): WorldState.resolve_upgrade_offer(current_floor, ""); _show_tab("shop"))
		return
	intro.text = "TAKE ONE OF THREE   ·   YOU KEEP IT FOR THE WHOLE DESCENT"
	upgrades_box.add_child(intro)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 20)
	upgrades_box.add_child(cards)
	var k := 0
	for id in offer:
		cards.add_child(_make_upgrade_card(id, k))
		k += 1

	# Refusal is a live choice (drawbacks make skipping sometimes right).
	var refuse := LampButton.new()
	refuse.custom_minimum_size = Vector2(230, 44)
	refuse.text = "TAKE NONE"
	refuse.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	refuse.pressed.connect(_on_refuse)
	upgrades_box.add_child(refuse)
	_refuse_btn = refuse


## The word printed on a card: how rare the perk is, or that it costs you something. (Rarity is the merchant's own weight `w` — docs/PERKS.md.)
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


## Its colour: a trade-off is the red the kit uses for "worse", a good turn the green for "better", the rest a brass that brightens with rarity.
static func rarity_ink(up: Dictionary) -> Color:
	if up.get("drawback", false):
		return Lamp.RED
	if up.get("kind", "") == "boon":
		return Lamp.GREEN
	var w := int(up.get("w", 3))
	if w >= 4:
		return Lamp.LABEL
	if w == 3:
		return Lamp.BRASS
	return Lamp.BRASS_HI


func _make_upgrade_card(id: String, index: int = 0) -> Control:
	var up: Dictionary = Progression.perk_info(id)
	var card := LampCard.new()
	card.name = "Card_" + id
	card.custom_minimum_size = Vector2((PANEL_W - 2.0 * PAD - 40.0) / 3.0, 230)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.margin = 18
	card.content.add_theme_constant_override("separation", 8)
	card.content.add_child(Lamp.label(rarity_word(up), "label", Lamp.PX_LABEL, rarity_ink(up)))
	var name_l := Lamp.label(String(up.get("name", id)), "head", Lamp.PX_NAME, Lamp.TEXT, true)
	name_l.custom_minimum_size = Vector2(card.custom_minimum_size.x - 2.0 * card.margin, 0)
	card.content.add_child(name_l)
	var desc := Lamp.label(String(up.get("desc", "")), "body", Lamp.PX_BODY, Lamp.BODY, true)
	desc.custom_minimum_size = Vector2(card.custom_minimum_size.x - 2.0 * card.margin, 0)    # a wrapping label needs a width to measure its height against
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.content.add_child(desc)
	card.content.add_child(Lamp.label("CLICK TO TAKE", "label", Lamp.PX_LABEL, Lamp.BRASS))
	card.chosen.connect(func(): _on_card_chosen(id, card))
	return card


## The click: light the card (brass brackets and a CHOSEN tab), set the other two aside, then let the page move on. The choice itself is `_on_take_upgrade` (unchanged); this is only its flourish.
func _on_card_chosen(id: String, card: Control) -> void:
	if _stamping != "":
		return
	_stamping = id
	if card is LampCard:
		(card as LampCard).held = true
	Ledger.play("pen", -9.0)
	for sib in card.get_parent().get_children():
		if sib != card and sib is Control:
			var t := create_tween().set_parallel(true)
			t.tween_property(sib, "modulate:a", 0.28, 0.3).set_delay(0.12)
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
	floor_label.text = ("FLOOR %d   ·   %s" % [current_floor, String(Progression.perk_info(id).get("name", id))]).to_upper()


func _on_refuse() -> void:
	if not refuse_armed:
		refuse_armed = true
		if _refuse_btn != null:
			_refuse_btn.text = "TAKE NONE — SURE?"
			_refuse_btn.tone = Lamp.RED
			_refuse_btn.queue_redraw()
		HUD.show_feedback("Click again to take none of them.")
		return
	WorldState.resolve_upgrade_offer(current_floor, "")
	_show_tab("shop")


func _render_owned_upgrades() -> void:
	upgrades_box.add_child(Lamp.label("YOURS THIS DESCENT", "label", Lamp.PX_LABEL, Lamp.BRASS))
	if WorldState.active_upgrades.is_empty():
		upgrades_box.add_child(Lamp.label("Nothing yet.", "body", Lamp.PX_BODY, Lamp.DIM))
	for id in WorldState.active_upgrades:
		var up: Dictionary = Progression.perk_info(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		upgrades_box.add_child(row)
		var nm := Lamp.label(String(up.get("name", id)), "head", Lamp.PX_NAME, Lamp.TEXT)
		nm.custom_minimum_size = Vector2(280, 0)
		nm.clip_text = true
		row.add_child(nm)
		var ds := Lamp.label(String(up.get("desc", "")), "body", Lamp.PX_BODY, Lamp.SOFT)
		ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ds.clip_text = true
		ds.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(ds)


func _add_upgrade_button(text: String, cb: Callable) -> void:
	var b := LampButton.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 44)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	upgrades_box.add_child(b)


func _refresh() -> void:
	_clear(rows_box)
	buy_buttons.clear()
	if detail_label != null:
		detail_label.text = ""

	for i in range(stock.size()):
		var entry = stock[i]
		var item_data = ItemData.get_item(entry["item_id"])
		var ink: Color = BAND_COLORS.get(entry["band"], Lamp.TEXT)
		var sold: bool = bool(entry["sold"])

		var holder := PanelContainer.new()                  # one ware: a dark card
		holder.custom_minimum_size = Vector2(WARES_W, ROW_H)
		var card := StyleBoxFlat.new()
		card.bg_color = Lamp.CARD
		card.border_color = Lamp.EDGE
		card.set_border_width_all(1)
		card.content_margin_left = 6
		card.content_margin_right = 10
		card.content_margin_top = 2
		card.content_margin_bottom = 2
		holder.add_theme_stylebox_override("panel", card)
		holder.mouse_filter = Control.MOUSE_FILTER_PASS
		holder.mouse_entered.connect(_show_ware_detail.bind(i))
		rows_box.add_child(holder)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		holder.add_child(row)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(56, 56)     # the icon 1:1 (it's drawn 56x56)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = ItemData.get_texture(entry["item_id"])
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.alignment = BoxContainer.ALIGNMENT_CENTER
		text_box.add_theme_constant_override("separation", -2)
		row.add_child(text_box)
		var name_label := Lamp.label(ware_title(entry), "head", Lamp.PX_NAME, ink)
		name_label.clip_text = true
		text_box.add_child(name_label)
		var desc_label := Lamp.label(String(item_data.get("description", "")), "body", Lamp.PX_LABEL, Lamp.SOFT)
		desc_label.clip_text = true                                    # one line about it; a longer one is trimmed, never wrapped over the next ware
		desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text_box.add_child(desc_label)

		var price_label := Lamp.label(str(int(entry["price"])), "head", Lamp.PX_NAME, Lamp.BRASS if not sold else Lamp.DIM)
		price_label.custom_minimum_size = Vector2(60, 0)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(price_label)

		var buy_btn := LampButton.new()
		buy_btn.custom_minimum_size = Vector2(110, 40)
		buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if sold:
			buy_btn.text = "SOLD"
			buy_btn.disabled = true
			name_label.add_theme_color_override("font_color", Lamp.DIM)
			desc_label.add_theme_color_override("font_color", Lamp.DIM)
			holder.modulate = Color(1, 1, 1, 0.55)
			if i == _fresh_sold:                                       # the sale just made: it dims live, from lit
				_fresh_sold = -1
				holder.modulate = Color(1.5, 1.25, 0.8, 1.0)
				create_tween().tween_property(holder, "modulate", Color(1, 1, 1, 0.55), 0.4)
		else:
			buy_btn.text = "BUY"
			buy_btn.pressed.connect(_on_buy_pressed.bind(i))
		row.add_child(buy_btn)
		buy_buttons.append(buy_btn)

	_refresh_sell_section()
	_update_money_label()


## A ware's title: its name, what a bundle holds ("Bullets x9"), and - for a weapon - its level (the merchant sells plain ones: Lv1).
func ware_title(entry: Dictionary) -> String:
	var id: String = String(entry.get("item_id", ""))
	var t: String = String(ItemData.get_item(id).get("name", "???"))
	var n: int = int(entry.get("amount", 0))
	if n > 1:
		t += " x%d" % n
	if WeaponUpgrades.can_upgrade(id):
		t += "  ·  %s" % WeaponUpgrades.tier_name(1)
	return t


## A carried item's title in the SELL column: its name, its stack, and a weapon's level (Lv1 .. Legendary +++).
func sell_title(inst) -> String:
	var t: String = inst.get_display_name()
	if WeaponUpgrades.can_upgrade(inst.item_id):
		t += "  ·  %s" % WeaponUpgrades.tier_name(inst.level)
	elif inst.count > 1:
		t += " x%d" % inst.count
	return t


## The whole description of ware `i` under the rows (each row shows one line of it).
func _show_ware_detail(i: int) -> void:
	if detail_label == null or i < 0 or i >= stock.size():
		return
	detail_label.text = String(ItemData.get_item(stock[i]["item_id"]).get("description", ""))


func _refresh_sell_section() -> void:
	_clear(sell_box)
	sell_buttons.clear()
	pending_sell_confirm = -1

	var remaining = WorldState.get_sales_remaining(current_floor)
	sell_box.add_child(Lamp.label("SELL", "label", Lamp.PX_LABEL, Lamp.BRASS))
	var note := Lamp.label("", "body", Lamp.PX_BODY, Lamp.SOFT, true)
	note.custom_minimum_size = Vector2(300, 0)
	sell_box.add_child(note)
	if remaining <= 0:
		note.text = "He has bought all he will this visit."
		return
	note.text = "He buys up to %d things a visit. %d left." % [WorldState.SELL_LIMIT_PER_VISIT, remaining]

	for i in range(WorldState.inventory.size()):
		var instance = WorldState.get_instance_at(i)
		var price: int = WorldState.sell_price_of(instance)
		if price <= 0:
			sell_buttons.append(null)
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.custom_minimum_size = Vector2(0, SELL_ROW_H)
		sell_box.add_child(row)
		var name_label := Lamp.label(sell_title(instance), "head", Lamp.PX_BODY, Lamp.TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		row.add_child(name_label)
		var price_label := Lamp.label(str(price), "head", Lamp.PX_BODY, Lamp.GREEN)
		price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(price_label)
		var btn := LampButton.new()
		btn.text = "SELL"
		btn.custom_minimum_size = Vector2(88, 36)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	var why: String = WorldState.sell_blocker(slot_index)
	if why != "":
		HUD.show_feedback(why, true)
	elif WorldState.sell_item(slot_index, current_floor):
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
		buy_buttons[index].text = "SURE?"
		return

	pending_confirm = -1
	var entry = stock[index]
	var price = int(entry["price"])

	if WorldState.get_money_total() < price:
		HUD.show_feedback("Not enough notes.", true)
		buy_buttons[index].text = "BUY"
		if buy_buttons[index].has_method("refuse"):
			buy_buttons[index].refuse()
		return
	if not WorldState.add_to_inventory(entry["item_id"], int(entry.get("amount", 0))):
		HUD.show_feedback("Inventory full.", true)
		buy_buttons[index].text = "BUY"
		if buy_buttons[index].has_method("refuse"):
			buy_buttons[index].refuse()
		return

	WorldState.spend_money(price)
	WorldState.mark_shop_item_sold(current_floor, index)
	HUD.refresh_inventory()
	HUD.show_feedback(ware_title(entry).split("  ·")[0] + " bought.")
	Ledger.play("notes", -8.0)
	_fresh_sold = index
	_refresh()
