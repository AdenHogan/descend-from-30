extends Node

# MUSIC MOODS + THE MASTER LIMITER (owner round 46: "static and noise in the audio… a more pulse pounding track… for entering breach rooms").
#   godot --headless res://tests/music_test.tscn
# The cross-fade runs on REAL time (Game._process), so the test scales it up (`Game.music_fade_scale`) and waits a few frames.

const RoomScript := preload("res://scripts/room.gd")

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== music test ===")
	WorldState.dev_seed = 5151
	WorldState.new_game()
	WorldState.is_first_run = false
	Game.music_fade_scale = 400.0
	_test_buses()
	_test_streams()
	await _test_claims()
	await _test_handover()
	await _test_breach_room()
	Game.music_fade_scale = 1.0
	WorldState.dev_seed = 0
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


## Wait until the mood gains settle (the scaled fade takes a few frames).
func _settle() -> void:
	for i in range(8):
		await get_tree().process_frame


func _test_buses() -> void:
	print("[buses: a limiter on Master, music on its own bus]")
	var master := AudioServer.get_bus_index("Master")
	var lims := 0
	var lim: AudioEffectLimiter = null
	for i in range(AudioServer.get_bus_effect_count(master)):
		var e := AudioServer.get_bus_effect(master, i)
		if e is AudioEffectLimiter:
			lims += 1
			lim = e
	check(lims == 1, "Master carries exactly one limiter (%d)" % lims)
	check(lim != null and lim.ceiling_db <= -0.5, "…with a ceiling under full scale, so summed peaks round off instead of clipping (%.1f dB)" % (lim.ceiling_db if lim != null else 0.0))
	Game._ensure_master_limiter()
	var again := 0
	for i in range(AudioServer.get_bus_effect_count(master)):
		if AudioServer.get_bus_effect(master, i) is AudioEffectLimiter:
			again += 1
	check(again == 1, "…and asking again never stacks a second one")
	check(AudioServer.get_bus_index(Game.MUSIC_BUS) != -1, "a Music bus exists")
	check(Game.music_player.bus == Game.MUSIC_BUS and Game.breach_player.bus == Game.MUSIC_BUS and Game.clear_player.bus == Game.MUSIC_BUS and Game.clear_hit_player.bus == Game.MUSIC_BUS, "every music player rides it (bed, pulse, won song, win hit)")
	check(AudioServer.get_bus_index(Game.ENEMY_BUS) != -1 and Game.music_player.bus != Game.ENEMY_BUS, "the enemy bus is still its own, and the music is not on it")


func _test_streams() -> void:
	print("[streams: three loops, stereo, loopable]")
	for mood in ["calm", "breach", "breach_clear"]:
		var s = load(String(Game.MUSIC_MOODS[mood]["stream"]))
		check(s is AudioStreamOggVorbis, "%s: %s loads as Ogg Vorbis" % [mood, String(Game.MUSIC_MOODS[mood]["stream"]).get_file()])
		if s is AudioStreamOggVorbis:
			check(s.loop, "%s: set to loop" % mood)
			check(s.get_length() > 20.0 and s.get_length() < 40.0, "%s: a loop of a sensible length (%.1f s)" % [mood, s.get_length()])
	check(Game.music_player.playing, "the exploration bed is playing from the start")
	check(not Game.breach_player.playing and not Game.clear_player.playing, "the breach track and its won twin are stopped until something claims them")
	var pulse = load(String(Game.MUSIC_MOODS["breach"]["stream"]))
	var won = load(String(Game.MUSIC_MOODS["breach_clear"]["stream"]))
	check(absf(pulse.get_length() - won.get_length()) < 0.02, "the pulse and its won twin are the SAME length (%.3f / %.3f s) — they can start on the same beat" % [pulse.get_length(), won.get_length()])
	check(Game.mood_family("breach") == "pulse" and Game.mood_family("breach_clear") == "pulse" and Game.mood_family("calm") == "", "the two are one family; the bed is its own thing")
	var hit = load(Game.CLEAR_HIT_STREAM)
	check(hit is AudioStreamOggVorbis and not hit.loop and hit.get_length() > 2.0, "the win hit is a one-shot (%.1f s)" % (hit.get_length() if hit != null else 0.0))


