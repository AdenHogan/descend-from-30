extends CanvasLayer

const PORTRAITS = [
	preload("res://assets/Health_Bar/1 - Healthy.png"),
	preload("res://assets/Health_Bar/2 - Hurt.png"),
	preload("res://assets/Health_Bar/3 - Injured.png"),
	preload("res://assets/Health_Bar/4 - Wounded.png"),
	preload("res://assets/Health_Bar/5 - Severely Wounded.png"),
	preload("res://assets/Health_Bar/6 - Dying.png")
]

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

var mode_label: Button = null   # clickable scavenge/combat toggle
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
var stamina_segments: Array = []
var wallet_label: Label = null
var listen_overlay: CanvasLayer = null
const STAMINA_SEGMENTS = 8
const STAMINA_BAR_W = 14.0
const STAMINA_BAR_H = 60.0

const SCREEN_W = 1152.0
const SCREEN_H = 648.0
const BAR_H = 80.0
const SLOT_SIZE = 64.0

func _ready() -> void:
	_layout()
	_create_mode_label()
	_create_slot_icons()
	_create_feedback_label()
	_create_dialogue_panel()
	_create_context_menu()
	_create_stamina_bar()
	_create_wallet_label()
	_create_dev_warp_prompt()
	_create_dev_item_prompt()
	# Listen-mode grey/ping/report overlay (own CanvasLayer above the HUD).
	listen_overlay = preload("res://scripts/listen_overlay.gd").new()
	add_child(listen_overlay)
	_create_smoke_fog()
	_create_speech_bubble()
	update_floor_label()
	update_portrait(0)
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
	color_rect.set_anchor_and_offset(SIDE_TOP, 0, SCREEN_H - BAR_H - 40)
	color_rect.set_anchor_and_offset(SIDE_BOTTOM, 0, SCREEN_H)
	color_rect.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	color_rect.set_anchor_and_offset(SIDE_RIGHT, 0, SCREEN_W)
	# FULLY opaque: at alpha 0.9 the world showed through the bar. It went
	# unnoticed while the view was static, but during a stair pan the floor
	# scrolls behind the inventory and the see-through is obvious.
	color_rect.color = Color(0.1, 0.1, 0.1, 1.0)

	floor_label.position = Vector2(SCREEN_W - 200, SCREEN_H - BAR_H + 18)
	floor_label.size = Vector2(100, 50)

	hbox.position = Vector2(SCREEN_W - (SLOT_SIZE + 8) * 6, SCREEN_H - BAR_H + 8)
	hbox.add_theme_constant_override("separation", 8)
	# The former "locked 6th slot" is now the inventory-upgrade unlock target,
	# so it joins the real slot list; _update_slot_locks() greys it until an
	# upgrade grants it.
	slots.append(slot_locked)
	for slot in slots:
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.add_theme_stylebox_override("panel", _make_slot_style(false))

func _create_mode_label() -> void:
	# Clickable so mouse players can flip scavenge↔combat without pressing F.
	mode_label = Button.new()
	mode_label.flat = true
	mode_label.focus_mode = Control.FOCUS_NONE
	mode_label.add_theme_font_size_override("font_size", 18)
	mode_label.position = Vector2(SCREEN_W - 258, SCREEN_H - BAR_H - 12)
	mode_label.size = Vector2(180, 44)
	mode_label.custom_minimum_size = Vector2(180, 44)
	mode_label.pressed.connect(_on_mode_button)
	$Control.add_child(mode_label)


func _on_mode_button() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("request_mode_toggle"):
		player.request_mode_toggle()

func _create_slot_icons() -> void:
	for i in range(slots.size()):
		var slot = slots[i]
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(SLOT_SIZE - 8, SLOT_SIZE - 8)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.anchors_preset = Control.PRESET_CENTER
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

		slot_durability_bars.append({"bg": dur_bg, "fill": dur_fill})

		slot.gui_input.connect(_on_slot_gui_input.bind(i))

func _create_feedback_label() -> void:
	feedback_label = Label.new()
	feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # never eat world clicks
	feedback_label.add_theme_font_size_override("font_size", 14)
	feedback_label.position = Vector2(SCREEN_W / 2 - 100, SCREEN_H - BAR_H - 35)
	feedback_label.size = Vector2(200, 30)
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


func show_world_prompt(owner: Node, text: String, world_pos: Vector2) -> void:
	if owner == null:
		return
	var id := owner.get_instance_id()
	if not _world_prompts.has(id):
		_world_prompts[id] = _make_world_prompt()
	var e = _world_prompts[id]
	e["label"].text = text
	e["pos"] = world_pos
	e["panel"].visible = true


