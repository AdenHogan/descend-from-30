class_name LedgerRing
extends RefCounted

## The pack ring and the body ring in the ledger's own terms (scripts/ledger.gd): every slot is a paper TAG lying on a dark shade — the thing is on the tag — and what the player does to it
## is done with a pen on the tag: the one in hand is circled, a craft that would work is ringed in green and one that would not in red, a gauge is a line of ink. The middle is a slip of
## paper taped down with the item's name and its numbers (printed head, plain body, the player's hand for the better / worse mark). Nothing glows, nothing is a gradient rectangle.
## All of it is pure drawing on a CanvasItem the caller passes in (`ci`); the rings keep every rule of what happens.

const BODY_TINT := Color(0.80, 0.84, 0.88)          # the body's tags are a cooler stock, so the two rings side by side are never mistaken
const SHADE := Color(0.03, 0.022, 0.016)

static var _slip_cache: Dictionary = {}


## A number in 0..1 that is always the same for the same (a, b): the wobble of an edge, the order of a pen stroke.
static func hash01(a: float, b: float) -> float:
	var s := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return s - floorf(s)


static func _moved(p: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	return Ledger.shifted(p, d)


## The outline of a round paper tag: a circle whose edge wanders a little (and stays inside the radius).
static func disc_points(rad: float, seed_value: int, n: int = 26) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var ang := TAU * float(i) / float(n)
		pts.append(Vector2(cos(ang), sin(ang)) * rad * (1.0 - 0.04 * hash01(float(i), float(seed_value))))
	return pts


## The dark the ring lies on (the desk the pack is open on), growing in with the ring.
static func shade(ci: CanvasItem, centre: Vector2, radius: float, t: float) -> void:
	ci.draw_circle(centre, radius, Color(SHADE.r, SHADE.g, SHADE.b, 0.40 * t))
	ci.draw_arc(centre, radius, 0.0, TAU, 96, Color(Ledger.PAPER.r, Ledger.PAPER.g, Ledger.PAPER.b, 0.10 * t), 1.5, true)


## One paper tag. `lift` 0..1 raises it (a bigger, softer shadow, a few px up) — the hover; there is no colour change.
static func tag(ci: CanvasItem, pos: Vector2, rad: float, seed_value: int, lift: float, t: float, tint: Color = Ledger.PAPER_SLIP) -> void:
	var c := pos + Vector2(0, -lift * 4.0)
	var pts := disc_points(rad, seed_value)
	var d := 3.0 + lift * 4.0
	ci.draw_colored_polygon(_moved(pts, c + Vector2(d * 0.6, d + 1.0)), Color(0, 0, 0, 0.20 * t))
	ci.draw_colored_polygon(_moved(pts, c + Vector2(d * 0.3, d * 0.55)), Color(0, 0, 0, 0.30 * t))
	var base := Color(tint.r, tint.g, tint.b, t)
	ci.draw_polygon(_moved(pts, c), Ledger.lit(_moved(pts, Vector2(rad, rad)), Vector2(rad * 2.0, rad * 2.0), base, 0.9))
	var closed := _moved(pts, c)
	closed.append(closed[0])
	ci.draw_polyline(closed, Color(tint.r * 0.62, tint.g * 0.62, tint.b * 0.62, t), 1.0)
	ci.draw_arc(c, rad * 0.9, 0.0, TAU, 40, Color(Ledger.INK_SOFT.r, Ledger.INK_SOFT.g, Ledger.INK_SOFT.b, 0.28 * t), 1.0, true)          # the stock's printed ring


## A circle drawn with a pen: not closed exactly (the pen overshoots and the end sits a little outside the start), never a perfect radius.
static func pen_circle(ci: CanvasItem, centre: Vector2, rad: float, col: Color, seed_value: int, width: float = 2.2) -> void:
	var pts := PackedVector2Array()
	var start := hash01(float(seed_value), 3.0) * TAU
	var n := 36
	for i in range(n + 1):
		var u := float(i) / float(n)
		var ang := start + TAU * 1.06 * u
		var r := rad + 2.2 * u + (hash01(float(i), float(seed_value) + 1.0) - 0.5) * 1.4
		pts.append(centre + Vector2(cos(ang), sin(ang)) * r)
	ci.draw_polyline(pts, col, width, true)


## A pencilled outline of a place where something was: short dashes round a circle.
static func dashed(ci: CanvasItem, centre: Vector2, rad: float, col: Color, width: float = 1.5) -> void:
	for k in range(14):
		var a0 := TAU * float(k) / 14.0
		ci.draw_arc(centre, rad, a0, a0 + TAU / 14.0 * 0.56, 6, col, width, true)


## A slip of paper (rect in the caller's coordinates): a wandering outline, the shadow it throws, optionally a strip of tape. The outline is cached by size + seed.
static func slip(ci: CanvasItem, rect: Rect2, seed_value: int, tint: Color = Ledger.PAPER_SLIP, taped: bool = true, alpha: float = 1.0) -> void:
	var key := "%d_%d_%d" % [int(rect.size.x), int(rect.size.y), seed_value]
	var out: PackedVector2Array = _slip_cache.get(key, PackedVector2Array())
	if out.size() < 3:
		out = Ledger.ragged(rect.size.x, rect.size.y, 26.0, 1.3, seed_value)
		_slip_cache[key] = out
	var o := _moved(out, rect.position)
	ci.draw_colored_polygon(_moved(o, Vector2(3, 5)), Color(0, 0, 0, 0.18 * alpha))
	ci.draw_colored_polygon(_moved(o, Vector2(1.5, 2.5)), Color(0, 0, 0, 0.26 * alpha))
	ci.draw_polygon(o, Ledger.lit(out, rect.size, Color(tint.r, tint.g, tint.b, alpha), 0.9))
	var closed := PackedVector2Array(o)
	closed.append(o[0])
	ci.draw_polyline(closed, Color(tint.r * 0.64, tint.g * 0.64, tint.b * 0.64, alpha), 1.0)
	if taped:
		ci.draw_set_transform(Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 1.0), -0.03 + 0.06 * hash01(float(seed_value), 5.0), Vector2.ONE)
		ci.draw_rect(Rect2(-17, -4, 34, 12), Color(0, 0, 0, 0.12 * alpha))
		ci.draw_rect(Rect2(-18, -6, 34, 12), Color(Ledger.TAPE.r, Ledger.TAPE.g, Ledger.TAPE.b, Ledger.TAPE.a * alpha))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The biggest font size (<= px) at which `s` fits in `width`.