func _test_claims() -> void:
	print("[claims: the newest wins, a release or a freed node hands back, nothing can strand the pulse]")
	await _settle()
	check(Game.music_mood == "calm" and Game.wanted_music_mood() == "calm", "no claim: calm")
	check(Game.music_player.volume_db > -20.0 and Game.breach_player.volume_db <= -60.0, "…the bed audible, the pulse silent")
	var a := Node.new()
	add_child(a)
	Game.music_claim(a, "breach")
	Game.music_claim(a, "breach")
	check(Game._music_claims.size() == 1, "a node claiming twice holds ONE claim")
	await _settle()
	check(Game.music_mood == "breach", "claimed: the mood is breach")
	check(Game.breach_player.playing and Game.breach_player.volume_db > -15.0, "…the pulse is playing and audible (%.1f dB)" % Game.breach_player.volume_db)
	check(Game.music_player.volume_db <= -60.0, "…the bed is ducked right down (%.1f dB) — it keeps its place, it is not stopped" % Game.music_player.volume_db)
	check(Game.music_player.playing, "…the bed is still playing underneath")
	# the pause menu does not stop a cross-fade (Game runs while the tree is paused)
	get_tree().paused = true
	Game.music_release(a)
	await _settle()
	get_tree().paused = false
	check(Game.music_mood == "calm" and not Game.breach_player.playing, "released (even while paused): back to calm, the pulse stopped")
	check(Game.music_player.volume_db > -20.0, "…the bed is back up (%.1f dB)" % Game.music_player.volume_db)
	# a freed node can never leave the pulse stuck on
	var b := Node.new()
	add_child(b)
	Game.music_claim(b, "breach")
	await _settle()
	check(Game.music_mood == "breach", "a second node claims it")
	b.free()
	await _settle()
	check(Game.music_mood == "calm" and Game._music_claims.is_empty(), "…and when that node is freed the claim goes with it")
	# a node that leaves the tree (not freed) is also dropped
	var c := Node.new()
	add_child(c)
	Game.music_claim(c, "breach")
	remove_child(c)
	await _settle()
	check(Game.music_mood == "calm", "a claimant out of the tree is dropped too")
	c.free()
	# an unknown mood is refused
	var d := Node.new()
	add_child(d)
	Game.music_claim(d, "polka")
	check(Game._music_claims.is_empty(), "an unknown mood is refused")
	d.free()
	# the pulse starts over on each entry
	var e := Node.new()
	add_child(e)
	Game.music_claim(e, "breach")
	await _settle()
	check(Game.breach_player.playing and Game.breach_player.get_playback_position() < 2.0, "each entry starts the pulse from its first beat (%.2f s in)" % Game.breach_player.get_playback_position())
	Game.music_release(e)
	e.free()
	await _settle()


