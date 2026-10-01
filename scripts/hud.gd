extends CanvasLayer

# Health portraits are per-CHARACTER now (the run's character — WorldState.current_character()).
# Each set is 6 stage files in assets/Health_Bar/<char_id> - N - Stage.png; loaded on demand and
# re-loaded when the run's character changes (see _ensure_portraits).
const PORTRAIT_STAGES := [
	"1 - Healthy", "2 - Hurt", "3 - Injured", "4 - Wounded", "5 - Severely Wounded", "6 - Dying",
]
var _portraits: Array = []
var _loaded_char: String = ""

# The health portrait is a CLICKABLE BUTTON: hovering gives it a mild shiny white outline
# + a gentle bounce so it reads as clickable, and a click opens the character profile panel
# (lore, with tabs for NPC stories).
var character_panel: Control = null
var _portrait_outline_mat: ShaderMaterial = null
var _portrait_bounce: Tween = null

@onready var portrait = $Control/Portrait
@onready var floor_label = $Control/FloorLabel
@onready var color_rect = $Control/ColorRect
@onready var hbox = $Control/HBoxContainer
@onready var slots = [
	$Control/HBoxContainer/Slot1,
	$Control/HBoxContainer/Slot2,
	$Control/HBoxContainer/Slot3,
	$Control/HBoxContainer/Slot4,
	$Control/HBoxContainer/Slot5
]
@onready var slot_locked = $Control/HBoxContainer/SlotLocked

var mode_label: Button = null   # clickable scavenge/combat toggle — on the name row, after the name
var mode_tip: PanelContainer = null      # the hover explanation of the two modes
var _mode_tip_blocks: Array = []         # [{head, body}] for scavenge, combat
var _mode_tip_hint: Label = null
var _mode_hover: bool = false
var _mode_hover_t: float = 0.0
var slot_icons: Array = []
var slot_durability_bars: Array = []
var selected_slot: int = -1
var feedback_label: Label = null
var feedback_timer: float = 0.0
# Player-speech dialogue (tutorial prompts): a centred first-person line, its
# own panel above the action bar. Transient lines auto-hide; prompt lines
# persist (a paused teaching beat) until TutorialManager dismisses them.
var dialogue_panel: PanelContainer = null
var dialogue_label: Label = null
var dialogue_hint: Label = null
var dialogue_timer: float = 0.0
var context_menu: Control = null
var context_slot: int = -1
var last_click_time: float = 0.0
var last_click_slot: int = -1
const DOUBLE_CLICK_TIME = 0.4
var slot_key_labels: Array = []

# Drag-and-drop inventory: hold LMB on a slot and move to drag its item.
# Drop on another slot to swap; bullets onto a gun (or gun onto bullets)
# loads the magazine; drop on the game world to discard.
const DRAG_THRESHOLD = 6.0
var drag_from: int = -1
var drag_armed_pos: Vector2 = Vector2.ZERO
var drag_active: bool = false
var drag_icon: TextureRect = null

var stamina_bar: Control = null
var wallet_label: Label = null
var scrap_label: Label = null
var boon_badge: Button = null          # "a boon is waiting" — click to choose (docs/PROGRESSION.md)
var boon_ui = null
var slot_level_labels: Array = []
var listen_overlay: CanvasLayer = null
const STAMINA_BAR_W = 170.0            # the stamina bar lies under the portrait's name (bottom-left)
const STAMINA_BAR_H = 5.0                            # thin: it is the NAME ROW'S UNDERLINE as well as the stamina gauge

const SCREEN_W = 1152.0
const SCREEN_H = 648.0
const SLOT_SIZE = 64.0

# NO BOTTOM BAR (owner round 26c: "remove the bottom bar entirely"): the world fills the whole screen
# (StairPan.HUD_BAR_H = 0) and the HUD floats over it. Identity sits bottom-left — the character's bust
# LARGE and uncropped (owner: the small circle "doesn't look as interesting"), with the name, condition,
# stamina bar, and the mode toggle + in-hand line beside it. The backpack button is bottom-right with the
# notes + scrap beside it; place + time top-right. There is NO hotbar (owner: "redundant if we have the
# wheel"): the six slots still exist as an OPT-IN (`set_hotbar_visible`), hidden by default — the pack
# ring and the quick wheel are the inventory, number keys 1-5 still equip. Because there is no band to test a click against any more,
# "is the pointer on the HUD" is a hit-test of the real widgets (`pointer_over_widget`), never a y-range.
const CLUSTER_MARGIN = 16.0
const PORTRAIT_W = 132.0                             # the bust, UNCROPPED and large (owner: not a small circle)
const PORTRAIT_H = 165.0                             # (281x351 art → 0.47 scale)
const HOTBAR_Y = 12.0
const HOTBAR_W = SLOT_SIZE * 6 + 8 * 5
const IDENT_Y = SCREEN_H - PORTRAIT_H - 4.0          # the bottom-left block's top edge
const IDENT_TEXT_X = PORTRAIT_W + 16.0               # the name row / stamina underline / in-hand column
const IDENT_ROW_Y = SCREEN_H - 68.0                  # the NAME + MODE row; the stamina underline sits right under it
const CURRENCY_X = SCREEN_W - CLUSTER_MARGIN - 124.0   # top-right: notes + scrap (icon, then the number)
const CURRENCY_Y = 12.0
const CURRENCY_ROW = 34.0
const PACK_BTN_W = 64.0
const PACK_BTN_H = 96.0
const INK := Color(0.075, 0.07, 0.085, 1.0)
const PANEL_EDGE := Color(0.29, 0.275, 0.32, 1.0)
const AMBER := Color(0.89, 0.647, 0.247, 1.0)
const TEXT_DIM := Color(0.64, 0.61, 0.53, 1.0)
const HEALTH_HINTS := ["Steady", "Walking it off", "Hurting", "Bleeding", "Barely standing", "Dying"]

var name_label: Label = null
var wallet_icon: TextureRect = null
var scrap_icon: TextureRect = null
var equip_box: Control = null            # the in-hand item box right of the name row (hud_equip_box.gd)
var wheel_hint: Label = null
var quick_wheel: Control = null
var pack_wheel: Control = null           # the backpack ring (pack_wheel.gd) — real time, whole bag
var pack_button: Control = null          # the clickable backpack in the strip (hud_pack_button.gd)
var _health_stage: int = 0

func _ready() -> void:
	_layout()
	_create_cluster()
	_create_mode_label()
	_create_slot_icons()
	_create_item_tip()
	_create_mode_tip()
	_create_feedback_label()
	_create_dialogue_panel()
	_create_context_menu()
	_create_stamina_bar()
	_create_wallet_label()
	_create_scrap_label()
	_create_boon_badge()
	_create_quick_wheel()
	_create_pack()
	_create_dev_warp_prompt()
	_create_dev_item_prompt()
	_create_dev_menu()
	# Listen-mode grey/ping/report overlay (own CanvasLayer above the HUD).
	listen_overlay = preload("res://scripts/listen_overlay.gd").new()
	add_child(listen_overlay)
	_create_smoke_fog()
	_create_speech_bubble()
	update_floor_label()
	update_portrait(0)
	_setup_portrait_button()
	_create_character_panel()
	update_mode_indicator()
	refresh_inventory()

func _layout() -> void:
	# The root Control spans the whole screen: it must NOT swallow mouse
	# events or click-to-move/world clicks never reach the game (playtest
	# bug). Children (slots, buttons) keep their own filters and stay
	# clickable.
	$Control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Floating text labels must never swallow a world click (click-to-move):
	# an IGNORE parent does NOT shield STOP children, so set each explicitly.
	floor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The old opaque bottom strip is gone (owner round 26c) — the node stays in hud.tscn but never shows.
	color_rect.visible = false
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# No floor / time / run text any more (owner round 26e: "extra bloat that isn't clean" — the floor is
	# announced on the stairs, and the sign on the wall says it). The scene's FloorLabel node stays (many
	# callers still `update_floor_label()`) but never shows; the top-right is the wallet + scrap now.
	floor_label.visible = false

	# The hotbar floats top-centre (there is no bar to sit in).
	hbox.set_anchors_preset(Control.PRESET_TOP_LEFT)        # the scene anchors it right-centre; pin it where we say
	hbox.grow_horizontal = Control.GROW_DIRECTION_END
	hbox.grow_vertical = Control.GROW_DIRECTION_END
	hbox.position = Vector2((SCREEN_W - HOTBAR_W) / 2.0, HOTBAR_Y)
	hbox.add_theme_constant_override("separation", 8)
	hbox.visible = hotbar_visible                       # hidden by default (see set_hotbar_visible)
	# The former "locked 6th slot" is now the inventory-upgrade unlock target,
	# so it joins the real slot list; _update_slot_locks() greys it until an
	# upgrade grants it.
	slots.append(slot_locked)
	for slot in slots:
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.add_theme_stylebox_override("panel", _make_slot_style(false))


