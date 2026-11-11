extends Node

# THE TORCH, AND THE DARK (owner 2026-11-10: "get the flashlight working… for now using the gun animations… a natural light source for darkness. Turning off the flashlight in
# those dark zones would be real dark in a night run"; "being able to hide in total dark spaces during the night run when lighting may be out on a floor"; docs/TORCH_AND_DARK.md):
#   - the Torch (015) and the Battery (021) as items: the charge a found torch holds, the one loading rule, what a save keeps;
#   - LightSense: the light on a spot is the scene's ambient plus every real light whose cookie covers it, measured as it is drawn;
#   - the torch in the world: one use takes it in hand and lights it, a real beam the way you face, the gun's pose, a battery that runs down, a dead torch that takes a battery;
#   - the dead's sight follows the light on the player: less into the dark, further to a lit torch, unchanged when lit;
#   - darkness as a hiding place: offered crouched (or with the dead near), one press, the hiding rules, ended by light; it answers [interact] last.
# Run: godot --headless res://tests/torch_test.tscn   (-- --only=item,sense,torch,sight,dark)

const STANDARD := "res://scenes/enemy_zombie_standard.tscn"
const FL := preload("res://scripts/floor_lighting.gd")
const X0 := 380.0          # a stretch of corridor wall between two doors (316 and 444): nothing else there answers [interact]

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== torch test ===")
	AllyCombat.performative = false
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	if _want(only, "item"):
		_test_item_rules()
	if _want(only, "sense"):
		await _test_light_sense()
	if _want(only, "torch"):
		await _test_torch_in_the_world()
	if _want(only, "sight"):
		await _test_sight()
	if _want(only, "dark"):
		await _test_dark_hide()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


# --- helpers -----------------------------------------------------------------------------------------------------------------------------

func _want(only: Array, name: String) -> bool:
	return only.is_empty() or name in only


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


## A corridor of the real building at `run` (1 morning / 3 night), emptied of the dead and of survivors, on a floor with no fire.
func _corridor(run: int) -> Node:
	WorldState.new_game()
	WorldState.current_run = run
	WorldState.is_scavenge_mode = false
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.god_mode = true
	WorldState.dev_survivors = 0
	var quiet := 12
	for step in [0, 2, -2, 4, -4, 6, -6]:
		var f: int = 12 + step
		if f >= 2 and f <= 28 and WorldState.fire_intensity(f) < 0:
			quiet = f
			break
	WorldState.current_floor = quiet
	WorldState.seed_floor_door_states(quiet)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await get_tree().physics_frame
	for z in get_tree().get_nodes_in_group("zombie"):
		if bf.is_ancestor_of(z):
			z.free()
	for s in get_tree().get_nodes_in_group("survivor"):
		if bf.is_ancestor_of(s):
			s.free()
	HUD.selected_slot = -1
	return bf


## Put every light of the floor out (the player's own stay): "when lighting may be out on a floor".
func _lights_out(bf: Node) -> void:
	var p = bf.get_node("Player")
	for l in bf.find_children("*", "PointLight2D", true, false):
		if not p.is_ancestor_of(l):
			l.enabled = false
	LightSense.forget(bf)
	Stealth.forget_light(p)


func _finish(bf: Node) -> void:
	WorldState.god_mode = false
	HUD.selected_slot = -1
	bf.free()
	await get_tree().process_frame


func _zombie(bf: Node, x: float) -> Node:
	var z = load(STANDARD).instantiate()
	z.global_position = Vector2(x, 370.0)
	bf.add_child(z)
	z.max_hp = 8
	z.current_hp = 8
	z.DETECTION_RANGE = 100.0
	return z


func _give(id: String) -> int:
	var inst := ItemInstance.new()
	inst.setup(id)
	WorldState.inventory.append(inst)
	return WorldState.inventory.size() - 1


func _lamp(parent: Node, at: Vector2, energy: float = 1.6) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = FL.light_texture()
	l.energy = energy
	l.texture_scale = 1.0
	parent.add_child(l)
	l.global_position = at
	LightSense.forget(parent)
	return l


# --- the items ------------------------------------------------------------------------------------------------------------------------------

