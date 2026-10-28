class_name Lamp
extends RefCounted

## THE LAMPLIGHT — the look the pack ring, the body ring and the found-item panel share (owner round 48j, after the taped-paper rings: "give me a version of the wheel that also looked
## like that other mockup you made, the one that was dark and goldish in the corners. It looked pretty smart and clean… there's just way too much text going on… it needs to be clean
## information a player can glance at and recognise. If we even need text, it needs to be one word (equip, drop, compare, etc)").
##
## The palette is the "Descent Menu Mockups" Lamplight board's, hex for hex: dark glass, a brass edge with brass corner brackets, warm text. The rules (a gate on any later UI in this look):
##   * information first — a word is ONE word (EQUIP, DROP, HELD, LOCKED); a number carries a coloured ▲ / ▼, never a sentence; no help strips;
##   * brass is what is YOURS or chosen (the item in hand, the corner brackets, the thing you are about to do); green / red are better / worse, and only that; a cool steel blue marks a body's
##     things, so two rings side by side are never mistaken;
##   * the journal stays paper (scripts/ledger.gd — it is the character's own diary); EVERYTHING ELSE the player operates is this look, the merchant and the workbench included (owner round 48l:
##     "there's a big UI disconnect. So many different font styles, colours, and types of text… didn't we change this back to the black and gold version?");
##   * ONE type scale (the PX_* constants below): a screen's name, an item's name, a sentence, a letter-spaced label — four sizes, nothing under 16 px, two faces, no handwriting;
##   * words are short and say what to DO or what it MEANS: a cost is shown against what you have, a refusal says exactly what is missing;
##   * drawing only: every function paints on the CanvasItem it is handed and returns; nothing here owns state or decides anything the rings did before.
## The type is the logo's Barlow Condensed (heads and letter-spaced labels) over Barlow (plain), from scripts/ledger.gd — one set of faces for the whole game.

const GLASS_TOP := Color(0.094, 0.071, 0.047, 0.97)       # rgba(24,18,12,.97)
const GLASS_BOT := Color(0.047, 0.035, 0.024, 0.98)       # rgba(12,9,6,.98)
const CARD := Color(0.106, 0.078, 0.051)                  # #1b140d
const WELL := Color(0.071, 0.047, 0.027)                  # #120c07
const EDGE := Color(0.290, 0.224, 0.125)                  # #4a3920
const EDGE_DIM := Color(0.180, 0.137, 0.078)              # #2e2314
const RIM := Color(0.165, 0.114, 0.055)                   # #2a1d0e
const BRASS := Color(0.851, 0.643, 0.255)                 # #d9a441
const BRASS_HI := Color(0.941, 0.725, 0.353)              # #f0b95a
const BRASS_DIM := Color(0.541, 0.416, 0.204)             # #8a6a34
const LABEL := Color(0.710, 0.541, 0.271)                 # #b58a45
const TEXT := Color(0.941, 0.886, 0.741)                  # #f0e2bd
const BODY := Color(0.796, 0.749, 0.624)                  # #cbbf9f
const SOFT := Color(0.663, 0.616, 0.510)                  # #a99d82
const DIM := Color(0.561, 0.514, 0.408)                   # #8f8368
const GREEN := Color(0.624, 0.820, 0.541)                 # #9fd18a
const RED := Color(0.878, 0.478, 0.400)                   # #e07a66
const STEEL := Color(0.435, 0.659, 0.839)                 # #6fa8d6 — the body's accent
const ON_BRASS := Color(0.102, 0.071, 0.031)              # #1a1208 — text on a brass fill

const TL := 1
const TR := 2
const BL := 4
const BR := 8
const ALL := 15

## THE TYPE SCALE (px at the 1152 x 648 screen). Every Lamplight screen uses these four and nothing else — the owner's "too many font styles… small and tough to read".
const PX_TITLE := 32        # a screen's name (WORKBENCH), a big number (scrap)
const PX_NAME := 26         # an item's / perk's / weapon's name
const PX_BODY := 20         # every sentence and every figure in a sentence
const PX_LABEL := 18        # letter-spaced capitals: tabs, buttons, captions

static var _label_font: Font = null


