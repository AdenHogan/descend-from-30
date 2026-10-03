extends Node

# THE NEW-GAME OPENING (owner round 35): the exterior shot a new game begins on — the tower in the morning, the camera climbing it
# floor by floor to the roof and the sky, the title over the clouds, a fade to black, then the run's time card. Locks: the art + its
# meta exist and agree; the timeline (a pure function of t) fades in, climbs monotonically, brings the title up late, fades out;
# the layers are anchored so the street is on screen at the start and the roof sits under the title at the end; clouds dress the
# title's sky; the overlay plays it as stage "exterior" and hands on to the card; a key hurries it (never cuts); the old black title
# screen is still the fallback; sounds exist. Run: godot --headless res://tests/opening_test.tscn

const Ext := preload("res://scripts/opening_exterior.gd")
const IntroScript := preload("res://scripts/intro_overlay.gd")

var failures: int = 0


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
	_test_timeline()
	await _test_layers()
	await _test_overlay_flow()
	await _test_hurry()
	await _test_fallback()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_art() -> void:
	print("[art]")
	check(Ext.art_present(), "every layer + the meta are in assets/opening/")
	var want := {"sky.png": Vector2i(288, 330), "far.png": Vector2i(288, 230), "mid.png": Vector2i(288, 300),
		"scene.png": Vector2i(288, 526), "fore.png": Vector2i(288, 200)}
	for f in want:
		var tex = load(Ext.DIR + f)
		check(tex is Texture2D and Vector2i(tex.get_width(), tex.get_height()) == want[f], "%s is the drawn size %s" % [f, str(want[f])])
	var m = JSON.parse_string(FileAccess.get_file_as_string(Ext.DIR + "opening_meta.json"))
	check(m is Dictionary and m.has("layers") and m.has("clouds") and m.has("scene"), "the meta lists layers, clouds and the scene's details")
	if m is Dictionary:
		var L: Dictionary = m["layers"]
		for k in ["sky", "far", "mid", "scene", "fore"]:
			check(L.has(k) and float(L[k]["h"]) > 0.0, "layer %s has a parallax + height" % k)
		check(float(L["sky"]["p"]) < float(L["far"]["p"]) and float(L["far"]["p"]) < float(L["mid"]["p"])
			and float(L["mid"]["p"]) < float(L["scene"]["p"]) and float(L["scene"]["p"]) < float(L["fore"]["p"]),
			"parallax grows toward the viewer (sky < far < mid < building < foreground)")
		check(float(m["scroll"]) > 300.0, "there is a real climb (%d px)" % int(m["scroll"]))
		check(m["scene"]["smoke"].size() >= 2, "the burnt floors give smoke points (%d)" % m["scene"]["smoke"].size())
		check(m["scene"]["lit"].size() >= 5, "a few lamps are still on (%d)" % m["scene"]["lit"].size())
		var floor30 := false
		for w in m["scene"]["lit"]:
			if int(w["floor"]) == 30:
				floor30 = true
		check(floor30, "…including a warm window on floor 30, where you wake")
	for f in ["wind.wav", "siren.wav", "swell.wav"]:
		check(load(Ext.AUDIO_DIR + f) is AudioStream, "sound %s" % f)


func _test_timeline() -> void:
	print("[timeline]")
	check(Ext.black_alpha(0.0) == 1.0, "starts on black")
	check(Ext.black_alpha(Ext.T_FADE_IN) == 0.0, "the picture is fully up after the fade in")
	check(Ext.black_alpha(Ext.t_out() - 0.01) == 0.0, "…and stays clear to the end of the hold")
	check(is_equal_approx(Ext.black_alpha(Ext.t_end()), 1.0), "ends on black, ready for the time card")
	check(Ext.pan_u(0.0) == 0.0 and Ext.pan_u(Ext.t_pan0()) == 0.0, "the street is held still before the climb")
	check(is_equal_approx(Ext.pan_u(Ext.t_pan_end()), 1.0), "the climb arrives at the roof")
	var last := -1.0
	var mono := true
	var tt := 0.0
	while tt <= Ext.t_end():
		var u := Ext.pan_u(tt)
		if u < last - 0.000001:
			mono = false
		last = u
		tt += 0.05
	check(mono, "the camera only ever climbs")
	var mid := Ext.pan_u(Ext.t_pan0() + Ext.T_PAN * 0.5)
	check(is_equal_approx(mid, 0.5), "ease in-out: halfway through the time is halfway up")
	check(Ext.pan_u(Ext.t_pan0() + 0.5) < 0.01, "it sets off gently (u %.4f after half a second)" % Ext.pan_u(Ext.t_pan0() + 0.5))
	check(Ext.title_alpha(Ext.t_title_in() - 0.1) == 0.0, "no title while the building is still filling the screen")
	check(Ext.t_title_in() > Ext.t_pan0() + Ext.T_PAN * 0.6 and Ext.t_title_in() < Ext.t_pan_end(), "the title comes up late in the climb")
	check(Ext.title_alpha(Ext.t_title_in() + Ext.T_TITLE_FADE) == 1.0, "…and is fully up well before the camera stops moving being useful")
	check(Ext.title_alpha(Ext.t_pan_end()) == 1.0, "the title is up when the camera arrives at the roof")
	check(Ext.title_visible(Ext.t_end()) == 0.0, "the title leaves with the fade to black")
	check(Ext.t_end() > 12.0 and Ext.t_end() < 30.0, "the whole opening is %.1f s — long enough to land, short enough to repeat" % Ext.t_end())