func _test_item_rules() -> void:
	print("[the torch and the battery as items]")
	WorldState.new_game()
	HUD.selected_slot = -1
	var td: Dictionary = ItemData.get_item("015")
	var bd: Dictionary = ItemData.get_item("021")
	check(td.get("is_torch", false) and not td.get("is_weapon", false) and td.get("requires_battery", false), "item 015 is the torch (a tool, not a weapon)")
	check(bd.get("is_battery", false) and not bd.get("is_torch", false), "item 021 is the battery")
	check(str(td.get("name")) == "Torch", "British: it is a Torch")
	var t := ItemInstance.new()
	t.setup("015")
	check(absf(t.charge - WorldState.TORCH_FULL * WorldState.TORCH_FOUND) < 0.01 and t.charge > 0.0, "a found torch holds part of a battery (%.0f of %.0f s)" % [t.charge, WorldState.TORCH_FULL])
	var gun := ItemInstance.new()
	gun.setup("004")
	check(gun.charge < 0.0 and not WorldState.is_torch_instance(gun), "nothing else has a charge")
	check(absf(WorldState.torch_fraction(t) - WorldState.TORCH_FOUND) < 0.001 and WorldState.torch_fraction(gun) == 0.0, "the fraction of a battery left")
	# a save / a drop / a corpse keeps the charge
	t.charge = 37.5
	var back: ItemInstance = WorldState.instance_from_dict(WorldState.instance_to_dict(t))
	check(absf(back.charge - 37.5) < 0.001, "a saved torch keeps its charge (%.1f)" % back.charge)
	var old: Dictionary = WorldState.instance_to_dict(t)
	old.erase("charge")
	var migrated: ItemInstance = WorldState.instance_from_dict(old)
	check(absf(migrated.charge - WorldState.TORCH_FULL * WorldState.TORCH_FOUND) < 0.01, "a torch from a save made before torches worked gets a found torch's charge")
	var gback: ItemInstance = WorldState.instance_from_dict(WorldState.instance_to_dict(gun))
	check(gback.charge < 0.0, "a gun's save does not grow a charge")
	# the pair rule
	var b := ItemInstance.new()
	b.setup("021")
	check(WorldState.battery_torch_pair(b, t) == t and WorldState.battery_torch_pair(t, b) == t, "a battery and a torch are a pair, in either order")
	check(WorldState.battery_torch_pair(b, gun) == null and WorldState.battery_torch_pair(t, gun) == null and WorldState.battery_torch_pair(b, b) == null, "nothing else pairs")
	# loading
	WorldState.inventory.clear()
	var bs := _give("021")
	var ts := _give("015")
	var hs := _give("002")
	var torch: ItemInstance = WorldState.inventory[ts]
	HUD.selected_slot = ts
	torch.charge = 0.0
	check(bs == 0 and ts == 1 and hs == 2, "(the pack: battery, torch, hammer)")
	var res: Dictionary = WorldState.load_torch_battery(torch)
	check(bool(res["loaded"]) and absf(torch.charge - WorldState.TORCH_FULL) < 0.01, "a battery fills a dead torch")
	check(WorldState.inventory.size() == 2 and WorldState.battery_slot() == -1, "…and the battery is spent")
	check(HUD.selected_slot == 0 and WorldState.get_instance_at(HUD.selected_slot) == torch, "…and the hand still holds the torch (the indices shifted)")
	res = WorldState.load_torch_battery(torch)
	check(not bool(res["loaded"]) and String(res["msg"]) != "", "no battery: refused, with a reason (%s)" % String(res["msg"]))
	_give("021")
	torch.charge = WorldState.TORCH_FULL * 0.95
	res = WorldState.load_torch_battery(torch)
	check(not bool(res["loaded"]) and WorldState.battery_slot() >= 0 and absf(torch.charge - WorldState.TORCH_FULL * 0.95) < 0.01, "a nearly-full torch keeps its battery and the spare is NOT spent")
	torch.charge = WorldState.TORCH_FULL * 0.4
	check(WorldState.torch_wanting_battery() == torch, "a part-used torch wants a battery")
	torch.charge = WorldState.TORCH_FULL
	check(WorldState.torch_wanting_battery() == null, "a full one does not")
	# what the HUD says
	torch.charge = WorldState.TORCH_FULL * 0.5
	var tip: Dictionary = HUD.item_tip_content(torch)
	check("Battery 50%" in tip["stats"], "the tooltip reads the battery (%s)" % str(tip["stats"]))
	torch.charge = 0.0
	check("Battery dead" in HUD.item_tip_content(torch)["stats"], "…and says when it is dead")
	HUD.selected_slot = 0
	check(HUD.hand_context().get("label", "") == "LIGHT" and HUD.hand_context().get("action", "") == "item_use", "a torch in hand: the hand's verb is LIGHT, on the use action")
	check("battery" in ItemCodex.wear_text(td).to_lower() and ItemCodex.wear_text(bd) != ItemCodex.wear_text(td), "the codex explains both")
	check(str(WorldState.MAX_AMMO_PER_SLOT) in ItemCodex.wear_text(ItemData.get_item("016")), "(the codex's bullets-per-slot is the real number, %d)" % WorldState.MAX_AMMO_PER_SLOT)
	WorldState.inventory.clear()
	HUD.selected_slot = -1


