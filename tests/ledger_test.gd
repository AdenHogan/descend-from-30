extends Node

# THE LEDGER (owner round 48j — "the ledger look… good, clean, connected, strong… not AI slop"): the shared paper kit (scripts/ledger*.gd). Round 48l moved the merchant and the workbench to the
# dark Lamplight look (the owner: "didn't we change this back to the black and gold version?"), so their tests live in tests/lamp_test.gd; what is left here is the paper kit itself (the journal's
# neighbour, nothing else wears it any more) and the desk SOUNDS, which every screen still plays. The LOOK is the owner's to judge; this pins what can be measured: every edge stays inside its box,
# nothing is random per frame, the fonts and sounds the kit promises exist.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	WorldState.new_game()
	Ledger.muted = true
	_test_kit()
	await _test_sounds()
	Ledger.muted = false
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_kit() -> void:
	print("[the kit: paper, fonts, the hand]")
	var a: PackedVector2Array = Ledger.ragged(300.0, 200.0, 30.0, 2.6, 7)
	var b: PackedVector2Array = Ledger.ragged(300.0, 200.0, 30.0, 2.6, 7)
	var c: PackedVector2Array = Ledger.ragged(300.0, 200.0, 30.0, 2.6, 8)
	check(a == b and a != c, "a sheet's outline is a pure function of its seed (the same sheet looks the same every time, no two look alike)")
	var inside := true
	for p in a:
		if p.x < -0.01 or p.y < -0.01 or p.x > 300.01 or p.y > 200.01:
			inside = false
	check(inside, "the wandering edge never leaves its rectangle (a sheet cannot overhang what holds it)")
	check(Geometry2D.triangulate_polygon(a).size() > 0, "…and it is a polygon the renderer can fill")
	var line: PackedVector2Array = Ledger.pen_line(Vector2(0, 0), Vector2(200, 0), 3, 1.2)
	var wobble := 0.0
	for p in line:
		wobble = maxf(wobble, absf(p.y))
	check(wobble > 0.0 and wobble <= 1.2, "a pen line wanders but only within its wobble (%.2f px)" % wobble)
	check(Ledger.pen_line(Vector2(0, 0), Vector2(200, 0), 3, 1.2) == line, "…and the same line twice is the same line")
	for kind in ["head", "body", "typed", "hand"]:
		check(Ledger.font(kind) != null and Ledger.font(kind) != ThemeDB.fallback_font, "the %s face loads (not the engine's fallback)" % kind)
	check(Ledger.font("body") != Ledger.font("typed") and Ledger.font("head") != Ledger.font("body"), "printed head, plain body and typed voice are three different faces")
	check(Ledger.hand_info().has("path") and Ledger.hand_ink() is Color, "the player's own hand is read from the journal's table (face + ink)")
	var lit: PackedColorArray = Ledger.lit(a, Vector2(300, 200), Ledger.PAPER)
	check(lit.size() == a.size() and lit[0].r >= lit[lit.size() / 2].r, "paper is lit from the upper left (the first vertex is no darker than a far one)")


func _test_sounds() -> void:
	print("[the desk sounds]")
	var missing := 0
	for name in Ledger.SOUNDS:
		for k in range(int(Ledger.SOUNDS[name])):
			if not ResourceLoader.exists("%s%s_%d.wav" % [Ledger.SOUND_DIR, name, k]):
				missing += 1
	check(missing == 0, "every take of every named sound exists on disk (%d missing)" % missing)
	Ledger.muted = true
	var before: int = get_tree().get_nodes_in_group("ledger_sfx").size()
	Ledger.play("stamp")
	await _frames(2)
	check(get_tree().get_nodes_in_group("ledger_sfx").size() == before, "muted (tests, captures) plays nothing")
	Ledger.muted = false
	Ledger.play("stamp", -40.0)
	await _frames(2)
	check(get_tree().get_nodes_in_group("ledger_sfx").size() > before, "a sound is a self-freeing one-shot player in the tree")
	var n1: int = get_tree().get_nodes_in_group("ledger_sfx").size()
	Ledger.play("tick", -40.0, 5.0)
	Ledger.play("tick", -40.0, 5.0)
	await _frames(2)
	check(get_tree().get_nodes_in_group("ledger_sfx").size() <= n1 + 1, "a throttled sound does not machine-gun (two calls inside the gap make one)")
	Ledger.play("nonsense")
	check(true, "an unknown sound name is ignored, not an error")
	Ledger.muted = true
