extends Control

# The CHARACTER JOURNAL — opened by clicking the HUD health portrait (hud.gd makes that a
# hover-glow button). It PAUSES the game while open. Owner round 34: "too neat and rectangular… stilted. Can we
# give it more energy, perhaps like loose papers in a journal book. The text can be a different handwritten font
# for each character." So it is a worn JOURNAL BOOK open on a desk — ragged pages, a gutter, a stack of page edges —
# with LOOSE things on it: a taped polaroid of the character, a sticky note of the run's facts, a torn lined sheet
# (spiral holes) of their traits, coloured bookmark tabs down the edge, stains and a coffee ring; each piece at its
# own angle, and they settle onto the page when it opens. Every character WRITES IN THEIR OWN HAND — font, ink and
# page tint (HAND below) — and the paper's stains/edges are seeded per character, so no two journals look alike.
#   • Story    — the character's lore + the cross-run chronicle (who came before, unlocked by
#                recovering their body).
#   • Quests   — active quests + important NPC information (scaffolding; quests not built yet).
#   • Map      — a fog-of-war map of the whole 30-floor building.
#   • Codex    — every item, found or ???.
# All authored copy is DATA (CHAR_LORE / NPC_STORIES); built in code (no .tscn), under the HUD. The node API the
# tests + hud read (title_label, status_text, subtitle_label, lore_text, before_text, traits_text, portrait_rect,
# npc_text, map_view, codex_box, tabs) is unchanged; `tabs` is a TabContainer with its own tab bar hidden — the
# bookmarks drive it.

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")

# Fallback palette (used before a character is known).
const PAPER := Color(0.90, 0.85, 0.71)
const INK := Color(0.20, 0.15, 0.09)
const INK_SOFT := Color(0.36, 0.28, 0.18)

# Each character's HAND (OFL fonts in assets/fonts/hand/, credited in OFL_*.txt): the typeface, a size multiplier
# (the hands differ a lot in x-height), the INK they write with and the tint of their paper.
const HAND := {
	"blond_man": {"path": "res://assets/fonts/hand/PatrickHand.ttf", "scale": 1.12, "ink": Color(0.12, 0.17, 0.38),
		"paper": Color(0.94, 0.90, 0.77), "name": "neat print, blue ballpoint"},
	"blond_woman": {"path": "res://assets/fonts/hand/Caveat.ttf", "scale": 1.28, "ink": Color(0.34, 0.11, 0.30),
		"paper": Color(0.95, 0.89, 0.84), "name": "loose cursive, plum ink"},
	"dark_woman": {"path": "res://assets/fonts/hand/IndieFlower.ttf", "scale": 1.0, "ink": Color(0.07, 0.10, 0.13),
		"paper": Color(0.90, 0.92, 0.85), "name": "round and tidy, black gel pen"},
	"bald_man": {"path": "res://assets/fonts/hand/ReenieBeanie.ttf", "scale": 1.32, "ink": Color(0.20, 0.20, 0.23),
		"paper": Color(0.93, 0.87, 0.69), "name": "a hurried scrawl, pencil"},
}
const BOOK_W := 1000.0
const BOOK_H := 590.0
const PAGE_W := 470.0

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
var panel: Control = null                 # the book (kept under its old name)
var title_label: Label = null
var status_text: RichTextLabel = null
var subtitle_label: Label = null
var lore_text: RichTextLabel = null
var before_text: RichTextLabel = null
var traits_text: RichTextLabel = null
var portrait_rect: TextureRect = null
var npc_text: RichTextLabel = null
var map_view: Control = null
var codex_box: VBoxContainer = null       # the Codex tab's rows (built once, on first open)
var tabs: TabContainer = null
var bookmarks: Array = []                 # the coloured tabs down the page edge (one per tab, in order)
var loose: Array = []                     # [{node, pos, rot}] — what settles onto the page when it opens
var _cid: String = ""
var _hand_nodes: Array = []               # [{node, size, soft}] — everything written in the character's hand
var _fonts: Dictionary = {}               # cid -> {normal, bold, italic}
var _papers: Array = []                   # every _Paper, re-tinted + re-seeded per character
var _settle: Tween = null


func _ready() -> void:
	name = "CharacterPanel"
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


# ---- the character's hand ---------------------------------------------------------------------------------------
func hand_info(cid: String) -> Dictionary:
	return HAND.get(cid, {"path": "", "scale": 1.0, "ink": INK, "paper": PAPER, "name": ""})