static func fit(font: Font, s: String, px: int, width: float) -> int:
	var size := px
	while size > 8 and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size


## Text on paper, centred in `width` starting at `left`, shrunk to fit. `kind` = head / body / typed / hand.
static func text(ci: CanvasItem, kind: String, baseline: Vector2, s: String, px: int, col: Color, width: float, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var font: Font = Ledger.font(kind)
	var size := fit(font, s, int(round(px * (Ledger.hand_scale() if kind == "hand" else 1.0))), width)
	ci.draw_string(font, baseline, s, align, width, size, col)


## The slip in the middle of a ring. `lines`: [{kind, text, px, col}] (a line of text) or [{row: true, label, value, delta, tone}] (a stat: the label soft, the value in ink, the
## mark in the player's hand — green when it is better, red when worse). Returns the slip's rect.
static func card(ci: CanvasItem, centre: Vector2, lines: Array, seed_value: int, tint: Color = Ledger.PAPER_SLIP, w: float = 124.0, alpha: float = 1.0) -> Rect2:
	var h := 18.0
	for l in lines:
		h += 14.0 if l.get("row", false) else float(l.get("px", 12)) + 5.0
	var rect := Rect2(centre - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
	slip(ci, rect, seed_value, tint, true, alpha)
	var y := rect.position.y + 12.0
	for l in lines:
		if l.get("row", false):
			var base := Vector2(rect.position.x + 9.0, y + 11.0)
			text(ci, "body", base, String(l["label"]), 11, Ledger.INK_SOFT, 50.0, HORIZONTAL_ALIGNMENT_LEFT)
			text(ci, "body", base + Vector2(48.0, 0), String(l["value"]), 11, Ledger.INK, 34.0, HORIZONTAL_ALIGNMENT_LEFT)
			if String(l.get("delta", "")) != "":
				var tone := int(l.get("tone", 0))
				var col: Color = Ledger.GREEN_INK if tone > 0 else (Ledger.RED_INK if tone < 0 else Ledger.INK_SOFT)
				text(ci, "hand", Vector2(rect.position.x + w - 46.0, base.y), String(l["delta"]), 11, col, 38.0, HORIZONTAL_ALIGNMENT_RIGHT)
			y += 14.0
		else:
			var px: int = int(l.get("px", 12))
			text(ci, String(l.get("kind", "body")), Vector2(rect.position.x + 8.0, y + px * 0.86), String(l["text"]), px, l.get("col", Ledger.INK), w - 16.0)
			y += float(px) + 5.0
	return rect


## A label slip under a tag or over a ring: one line on a short strip of paper (`bounds_x` > 0 keeps it inside a screen that wide).
static func plate(ci: CanvasItem, kind: String, centre: Vector2, s: String, px: int, col: Color, seed_value: int, taped: bool = false, alpha: float = 1.0, max_w: float = 520.0, bounds_x: float = -1.0) -> Rect2:
	var font: Font = Ledger.font(kind)
	var size := int(round(px * (Ledger.hand_scale() if kind == "hand" else 1.0)))
	var w := minf(font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 22.0, max_w)
	var h := float(size) + 9.0
	if bounds_x > 0.0:                                                          # never run off the screen's edge
		centre.x = clampf(centre.x, w * 0.5 + 4.0, bounds_x - w * 0.5 - 4.0)
	var rect := Rect2(centre - Vector2(w * 0.5, 0.0), Vector2(w, h))
	slip(ci, rect, seed_value, Ledger.PAPER_SLIP, taped, alpha)
	var fs := fit(font, s, size, w - 14.0)
	ci.draw_string(font, Vector2(rect.position.x + 7.0, rect.position.y + h - 6.0), s, HORIZONTAL_ALIGNMENT_CENTER, w - 14.0, fs, Color(col.r, col.g, col.b, col.a * alpha))
	return rect


## A padlock in ink (the locked slot).
static func padlock(ci: CanvasItem, pos: Vector2, col: Color) -> void:
	ci.draw_arc(pos + Vector2(0, -3), 6.0, PI, TAU, 16, col, 2.5, true)
	ci.draw_rect(Rect2(pos + Vector2(-8, -3), Vector2(16, 12)), col)
	ci.draw_circle(pos + Vector2(0, 2), 1.8, Color(Ledger.PAPER.r, Ledger.PAPER.g, Ledger.PAPER.b, 0.9))


## A gauge: a ruled hairline with a pen stroke along it for how much is left (green ink while there is plenty, red when it is nearly gone).
static func gauge(ci: CanvasItem, left: Vector2, width: float, ratio: float, seed_value: int) -> void:
	ci.draw_line(left, left + Vector2(width, 0), Color(Ledger.INK.r, Ledger.INK.g, Ledger.INK.b, 0.30), 1.0)
	var col: Color = Ledger.GREEN_INK if ratio > 0.3 else Ledger.RED_INK
	ci.draw_polyline(Ledger.pen_line(left, left + Vector2(maxf(width * ratio, 2.0), 0), seed_value, 0.5), col, 2.4, true)
