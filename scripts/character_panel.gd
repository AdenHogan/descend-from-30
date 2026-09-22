extends Control

# CHARACTER PROFILE panel — opened by clicking the HUD health portrait (hud.gd makes that
# portrait a hover-glow button). A jumping-off point for lore: it shows the RUN's current
# character (WorldState.current_character()) at full health, their name/subtitle, and a lore
# body, plus a tabbed layout so NPC stories can live here too. All the words are DATA
# (CHAR_LORE / NPC_STORIES) so the owner fills them in one place without touching layout.
# Purely a reader — it pauses the game while open (a menu, so lore is comfortably readable).
#
# Built entirely in code (no .tscn) so the layout stays in one reviewable file; added as a
# child of the HUD CanvasLayer, so it draws above the action bar.

# Per-character lore. Keyed by the character id used for the portrait files
# (WorldState.CHARACTERS). name/subtitle/lore are placeholders for the owner to author;
# a missing entry falls back to a prettified id + a "no lore yet" note, so a new character
# never crashes the panel.
const CHAR_LORE := {
	"blond_man": {
		"name": "The Tenant",
		"subtitle": "Floor 30 — morning",
		"lore": "Lore coming soon. (Owner: write this character's story here.)",
	},
	"dark_woman": {
		"name": "The Nurse",
		"subtitle": "Floor 30 — afternoon",
		"lore": "Lore coming soon. (Owner: write this character's story here.)",
	},
	"bald_man": {
		"name": "The Super",
		"subtitle": "Floor 30 — night",
		"lore": "Lore coming soon. (Owner: write this character's story here.)",
	},
	"blond_woman": {
		"name": "The Neighbour",
		"subtitle": "Floor 30",
		"lore": "Lore coming soon. (Owner: write this character's story here.)",
	},
}

# NPC stories the player has uncovered — a placeholder list for now; a real system would
# unlock entries as the player meets NPCs. Each: {name, story}.
const NPC_STORIES: Array = []

var _prev_paused: bool = false
var panel: PanelContainer = null
var title_label: Label = null
var subtitle_label: Label = null
var lore_text: RichTextLabel = null
var portrait_rect: TextureRect = null
var npc_text: RichTextLabel = null
var tabs: TabContainer = null


func _ready() -> void:
	name = "CharacterPanel"
	process_mode = Node.PROCESS_MODE_ALWAYS   # stay live while the tree is paused
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # only the dim/panel capture input
	_build()


func _build() -> void:
	# Full-screen dim that also closes the panel when clicked OUTSIDE the card.
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	panel = PanelContainer.new()
	panel.name = "Card"
	panel.custom_minimum_size = Vector2(720, 470)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	# Center it: anchor to middle, then offset by half its min size.
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -360
	panel.offset_top = -235
	panel.offset_right = 360
	panel.offset_bottom = 235
	panel.mouse_filter = Control.MOUSE_FILTER_STOP   # clicks on the card do NOT close it
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Header: title + close button.
	var header := HBoxContainer.new()
	vbox.add_child(header)
	title_label = Label.new()
	title_label.text = "Character"
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tabs)

	# --- Tab 1: Profile ---
	var profile := HBoxContainer.new()
	profile.name = "Profile"
	profile.add_theme_constant_override("separation", 16)
	tabs.add_child(profile)

	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(200, 250)
	portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	profile.add_child(portrait_rect)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	profile.add_child(right)
	subtitle_label = Label.new()
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.modulate = Color(0.8, 0.8, 0.85)
	right.add_child(subtitle_label)
	lore_text = RichTextLabel.new()
	lore_text.bbcode_enabled = true
	lore_text.fit_content = false
	lore_text.scroll_active = true
	lore_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(lore_text)

	# --- Tab 2: NPCs (placeholder, grows as stories are uncovered) ---
	npc_text = RichTextLabel.new()
	npc_text.name = "NPCs"
	npc_text.bbcode_enabled = true
	npc_text.scroll_active = true
	tabs.add_child(npc_text)


func open() -> void:
	_refresh()
	visible = true
	_prev_paused = get_tree().paused
	get_tree().paused = true


func close() -> void:
	visible = false
	# Only lift the pause if WE set it (don't stomp a real pause menu that was already up).
	get_tree().paused = _prev_paused


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _refresh() -> void:
	var cid: String = WorldState.current_character()
	var info: Dictionary = CHAR_LORE.get(cid, {})
	var pretty := _prettify(cid)
	title_label.text = str(info.get("name", pretty))
	subtitle_label.text = str(info.get("subtitle", ""))
	lore_text.text = str(info.get("lore", "No lore recorded yet for %s." % pretty))
	# Show the character at FULL health in their profile, whatever their current state is.
	var tex = load("res://assets/Health_Bar/%s - 1 - Healthy.png" % cid)
	if tex != null:
		portrait_rect.texture = tex
	# NPC tab.
	if NPC_STORIES.is_empty():
		npc_text.text = "[i]Stories you uncover from the building's residents will collect here.[/i]"
	else:
		var body := ""
		for entry in NPC_STORIES:
			body += "[b]%s[/b]\n%s\n\n" % [str(entry.get("name", "?")), str(entry.get("story", ""))]
		npc_text.text = body


func _prettify(cid: String) -> String:
	var parts := cid.split("_", false)
	var out := ""
	for p in parts:
		if p.length() > 0:
			out += p.substr(0, 1).to_upper() + p.substr(1) + " "
	return out.strip_edges()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
