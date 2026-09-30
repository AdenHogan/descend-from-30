extends Control

# The BACKPACK button in the HUD strip (docs/BACKPACK.md): a small pixel rucksack. Click it (or press
# the pack key, default B) and the character kneels to open it. Hover lifts + lights it; while the pack
# is open its flap is thrown back and it glows amber. Drawn in code (placeholder until real UI art), in
# whole "art pixels" of PX screen px so it stays crisp. The only clickable thing here is this button —
# everything else in the strip keeps ignoring the mouse (click-to-move).

signal pressed

const PX := 4.0
const BODY := Color(0.30, 0.34, 0.22)
const BODY_DARK := Color(0.20, 0.23, 0.15)
const BODY_LIGHT := Color(0.42, 0.47, 0.30)
const STRAP := Color(0.14, 0.12, 0.10)
const BUCKLE := Color(0.82, 0.70, 0.32)
const MOUTH := Color(0.05, 0.045, 0.05)
const AMBER := Color(0.89, 0.647, 0.247, 1.0)

var hovered: bool = false
var is_pack_open: bool = false          # set by the HUD each frame from the player's pack phase
var key_text: String = "B"
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(64, 78)
	size = Vector2(64, 78)
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


func _rect(x: float, y: float, w: float, h: float, col: Color) -> void:
	draw_rect(Rect2(Vector2(x, y) * PX, Vector2(w, h) * PX), col)


func _draw() -> void:
	var lift: float = (sin(_t * 5.0) * 0.5 + 0.5) * 0.5 if hovered else 0.0      # a small bob on hover
	var oy: float = -lift
	# glow when it's open or under the pointer
	if is_pack_open or hovered:
		draw_rect(Rect2(Vector2(0, 0) * PX, Vector2(16, 14) * PX), Color(AMBER.r, AMBER.g, AMBER.b, 0.09 if not is_pack_open else 0.16))
	var b: float = 1.0 + oy
	# handle loop
	_rect(6, b, 4, 1, STRAP)
	_rect(5, b + 1, 1, 1, STRAP)
	_rect(10, b + 1, 1, 1, STRAP)
	# body
	_rect(3, b + 2, 10, 10, BODY)
	_rect(3, b + 2, 1, 10, BODY_LIGHT)
	_rect(12, b + 2, 1, 10, BODY_DARK)
	_rect(4, b + 1.5, 8, 0.5, BODY)
	# the mouth + flap
	if is_pack_open:
		_rect(4, b + 2, 8, 2, MOUTH)
		_rect(4, b - 0.5, 8, 2.5, BODY_LIGHT)          # flap thrown back
		_rect(7, b - 1.0, 2, 1, STRAP)
		_rect(5, b + 2, 2, 1, Color(0.86, 0.82, 0.72))  # a glimpse inside
	else:
		_rect(4, b + 2, 8, 4, BODY_DARK)                # closed flap
		_rect(4, b + 2, 8, 1, BODY_LIGHT)
		_rect(7, b + 4, 2, 3, STRAP)
		_rect(7, b + 6, 2, 1, BUCKLE)
	# front pocket + side pockets
	_rect(4, b + 8, 8, 3, BODY_DARK)
	_rect(4, b + 8, 8, 1, BODY_LIGHT)
	_rect(2, b + 6, 1, 4, BODY_DARK)
	_rect(13, b + 6, 1, 4, BODY_DARK)
	# the key hint under it
	var font: Font = get_theme_default_font()
	var col: Color = AMBER if (hovered or is_pack_open) else Color(0.64, 0.61, 0.53)
	draw_string_outline(font, Vector2(0, 14.6 * PX + 12.0), "[%s]" % key_text, HORIZONTAL_ALIGNMENT_CENTER, 16.0 * PX, 13, 4, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(0, 14.6 * PX + 12.0), "[%s]" % key_text, HORIZONTAL_ALIGNMENT_CENTER, 16.0 * PX, 13, col)
