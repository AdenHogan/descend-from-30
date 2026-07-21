extends CanvasLayer

# Merchant shop screen (docs/STORE_DESIGN.md steps 4-5). One panel listing the
# visit's seeded stock; buying debits the wallet/notes stack via
# WorldState.spend_money. The upgrades tab (step 6) is not built yet.

const SCREEN_W = 1152.0
const SCREEN_H = 648.0
const PANEL_W = 780.0
const PANEL_H = 470.0

const BAND_COLORS = {
	"common": Color(0.85, 0.85, 0.85, 1.0),
	"quality": Color(0.45, 0.7, 1.0, 1.0),
	"legendary": Color(1.0, 0.8, 0.2, 1.0),
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
# Upgrades tab (step 6): the pick-1-of-2 offer leads the visit; shop is the
# errand. Tab bar lets you flip back to review owned upgrades.
var shop_content: VBoxContainer = null
var upgrades_box: VBoxContainer = null
var tab_shop_btn: Button = null
var tab_upg_btn: Button = null
var active_tab: String = "shop"
var refuse_armed: bool = false


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.position = Vector2((SCREEN_W - PANEL_W) / 2, 36)
	panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.96)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.5, 0.45, 0.3, 1.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var header = HBoxContainer.new()
	vbox.add_child(header)

	var title = Label.new()
	title.text = "MERCHANT"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 14)
	money_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55, 1.0))
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(money_label)

	dialogue_label = Label.new()
	dialogue_label.add_theme_font_size_override("font_size", 12)
	dialogue_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6, 1.0))
	vbox.add_child(dialogue_label)

	# Tab bar
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	vbox.add_child(tabs)
	tab_upg_btn = Button.new()
	tab_upg_btn.text = "UPGRADES"
	tab_upg_btn.custom_minimum_size = Vector2(150, 28)
	tab_upg_btn.pressed.connect(func(): _show_tab("upgrades"))
	tabs.add_child(tab_upg_btn)
	tab_shop_btn = Button.new()
	tab_shop_btn.text = "SHOP"
	tab_shop_btn.custom_minimum_size = Vector2(150, 28)
	tab_shop_btn.pressed.connect(func(): _show_tab("shop"))
	tabs.add_child(tab_shop_btn)

	vbox.add_child(HSeparator.new())

	# Upgrades tab content
	upgrades_box = VBoxContainer.new()
	upgrades_box.add_theme_constant_override("separation", 8)
	upgrades_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(upgrades_box)

	# Shop tab content (wares + sell)
	shop_content = VBoxContainer.new()
	shop_content.add_theme_constant_override("separation", 6)
	shop_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(shop_content)

	rows_box = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 4)
	rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_content.add_child(rows_box)

	shop_content.add_child(HSeparator.new())
	sell_box = VBoxContainer.new()
	sell_box.add_theme_constant_override("separation", 2)
	shop_content.add_child(sell_box)

	var close_btn = Button.new()
	close_btn.text = "Leave"
	close_btn.custom_minimum_size = Vector2(120, 32)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(close)
	vbox.add_child(close_btn)


func open(floor_num: int, greeting: String) -> void:
	current_floor = floor_num
	stock = WorldState.get_merchant_stock(floor_num)
	dialogue_label.text = "\"" + greeting + "\""
	pending_confirm = -1
	refuse_armed = false
	_refresh()
	# The boon is the event: the upgrade offer leads the visit until resolved,
	# then re-opening goes straight to the shop.
	_show_tab("upgrades" if not WorldState.is_upgrade_offer_resolved(floor_num) else "shop")
	visible = true


func _show_tab(tab: String) -> void:
	active_tab = tab
	refuse_armed = false
	upgrades_box.visible = tab == "upgrades"
	shop_content.visible = tab == "shop"
	tab_upg_btn.disabled = tab == "upgrades"
	tab_shop_btn.disabled = tab == "shop"
	if tab == "upgrades":
		_refresh_upgrades()


func close() -> void:
	visible = false
	pending_confirm = -1