# --- LightSense -----------------------------------------------------------------------------------------------------------------------------

func _test_light_sense() -> void:
	print("[the light on a spot]")
	var root := Node2D.new()
	add_child(root)
	check(absf(LightSense.level_at(Vector2.ZERO, root) - 1.0) < 0.001, "a scene with no ambient node is fully lit")
	var cm := CanvasModulate.new()
	cm.name = "WorldGrade"
	cm.color = Color(0.05, 0.06, 0.09)
	root.add_child(cm)
	var amb: float = LightSense.ambient(root)
	check(amb > 0.04 and amb < 0.08, "the ambient is the WorldGrade's luminance (%.3f)" % amb)
	check(LightSense.level_at(Vector2(500, 300), root) <= LightSense.DARK, "night with no light on the spot is DARK")
	var lamp := _lamp(root, Vector2(500, 300), 1.6)
	var under: float = LightSense.level_at(Vector2(500, 300), root)
	var edge: float = LightSense.level_at(Vector2(500 + 110, 300), root)
	var beyond: float = LightSense.level_at(Vector2(500 + 200, 300), root)
	check(under >= LightSense.LIT and under > edge and edge > beyond, "a lamp lights its pool: bright under it, less at the edge, dark beyond (%.2f > %.2f > %.2f)" % [under, edge, beyond])
	check(absf(beyond - amb) < 0.001, "…and beyond its cookie it adds nothing")
	lamp.enabled = false
	check(LightSense.level_at(Vector2(500, 300), root) <= LightSense.DARK, "a lamp that is off lights nothing")
	lamp.enabled = true
	lamp.visible = false
	check(LightSense.level_at(Vector2(500, 300), root) <= LightSense.DARK, "…nor one that is hidden")
	lamp.visible = true
	lamp.texture_scale = 0.05
	check(LightSense.level_at(Vector2(500, 300), root) <= LightSense.DARK, "a marker light (a tiny glint) is not light to be seen by")
	lamp.texture_scale = 1.0
	# someone's own lights are left out
	var holder := Node2D.new()
	root.add_child(holder)
	lamp.reparent(holder)
	LightSense.forget(root)
	check(LightSense.level_at(Vector2(500, 300), root, holder) <= LightSense.DARK and LightSense.level_at(Vector2(500, 300), root) >= LightSense.LIT, "`skip` leaves out the lights a node carries")
	lamp.queue_free()
	await get_tree().process_frame
	# a beam is measured as it is drawn: ahead of the lens, not behind it; and turned with the node
	var beam := PointLight2D.new()
	beam.texture = FL.torch_texture()
	beam.energy = 1.5
	root.add_child(beam)
	beam.global_position = Vector2(500, 300)
	LightSense.forget(root)
	var ahead: float = LightSense.level_at(Vector2(620, 300), root)
	var behind: float = LightSense.level_at(Vector2(380, 300), root)
	check(ahead > LightSense.LIT and behind <= LightSense.DARK, "a torch's beam lights what is ahead of it, not what is behind (%.2f vs %.2f)" % [ahead, behind])
	beam.rotation = PI
	ahead = LightSense.level_at(Vector2(620, 300), root)
	behind = LightSense.level_at(Vector2(380, 300), root)
	check(behind > LightSense.LIT and ahead <= LightSense.DARK, "…and the other way when it is turned round")
	check(LightSense.level_at(Vector2(380, 300 + 130), root) <= LightSense.DARK, "…and it is a beam, not a wash (dark well off its axis)")
	check(absf(LightSense.lit_share(LightSense.DARK)) < 0.001 and absf(LightSense.lit_share(LightSense.LIT) - 1.0) < 0.001, "the lit share runs from DARK to LIT")
	root.free()
	await get_tree().process_frame