func _hud_label(text: String, size: int, col: Color, pos: Vector2, dim: Vector2, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	# One floating HUD line: never swallows a world click (click-to-move), outlined so it reads on any wall.
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.position = pos
	l.size = dim
	l.horizontal_alignment = align
	$Control.add_child(l)
	return l


func _create_cluster() -> void:
	# --- bottom-left: the character's bust, LARGE and uncropped, is THE clickable button (hover rim /
	# bounce / profile panel). The portrait art already changes with health, so it IS the health display
	# (no ring round it any more — owner: the circular patch was restrictive). ---
	portrait.get_parent().remove_child(portrait)
	$Control.add_child(portrait)
	portrait.set_anchors_preset(Control.PRESET_TOP_LEFT)
	portrait.position = Vector2(CLUSTER_MARGIN - 8.0, IDENT_Y)
	portrait.size = Vector2(PORTRAIT_W, PORTRAIT_H)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tx: float = IDENT_TEXT_X
	name_label = _hud_label("", 16, Color(0.93, 0.89, 0.82), Vector2(tx, IDENT_ROW_Y), Vector2(240, 22))

	# --- right of the name row: the item in hand, as a BOX (icon + a durability outline; owner round 27) ---
	equip_box = preload("res://scripts/hud_equip_box.gd").new()
	$Control.add_child(equip_box)
	var pack_left: float = SCREEN_W - CLUSTER_MARGIN - PACK_BTN_W
	wheel_hint = _hud_label("", 12, TEXT_DIM, Vector2(pack_left - 264.0, SCREEN_H - 24.0), Vector2(250, 18), HORIZONTAL_ALIGNMENT_RIGHT)



func _create_quick_wheel() -> void:
	# Added late so it draws over the cluster and the hotbar (and under the dev panels).
	quick_wheel = preload("res://scripts/quick_wheel.gd").new()
	$Control.add_child(quick_wheel)
	update_wheel_hint()


func _create_pack() -> void:
	# The backpack: THE inventory. A button in the bottom-right corner + its ring. The ring is added AFTER
	# the quick wheel so it draws over it. (Dropping a loot item onto this button takes it into the pack.)
	pack_button = preload("res://scripts/hud_pack_button.gd").new()
	pack_button.position = Vector2(SCREEN_W - CLUSTER_MARGIN - PACK_BTN_W, SCREEN_H - PACK_BTN_H - 8.0)
	$Control.add_child(pack_button)
	pack_button.pressed.connect(func() -> void:
		if pack_wheel != null:
			pack_wheel.toggle())
	pack_wheel = preload("res://scripts/pack_wheel.gd").new()
	$Control.add_child(pack_wheel)
	pack_button.key_text = action_key_name("open_pack", "B")


func _create_mode_label() -> void:
	# The MODE sits on the name row, right after the name ("THE NEIGHBOUR  SCAVENGE"): click it (or press the
	# mode key) to switch, hover it for a short explanation of the two modes. A flat, padding-free Button so
	# it reads as text.
	mode_label = Button.new()
	mode_label.flat = true
	mode_label.focus_mode = Control.FOCUS_NONE
	mode_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mode_label.add_theme_font_size_override("font_size", 16)
	mode_label.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		mode_label.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	mode_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	mode_label.add_theme_constant_override("outline_size", 4)
	mode_label.position = Vector2(IDENT_TEXT_X + 140.0, IDENT_ROW_Y)        # same baseline as the name (measured: -1 sat one pixel high)
	mode_label.pressed.connect(_on_mode_button)
	mode_label.mouse_entered.connect(func() -> void:
		_mode_hover = true
		_mode_hover_t = 0.0)
	mode_label.mouse_exited.connect(func() -> void:
		_mode_hover = false
		if mode_tip != null:
			mode_tip.visible = false)
	$Control.add_child(mode_label)


func _on_mode_button() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("request_mode_toggle"):
		player.request_mode_toggle()

func _create_slot_icons() -> void:
	for i in range(slots.size()):
		var slot = slots[i]
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# centred in the slot (owner round 25: the icon sat in the top-left corner — setting
		# anchors_preset on a code-built Control did nothing, so it stayed at the slot's origin)
		icon.position = Vector2(SLOT_SIZE - ICON_PX, SLOT_SIZE - ICON_PX) * 0.5
		icon.size = Vector2(ICON_PX, ICON_PX)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		slot.add_child(icon)
		slot_icons.append(icon)

		# Durability bar — thin strip at bottom of slot
		var dur_bg = ColorRect.new()
		dur_bg.size = Vector2(SLOT_SIZE - 4, 4)
		dur_bg.position = Vector2(2, SLOT_SIZE - 6)
		dur_bg.color = Color(0.2, 0.2, 0.2, 1.0)
		dur_bg.visible = false
		slot.add_child(dur_bg)

		var dur_fill = ColorRect.new()
		dur_fill.size = Vector2(SLOT_SIZE - 4, 4)
		dur_fill.position = Vector2(2, SLOT_SIZE - 6)
		dur_fill.color = Color(0.2, 0.8, 0.2, 1.0)
		dur_fill.visible = false
		slot.add_child(dur_fill)
		
		var key_label = Label.new()
		key_label.add_theme_font_size_override("font_size", 12)
		key_label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05, 1.0))
		key_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
		key_label.add_theme_constant_override("outline_size", 2)
		key_label.position = Vector2(2, 2)
		key_label.size = Vector2(SLOT_SIZE - 4, 16)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.visible = false
		slot.add_child(key_label)
		slot_key_labels.append(key_label)
		# Workbench level tag ("Lv3") in the slot's bottom-left, clear of the top tag.
		var lv_label = Label.new()
		lv_label.add_theme_font_size_override("font_size", 10)
		lv_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3, 1.0))
		lv_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		lv_label.add_theme_constant_override("outline_size", 3)
		lv_label.position = Vector2(3, SLOT_SIZE - 22)
		lv_label.size = Vector2(SLOT_SIZE - 6, 14)
		lv_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lv_label.visible = false
		slot.add_child(lv_label)
		slot_level_labels.append(lv_label)

		slot_durability_bars.append({"bg": dur_bg, "fill": dur_fill})

		slot.gui_input.connect(_on_slot_gui_input.bind(i))

func _create_feedback_label() -> void:
	feedback_label = Label.new()
	feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # never eat world clicks
	feedback_label.add_theme_font_size_override("font_size", 14)
	feedback_label.position = Vector2(SCREEN_W / 2 - 250, 34.0)   # top-centre
	feedback_label.size = Vector2(500, 30)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.modulate = Color(1, 1, 0.5, 0)
	$Control.add_child(feedback_label)


# --- World-anchored loot prompt -------------------------------------------
# A lootable's "<name>  [Click] Take" used to be a Label sitting in the WORLD,
# so the zoomed-in room camera blew it up huge and blurry and it spilled past
# the walls. Instead it's a screen-space HUD label (crisp, exactly like the
# dialogue box) that TRACKS the item's projected screen position each frame and
# is clamped inside the viewport, so it's sharp, small, and never out of bounds.
# --- Crisp, world-anchored interaction prompts (screen-space) --------------
# Doors, stairwells, balcony zones and dropped loot all post their prompt here.
# Each renders as a small dark pill (matching the dialogue box) with the crisp
# pixel font at ONE consistent size, projected from the owner's world anchor each
# frame and clamped fully on-screen and above the HUD bar. Several can show at
# once (e.g. a door prompt AND a loot prompt) — one per owner, so one leaving
# range never wipes another's.
const WORLD_PROMPT_FONT_SIZE := 17
const WORLD_PROMPT_PAD := Vector2(13, 6)   # padding around the text inside the pill
const WORLD_PROMPT_GAP := 12.0             # screen px the pill floats above its anchor
var _world_prompts: Dictionary = {}        # owner instance_id -> {panel, label, pos}


