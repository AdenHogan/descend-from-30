extends Control

# The CHARACTER JOURNAL — opened by clicking the HUD health portrait (hud.gd makes that a
# hover-glow button). Styled as a worn DIARY/paper page that PAUSES the game while open (a menu,
# so it reads comfortably). A status header shows the run + character + CONDITION IN WORDS + floor
# + this run's tallies (felled / scavenged / apartments looted). Three tabs:
#   • Story    — the character's lore + the cross-run chronicle (who came before, unlocked by
#                recovering their body).
#   • Quests   — active quests + important NPC information (scaffolding; quests not built yet).
#   • Map      — a fog-of-war map of the whole 30-floor building, clearing as you descend, marking
#                where you've been, where your corpses lie, and where the dead were last seen.
# All authored copy is DATA (CHAR_LORE / NPC_STORIES); built in code (no .tscn), under the HUD.

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")

# Paper palette (a warm, worn diary page).
const PAPER := Color(0.90, 0.85, 0.71)
const INK := Color(0.20, 0.15, 0.09)
const INK_SOFT := Color(0.36, 0.28, 0.18)

# Per-character lore. NAMES are NOT here — they live ONCE in WorldState.CHARACTER_NAMES (the title,
# status line and chronicle all read that), so a rename can never make this page disagree with
# itself. Subtitles must stay TIME-AGNOSTIC: the cast is drawn to runs at random, so any
# character can be the morning, afternoon or night run (the status header shows which).
const CHAR_LORE := {
	"blond_man": {"subtitle": "A resident of the building.",
		"lore": "Lore coming soon. (Owner: write this character's story here.)"},
	"dark_woman": {"subtitle": "A resident of the building.",
		"lore": "Lore coming soon. (Owner: write this character's story here.)"},
	"bald_man": {"subtitle": "A resident of the building.",
		"lore": "Lore coming soon. (Owner: write this character's story here.)"},
	"blond_woman": {"subtitle": "A resident of the building.",
		"lore": "Lore coming soon. (Owner: write this character's story here.)"},
}

# Uncovered NPC stories (placeholder; unlocks as the player meets residents). {name, story}.
const NPC_STORIES: Array = []

var _prev_paused: bool = false
var panel: PanelContainer = null
var title_label: Label = null
var status_text: RichTextLabel = null
var subtitle_label: Label = null
var lore_text: RichTextLabel = null
var before_text: RichTextLabel = null
var traits_text: RichTextLabel = null
var portrait_rect: TextureRect = null
var npc_text: RichTextLabel = null
var map_view: Control = null
var tabs: TabContainer = null


func _ready() -> void:
	name = "CharacterPanel"
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _paper_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = Color(0.30, 0.22, 0.13)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(4)
	return sb


func _ink_label(text: String, size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _ink_rich() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = true
	r.add_theme_font_override("normal_font", FONT)
	r.add_theme_font_override("bold_font", FONT)
	r.add_theme_font_override("italics_font", FONT)
	r.add_theme_font_size_override("normal_font_size", 15)
	r.add_theme_color_override("default_color", INK)
	return r


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	panel = PanelContainer.new()
	panel.name = "Card"
	panel.anchor_left = 0.5; panel.anchor_top = 0.5; panel.anchor_right = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -370; panel.offset_top = -260; panel.offset_right = 370; panel.offset_bottom = 260
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _paper_style())
	add_child(panel)

	var margin := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Header: title (character name) + close.
	var header := HBoxContainer.new()
	vbox.add_child(header)
	title_label = _ink_label("Journal", 26)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(38, 38)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	# Status block — the "first page" facts: run, condition (in words), floor, run tallies.
	status_text = _ink_rich()
	status_text.fit_content = true
	status_text.scroll_active = false
	status_text.custom_minimum_size = Vector2(0, 58)
	vbox.add_child(status_text)

	var rule := ColorRect.new()
	rule.color = Color(0.30, 0.22, 0.13, 0.5)
	rule.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(rule)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_override("font", FONT)
	tabs.add_theme_font_size_override("font_size", 15)
	vbox.add_child(tabs)

	# --- Tab 1: Story (portrait + lore + the cross-run chronicle) ---
	var story := HBoxContainer.new()
	story.name = "Story"
	story.add_theme_constant_override("separation", 14)
	tabs.add_child(story)
	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(190, 240)
	portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	story.add_child(portrait_rect)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 5)
	story.add_child(right)
	subtitle_label = _ink_label("", 13, INK_SOFT)
	right.add_child(subtitle_label)
	# This character's traits (WorldState.CHARACTER_TRAITS) — what makes this run play differently.
	traits_text = _ink_rich()
	traits_text.fit_content = true
	traits_text.scroll_active = false
	right.add_child(traits_text)
	lore_text = _ink_rich()
	lore_text.custom_minimum_size = Vector2(0, 96)
	right.add_child(lore_text)
	right.add_child(_ink_label("— Before you —", 14, INK_SOFT))
	before_text = _ink_rich()
	before_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(before_text)

	# --- Tab 2: Quests & NPCs (scaffolding) ---
	npc_text = _ink_rich()
	npc_text.name = "Quests & NPCs"
	tabs.add_child(npc_text)

	# --- Tab 3: Map (fog-of-war building) ---
	map_view = _MapView.new()
	map_view.name = "Map"
	tabs.add_child(map_view)


