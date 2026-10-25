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
##   * the journal, the merchant and the workbench stay paper (scripts/ledger.gd) — those are places to sit and read; this is the glance-and-go layer that sits over the live game;
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
			text(ci, "label", rect.position + Vector2(0, rect.size.y * 0.5 + 5.0), str(num), 14, fade(DIM, 0.5 * t), rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var c := (rect.position + rect.size * 0.5).round()
	var tex: Texture2D = ItemData.get_texture(inst.item_id)
	if tex != null:
		var broken: bool = inst.is_depleted and inst.get_max_durability() > 0
		ci.draw_texture_rect(tex, Rect2(c - Vector2(SLOT_ICON, SLOT_ICON) * 0.5, Vector2(SLOT_ICON, SLOT_ICON)), false, Color(0.55, 0.42, 0.42, t) if broken else Color(1, 1, 1, t))
	if num > 0:
		text(ci, "label", rect.position + Vector2(5.0, 12.0), str(num), 11, fade(DIM, t), 16.0)
	var max_d: int = inst.get_max_durability()
	if max_d > 1 and not inst.is_depleted:
		var ratio := clampf(float(inst.current_durability) / float(max_d), 0.0, 1.0)
		var bar := Rect2(rect.position.x + 8.0, rect.end.y - 5.0, rect.size.x - 16.0, 3.0)
		ci.draw_rect(bar, fade(EDGE_DIM, t))
		ci.draw_rect(Rect2(bar.position, Vector2(maxf(bar.size.x * ratio, 2.0), bar.size.y)), fade(GREEN if ratio > 0.5 else (BRASS if ratio > 0.25 else RED), t))
	if inst.count > 1:
		var s := "x%d" % inst.count
		var w := font("head").get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 8.0
		var pill := Rect2(rect.end.x - w - 3.0, rect.end.y - 21.0, w, 15.0)
		ci.draw_rect(pill, Color(WELL.r, WELL.g, WELL.b, 0.86 * t))
		text(ci, "head", Vector2(pill.position.x + 4.0, pill.end.y - 3.0), s, 14, fade(TEXT, t), w)
	if held:
		brackets(ci, rect, fade(accent, t), 9.0, 3.0, ALL, 1.0)
		tab(ci, Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y - 1.0), "HELD", accent, t)
	elif plan >= 0:
		brackets(ci, rect, fade(mark, t), 9.0, 3.0, ALL, 1.0)


## A small solid tab with one word on it, centred on `at` (the in-hand mark on a slot; the board's IN HAND).
static func tab(ci: CanvasItem, at: Vector2, word: String, fill: Color, t: float = 1.0) -> Rect2:
	var f := font("label")
	var w := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12.0
	var r := Rect2(at - Vector2(w * 0.5, 7.0), Vector2(w, 14.0))
	ci.draw_rect(r, fade(fill, t))
	text(ci, "label", Vector2(r.position.x + 1.0, r.end.y - 3.0), word, 11, fade(ON_BRASS, t), w, HORIZONTAL_ALIGNMENT_CENTER)
	return r


# ---------------------------------------------------------------------------------------------------------------------------------- the card in the middle
const ROW_H := 17.0

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
	text(ci, "body", Vector2(x, base), String(r["label"]), int(round(float(big) * 0.72)), fade(SOFT, t), label_w)
	text(ci, "head", Vector2(x + label_w, base), String(r["text"]), big, fade(TEXT, t), 44.0 * k)
	var d: String = String(r.get("delta", ""))
	if d == "":
		return
	var tone := int(r.get("tone", 0))
	var col: Color = GREEN if tone > 0 else (RED if tone < 0 else DIM)
	var f := font("head")
	var num: String = d.substr(1).strip_edges()                    # "▲ +18" -> "+18"
	var nw := f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, big - 1).x
	ci.draw_string(f, Vector2(x + w - nw, base), num, HORIZONTAL_ALIGNMENT_LEFT, nw + 2.0, big - 1, fade(col, t))
	arrow(ci, Vector2(x + w - nw - 3.0 - 3.5 * k, base - 4.0 * k - 1.0), d.begins_with("▲"), fade(col, t), 3.5 * k)