func _refresh_upgrades() -> void:
	for child in upgrades_box.get_children():
		child.queue_free()

	if WorldState.is_upgrade_offer_resolved(current_floor):
		_render_owned_upgrades()
		return

	var pair = WorldState.get_upgrade_pair(current_floor)
	var intro = Label.new()
	intro.add_theme_font_size_override("font_size", 13)
	intro.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6, 1.0))
	if pair.is_empty():
		intro.text = "\"Nothing left to teach you, friend.\""
		upgrades_box.add_child(intro)
		_add_upgrade_button("Continue to shop", func(): WorldState.resolve_upgrade_offer(current_floor, ""); _show_tab("shop"))
		return
	intro.text = "Choose one — it stays with you for the whole descent."
	upgrades_box.add_child(intro)

	var cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	upgrades_box.add_child(cards)
	for id in pair:
		cards.add_child(_make_upgrade_card(id))

	# Refusal is a live choice (drawbacks make skipping sometimes right).
	var refuse = Button.new()
	refuse.custom_minimum_size = Vector2(180, 30)
	refuse.text = "Take neither"
	refuse.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	refuse.pressed.connect(_on_refuse)
	upgrades_box.add_child(refuse)


func _make_upgrade_card(id: String) -> Control:
	var up = WorldState.UPGRADE_POOL.get(id, {})
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(320, 130)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 1.0)
	style.set_border_width_all(2)
	style.border_color = Color(0.8, 0.45, 0.4, 1.0) if up.get("drawback", false) else Color(0.4, 0.6, 0.9, 1.0)
	card.add_theme_stylebox_override("panel", style)
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	card.add_child(m)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	m.add_child(box)
	var name_l = Label.new()
	name_l.text = up.get("name", id)
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_color_override("font_color", Color(1.0, 0.7, 0.6, 1.0) if up.get("drawback", false) else Color(0.7, 0.85, 1.0, 1.0))
	box.add_child(name_l)
	if up.get("drawback", false):
		var tag = Label.new()
		tag.text = "TRADE-OFF"
		tag.add_theme_font_size_override("font_size", 9)
		tag.add_theme_color_override("font_color", Color(0.9, 0.5, 0.4, 1.0))
		box.add_child(tag)
	var desc = Label.new()
	desc.text = up.get("desc", "")
	desc.add_theme_font_size_override("font_size", 12)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc)
	var take = Button.new()
	take.text = "Take"
	take.pressed.connect(func(): _on_take_upgrade(id))
	box.add_child(take)
	return card


func _on_take_upgrade(id: String) -> void:
	WorldState.resolve_upgrade_offer(current_floor, id)
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		HUD.update_stamina(WorldState.stamina, WorldState.get_max_stamina())
	HUD.refresh_inventory()
	HUD.show_feedback("Upgrade: " + WorldState.UPGRADE_POOL[id]["name"])
	_show_tab("shop")


func _on_refuse() -> void:
	if not refuse_armed:
		refuse_armed = true
		HUD.show_feedback("You sure, friend? Click again to pass.")
		return
	WorldState.resolve_upgrade_offer(current_floor, "")
	_show_tab("shop")


func _render_owned_upgrades() -> void:
	var header = Label.new()
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7, 1.0))
	header.text = "Acquired this descent:"
	upgrades_box.add_child(header)
	if WorldState.active_upgrades.is_empty():
		var none = Label.new()
		none.text = "(none yet)"
		none.add_theme_font_size_override("font_size", 12)
		upgrades_box.add_child(none)
	for id in WorldState.active_upgrades:
		var up = WorldState.UPGRADE_POOL.get(id, {})
		var row = Label.new()
		row.text = "• " + up.get("name", id) + " — " + up.get("desc", "")
		row.add_theme_font_size_override("font_size", 12)
		row.add_theme_color_override("font_color", Color(0.75, 0.85, 0.7, 1.0))
		upgrades_box.add_child(row)


func _add_upgrade_button(text: String, cb: Callable) -> void:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 30)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	upgrades_box.add_child(b)


