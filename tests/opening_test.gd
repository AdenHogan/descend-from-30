extends Node

# THE NEW-GAME / LOAD / RUN-START OPENING (owner round 35 + 35b): the exterior shot a run begins on — the tower in that run's light
# (morning / dusk / night, more of the city and the building ruined each time), the camera climbing it floor by floor to the roof and
# the sky, the title over the clouds (a new game or a load; a later run's cold open has none) — since round 48n the title is the LOGO,
# its lettering fading in first and the bloody handprint behind it a beat later — a fade to black, then the run's time
# card. The burnt floors are THIS playthrough's own fire. Locks: the art + its meta exist for all three runs and agree; the looks
# really differ (and escalate); the timeline (a pure function of t) fades in, climbs monotonically, brings the title up late, fades
# out — and a title-less cut is shorter; the layers are anchored so the street is on screen at the start and the roof sits under the
# title at the end; clouds dress the sky; the burn plan IS the fire sim and lays the windows; the overlay plays it as stage "exterior"
# and hands on to the card; a key hurries it (never cuts); a load plays it standalone; the old black title screen is still the
# fallback; sounds exist. Run: godot --headless res://tests/opening_test.tscn

const Ext := preload("res://scripts/opening_exterior.gd")
const IntroScript := preload("res://scripts/intro_overlay.gd")
const Seq := preload("res://scripts/opening_sequence.gd")

var failures: int = 0
var _seq_done := false


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== opening test ===")
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_test_art()
	_test_looks()
	_test_timeline()
	await _test_layers()
	await _test_logo_title()
	await _test_survivors()
	await _test_runner()
	await _test_night_storm()
	_test_help_sheets()
	_test_garden_plan()
	await _test_depth_and_weather()
	await _test_runs()
	await _test_burning()
	await _test_overlay_flow()
	await _test_hurry()
	await _test_load_sequence()
	await _test_fallback()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _meta(run: int) -> Dictionary:
	var m = JSON.parse_string(FileAccess.get_file_as_string("%sopening_meta_%d.json" % [Ext.DIR, run]))
	return m if m is Dictionary else {}


