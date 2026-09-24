extends ChoicePanel

# LEGACY (docs/PROGRESSION.md, tier 3 — the PROFILE, forever). Opened from the profile screen:
# spend the Legacy your characters earned (by how deep they got, +10 for escaping) on ranked
# perks that apply to every run of every playthrough in this save slot. Data:
# Progression.LEGACY_PERKS; state: WorldState.legacy_points / legacy_ranks (profile file).

const W := 700.0
const H := 430.0
var _points: Label = null
var _list: GridContainer = null
var _msg: Label = null


func _ready() -> void:
	build_card("LEGACY", W, H, Color(0.45, 0.55, 0.85))
	_points = label("", 14, INK)
	_points.position = Vector2(W - 290, 22)
	_points.size = Vector2(230, 20)
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(_points)
	var sub := label("What every character before you learned — permanent, for every run in this slot.", 12, DIM)
	sub.position = Vector2(24, 52)
	card.add_child(sub)
	_list = GridContainer.new()                     # name | what it does | learn — aligned columns
	_list.columns = 3
	_list.position = Vector2(24, 84)
	_list.size = Vector2(W - 48, H - 130)
	_list.add_theme_constant_override("h_separation", 14)
	_list.add_theme_constant_override("v_separation", 8)
	card.add_child(_list)
	_msg = label("", 12, GOLD)
	_msg.position = Vector2(24, H - 40)
	card.add_child(_msg)


func open() -> void:
	_msg.text = ""
	refresh()
	show_panel()


func refresh() -> void:
	_points.text = "LEGACY  %d" % WorldState.legacy_points
	for c in _list.get_children():
		c.queue_free()
	for id in Progression.LEGACY_PERKS:
		var d: Dictionary = Progression.legacy_perk(id)
		var rank: int = WorldState.legacy_rank(id)
		var maxr: int = Progression.legacy_max_rank(id)
		var cost: int = Progression.legacy_next_cost(id, rank)
		var name_l := label("%s\n%s" % [d.get("name", id), "■".repeat(rank) + "□".repeat(maxr - rank)], 13, INK, FONT_BOLD)
		name_l.custom_minimum_size = Vector2(230, 0)
		_list.add_child(name_l)
		var desc := label(d.get("desc", ""), 12, DIM)
		desc.custom_minimum_size = Vector2(250, 0)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_list.add_child(desc)
		var b := Button.new()
		b.custom_minimum_size = Vector2(130, 30)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if cost < 0:
			b.text = "Mastered"
			b.disabled = true
		else:
			b.text = "Learn  (%d)" % cost
			b.disabled = WorldState.legacy_points < cost
			b.pressed.connect(buy.bind(id))
		_list.add_child(b)


func buy(perk_id: String) -> String:
	var err: String = WorldState.buy_legacy_rank(perk_id)
	_msg.text = err if err != "" else "%s — rank %d." % [Progression.legacy_perk(perk_id).get("name", perk_id), WorldState.legacy_rank(perk_id)]
	refresh()
	return err