func _make_world_prompt() -> Dictionary:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE   # never eat world clicks
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.86)
	style.border_color = Color(0.0, 0.0, 0.0, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", WORLD_PROMPT_FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0.96, 0.96, 1.0, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)   # fills + centres in the pill
	panel.add_child(label)
	panel.visible = false
	$Control.add_child(panel)
	return {"panel": panel, "label": label, "pos": Vector2.ZERO}


func show_world_prompt(prompt_owner: Node, text: String, world_pos: Vector2) -> void:
	if prompt_owner == null:
		return
	var id := prompt_owner.get_instance_id()
	if not _world_prompts.has(id):
		_world_prompts[id] = _make_world_prompt()
	var e = _world_prompts[id]
	e["label"].text = text
	e["pos"] = world_pos
	e["panel"].visible = true


func hide_world_prompt(prompt_owner: Node) -> void:
	# Only this owner's own pill is hidden, so one drop/door leaving range can't
	# wipe another's prompt.
	if prompt_owner == null:
		return
	var e = _world_prompts.get(prompt_owner.get_instance_id())
	if e != null:
		e["panel"].visible = false


func _update_world_prompt() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	for id in _world_prompts.keys():
		# Owner gone (scene change, freed drop): drop its pill so nothing leaks.
		if instance_from_id(id) == null:
			_world_prompts[id]["panel"].queue_free()
			_world_prompts.erase(id)
			continue
		var e = _world_prompts[id]
		var panel: Panel = e["panel"]
		if not panel.visible:
			continue
		var label: Label = e["label"]
		var font := label.get_theme_font("font")
		var tw: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, WORLD_PROMPT_FONT_SIZE).x
		var pw: float = tw + WORLD_PROMPT_PAD.x * 2.0
		var ph: float = float(WORLD_PROMPT_FONT_SIZE) + WORLD_PROMPT_PAD.y * 2.0
		panel.size = Vector2(pw, ph)
		# Project the anchor into design pixels, float the pill above it, then clamp
		# fully on-screen and above the HUD bar.
		var screen: Vector2 = (e["pos"] - cam.get_screen_center_position()) * cam.zoom \
			+ Vector2(SCREEN_W, SCREEN_H) / 2.0
		var x: float = clampf(screen.x - pw / 2.0, 6.0, SCREEN_W - pw - 6.0)
		var y: float = clampf(screen.y - ph - WORLD_PROMPT_GAP, 6.0, SCREEN_H - 6.0 - ph)
		panel.position = Vector2(x, y)


func world_prompt_panel(prompt_owner: Node) -> Panel:
	# Test/inspection accessor: the on-screen pill Panel for an owner, or null.
	if prompt_owner == null:
		return null
	var e = _world_prompts.get(prompt_owner.get_instance_id())
	return e["panel"] if e != null else null

func _create_dialogue_panel() -> void:
	dialogue_panel = PanelContainer.new()
	# Renders while the tree is paused (teaching beats pause the game); a
	# CanvasItem draws regardless of pause, but keep it ALWAYS to be safe.
	dialogue_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	# Pure display — must NEVER swallow world clicks (click-to-move).
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.92)
	style.border_color = Color(0.75, 0.75, 0.8, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	dialogue_panel.add_theme_stylebox_override("panel", style)
	var box_w = 640.0
	dialogue_panel.position = Vector2((SCREEN_W - box_w) / 2, 96)
	dialogue_panel.custom_minimum_size = Vector2(box_w, 0)
	dialogue_panel.visible = false

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	# IGNORE doesn't shield children — they hit-test independently.
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.add_child(vbox)

	dialogue_label = Label.new()
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_label.add_theme_font_size_override("font_size", 20)
	dialogue_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1.0))
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.custom_minimum_size = Vector2(box_w - 28, 0)
	vbox.add_child(dialogue_label)

	dialogue_hint = Label.new()
	dialogue_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_hint.add_theme_font_size_override("font_size", 14)
	dialogue_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35, 1.0))
	dialogue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_hint.visible = false
	vbox.add_child(dialogue_hint)

	$Control.add_child(dialogue_panel)


func show_dialogue(text: String, hint: String = "", persist: bool = false, seconds: float = 5.0) -> void:
	# Player-speech line. `persist` = a paused teaching beat that stays up until
	# hide_dialogue(); otherwise it auto-hides after `seconds`.
	if dialogue_panel == null:
		return
	dialogue_label.text = text
	if hint != "":
		dialogue_hint.text = hint
		dialogue_hint.visible = true
	else:
		dialogue_hint.visible = false
	dialogue_panel.visible = true
	dialogue_timer = 0.0 if persist else seconds


func hide_dialogue() -> void:
	if dialogue_panel == null:
		return
	dialogue_panel.visible = false
	dialogue_timer = 0.0


func _create_context_menu() -> void:
	context_menu = PanelContainer.new()
	context_menu.visible = false
	var vbox = VBoxContainer.new()
	context_menu.add_child(vbox)

	var use_btn = Button.new()
	use_btn.text = "Use"
	use_btn.pressed.connect(_context_use)
	vbox.add_child(use_btn)

	var discard_btn = Button.new()
	discard_btn.text = "Discard"
	discard_btn.pressed.connect(_context_discard)
	vbox.add_child(discard_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_context_cancel)
	vbox.add_child(cancel_btn)

	$Control.add_child(context_menu)

func _create_stamina_bar() -> void:
	# ONE continuous bar (hud_stamina.gd) under the portrait's name — it drains and refills smoothly off
	# the same stamina numbers as always; nothing about the drain or regen changed.
	stamina_bar = preload("res://scripts/hud_stamina.gd").new()
	stamina_bar.position = Vector2(IDENT_TEXT_X, IDENT_ROW_Y + 26.0)
	stamina_bar.size = Vector2(STAMINA_BAR_W, STAMINA_BAR_H)
	$Control.add_child(stamina_bar)