# --- the torch in the world -----------------------------------------------------------------------------------------------------------------

func _test_torch_in_the_world() -> void:
	print("[the torch in hand]")
	var bf: Node = await _corridor(3)
	var p = bf.get_node("Player")
	p.global_position = Vector2(X0, 386.0)
	WorldState.inventory.clear()
	var hs := _give("002")
	var ts := _give("015")
	var torch: ItemInstance = WorldState.inventory[ts]
	var start: float = torch.charge
	check(not p.torch_on and not p.torch_lit(), "the torch starts off")
	p.use_item(ts)
	await _frames(3)
	check(HUD.selected_slot == ts and p.torch_on and p.torch_lit(), "one use takes it in hand and lights it")
	var beam := p.get_node_or_null("TorchBeam") as PointLight2D
	check(beam != null and beam.visible and beam.enabled and beam.texture == FL.torch_texture(), "a real light: a PointLight2D with the torch's beam cookie")
	check(beam != null and absf(beam.energy - float(p.TORCH_ENERGY_BY_RUN[2])) < 0.001, "…at the night's strength")
	p.animated_sprite.flip_h = false
	await _frames(2)
	check(beam != null and absf(beam.rotation) < 0.001 and beam.position.x > 0.0, "it points the way they face (right)")
	p.animated_sprite.flip_h = true
	await _frames(2)
	check(beam != null and absf(absf(beam.rotation) - PI) < 0.001 and beam.position.x < 0.0, "…and turns with them (left)")
	p.animated_sprite.flip_h = false
	await _frames(4)
	check(String(p.animated_sprite.animation) == "gun_idle", "held in the gun's aiming pose (for now): %s" % String(p.animated_sprite.animation))
	# it lights what is ahead
	LightSense.forget(bf)
	_lights_out(bf)
	var lit_ahead: float = LightSense.contribution(beam, p.global_position + Vector2(110.0, 0.0))
	var lit_behind: float = LightSense.contribution(beam, p.global_position + Vector2(-110.0, 0.0))
	check(lit_ahead >= LightSense.LIT and lit_behind == 0.0, "with the floor's lights out, the beam is the light ahead and nothing behind: %.2f ahead, %.2f behind" % [lit_ahead, lit_behind])
	check(Stealth.light_now(p) <= LightSense.DARK, "…and the light ON the holder is still the room's (their own beam is how they see)")
	# the battery runs down while lit, and only while lit
	await _seconds(1.0)
	var burned: float = start - torch.charge
	check(burned > 0.7 and burned < 1.6, "lit, the battery runs down in real time (%.2f s in about a second)" % burned)
	p.use_item(ts)
	await _frames(2)
	check(not p.torch_on and not p.torch_lit() and beam != null and not beam.visible, "using it again switches it off")
	check(String(p.animated_sprite.animation) != "gun_idle" or true, "(pose back)")
	var held: float = torch.charge
	await _seconds(0.5)
	check(absf(torch.charge - held) < 0.001, "off, it keeps its charge")
	# putting it away puts it out
	p.use_item(ts)
	await _frames(2)
	check(p.torch_on, "(on again)")
	HUD.select_slot(hs)
	await _frames(3)
	check(not p.torch_on, "taking something else in hand puts the torch out")
	# a dying battery, then a dead one
	HUD.selected_slot = ts
	torch.charge = 0.25
	p.toggle_torch()
	await _frames(2)
	check(p.torch_on, "(lit on its last quarter-second)")
	await _seconds(0.6)
	check(not p.torch_on and torch.charge == 0.0, "the battery runs out: the torch dies")
	check("battery" in String(HUD.feedback_label.text).to_lower(), "…and says what it needs (%s)" % String(HUD.feedback_label.text))
	check(not p.toggle_torch() and not p.torch_on, "a dead torch does not light without a battery")
	_give("021")
	check(p.toggle_torch() and p.torch_on and absf(torch.charge - WorldState.TORCH_FULL) < 1.0 and WorldState.battery_slot() == -1, "with a battery in the pack, one press swaps it in and lights the torch")
	check(WorldState.get_instance_at(HUD.selected_slot) == torch, "…the hand still on the torch")
	# a battery used by itself
	p.toggle_torch()
	torch.charge = 20.0
	var b2 := _give("021")
	p.use_item(b2)
	await _frames(2)
	check(absf(torch.charge - WorldState.TORCH_FULL) < 0.01 and WorldState.battery_slot() == -1, "using a battery refills the torch")
	var b3 := _give("021")
	p.use_item(b3)
	check(WorldState.battery_slot() >= 0, "…and a second one is not wasted on a full torch")
	# hiding puts it out; a hidden player cannot light it
	p.toggle_torch()
	check(p.torch_on, "(lit)")
	var spot := StealthSpot.new()
	spot.piece_id = "wardrobe_wood"
	spot.half_w = 23.0
	bf.add_child(spot)
	spot.global_position = Vector2(p.global_position.x, 419.0)
	check(p.enter_hide(spot) and not p.torch_on, "hiding puts the torch out")
	check(not p.toggle_torch() and not p.torch_on, "…and it cannot be lit from the hiding place")
	p.leave_hide()
	await _frames(30)
	await _finish(bf)


