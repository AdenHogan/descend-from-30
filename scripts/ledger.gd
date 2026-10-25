class_name Ledger
extends RefCounted

## THE LEDGER — the look the menus that act on the world share (owner round 48j: "I quite like the ledger look as it ties together with the Player detail UI… the appropriate amount of
## UX design… lighting, sound effects… good, clean, connected, and strong. We don't want it to look like AI slop").
##
## It is paper, ink and a desk, because that is what the journal already is (character_panel.gd's _Paper kit). The rules that keep it from being a stock "fantasy UI":
##   * every effect has a physical reason — a slip is taped, a stamp is pressed, a line is written with a pen, a sheet has a shadow because it lies on something;
##   * nothing glows. Light is the paper's own shading and the dark of the desk round it; hover is a slip LIFTING (a bigger, softer shadow), not a halo;
##   * no stock icon set, no gradient fills on rectangles, no rounded "cards" — edges wander a little, seeded, so a sheet always looks the same and no two look alike;
##   * type is a real mix: printed heads (Barlow Condensed — the logo's), a plain body (Barlow), a typed voice (Special Elite — the merchant's receipts), and the PLAYER'S OWN HAND
##     (the same face and ink the journal writes in) for what the player does: their notes, their choices;
##   * sound is what the thing would sound like on a desk (tools/gen_ui_audio.py): paper, pencil, rubber stamp, pen, tape, banknotes, a knuckle — quiet, varied, never a UI "blip".
## This file is the one place the palette, the fonts, the sounds and the paper outline live; ledger_sheet / ledger_slip / ledger_stamp / ledger_button draw with them.

const PAPER := Color(0.91, 0.86, 0.72)
const PAPER_LIGHT := Color(0.96, 0.92, 0.80)
const PAPER_SLIP := Color(0.95, 0.91, 0.79)
const INK := Color(0.15, 0.11, 0.08)
const INK_SOFT := Color(0.38, 0.30, 0.21)
const INK_FAINT := Color(0.52, 0.44, 0.32)
const RULE := Color(0.30, 0.38, 0.52, 0.26)
const MARGIN_RULE := Color(0.62, 0.20, 0.17, 0.46)
const STAMP_RED := Color(0.60, 0.12, 0.10)
const PENCIL := Color(0.30, 0.30, 0.33)
const TAPE := Color(0.82, 0.74, 0.50, 0.78)
const DESK := Color(0.05, 0.035, 0.028)
const BLUE_INK := Color(0.16, 0.30, 0.50)
const RED_INK := Color(0.54, 0.15, 0.12)
const GOLD_INK := Color(0.50, 0.34, 0.07)
const GREEN_INK := Color(0.20, 0.38, 0.20)

const FONT_HEAD := "res://assets/fonts/logo/BarlowCondensed-Bold.ttf"
const FONT_BODY := "res://assets/fonts/ledger/Barlow-Regular.ttf"
const FONT_TYPED := "res://assets/fonts/ledger/SpecialElite-Regular.ttf"
const SOUND_DIR := "res://assets/audio/ui/"
const SOUNDS := {"sheet": 2, "page": 2, "tick": 3, "stamp": 2, "pen": 2, "tape": 1, "notes": 2, "deny": 1}

static var _fonts: Dictionary = {}
static var _streams: Dictionary = {}
static var _last_play: Dictionary = {}
static var muted: bool = false          # tests / captures can silence it


# ---------------------------------------------------------------------------------------------------------------------------------- fonts
static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f: Font = null
	match kind:
		"head":
			var v := FontVariation.new()
			v.base_font = load(FONT_HEAD)
			v.spacing_glyph = 1
			f = v
		"body":
			f = load(FONT_BODY)
		"typed":
			f = load(FONT_TYPED)
		"hand":
			f = load(hand_info().get("path", "res://assets/fonts/hand/PatrickHand.ttf"))
		_:
			f = ThemeDB.fallback_font
	if f == null:
		f = ThemeDB.fallback_font
	if kind != "hand":
		_fonts[kind] = f                  # the hand follows the run's character (the cast changes between runs), so it is never cached
	return f