func _currency_icon(item_id: String, x: float) -> TextureRect:
	var t := TextureRect.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture = ItemData.get_texture(item_id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.position = Vector2(x, CURRENCY_Y)
	t.size = Vector2(28, 28)
	t.visible = false
	$Control.add_child(t)
	return t


func _create_wallet_label() -> void:
	# Notes: the wallet's balance, a small icon + the number, TOP-RIGHT (where the floor / time text used to be).
	wallet_icon = _currency_icon("033", CURRENCY_X)
	wallet_label = _hud_label("", 18, Color(0.56, 0.84, 0.54), Vector2(CURRENCY_X + 34.0, CURRENCY_Y + 2.0), Vector2(90, 24))
	wallet_label.visible = false
	update_wallet()


func _create_dev_warp_prompt() -> void:
	# DEV: F6 floor-warp prompt (see dev_warp_prompt.gd). Lives on the HUD
	# layer so it exists in every gameplay scene.
	var warp = preload("res://scripts/dev_warp_prompt.gd").new()
	$Control.add_child(warp)


func _create_dev_item_prompt() -> void:
	# DEV: item-spawn prompt (see dev_item_prompt.gd). Opened from the F1 dev menu.
	# Lives on the HUD layer so it exists in every gameplay scene.
	var spawn = preload("res://scripts/dev_item_prompt.gd").new()
	$Control.add_child(spawn)


func _create_dev_menu() -> void:
	# DEV: the F1 consolidated dev-tools menu (see dev_menu.gd). One panel for god
	# mode / health / run / hazard / wallet / tutorial / warp / item — no more juggling
	# eight function keys (and nothing on F8, which the editor steals as Stop).
	var menu = preload("res://scripts/dev_menu.gd").new()
	$Control.add_child(menu)


func _create_scrap_label() -> void:
	# Scrap: the same treatment, on the row under the notes (docs/SCRAP_UPGRADES.md).
	scrap_icon = _currency_icon("037", CURRENCY_X)
	scrap_label = _hud_label("", 18, Color(0.85, 0.75, 0.5), Vector2(CURRENCY_X + 34.0, CURRENCY_Y + 2.0), Vector2(90, 24))
	scrap_label.visible = false
	update_scrap()


func _create_boon_badge() -> void:
	# A milestone floor's run boon is OFFERED, never forced: this badge waits beside the portrait
	# until the player clicks it (arriving mid-fight or mid-stair-pan must not pause the game).
	boon_badge = Button.new()
	boon_badge.text = "★ BOON"
	boon_badge.position = Vector2(CLUSTER_MARGIN, IDENT_Y - 38.0)      # above the portrait
	boon_badge.size = Vector2(150, 30)
	boon_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	boon_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	boon_badge.visible = false
	boon_badge.pressed.connect(open_boon_offer)
	$Control.add_child(boon_badge)


func refresh_boon_badge() -> void:
	if boon_badge == null:
		return
	var n: int = WorldState.pending_boon_floors.size()
	boon_badge.visible = n > 0
	boon_badge.text = "★ BOON — choose" + (" (%d)" % n if n > 1 else "")


func open_boon_offer() -> void:
	if boon_ui == null or not is_instance_valid(boon_ui):
		boon_ui = preload("res://scripts/boon_offer_ui.gd").new()
		add_child(boon_ui)
	boon_ui.open()


func update_scrap() -> void:
	if scrap_label == null:
		return
	scrap_label.visible = WorldState.scrap_unlocked
	if scrap_icon != null:
		scrap_icon.visible = WorldState.scrap_unlocked
	scrap_label.text = str(WorldState.scrap)
	_layout_currency()


## Notes on the first row, scrap under it — or scrap alone on the first row while the wallet is still locked.
func _layout_currency() -> void:
	if scrap_label == null or scrap_icon == null:
		return
	var row: float = 1.0 if WorldState.wallet_unlocked else 0.0
	scrap_icon.position = Vector2(CURRENCY_X, CURRENCY_Y + CURRENCY_ROW * row)
	scrap_label.position = Vector2(CURRENCY_X + 34.0, CURRENCY_Y + CURRENCY_ROW * row + 2.0)


func update_wallet() -> void:
	if wallet_label == null:
		return
	wallet_label.visible = WorldState.wallet_unlocked
	if wallet_icon != null:
		wallet_icon.visible = WorldState.wallet_unlocked
	wallet_label.text = str(WorldState.wallet_balance)
	_layout_currency()


func update_stamina(current: float, maximum: float) -> void:
	if stamina_bar != null and stamina_bar.has_method("set_values"):
		stamina_bar.set_values(current, maximum)

# --- smoke fog (reduced visibility while standing in a blaze's smoke) --------
var smoke_fog_rect: TextureRect = null
var _fog_alpha: float = 0.0
var _fog_target: float = 0.0
const FOG_MAX_ALPHA := 0.34


func _create_smoke_fog() -> void:
	# A SUBTLE, washed-out haze — a warm-grey veil that hangs a little denser up top
	# (where smoke gathers) but touches the whole screen, so a fire floor reads as
	# gradually hazy / slightly washed-out and darker. NOT a heavy black fog, and NOT
	# something you have to crouch under — pure atmosphere. Proper smoke art later.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(0.44, 0.41, 0.37, 0.95),  # top: light warm-grey haze
		Color(0.44, 0.41, 0.37, 0.6),   # middle
		Color(0.44, 0.41, 0.37, 0.38),  # floor: still a touch of haze (washes the whole view)
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)         # vertical
	tex.width = 8
	tex.height = 64
	smoke_fog_rect = TextureRect.new()
	smoke_fog_rect.texture = tex
	smoke_fog_rect.stretch_mode = TextureRect.STRETCH_SCALE
	smoke_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	smoke_fog_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	smoke_fog_rect.modulate.a = 0.0
	$Control.add_child(smoke_fog_rect)
	$Control.move_child(smoke_fog_rect, 0)   # behind the HUD elements, over the world


# --- speech bubble (small line above the player's head) ----------------------
var speech_panel: PanelContainer = null
var speech_label: Label = null
var speech_timer: float = 0.0


func _create_speech_bubble() -> void:
	speech_panel = PanelContainer.new()
	speech_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.09, 0.9)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	speech_panel.add_theme_stylebox_override("panel", sb)
	speech_label = Label.new()
	speech_label.add_theme_font_size_override("font_size", 15)
	speech_label.add_theme_color_override("font_color", Color(1, 1, 1))
	speech_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speech_panel.add_child(speech_label)
	speech_panel.visible = false
	speech_panel.z_index = 30
	$Control.add_child(speech_panel)


func show_speech(text: String, seconds: float = 2.5) -> void:
	# A small speech bubble above the player's head (used for fire/smoke reactions).
	if speech_panel == null:
		return
	speech_label.text = text
	speech_panel.visible = true
	speech_timer = seconds
	_position_speech()


func _position_speech() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		speech_panel.visible = false
		return
	speech_panel.reset_size()
	var sz := speech_panel.size
	var head: Vector2 = get_viewport().get_canvas_transform() * (player.global_position + Vector2(0, -52))
	var px := clampf(head.x - sz.x * 0.5, 6.0, SCREEN_W - sz.x - 6.0)
	var py := clampf(head.y - sz.y, 6.0, SCREEN_H - sz.y - 6.0)
	speech_panel.position = Vector2(px, py)


func set_smoke_fog(on: bool, intensity: float = 1.0) -> void:
	# Atmosphere only: a gradual hazy wash whose strength scales with how much of the
	# floor is alight, building up from nothing (no crouch, no damage). It eases in via
	# _update_smoke_fog, so it thickens gradually rather than snapping on.
	_fog_target = clampf(intensity, 0.0, 1.0) if on else 0.0


func _update_smoke_fog(delta: float) -> void:
	if smoke_fog_rect == null:
		return
	_fog_alpha = move_toward(_fog_alpha, _fog_target, delta * 0.5)   # slow, gradual build
	smoke_fog_rect.modulate.a = _fog_alpha * FOG_MAX_ALPHA


func _process(delta: float) -> void:
	_fade_identity_over_player(delta)
	if _mode_hover and mode_tip != null and not mode_tip.visible:
		_mode_hover_t += delta
		if _mode_hover_t >= MODE_TIP_DELAY:
			show_mode_tip()
	if pack_button != null:
		var pl = get_tree().get_first_node_in_group("player")
		pack_button.is_pack_open = pl != null and is_instance_valid(pl) and str(pl.get("pack_phase")) in ["kneel", "open"]
	_update_drag()
	_update_item_tip(delta)
	_update_world_prompt()
	_update_smoke_fog(delta)
	if speech_timer > 0.0:
		speech_timer -= delta
		_position_speech()
		if speech_timer <= 0.0:
			speech_panel.visible = false
	if feedback_timer > 0:
		feedback_timer -= delta
		var alpha = min(feedback_timer / 0.5, 1.0)
		feedback_label.modulate = Color(1, 1, 0.5, alpha)
		if feedback_timer <= 0:
			feedback_label.modulate = Color(1, 1, 0.5, 0)

	# Transient dialogue auto-hide (persistent prompt lines keep timer at 0).
	if dialogue_timer > 0:
		dialogue_timer -= delta
		if dialogue_timer <= 0:
			hide_dialogue()

	# Close context menu on click outside
	if context_menu and context_menu.visible:
		if Input.is_action_just_pressed("interact") or \
		   (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and \
		   not context_menu.get_global_rect().has_point(get_viewport().get_mouse_position())):
			context_menu.visible = false

func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Arm a potential drag; the actual drag start / drop / cancel is driven
		# by mouse polling in _process, since a slot's gui_input stops firing
		# once the cursor leaves it. A plain press (no drag) still selects, and
		# a double-press still uses the item.
		if slot_index < WorldState.inventory.size():
			drag_from = slot_index
			drag_armed_pos = get_viewport().get_mouse_position()
		var now = Time.get_ticks_msec() / 1000.0
		if last_click_slot == slot_index and (now - last_click_time) < DOUBLE_CLICK_TIME:
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("use_item"):
				player.use_item(slot_index)
			last_click_slot = -1
			drag_from = -1
		else:
			select_slot(slot_index)
			last_click_time = now
			last_click_slot = slot_index
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if slot_index < WorldState.inventory.size():
			show_context_menu(slot_index)


func _update_drag() -> void:
	# Whole drag lifecycle, polled so it survives the cursor leaving the slot.
	if drag_from < 0:
		return
	var held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not drag_active:
		if not held:
			drag_from = -1  # released without moving — it was just a click
			return
		if get_viewport().get_mouse_position().distance_to(drag_armed_pos) > DRAG_THRESHOLD:
			_start_drag()
	else:
		drag_icon.position = get_viewport().get_mouse_position() - Vector2(ICON_PX, ICON_PX) * 0.5
		if not held:
			_finish_drag()