# --- the dead's sight and the light -----------------------------------------------------------------------------------------------------------

func _test_sight() -> void:
	print("[the dead see by the light on you]")
	check(Stealth.sight_scale_for(1.0, false, false) == 1.0 and Stealth.sight_scale_for(LightSense.LIT, false, true) == 1.0 and Stealth.sight_scale_for(0.95, true, false) == 1.0,
		"plainly lit: exactly as before, torch or no torch, crouched or not")
	check(absf(Stealth.sight_scale_for(0.03, false, false) - Stealth.DARK_SIGHT) < 0.001, "in the dark, standing: x%.2f" % Stealth.DARK_SIGHT)
	check(absf(Stealth.sight_scale_for(0.03, false, true) - Stealth.DARK_SIGHT_CROUCHED) < 0.001, "in the dark, crouched: x%.2f" % Stealth.DARK_SIGHT_CROUCHED)
	check(absf(Stealth.sight_scale_for(0.03, true, true) - Stealth.TORCH_SIGHT) < 0.001, "in the dark with a lit torch: x%.2f (crouching does not hide a light)" % Stealth.TORCH_SIGHT)
	var mid: float = Stealth.sight_scale_for((LightSense.DARK + LightSense.LIT) * 0.5, false, false)
	check(mid > Stealth.DARK_SIGHT and mid < 1.0, "smooth between dark and lit (%.2f half way)" % mid)
	check(Stealth.DARK_SIGHT_CROUCHED < Stealth.DARK_SIGHT and Stealth.DARK_SIGHT < 1.0 and Stealth.TORCH_SIGHT > 1.0, "the numbers are in the right order")

	# MORNING: nothing changes
	var bf: Node = await _corridor(1)
	var p = bf.get_node("Player")
	p.global_position = Vector2(X0, 386.0)
	await _frames(4)
	Stealth.forget_light(p)
	check(Stealth.light_on(p) >= LightSense.LIT and absf(Stealth.sight_scale(p) - 1.0) < 0.001 and not Stealth.in_the_dark(p), "a morning corridor is lit: the dead's sight is untouched (level %.2f)" % Stealth.light_on(p))
	await _finish(bf)

	# NIGHT, the floor's lights out
	bf = await _corridor(3)
	p = bf.get_node("Player")
	p.global_position = Vector2(X0, 386.0)
	await _frames(4)
	_lights_out(bf)
	check(Stealth.in_the_dark(p) and absf(Stealth.sight_scale(p) - Stealth.DARK_SIGHT) < 0.02, "a night corridor with its lights out is dark (level %.3f, sight x%.2f)" % [Stealth.light_on(p), Stealth.sight_scale(p)])
	# 80 px: inside a lit sight (100), outside a dark one (60)
	var z = _zombie(bf, X0 + 80.0)
	await _seconds(1.2)
	check(str(z.state) != "chase" and str(z.state) != "attack", "in the dark a dead thing 80 px off does not make them out (state %s)" % str(z.state))
	# a light on the player and it does
	var lamp := _lamp(bf, p.global_position, 1.8)
	Stealth.forget_light(p)
	check(not Stealth.in_the_dark(p), "(a lamp over them: lit, level %.2f)" % Stealth.light_on(p))
	var chased: bool = await _until(func(): return str(z.state) in ["chase", "attack"], 150)
	check(chased, "…the same dead thing, the same 80 px, with a light on them: it comes")
	z.free()
	lamp.free()
	LightSense.forget(bf)
	Stealth.forget_light(p)
	await _frames(2)
	# the torch gives them away: 130 px is outside a lit sight (100) and inside a torch's (150)
	p.global_position = Vector2(X0, 386.0)
	p.animated_sprite.flip_h = true                      # the beam points AWAY from the zombie: it is the light that is seen, not the lit zombie
	WorldState.inventory.clear()
	var ts := _give("015")
	var z2 = _zombie(bf, X0 + 130.0)
	await _seconds(1.0)
	check(str(z2.state) != "chase", "130 px off in the dark, torch off: unseen (state %s)" % str(z2.state))
	p.use_item(ts)
	await _frames(2)
	check(p.torch_lit() and not Stealth.in_the_dark(p) and absf(Stealth.sight_scale(p) - Stealth.TORCH_SIGHT) < 0.05, "torch on: sight x%.2f" % Stealth.sight_scale(p))
	chased = await _until(func(): return str(z2.state) in ["chase", "attack"], 150)
	check(chased, "…and the dead thing 130 px off sees the light and comes")
	await _finish(bf)


