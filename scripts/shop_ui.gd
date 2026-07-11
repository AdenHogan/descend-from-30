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

	var sep = HSeparator.new()
	vbox.add_child(sep)

	rows_box = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 4)
	rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(rows_box)

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
	_refresh()
	visible = true


func close() -> void:
	visible = false
	pending_confirm = -1


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