func _start_drag() -> void:
	drag_active = true
	# The item lifts out of its slot: the slot keeps a faint ghost of it, and just the item — no box
	# behind it — follows the pointer, centred on it.
	if drag_from >= 0 and drag_from < slot_icons.size():
		slot_icons[drag_from].modulate.a = 0.3
	drag_icon = TextureRect.new()
	drag_icon.texture = ItemData.get_texture(WorldState.get_item_id_at(drag_from))
	drag_icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	drag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_icon.modulate = Color(1, 1, 1, 0.9)
	drag_icon.size = Vector2(ICON_PX, ICON_PX)
	drag_icon.position = get_viewport().get_mouse_position() - drag_icon.size * 0.5
	$Control.add_child(drag_icon)


func _finish_drag() -> void:
	drag_active = false
	if drag_icon != null:
		drag_icon.queue_free()
		drag_icon = null
	var from = drag_from
	drag_from = -1
	refresh_inventory()                         # the lifted slot's icon back to full (every outcome)
	if from < 0 or from >= WorldState.inventory.size():
		return
	var mouse = get_viewport().get_mouse_position()
	# Dropped on another slot?
	for i in range(slots.size()):
		if slots[i].get_global_rect().has_point(mouse) and i != from:
			_drop_on_slot(from, i)
			return
	# Dropped on the game world (anywhere that isn't a HUD widget) = discard.
	if not pointer_over_widget(mouse):
		_discard_slot(from)


func _drop_on_slot(from: int, to: int) -> void:
	if slot_is_locked(to):
		return  # can't place into a still-locked slot
	var from_inst = WorldState.get_instance_at(from)
	var from_data = from_inst.get_data()
	# Dropping onto an empty slot reorders to the end.
	if to >= WorldState.inventory.size():
		WorldState.move_inventory_slot_to_end(from)
		refresh_inventory()
		return
	# Bullets onto a gun (either direction) load the magazine.
	if to < WorldState.inventory.size():
		var to_inst = WorldState.get_instance_at(to)
		var to_data = to_inst.get_data()
		var gun_inst: ItemInstance = null
		if from_data.get("is_ammo", false) and to_data.get("name", "").to_lower().contains("gun"):
			gun_inst = to_inst
		elif to_data.get("is_ammo", false) and from_data.get("name", "").to_lower().contains("gun"):
			gun_inst = from_inst
		if gun_inst != null:
			var loaded = WorldState.reload_gun(gun_inst)
			if loaded > 0:
				show_feedback("Loaded %d — mag %d/%d." % [loaded, gun_inst.mag_count, gun_inst.get_mag_cap()])
			else:
				show_feedback("Magazine full." if gun_inst.mag_count >= gun_inst.get_mag_cap() else "No bullets to load.")
			return
	WorldState.swap_inventory_slots(from, to)
	refresh_inventory()


func _discard_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= WorldState.inventory.size():
		return
	var instance = WorldState.get_instance_at(slot_index)
	var item_data = instance.get_data()
	_drop_to_world(instance)
	if selected_slot > slot_index:
		selected_slot -= 1
	elif selected_slot == slot_index:
		selected_slot = -1
	WorldState.remove_from_inventory(slot_index)
	_update_slot_highlights()
	refresh_inventory()
	show_feedback(item_data.get("name", "Item") + " dropped.")

# Put a discarded item on the floor WITH ITS MEMORY (docs/SCRAP_UPGRADES.md "discard memory"):
# a weapon keeps its durability / magazine / damage / workbench level + perks, a stack keeps its
# count, and a BROKEN weapon or tool still drops (it's repairable, and upgrade feed) — an accidental
# drop is always recoverable exactly as it was. Only a used-up consumable just goes.
func _drop_to_world(instance) -> void:
	if instance.is_depleted and not instance.is_repairable():
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var d: Dictionary = instance.get_data()
	var extra = {}
	if instance.target_apartment != "":
		extra["target_apartment"] = instance.target_apartment
	if d.get("is_money", false) or d.get("is_ammo", false) or d.get("is_fuse", false) \
			or (d.get("is_throwable", false) and instance.count > 1):
		extra["amount"] = instance.count          # a stack comes back as the same count
	else:
		extra["instance"] = WorldState.instance_to_dict(instance)
	WorldState.drop_item_from(player, instance.item_id, extra)


# --- ITEM TOOLTIP: hover a slot for the details (owner: "recognise the item instantly, then hover
# over it if they want more information"). The icon says WHAT it is; this says how it's doing. ---------
const ICON_PX := 56.0                  # icons are drawn 56x56 (tools/art/item_icons.py) — shown 1:1
const TIP_DELAY := 0.18
const TIP_W := 250.0
var item_tip: PanelContainer = null
var _tip_title: Label = null
var _tip_stats: Label = null
var _tip_desc: Label = null
var _tip_hint: Label = null
var _tip_slot: int = -1
var _tip_t: float = 0.0
var tip_mouse_override = null          # tests only: a Vector2 stands in for the pointer (headless has none)


# --- the MODE row (name + mode) and its tooltip ---------------------------------------------------

const MODE_TIP_DELAY := 0.15
const MODE_TIP_W := 290.0
const MODE_COL_SCAV := Color(0.55, 0.9, 0.5)
const MODE_COL_COMBAT := Color(0.95, 0.4, 0.34)


## Lay out the identity row: the mode sits right after the name, and the stamina bar underlines BOTH
## (it is the row's underline as well as the gauge). Re-run whenever the name or the mode text changes.
func _layout_identity_row() -> void:
	if name_label == null or mode_label == null or stamina_bar == null:
		return
	var f: Font = name_label.get_theme_default_font()
	var nw: float = f.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	name_label.size.x = nw + 4.0
	mode_label.reset_size()
	var mw: float = f.get_string_size(mode_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	mode_label.position = Vector2(IDENT_TEXT_X + nw + 12.0, IDENT_ROW_Y)
	mode_label.size = Vector2(mw + 4.0, 24.0)
	var w: float = maxf(nw + 12.0 + mw, 150.0)
	stamina_bar.size = Vector2(w, STAMINA_BAR_H)
	if equip_box != null:
		# the in-hand box sits to the RIGHT of the whole name / mode / stamina block, level with it
		equip_box.position = Vector2(IDENT_TEXT_X + w + 18.0, SCREEN_H - equip_box.size.y - 12.0)


func _create_mode_tip() -> void:
	mode_tip = PanelContainer.new()
	mode_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_tip.visible = false
	mode_tip.z_index = 50
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.07, 0.09, 0.95)
	st.border_color = Color(0.62, 0.58, 0.46, 0.95)
	st.set_border_width_all(1)
	st.set_corner_radius_all(3)
	st.set_content_margin_all(9)
	mode_tip.add_theme_stylebox_override("panel", st)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	mode_tip.add_child(box)
	for col in [MODE_COL_SCAV, MODE_COL_COMBAT]:
		var head := _mode_tip_label(box, 14, col)
		var body := _mode_tip_label(box, 12, Color(0.78, 0.82, 0.86))
		_mode_tip_blocks.append({"head": head, "body": body})
	_mode_tip_hint = _mode_tip_label(box, 11, Color(0.95, 0.82, 0.42))
	$Control.add_child(mode_tip)


