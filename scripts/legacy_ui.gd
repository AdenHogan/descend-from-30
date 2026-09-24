extends ChoicePanel

# LEGACY — the profile's permanent tier (docs/PROGRESSION.md, "Descent Valour"). Two tabs:
#   DESCENT OFFER — at the end of a three-run session, up to Progression.OFFER_COUNT perks the player
#                   acquired that session (drawn at random, no weighting). Buy ONE with Valour to keep
#                   forever, or keep the Valour for later. Opened automatically by game_over.gd.
#   COLLECTION    — the perks kept forever (max Progression.PERMANENT_CAP); trade one out for a
#                   partial refund. Opened from the profile screen's LEGACY button.
# State: WorldState.valour / permanent_perks / valour_offer / last_valour (the profile file).

const W := 780.0
const H := 500.0
const TAB_OFFER := "offer"
const TAB_COLLECTION := "collection"

var tab := TAB_OFFER
var _valour: Label = null
var _tab_offer: Button = null
var _tab_coll: Button = null
var _body: Control = null
var _msg: Label = null
var _pending_buy := ""          # offer perk waiting for a trade-out pick (collection full)
var _confirm_trade := ""        # collection perk whose Trade out was pressed once (confirm)


func _ready() -> void:
	build_card("LEGACY", W, H, Color(0.45, 0.55, 0.85))
	_valour = label("", 14, GOLD, FONT_BOLD)
	_valour.position = Vector2(W - 330, 22)
	_valour.size = Vector2(270, 20)
	_valour.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(_valour)
	_tab_offer = _tab_button("Descent offer", Vector2(24, 56))
	_tab_offer.pressed.connect(func(): show_tab(TAB_OFFER))
	_tab_coll = _tab_button("Collection", Vector2(214, 56))
	_tab_coll.pressed.connect(func(): show_tab(TAB_COLLECTION))
	_body = Control.new()
	_body.position = Vector2(24, 100)
	_body.size = Vector2(W - 48, H - 150)
	card.add_child(_body)
	_msg = label("", 12, GOLD)
	_msg.position = Vector2(24, H - 36)
	_msg.size = Vector2(W - 48, 20)
	card.add_child(_msg)


func _tab_button(text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(180, 32)
	b.toggle_mode = true
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 13)
	card.add_child(b)
	return b


func open(which: String = "") -> void:
	_msg.text = ""
	_pending_buy = ""
	_confirm_trade = ""
	if which == "":
		which = TAB_OFFER if not WorldState.valour_offer.is_empty() else TAB_COLLECTION
	show_tab(which)
	show_panel()


func show_tab(which: String) -> void:
	tab = which
	refresh()


func refresh() -> void:
	_valour.text = "VALOUR  %d" % WorldState.valour
	_tab_offer.button_pressed = tab == TAB_OFFER
	_tab_coll.button_pressed = tab == TAB_COLLECTION
	_tab_coll.text = "Collection  %d/%d" % [WorldState.permanent_perks.size(), Progression.PERMANENT_CAP]
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	if tab == TAB_OFFER:
		_build_offer()
	else:
		_build_collection()


# --- the end-of-session offer --------------------------------------------------------------
func _build_offer() -> void:
	var offer: Array = WorldState.valour_offer
	var total: int = int(WorldState.last_valour.get("total", 0))
	var head := label("", 13, INK)
	head.size = Vector2(_body.size.x, 40)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(head)
	if offer.is_empty():
		head.text = "No perks on offer.\n\nAt the end of a three-run session you're offered perks your characters picked up along the way — keep one forever with Descent Valour."
		head.add_theme_color_override("font_color", DIM)
		head.size.y = 120
		return
	head.text = "Your descent earned +%d Valour. Keep ONE perk you found this session — forever." % total
	var cw := (_body.size.x - 24.0) / 3.0
	for i in offer.size():
		var id: String = offer[i]
		var d: Dictionary = Progression.perk_info(id)
		var cost: int = int(d.get("cost", 0))
		var kind := "Run boon" if d.get("kind", "") == "boon" else "Merchant upgrade"
		var b := choice_button(String(d.get("name", id)),
			"%s\n\n%s\n\nKeep forever — %d Valour" % [d.get("desc", ""), kind, cost], cw, 170)
		b.position = Vector2(i * (cw + 12.0), 40)
		b.size = Vector2(cw, 170)
		b.disabled = WorldState.valour < cost and WorldState.permanent_perks.size() < Progression.PERMANENT_CAP
		b.toggle_mode = true
		b.button_pressed = id == _pending_buy
		b.pressed.connect(buy.bind(id))
		_body.add_child(b)
	if _pending_buy != "":
		_build_trade_picker()
		return
	var save := Button.new()
	save.text = "Keep my Valour (take nothing)"
	save.position = Vector2(0, 232)
	save.size = Vector2(300, 34)
	save.pressed.connect(decline)
	_body.add_child(save)


