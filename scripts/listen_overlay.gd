extends CanvasLayer

# Listen-mode presentation (docs/SOUND_STEALTH.md): grey-out vignette that
# darkens with distance from screen centre, organic red echo pings at the
# listened door/stairwell, and the player's spoken report afterwards.
# Sits on layer 2 so pings and popup stay in colour above the grey (HUD's
# own layer would be desaturated along with the world otherwise).

const FADE_TIME = 0.45
const PING_BASE_RADIUS = 12.0
const PING_MAX_GROWTH = 78.0
const REPORT_SHOW_TIME = 3.5

var state: String = "idle"  # idle / fading_in / active / fading_out
var intensity: float = 0.0
var source_world_pos: Vector2 = Vector2.ZERO
var profile: Dictionary = {}
var pings: Array = []          # each: {"age": float, "phase": float}
var ping_spawn_timer: float = 0.0
var pending_report: String = ""
var report_timer: float = 0.0

var grey_rect: ColorRect = null
var ping_canvas: Control = null
var report_panel: PanelContainer = null
var report_label: Label = null

const HEARTBEAT_STREAM = preload("res://assets/audio/heartbeat.wav")
const HEARTBEAT_PERIOD = 1.1
var heartbeat_player: AudioStreamPlayer = null
var heartbeat_timer: float = 0.0


func _ready() -> void:
	layer = 2
	grey_rect = ColorRect.new()
	grey_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	grey_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grey_rect.visible = false
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_tex : hint_screen_texture;
void fragment() {
	vec4 scr = texture(screen_tex, SCREEN_UV);
	float g = dot(scr.rgb, vec3(0.299, 0.587, 0.114));
	float d = distance(SCREEN_UV, vec2(0.5, 0.5));
	// Focus falloff: a TIGHT readable circle around the player, then a hard
	// slide into near-black — the edges must be dark enough for something to
	// genuinely sneak up through them while you're focused.
	float vig = smoothstep(0.06, 0.40, d);
	vec3 grey = mix(vec3(g * 0.9), vec3(g * 0.05), vig);
	COLOR = vec4(mix(scr.rgb, grey, intensity), 1.0);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	grey_rect.material = mat
	add_child(grey_rect)

	ping_canvas = Control.new()
	ping_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	ping_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ping_canvas.draw.connect(_draw_pings)
	add_child(ping_canvas)

	report_panel = PanelContainer.new()
	report_panel.visible = false
	report_panel.position = Vector2(140, 470)
	report_panel.custom_minimum_size = Vector2(420, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.92)
	style.border_width_left = 3
	style.border_color = Color(0.7, 0.65, 0.5, 1.0)
	report_panel.add_theme_stylebox_override("panel", style)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	report_panel.add_child(margin)
	report_label = Label.new()
	report_label.add_theme_font_size_override("font_size", 14)
	report_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8, 1.0))
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(report_label)
	add_child(report_panel)

	heartbeat_player = AudioStreamPlayer.new()
	heartbeat_player.stream = HEARTBEAT_STREAM
	add_child(heartbeat_player)


func begin(world_pos: Vector2, listen_profile: Dictionary) -> void:
	source_world_pos = world_pos
	profile = listen_profile
	pings.clear()
	ping_spawn_timer = 0.0
	state = "fading_in"
	grey_rect.visible = true
	report_panel.visible = false


func abort() -> void:
	# Interrupted (took a hit) — grey snaps away, no report is delivered.
	state = "idle"
	intensity = 0.0
	grey_rect.visible = false
	pings.clear()
	ping_canvas.queue_redraw()


func finish(report_line: String) -> void:
	state = "fading_out"
	pending_report = report_line


func _process(delta: float) -> void:
	match state:
		"fading_in":
			intensity = min(intensity + delta / FADE_TIME, 1.0)
			if intensity >= 1.0:
				state = "active"
		"fading_out":
			intensity = max(intensity - delta / FADE_TIME, 0.0)
			if intensity <= 0.0:
				state = "idle"
				grey_rect.visible = false
				pings.clear()
				if pending_report != "":
					report_label.text = "\"" + pending_report + "\""
					report_panel.visible = true
					report_panel.modulate = Color(1, 1, 1, 1)
					report_timer = REPORT_SHOW_TIME
					pending_report = ""
	if grey_rect.visible:
		(grey_rect.material as ShaderMaterial).set_shader_parameter("intensity", intensity)

	if state == "fading_in" or state == "active":
		_tick_pings(delta)
		# Heartbeat swells with the grey — the focus has a pulse.
		heartbeat_timer -= delta
		if heartbeat_timer <= 0.0:
			heartbeat_timer = HEARTBEAT_PERIOD
			heartbeat_player.volume_db = lerp(-30.0, -12.0, intensity)
			heartbeat_player.play()
	ping_canvas.queue_redraw()

	if report_panel.visible:
		report_timer -= delta
		if report_timer <= 1.0:
			report_panel.modulate = Color(1, 1, 1, max(report_timer, 0.0))
		if report_timer <= 0.0:
			report_panel.visible = false


func _tick_pings(delta: float) -> void:
	for ping in pings:
		ping["age"] += delta
	pings = pings.filter(func(p): return p["age"] < 1.0)
	if int(profile.get("count", 0)) <= 0 and not profile.get("has_big", false):
		return  # silence — no echoes at all is itself the answer
	ping_spawn_timer -= delta
	if ping_spawn_timer <= 0.0:
		# Faster pings = noise nearer the door (nearness 1 = at the entrance).
		var nearness = clamp(float(profile.get("nearness", 0.5)), 0.0, 1.0)
		ping_spawn_timer = lerp(0.85, 0.22, nearness)
		pings.append({"age": 0.0, "phase": randf() * TAU})


func _draw_pings() -> void:
	if pings.is_empty():
		return
	var screen_pos = ping_canvas.get_viewport().canvas_transform * source_world_pos
	var big = profile.get("has_big", false)
	var base_color = Color(0.78, 0.10, 0.06) if big else Color(0.88, 0.18, 0.10)
	var width = 3.0 if big else 2.0
	for ping in pings:
		var age = ping["age"]
		var radius = PING_BASE_RADIUS + age * PING_MAX_GROWTH
		var alpha = (1.0 - age) * 0.85 * intensity
		var points = PackedVector2Array()
		# Organic ring: the radius wobbles with two interfering sine bands, so
		# each echo reads as a pressure ripple rather than a drawn circle.
		for i in range(41):
			var angle = TAU * i / 40.0
			var wobble = sin(angle * 5.0 + ping["phase"] + age * 7.0) * 4.0 \
				+ sin(angle * 3.0 - age * 5.0 + ping["phase"]) * 3.0
			points.append(screen_pos + Vector2.from_angle(angle) * (radius + wobble))
		ping_canvas.draw_polyline(points, Color(base_color.r, base_color.g, base_color.b, alpha), width)