func open() -> void:
	_refresh()
	visible = true
	_prev_paused = get_tree().paused
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = _prev_paused


func toggle() -> void:
	if visible: close()
	else: open()


func _refresh() -> void:
	var cid: String = WorldState.current_character()
	var info: Dictionary = CHAR_LORE.get(cid, {})
	var char_name: String = WorldState.character_display_name(cid)   # the ONE name source
	title_label.text = char_name
	subtitle_label.text = str(info.get("subtitle", ""))
	traits_text.text = traits_bbcode(cid) + progression_bbcode()
	lore_text.text = str(info.get("lore", "No lore recorded yet for %s." % char_name))
	var tex = load("res://assets/Health_Bar/%s - 1 - Healthy.png" % cid)
	if tex != null:
		portrait_rect.texture = tex
	# Status header.
	var where := "the Lobby" if WorldState.current_floor == 0 else "Floor %d" % WorldState.current_floor
	status_text.text = "[b]Run %d — %s[/b]   ·   %s\nCondition: [b]%s[/b]   ·   %s\nFelled %d   ·   Scavenged %d   ·   Looted %d apartment%s" % [
		WorldState.current_run, WorldState.run_name(WorldState.current_run),
		char_name,
		WorldState.health_word(), where,
		WorldState.run_kills, WorldState.run_scavenged,
		WorldState.run_apartments_looted.size(), "" if WorldState.run_apartments_looted.size() == 1 else "s",
	]
	# Chronicle (Before you).
	before_text.text = _chronicle_bbcode()
	# Quests & NPCs.
	var q := "[b]Quests[/b]\n[i]No active quests. Story quests will be logged here as they open.[/i]\n\n[b]People[/b]\n"
	if NPC_STORIES.is_empty():
		q += "[i]Stories you uncover from the building's residents will collect here.[/i]"
	else:
		for entry in NPC_STORIES:
			q += "[b]%s[/b]\n%s\n\n" % [str(entry.get("name", "?")), str(entry.get("story", ""))]
	npc_text.text = q
	if map_view != null:
		map_view.queue_redraw()


static func traits_bbcode(cid: String) -> String:
	# Strengths + weaknesses, straight from the trait data the stats fold reads — so what the
	# journal promises is exactly what the game applies.
	var t: Dictionary = WorldState.character_traits(cid)
	if t.is_empty():
		return ""
	var out := "[i]%s[/i]\n" % str(t.get("tagline", ""))
	for p in t.get("perks", []):
		out += "[color=#2f5a2a]+ %s[/color]\n" % str(p)
	for f in t.get("flaws", []):
		out += "[color=#7a2a1f]− %s[/color]\n" % str(f)
	return out.strip_edges()


# What else is lifting this character (docs/PROGRESSION.md): this run's boons (gone at the time
# skip) and the profile's permanent perks (Descent Valour — every game in this save).
static func progression_bbcode() -> String:
	var out := ""
	if not WorldState.run_boons.is_empty():
		var names: Array = []
		for id in WorldState.run_boons:
			names.append(Progression.boon(id).get("name", id))
		out += "\n[color=#8a5a10]This run: %s[/color]" % ", ".join(names)
	if not WorldState.permanent_perks.is_empty():
		var kept: Array = []
		for id in WorldState.permanent_perks:
			kept.append(Progression.perk_info(id).get("name", id))
		out += "\n[color=#2f4a7a]Legacy: %s[/color]" % ", ".join(kept)
	return out