# ---------------------------------------------------------------------------------------------------------------------------------- type
## `kind`: "head" (Barlow Condensed Bold), "label" (the same, letter-spaced — for a one-word caption), "body" (Barlow).
static func font(kind: String) -> Font:
	match kind:
		"label":
			if _label_font == null:
				var v := FontVariation.new()
				v.base_font = load(Ledger.FONT_HEAD)
				v.spacing_glyph = 2
				_label_font = v
			return _label_font
		"head":
			return Ledger.font("head")
		_:
			return Ledger.font("body")


## The biggest size (<= px) at which `s` fits in `width`; it stops at 8 rather than loop.
static func fit(f: Font, s: String, px: int, width: float) -> int:
	var size := px
	while size > 8 and f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size


## Text on a baseline, shrunk to fit `width`. `align` is a HORIZONTAL_ALIGNMENT_*; the string is placed in [baseline.x, baseline.x + width].
static func text(ci: CanvasItem, kind: String, baseline: Vector2, s: String, px: int, col: Color, width: float, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f: Font = font(kind)
	ci.draw_string(f, baseline, s, align, width, fit(f, s, px, width), col)


## A Label in the kit's faces and colours (never a different font or size by accident). `kind`: "head" / "label" / "body".
static func label(text: String, kind: String, px: int, col: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A RichTextLabel set up the same way: Barlow at the body size in the body colour, bold = Barlow Condensed. Colour a word with [color=#hex] (use the `hex` helper).
static func rich(px: int = PX_BODY, col: Color = BODY) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = false
	r.fit_content = true
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", font("body"))
	r.add_theme_font_override("bold_font", font("head"))
	r.add_theme_font_size_override("normal_font_size", px)
	r.add_theme_font_size_override("bold_font_size", px + 2)
	r.add_theme_color_override("default_color", col)
	return r


static func hex(c: Color) -> String:
	return c.to_html(false)


## The room dims round a screen: a vignette that keeps the middle of the view the world (and stops clicks, because the game is paused behind it).
static func backdrop() -> TextureRect:
	var t := TextureRect.new()
	t.name = "Backdrop"
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.30), Color(0, 0, 0, 0.52), Color(0.02, 0.012, 0.008, 0.82)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 1.0)
	gt.width = 256
	gt.height = 144
	t.texture = gt
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	return t


static func fade(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


# ---------------------------------------------------------------------------------------------------------------------------------- frames
## An L of `col` at each chosen corner of `rect`, hugging the outside edge (the board's brass ticks). `corners` is a mask of TL / TR / BL / BR.
static func brackets(ci: CanvasItem, rect: Rect2, col: Color, arm: float = 14.0, thick: float = 3.0, corners: int = ALL, out: float = 1.0) -> void:
	var r := rect.grow(out)
	if corners & TL:
		ci.draw_rect(Rect2(r.position, Vector2(arm, thick)), col)
		ci.draw_rect(Rect2(r.position, Vector2(thick, arm)), col)
	if corners & TR:
		ci.draw_rect(Rect2(Vector2(r.end.x - arm, r.position.y), Vector2(arm, thick)), col)
		ci.draw_rect(Rect2(Vector2(r.end.x - thick, r.position.y), Vector2(thick, arm)), col)
	if corners & BL:
		ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - thick), Vector2(arm, thick)), col)
		ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - arm), Vector2(thick, arm)), col)
	if corners & BR:
		ci.draw_rect(Rect2(Vector2(r.end.x - arm, r.end.y - thick), Vector2(arm, thick)), col)
		ci.draw_rect(Rect2(Vector2(r.end.x - thick, r.end.y - arm), Vector2(thick, arm)), col)


## A 1-px outline drawn as four filled strips (a pixel-exact edge whatever the stretch).
static func outline(ci: CanvasItem, rect: Rect2, col: Color, w: float = 1.0) -> void:
	ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, w)), col)
	ci.draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - w), Vector2(rect.size.x, w)), col)
	ci.draw_rect(Rect2(rect.position + Vector2(0, w), Vector2(w, rect.size.y - 2.0 * w)), col)
	ci.draw_rect(Rect2(Vector2(rect.end.x - w, rect.position.y + w), Vector2(w, rect.size.y - 2.0 * w)), col)