func _test_handover() -> void:
	print("[the won song: a hand-over on the beat inside the pulse family, one hit, and the bed under both]")
	check(is_equal_approx(Game.step_position(10.0, 27.4286), 10.0) and absf(Game.step_position(30.0, 27.4286) - 2.5714) < 0.01 and Game.step_position(-3.0, 27.4286) == 0.0 and Game.step_position(5.0, 0.0) == 0.0,
			"the in-step start position wraps a longer sibling and never goes negative")
	var a := Node.new()
	add_child(a)
	Game.music_claim(a, "breach")
	await _settle()
	check(Game.music_mood == "breach" and Game.breach_player.playing and not Game.clear_player.playing, "the pulse is playing alone")
	var hits0: int = Game.clear_hits
	Game.music_claim(a, "breach_clear")
	await get_tree().process_frame
	check(Game.music_mood == "breach_clear", "the node turns its claim to the won song: mood breach_clear")
	check(Game.clear_hits == hits0 + 1, "…and the win hit fires, once (%d)" % (Game.clear_hits - hits0))
	check(Game.clear_hit_player.playing, "…and it is sounding")
	check(Game.clear_player.playing and Game.last_step_from == "breach", "the won loop did NOT start from its first beat: it came in on the beat the pulse was on (stepped in beside '%s')" % Game.last_step_from)
	await _settle()
	check(Game.clear_player.volume_db > -15.0 and Game.breach_player.volume_db <= -60.0 and not Game.breach_player.playing, "the pulse has handed over: the won song up (%.1f dB), the pulse stopped" % Game.clear_player.volume_db)
	check(Game.music_player.volume_db <= -60.0 and Game.music_player.playing, "the bed stays ducked under it, still playing")
	# the same claim again is not a second hit
	Game.music_claim(a, "breach_clear")
	await _settle()
	check(Game.clear_hits == hits0 + 1, "claiming the same mood again does not fire the hit twice")
	# trouble comes back: straight back to the fight, and no hit (it is not a win)
	Game.music_claim(a, "breach")
	await _settle()
	check(Game.music_mood == "breach" and Game.breach_player.playing and not Game.clear_player.playing and Game.clear_hits == hits0 + 1, "the fight starting again flips it back to the pulse — and that is not a win, so no hit")
	# a hand-over crosses fast; a hand-back to the bed does not
	Game.music_fade_scale = 1.0
	Game.music_claim(a, "breach_clear")
	await get_tree().create_timer(0.7).timeout
	check(Game._mood_gain["breach_clear"] > 0.95 and Game._mood_gain["breach"] < 0.05, "a pulse hand-over is over inside a second (won %.2f, pulse %.2f)" % [Game._mood_gain["breach_clear"], Game._mood_gain["breach"]])
	Game.music_release(a)
	await get_tree().create_timer(0.7).timeout
	check(Game._mood_gain["breach_clear"] > 0.5 and Game._mood_gain["calm"] < 0.5, "…but the way back to the bed is slow (won %.2f, bed %.2f after 0.7 s)" % [Game._mood_gain["breach_clear"], Game._mood_gain["calm"]])
	Game.music_fade_scale = 400.0
	await _settle()
	check(Game.music_mood == "calm" and not Game.clear_player.playing and not Game.breach_player.playing, "released: calm, both pulse-family players stopped")
	a.free()
	# a freed claimant on the won song can never strand it
	var b := Node.new()
	add_child(b)
	Game.music_claim(b, "breach_clear")
	await _settle()
	check(Game.music_mood == "breach_clear" and Game.clear_player.playing and Game.last_step_from == "", "a claimant on the won song alone starts it from the top (no sibling to step in beside)")
	b.free()
	await _settle()
	check(Game.music_mood == "calm" and not Game.clear_player.playing, "…and freeing that node drops it")


func _room(apt: String) -> Node:
	WorldState.current_apartment_id = apt
	WorldState.current_floor = WorldState._apartment_floor(apt)
	WorldState.spawn_source = ""
	WorldState.set_door_state(apt, WorldState.DoorState.BREACHED)
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	return room


func _find_breach() -> String:
	for f in range(4, 25):
		if not WorldState.gun_cabinets_on_floor(f).is_empty():
			continue
		for i in range(1, 6):
			var apt := str(f) + "0" + str(i)
			var burnt: bool = WorldState.apartment_fire_stage(f, i) in [WorldState.FIRE_CHARRED, WorldState.FIRE_BLAZE]
			if not burnt and WorldState.cabinet_for_key_room(apt) == "":
				return apt
	return ""