func hide_world_prompt(owner: Node) -> void:
	# Only this owner's own pill is hidden, so one drop/door leaving range can't
	# wipe another's prompt.
	if owner == null:
		return
	var e = _world_prompts.get(owner.get_instance_id())
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
		var y: float = clampf(screen.y - ph - WORLD_PROMPT_GAP, 6.0, SCREEN_H - BAR_H - ph)
		panel.position = Vector2(x, y)


func world_prompt_panel(owner: Node) -> Panel:
	# Test/inspection accessor: the on-screen pill Panel for an owner, or null.
	if owner == null:
		return null
	var e = _world_prompts.get(owner.get_instance_id())
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
	stamina_bar = Control.new()
	stamina_bar.position = Vector2(8, SCREEN_H - BAR_H + 10)
	stamina_bar.size = Vector2(STAMINA_BAR_W, STAMINA_BAR_H)
	$Control.add_child(stamina_bar)

	var segment_h = (STAMINA_BAR_H - (STAMINA_SEGMENTS - 1) * 2) / STAMINA_SEGMENTS
	for i in range(STAMINA_SEGMENTS):
		var seg = ColorRect.new()
		seg.size = Vector2(STAMINA_BAR_W, segment_h)
		seg.position = Vector2(0, STAMINA_BAR_H - (i + 1) * (segment_h + 2))
		seg.color = Color(0.2, 0.8, 0.4, 1.0)
		stamina_bar.add_child(seg)
		stamina_segments.append(seg)

func _create_wallet_label() -> void:
	wallet_label = Label.new()
	wallet_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet_label.add_theme_font_size_override("font_size", 12)
	wallet_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55, 1.0))
	wallet_label.position = Vector2(SCREEN_W - (SLOT_SIZE + 8) * 6 - 8, SCREEN_H - BAR_H - 16)
	wallet_label.size = Vector2((SLOT_SIZE + 8) * 6, 16)
	wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet_label.visible = false
	$Control.add_child(wallet_label)
	update_wallet()


func _create_dev_warp_prompt() -> void:
	# DEV: F6 floor-warp prompt (see dev_warp_prompt.gd). Lives on the HUD
	# layer so it exists in every gameplay scene.
	var warp = preload("res://scripts/dev_warp_prompt.gd").new()
	$Control.add_child(warp)


func _create_dev_item_prompt() -> void:
	# DEV: F1 item-spawn prompt (see dev_item_prompt.gd). Lives on the HUD
	# layer so it exists in every gameplay scene.
	var spawn = preload("res://scripts/dev_item_prompt.gd").new()
	$Control.add_child(spawn)


func update_wallet() -> void:
	if wallet_label == null:
		return
	wallet_label.visible = WorldState.wallet_unlocked
	wallet_label.text = "WALLET  " + str(WorldState.wallet_balance)


func update_stamina(current: float, maximum: float) -> void:
	if stamina_segments.is_empty():
		return
	var ratio = current / maximum
	var filled = int(round(ratio * STAMINA_SEGMENTS))
	# All filled bars share one colour, chosen by how many bars are filled:
	# 1-2 = red, 3-4 = yellow, 5+ = green. Avoids per-segment gradient flicker.
	var band: Color
	if filled <= 2:
		band = Color(0.9, 0.2, 0.2, 1.0)
	elif filled <= 4:
		band = Color(0.9, 0.7, 0.1, 1.0)
	else:
		band = Color(0.2, 0.8, 0.4, 1.0)
	for i in range(STAMINA_SEGMENTS):
		if i < filled:
			stamina_segments[i].color = band
		else:
			stamina_segments[i].color = Color(0.15, 0.15, 0.15, 1.0)

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
	var py := clampf(head.y - sz.y, 6.0, SCREEN_H - BAR_H - sz.y - 6.0)
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
	_update_drag()
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
		drag_icon.position = get_viewport().get_mouse_position() - Vector2(24, 24)
		if not held:
			_finish_drag()


func _start_drag() -> void:
	drag_active = true
	drag_icon = TextureRect.new()
	drag_icon.texture = ItemData.get_texture(WorldState.get_item_id_at(drag_from))
	drag_icon.custom_minimum_size = Vector2(48, 48)
	drag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_icon.modulate = Color(1, 1, 1, 0.8)
	$Control.add_child(drag_icon)


