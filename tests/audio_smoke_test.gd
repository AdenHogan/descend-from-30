extends Node

# Headless audio smoke test: every wired stream loads, and the runtime
# audio players exist on player/zombies after instantiation.
# Run:  godot --headless res://tests/audio_smoke_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== audio smoke test ===")
	_test_streams()
	_test_players()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_streams() -> void:
	print("[streams]")
	var paths = [
		"res://assets/audio/gunshot.wav",
		"res://assets/audio/heartbeat.wav",
		"res://assets/audio/elevator_ding.wav",
		"res://assets/audio/zombie/moan_1.wav",
		"res://assets/audio/zombie/moan_2.wav",
		"res://assets/audio/zombie/moan_3.wav",
		"res://assets/audio/zombie/moan_4.wav",
		"res://assets/audio/doors/metalLatch.ogg",
		"res://assets/audio/impacts/knifeSlice.ogg",
		"res://assets/audio/impacts/knifeSlice2.ogg",
		"res://assets/audio/impacts/impactWood_medium_000.ogg",
	]
	for i in range(5):
		paths.append("res://assets/audio/footsteps/footstep_carpet_00%d.ogg" % i)
		paths.append("res://assets/audio/footsteps/footstep_concrete_00%d.ogg" % i)
		paths.append("res://assets/audio/impacts/impactPlank_medium_00%d.ogg" % i)
	for i in range(3):
		paths.append("res://assets/audio/impacts/impactWood_heavy_00%d.ogg" % i)
	for path in paths:
		var stream = load(path)
		check(stream != null and stream is AudioStream, "loads: " + path.get_file())


func _test_players() -> void:
	print("[runtime players]")
	WorldState.new_game()
	var player = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	check(player.get_node_or_null("FootstepPlayer") != null, "player has footstep player")
	check(player.get_node_or_null("GunshotPlayer") != null, "player has gunshot player")
	player.queue_free()

	var zombie = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	add_child(zombie)
	check(zombie.get_node_or_null("MoanPlayer") != null, "standard zombie has moan player")
	zombie.queue_free()

	var big = load("res://scenes/enemy_zombie_big.tscn").instantiate()
	add_child(big)
	check(big.get_node_or_null("MoanPlayer") != null, "big zombie has moan player")
	big.queue_free()

	var overlay = load("res://scripts/listen_overlay.gd").new()
	add_child(overlay)
	check(overlay.heartbeat_player != null, "listen overlay has heartbeat player")
	overlay.queue_free()

	var music = load("res://assets/audio/music/dread_loop.ogg")
	check(music != null and music is AudioStream, "background loop loads")
	check(Game.music_player != null and Game.music_player.stream != null,
		"Game autoload carries the music player")
	check(Game.music_player.stream.loop, "background loop set to loop")