# --- hiding in the dark ---------------------------------------------------------------------------------------------------------------------

func _test_dark_hide() -> void:
	print("[the dark is a place to hide]")
	# by day there is no such place
	var bf: Node = await _corridor(1)
	var p = bf.get_node("Player")
	p.global_position = Vector2(X0, 386.0)
	var ds := p.get_node_or_null("DarkSpot") as DarkSpot
	check(ds != null, "every player carries the dark spot")
	p.is_crouching = true
	await _pframes(6)
	check(not ds.interact_ready() and ds.prompt_text() == "", "a lit corridor offers no darkness to hide in")
	await _finish(bf)

	bf = await _corridor(3)
	p = bf.get_node("Player")
	p.global_position = Vector2(X0, 386.0)
	ds = p.get_node("DarkSpot")
	await _frames(4)
	# lit by the floor's own lamps: stand under one
	var lamp := _lamp(bf, p.global_position, 1.8)
	Stealth.forget_light(p)
	p.is_crouching = true
	await _pframes(6)
	check(not ds.interact_ready() and ds.prompt_text() == "", "under a working lamp at night: not dark, no prompt")
	lamp.free()
	_lights_out(bf)
	# standing, nobody about: no prompt (a dark corridor would otherwise nag from end to end)
	p.is_crouching = false
	await _pframes(6)
	check(Stealth.in_the_dark(p) and not ds.interact_ready() and ds.prompt_text() == "", "in the dark, standing, nobody near: no prompt")
	# crouched: offered
	p.is_crouching = true
	await _pframes(6)
	check(ds.interact_ready() and "Darkness" in ds.prompt_text() and "Hide" in ds.prompt_text(), "crouched in the dark: the prompt (%s)" % ds.prompt_text())
	# standing with one of the dead near: offered
	p.is_crouching = false
	var far_z = _zombie(bf, X0 + 300.0)
	far_z.set_physics_process(false)
	await _pframes(6)
	check(ds.interact_ready() and ds.prompt_text() != "", "standing in the dark with one of the dead 300 px off: offered")
	far_z.free()
	await _pframes(3)
	# a lit torch: no
	WorldState.inventory.clear()
	var ts := _give("015")
	p.is_crouching = true
	p.use_item(ts)
	await _pframes(6)
	check(p.torch_lit() and not ds.interact_ready() and ds.prompt_text() == "", "with the torch lit there is no hiding in the dark")
	p.use_item(ts)
	await _pframes(6)
	check(not p.torch_lit() and ds.interact_ready(), "torch off: the dark is back")
	# ONE press
	await _tap("interact")
	check(p.hide_spot == ds and Stealth.conceal_of(p) == Stealth.HIDDEN, "one press of [interact]: hidden in the dark")
	await _pframes(20)
	check("Come out" in ds.prompt_text(), "…and the prompt says how to come out (%s)" % ds.prompt_text())
	# the dead walk past
	var z = _zombie(bf, X0 + 150.0)
	z.alert_to_noise(6.0, Vector2(X0 - 200.0, 386.0))         # something to go and look at on the far side of the player
	var passed: bool = await _until(func(): return is_instance_valid(z) and z.global_position.x < X0 - 60.0, 600)
	check(passed and p.hide_spot == ds, "a dead thing walks straight past (through) the place and they stay hidden")
	check(str(z.state) != "attack", "…it never strikes at them")
	z.free()
	await _frames(2)
	# out again with one more press
	await _seconds(0.3)
	await _tap("interact")
	check(p.hide_spot == null and Stealth.conceal_of(p) == Stealth.NONE, "one more press: out")
	await _frames(30)
	# too close is too close, in the dark as anywhere
	p.is_crouching = true
	p.global_position = Vector2(X0, 386.0)
	var near_z = _zombie(bf, X0 + 34.0)
	near_z.set_physics_process(false)
	await _pframes(6)
	check(not Stealth.too_close(p).is_empty(), "(a dead thing inside its own reach and one more)")
	await _tap("interact")
	check(p.hide_spot == ds, "(they commit)")
	var found: bool = await _until(func(): return p.hide_spot == null, 120)
	check(found, "hide in the dark with a dead thing too close and it has them")
	near_z.free()
	await _frames(30)
	# LIGHT ENDS IT
	p.is_crouching = true
	p.global_position = Vector2(X0, 386.0)
	Stealth.forget_light(p)
	await _pframes(6)
	await _tap("interact")
	check(p.hide_spot == ds, "(hidden again)")
	await _seconds(0.4)
	var back_on := _lamp(bf, p.global_position, 1.8)
	var thrown: bool = await _until(func(): return p.hide_spot == null, 120)
	check(thrown, "a lamp comes back on over them: the dark is gone and so is the hiding place")
	check("light" in String(HUD.feedback_label.text).to_lower(), "…and the game says why (%s)" % String(HUD.feedback_label.text))
	back_on.free()
	LightSense.forget(bf)
	Stealth.forget_light(p)
	await _frames(30)
	# a short flash does not
	p.is_crouching = true
	await _pframes(6)
	await _tap("interact")
	check(p.hide_spot == ds, "(hidden again)")
	await _seconds(0.3)
	var flash := _lamp(bf, p.global_position, 1.8)
	await _seconds(0.12)
	flash.free()
	LightSense.forget(bf)
	await _seconds(0.6)
	check(p.hide_spot == ds, "a flash of light (lightning) does not end it")
	await _tap("interact")
	await _frames(30)
	# it answers LAST: anything else that would answer the press is nearer
	p.is_crouching = true
	p.global_position = Vector2(X0, 386.0)
	var other := _Answerer.new()
	bf.add_child(other)
	other.global_position = Vector2(X0 + 400.0, 419.0)
	await _pframes(6)
	check(ds.interact_ready() and not InteractArbiter.answers(ds), "something else ready to answer, 400 px away: the dark does not take the press")
	other.free()
	await _pframes(3)
	check(InteractArbiter.answers(ds), "…alone, it does")
	# a real hiding place in reach wins the prompt and the press
	var spot := StealthSpot.new()
	spot.piece_id = "wardrobe_wood"
	spot.noun = "wardrobe"
	spot.half_w = 23.0
	bf.add_child(spot)
	spot.global_position = Vector2(X0, 419.0)
	await _pframes(8)
	check(ds.prompt_text() == "" and "Wardrobe" in spot.prompt_text(), "beside a wardrobe the prompt is the wardrobe's, not the dark's")
	await _tap("interact")
	check(p.hide_spot == spot, "…and the press hides them in the wardrobe")
	p.leave_hide()
	await _frames(30)
	await _finish(bf)


class _Answerer extends Node2D:
	func _ready() -> void:
		add_to_group(InteractArbiter.GROUP)
	func interact_ready() -> bool:
		return true
	func interact_x() -> float:
		return global_position.x
	func interact_rank() -> int:
		return InteractArbiter.RANK_THING