func _test_breach_room() -> void:
	print("[a breach flat: the pulse takes over on entry, hands back when the last of the dead is down, and goes with the room]")
	WorldState.current_run = 2
	WorldState.god_mode = true
	var apt := _find_breach()
	check(apt != "", "found a breach flat (%s)" % apt)
	if apt == "":
		return
	var room := _room(apt)
	for i in range(10):
		await get_tree().physics_frame
	var alive := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if room.is_ancestor_of(z) and z.get("is_dead") != true:
			alive += 1
	check(alive > 0, "the flat's pack is standing (%d)" % alive)
	check(room.breach_threat_alive(), "…so the room reports a live threat")
	await _settle()
	check(Game.music_mood == "breach", "entering it: the mood is breach")
	check(Game.breach_player.playing and Game.breach_player.volume_db > -15.0, "…the pulse is up (%.1f dB)" % Game.breach_player.volume_db)
	# it does not hand back while any of them stands …
	room._breach_music_tick(5.0)
	check(Game.music_mood == "breach", "a tick with the dead still standing keeps the pulse")
	# … but once they are all down the SAME SONG turns to its won self — it does not drop away
	for z in get_tree().get_nodes_in_group("zombie"):
		if room.is_ancestor_of(z):
			z.free()
	room._entrant_todo.clear()
	check(not room.breach_threat_alive(), "with the last of them gone the room reports no threat")
	var hits0: int = Game.clear_hits
	room._breach_music_tick(5.0)
	await _settle()
	check(Game.music_mood == "breach_clear" and Game.clear_player.playing and not Game.breach_player.playing, "the last one down: the pulse turns into the victory loop (mood %s)" % Game.music_mood)
	check(Game.clear_hits == hits0 + 1, "…with the win hit, once")
	check(room._breach_music_phase == "won", "the room is in its won phase (%s)" % room._breach_music_phase)
	# it stays on — a long while after the room is clear
	room._breach_music_tick(room.BREACH_WON_HOLD * 0.5)
	await _settle()
	check(Game.music_mood == "breach_clear", "half the hold later it is still playing (the old rule dropped it half a second after the last kill)")
	# someone comes in again: back to the fight, no second hit
	room._entrant_todo.append({"key": "x", "delay": 1.0})
	room._breach_music_tick(1.0)
	await _settle()
	check(Game.music_mood == "breach" and room._breach_music_phase == "fight" and Game.clear_hits == hits0 + 1, "a late arrival flips it back to the pulse (no hit)")
	room._entrant_todo.clear()
	room._breach_music_tick(1.0)
	await _settle()
	check(Game.music_mood == "breach_clear" and Game.clear_hits == hits0 + 2, "and once they are down again it is the victory loop again, with its hit")
	# it holds for a fixed time and then drains back to the bed
	room._breach_music_tick(room.BREACH_WON_HOLD + 1.0)
	await _settle()
	check(Game.music_mood == "calm" and not Game.clear_player.playing and room._breach_music_phase == "", "after the hold it hands back to the bed")
	room.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	# leaving the flat mid-fight must never strand the pulse
	var room2 := _room(apt)
	WorldState.killed_zombies.clear()
	WorldState.zombie_positions.clear()
	for i in range(10):
		await get_tree().physics_frame
	await _settle()
	var on := Game.music_mood == "breach"
	check(on or not room2.breach_threat_alive(), "a second entry claims the pulse again (mood %s)" % Game.music_mood)
	room2.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _settle()
	check(Game.music_mood == "calm" and Game._music_claims.is_empty(), "leaving the flat mid-fight (the room freed) can never leave the pulse stuck on")
	# an ordinary (non-breach) flat does not claim it
	var plain := ""
	for f in range(4, 20):
		for i in range(1, 6):
			var a2 := str(f) + "0" + str(i)
			if WorldState.get_door_state(a2) != WorldState.DoorState.BREACHED and plain == "":
				plain = a2
	WorldState.current_apartment_id = plain
	WorldState.current_floor = WorldState._apartment_floor(plain)
	WorldState.set_door_state(plain, WorldState.DoorState.OPEN)
	var room3 = load("res://scenes/room.tscn").instantiate()
	add_child(room3)
	for i in range(6):
		await get_tree().physics_frame
	await _settle()
	check(Game.music_mood == "calm", "an ordinary flat stays on the exploration bed (%s)" % plain)
	room3.queue_free()
	WorldState.god_mode = false
	await get_tree().physics_frame