func _chronicle_bbcode() -> String:
	WorldState._ensure_chronicle()
	var out := ""
	for run in range(1, 4):
		var e: Dictionary = WorldState.chronicle_entry(run)
		var who: String = String(e.get("character", ""))
		if who == "":
			continue
		var is_now: bool = run == WorldState.current_run
		var tag := "  [i](now)[/i]" if is_now else ""
		out += "[b]%s — %s[/b]%s\n" % [WorldState.run_name(run), WorldState.character_display_name(who), tag]
		var depth := int(e.get("deepest_floor", 30))
		var depth_txt := "the lobby" if depth == 0 else "floor %d" % depth
		if is_now:
			out += "Still descending — %s so far.\n" % depth_txt
		else:
			var oc := String(e.get("outcome", ""))
			if oc == "escaped":
				out += "Escaped the building.\n"
			elif oc == "fell":
				out += "Fell on %s.\n" % depth_txt
			else:
				out += "Unaccounted for. Last known: %s.\n" % depth_txt
		var traces: Array = e.get("traces", [])
		if not traces.is_empty():
			out += "[i]They left: %s[/i]\n" % ", ".join(traces)
		if not is_now:
			if bool(e.get("recovered", false)):
				var lore := str(CHAR_LORE.get(who, {}).get("lore", ""))
				if lore != "":
					out += lore + "\n"
			else:
				out += "[i]You haven't found their body. Their story is lost until you do.[/i]\n"
		for t in e.get("thoughts", []):
			out += "[color=#6b4f3a]“%s”[/color]\n" % str(t)
		out += "\n"
	if out == "":
		out = "[i]No one has come before you yet.[/i]"
	return out


func _prettify(cid: String) -> String:
	var parts := cid.split("_", false)
	var o := ""
	for p in parts:
		if p.length() > 0:
			o += p.substr(0, 1).to_upper() + p.substr(1) + " "
	return o.strip_edges()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# ---- The fog-of-war building map (a code-drawn strip of all 30 floors) --------------------
class _MapView:
	extends Control

	const FONT := preload("res://assets/fonts/PixelOperator8.ttf")

	func _ready() -> void:
		custom_minimum_size = Vector2(300, 400)

	func _corpse_floors() -> Dictionary:
		var out: Dictionary = {}
		for k in WorldState.player_corpses:
			out[str(int(WorldState.player_corpses[k].get("floor", -1)))] = true
		return out

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var gutter := 30.0
		var barx := gutter + 4.0
		var barw: float = w - barx - 10.0
		var rows := 31                          # floors 30 … 1 plus the lobby (0)
		var rh: float = h / float(rows)
		var corpses := _corpse_floors()
		for f in range(0, 31):
			var y: float = float(30 - f) * rh      # floor 30 at the top, the lobby at the bottom
			var r := Rect2(barx, y + 1.0, barw, rh - 2.0)
			var visited: bool = WorldState.visited_floors.has(str(f))
			# Fog: unvisited floors are dark/hazed; visited floors read as clear paper cells.
			draw_rect(r, Color(0.80, 0.72, 0.54) if visited else Color(0.34, 0.30, 0.24))
			draw_rect(r, Color(0.30, 0.22, 0.13, 0.35), false, 1.0)
			if visited:
				# The dead were seen here (red) and/or a fallen character lies here (blue).
				if WorldState.floors_enemy_seen.has(str(f)):
					draw_circle(Vector2(barx + barw - 12.0, y + rh * 0.5), 3.5, Color(0.75, 0.16, 0.13))
				if corpses.has(str(f)):
					draw_circle(Vector2(barx + barw - 26.0, y + rh * 0.5), 3.5, Color(0.30, 0.45, 0.85))
			if f == WorldState.current_floor:
				draw_rect(r, Color(0.85, 0.28, 0.15), false, 2.0)   # YOU ARE HERE
				draw_string(FONT, Vector2(barx + 4.0, y + rh - 3.0), "▶ you",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.15, 0.10, 0.05))
			# Floor number gutter every 5th floor (+ floor 1); "L" marks the lobby.
			if f == 0 or f % 5 == 0 or f == 1:
				draw_string(FONT, Vector2(2.0, y + rh - 3.0), "L" if f == 0 else str(f),
					HORIZONTAL_ALIGNMENT_LEFT, gutter, 11, Color(0.20, 0.15, 0.09))