## The run's character writes in their own hand — the face, size scale and ink the journal uses for them (character_panel.gd HAND).
static func hand_info() -> Dictionary:
	var table: Dictionary = load("res://scripts/character_panel.gd").HAND      # a load(), not a preload: world_drop -> ItemCompare -> Ledger -> character_panel -> ... would be a compile cycle (an enemy's loot drop came back a null scene)
	var cid := "blond_man"
	if Engine.get_main_loop() != null and WorldState != null and WorldState.has_method("current_character"):
		cid = String(WorldState.current_character())
	return table.get(cid, table["blond_man"])


static func hand_ink() -> Color:
	return hand_info().get("ink", BLUE_INK)


static func hand_scale() -> float:
	return float(hand_info().get("scale", 1.0))


# ---------------------------------------------------------------------------------------------------------------------------------- sound
## Play one of the desk sounds (`name` = a key of SOUNDS). Varied (a different take, a hair of pitch) so it never machine-guns; `min_gap` throttles the quiet ones.
static func play(sound: String, volume_db: float = -8.0, min_gap: float = 0.0) -> void:
	if muted or not SOUNDS.has(sound):
		return
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if min_gap > 0.0 and now - float(_last_play.get(sound, -9.0)) < min_gap:
		return
	_last_play[sound] = now
	var k := randi() % int(SOUNDS[sound])
	var path := "%s%s_%d.wav" % [SOUND_DIR, sound, k]
	var stream: AudioStream = _streams.get(path)
	if stream == null:
		if not ResourceLoader.exists(path):
			return
		stream = load(path)
		_streams[path] = stream
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-0.04, 0.04)
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.add_to_group("ledger_sfx")
	p.autoplay = true                                           # plays the moment it is in the tree — safe to call while a scene is still being set up
	p.finished.connect(p.queue_free)
	loop.root.add_child.call_deferred(p)


# ---------------------------------------------------------------------------------------------------------------------------------- paper
## A rectangle whose edges wander (every point stays INSIDE the rect, so the outline is the paper's, never past it). `amp` = how far, `step` = how often. Pure function of the seed.
static func ragged(w: float, h: float, step: float, amp: float, seed_value: int, top_amp: float = -1.0) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed_value) + 1
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
	if Geometry2D.triangulate_polygon(pts).is_empty():                       # never hand the renderer an outline it cannot fill
		return PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
	return pts


static func shifted(p: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var o := PackedVector2Array()
	for v in p:
		o.append(v + d)
	return o


## Paper under a lamp: each vertex takes a tone by where it is — brighter toward the upper left (where the lamp is), a touch dim toward the lower right. No glow, just where the light falls.
static func lit(points: PackedVector2Array, size: Vector2, base: Color, strength: float = 1.0) -> PackedColorArray:
	var cols := PackedColorArray()
	for v in points:
		var t := clampf((v.x / maxf(size.x, 1.0) * 0.55 + v.y / maxf(size.y, 1.0) * 0.45), 0.0, 1.0)
		var f := (1.04 - 0.13 * t) * strength + (1.0 - strength)
		cols.append(Color(minf(base.r * f, 1.0), minf(base.g * f, 1.0), minf(base.b * f, 1.0), base.a))
	return cols


## A wobbling pen line from a to b (never a ruler's): `wobble` px of drift, a few points.
static func pen_line(a: Vector2, b: Vector2, seed_value: int, wobble: float = 1.2) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed_value) + 7
	var pts := PackedVector2Array()
	var n := maxi(3, int(a.distance_to(b) / 14.0))
	for i in range(n + 1):
		var t := float(i) / float(n)
		pts.append(a.lerp(b, t) + Vector2(0, rng.randf_range(-wobble, wobble)))
	return pts


# ---------------------------------------------------------------------------------------------------------------------------------- small factories
## A label in one of the ledger's faces. `kind` = head / body / typed / hand.
static func label(text: String, kind: String, px: int, colour: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", int(round(px * (hand_scale() if kind == "hand" else 1.0))))
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Style an existing Label (the shop's labels were created plain; the ledger re-fonts them without changing what they say).
static func style(l: Label, kind: String, px: int, colour: Color) -> void:
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", int(round(px * (hand_scale() if kind == "hand" else 1.0))))
	l.add_theme_color_override("font_color", colour)