# Collection full: pick which kept perk to trade out for the new one.
func _build_trade_picker() -> void:
	var hint := label("Your legacy is full (%d). Trade one out for %s:" % [Progression.PERMANENT_CAP,
		Progression.perk_info(_pending_buy).get("name", _pending_buy)], 12, BAD)
	hint.position = Vector2(0, 218)
	_body.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(0, 240)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 3)
	_body.add_child(grid)
	for id in WorldState.permanent_perks:
		var b := Button.new()
		b.text = "%s (+%d)" % [Progression.perk_info(id).get("name", id), Progression.trade_refund(id)]
		b.custom_minimum_size = Vector2(238, 26)
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect(buy.bind(_pending_buy, id))
		grid.add_child(b)


func buy(perk_id: String, trade_out: String = "") -> String:
	if trade_out == "" and WorldState.permanent_perks.size() >= Progression.PERMANENT_CAP:
		_pending_buy = "" if _pending_buy == perk_id else perk_id      # click again to cancel
		_msg.text = ""
		refresh()
		return "full"
	var err: String = WorldState.buy_permanent(perk_id, trade_out)
	_pending_buy = ""
	_msg.text = err if err != "" else "%s is yours for good — every new game starts with it." % Progression.perk_info(perk_id).get("name", perk_id)
	if err == "":
		tab = TAB_COLLECTION
	refresh()
	return err


func decline() -> void:
	WorldState.decline_valour_offer()
	_msg.text = "Valour kept for another descent."
	tab = TAB_COLLECTION
	refresh()


# --- the collection --------------------------------------------------------------------
func _build_collection() -> void:
	if WorldState.permanent_perks.is_empty():
		var none := label("Nothing kept yet.\n\nFinish a three-run session and spend Descent Valour on a perk you found — it stays with every new game in this save.", 13, DIM)
		none.size = Vector2(_body.size.x, 120)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(none)
		return
	var grid := GridContainer.new()                   # name | what it does | trade out — aligned
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 3)
	_body.add_child(grid)
	for id in WorldState.permanent_perks:
		var d: Dictionary = Progression.perk_info(id)
		var n := label(String(d.get("name", id)), 12, INK, FONT_BOLD)
		n.custom_minimum_size = Vector2(200, 0)
		grid.add_child(n)
		var desc := label(String(d.get("desc", "")), 11, DIM)
		desc.custom_minimum_size = Vector2(340, 0)
		desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(desc)
		var b := Button.new()
		b.custom_minimum_size = Vector2(170, 24)
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 10)
		b.text = ("Confirm? +%d" if _confirm_trade == id else "Trade out  (+%d)") % Progression.trade_refund(id)
		b.pressed.connect(trade_out.bind(id))
		grid.add_child(b)


# Two presses: the first arms it, the second trades it out (refunds part of its cost).
func trade_out(perk_id: String) -> int:
	if _confirm_trade != perk_id:
		_confirm_trade = perk_id
		_msg.text = "Trade out %s? It stops applying to new games." % Progression.perk_info(perk_id).get("name", perk_id)
		refresh()
		return 0
	_confirm_trade = ""
	var refund: int = WorldState.trade_out_permanent(perk_id)
	_msg.text = "Traded out — +%d Valour." % refund
	refresh()
	return refund