func _mode_tip_label(box: Node, size: int, col: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(MODE_TIP_W, 0)
	box.add_child(l)
	return l


## What the two modes are, for the tooltip. Public + a plain function of the current mode so a test can read it.
## Every claim here is a rule in player.gd / interactable.gd (slow + quiet scavenging, no sprint / shove / swing,
## searching only in scavenge; full pace + sprint + shove + swing in combat).
func mode_tip_content() -> Dictionary:
	var key: String = action_key_name("mode_toggle", "F")
	var scav: bool = WorldState.is_scavenge_mode
	return {
		"scavenge": {"head": "SCAVENGE" + ("   ◂ you are here" if scav else ""),
			"body": "Searching mode. Loot nodes can only be searched here. You move slowly and quietly (about half speed, a small noise ring) and can't sprint, shove or swing a weapon — pressing attack with one drawn switches you to combat."},
		"combat": {"head": "COMBAT" + ("" if scav else "   ◂ you are here"),
			"body": "Fighting mode. Swing, shoot and shove, walk at full pace and sprint (sprinting is loud). Nothing can be searched from here — switch to scavenge first."},
		"hint": "Click here or press [%s] to switch. It takes a moment — you can't move while you do." % key,
		"current": "scavenge" if scav else "combat",
	}


## Fill and place the mode tooltip above the mode text (public so a test / the capture tool can drive it).
func show_mode_tip() -> void:
	if mode_tip == null or mode_label == null:
		return
	var c: Dictionary = mode_tip_content()
	for i in range(2):
		var k: String = "scavenge" if i == 0 else "combat"
		var blk: Dictionary = c[k]
		_mode_tip_blocks[i]["head"].text = blk["head"]
		_mode_tip_blocks[i]["body"].text = blk["body"]
		# the mode you're in reads brighter; the other is dimmed
		var on: bool = c["current"] == k
		_mode_tip_blocks[i]["body"].add_theme_color_override("font_color", Color(0.86, 0.9, 0.94) if on else Color(0.6, 0.62, 0.66))
	_mode_tip_hint.text = c["hint"]
	mode_tip.reset_size()
	var sz: Vector2 = mode_tip.get_combined_minimum_size()
	var r: Rect2 = mode_label.get_global_rect()
	mode_tip.position = Vector2(clampf(IDENT_TEXT_X - 8.0, 8.0, SCREEN_W - sz.x - 8.0), maxf(8.0, r.position.y - sz.y - 10.0))
	mode_tip.visible = true


func _create_item_tip() -> void:
	item_tip = PanelContainer.new()
	item_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_tip.visible = false
	item_tip.z_index = 50
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.07, 0.09, 0.94)
	st.border_color = Color(0.62, 0.58, 0.46, 0.95)
	st.set_border_width_all(1)
	st.set_corner_radius_all(3)
	st.set_content_margin_all(8)
	item_tip.add_theme_stylebox_override("panel", st)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	item_tip.add_child(box)
	_tip_title = _tip_label(box, 15, Color(0.97, 0.94, 0.84))
	_tip_stats = _tip_label(box, 12, Color(0.78, 0.82, 0.86))
	_tip_desc = _tip_label(box, 12, Color(0.66, 0.64, 0.6))
	_tip_hint = _tip_label(box, 11, Color(0.95, 0.82, 0.42))
	$Control.add_child(item_tip)


func _tip_label(box: Node, size: int, col: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(TIP_W, 0)
	box.add_child(l)
	return l


## What the tooltip says about an item: {title, stats (lines), desc, hint, broken}.
func item_tip_content(inst) -> Dictionary:
	var d: Dictionary = inst.get_data()
	var stats: Array = []
	var broken := false
	var tier: String = inst.tier_label()
	if tier != "":
		stats.append(tier)
	var max_d: int = inst.get_max_durability()
	if inst.is_depleted and max_d > 0:
		broken = true
		stats.append("BROKEN — repair it with a toolbox")
	elif d.get("is_weapon", false) and _is_gun_data(d):
		stats.append("Magazine %d / %d" % [inst.mag_count, inst.get_mag_cap()])
		if inst.is_damaged:
			broken = true
			stats.append("Damaged — shoots wide until repaired")
	elif max_d > 1:
		stats.append(("Durability %d / %d" if d.get("is_weapon", false) else "Uses left %d / %d") % [inst.current_durability, max_d])
	if d.get("is_money", false):
		stats.append("%d in notes" % inst.count)
	elif d.get("is_ammo", false):
		stats.append("%d rounds" % inst.count)
	elif inst.count > 1:
		stats.append("x%d" % inst.count)
	if d.get("is_health_item", false):
		stats.append("Heals %d" % (int(d.get("heals_states", 0)) + WorldState.get_heal_bonus()))
	var hint := ""
	if d.get("is_molotov", false):
		hint = "Double-click to throw — it bursts into flame where it lands"
	elif d.get("is_bottle", false):
		hint = "Double-click to throw — it smashes where it lands"
	elif d.get("is_junk", false):
		hint = "Junk — break it down at a workbench, or drag it out to drop it"
	elif d.get("is_weapon", false):
		hint = "Click to equip · double-click to use"
	elif d.get("is_health_item", false) or d.get("is_speed_boost", false) or d.get("is_extinguisher", false) \
			or d.get("is_throwable", false) or d.get("can_repair", false):
		hint = "Double-click to use"
	return {"title": inst.get_display_name(), "stats": stats, "desc": str(d.get("description", "")),
		"hint": hint, "broken": broken, "legendary": inst.level >= WeaponUpgrades.LEGENDARY_LEVEL}


func _is_gun_data(d: Dictionary) -> bool:
	return str(d.get("name", "")).to_lower() == "gun"


func _hovered_slot() -> int:
	if not hotbar_visible:
		return -1
	var mouse: Vector2 = tip_mouse_override if tip_mouse_override is Vector2 else get_viewport().get_mouse_position()
	for i in range(slots.size()):
		if i < WorldState.inventory.size() and slots[i].get_global_rect().has_point(mouse):
			return i
	return -1


func _update_item_tip(delta: float) -> void:
	if item_tip == null:
		return
	var i := -1 if (drag_active or (context_menu != null and context_menu.visible)) else _hovered_slot()
	if i != _tip_slot:
		_tip_slot = i
		_tip_t = 0.0
		item_tip.visible = false
	if i < 0:
		return
	_tip_t += delta
	if _tip_t < TIP_DELAY:
		return
	show_item_tip(i)


## Fill + place the tooltip for slot i (public so tests and the drag code can drive it).
func show_item_tip(i: int) -> void:
	var inst = WorldState.get_instance_at(i) if i >= 0 and i < WorldState.inventory.size() else null
	if inst == null:
		item_tip.visible = false
		return
	var c: Dictionary = item_tip_content(inst)
	_tip_title.text = c["title"]
	_tip_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3) if c["legendary"] else Color(0.97, 0.94, 0.84))
	_tip_stats.text = "\n".join(c["stats"])
	_tip_stats.visible = not c["stats"].is_empty()
	_tip_stats.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if c["broken"] else Color(0.78, 0.82, 0.86))
	_tip_desc.text = c["desc"]
	_tip_desc.visible = c["desc"] != ""
	_tip_hint.text = c["hint"]
	_tip_hint.visible = c["hint"] != ""
	item_tip.reset_size()
	var sz: Vector2 = item_tip.get_combined_minimum_size()
	var r: Rect2 = slots[i].get_global_rect()
	item_tip.position = Vector2(clampf(r.position.x + r.size.x * 0.5 - sz.x * 0.5, 8.0, SCREEN_W - sz.x - 8.0),
		r.end.y + 8.0)                                  # the hotbar is at the top now: the tip hangs below it
	item_tip.visible = true


func select_slot(index: int) -> void:
	var was: int = selected_slot
	if selected_slot == index:
		selected_slot = -1
	else:
		selected_slot = index
	_update_slot_highlights()
	context_menu.visible = false
	_announce_weapon_selection(was)


func _announce_weapon_selection(was: int) -> void:
	# Re-selecting the equipped slot TOGGLES it off. That used to be silent, so a stray click or
	# key-press left the player swinging nothing without knowing why. Say it every time.
	var now_inst = WorldState.get_instance_at(selected_slot) if selected_slot >= 0 and selected_slot < WorldState.inventory.size() else null
	if now_inst != null and now_inst.get_data().get("is_weapon", false):
		var n: String = now_inst.get_data().get("name", "weapon")
		show_feedback(("Equipped %s — it's broken." if now_inst.is_depleted else "Equipped %s.") % n)
		return
	if selected_slot == -1 and was >= 0 and was < WorldState.inventory.size():
		var old = WorldState.get_instance_at(was)
		if old != null and old.get_data().get("is_weapon", false):
			show_feedback("Put away %s." % old.get_data().get("name", "weapon"))

func _update_slot_highlights() -> void:
	for i in range(slots.size()):
		if i == selected_slot:
			slots[i].add_theme_stylebox_override("panel", _make_slot_style_selected())
		else:
			slots[i].add_theme_stylebox_override("panel", _make_slot_style(false))
	_update_equipped_chip()