func _refresh() -> void:
	for child in rows_box.get_children():
		child.queue_free()
	buy_buttons.clear()

	for i in range(stock.size()):
		var entry = stock[i]
		var item_data = ItemData.get_item(entry["item_id"])

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		rows_box.add_child(row)

		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = ItemData.get_texture(entry["item_id"])
		row.add_child(icon)

		var text_box = VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_box)

		var name_label = Label.new()
		name_label.text = item_data.get("name", "???")
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", BAND_COLORS.get(entry["band"], Color.WHITE))
		text_box.add_child(name_label)

		var desc_label = Label.new()
		desc_label.text = item_data.get("description", "")
		desc_label.add_theme_font_size_override("font_size", 9)
		desc_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1.0))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_box.add_child(desc_label)

		var price_label = Label.new()
		price_label.text = str(int(entry["price"]))
		price_label.add_theme_font_size_override("font_size", 16)
		price_label.add_theme_color_override("font_color", BAND_COLORS.get(entry["band"], Color.WHITE))
		price_label.custom_minimum_size = Vector2(60, 0)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(price_label)

		var buy_btn = Button.new()
		buy_btn.custom_minimum_size = Vector2(100, 30)
		if entry["sold"]:
			buy_btn.text = "SOLD"
			buy_btn.disabled = true
		else:
			buy_btn.text = "Buy"
			buy_btn.pressed.connect(_on_buy_pressed.bind(i))
		row.add_child(buy_btn)
		buy_buttons.append(buy_btn)

	_refresh_sell_section()
	_update_money_label()


func _refresh_sell_section() -> void:
	for child in sell_box.get_children():
		child.queue_free()
	sell_buttons.clear()
	pending_sell_confirm = -1

	var remaining = WorldState.get_sales_remaining(current_floor)
	var header = Label.new()
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6, 1.0))
	if remaining <= 0:
		header.text = "SELL — \"Not in a position to buy more right now.\""
		sell_box.add_child(header)
		return
	header.text = "SELL — the merchant will take %d more item%s this visit" % [remaining, "" if remaining == 1 else "s"]
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
		var name_label = Label.new()
		name_label.text = instance.get_display_name()
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var price_label = Label.new()
		price_label.text = str(price)
		price_label.add_theme_font_size_override("font_size", 12)
		price_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55, 1.0))
		row.add_child(price_label)
		var btn = Button.new()
		btn.text = "Sell"
		btn.custom_minimum_size = Vector2(80, 24)
		btn.pressed.connect(_on_sell_pressed.bind(i))
		row.add_child(btn)
		sell_buttons.append(btn)


func _on_sell_pressed(slot_index: int) -> void:
	if pending_sell_confirm != slot_index:
		if pending_sell_confirm >= 0 and pending_sell_confirm < sell_buttons.size() \
				and sell_buttons[pending_sell_confirm] != null:
			sell_buttons[pending_sell_confirm].text = "Sell"
		pending_sell_confirm = slot_index
		if slot_index < sell_buttons.size() and sell_buttons[slot_index] != null:
			sell_buttons[slot_index].text = "Confirm?"
		return
	pending_sell_confirm = -1
	if WorldState.sell_item(slot_index, current_floor):
		HUD.show_feedback("Sold.")
	_refresh_sell_section()
	_update_money_label()


func _update_money_label() -> void:
	money_label.text = "NOTES  " + str(WorldState.get_money_total())


func _on_buy_pressed(index: int) -> void:
	# Two-click confirm: first press arms the purchase, second commits it.
	if pending_confirm != index:
		if pending_confirm >= 0 and pending_confirm < buy_buttons.size() and \
				not buy_buttons[pending_confirm].disabled:
			buy_buttons[pending_confirm].text = "Buy"
		pending_confirm = index
		buy_buttons[index].text = "Confirm?"
		return

	pending_confirm = -1
	var entry = stock[index]
	var price = int(entry["price"])

	if WorldState.get_money_total() < price:
		HUD.show_feedback("Not enough notes.")
		buy_buttons[index].text = "Buy"
		return
	if not WorldState.add_to_inventory(entry["item_id"]):
		HUD.show_feedback("Inventory full.")
		buy_buttons[index].text = "Buy"
		return

	WorldState.spend_money(price)
	WorldState.mark_shop_item_sold(current_floor, index)
	HUD.refresh_inventory()
	var item_data = ItemData.get_item(entry["item_id"])
	HUD.show_feedback(item_data.get("name", "Item") + " purchased.")
	_refresh()