func _built(title_text := "DESCEND FROM 30") -> Control:
	var e: Control = Ext.new()
	e.title_text = title_text
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
	# where the roof lands: under the title, with sky above it
	var roof_screen: float = scene.position.y + 22.0
	check(roof_screen > 90.0 and roof_screen < 140.0, "at the end the roof's parapet sits low in the frame (y %.0f of 162)" % roof_screen)
	check(sky.position.y + float(e.layers["sky"]["h"]) > Ext.VIEW_H, "…and the sky still fills the view behind it")
	# the clouds dress the title's sky
	var seen := 0
	for c in e.clouds:
		var sp: Sprite2D = c["node"]
		var sz: Vector2 = sp.texture.get_size()
		if sp.position.y > -sz.y and sp.position.y < roof_screen - 10.0 and sp.position.x > -sz.x and sp.position.x < Ext.VIEW_W:
			seen += 1
	check(seen >= 6, "clouds are in the sky over the roof at the end (%d)" % seen)
	# the climb passes the sections: brick shows mid-climb (it is a different building at each height)
	e.t = Ext.t_pan0() + Ext.T_PAN * 0.5
	e._apply(0.0)
	check(scene.position.y > y0s + S * 0.4 and scene.position.y < y0s + S * 0.6, "halfway: the camera is halfway up the tower")
	# clouds drift (they are alive, not pasted)
	var cx0: float = e.clouds[0]["node"].position.x
	e.t += 5.0
	e._apply(0.0)
	check(not is_equal_approx(e.clouds[0]["node"].position.x, cx0), "clouds drift across the sky")
	# something moves at the start: smoke plumes and a beacon exist
	var smokes := e.find_children("*", "AnimatedSprite2D", true, false)
	check(smokes.size() >= 3, "smoke plumes are animating (%d)" % smokes.size())
	check(e.beacons.size() >= 2 and e.flickers.size() >= 1, "beacons blink and a lamp is failing (%d / %d)" % [e.beacons.size(), e.flickers.size()])
	check(e.birds != null, "crows circle the roof")
	e.queue_free()


func _test_overlay_flow() -> void:
	print("[the cold open begins on it]")
	var intro: CanvasLayer = IntroScript.new()
	add_child(intro)
	await get_tree().process_frame
	check(intro.stage == "exterior" and intro.ext != null, "a new game (a title in the config) starts on the exterior shot")
	check(get_tree().paused, "the opening pauses play like the rest of the cold open")
	var title_seen := 0.0
	var steps := 0
	while intro.stage == "exterior" and steps < 4000:
		intro._process(0.02)
		title_seen = maxf(title_seen, intro.ext.title.modulate.a if intro.ext != null else title_seen)
		steps += 1
	check(title_seen >= 0.99, "the game's title came fully up on the way")
	check(intro.stage == "card" and intro.ext == null, "then it hands on to the time card (the exterior is gone)")
	check(intro.black.color.a == 1.0, "…over black, as the run information always was")
	check(intro.gore.modulate.a < 0.2, "…the handprint isn't up yet — it arrives with the card")
	intro.queue_free()
	await get_tree().process_frame
	check(not get_tree().paused, "freed mid-way → never leaves the game paused")
	# runs 2 and 3 skip it (they have no title screen)
	var again: CanvasLayer = IntroScript.new()
	again.title_text = ""
	add_child(again)
	await get_tree().process_frame
	check(again.stage == "card" and again.ext == null, "a later run opens straight on its time card")
	again.queue_free()
	await get_tree().process_frame


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
	check(e.speed == Ext.HURRY_SPEED and e.t < Ext.t_title_in(), "a key during the climb speeds it up — it doesn't cut")
	var guard := 0
	while e.t < Ext.t_title_in() + 0.5 and guard < 2000:
		intro._process(0.02)
		guard += 1
	check(e.speed == 1.0, "…and the title lands at its own pace")
	intro._input(ev)
	check(e.t >= Ext.t_out() - 0.001, "a key once the title is up goes straight to the fade out")
	guard = 0
	while intro.stage == "exterior" and guard < 400:
		intro._process(0.02)
		guard += 1
	check(intro.stage == "card", "…and on to the card")
	# a very long frame (the scene loading) does not skip the fade in
	var e2: Control = Ext.new()
	add_child(e2)
	await get_tree().process_frame
	e2.tick(1.5)
	check(e2.t <= 0.1 + 0.0001, "a long frame advances the clock by at most 0.1 s")
	e2.queue_free()
	intro.queue_free()
	await get_tree().process_frame


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