## A soft warm halo round a rect (a few widening rings of falling alpha) — what a lit edge throws on the dark.
static func glow(ci: CanvasItem, rect: Rect2, col: Color, strength: float) -> void:
	for i in range(4):
		var g := float(i + 1) * 2.5
		ci.draw_rect(rect.grow(g), Color(col.r, col.g, col.b, strength * (0.20 - 0.045 * float(i))))


## The dark glass of the board: a drop shadow, the vertical gradient, a faint warm inner light, a 2-px brass edge with a thin darker rim outside it, and brass corner brackets.
## `corners` chooses which brackets (the found-item panel uses TL + BR, like the board). `accent` is the bracket colour (steel for a body).
static func panel(ci: CanvasItem, rect: Rect2, alpha: float = 1.0, corners: int = ALL, arm: float = 18.0, accent: Color = BRASS, edge: Color = BRASS_DIM) -> void:
	for i in range(4):
		var sh := rect.grow(float(i) * 3.0 + 1.0)
		ci.draw_rect(Rect2(sh.position + Vector2(0, 7.0 + float(i) * 2.0), sh.size), Color(0, 0, 0, 0.13 * alpha))
	var top := fade(GLASS_TOP, alpha)
	var bot := fade(GLASS_BOT, alpha)
	ci.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), PackedColorArray([top, top, bot, bot]))
	for i in range(3):                                                                                       # the lamp's light inside the glass
		ci.draw_rect(rect.grow(-2.0 - float(i) * 5.0), Color(0.78, 0.55, 0.20, 0.022 * alpha), false, 5.0)
	outline(ci, rect.grow(1.0), fade(RIM, alpha), 1.0)
	outline(ci, rect, fade(edge, alpha), 2.0)
	if corners != 0:
		brackets(ci, rect, fade(accent, alpha), arm, 4.0, corners, 2.0)


## A card: fill, 1-px edge. `lit` brightens the edge to brass (hover / chosen).
static func card(ci: CanvasItem, rect: Rect2, fill: Color = CARD, edge: Color = EDGE, alpha: float = 1.0) -> void:
	ci.draw_rect(rect, fade(fill, alpha))
	outline(ci, rect, fade(edge, alpha), 1.0)


## A dashed outline of where something was (a slot whose item is being dragged).
static func dashed_rect(ci: CanvasItem, rect: Rect2, col: Color, dash: float = 5.0, gap: float = 4.0) -> void:
	var x := rect.position.x
	while x < rect.end.x:
		var x2 := minf(x + dash, rect.end.x)
		ci.draw_line(Vector2(x, rect.position.y + 0.5), Vector2(x2, rect.position.y + 0.5), col, 1.0)
		ci.draw_line(Vector2(x, rect.end.y - 0.5), Vector2(x2, rect.end.y - 0.5), col, 1.0)
		x += dash + gap
	var y := rect.position.y
	while y < rect.end.y:
		var y2 := minf(y + dash, rect.end.y)
		ci.draw_line(Vector2(rect.position.x + 0.5, y), Vector2(rect.position.x + 0.5, y2), col, 1.0)
		ci.draw_line(Vector2(rect.end.x - 0.5, y), Vector2(rect.end.x - 0.5, y2), col, 1.0)
		y += dash + gap


## The dark the ring lies on, and the dashed track the slots sit on (the board's quiet dashed ring).
static func ring_base(ci: CanvasItem, centre: Vector2, radius: float, track_r: float, t: float, accent: Color = BRASS_DIM) -> void:
	ci.draw_circle(centre, radius, Color(0.03, 0.022, 0.014, 0.56 * t))
	ci.draw_arc(centre, radius, 0.0, TAU, 96, Color(accent.r, accent.g, accent.b, 0.30 * t), 1.0, true)
	for k in range(24):
		var a0 := TAU * float(k) / 24.0
		ci.draw_arc(centre, track_r, a0, a0 + TAU / 24.0 * 0.5, 4, Color(EDGE.r, EDGE.g, EDGE.b, 0.9 * t), 1.0, true)


## A triangle that says higher / lower (▲ / ▼), drawn — not a font glyph — so it is the same on every machine.
static func arrow(ci: CanvasItem, centre: Vector2, up: bool, col: Color, size: float = 4.0) -> void:
	var s := size
	if up:
		ci.draw_colored_polygon(PackedVector2Array([centre + Vector2(0, -s), centre + Vector2(s, s * 0.8), centre + Vector2(-s, s * 0.8)]), col)
	else:
		ci.draw_colored_polygon(PackedVector2Array([centre + Vector2(0, s), centre + Vector2(s, -s * 0.8), centre + Vector2(-s, -s * 0.8)]), col)