func _mean_lum(tex: Texture2D) -> float:
	var img: Image = tex.get_image()
	var sum := 0.0
	var n := 0
	for y in range(0, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				sum += 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
				n += 1
	return sum / maxf(1.0, float(n))


func _test_art() -> void:
	print("[art — three runs]")
	var want := {"sky": Vector2i(288, 330), "far": Vector2i(288, 230), "mid": Vector2i(288, 300),
		"scene": Vector2i(288, 526), "garden": Vector2i(288, 526), "fore": Vector2i(288, 200)}
	for run in [1, 2, 3]:
		check(Ext.art_present(run), "run %d: every layer + the meta are in assets/opening/" % run)
		for f in want:
			var tex = load("%s%s_%d.png" % [Ext.DIR, f, run])
			check(tex is Texture2D and Vector2i(tex.get_width(), tex.get_height()) == want[f], "run %d %s is the drawn size %s" % [run, f, str(want[f])])
		var m := _meta(run)
		check(m.has("layers") and m.has("clouds") and m.has("scene") and m.has("burn") and int(m.get("run", 0)) == run,
			"run %d: the meta lists layers, clouds, the scene's details and the burn sheet" % run)
		var L: Dictionary = m.get("layers", {})
		for k in ["sky", "far", "mid", "scene", "garden", "fore"]:
			check(L.has(k) and float(L[k]["h"]) > 0.0, "run %d layer %s has a parallax + height" % [run, k])
		check(float(L["sky"]["p"]) < float(L["far"]["p"]) and float(L["far"]["p"]) < float(L["mid"]["p"])
			and float(L["mid"]["p"]) < float(L["scene"]["p"]) and float(L["scene"]["p"]) < float(L["garden"]["p"]) and float(L["garden"]["p"]) < float(L["fore"]["p"]),
			"run %d: parallax grows toward the viewer (sky < far < mid < building < garden < foreground wires)" % run)
		check(float(m["scroll"]) > 300.0, "run %d: a real climb (%d px)" % [run, int(m["scroll"])])
		check(m["scene"]["lit"].size() >= 4, "run %d: a few lamps are on (%d)" % [run, m["scene"]["lit"].size()])
		var floor30 := false
		for w in m["scene"]["lit"]:
			if int(w["floor"]) == 30:
				floor30 = true
		check(floor30, "run %d: …including a warm window on floor 30, where you wake" % run)
		var g: Dictionary = m["scene"]["grid"]
		check(int(g["bays"]) == 8 and int(g["floor_h"]) == 14 and int(g["floor0_y"]) == 30, "run %d: the window grid the burn overlay needs" % run)
	check(load(Ext.DIR + "burn.png") is Texture2D, "the burn sheet (charred windows + soot)")
	var bm: Dictionary = _meta(1)["burn"]
	check(bm["char"].size() >= 3 and bm["soot"].size() >= 3, "…with %d charred windows and %d soot streaks" % [bm["char"].size(), bm["soot"].size()])
	for f in ["hum.wav", "siren.wav", "swell.wav"]:
		check(load(Ext.AUDIO_DIR + f) is AudioStream, "sound %s" % f)


func _test_looks() -> void:
	print("[three looks, escalating]")
	var lum: Array = []
	var sc_lum: Array = []
	for run in [1, 2, 3]:
		lum.append(_mean_lum(load("%ssky_%d.png" % [Ext.DIR, run])))
		sc_lum.append(_mean_lum(load("%sscene_%d.png" % [Ext.DIR, run])))
	check(lum[0] > lum[1] and lum[1] > lum[2], "the sky darkens run by run (%.2f > %.2f > %.2f)" % [lum[0], lum[1], lum[2]])
	check(sc_lum[0] > sc_lum[1] and sc_lum[1] > sc_lum[2], "…and so does the street (%.2f > %.2f > %.2f)" % [sc_lum[0], sc_lum[1], sc_lum[2]])
	var m1 := _meta(1)
	var m2 := _meta(2)
	var m3 := _meta(3)
	check(m1["garden"]["fires"].size() == 0 and m2["garden"]["fires"].size() >= 1 and m3["garden"]["fires"].size() > m2["garden"]["fires"].size(),
		"fires in the garden: none, some, more (%d / %d / %d)" % [m1["garden"]["fires"].size(), m2["garden"]["fires"].size(), m3["garden"]["fires"].size()])
	check(m1["scene"]["helps"].size() == 0 and m2["scene"]["helps"].size() >= 1 and m3["scene"]["helps"].size() > m2["scene"]["helps"].size(),
		"HELP / SOS sheets hang out of windows only from the afternoon: none, some, more (%d / %d / %d)" % [m1["scene"]["helps"].size(), m2["scene"]["helps"].size(), m3["scene"]["helps"].size()])
	check(int(m1["look"]["city_smokes"][0]) == 0 and int(m1["look"]["city_smokes"][1]) == 0 and int(m2["look"]["city_smokes"][0]) > 0,
		"…and so do the smoke columns over the city %s / %s" % [str(m1["look"]["city_smokes"]), str(m2["look"]["city_smokes"])])
	# the ground is a GARDEN (owner round 36h: "get rid of the road… trees… a cat… a human running in fear… bodies everywhere at night")
	for run in [1, 2, 3]:
		var gm: Dictionary = _meta(run)["garden"]
		check(not gm.has("cars") and gm["trees"].size() >= 5, "run %d: no cars, no road — %d trees in the garden" % [run, gm["trees"].size()])
	var b1: int = _meta(1)["garden"]["bodies"].size()
	var b2: int = _meta(2)["garden"]["bodies"].size()
	var b3: int = _meta(3)["garden"]["bodies"].size()
	check(b1 == 0 and b2 >= 1 and b3 >= 8 and b3 > b2, "bodies on the ground: none by morning, one by the afternoon, everywhere at night (%d / %d / %d)" % [b1, b2, b3])
	check(String(_meta(1)["garden"]["runner"]["kind"]) == "cat" and String(_meta(2)["garden"]["runner"]["kind"]) == "human" and String(_meta(3)["garden"]["runner"]["kind"]) == "",
		"a black cat crosses the lawn in the morning, a person flees in the afternoon, no one runs at night")
	var road_row: Image = (load(Ext.DIR + "garden_1.png") as Texture2D).get_image()
	var grey := 0
	for x in range(0, 288, 2):
		var px := road_row.get_pixel(x, 515)
		if absf(px.r - px.g) < 0.04 and absf(px.g - px.b) < 0.06 and px.r < 0.4:
			grey += 1
	check(grey < 10, "the ground below the building is not asphalt (%d grey road pixels on a row)" % grey)
	var cf := [int(m1["look"]["city_fires"]), int(m2["look"]["city_fires"]), int(m3["look"]["city_fires"])]
	check(cf[0] == 0 and cf[1] > 0 and cf[2] > cf[1], "towers burning in the city: none, some, more %s" % str(cf))
	check(not bool(m1["look"]["rain"]) and not bool(m2["look"]["rain"]) and bool(m3["look"]["rain"]), "rain and storm only at night")
	# the SAME building: a window's silhouette (its alpha) is identical in every run — the damage grows, the building doesn't move
	var a1: Image = (load(Ext.DIR + "scene_1.png") as Texture2D).get_image()
	var a3: Image = (load(Ext.DIR + "scene_3.png") as Texture2D).get_image()
	var same := 0
	var total := 0
	for y in range(30, 440, 2):
		for x in range(80, 208, 2):
			total += 1
			if (a1.get_pixel(x, y).a > 0.5) == (a3.get_pixel(x, y).a > 0.5):
				same += 1
	check(float(same) / float(total) > 0.995, "the tower is the same tower in every run (%.1f%% of its face agrees)" % (100.0 * same / total))
	var differ := 0
	for y in range(30, 440, 3):
		for x in range(80, 208, 3):
			if a1.get_pixel(x, y).is_equal_approx(a3.get_pixel(x, y)):
				continue
			differ += 1
	check(differ > 1500, "…but it reads differently (%d sampled pixels changed)" % differ)


func _test_timeline() -> void:
	print("[timeline]")
	for wt in [true, false]:
		var tag := "title" if wt else "no title"
		check(Ext.black_alpha(0.0, wt) == 1.0, "(%s) starts on black" % tag)
		check(Ext.black_alpha(Ext.T_FADE_IN, wt) == 0.0, "(%s) the picture is fully up after the fade in" % tag)
		check(Ext.black_alpha(Ext.t_out(wt) - 0.01, wt) == 0.0, "(%s) …and stays clear to the end of the hold" % tag)
		check(is_equal_approx(Ext.black_alpha(Ext.t_end(wt), wt), 1.0), "(%s) ends on black, ready for the time card" % tag)
		check(Ext.pan_u(0.0, wt) == 0.0 and Ext.pan_u(Ext.t_pan0(), wt) == 0.0, "(%s) the street is held still before the climb" % tag)
		check(is_equal_approx(Ext.pan_u(Ext.t_pan_end(wt), wt), 1.0), "(%s) the climb arrives at the roof" % tag)
		var last := -1.0
		var mono := true
		var tt := 0.0
		while tt <= Ext.t_end(wt):
			var u := Ext.pan_u(tt, wt)
			if u < last - 0.000001:
				mono = false
			last = u
			tt += 0.05
		check(mono, "(%s) the camera only ever climbs" % tag)
		check(is_equal_approx(Ext.pan_u(Ext.t_pan0() + Ext.pan_len(wt) * 0.5, wt), 0.5), "(%s) ease in-out: halfway through the time is halfway up" % tag)
		check(Ext.pan_u(Ext.t_pan0() + 0.5, wt) < 0.01, "(%s) it sets off gently" % tag)
	check(Ext.title_alpha(Ext.t_title_in(true) - 0.1, true) == 0.0, "no title while the building is still filling the screen")
	check(Ext.t_title_in(true) > Ext.t_pan0() + Ext.T_PAN * 0.6 and Ext.t_title_in(true) < Ext.t_pan_end(true), "the title comes up late in the climb")
	check(Ext.title_alpha(Ext.t_pan_end(true), true) == 1.0, "the title is up when the camera arrives at the roof")
	check(Ext.title_visible(Ext.t_end(true), true) == 0.0, "the title leaves with the fade to black")
	check(Ext.title_alpha(Ext.t_pan_end(false), false) == 0.0 and Ext.title_visible(5.0, false) == 0.0, "a cut with no title never shows one")
	# the title is the LOGO in two layers (owner round 48n: "fade in text first, then fade in the hand behind it")
	var order_ok := true
	var rising := true
	var last_w := 0.0
	var last_h := 0.0
	var ts: float = Ext.t_title_in(true) - 1.0
	while ts < Ext.t_pan_end(true) + 1.0:
		var wa: float = Ext.text_alpha(ts, true)
		var ha: float = Ext.hand_alpha(ts, true)
		if ha > 0.0 and wa < 1.0:
			order_ok = false
		if wa < last_w - 0.000001 or ha < last_h - 0.000001:
			rising = false
		last_w = wa
		last_h = ha
		ts += 0.01
	var shadow_ok := true
	var shadow_lags := true
	ts = Ext.t_title_in(true) - 1.0
	while ts < Ext.t_pan_end(true) + 1.0:
		var wa2: float = Ext.text_alpha(ts, true)
		var sa: float = Ext.shadow_alpha(ts, true)
		if sa > wa2 + 0.000001:
			shadow_ok = false                       # the shadow must never be stronger than the words it holds up
		if wa2 > 0.02 and wa2 < 0.98 and sa >= wa2 - 0.01:
			shadow_lags = false                     # …and while they fade it comes in BEHIND them
		ts += 0.01
	check(shadow_ok and shadow_lags, "the lettering's shadow never leads the words: it comes in behind them (owner: the title flashed black while it faded in)")
	check(Ext.shadow_alpha(Ext.t_title_in(true) - 0.05, true) == 0.0 and Ext.shadow_alpha(Ext.t_hand_in(true), true) == 1.0, "…it is absent before the words and whole once they are up")
	check(order_ok, "the hand only starts once the lettering is fully up (text first, then the hand)")
	check(rising, "…and neither layer ever fades back while the title lands")
	check(Ext.text_alpha(Ext.t_title_in(true) - 0.05, true) == 0.0 and Ext.text_alpha(Ext.t_title_in(true) + Ext.T_TEXT_FADE * 0.5, true) > 0.2
		and Ext.text_alpha(Ext.t_title_in(true) + Ext.T_TEXT_FADE * 0.5, true) < 0.8, "the lettering fades in over %.1f s from the title's start" % Ext.T_TEXT_FADE)
	check(Ext.hand_alpha(Ext.t_hand_in(true) - 0.01, true) == 0.0 and Ext.hand_alpha(Ext.t_hand_in(true) + Ext.T_HAND_FADE * 0.5, true) > 0.2
		and Ext.hand_alpha(Ext.t_hand_in(true) + Ext.T_HAND_FADE * 0.5, true) < 0.8, "the handprint then fades in over %.1f s" % Ext.T_HAND_FADE)
	check(Ext.t_hand_in(true) - (Ext.t_title_in(true) + Ext.T_TEXT_FADE) >= 0.1, "a held beat with only the words on screen")
	check(Ext.t_title_up(true) <= Ext.t_pan_end(true), "the whole logo is up before the camera settles on the roof (%.2f <= %.2f)" % [Ext.t_title_up(true), Ext.t_pan_end(true)])
	check(Ext.text_alpha(5.0, false) == 0.0 and Ext.hand_alpha(Ext.t_pan_end(false) + 1.0, false) == 0.0, "a cut with no title shows neither layer")
	check(Ext.t_end(true) > 12.0 and Ext.t_end(true) < 30.0, "the title cut is %.1f s — long enough to land, short enough to repeat" % Ext.t_end(true))
	check(Ext.t_end(false) < Ext.t_end(true) - 3.0 and Ext.t_end(false) > 8.0, "a later run's cut is shorter (%.1f s)" % Ext.t_end(false))


func _built(title_text := "DESCEND FROM 30", run := 1) -> Control:
	var e: Control = Ext.new()
	e.title_text = title_text
	e.run = run
	add_child(e)
	return e


func _test_layers() -> void:
	print("[layers]")
	var e := _built()
	await get_tree().process_frame
	check(e.load_ok, "the exterior builds")
	if not e.load_ok:
		e.queue_free()
		return
	var S: float = e.scroll
	e.t = 0.0
	e._apply(0.0)
	var scene: Node2D = e.layers["scene"]["node"]
	var sky: Node2D = e.layers["sky"]["node"]
	check(is_equal_approx(scene.position.y, Ext.VIEW_H - 526.0), "start: the street is on screen (the scene's bottom meets the view's)")
	check(is_equal_approx(sky.position.y, Ext.VIEW_H - 330.0), "start: the sky's low end (the sun) is what shows")
	check(float(e.layers["fore"]["node"].position.y) < Ext.VIEW_H, "start: the wire pole stands in the foreground")
	var y0s: float = scene.position.y
	var y0k: float = sky.position.y
	e.t = Ext.t_pan_end()
	e._apply(0.0)
	var dscene: float = scene.position.y - y0s
	var dsky: float = sky.position.y - y0k
	check(is_equal_approx(dscene, S), "the building travels the whole climb (%.0f px)" % dscene)
	check(dsky < dscene * 0.4 and dsky > 0.0, "…the sky only a third of it (parallax %.0f vs %.0f)" % [dsky, dscene])
	var roof_screen: float = scene.position.y + 22.0
	check(roof_screen > 90.0 and roof_screen < 140.0, "at the end the roof's parapet sits low in the frame (y %.0f of 162)" % roof_screen)
	check(sky.position.y + float(e.layers["sky"]["h"]) > Ext.VIEW_H, "…and the sky still fills the view behind it")
	var seen := 0
	for c in e.clouds:
		var sp: Sprite2D = c["node"]
		var sz: Vector2 = sp.texture.get_size()
		if sp.position.y > -sz.y and sp.position.y < roof_screen - 10.0 and sp.position.x > -sz.x and sp.position.x < Ext.VIEW_W:
			seen += 1
	check(seen >= 6, "clouds are in the sky over the roof at the end (%d)" % seen)
	e.t = Ext.t_pan0() + Ext.T_PAN * 0.5
	e._apply(0.0)
	check(scene.position.y > y0s + S * 0.4 and scene.position.y < y0s + S * 0.6, "halfway: the camera is halfway up the tower")
	var cx0: float = e.clouds[0]["node"].position.x
	e.t += 5.0
	e._apply(0.0)
	check(not is_equal_approx(e.clouds[0]["node"].position.x, cx0), "clouds drift across the sky")
	var smokes := e.find_children("*", "AnimatedSprite2D", true, false)
	check(smokes.size() == 0, "the first morning has no smoke or fire anywhere (%d plumes)" % smokes.size())
	check(e.beacons.size() >= 2 and e.flickers.size() >= 1, "beacons blink and a lamp is failing (%d / %d)" % [e.beacons.size(), e.flickers.size()])
	check(e.birds != null, "crows circle the roof")
	e.queue_free()


func _test_logo_title() -> void:
	print("[the title is the logo]")
	var e := _built()
	await get_tree().process_frame
	check(e.load_ok and e.title != null and e.title is Control, "the title is a node of the exterior")
	if not e.load_ok:
		e.queue_free()
		return
	var kids: Array = e.title.get_children()
	var names: Array = []
	var all_sprites := true
	for k in kids:
		names.append(str(k.name))
		if not (k is Sprite2D):
			all_sprites = false
	check(names == ["TitleHand", "TitleShadow", "TitleText"], "behind to front: the handprint, the lettering's shadow, the lettering (%s)" % str(names))
	check(all_sprites, "…only pictures: no panel, no box, no background behind the logo")
	check(e.title_hand.texture.resource_path == Ext.LOGO_HAND and e.title_words.texture.resource_path == Ext.LOGO_TEXT, "the two layers are the logo's own (assets/logo/logo_layer_*)")
	check(e.title_hand.texture.get_size() == e.title_words.texture.get_size() and e.title_shadow.texture == e.title_words.texture,
		"both layers are one canvas, so stacked they ARE the logo (%s)" % str(e.title_words.texture.get_size()))
	check(e.title_shadow.material is ShaderMaterial, "the lettering casts a soft shadow (no panel — cream words would wash into a bright morning sky)")
	var drop_tx: float = float((e.title_shadow.material as ShaderMaterial).get_shader_parameter("drop_texels"))
	check(absf(drop_tx - Ext.SHADOW_DROP / Ext.LOGO_SCALE) < 0.001 and Ext.SHADOW_SHADER_CODE.contains("drop_texels") and Ext.SHADOW_SHADER_CODE.contains("(1.0 - body)"),
		"the shadow is taken out under the solid letters, sampled where they stand (%.1f texels = the %.0f px drop)" % [drop_tx, Ext.SHADOW_DROP])
	# at rest the layers sit on the same spot at the same scale
	e.t = Ext.t_title_up(true) + 0.2
	e._apply(0.0)
	check(e.title_hand.position == e.title_words.position and e.title_hand.scale == e.title_words.scale, "at rest the hand and the lettering are exactly registered")
	check(e.title_words.modulate.a == 1.0 and e.title_hand.modulate.a == 1.0 and e.title.modulate.a == 1.0, "once up, the whole logo is fully visible")
	# the fade-in in the real node
	e.t = 0.5
	e._apply(0.0)
	check(e.title_words.modulate.a == 0.0 and e.title_hand.modulate.a == 0.0, "the opening starts with no title")
	e.t = Ext.t_hand_in(true) - 0.02
	e._apply(0.0)
	check(e.title_words.modulate.a == 1.0 and e.title_hand.modulate.a == 0.0, "words up, the hand not yet")
	e.t = Ext.t_title_in(true) + Ext.T_TEXT_FADE * 0.5
	e._apply(0.0)
	check(e.title_shadow.modulate.a < e.title_words.modulate.a and e.title_words.modulate.a > 0.2 and e.title_words.modulate.a < 0.8
		and e.title_shadow.position == e.title_words.position + Vector2(0.0, Ext.SHADOW_DROP),
		"mid-fade the shadow is fainter than the words (%.2f vs %.2f) and sits its drop below them" % [e.title_shadow.modulate.a, e.title_words.modulate.a])
	e.t = Ext.t_hand_in(true) + T_HALF_HAND()
	e._apply(0.0)
	check(e.title_words.modulate.a == 1.0 and e.title_hand.modulate.a > 0.1 and e.title_hand.modulate.a < 0.9, "then the hand coming up behind them (%.2f)" % e.title_hand.modulate.a)
	e.t = Ext.t_end(true)
	e._apply(0.0)
	check(e.title.modulate.a == 0.0, "the logo leaves with the fade to black")
	# where it sits: on the screen, centred, and clear of the roof's gear at the end of the climb
	var scale: float = Ext.LOGO_SCALE
	var hr: Rect2i = e.title_hand.texture.get_image().get_used_rect()
	var tr: Rect2i = e.title_words.texture.get_image().get_used_rect()
	var ink: Rect2i = hr.merge(tr)
	var half: Vector2 = e.title_words.texture.get_size() * 0.5
	var x0: float = Ext.LOGO_CENTRE.x + (ink.position.x - half.x) * scale
	var x1: float = Ext.LOGO_CENTRE.x + (ink.end.x - half.x) * scale
	var y0: float = Ext.LOGO_CENTRE.y + (ink.position.y - half.y) * scale
	var y1: float = Ext.LOGO_CENTRE.y + (ink.end.y - half.y) * scale
	check(x0 >= 16.0 and x1 <= Ext.VIEW_W * Ext.PIXEL - 16.0 and y0 >= 8.0, "the logo's ink is on the screen (x %.0f..%.0f, y from %.0f)" % [x0, x1, y0])
	check(absf((x0 + x1) * 0.5 - Ext.VIEW_W * Ext.PIXEL * 0.5) <= 12.0, "…centred across it (ink middle %.0f of %.0f)" % [(x0 + x1) * 0.5, Ext.VIEW_W * Ext.PIXEL * 0.5])
	e.t = Ext.t_pan_end(true)
	e._apply(0.0)
	var scene: Node2D = e.layers["scene"]["node"]
	var gear_top: float = (scene.position.y + 22.0 - 22.0) * Ext.PIXEL     # the rooftop's water tank / plant room / mast stand up to ~22 px above the parapet
	check(y1 <= gear_top, "…and its lowest drip stays above the roof's gear at the end of the climb (%.0f <= %.0f)" % [y1, gear_top])
	e.queue_free()
	await get_tree().process_frame
	# a cut with no title builds the node but shows nothing of it
	var bare := _built("")
	await get_tree().process_frame
	check(bare.load_ok and not bare.title.visible, "a later run's cut has no title node on screen")
	bare.queue_free()
	await get_tree().process_frame


func T_HALF_HAND() -> float:
	return Ext.T_HAND_FADE * 0.5


func _test_survivors() -> void:
	print("[survivors at the windows]")
	var e := _built("", 2)
	await get_tree().process_frame
	var sv = e.survivors
	check(sv != null and sv.people.size() >= 2, "run 2: survivors are at lit windows (%d)" % (sv.people.size() if sv != null else 0))
	if sv == null:
		e.queue_free()
		return
	var kinds := {}
	var lit := {}
	for w in e.meta["scene"]["lit"]:
		lit["%d:%d" % [int(w["floor"]), int(w["bay"])]] = true
	var inside := true
	for p in sv.people:
		kinds[String(p["kind"])] = true
		inside = inside and lit.has("%d:%d" % [int(p["floor"]), int(p["bay"])])
	check(inside, "…every one at a LIT window (a silhouette against the light)")
	check(kinds.size() >= 2, "…not all doing the same thing %s" % str(kinds.keys()))
	# a pacer actually walks; everyone is a 4 px bust inside the 9 px of glass
	var moved := false
	var within := true
	for p in sv.people:
		sv.clock = 0.0
		var x0: float = sv.person_x(p)
		var lo := x0
		var hi := x0
		for k in range(60):
			sv.clock = float(k) * 0.25
			var xx: float = sv.person_x(p)
			lo = minf(lo, xx)
			hi = maxf(hi, xx)
		if String(p["kind"]) == "pace" and hi - lo > 2.0:
			moved = true
		within = within and roundf(lo) >= 0.0 and roundf(hi) <= 5.0
	check(moved or not kinds.has("pace"), "a pacer crosses its window")
	check(within, "…and a bust (4 px wide) stays inside the 9 px of glass")
	e.t = 6.0
	e._apply(0.0)
	check(is_equal_approx(sv.clock, 6.0), "they animate off the opening's own clock")
	e.queue_free()
	# owner round 49 ("people at windows could be more animated"): a real repertoire, and shadows passing behind curtains
	var known := ["wave", "pace", "peer", "sway", "pound", "slump"]
	var all_kinds := {}
	var pass_ok := true
	var n_pass := 0
	var night_people := 0
	for run in [2, 3]:
		var e3 := _built("", run)
		await get_tree().process_frame
		var s3 = e3.survivors
		if s3 == null:
			check(false, "run %d: has people at windows" % run)
			e3.queue_free()
			continue
		var lit3 := {}
		var mans := {}
		for w in e3.meta["scene"]["lit"]:
			lit3["%d:%d" % [int(w["floor"]), int(w["bay"])]] = Vector2(float(w["x"]), float(w["y"]))
		for p in s3.people:
			all_kinds[String(p["kind"])] = true
			check(known.has(String(p["kind"])), "run %d: a known behaviour (%s)" % [run, String(p["kind"])])
			mans["%d:%d" % [int(p["floor"]), int(p["bay"])]] = true
		for q in s3.passers:
			if run == 2:
				n_pass += 1
			var at := Vector2(float(q["x"]), float(q["y"]))
			var found := false
			for key in lit3:
				if (lit3[key] as Vector2) == at and not mans.has(key):
					found = true
			pass_ok = pass_ok and found
		if run == 3:
			night_people = s3.people.size() + s3.passers.size()
		# a figure's pose is a pure function of the clock: the same time gives the same place, whatever came before
		if not s3.people.is_empty():
			s3.clock = 3.0
			var a1: float = s3.person_x(s3.people[0])
			s3.clock = 17.0
			s3.clock = 3.0
			check(is_equal_approx(a1, float(s3.person_x(s3.people[0]))), "run %d: a pose depends on the clock alone" % run)
		e3.queue_free()
		await get_tree().process_frame
	check(all_kinds.size() >= 3, "between them the people do at least three different things %s" % str(all_kinds.keys()))
	check(n_pass >= 3 and pass_ok, "shadows pass behind the curtains of OTHER lit windows (%d), never a window with someone at it" % n_pass)
	check(night_people >= 1 and night_people <= 4, "the night has few people at its windows (%d)" % night_people)
	_test_window_frames()


## Owner round 49c ("the people seem to be clipping the window frame… looking half outside"): every figure is a bust inside ONE pane and the window's own
## frame (jamb, lintel, mullion, sill — copied from the FINISHED picture) is laid back over it, so a figure stands behind them.
func _test_window_frames() -> void:
	for run in [1, 2]:
		var m: Dictionary = _meta(run)["scene"]
		var wins: Array = []
		wins.append_array(m["survivors"])
		wins.append_array(m["passers"])
		check(not wins.is_empty(), "run %d: windows with people have their frames kept (%d)" % [run, wins.size()])
		var tex := load("%swinover_%d.png" % [Ext.DIR, run]) as Texture2D
		check(tex != null and tex.get_width() == 9 and tex.get_height() == 8 * wins.size(), "run %d: one 9 x 8 frame tile per window (%d)" % [run, wins.size()])
		if tex == null:
			continue
		var img: Image = tex.get_image()
		var scene: Image = (load("%sscene_%d.png" % [Ext.DIR, run]) as Texture2D).get_image()
		var ok := true
		var why := ""
		for w in wins:
			var i := int(w["over"])
			for xx in range(9):
				for yy in range(8):
					var pc := img.get_pixel(xx, i * 8 + yy)
					var sc := scene.get_pixel(int(w["x"]) + xx, int(w["y"]) + yy)
					var must := yy in [0, 1, 7] or xx in [0, 4]
					if must and (pc.a < 0.99 or pc.is_equal_approx(sc) == false):
						ok = false
						why = "tile %d (%d,%d) is not the picture's own pixel" % [i, xx, yy]
					if not must and not (xx in [1, 7, 8]) and pc.a > 0.01:
						ok = false
						why = "tile %d (%d,%d) covers open glass" % [i, xx, yy]
		check(ok, "run %d: the tiles hold ONLY the frame (lintel, sill, jamb, mullion), pixel for pixel from the finished picture %s" % [run, why])


func _test_runner() -> void:
	print("[the garden's runner]")
	for run in [1, 2]:
		var e := _built("", run)
		await get_tree().process_frame
		var rn = e.runner
		var who := "a cat" if run == 1 else "a person"
		check(rn != null and rn.spec["kind"] == ("cat" if run == 1 else "human"), "run %d: %s is in the garden" % [run, who])
		if rn == null:
			e.queue_free()
			continue
		var pts: Array = rn._pts
		check(pts.size() >= 4, "run %d: it follows a planned route (%d waypoints)" % [run, pts.size()])
		var first: Vector2 = pts[0]
		check(first.x <= 0.0 or first.x >= 288.0 or first.y > 43.0, "run %d: it comes in from off the picture (x %d, row %d)" % [run, int(first.x), int(first.y)])
		# DEPTH — owner round 49: "they always run from the very bottom of the screen, when they could be moving deeper into the scene"
		var rows_min := 99.0
		var rows_max := -99.0
		var len_all := 0.0
		var len_front := 0.0
		for i in range(1, pts.size()):
			var a: Vector2 = pts[i - 1]
			var b: Vector2 = pts[i]
			rows_min = minf(rows_min, minf(a.y, b.y))
			rows_max = maxf(rows_max, maxf(a.y, b.y))
			len_all += a.distance_to(b)
			if a.y >= 40.0 and b.y >= 40.0 and a.y <= 43.0 and b.y <= 43.0:        # the strip along the picture's bottom edge (rows below 43 are off-screen)
				len_front += a.distance_to(b)
		check(rows_max - rows_min >= 30.0, "run %d: it travels deep into the scene (rows %d down to %d)" % [run, int(rows_max), int(rows_min)])
		check(len_front < 0.45 * len_all, "run %d: no more than 45%% of the way is spent along the bottom edge (%d of %d px)" % [run, int(len_front), int(len_all)])
		var last: Vector2 = pts[pts.size() - 1]
		check(last.y <= 6.0, "run %d: and it ends at the building (row %d)" % [run, int(last.y)])
		# owner round 49c ("he gets weirdly smaller… strange body pixel proportions"): hand-drawn figures in THREE sizes picked by the ground row — never a
		# drawing rescaled to a fractional size, never smaller than a person at the building's own plane (10 px)
		check(rn.art != null and rn.tier_at(3.0) == "S" and rn.tier_at(20.0) == "M" and rn.tier_at(43.0) == "L", "run %d: one of three hand-drawn sizes by the row it stands on (%s / %s / %s)" % [run, rn.tier_at(3.0), rn.tier_at(20.0), rn.tier_at(43.0)])
		var fig_ok := rn.art != null
		var h_min := 99.0
		if rn.art != null:
			for k in rn.art.rects:
				if String(k).begins_with("person_") and not String(k).contains("pound"):
					h_min = minf(h_min, (rn.art.rects[k] as Rect2).size.y)
			for t_name in ["L", "M", "S"]:
				for f_name in ["a", "p1", "b", "p2"] if run == 2 else ["a", "b"]:
					fig_ok = fig_ok and rn.art.rects.has("%s_%s_%s" % ["person" if run == 2 else "cat", t_name, f_name])
		check(fig_ok, "run %d: every size has every frame of its run on the sheet" % run)
		if run == 2:
			check(h_min >= 10.0, "…and the smallest person is %d px tall (a figure at the building is still a person, not a speck)" % int(h_min))
		var names_seen := {}
		for i in range(24):
			rn.clock = float(rn.spec["start"]) + 0.05 * float(i) + 0.3
			names_seen[rn.sprite_name()] = true
		check(names_seen.size() >= 2, "run %d: its gait cycles through frames (%s)" % [run, str(names_seen.keys())])
		# the clock
		var st: float = float(rn.spec["start"])
		e.t = st - 0.5
		e._apply(0.0)
		check(not rn.active(), "run %d: not there before it sets off" % run)
		e.t = st + 0.3
		e._apply(0.0)
		check(rn.active(), "run %d: running soon after" % run)
		check(float(rn.pose()["dir"]) == (1.0 if run == 1 else -1.0), "run %d: it faces the way it runs (%s)" % [run, "right" if run == 1 else "left"])
		var f0: Vector2 = rn.feet()
		e.t = st + float(rn.total()) * 0.5
		e._apply(0.0)
		var f1: Vector2 = rn.feet()
		e.t = st + float(rn.total()) - 0.05
		e._apply(0.0)
		var f2: Vector2 = rn.feet()
		check(f0.y > f1.y and f1.y > f2.y, "run %d: its feet go UP the picture the whole way (y %d → %d → %d)" % [run, int(f0.y), int(f1.y), int(f2.y)])
		e.t = st + float(rn.total()) + 1.5
		e._apply(0.0)
		if run == 1:
			check(not rn.active(), "run 1: the cat has gone into the doorway")
		else:
			check(rn.active() and bool(rn.pose()["done"]), "run 2: the person is still at the door, hammering on it")
		e.queue_free()
		await get_tree().process_frame
	var night := _built("", 3)
	await get_tree().process_frame
	check(night.runner == null, "night: nothing runs across the garden")
	night.queue_free()


## THE NIGHT'S STORM + ITS FLYING HORRORS (owner round 49c: "more lightning, especially actual lightning bolts in the background striking down";
## "instead of those birds… flying monsters. Just shadow silhouettes… not humanish in form. Lovecraftian").
func _test_night_storm() -> void:
	print("[the night: bolts behind the city, flying horrors]")
	var e := _built("", 3)
	await get_tree().process_frame
	check(e.load_ok and e.sky_bolts != null and e.fliers != null and e.fliers_sky != null, "night: the storm layer and both flocks are built")
	if not e.load_ok or e.sky_bolts == null:
		e.queue_free()
		return
	check(e.sky_bolts.get_parent() == e.layers["sky"]["node"], "the bolts live IN THE SKY LAYER, behind the far and mid skylines and the tower")
	check(e.sky_bolts.material is CanvasItemMaterial and (e.sky_bolts.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "…drawn additively, so a bolt lights the cloud deck")
	var st: Array = e._strikes
	var bolts := 0
	for q in st:
		if String(q["kind"]) == "bolt":
			bolts += 1
	check(st.size() >= 12 and bolts >= int(0.5 * st.size()), "a strike every second or two, most of them real forked bolts (%d, %d bolts)" % [st.size(), bolts])
	var last_t := -1.0
	var gaps_ok := true
	for q in st:
		gaps_ok = gaps_ok and float(q["t"]) > last_t
		last_t = float(q["t"])
	check(gaps_ok, "the strikes are in time order")
	# a bolt is a connected channel from the top of what is on screen down into the sky, with forks leaving it
	var q0: Dictionary = {}
	for q in st:
		if String(q["kind"]) == "bolt":
			q0 = q
			break
	var shp: Dictionary = e.sky_bolts.shape(q0)
	var main: PackedVector2Array = shp["main"]
	var connected := main.size() > 40
	for i in range(1, main.size()):
		connected = connected and absf(main[i].y - main[i - 1].y) == 1.0 and absf(main[i].x - main[i - 1].x) <= 2.0
	check(connected, "a bolt is ONE connected jagged channel (%d px long, a step of at most 2 px sideways per row)" % main.size())
	check(absf(main[0].y - float(q0["y0"])) <= 1.5 and absf(main[main.size() - 1].y - float(q0["y1"])) <= 1.5, "…running from its top to its end")
	var forks: Array = shp["forks"]
	var from_main := not forks.is_empty()
	for f in forks:
		var fp: PackedVector2Array = f
		var touches := false
		for pt in main:
			if absf(pt.y - (fp[0].y - 1.0)) < 0.5 and absf(pt.x - fp[0].x) <= 3.0:
				touches = true
		from_main = from_main and touches
	check(from_main, "…with forks that leave it (%d)" % forks.size())
	check(e.sky_bolts.shape(q0)["main"] == main, "the same strike is always the same shape")
	# the flash: a fast rise, a fall, a restrike; nothing before it or after its life
	check(e.sky_bolts.level(-0.1, true) == 0.0 and e.sky_bolts.level(0.9, true) == 0.0, "no light before a strike or after its life")
	var peak := 0.0
	for i in range(0, 80):
		peak = maxf(peak, e.sky_bolts.level(float(i) * 0.01, false))
	check(peak >= 0.95 and e.sky_bolts.level(0.06, false) > e.sky_bolts.level(0.35, false), "it peaks within a tenth of a second and dies away (%.2f)" % peak)
	check(e.sky_bolts.level(0.23, true) > e.sky_bolts.level(0.23, false) + 0.3, "a restrike lights it a second time")
	# the clock plays them: the flash and the thunder queue (thunder arrives AFTER the light)
	var first: Dictionary = st[0]
	e.t = float(first["t"]) + 0.02
	e._strike_i = 0
	e._booms.clear()
	e.flash.modulate.a = 0.0
	e._lightning(0.016)
	check(e.flash.modulate.a >= 0.05, "the picture flashes as the strike lands")
	if String(first["kind"]) == "bolt":
		check(e._booms.size() == 1 and float(e._booms[0]["at"]) > e.t + 0.5, "…and its thunder comes later, softer, by how far off it was")
	e.queue_free()
	await get_tree().process_frame
	# the fliers: a sheet of shadow silhouettes that are NOT a bat, a bird or a person
	var tex := load(Ext.DIR + "monsters.png") as Texture2D
	check(tex != null, "the flying horrors have their sheet")
	if tex != null:
		var img: Image = tex.get_image()
		var meta3: Dictionary = _meta(3)["monsters"]
		var all := 0
		var asym_ok := true
		var dark_ok := true
		var worst := 1.0
		for size in ["L", "M", "S"]:
			for e2 in meta3[size]:
				all += 1
				var rx: int = int(e2["x"])
				var ry: int = int(e2["y"])
				var w: int = int(e2["w"])
				var h: int = int(e2["h"])
				var diff := 0
				var solid := 0
				for yy in range(h):
					for xx in range(w):
						var a := img.get_pixel(rx + xx, ry + yy)
						var b := img.get_pixel(rx + (w - 1 - xx), ry + yy)
						if a.a > 0.5:
							solid += 1
							if a.r + a.g + a.b > 0.6:
								dark_ok = false
						if (a.a > 0.5) != (b.a > 0.5):
							diff += 1
				var frac := float(diff) / maxf(1.0, float(solid))
				worst = minf(worst, frac)
				asym_ok = asym_ok and frac >= 0.12
		check(all == 15, "three sizes x five wing poses (%d)" % all)
		check(dark_ok, "they are SHADOWS: every solid pixel is near black")
		check(asym_ok, "not mirror-symmetric — a Lovecraftian thing, not a bird or a bat with a body down the middle (least asymmetric: %.0f %% of its pixels differ)" % (worst * 100.0))
	# the flocks are pure functions of the clock; the roof flock wheels over the roof, the far one crosses the sky and wraps
	var e4 := _built("", 3)
	await get_tree().process_frame
	var fl = e4.fliers
	fl.clock = 5.0
	var p1: Dictionary = fl.pose(0, 5.0)
	var p2: Dictionary = fl.pose(0, 5.0)
	check(p1 == p2 and String(p1["frame"]) != "", "a flier's pose depends on the clock alone")
	var near_roof := true
	for i in fl.flock.size():
		for tt in [0.0, 3.0, 9.0, 17.0, 31.0]:
			var q: Dictionary = fl.pose(i, tt)
			near_roof = near_roof and absf((q["pos"] as Vector2).x - fl.home_x) <= 140.0 and (q["pos"] as Vector2).y < 0.0
	check(near_roof, "the roof flock wheels over the roof, above its parapet")
	var sky = e4.fliers_sky
	var wrap_ok := true
	for i in sky.flock.size():
		for tt in range(0, 120, 7):
			var xq: float = (sky.pose(i, float(tt))["pos"] as Vector2).x
			wrap_ok = wrap_ok and xq >= -42.0 and xq <= 330.0
	check(wrap_ok, "the far flock crosses the sky and wraps round off both edges")
	var frames := {}
	for i in range(0, 60):
		frames[String(fl.pose(2, float(i) * 0.2)["frame"])] = true
	check(frames.size() >= 3, "they beat their wings and glide (%s)" % str(frames.keys()))
	e4.queue_free()
	await get_tree().process_frame


## Owner round 49c: "the help sign… the letters should be under one another like that, it's difficult to read… HELP should be together, not two letters
## above two below". A word is ONE line: its red letters fill a band at most a few rows tall and a word's width across.
func _test_help_sheets() -> void:
	print("[HELP is one line]")
	for run in [2, 3]:
		var m: Dictionary = _meta(run)["scene"]
		var img: Image = (load("%sscene_%d.png" % [Ext.DIR, run]) as Texture2D).get_image()
		var n_help := 0
		var all_one_line := true
		var why := ""
		for hp in m["helps"]:
			var x0 := int(hp["x"])
			var y0 := int(hp["y"])
			var w := int(hp["w"])
			var h := int(hp["h"])
			var minx := 999
			var maxx := -1
			var miny := 999
			var maxy := -1
			for yy in range(h):
				for xx in range(w):
					var c := img.get_pixel(x0 + xx, y0 + yy)
					if c.r > 0.10 and c.r > c.g * 3.0 and c.r > c.b * 3.0:                  # the paint's red, however dark the hour grades it
						minx = mini(minx, xx)
						maxx = maxi(maxx, xx)
						miny = mini(miny, yy)
						maxy = maxi(maxy, yy)
			var word := String(hp["word"])
			if word == "HELP":
				n_help += 1
				check(w == 17, "run %d: a HELP sheet is 17 px wide, over the piers but not over a neighbour's frame (%d)" % [run, w])
			var span := maxx - minx + 1
			var band := maxy - miny + 1
			var want_w := 4 * word.length() - 1
			if maxx < 0 or span < want_w - 1 or band > 9:
				all_one_line = false
				why += " %s: letters span %d x %d" % [word, span, band]
		check(all_one_line, "run %d: every sheet's letters sit on ONE line, side by side%s" % [run, why])
		check(run != 2 or n_help >= 1, "run %d has a HELP sheet to look at" % run)


func _test_runs() -> void:
	print("[each run builds its own look]")
	for run in [1, 2, 3]:
		var e := _built("DESCEND FROM 30", run)
		await get_tree().process_frame
		check(e.load_ok and e.run == run, "run %d builds" % run)
		var tex: Texture2D = e.layers["sky"]["node"].get_child(0).texture
		check(str(tex.resource_path).ends_with("sky_%d.png" % run), "run %d uses its own sky (%s)" % [run, tex.resource_path.get_file()])
		var stex: Texture2D = e.layers["scene"]["node"].get_child(0).texture
		check(str(stex.resource_path).ends_with("scene_%d.png" % run), "…and its own building + street")
		check((e.rain != null) == (run == 3) and (e.birds != null) == (run < 3), "run %d: rain %s, crows %s" % [run, run == 3, run < 3])
		if run >= 2:
			check(e.flames.size() >= 2, "run %d: things are burning in the city and the street (%d flames)" % [run, e.flames.size()])
		var smokes := e.find_children("*", "AnimatedSprite2D", true, false)
		if run == 1:
			check(smokes.size() == 0 and e.flames.is_empty() and e.layers["scene"]["node"].get_node_or_null("Burning") == null,
				"run 1: no smoke, flame or burnt window anywhere (%d sprites) — fire only arrives with the afternoon" % smokes.size())
		else:
			check(smokes.size() >= 3 + run, "run %d: the smoke / flame sprites are animating (%d)" % [run, smokes.size()])
		var seen_people: int = (e.survivors.people.size() + e.survivors.passers.size()) if e.survivors != null else 0
		if run < 3:
			check(e.survivors != null and e.survivors.people.size() >= 1, "run %d: someone is at a window (%d)" % [run, seen_people])
		else:
			check(e.survivors != null and seen_people >= 1 and seen_people <= 4, "night: only a few people at the windows, not a crowd (%d)" % seen_people)
		check((e.fliers != null) == (run == 3) and (e.fliers_sky != null) == (run == 3) and (e.sky_bolts != null) == (run == 3),
			"run %d: the night's flying horrors and the storm behind the city are there only at night" % run)
		# the night lightning flashes the picture and settles
		if run == 3:
			e._bolt_in = 0.0
			e._apply(0.016)
			check(e.flash.modulate.a > 0.3, "night: a lightning flash")
			e._apply(0.6)
			check(e.flash.modulate.a < 0.1, "…that dies away")
		e.queue_free()
		await get_tree().process_frame
	# with no run given it follows the game's run
	WorldState.new_game()
	WorldState.current_run = 2
	var d: Control = Ext.new()
	add_child(d)
	await get_tree().process_frame
	check(d.run == 2 and d.load_ok, "with no run given it takes WorldState.current_run (2)")
	d.queue_free()
	WorldState.current_run = 1


func _expected_stage_count(stage: int) -> Array:
	return [1, 2] if stage == WorldState.FIRE_LIGHT else ([3, 5] if stage == WorldState.FIRE_BLAZE else [6, 8])


func _test_burning() -> void:
	print("[the floors burning are this playthrough's own]")
	# find a building with at least two fire origins so every run's front shows
	var found := false
	for sd in range(1, 400):
		WorldState.new_game()
		WorldState.master_seed = sd
		WorldState.fire_dealt_with = {}
		var origins := 0
		for f in range(2, 30):
			if WorldState._fire_origin_seeded(f):
				origins += 1
		if origins >= 2:
			found = true
			break
	check(found, "found a seed with fire origins (%d)" % WorldState.master_seed)
	var counts: Array = []
	for run in [1, 2, 3]:
		WorldState.current_run = run
		var plan: Array = Ext.burn_plan()
		counts.append(plan.size())
		var ok := true
		var floors := {}
		for e in plan:
			floors[int(e["floor"])] = true
			var want: Array = _expected_stage_count(int(e["stage"]))
			var bays: Array = e["bays"]
			var uniq := {}
			for b in bays:
				uniq[int(b)] = true
				if int(b) < 0 or int(b) > 7:
					ok = false
			if bays.size() < want[0] or bays.size() > want[1] or uniq.size() != bays.size() or int(e["stage"]) != WorldState.fire_intensity(int(e["floor"])):
				ok = false
		check(ok, "run %d: every entry is the fire sim's stage with a window count to match (%d floors)" % [run, plan.size()])
		var every := true
		for f in range(2, 30):
			if (WorldState.fire_intensity(f) >= 0) != floors.has(f):
				every = false
		check(every, "run %d: exactly the floors the corridors will have alight" % run)
		check(str(Ext.burn_plan()) == str(plan), "run %d: the plan is the same every time it's asked" % run)
	check(counts[0] >= 1 and counts[1] >= counts[0] and counts[2] >= counts[1], "the fire climbs the building run by run %s" % str(counts))
	# …but the first morning's picture shows none of it, though the sim has a light fire going (it arrives with the afternoon)
	WorldState.current_run = 1
	var calm: Control = _built("", 1)
	await get_tree().process_frame
	check(not Ext.burn_plan().is_empty() and calm.layers["scene"]["node"].get_node_or_null("Burning") == null and calm.burning.is_empty(),
		"run 1: the fire sim has a light fire, the exterior still shows none")
	calm.queue_free()
	await get_tree().process_frame
	# stages escalate on a floor: the same origin floor is LIGHT, then BLAZE, then CHARRED
	var origin := -1
	for f in range(2, 30):
		if WorldState._fire_origin_seeded(f):
			origin = f
			break
	var st: Array = []
	for run in [1, 2, 3]:
		WorldState.current_run = run
		st.append(WorldState.fire_intensity(origin))
	check(st == [WorldState.FIRE_LIGHT, WorldState.FIRE_BLAZE, WorldState.FIRE_CHARRED], "an origin floor goes light → blaze → charred %s" % str(st))
	# the overlay is laid: a charred window sprite for every burning window, flames only where it is still alight
	WorldState.current_run = 2
	var e: Control = _built("", 2)
	await get_tree().process_frame
	var holder: Node = e.layers["scene"]["node"].get_node_or_null("Burning")
	var windows := 0
	var alight := 0
	for entry in Ext.burn_plan():
		windows += entry["bays"].size()
		if int(entry["stage"]) == WorldState.FIRE_BLAZE:
			alight += entry["bays"].size()
	check(holder != null and holder.get_child_count() >= windows * 2, "run 2: charred windows + soot are laid on the burning floors (%d windows)" % windows)
	var fire_sprites := 0
	if holder != null:
		for ch in holder.get_children():
			if ch is AnimatedSprite2D and str((ch as AnimatedSprite2D).sprite_frames.get_frame_texture("default", 0).atlas.resource_path).ends_with("fire.png"):
				fire_sprites += 1
	check(fire_sprites == alight, "…with flames in exactly the windows still alight (%d)" % fire_sprites)
	e.queue_free()
	await get_tree().process_frame
	# put every origin out and the building is clean
	WorldState.current_run = 3
	for f in range(2, 30):
		if WorldState._fire_origin_seeded(f):
			WorldState.fire_dealt_with[str(f)] = 1
	check(Ext.burn_plan().is_empty(), "fires put out for good leave nothing burning on the building")
	var clean: Control = _built("", 3)
	await get_tree().process_frame
	check(clean.layers["scene"]["node"].get_node_or_null("Burning") == null, "…and no overlay is laid")
	clean.queue_free()
	WorldState.current_run = 1
	WorldState.fire_dealt_with = {}
	await get_tree().process_frame


func _test_overlay_flow() -> void:
	print("[the cold open begins on it]")
	WorldState.new_game()
	var intro: CanvasLayer = IntroScript.new()
	add_child(intro)
	await get_tree().process_frame
	check(intro.stage == "exterior" and intro.ext != null and intro.ext.with_title, "a new game (a title in the config) starts on the exterior shot, with its title")
	check(get_tree().paused, "the opening pauses play like the rest of the cold open")
	var words_seen := 0.0
	var hand_seen := 0.0
	var order_ok := true
	var steps := 0
	while intro.stage == "exterior" and steps < 4000:
		intro._process(0.02)
		if intro.ext != null:
			words_seen = maxf(words_seen, intro.ext.title_words.modulate.a)
			hand_seen = maxf(hand_seen, intro.ext.title_hand.modulate.a)
			if intro.ext.title_hand.modulate.a > 0.0 and intro.ext.title_words.modulate.a < 1.0:
				order_ok = false
		steps += 1
	check(words_seen >= 0.99 and hand_seen >= 0.99, "the game's title came fully up on the way: the lettering (%.2f) and the handprint (%.2f)" % [words_seen, hand_seen])
	check(order_ok, "…the lettering first, the handprint only once the words were up")
	check(intro.stage == "card" and intro.ext == null, "then it hands on to the time card (the exterior is gone)")
	check(intro.black.color.a == 1.0, "…over black, as the run information always was")
	check(intro.gore.modulate.a < 0.2, "…the handprint isn't up yet — it arrives with the card")
	intro.queue_free()
	await get_tree().process_frame
	check(not get_tree().paused, "freed mid-way → never leaves the game paused")
	# runs 2 and 3: the same shot in their light, shorter, no title
	for run in [2, 3]:
		WorldState.current_run = run
		var again: CanvasLayer = IntroScript.new()
		again.title_text = ""
		add_child(again)
		await get_tree().process_frame
		check(again.stage == "exterior" and again.ext != null and not again.ext.with_title and again.ext.run == run,
			"run %d's cold open starts on its own exterior, no title" % run)
		var n := 0
		while again.stage == "exterior" and n < 4000:
			again._process(0.02)
			n += 1
		check(again.stage == "card" and float(n) * 0.02 < Ext.t_end(true) - 3.0, "…and reaches the time card sooner (%.1f s)" % (float(n) * 0.02))
		again.queue_free()
		await get_tree().process_frame
	WorldState.current_run = 1


func _test_hurry() -> void:
	print("[a key hurries it]")
	var intro: CanvasLayer = IntroScript.new()
	add_child(intro)
	await get_tree().process_frame
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	var e: Control = intro.ext
	intro._input(ev)
	check(e.speed == Ext.HURRY_SPEED and e.t < Ext.t_title_in(true), "a key during the climb speeds it up — it doesn't cut")
	var guard := 0
	while e.t < Ext.t_title_in(true) + 0.5 and guard < 2000:
		intro._process(0.02)
		guard += 1
	check(e.speed == 1.0, "…and the title lands at its own pace")
	intro._input(ev)
	check(e.t >= Ext.t_out(true) - 0.001, "a key once the title is up goes straight to the fade out")
	guard = 0
	while intro.stage == "exterior" and guard < 400:
		intro._process(0.02)
		guard += 1
	check(intro.stage == "card", "…and on to the card")
	var e2: Control = Ext.new()
	add_child(e2)
	await get_tree().process_frame
	e2.tick(1.5)
	check(e2.t <= 0.1 + 0.0001, "a long frame advances the clock by at most 0.1 s")
	e2.queue_free()
	# a title-less cut: a key after the climb goes to the fade out
	var e3: Control = _built("", 2)
	await get_tree().process_frame
	e3.t = Ext.t_pan_end(false) + 0.05
	e3.hurry()
	check(e3.t >= Ext.t_out(false) - 0.001, "(no title) a key once the climb is over goes straight to the fade out")
	e3.queue_free()
	intro.queue_free()
	await get_tree().process_frame


func _on_seq_done() -> void:
	_seq_done = true


func _test_load_sequence() -> void:
	print("[loading a save plays it in the save's own run]")
	WorldState.new_game()
	WorldState.current_run = 3
	check(Seq.available(), "the opening is available for a run-3 save")
	var seq = Seq.new()
	seq.finished.connect(_on_seq_done)
	add_child(seq)
	await get_tree().process_frame
	check(seq.ext != null and seq.ext.run == 3 and seq.ext.with_title and seq.ext.own_input, "it plays run 3's night exterior, with the title, and listens for a key")
	check(seq.layer == 6, "…beneath Transition's black (layer 128)")
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	seq.ext._input(ev)
	check(seq.ext.speed == Ext.HURRY_SPEED, "a key hurries it")
	var n := 0
	while not _seq_done and n < 6000:
		seq._process(0.02)
		n += 1
		if seq.ext != null and seq.ext.t >= Ext.t_title_in(true) and seq.ext.t < Ext.t_out(true) - 0.5 and n % 7 == 0:
			seq.ext.t = Ext.t_out(true) - 0.4
	check(_seq_done, "it says finished once the picture has faded to black (after %.1f s of ticks)" % (float(n) * 0.02))
	check(seq.ext.shade.color.a >= 0.99, "…and it is on black, ready for the saved scene")
	seq.queue_free()
	await get_tree().process_frame
	WorldState.current_run = 1


func _test_fallback() -> void:
	print("[the old black title screen is still the fallback]")
	var intro: CanvasLayer = IntroScript.new()
	intro.exterior_enabled = false
	add_child(intro)
	await get_tree().process_frame
	check(intro.stage == "title" and intro.ext == null and intro.title.text == "DESCEND FROM 30", "exterior off → the black title screen")
	for i in 400:
		intro._process(0.02)
		if intro.stage != "title":
			break
	check(intro.stage == "card" and intro.gore.modulate.a == 1.0, "…then the card with the handprint already up, as before")
	intro.queue_free()
	await get_tree().process_frame


# ---- round 36j: the garden's path, its walls, what may stand where; the 2.5D split; fog; pixel rain + bolt --------------------------------
func _zone(path: Dictionary, x0: int, x1: int, yy: int) -> String:
	var hw := int(float(path["a"]) + float(yy) * float(path["b"]))
	var lo: int = x0 - int(path["cx"])
	var hi: int = x1 - int(path["cx"])
	if lo >= -(hw - 1) and hi <= hw - 1:
		return "path"
	var wall := int(path["wall_t"]) + 3 if (yy >= int(path["wall_from"]) - 1 and yy <= int(path["wall_to"]) + 2) else 0
	var clear := hw + 2 + wall
	if hi <= -clear or lo >= clear:
		return "lawn"
	return ""


func _test_garden_plan() -> void:
	print("[the garden: a path with walls, nature kept to the lawn]")
	for run in [1, 2, 3]:
		var gm: Dictionary = _meta(run)["garden"]
		var path: Dictionary = gm["path"]
		var plants := 0
		var bad: Array = []
		for pl in gm["placed"]:
			var what := String(pl["what"])
			var z := _zone(path, int(pl["x0"]), int(pl["x1"]), int(pl["yy"]))
			if what.begins_with("tree") or what.contains("shrub") or what.contains("bush") or what == "planter" or what == "bench" or what == "lamp":
				plants += 1
				if z != "lawn":
					bad.append(what)
			if String(pl["zone"]) != z:
				bad.append("zone drift " + what)
		check(plants >= 14 and bad.is_empty(), "run %d: %d trees / shrubs / planters / benches / lamps, every one on the lawn, none on the path or its walls %s" % [run, plants, str(bad)])
		for t_ in gm["trees"]:
			var hh := int(float(t_["r"]) * (0.9 if t_["kind"] == "poplar" else 1.4)) + 1
			check(_zone(path, int(t_["x"]) - hh, int(t_["x"]) + hh, int(t_["y"]) - 482) == "lawn", "run %d: the %s at x %d does not reach the path" % [run, t_["kind"], int(t_["x"])])
		# the walls are really drawn: stone (grey, low saturation) at the wall's foot on both sides, grass beyond it; the path itself is paving
		var img: Image = (load("%sgarden_%d.png" % [Ext.DIR, run]) as Texture2D).get_image()
		var cx := int(path["cx"])
		var yy := 28
		var hw := int(float(path["a"]) + yy * float(path["b"]))
		for side in [-1, 1]:
			var px := img.get_pixel(cx + side * (hw + 1), 482 + yy - 2)
			var lawn := img.get_pixel(cx + side * (hw + int(path["wall_t"]) + 24), 482 + yy)
			var paving := img.get_pixel(cx + side * (hw - 8), 482 + yy)
			var nm := "left" if side < 0 else "right"
			check(px.a > 0.9 and lawn.a > 0.9 and (px.to_html(false) != lawn.to_html(false)) and (px.to_html(false) != paving.to_html(false)),
				"run %d: a wall stands between the paving and the lawn on the %s" % [run, nm])
			if run == 1:
				check(px.s < 0.30, "run 1: it is stone, not leaf (sat %.2f)" % px.s)
				check(lawn.g > lawn.r and lawn.g > lawn.b, "run 1: grass beyond it on the %s" % nm)
		var tones := {}
		for x in range(cx - hw + 6, cx + hw - 5, 2):
			tones[img.get_pixel(x, 482 + 14).to_html(false)] = true
		check(tones.size() >= 6, "run %d: the paving has real detail (%d tones across a row of slabs)" % [run, tones.size()])


func _test_depth_and_weather() -> void:
	print("[2.5D: a flat facade, the garden on its own plane; fog; pixel rain + lightning]")
	var sc: Image = (load(Ext.DIR + "scene_1.png") as Texture2D).get_image()
	var right_of := sc.get_pixel(209 + 6, 300)
	var below := sc.get_pixel(143, 482 + 30)
	check(right_of.a < 0.05, "the facade is flat on to us: nothing is drawn on its right (no receding side wall)")
	check(below.a > 0.9, "…and the building stands on its own back lawn, so the garden can slide past without a hole")
	var gd: Image = (load(Ext.DIR + "garden_1.png") as Texture2D).get_image()
	check(gd.get_pixel(143, 100).a < 0.05 and gd.get_pixel(143, 482 + 30).a > 0.9, "the garden layer holds only the ground and what stands on it")
	# the garden slides faster than the building as the camera climbs
	var e := _built("", 1)
	await get_tree().process_frame
	e.t = 0.0
	e._apply(0.0)
	var d0: float = e.layers["garden"]["node"].position.y - e.layers["scene"]["node"].position.y
	e.t = Ext.t_pan_end()
	e._apply(0.0)
	var d1: float = e.layers["garden"]["node"].position.y - e.layers["scene"]["node"].position.y
	check(is_equal_approx(d0, 0.0) and d1 > 40.0, "the garden and the building coincide at the start and part company on the climb (%.0f px apart at the end)" % d1)
	check(e.runner != null and e.runner.get_parent() == e.layers["garden"]["node"], "the cat is a child of the garden plane")
	check(not e.layers.has("fog"), "morning: no fog")
	e.queue_free()
	await get_tree().process_frame
	# the afternoon's fog drifts
	var f := _built("", 2)
	await get_tree().process_frame
	check(f.layers.has("fog") and f.layers.has("fogf"), "afternoon: a fog bank behind the garden and a veil in front of it")
	if f.layers.has("fog"):
		f.t = 1.0
		f._apply(0.0)
		var x1: float = f.layers["fog"]["node"].get_child(0).position.x
		f.t = 5.0
		f._apply(0.0)
		var x2: float = f.layers["fog"]["node"].get_child(0).position.x
		check(x2 < x1, "…and it drifts sideways (%.0f -> %.0f)" % [x1, x2])
		var order: Array = f.world.get_children().map(func(n): return n.name)
		check(order.find("Scene") < order.find("Fog") and order.find("Fog") < order.find("Garden") and order.find("Garden") < order.find("Fogf"), "…layered building < fog < garden < front fog")
	f.queue_free()
	await get_tree().process_frame
	var n3 := _built("", 3)
	await get_tree().process_frame
	check(not n3.layers.has("fog"), "night: no fog (rain instead)")
	# night: pixel rain (whole 4 px game pixels) and a pixel bolt with a double flash
	check(n3.rain != null and n3.rain.drops.size() >= 150, "night: rain in two depths (%d drops)" % n3.rain.drops.size())
	var snapped := true
	n3.rain.size = Vector2(1152, 648)
	for d in n3.rain.drops:
		var x: float = float(d["x"]) * 1152.0
		var sx: float = floorf(x / 4.0) * 4.0
		if fmod(sx, 4.0) != 0.0:
			snapped = false
	check(snapped, "…every drop draws on the 4 px pixel grid")
	check(n3.bolt != null, "night: a bolt layer is in the picture")
	n3._bolt_in = 0.0
	n3._lightning(0.016)
	check(n3.bolt.life > 0.0 and n3.bolt.pts.size() >= 20 and n3.flash.modulate.a >= 0.4, "a strike draws a jagged bolt (%d cells) with a flash" % n3.bolt.pts.size())
	var cell_ok := true
	for p in n3.bolt.pts:
		if fmod(p.x, 4.0) != 0.0 or fmod(p.y, 4.0) != 0.0:
			cell_ok = false
	check(cell_ok, "…whose every cell is a whole game pixel")
	for k in 10:
		n3._lightning(0.016)
	check(n3.flash.modulate.a >= 0.2 or n3._flicker_in < 0.0, "…and the flash stutters once after the first")
	n3.queue_free()