## The in-hand BOX: the selected item's icon inside an outline that is its durability (draining as it wears,
## empty = broken). Numbers appear ONLY as a gun's rounds (owner round 27) — no "10/10 uses" text any more.
func _update_equipped_chip() -> void:
	if equip_box == null:
		return
	var inst = WorldState.get_instance_at(selected_slot) if selected_slot >= 0 and selected_slot < WorldState.inventory.size() else null
	if inst == null:
		equip_box.clear_item()
		return
	var d: Dictionary = inst.get_data()
	var max_d: int = inst.get_max_durability()
	var wears: bool = max_d > 1 and not d.get("single_use", false)
	var broken: bool = inst.is_depleted and max_d > 0
	var frac: float = -1.0
	if broken:
		frac = 0.0
	elif wears:
		frac = clampf(float(inst.current_durability) / float(max_d), 0.0, 1.0)
	var ammo := ""
	if d.get("is_weapon", false) and _is_gun_data(d) and not broken:
		ammo = "%d/%d" % [inst.mag_count, inst.get_mag_cap()]
	equip_box.set_item(ItemData.get_texture(inst.item_id), frac, broken, ammo)


## The in-hand box's shape: "square", "rounded" (default) or "circle".
func set_equip_box_style(style: String) -> void:
	if equip_box != null:
		equip_box.set_style(style)


func wheel_key_name() -> String:
	# The quick wheel's CURRENT binding, read straight from the InputMap (the hint must never name a
	# key the player has rebound away — same rule as the tutorial lines).
	return action_key_name("item_wheel", "Tab")


## The identity block (portrait, name, condition, stamina) sits over the bottom-left of the WORLD now, and the
## left staircase is right there: while the player (or anyone) stands under it, it fades back so nobody is
## hidden behind a HUD panel. Cosmetic; never touches input.
const IDENT_FADE_ALPHA := 0.3
func _fade_identity_over_player(delta: float) -> void:
	if portrait == null:
		return
	var block_w: float = IDENT_TEXT_X + 250.0
	if equip_box != null:
		block_w = maxf(block_w, equip_box.position.x + equip_box.size.x + 8.0)
	var block := Rect2(Vector2(0.0, IDENT_Y - 8.0), Vector2(block_w, SCREEN_H - IDENT_Y + 8.0))
	var under := false
	var pl = get_tree().get_first_node_in_group("player")
	if pl != null and is_instance_valid(pl) and pl is Node2D:
		var sp: Vector2 = get_viewport().get_canvas_transform() * (pl as Node2D).global_position
		under = block.grow(20.0).has_point(sp)
	var a: float = IDENT_FADE_ALPHA if under else 1.0
	for n in [portrait, name_label, stamina_bar, mode_label, equip_box]:
		if n != null and is_instance_valid(n):
			n.modulate.a = lerpf(n.modulate.a, a, clampf(delta * 8.0, 0.0, 1.0))


## The six-slot hotbar is OPT-IN and hidden by default (owner: "redundant if we have the wheel"). Everything
## that exists to serve it (drag / drop, tooltips, click to equip) only runs while it's shown. (A pack-less
## character does NOT get a pocket bar either — owner round 27: the two empty boxes at the top were noise; the
## in-hand box shows what they hold, number keys 1-2 switch.)
var hotbar_visible: bool = false
var _hotbar_w: float = HOTBAR_W


func set_hotbar_visible(on: bool) -> void:
	hotbar_visible = on
	_apply_hotbar()


func _apply_hotbar() -> void:
	hbox.visible = hotbar_visible
	for s in slots:
		s.visible = true
	_hotbar_w = HOTBAR_W
	hbox.position = Vector2((SCREEN_W - _hotbar_w) / 2.0, HOTBAR_Y)
	if not hotbar_visible:
		item_tip.visible = false
		context_menu.visible = false


## Follow WorldState.has_backpack: the pack button + wheel hint exist only once the character has a
## backpack.
func update_backpack_state() -> void:
	var has: bool = WorldState.has_backpack
	if pack_button != null and is_instance_valid(pack_button):
		pack_button.visible = has
	if wheel_hint != null:
		wheel_hint.visible = has
	_apply_hotbar()


## The hotbar's screen rectangle (the slots showing), padded a little — empty while it is hidden.
func hotbar_rect() -> Rect2:
	if not hotbar_visible:
		return Rect2()
	return Rect2(hbox.position - Vector2(6, 6), Vector2(_hotbar_w + 12.0, SLOT_SIZE + 12.0))


## Where a dragged loot item is dropped to take it: the backpack button (or the hotbar, when shown).
func inventory_drop_rect() -> Rect2:
	if hotbar_visible:
		return hotbar_rect()
	if pack_button != null and is_instance_valid(pack_button):
		return pack_button.get_global_rect().grow(14.0)
	return Rect2()


## Is a screen point over something the player would click ON (a slot, the pack, the mode toggle, the
## portrait, the boon badge, an open context menu)? Clicks anywhere else belong to the world. This replaces
## the old "below y 528 is the bar" band test now that there is no bar.
func pointer_over_widget(pos: Vector2) -> bool:
	if hotbar_rect().has_point(pos):
		return true
	for w in [pack_button, mode_label, portrait, boon_badge, context_menu]:
		if w != null and is_instance_valid(w) and w.visible and w.get_global_rect().has_point(pos):
			return true
	# Clickable things that live elsewhere (a resident's speech bubble with its trade buttons).
	for w in get_tree().get_nodes_in_group("hud_widget_extra"):
		if w is Control and w.is_visible_in_tree() and w.get_global_rect().has_point(pos):
			return true
	return false


## The CURRENT binding of an action as short text, straight from the InputMap (a hint must never
## name a key the player has rebound away). `fallback` is shown if the action has no event.
func action_key_name(action: String, fallback: String) -> String:
	if not InputMap.has_action(action):
		return fallback
	var evs: Array = InputMap.action_get_events(action)
	if evs.is_empty():
		return "?"
	return String(evs[0].as_text()).replace(" (Physical)", "").replace(" - Physical", "")


func update_wheel_hint() -> void:
	if wheel_hint != null:
		wheel_hint.text = "Hold [%s]  quick wheel" % wheel_key_name()

func _make_slot_style_selected() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.16, 0.1, 1.0)
	style.set_border_width_all(2)
	style.border_color = AMBER
	return style

func show_context_menu(slot_index: int) -> void:
	context_slot = slot_index
	var slot_pos = slots[slot_index].global_position
	context_menu.position = Vector2(slot_pos.x, slot_pos.y + SLOT_SIZE + 6.0)
	context_menu.visible = true

func _context_use() -> void:
	context_menu.visible = false
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("use_item"):
		player.use_item(context_slot)

func _context_discard() -> void:
	context_menu.visible = false
	if context_slot >= 0 and context_slot < WorldState.inventory.size():
		var instance = WorldState.get_instance_at(context_slot)
		_drop_to_world(instance)
		if selected_slot > context_slot:
			selected_slot -= 1
		elif selected_slot == context_slot:
			selected_slot = -1
		WorldState.remove_from_inventory(context_slot)
		_update_slot_highlights()
		refresh_inventory()
		show_feedback("Item dropped.")

## Drop the item in inventory slot `slot` at the player's feet (the pack ring's Delete; the hotbar's
## context-menu Discard — one path, so nothing is ever deleted, only put on the floor).
func discard_slot(slot: int) -> void:
	context_slot = slot
	_context_discard()


func _context_cancel() -> void:
	context_menu.visible = false

func show_feedback(text: String) -> void:
	feedback_label.text = text
	feedback_timer = 2.0
	feedback_label.modulate = Color(1, 1, 0.5, 1)

func _make_slot_style(locked: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.153, 0.141, 0.165, 1.0) if not locked else Color(0.1, 0.095, 0.11, 1.0)
	style.set_border_width_all(2)
	style.border_color = Color(0.294, 0.275, 0.318, 1.0) if not locked else Color(0.2, 0.19, 0.22, 1.0)
	return style

func update_floor_label() -> void:
	floor_label.text = str(WorldState.current_floor)          # hidden (see _layout) — kept for the many callers

func _ensure_portraits() -> void:
	# Load the current run's character's 6 portrait stages, reloading when the run's
	# character changes (advance_run / new_game re-roll the cast via master_seed).
	var cid: String = WorldState.current_character()
	if cid == _loaded_char and not _portraits.is_empty():
		return
	_portraits.clear()
	for stage in PORTRAIT_STAGES:
		_portraits.append(load("res://assets/Health_Bar/%s - %s.png" % [cid, stage]))
	_loaded_char = cid