## A padlock in brass (the locked slot).
static func padlock(ci: CanvasItem, pos: Vector2, col: Color) -> void:
	ci.draw_arc(pos + Vector2(0, -3), 6.0, PI, TAU, 16, col, 2.5, true)
	ci.draw_rect(Rect2(pos + Vector2(-8, -3), Vector2(16, 12)), col)
	ci.draw_rect(Rect2(pos + Vector2(-1, 1), Vector2(2, 4)), Color(0.05, 0.035, 0.02, 0.9))


# ---------------------------------------------------------------------------------------------------------------------------------- a slot
const SLOT_ICON := 56.0

## One slot of a ring: a dark card with the thing on it, its key number, a count, and a bar for what is left of it.
## `o`: on (the pointer is on it), held (in hand), plan (-1 none / 0 will not work / 1 will — a craft being dragged over it), accent (bracket colour), lit (the hovered edge's colour),
## t (open 0..1), num (key number or 0), pulse (0..1).
static func slot(ci: CanvasItem, rect: Rect2, inst, o: Dictionary) -> void:
	var t: float = o.get("t", 1.0)
	var accent: Color = o.get("accent", BRASS)
	var on: bool = o.get("on", false)
	var held: bool = o.get("held", false)
	var plan: int = o.get("plan", -1)
	var pulse: float = o.get("pulse", 0.0)
	var edge: Color = EDGE if inst != null else EDGE_DIM
	if on and inst != null:
		edge = o.get("lit", BRASS_HI)
	if held:
		edge = accent
	var mark := Color(0, 0, 0, 0)
	if plan >= 0:
		mark = GREEN if plan > 0 else RED
		edge = mark
	if inst != null and (on or held or plan >= 0):
		glow(ci, rect, mark if plan >= 0 else edge, t * (0.7 + 0.3 * pulse))
	card(ci, rect, CARD if inst != null else WELL, edge, t)
	var num: int = o.get("num", 0)
	if inst == null:
		if num > 0:
			text(ci, "label", rect.position + Vector2(0, rect.size.y * 0.5 + 6.0), str(num), 18, fade(DIM, 0.5 * t), rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var c := (rect.position + rect.size * 0.5).round()
	var tex: Texture2D = ItemData.get_texture(inst.item_id)
	if tex != null:
		var broken: bool = inst.is_depleted and inst.get_max_durability() > 0
		ci.draw_texture_rect(tex, Rect2(c - Vector2(SLOT_ICON, SLOT_ICON) * 0.5, Vector2(SLOT_ICON, SLOT_ICON)), false, Color(0.55, 0.42, 0.42, t) if broken else Color(1, 1, 1, t))
	if num > 0:
		text(ci, "label", rect.position + Vector2(5.0, 15.0), str(num), 15, fade(DIM, t), 18.0)
	var max_d: int = inst.get_max_durability()
	if max_d > 1 and not inst.is_depleted:
		var ratio := clampf(float(inst.current_durability) / float(max_d), 0.0, 1.0)
		var bar := Rect2(rect.position.x + 8.0, rect.end.y - 5.0, rect.size.x - 16.0, 3.0)
		ci.draw_rect(bar, fade(EDGE_DIM, t))
		ci.draw_rect(Rect2(bar.position, Vector2(maxf(bar.size.x * ratio, 2.0), bar.size.y)), fade(GREEN if ratio > 0.5 else (BRASS if ratio > 0.25 else RED), t))
	if inst.count > 1:
		var s := "x%d" % inst.count
		var w := font("head").get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 8.0
		var pill := Rect2(rect.end.x - w - 3.0, rect.end.y - 25.0, w, 19.0)
		ci.draw_rect(pill, Color(WELL.r, WELL.g, WELL.b, 0.86 * t))
		text(ci, "head", Vector2(pill.position.x + 4.0, pill.end.y - 3.0), s, 18, fade(TEXT, t), w)
	if held:
		brackets(ci, rect, fade(accent, t), 9.0, 3.0, ALL, 1.0)
		tab(ci, Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y - 1.0), "HELD", accent, t)
	elif plan >= 0:
		brackets(ci, rect, fade(mark, t), 9.0, 3.0, ALL, 1.0)