## The info card in the middle of a ring (and the heart of any small readout). `info_size` is its size for `lines` (pure); `info` draws it, centred. `lines`:
##   {"title": s, "col"?}   the item's name, the bright head face        {"word": s, "col"?}  one letter-spaced caption word (CRAFT, LOCKED…)
##   {"big": s, "col"?}     one large word (DROP)                         {"note": s, "col"?}  a short plain line
##   {"row": true, label, text, delta, tone}   a stat row
## Returns its rect. A card with a stat row is wider so the row has room.
static func info_size(lines: Array) -> Vector2:
	var has_rows := false
	var h := 20.0
	for l in lines:
		if l.has("row"):
			has_rows = true
			h += ROW_H
		elif l.has("big"):
			h += 28.0
		elif l.has("title"):
			h += 24.0
		elif l.has("word"):
			h += 17.0
		else:
			h += 16.0
	return Vector2(140.0 if has_rows else 116.0, h)


static func info(ci: CanvasItem, centre: Vector2, lines: Array, t: float = 1.0, accent: Color = BRASS) -> Rect2:
	var sz := info_size(lines)
	var w := sz.x
	var rect := Rect2((centre - sz * 0.5).round(), sz)
	panel(ci, rect, t, TL | BR, 11.0, accent, EDGE)
	var y := rect.position.y + 10.0
	var inner := w - 20.0
	for l in lines:
		if l.has("row"):
			row(ci, rect.position.x + 10.0, y, inner, l, t, 42.0, 15)
			y += ROW_H
		elif l.has("big"):
			text(ci, "head", Vector2(rect.position.x + 10.0, y + 22.0), String(l["big"]), 26, fade(l.get("col", TEXT), t), inner, HORIZONTAL_ALIGNMENT_CENTER)
			y += 28.0
		elif l.has("title"):
			text(ci, "head", Vector2(rect.position.x + 10.0, y + 18.0), String(l["title"]), 20, fade(l.get("col", TEXT), t), inner, HORIZONTAL_ALIGNMENT_CENTER)
			y += 24.0
		elif l.has("word"):
			text(ci, "label", Vector2(rect.position.x + 10.0, y + 12.0), String(l["word"]), 12, fade(l.get("col", LABEL), t), inner, HORIZONTAL_ALIGNMENT_CENTER)
			y += 17.0
		else:
			text(ci, "body", Vector2(rect.position.x + 10.0, y + 12.0), String(l["note"]), 12, fade(l.get("col", SOFT), t), inner, HORIZONTAL_ALIGNMENT_CENTER)
			y += 16.0
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
		text(ci, "label", Vector2(pos.x + 12.0, y + row_h - 6.0), String(rows[i][0]).to_upper(), 13, col, w - 24.0)


## What the middle of a ring says about an item under the pointer: its name, then the few numbers that matter — a weapon's (set against the one in hand when it is another weapon:
## the rows that differ come first), a single short line for anything else, one word when it is broken. Both rings read this, so a thing reads the same on either.
static func item_lines(inst) -> Array:
	var tip: Dictionary = HUD.item_tip_content(inst)
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
		return wk.to_upper()
	for pair in [["is_key", "KEY"], ["is_ammo", "AMMO"], ["is_money", "CASH"], ["is_scrap", "SCRAP"], ["is_molotov", "FIRE"], ["is_throwable", "THROWN"],
			["is_health_item", "MEDICAL"], ["is_speed_boost", "MEDICAL"], ["is_junk", "JUNK"], ["is_extinguisher", "TOOL"], ["is_tool", "TOOL"], ["is_fuse", "TOOL"]]:
		if d.get(pair[0], false):
			return String(pair[1])
	return "FOUND"