## {normal, bold, italic} fonts for this character's hand — the pixel font stands behind each as the glyph fallback
## (an arrow, a ✕), so no symbol ever draws as an empty box.
func fonts_for(cid: String) -> Dictionary:
	if _fonts.has(cid):
		return _fonts[cid]
	var normal: Font = FONT
	var path: String = String(hand_info(cid).get("path", ""))
	if path != "" and ResourceLoader.exists(path):
		var f = load(path)
		if f is FontFile:
			var fb: Array[Font] = [FONT]
			f.fallbacks = fb
			normal = f
	var bold := FontVariation.new()
	bold.base_font = normal
	bold.variation_embolden = 0.8
	var italic := FontVariation.new()
	italic.base_font = normal
	italic.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.22, 1.0), Vector2.ZERO)
	_fonts[cid] = {"normal": normal, "bold": bold, "italic": italic}
	return _fonts[cid]


func ink_color() -> Color:
	return hand_info(_cid).get("ink", INK)


func ink_soft() -> Color:
	return ink_color().lerp(hand_info(_cid).get("paper", PAPER), 0.38)


func _ink_label(text: String, font_size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	_hand_nodes.append({"node": l, "size": font_size, "soft": color != INK})
	_style_one(_hand_nodes[-1])
	return l


func _ink_rich() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = true
	_hand_nodes.append({"node": r, "size": 15, "soft": false})
	_style_one(_hand_nodes[-1])
	return r


func _style_one(e: Dictionary) -> void:
	var n = e["node"]
	if not is_instance_valid(n):
		return
	var f: Dictionary = fonts_for(_cid)
	var sz: int = int(round(float(e["size"]) * float(hand_info(_cid).get("scale", 1.0)) * 1.18))
	var col: Color = ink_soft() if bool(e["soft"]) else ink_color()
	if n is Label:
		n.add_theme_font_override("font", f["normal"])
		n.add_theme_font_size_override("font_size", sz)
		n.add_theme_color_override("font_color", col)
	elif n is RichTextLabel:
		n.add_theme_font_override("normal_font", f["normal"])
		n.add_theme_font_override("bold_font", f["bold"])
		n.add_theme_font_override("italics_font", f["italic"])
		n.add_theme_font_override("bold_italics_font", f["bold"])
		for k in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
			n.add_theme_font_size_override(k, sz)
		n.add_theme_color_override("default_color", col)


## Shrink a hand-written block until it fits its page space (the hands differ a lot in size — a scrawl needs more room).
func _set_fit(node: Control, h: float) -> void:
	for e in _hand_nodes:
		if e["node"] == node:
			e["fit_h"] = h


func _fit_all() -> void:
	for e in _hand_nodes:
		var n = e["node"]
		if not is_instance_valid(n) or not (n is RichTextLabel) or float(e.get("fit_h", 0.0)) <= 0.0:
			continue
		var sz: int = int(round(float(e["size"]) * float(hand_info(_cid).get("scale", 1.0)) * 1.18))
		while sz > 10:
			for k in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
				n.add_theme_font_size_override(k, sz)
			if n.get_content_height() <= float(e["fit_h"]):
				break
			sz -= 1


## Re-style everything for the character the run is on (the cast changes run to run): the hand, the ink, the paper.
func _restyle(cid: String) -> void:
	_cid = cid
	var keep: Array = []
	for e in _hand_nodes:
		if is_instance_valid(e["node"]):
			_style_one(e)
			keep.append(e)
	_hand_nodes = keep
	var info := hand_info(cid)
	var seed_ := absi(hash(cid + str(WorldState.master_seed)))
	for p in _papers:
		if is_instance_valid(p):
			p.restyle(info.get("paper", PAPER), seed_)
	if map_view != null:
		map_view.hand = fonts_for(cid)["normal"]
		map_view.ink = ink_color()
	for b in bookmarks:
		b.font = fonts_for(cid)["bold"]
		b.queue_redraw()
	if panel != null:
		for n in panel.get_children():
			if n is _Scribble:
				n.ink = ink_color()
				n.queue_redraw()


func _paper(kind: String, rect: Rect2, rot_deg: float = 0.0, tint: Color = Color(0, 0, 0, 0)) -> Control:
	var p := _Paper.new()
	p.kind = kind
	p.position = rect.position
	p.size = rect.size
	p.pivot_offset = rect.size * 0.5
	p.rotation_degrees = rot_deg
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tint.a > 0.0:
		p.fixed_tint = tint
	p.seed_ = _papers.size() * 977 + 13
	_papers.append(p)
	return p


func _build() -> void:
	_cid = WorldState.current_character()
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.012, 0.008, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	# THE BOOK — one Control the size of the spread, centred; everything below is placed in its coordinates.
	panel = Control.new()
	panel.name = "Card"
	panel.anchor_left = 0.5; panel.anchor_top = 0.5; panel.anchor_right = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -BOOK_W * 0.5; panel.offset_top = -BOOK_H * 0.5
	panel.offset_right = BOOK_W * 0.5; panel.offset_bottom = BOOK_H * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var cover := _paper("cover", Rect2(-6, 2, BOOK_W + 12, BOOK_H - 4), -0.5)
	cover.name = "Cover"
	panel.add_child(cover)
	var left_page := _paper("page_l", Rect2(24, 18, PAGE_W + 6, BOOK_H - 40), 0.0)
	left_page.name = "LeftPage"
	panel.add_child(left_page)
	var right_page := _paper("page_r", Rect2(BOOK_W * 0.5 - 6, 18, PAGE_W + 6, BOOK_H - 40), 0.0)
	right_page.name = "RightPage"
	panel.add_child(right_page)

	# ---- LEFT PAGE: the name, a taped polaroid, the run's facts on a sticky, a torn sheet of traits ------------------
	var lx := 24.0
	title_label = _ink_label("Journal", 38)
	title_label.position = Vector2(lx + 34, 30)
	title_label.size = Vector2(PAGE_W - 70, 64)
	title_label.pivot_offset = Vector2(0, 40)
	title_label.rotation_degrees = -1.6
	panel.add_child(title_label)
	var scribble := _Scribble.new()
	scribble.position = Vector2(lx + 30, 88)
	scribble.size = Vector2(300, 14)
	scribble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(scribble)

	var photo := _paper("photo", Rect2(lx + 26, 112, 196, 236), -3.6)
	photo.name = "Polaroid"
	panel.add_child(photo)
	portrait_rect = TextureRect.new()
	portrait_rect.position = Vector2(12, 12)
	portrait_rect.size = Vector2(172, 190)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.add_child(portrait_rect)
	_loose(photo)

	subtitle_label = _ink_label("", 13, INK_SOFT)
	subtitle_label.position = Vector2(lx + 240, 116)
	subtitle_label.size = Vector2(PAGE_W - 270, 52)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.rotation_degrees = 1.0
	panel.add_child(subtitle_label)

	var sticky := _paper("sticky", Rect2(lx + 236, 176, 224, 178), 3.2)
	sticky.name = "StatusNote"
	panel.add_child(sticky)
	status_text = _ink_rich()
	status_text.position = Vector2(14, 20)
	status_text.size = Vector2(198, 142)
	_set_fit(status_text, 142.0)
	status_text.fit_content = false
	status_text.scroll_active = false
	status_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sticky.add_child(status_text)
	_loose(sticky)

	var sheet := _paper("torn", Rect2(lx + 6, 358, PAGE_W - 8, 202), 1.7)
	sheet.name = "TraitsSheet"
	panel.add_child(sheet)
	traits_text = _ink_rich()
	traits_text.position = Vector2(44, 26)
	traits_text.size = Vector2(PAGE_W - 8 - 62, 156)
	_set_fit(traits_text, 156.0)
	traits_text.scroll_active = false
	traits_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(traits_text)
	_loose(sheet)

	# ---- RIGHT PAGE: the tabs' content (the TabContainer's own tab bar is hidden — the bookmarks drive it) -----------
	var rx := BOOK_W * 0.5 - 6.0
	tabs = TabContainer.new()
	tabs.position = Vector2(rx + 34, 46)
	tabs.size = Vector2(PAGE_W - 58, BOOK_H - 112)
	tabs.tabs_visible = false
	tabs.mouse_filter = Control.MOUSE_FILTER_PASS
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.add_child(tabs)

	# --- Tab 1: Story (the lore + the cross-run chronicle) ---
	var story := ScrollContainer.new()
	story.name = "Story"
	story.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var sv := VBoxContainer.new()
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_theme_constant_override("separation", 8)
	story.add_child(sv)
	lore_text = _ink_rich()
	lore_text.fit_content = true
	lore_text.scroll_active = false
	sv.add_child(lore_text)
	sv.add_child(_ink_label("~ before you ~", 17, INK_SOFT))
	before_text = _ink_rich()
	before_text.fit_content = true
	before_text.scroll_active = false
	sv.add_child(before_text)
	tabs.add_child(story)

	# --- Tab 2: Quests & NPCs (scaffolding) ---
	npc_text = _ink_rich()
	npc_text.name = "Quests & NPCs"
	tabs.add_child(npc_text)

	# --- Tab 3: Map (fog-of-war building, drawn as if sketched on the page) ---
	map_view = _MapView.new()
	map_view.name = "Map"
	tabs.add_child(map_view)

	# --- Tab 4: Codex (every item's durability, in words) ---
	var codex_scroll := ScrollContainer.new()
	codex_scroll.name = "Codex"
	codex_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	codex_box = VBoxContainer.new()
	codex_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	codex_box.add_theme_constant_override("separation", 6)
	codex_scroll.add_child(codex_box)
	tabs.add_child(codex_scroll)

	# ---- the bookmarks: coloured paper tabs down the page edge (the active one sticks further out) -------------------
	var marks := [["Story", Color(0.78, 0.30, 0.24)], ["Quests", Color(0.30, 0.50, 0.72)],
		["Map", Color(0.34, 0.60, 0.38)], ["Codex", Color(0.86, 0.70, 0.28)]]
	for i in marks.size():
		var b := _Bookmark.new()
		b.text = marks[i][0]
		b.color = marks[i][1]
		b.index = i
		b.base_x = BOOK_W - 50.0
		b.position = Vector2(b.base_x, 70.0 + i * 58.0)
		b.size = Vector2(124, 40)
		b.pivot_offset = Vector2(0, 20)
		b.rotation_degrees = [2.2, -1.6, 1.4, -2.4][i]
		b.picked.connect(_pick_tab)
		panel.add_child(b)
		bookmarks.append(b)
	var close_btn := _CloseScrap.new()
	close_btn.name = "Close"
	close_btn.position = Vector2(BOOK_W - 74, -6)
	close_btn.size = Vector2(70, 46)
	close_btn.rotation_degrees = 3.0
	close_btn.pressed.connect(close)
	panel.add_child(close_btn)
	_pick_tab(0)
	_restyle(_cid)


func _loose(n: Control) -> void:
	loose.append({"node": n, "pos": n.position, "rot": n.rotation_degrees})


func _pick_tab(i: int) -> void:
	if tabs != null:
		tabs.current_tab = clampi(i, 0, tabs.get_tab_count() - 1)
	for b in bookmarks:
		b.active = b.index == i
		b.queue_redraw()


## The loose pieces drop onto the page a few at a time, each from its own small offset and angle.
func _settle_in() -> void:
	if _settle != null and _settle.is_valid():
		_settle.kill()
	_settle = create_tween().set_parallel(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4410
	var delay := 0.0
	for e in loose:
		var n: Control = e["node"]
		if not is_instance_valid(n):
			continue
		n.position = e["pos"] + Vector2(rng.randf_range(-26.0, 26.0), rng.randf_range(-34.0, -12.0))
		n.rotation_degrees = float(e["rot"]) + rng.randf_range(-7.0, 7.0)
		n.modulate.a = 0.0
		_settle.tween_property(n, "position", e["pos"], 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_settle.tween_property(n, "rotation_degrees", e["rot"], 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_settle.tween_property(n, "modulate:a", 1.0, 0.18).set_delay(delay)
		delay += 0.07


func open() -> void:
	_refresh()
	_pick_tab(0)
	visible = true
	_settle_in()
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
	_restyle(cid)
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
	status_text.text = "[b]Run %d — %s[/b]\nCondition: [b]%s[/b]\n%s\nFelled %d  ·  Scavenged %d\nLooted %d apartment%s" % [
		WorldState.current_run, WorldState.run_name(WorldState.current_run),
		WorldState.health_word(), where,
		WorldState.run_kills, WorldState.run_scavenged,
		WorldState.run_apartments_looted.size(), "" if WorldState.run_apartments_looted.size() == 1 else "s",
	]
	# Chronicle (Before you).
	before_text.text = _chronicle_bbcode()
	# Quests & NPCs.
	var q := "[b]Quests[/b]\n" + _quest_bbcode() + "\n\n[b]People[/b]\n"
	if NPC_STORIES.is_empty():
		q += "[i]Stories you uncover from the building's residents will collect here.[/i]"
	else:
		for entry in NPC_STORIES:
			q += "[b]%s[/b]\n%s\n\n" % [str(entry.get("name", "?")), str(entry.get("story", ""))]
	npc_text.text = q
	if map_view != null:
		map_view.queue_redraw()
	_build_codex()
	_fit_all()


## This run's personal quest (docs/CHARACTER_STORIES.md): its title, the objectives already behind them struck through, and the one now.
func _quest_bbcode() -> String:
	var cq: Dictionary = CharacterStory.current_quest()
	if cq.is_empty():
		return "[i]No active quests. Story quests will be logged here as they open.[/i]"
	var out := "[b]%s[/b]\n" % str(cq["title"])
	for done in cq["earlier"]:
		out += "[s]%s[/s]\n" % str(done)
	out += "- %s" % str(cq["objective"])
	return out


## The Codex tab: a legend for the in-hand box's colour, then every item with its durability and how it wears
## (all derived from real item data by ItemCodex). Rebuilt on each refresh — entries unlock as items are found.
func _build_codex() -> void:
	if codex_box == null:
		return
	for c in codex_box.get_children():   # rebuilt on every refresh: what's been found changes
		codex_box.remove_child(c)
		c.queue_free()
	var intro := _ink_rich()
	intro.fit_content = true
	intro.scroll_active = false
	intro.text = "[i]The box by your name shows what you're holding. Its colour is the item's condition — it drifts a little with every use, and once it runs out the item is broken.[/i]"
	codex_box.add_child(intro)
	var counts: Array = ItemCodex.found_counts()
	var tally := _ink_label("Found %d of %d items" % [counts[0], counts[1]], 13, INK_SOFT)
	tally.name = "CodexTally"
	codex_box.add_child(tally)
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 14)
	legend.add_theme_constant_override("v_separation", 2)
	for entry in ItemCodex.legend():
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 5)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(16, 16)
		sw.color = entry[1]
		chip.add_child(sw)
		chip.add_child(_ink_label(str(entry[0]), 13, INK_SOFT))
		legend.add_child(chip)
	codex_box.add_child(legend)
	for sec in ItemCodex.sections():
		codex_box.add_child(_ink_label("— %s —" % sec["title"], 15, INK_SOFT))
		for it in sec["items"]:
			var row := HBoxContainer.new()
			row.name = "Item_" + str(it["id"])
			row.add_theme_constant_override("separation", 10)
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(44, 44)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.texture = ItemData.get_texture(str(it["id"]))
			if not it["found"]:
				icon.modulate = Color(0.08, 0.06, 0.05, 0.85)   # an unfound item is a silhouette
			row.add_child(icon)
			var text := _ink_rich()
			text.fit_content = true
			text.scroll_active = false
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var body := "[b]%s[/b]  —  [color=#8a5a10]%s[/color]\n%s" % [it["name"], it["durability"], it["wear"]]
			if str(it["ending"]) != "":
				body += "\n[i]%s[/i]" % it["ending"]
			if not it["found"]:
				body = "[b]???[/b]\n[i]You haven't found this yet.[/i]"
			text.text = body
			row.add_child(text)
			codex_box.add_child(row)


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
	elif tabs != null and (event.is_action_pressed("ui_page_down") or event.is_action_pressed("ui_page_up")):
		# LB / RB (or PageUp / PageDown) turn the bookmarks.
		var step: int = 1 if event.is_action_pressed("ui_page_down") else -1
		var n: int = tabs.get_tab_count()
		_pick_tab((tabs.current_tab + step + n) % n)
		get_viewport().set_input_as_handled()


# ---- A piece of paper: ragged edge, shadow, and what its KIND carries ---------------------------------------------------
# cover (the book's leather), page_l / page_r (the spread, with a stack of page edges + the gutter), photo (a taped
# polaroid), sticky (a yellow note), torn (a lined sheet pulled out of a spiral). Everything is a pure function of the
# kind, the size and the character's seed, so a character's journal always looks the same and no two look alike.
class _Paper:
	extends Control

	var kind: String = "page_l"
	var fixed_tint: Color = Color(0, 0, 0, 0)
	var seed_: int = 1
	var char_seed: int = 0
	var base: Color = Color(0.90, 0.85, 0.71)
	var _poly: PackedVector2Array = PackedVector2Array()
	var _poly_size: Vector2 = Vector2.ZERO

	func restyle(color: Color, cseed: int) -> void:
		base = color
		char_seed = cseed
		_poly = PackedVector2Array()
		queue_redraw()

	func _rng(salt: int) -> RandomNumberGenerator:
		var r := RandomNumberGenerator.new()
		r.seed = absi(seed_ * 7919 + char_seed * 31 + kind.hash() + salt * 104729)
		return r

	func _colour() -> Color:
		match kind:
			"cover":
				return Color(0.23, 0.14, 0.10).lerp(Color(0.16, 0.17, 0.20), float(char_seed % 5) / 14.0)
			"photo":
				return Color(0.96, 0.95, 0.91)
			"sticky":
				return Color(0.98, 0.91, 0.52).lerp(base, 0.12)
			"torn":
				return base.lightened(0.20)
		return base

	## A rectangle whose edges wander: every point stays INSIDE the rect (so the outline is the paper's, never past it).
	static func ragged(w: float, h: float, step: float, amp: float, top_amp: float, rng: RandomNumberGenerator) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var x := 0.0
		while x < w:
			pts.append(Vector2(x, rng.randf() * (top_amp if top_amp >= 0.0 else amp)))
			x += step * rng.randf_range(0.7, 1.2)
		var y := 0.0
		while y < h:
			pts.append(Vector2(w - rng.randf() * amp, y))
			y += step * rng.randf_range(0.7, 1.2)
		x = w
		while x > 0.0:
			pts.append(Vector2(x, h - rng.randf() * amp))
			x -= step * rng.randf_range(0.7, 1.2)
		y = h
		while y > 0.0:
			pts.append(Vector2(rng.randf() * amp, y))
			y -= step * rng.randf_range(0.7, 1.2)
		return pts

	func _outline() -> PackedVector2Array:
		if _poly.size() >= 3 and _poly_size == size:
			return _poly
		var rect := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
		var p: PackedVector2Array
		match kind:
			"cover":
				p = ragged(size.x, size.y, 30.0, 3.0, -1.0, _rng(1))
			"photo":
				p = ragged(size.x, size.y, 40.0, 1.2, -1.0, _rng(1))
			"sticky":
				p = ragged(size.x, size.y, 50.0, 1.4, -1.0, _rng(1))
			"torn":
				p = ragged(size.x, size.y, 11.0, 1.6, 7.0, _rng(1))
			_:
				p = ragged(size.x, size.y, 26.0, 2.6, -1.0, _rng(1))
		if Geometry2D.triangulate_polygon(p).is_empty():
			p = rect
		_poly = p
		_poly_size = size
		return _poly

	static func _shift(p: PackedVector2Array, d: Vector2) -> PackedVector2Array:
		var o := PackedVector2Array()
		for v in p:
			o.append(v + d)
		return o

	func _draw() -> void:
		var out := _outline()
		var col := _colour()
		# the shadow it throws on whatever is under it
		if kind != "cover":
			draw_colored_polygon(_shift(out, Vector2(5, 7)), Color(0, 0, 0, 0.16))
			draw_colored_polygon(_shift(out, Vector2(3, 4)), Color(0, 0, 0, 0.22))
		else:
			draw_colored_polygon(_shift(out, Vector2(6, 9)), Color(0, 0, 0, 0.35))
		# page edges stacked beneath the spread's two pages
		if kind == "page_l" or kind == "page_r":
			var dir := -1.0 if kind == "page_l" else 1.0
			for i in range(3, 0, -1):
				var e := _shift(out, Vector2(dir * 2.0 * i, 3.0 * i))
				draw_colored_polygon(e, col.darkened(0.10 + 0.05 * i))
				draw_polyline(e, col.darkened(0.45), 1.0)
		draw_colored_polygon(out, col)
		match kind:
			"cover":
				_draw_cover()
			"page_l", "page_r":
				_draw_page()
			"photo":
				_draw_photo()
			"sticky":
				_draw_sticky(col)
			"torn":
				_draw_torn(col)
		var closed := PackedVector2Array(out)
		closed.append(out[0])
		draw_polyline(closed, col.darkened(0.5 if kind == "cover" else 0.35), 1.0)

	func _draw_cover() -> void:
		var r := _rng(2)
		for i in 140:
			var c := Color(0, 0, 0, 0.10) if r.randf() < 0.5 else Color(1, 1, 1, 0.045)
			draw_rect(Rect2(r.randf() * size.x, r.randf() * size.y, r.randf_range(2.0, 9.0), r.randf_range(1.0, 3.0)), c)
		var inset := 9.0
		var col := Color(0.62, 0.50, 0.34, 0.5)
		draw_dashed_line(Vector2(inset, inset), Vector2(size.x - inset, inset), col, 1.0, 5.0)
		draw_dashed_line(Vector2(inset, size.y - inset), Vector2(size.x - inset, size.y - inset), col, 1.0, 5.0)
		draw_dashed_line(Vector2(inset, inset), Vector2(inset, size.y - inset), col, 1.0, 5.0)
		draw_dashed_line(Vector2(size.x - inset, inset), Vector2(size.x - inset, size.y - inset), col, 1.0, 5.0)

	func _draw_page() -> void:
		var r := _rng(3)
		var left := kind == "page_l"
		# paper fibre + foxing
		for i in 90:
			draw_rect(Rect2(r.randf() * size.x, r.randf() * size.y, r.randf_range(1.0, 5.0), 1.0), Color(0.45, 0.30, 0.12, r.randf_range(0.04, 0.10)))
		for i in 5:
			draw_circle(Vector2(r.randf_range(20, size.x - 20), r.randf_range(20, size.y - 20)), r.randf_range(7.0, 20.0), Color(0.55, 0.38, 0.14, 0.045))
		# the gutter: a soft dark fold on the side that meets the spine, and the curl of the page leaving it
		var gx := size.x if left else 0.0
		for i in 26:
			var a := 0.20 * pow(1.0 - float(i) / 26.0, 2.0)
			var x := gx - (i + 1) * 1.0 if left else gx + i
			draw_rect(Rect2(x, 4, 1.0, size.y - 8), Color(0.10, 0.06, 0.03, a))
		# a coffee ring (somewhere different in every character's journal) + a thumb smudge
		var cx := r.randf_range(size.x * 0.55, size.x - 70.0) if not left else r.randf_range(60.0, size.x * 0.4)
		var cy := r.randf_range(size.y * 0.62, size.y - 60.0)
		draw_circle(Vector2(cx, cy), 24.0, Color(0.50, 0.30, 0.10, 0.045))
		var a0 := r.randf() * TAU
		draw_arc(Vector2(cx, cy), 24.0, a0, a0 + 5.2, 28, Color(0.42, 0.24, 0.08, 0.30), 2.4)
		draw_arc(Vector2(cx + 1.0, cy + 1.0), 22.0, a0 + 0.4, a0 + 4.1, 24, Color(0.42, 0.24, 0.08, 0.14), 1.4)
		draw_circle(Vector2(r.randf_range(40, size.x - 40), r.randf_range(30, size.y * 0.4)), 11.0, Color(0.30, 0.20, 0.10, 0.06))

	func _draw_photo() -> void:
		var back := Rect2(11, 11, size.x - 22, size.y - 58)
		draw_rect(back, Color(0.27, 0.30, 0.34))
		draw_rect(Rect2(back.position, Vector2(back.size.x, back.size.y * 0.5)), Color(0.34, 0.38, 0.43, 0.7))
		# tape on the top corners, each at its own skew
		for t in [[Vector2(10, 4), -0.45], [Vector2(size.x - 10, 6), 0.5]]:
			draw_set_transform(t[0], t[1])
			draw_rect(Rect2(-24, -9, 48, 18), Color(0.92, 0.88, 0.62, 0.62))
			draw_rect(Rect2(-24, -9, 48, 18), Color(0.5, 0.45, 0.2, 0.35), false, 1.0)
		draw_set_transform(Vector2.ZERO)

	func _draw_sticky(col: Color) -> void:
		draw_rect(Rect2(0, 0, size.x, 15), col.darkened(0.07))
		draw_line(Vector2(0, 15), Vector2(size.x, 15), col.darkened(0.2), 1.0)
		# the lower corner is lifting
		draw_colored_polygon(PackedVector2Array([Vector2(size.x, size.y - 26), Vector2(size.x - 26, size.y), Vector2(size.x, size.y)]), col.lightened(0.18))
		draw_line(Vector2(size.x, size.y - 26), Vector2(size.x - 26, size.y), col.darkened(0.25), 1.0)

	func _draw_torn(col: Color) -> void:
		var r := _rng(4)
		# faint rules + the margin
		var y := 40.0
		while y < size.y - 8.0:
			draw_line(Vector2(34, y), Vector2(size.x - 12, y), Color(0.35, 0.50, 0.70, 0.30), 1.0)
			y += 23.0
		draw_line(Vector2(38, 14), Vector2(38, size.y - 6), Color(0.78, 0.30, 0.28, 0.40), 1.0)
		# spiral holes down the left edge (the edge they were torn from)
		y = 22.0
		while y < size.y - 12.0:
			draw_circle(Vector2(16, y), 5.0, Color(0.10, 0.07, 0.05, 0.85))
			draw_arc(Vector2(16, y), 5.0, 0.0, TAU, 14, col.darkened(0.3), 1.0)
			y += 27.0
		for i in 6:
			draw_rect(Rect2(r.randf() * size.x, r.randf() * size.y, r.randf_range(2.0, 6.0), 1.0), Color(0.4, 0.28, 0.12, 0.10))


# ---- A hand-drawn underline ---------------------------------------------------------------------------------------
class _Scribble:
	extends Control

	var ink: Color = Color(0.2, 0.15, 0.09)

	func _draw() -> void:
		for pass_i in 2:
			var pts := PackedVector2Array()
			var x := 0.0
			while x <= size.x:
				pts.append(Vector2(x, size.y * 0.5 + sin(x * 0.07 + pass_i * 1.7) * 2.6 + sin(x * 0.31) * 0.9 + pass_i * 3.0))
				x += 5.0
			draw_polyline(pts, Color(ink.r, ink.g, ink.b, 0.8 - 0.3 * pass_i), 2.4 - pass_i * 0.8)


# ---- A coloured paper tab sticking out of the page edge — click it to turn to that section ------------------------------
class _Bookmark:
	extends Control

	const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
	signal picked(index: int)

	var text: String = ""
	var color: Color = Color(0.7, 0.3, 0.2)
	var index: int = 0
	var base_x: float = 0.0
	var active: bool = false
	var font: Font = null
	var hover: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): hover = true; queue_redraw())
		mouse_exited.connect(func(): hover = false; queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(index)
			accept_event()

	func _draw() -> void:
		var w := size.x - (0.0 if active else 16.0) + (6.0 if hover and not active else 0.0)
		var h := size.y
		var shape := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - 12.0, h * 0.5), Vector2(w, h), Vector2(0, h)])
		var shifted := PackedVector2Array()
		for p in shape:
			shifted.append(p + Vector2(3, 4))
		draw_colored_polygon(shifted, Color(0, 0, 0, 0.28))
		var c := color if active else color.darkened(0.14)
		draw_colored_polygon(shape, c)
		var line := PackedVector2Array(shape)
		line.append(shape[0])
		draw_polyline(line, c.darkened(0.45), 1.0)
		draw_line(Vector2(2, 3), Vector2(w - 2, 3), Color(1, 1, 1, 0.22), 1.0)
		var f: Font = font if font != null else FONT
		var fs := 19
		while fs > 11 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w - 34.0:
			fs -= 1
		draw_string(f, Vector2(16, h * 0.5 + fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.09, 0.06, 0.04, 0.92))