## A small solid tab with one word on it, centred on `at` (the in-hand mark on a slot; the board's IN HAND).
static func tab(ci: CanvasItem, at: Vector2, word: String, fill: Color, t: float = 1.0) -> Rect2:
	var f := font("label")
	var w := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 14.0
	var r := Rect2(at - Vector2(w * 0.5, 9.0), Vector2(w, 18.0))
	ci.draw_rect(r, fade(fill, t))
	text(ci, "label", Vector2(r.position.x + 1.0, r.end.y - 4.0), word, 14, fade(ON_BRASS, t), w, HORIZONTAL_ALIGNMENT_CENTER)
	return r


# ---------------------------------------------------------------------------------------------------------------------------------- the card in the middle
## The readout in the middle of a ring (owner round 48l, on two screenshots of the ring: "this text needs optimising. It's way too small and unreadable"): every size is from the type scale
## — a name 22, a figure 20, a note 18, a caption 16 — so the card is read at a glance from where the player sits; it WRAPS a long name onto a second line rather than shrinking it to nothing,
## and the ring is sized to leave it room (pack_wheel.RING_R; tests/lamp_test measures it never touches a slot).
const ROW_H := 26.0                  # a stat row (20 px figures)
const INFO_PAD := 12.0
const INFO_W := 168.0                # a card of words
const INFO_W_ROWS := 200.0           # a card with stat rows: label | figure | the ▲ / ▼
const PX_INFO_TITLE := 22
const PX_INFO_NOTE := 18
const PX_INFO_WORD := 16
const PX_INFO_BIG := 30
const INFO_LINE_MIN := 15            # the smallest a line is ever shrunk to when even two lines will not hold it

## Which of an ItemCompare card's rows are worth a glance: the ones that differ from the weapon in hand first, then the usual three — at most `n`.
static func pick_rows(rows: Array, n: int = 3) -> Array:
	var order := ["Damage", "Durability", "Speed", "Reach", "Close hit", "Magazine", "Stamina"]
	var out: Array = []
	for r in rows:
		if String(r["delta"]) != "":
			out.append(r)
	for want in order:
		if out.size() >= n:
			break
		for r in rows:
			if String(r["label"]) == want and not out.has(r):
				out.append(r)
				break
	out = out.slice(0, n)
	var sorted: Array = []                      # keep the card's own order so the rows never shuffle between items
	for r in rows:
		if out.has(r):
			sorted.append(r)
	return sorted


## One stat row: the label soft, the value in the bright head face, then the ▲ / ▼ and the difference in green (better) or red (worse). Draws in [x, x + w]; `y` is the row's top, the
## row is `row_h` tall and `big` is the value's size (the label and the mark follow it).
static func row(ci: CanvasItem, x: float, y: float, w: float, r: Dictionary, t: float = 1.0, label_w: float = 52.0, big: int = 15, row_h: float = ROW_H) -> void:
	var base := y + row_h * 0.5 + float(big) * 0.33
	var k := float(big) / 15.0
	text(ci, "body", Vector2(x, base), String(r["label"]), int(round(float(big) * 0.78)), fade(SOFT, t), label_w)
	text(ci, "head", Vector2(x + label_w, base), String(r["text"]), big, fade(TEXT, t), 44.0 * k)
	var d: String = String(r.get("delta", ""))
	if d == "":
		return
	var tone := int(r.get("tone", 0))
	var col: Color = GREEN if tone > 0 else (RED if tone < 0 else DIM)
	var f := font("head")
	var num: String = d.substr(1).strip_edges()                    # "▲ +18" -> "+18"
	var nw := f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, big - 2).x
	ci.draw_string(f, Vector2(x + w - nw, base), num, HORIZONTAL_ALIGNMENT_LEFT, nw + 2.0, big - 2, fade(col, t))
	arrow(ci, Vector2(x + w - nw - 3.0 - 3.5 * k, base - 4.0 * k - 1.0), d.begins_with("▲"), fade(col, t), 3.5 * k)


