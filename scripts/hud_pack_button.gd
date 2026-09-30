extends Control

# The BACKPACK button (docs/BACKPACK.md): the pixel RUCKSACK from PackArt (shared with the floor prop). Click it (or press
# the pack key, default B) and the character kneels to open it. Hover lifts + lights it; while the pack
# is open it glows amber. Drawn from the shared PackArt texture in
# whole "art pixels" of PX screen px so it stays crisp. The only clickable thing here is this button —
# everything else in the strip keeps ignoring the mouse (click-to-move).

signal pressed

const PX := 4.0
const AMBER := Color(0.89, 0.647, 0.247, 1.0)

var hovered: bool = false
var is_pack_open: bool = false          # set by the HUD each frame from the player's pack phase
var key_text: String = "B"
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(64, 96)
	size = Vector2(64, 96)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_entered.connect(func() -> void:
		hovered = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		hovered = false
		queue_redraw())


func _process(delta: float) -> void:
	_t += delta
	if hovered or is_pack_open:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func _draw() -> void:
	var lift: float = (sin(_t * 5.0) * 0.5 + 0.5) * 2.0 if hovered else 0.0      # a small bob on hover
	var w: float = PackArt.W * PX
	var h: float = PackArt.H * PX
	var oy: float = -lift
	# a soft amber glow behind it when it's open or under the pointer
	if is_pack_open or hovered:
		var a: float = 0.16 if is_pack_open else 0.09
		draw_rect(Rect2(Vector2(-4, -4), Vector2(w + 8, h + 8)), Color(AMBER.r, AMBER.g, AMBER.b, a))
	# a floor shadow so it sits rather than floats
	draw_rect(Rect2(Vector2(6, h - 2), Vector2(w - 12, 5)), Color(0, 0, 0, 0.35))
	var tint: Color = Color(1.12, 1.06, 0.94) if (hovered or is_pack_open) else Color(1, 1, 1)
	draw_texture_rect(PackArt.texture(), Rect2(Vector2(0, oy), Vector2(w, h)), false, tint)
	# the key hint under it
	var font: Font = get_theme_default_font()
	var col: Color = AMBER if (hovered or is_pack_open) else Color(0.64, 0.61, 0.53)
	var y: float = h + 14.0
	draw_string_outline(font, Vector2(0, y), "[%s]" % key_text, HORIZONTAL_ALIGNMENT_CENTER, w, 13, 4, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(0, y), "[%s]" % key_text, HORIZONTAL_ALIGNMENT_CENTER, w, 13, col)