# ---- The close scrap: a torn corner of paper, top right -------------------------------------------------------------
class _CloseScrap:
	extends Control

	const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
	signal pressed

	var hover: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pivot_offset = size * 0.5
		mouse_entered.connect(func(): hover = true; queue_redraw())
		mouse_exited.connect(func(): hover = false; queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 91
		var p := PackedVector2Array()
		for i in 7:
			p.append(Vector2(float(i) / 6.0 * size.x, rng.randf() * 4.0))
		p.append(Vector2(size.x - rng.randf() * 3.0, size.y))
		p.append(Vector2(0, size.y - rng.randf() * 3.0))
		var sh := PackedVector2Array()
		for v in p:
			sh.append(v + Vector2(2, 3))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.3))
		draw_colored_polygon(p, Color(0.86, 0.80, 0.66) if hover else Color(0.74, 0.67, 0.53))
		draw_string(FONT, Vector2(8, size.y * 0.5 + 5.0), "CLOSE", HORIZONTAL_ALIGNMENT_LEFT, size.x - 10.0, 12, Color(0.35, 0.10, 0.08))


# ---- The fog-of-war building map (a code-drawn strip of all 30 floors, sketched in the character's hand) ------------------
class _MapView:
	extends Control

	const FONT := preload("res://assets/fonts/PixelOperator8.ttf")

	var hand: Font = null
	var ink: Color = Color(0.20, 0.15, 0.09)

	func _ready() -> void:
		custom_minimum_size = Vector2(300, 400)

	func _corpse_floors() -> Dictionary:
		var out: Dictionary = {}
		for k in WorldState.player_corpses:
			out[str(int(WorldState.player_corpses[k].get("floor", -1)))] = true
		return out

	## A pen-drawn rectangle: four slightly wandering sides that overshoot a little at the corners.
	func _sketch(r: Rect2, col: Color, width: float, seed_: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_
		var j := func() -> float: return rng.randf_range(-1.1, 1.1)
		var a := r.position
		var b := Vector2(r.end.x, r.position.y)
		var c := r.end
		var d := Vector2(r.position.x, r.end.y)
		draw_line(a + Vector2(-1.5, j.call()), b + Vector2(1.5, j.call()), col, width)
		draw_line(b + Vector2(j.call(), -1.5), c + Vector2(j.call(), 1.5), col, width)
		draw_line(c + Vector2(1.5, j.call()), d + Vector2(-1.5, j.call()), col, width)
		draw_line(d + Vector2(j.call(), 1.5), a + Vector2(j.call(), -1.5), col, width)

	func _draw() -> void:
		var f: Font = hand if hand != null else FONT
		var w: float = size.x
		var h: float = size.y
		var gutter := 30.0
		var barx := gutter + 4.0
		var barw: float = w - barx - 10.0
		var rows := 31                          # floors 30 … 1 plus the lobby (0)
		var rh: float = h / float(rows)
		var corpses := _corpse_floors()
		for fl in range(0, 31):
			var y: float = float(30 - fl) * rh      # floor 30 at the top, the lobby at the bottom
			var r := Rect2(barx, y + 1.5, barw, rh - 3.0)
			var visited: bool = WorldState.visited_floors.has(str(fl))
			# Fog: floors you haven't been to are shaded in soft pencil; visited floors are left as clear paper.
			if visited:
				draw_rect(r, Color(ink.r, ink.g, ink.b, 0.06))
			else:
				draw_rect(r, Color(0.25, 0.22, 0.18, 0.15))
				for hx in range(0, int(barw), 10):
					draw_line(Vector2(barx + hx, r.end.y), Vector2(barx + hx + 5.0, r.position.y), Color(0.2, 0.17, 0.13, 0.11), 1.0)
			_sketch(r, Color(ink.r, ink.g, ink.b, 0.55 if visited else 0.30), 1.2, fl * 53 + 7)
			if visited:
				# The dead were seen here (red) and/or a fallen character lies here (blue).
				if WorldState.floors_enemy_seen.has(str(fl)):
					draw_circle(Vector2(barx + barw - 12.0, y + rh * 0.5), 3.5, Color(0.75, 0.16, 0.13))
				if corpses.has(str(fl)):
					draw_circle(Vector2(barx + barw - 26.0, y + rh * 0.5), 3.5, Color(0.30, 0.45, 0.85))
			if fl == WorldState.current_floor:
				_sketch(Rect2(r.position - Vector2(2, 1), r.size + Vector2(4, 2)), Color(0.80, 0.22, 0.12), 2.2, 991)   # YOU ARE HERE
				draw_string(f, Vector2(barx + 8.0, y + rh - 3.0), "← you",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.70, 0.16, 0.08))
			# Floor number gutter every 5th floor (+ floor 1); "L" marks the lobby.
			if fl == 0 or fl % 5 == 0 or fl == 1:
				draw_string(f, Vector2(2.0, y + rh - 3.0), "L" if fl == 0 else str(fl),
					HORIZONTAL_ALIGNMENT_LEFT, gutter, 15, ink)