## `s` set in `width`: at `px` on one line if it fits, else on two lines (split at the space that balances them) at `px`, else shrunk — never below INFO_LINE_MIN — to the width.
## Returns {lines: PackedStringArray, px: int}. Pure (it reads the font's metrics only), so a card's size can be known before it is drawn.
static func wrap_two(kind: String, s: String, px: int, width: float) -> Dictionary:
	var f: Font = font(kind)
	if f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= width:
		return {"lines": PackedStringArray([s]), "px": px}
	var best := -1
	var best_w := 1.0e9
	for i in range(s.length()):
		if s[i] != " ":
			continue
		var w1 := f.get_string_size(s.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var w2 := f.get_string_size(s.substr(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		if maxf(w1, w2) < best_w:
			best_w = maxf(w1, w2)
			best = i
	if best >= 0 and best_w <= width:
		return {"lines": PackedStringArray([s.substr(0, best), s.substr(best + 1)]), "px": px}
	var small := maxi(INFO_LINE_MIN, fit(f, s, px, width))
	if best >= 0:
		var two := wrap_two(kind, s, maxi(INFO_LINE_MIN, px - 2), width) if px - 2 >= INFO_LINE_MIN else {}
		if not two.is_empty() and (two["lines"] as PackedStringArray).size() == 2:
			return two
	return {"lines": PackedStringArray([s]), "px": small}


static func _line_h(px: int) -> float:
	return float(px) * 1.2


## The info card in the middle of a ring (and the heart of any small readout). `info_size` is its size for `lines` (pure); `info` draws it, centred. `lines`:
##   {"title": s, "col"?}   the item's name, the bright head face (two lines if long)       {"word": s, "col"?}  one letter-spaced caption word (CRAFT, LOCKED…)
##   {"big": s, "col"?}     one large word (DROP)                                           {"note": s, "col"?}  a short plain line (two if long)
##   {"row": true, label, text, delta, tone}   a stat row
## Returns its rect. A card with a stat row is wider so the row has room.
static func _inner_w(lines: Array) -> float:
	for l in lines:
		if l.has("row"):
			return INFO_W_ROWS - 2.0 * INFO_PAD
	return INFO_W - 2.0 * INFO_PAD


static func _line_block(l: Dictionary, inner: float) -> Dictionary:
	if l.has("title"):
		var w := wrap_two("head", String(l["title"]), PX_INFO_TITLE, inner)
		return {"kind": "head", "w": w, "col": l.get("col", TEXT), "gap": 4.0}
	if l.has("note"):
		var w2 := wrap_two("body", String(l["note"]), PX_INFO_NOTE, inner)
		return {"kind": "body", "w": w2, "col": l.get("col", SOFT), "gap": 2.0}
	return {}


static func info_size(lines: Array) -> Vector2:
	var inner := _inner_w(lines)
	var h := 2.0 * INFO_PAD - 2.0
	for l in lines:
		if l.has("row"):
			h += ROW_H
		elif l.has("big"):
			h += 38.0
		elif l.has("word"):
			h += 24.0
		else:
			var b := _line_block(l, inner)
			h += _line_h(int(b["w"]["px"])) * float((b["w"]["lines"] as PackedStringArray).size()) + float(b["gap"])
	return Vector2(INFO_W_ROWS if inner > INFO_W - 2.0 * INFO_PAD else INFO_W, maxf(h, 44.0))


static func info(ci: CanvasItem, centre: Vector2, lines: Array, t: float = 1.0, accent: Color = BRASS) -> Rect2:
	var sz := info_size(lines)
	var rect := Rect2((centre - sz * 0.5).round(), sz)
	panel(ci, rect, t, TL | BR, 11.0, accent, EDGE)
	var inner := sz.x - 2.0 * INFO_PAD
	var x := rect.position.x + INFO_PAD
	var y := rect.position.y + INFO_PAD - 1.0
	for l in lines:
		if l.has("row"):
			row(ci, x, y, inner, l, t, 78.0, 20, ROW_H)
			y += ROW_H
		elif l.has("big"):
			text(ci, "head", Vector2(x, y + 29.0), String(l["big"]), PX_INFO_BIG, fade(l.get("col", TEXT), t), inner, HORIZONTAL_ALIGNMENT_CENTER)
			y += 38.0
		elif l.has("word"):
			text(ci, "label", Vector2(x, y + 17.0), String(l["word"]), PX_INFO_WORD, fade(l.get("col", LABEL), t), inner, HORIZONTAL_ALIGNMENT_CENTER)
			y += 24.0
		else:
			var b := _line_block(l, inner)
			var px: int = int(b["w"]["px"])
			for ln in (b["w"]["lines"] as PackedStringArray):
				text(ci, String(b["kind"]), Vector2(x, y + float(px) * 0.92), String(ln), px, fade(b["col"], t), inner, HORIZONTAL_ALIGNMENT_CENTER)
				y += _line_h(px)
			y += float(b["gap"])
	return rect


## The right-click menu: a dark panel, one word a row, the row under the pointer lit in brass (a drop in red). `rows`: [[label, action]]. `hot` = the highlighted row or -1.
static func menu(ci: CanvasItem, pos: Vector2, w: float, row_h: float, rows: Array, hot: int, accent: Color = BRASS) -> void:
	var h := row_h * float(rows.size()) + 8.0
	var rect := Rect2(pos, Vector2(w, h))
	panel(ci, rect, 1.0, TL | BR, 8.0, accent, EDGE)
	for i in range(rows.size()):
		var y := pos.y + 4.0 + row_h * float(i)
		var drop: bool = String(rows[i][1]) == "drop"
		if i == hot:
			ci.draw_rect(Rect2(pos.x + 4.0, y, w - 8.0, row_h), RED if drop else BRASS)
		var col: Color = (ON_BRASS if i == hot else (RED if drop else BODY))
		text(ci, "label", Vector2(pos.x + 12.0, y + row_h - 6.0), String(rows[i][0]).to_upper(), 17, col, w - 24.0)


## What the middle of a ring says about an item under the pointer: its name, then the few numbers that matter — a weapon's (set against the one in hand when it is another weapon:
## the rows that differ come first), a single short line for anything else, one word when it is broken. Both rings read this, so a thing reads the same on either.
static func item_lines(inst) -> Array:
	var tip: Dictionary = HUD.item_tip_content(inst)
	var kt: String = String(tip.get("key_target", ""))
	if kt != "":                                  # a key: its name, then WHERE it opens — floor and flat in full — or that nothing takes it any more
		var kl: Array = [{"title": WorldState.key_name(kt)}, {"note": WorldState.key_where(kt)}]
		if WorldState.key_is_dead(kt):
			kl.append({"word": "NO CABINET", "col": RED})
		return kl
	var lines: Array = [{"title": String(tip["title"]), "col": BRASS_HI if bool(tip.get("legendary", false)) else TEXT}]
	var cmp: Dictionary = ItemCompare.card(inst, ItemCompare.held_weapon())
	if not cmp.is_empty():
		for r in pick_rows(cmp["rows"], 3):
			var rr: Dictionary = r.duplicate()
			rr["row"] = true
			lines.append(rr)
	if bool(tip.get("broken", false)):
		lines.append({"word": "BROKEN", "col": RED})
	if cmp.is_empty():
		for s in tip["stats"]:                     # the first short fact: "Heals 2", "40 in notes", "6 rounds" — the long sentences are the tooltip's
			var str_s := String(s)
			if str_s.length() <= 16 and str_s != inst.tier_label() and not str_s.begins_with("BROKEN"):
				lines.append({"note": str_s})
				break
	return lines


## What an item IS, in one word, for a panel's small caption: a weapon's kind, else the first flag that fits, else FOUND.
static func kind_word(d: Dictionary) -> String:
	var wk: String = ItemCompare.weapon_kind(d)
	if wk != "":
		# "bat" is the combat table's name for the whole blunt family — a hammer is not a bat
		return {"bat": "BLUNT", "knife": "BLADE", "sword": "BLADE", "gun": "GUN"}.get(wk, wk.to_upper())
	for pair in [["is_key", "KEY"], ["is_ammo", "AMMO"], ["is_money", "CASH"], ["is_scrap", "SCRAP"], ["is_molotov", "FIRE"], ["is_throwable", "THROWN"],
			["is_health_item", "MEDICAL"], ["is_speed_boost", "MEDICAL"], ["is_junk", "JUNK"], ["is_extinguisher", "TOOL"], ["is_tool", "TOOL"], ["is_fuse", "TOOL"]]:
		if d.get(pair[0], false):
			return String(pair[1])
	return "FOUND"