func update_portrait(health_index: int) -> void:
	if portrait == null:
		return
	_ensure_portraits()
	portrait.texture = _portraits[clampi(health_index, 0, _portraits.size() - 1)]
	_health_stage = clampi(health_index, 0, HEALTH_HINTS.size() - 1)
	if name_label != null:
		name_label.text = WorldState.character_display_name(_loaded_char).to_upper()
		_layout_identity_row()


# --- Portrait-as-button (hover glow + bounce, click opens the character profile) ----------

# Outline shader: paints a soft white rim on the transparent pixels adjacent to the
# character silhouette when `on` is 1, with a gentle shimmer so it reads "shiny/clickable".
const _PORTRAIT_OUTLINE_SHADER := """
shader_type canvas_item;
uniform float on = 0.0;
uniform float width = 1.6;
uniform vec4 rim : source_color = vec4(1.0, 1.0, 1.0, 1.0);
void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec4 outc = col;
	if (on > 0.5 && col.a < 0.35) {
		vec2 px = TEXTURE_PIXEL_SIZE * width;
		float a = 0.0;
		a = max(a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(px.x, px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);
		if (a > 0.35) {
			float shimmer = 0.72 + 0.28 * sin(TIME * 4.0 + UV.y * 12.0);
			outc = vec4(rim.rgb, rim.a * shimmer);
		}
	}
	COLOR = outc;
}
"""


func _setup_portrait_button() -> void:
	if portrait == null:
		return
	# Capture hover/click ON the portrait only (the root Control stays IGNORE, so world
	# clicks elsewhere — click-to-move — are untouched; this just makes the corner bust live).
	portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	portrait.tooltip_text = "Character profile"
	var sh := Shader.new()
	sh.code = _PORTRAIT_OUTLINE_SHADER
	_portrait_outline_mat = ShaderMaterial.new()
	_portrait_outline_mat.shader = sh
	_portrait_outline_mat.set_shader_parameter("on", 0.0)
	portrait.material = _portrait_outline_mat
	portrait.mouse_entered.connect(func(): _set_portrait_hover(true))
	portrait.mouse_exited.connect(func(): _set_portrait_hover(false))
	portrait.gui_input.connect(_on_portrait_gui_input)


func _stage_colour(stage: int) -> Color:
	return [Color(0.62, 0.86, 0.55), Color(0.85, 0.85, 0.5), Color(0.93, 0.72, 0.4),
		Color(0.94, 0.55, 0.32), Color(0.92, 0.36, 0.3), Color(0.9, 0.25, 0.25)][clampi(stage, 0, 5)]


func _set_portrait_hover(hovered: bool) -> void:
	if portrait == null:
		return
	if _portrait_outline_mat != null:
		_portrait_outline_mat.set_shader_parameter("on", 1.0 if hovered else 0.0)
	# Scale from the centre so the bounce doesn't drift the anchored bust.
	portrait.pivot_offset = portrait.size * 0.5
	if _portrait_bounce != null and _portrait_bounce.is_valid():
		_portrait_bounce.kill()
		_portrait_bounce = null
	if hovered:
		# A quick pop, then a gentle continuous pulse — "clickable button" feel.
		_portrait_bounce = create_tween().set_loops()
		_portrait_bounce.tween_property(portrait, "scale", Vector2(1.05, 1.05), 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_portrait_bounce.tween_property(portrait, "scale", Vector2(1.0, 1.0), 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		portrait.scale = Vector2.ONE


func _on_portrait_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		open_character_panel()
		portrait.accept_event()   # Control method — the handler runs on the HUD (a CanvasLayer)


func _create_character_panel() -> void:
	character_panel = preload("res://scripts/character_panel.gd").new()
	add_child(character_panel)


func open_character_panel() -> void:
	if character_panel != null:
		character_panel.open()

func update_mode_indicator() -> void:
	if mode_label == null:
		return
	if WorldState.is_scavenge_mode:
		mode_label.text = "SCAVENGE"
		mode_label.modulate = Color(0.55, 0.9, 0.5, 1.0)
	else:
		mode_label.text = "COMBAT"
		mode_label.modulate = Color(0.95, 0.4, 0.34, 1.0)
	_layout_identity_row()
	if mode_tip != null and mode_tip.visible:
		show_mode_tip()

func refresh_inventory() -> void:
	# The two counters ride along: a New Game / load / time skip changes them without a wallet
	# or scrap event, and they used to show the previous game's values until the next pickup.
	update_wallet()
	update_scrap()
	refresh_boon_badge()
	update_backpack_state()
	WorldState.sync_overload()
	for i in range(slots.size()):
		var dur = slot_durability_bars[i]
		if i < WorldState.inventory.size():
			var instance = WorldState.inventory[i]
			var item_id = instance.item_id
			var texture = ItemData.get_texture(item_id)
			slot_icons[i].modulate = Color(1, 1, 1, 1.0)  # reset (broken items tint below)
			if texture != null:
				slot_icons[i].texture = texture
				slot_icons[i].visible = true
			else:
				slot_icons[i].visible = false

			var item_data = ItemData.get_item(item_id)

			var key_label = slot_key_labels[i]
			var item_name_l = item_data.get("name", "").to_lower()
			if item_data.get("is_key", false) and instance.target_apartment != "":
				key_label.text = WorldState.key_tag(instance.target_apartment)
				key_label.visible = true
			elif item_data.get("is_money", false) or item_data.get("is_ammo", false) \
					or (item_data.get("is_throwable", false) and instance.count > 1) \
					or (item_data.get("is_fuse", false) and instance.count > 1):
				key_label.text = "x" + str(instance.count)
				key_label.visible = true
			elif instance.is_depleted and int(item_data.get("max_durability", -1)) > 0:
				# Broken durability item — repairable with a toolbox.
				key_label.text = "BROKEN"
				key_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.25, 1.0))
				key_label.visible = true
				slot_icons[i].modulate = Color(0.5, 0.4, 0.4, 1.0)
			elif item_data.get("is_weapon", false) and item_name_l.contains("gun"):
				key_label.text = ("%d/%d" % [instance.mag_count, instance.get_mag_cap()]) + (" DMG" if instance.is_damaged else "")
				key_label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05, 1.0))
				key_label.visible = true
			elif texture == null:
				# No art yet (e.g. a new item's .png not added): show the name so
				# the item is visible in the slot instead of a blank square.
				key_label.text = item_data.get("name", "?").left(9)
				key_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1.0))
				key_label.visible = true
			else:
				key_label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05, 1.0))
				key_label.visible = false

			if i < slot_level_labels.size():
				slot_level_labels[i].text = instance.tier_tag()
				slot_level_labels[i].visible = instance.level > 1
			var max_dur = instance.get_max_durability()   # perks can raise it (Reinforced Handle)
			if max_dur > 0 and not item_data.get("single_use", false):
				var ratio = float(instance.current_durability) / float(max_dur)
				dur["bg"].visible = true
				dur["fill"].visible = true
				dur["fill"].size.x = (SLOT_SIZE - 4) * ratio
				if ratio > 0.5:
					dur["fill"].color = Color(0.2, 0.8, 0.2, 1.0)
				elif ratio > 0.25:
					dur["fill"].color = Color(0.9, 0.7, 0.1, 1.0)
				else:
					dur["fill"].color = Color(0.9, 0.2, 0.2, 1.0)
			else:
				dur["bg"].visible = false
				dur["fill"].visible = false
		else:
			slot_icons[i].visible = false
			dur["bg"].visible = false
			dur["fill"].visible = false
			slot_key_labels[i].visible = false
			if i < slot_level_labels.size():
				slot_level_labels[i].visible = false
	_update_slot_highlights()
	_update_slot_locks()


func _update_slot_locks() -> void:
	# Slots beyond current inventory capacity show a greyed lock; the inventory
	# upgrade lifts it (the last slot is the classic "6th slot" unlock).
	var unlocked = WorldState.get_inventory_slots()
	for i in range(slots.size()):
		slots[i].modulate = Color(1, 1, 1, 1.0) if i < unlocked else Color(0.3, 0.3, 0.3, 1.0)


func slot_is_locked(index: int) -> bool:
	return index >= WorldState.get_inventory_slots()


func show_hud() -> void:
	visible = true

func hide_hud() -> void:
	visible = false