func _finish_drag() -> void:
	drag_active = false
	if drag_icon != null:
		drag_icon.queue_free()
		drag_icon = null
	var from = drag_from
	drag_from = -1
	if from < 0 or from >= WorldState.inventory.size():
		return
	var mouse = get_viewport().get_mouse_position()
	# Dropped on another slot?
	for i in range(slots.size()):
		if slots[i].get_global_rect().has_point(mouse) and i != from:
			_drop_on_slot(from, i)
			return
	# Dropped on the game world (above the HUD bar) = discard.
	if mouse.y < SCREEN_H - BAR_H - 40:
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
	if not instance.is_depleted:
		var player = get_tree().get_first_node_in_group("player")
		if player != null:
			var drop_pos = player.global_position + Vector2(randf_range(-20, 20), 0)
			var extra = {}
			if instance.target_apartment != "":
				extra["target_apartment"] = instance.target_apartment
			WorldState.add_world_drop(instance.item_id, drop_pos, WorldState.current_floor, extra)
	if selected_slot > slot_index:
		selected_slot -= 1
	elif selected_slot == slot_index:
		selected_slot = -1
	WorldState.remove_from_inventory(slot_index)
	_update_slot_highlights()
	refresh_inventory()
	show_feedback(item_data.get("name", "Item") + " dropped.")

func select_slot(index: int) -> void:
	if selected_slot == index:
		selected_slot = -1
	else:
		selected_slot = index
	_update_slot_highlights()
	context_menu.visible = false

func _update_slot_highlights() -> void:
	for i in range(slots.size()):
		if i == selected_slot:
			slots[i].add_theme_stylebox_override("panel", _make_slot_style_selected())
		else:
			slots[i].add_theme_stylebox_override("panel", _make_slot_style(false))

func _make_slot_style_selected() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.4, 0.1, 1.0)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(1.0, 1.0, 0.2, 1.0)
	return style

func show_context_menu(slot_index: int) -> void:
	context_slot = slot_index
	var slot_pos = slots[slot_index].global_position
	context_menu.position = Vector2(slot_pos.x, slot_pos.y - 100)
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
		var item_data = instance.get_data()
		var is_broken = item_data.get("is_weapon", false) and instance.is_depleted
		var is_consumed = not item_data.get("is_weapon", false) and instance.is_depleted
		if not is_broken and not is_consumed:
			var player = get_tree().get_first_node_in_group("player")
			if player != null:
				var drop_pos = player.global_position + Vector2(randf_range(-20, 20), 0)
				var extra = {}
				if instance.target_apartment != "":
					extra["target_apartment"] = instance.target_apartment
				WorldState.add_world_drop(instance.item_id, drop_pos, WorldState.current_floor, extra)
		if selected_slot > context_slot:
			selected_slot -= 1
		elif selected_slot == context_slot:
			selected_slot = -1
		WorldState.remove_from_inventory(context_slot)
		_update_slot_highlights()
		refresh_inventory()
		show_feedback("Item dropped.")

func _context_cancel() -> void:
	context_menu.visible = false

func show_feedback(text: String) -> void:
	feedback_label.text = text
	feedback_timer = 2.0
	feedback_label.modulate = Color(1, 1, 0.5, 1)

func _make_slot_style(locked: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.25, 0.25, 1.0) if not locked else Color(0.15, 0.15, 0.15, 1.0)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.6, 0.6, 0.6, 1.0) if not locked else Color(0.35, 0.35, 0.35, 1.0)
	return style

func update_floor_label() -> void:
	floor_label.text = "FLOOR:\n" + str(WorldState.current_floor) + " / 30"

func update_portrait(health_index: int) -> void:
	if portrait == null:
		return
	portrait.texture = PORTRAITS[health_index]

func update_mode_indicator() -> void:
	if mode_label == null:
		return
	if WorldState.is_scavenge_mode:
		mode_label.text = "[ SCAVENGE ]"
		mode_label.modulate = Color(0.4, 1.0, 0.4, 1.0)
	else:
		mode_label.text = "[ COMBAT ]"
		mode_label.modulate = Color(1.0, 0.3, 0.3, 1.0)

func refresh_inventory() -> void:
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
				key_label.text = instance.target_apartment
				key_label.visible = true
			elif item_data.get("is_money", false) or item_data.get("is_ammo", false) \
					or (item_data.get("is_throwable", false) and instance.count > 1):
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

			var max_dur = item_data.get("max_durability", -1)
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
