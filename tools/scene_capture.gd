extends Node

# DEV TOOL — plays a scripted sequence against the REAL game and saves rendered frames, so a
# flow (the cold open, the tutorial, a death → next run) can be reviewed without a playtest.
# Needs a rendering driver (not --headless):
#
#   xvfb-run -a -s "-screen 0 1152x648x24" godot --rendering-driver opengl3 \
#       res://tools/scene_capture.tscn -- --out=/tmp/cap --tutorial=1 \
#       --steps="newgame,w:60,s,k:SPACE,rec:90:6,x:560,a:interact,rec:120:10"
#
# Steps (comma separated):
#   newgame          Game.new_game() — exactly what the title screen's New Game does
#   scene:<path>     change to a scene (res://...)
#   w:<n>            wait n frames
#   s                one screenshot
#   rec:<n>:<every>  wait n frames, screenshot every <every> frames
#   k:<KEY>          tap a physical key (SPACE, E, W, ESCAPE, Q ...)
#   a:<action>       tap an input action (interact, attack, push, move_up ...)
#   hold:<action>:<n> hold an action for n frames (screenshots every 10)
#   x:<px>           teleport the player to x (on the corridor plane)
#   go:<px>          walk the player to x (click-to-move target) and wait until arrived
#   floor:<n> run:<n> set WorldState.current_floor / current_run
#   give:<id>[:<lvl>] put an item in the inventory (optionally at a workbench level)
#   scrap:<n>        set the scrap counter
#   boon:<floor>     reach a run-boon milestone (queues the HUD badge)
#   valour:<n>       set the profile's Descent Valour
#   perk:<id>        record a perk as acquired this session (the Valour offer's pool)
#   chron:<run>:<deepest>:<dead|survived>  set a run's deepest floor + outcome (for scoring)
#   perm:<id>        keep a perk permanently (the profile's collection)
#   finish           score the session (WorldState.finish_session) → Valour + offer
#   hud:<method>     call a no-arg HUD method (e.g. open_boon_offer)
#   kill             kill the player now (player._die → the real Game.game_over flow)
#   hp:<n>           set health
#   eval:<method>    call a no-arg method on the current scene
#   call:<group>:<method>[:<arg>]  call a method on the first node in a group (e.g. modal_panel)
# Other args: --tutorial=1|0 (first-run tutorial on/off), --seed=<n>.

var _out := "/tmp/cap"
var _steps: PackedStringArray = []
var _tutorial := true
var _seed := 0
var _n := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS    # the tutorial pauses the tree; keep driving it
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--steps="):
			_steps = a.substr(8).split(",", false)
		elif a.begins_with("--tutorial="):
			_tutorial = a.substr(11) == "1"
		elif a.begins_with("--seed="):
			_seed = int(a.substr(7))
	DirAccess.make_dir_recursive_absolute(_out)
	# Hand "current scene" to a stub so scene changes don't free this driver.
	var stub := Node.new()
	get_tree().root.add_child.call_deferred(stub)
	await get_tree().process_frame
	get_tree().current_scene = stub
	WorldState.set_tutorial_completed(not _tutorial)
	for step in _steps:
		await _do(step.strip_edges())
	print("scene_capture: %d frames -> %s" % [_n, _out])
	get_tree().quit(0)


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _do(step: String) -> void:
	var p := step.split(":")
	match p[0]:
		"newgame":
			Game.new_game()
			if _seed != 0:
				WorldState.master_seed = _seed
			await _frames(2)
		"scene":
			get_tree().change_scene_to_file(p[1] + ":" + p[2] if p.size() > 2 else p[1])
			await _frames(2)
		"w":
			await _frames(int(p[1]))
		"s":
			await _shot()
		"rec":
			var every: int = int(p[2]) if p.size() > 2 else 6
			for i in int(p[1]):
				if i % every == 0:
					await _shot()
				else:
					await _frames(1)
		"k":
			await _key(p[1])
		"a":
			await _action(p[1], 1)
		"hold":
			await _action(p[1], int(p[2]))
		"x":
			var pl = _player()
			if pl != null:
				pl.global_position = Vector2(float(p[1]), 386.0)
			await _frames(1)
		"go":
			var pl = _player()
			if pl != null and pl.has_method("set_move_target"):
				pl.set_move_target(float(p[1]))
				var guard := 0
				while is_instance_valid(pl) and absf(pl.global_position.x - float(p[1])) > 6.0 and guard < 900:
					if guard % 15 == 0:
						await _shot()
					else:
						await _frames(1)
					guard += 1
		"give":
			# give:<item id>[:<workbench level>]
			var inst := ItemInstance.new()
			inst.setup(p[1])
			if p.size() > 2:
				inst.level = int(p[2])
			WorldState.inventory.append(inst)
			HUD.refresh_inventory()
		"boon":
			WorldState.note_boon_milestone(int(p[1]))
		"valour":
			WorldState.valour = int(p[1])
		"perk":
			WorldState.note_perk_acquired(p[1])
		"chron":
			WorldState.run_chronicle[int(p[1]) - 1]["deepest_floor"] = int(p[2])
			WorldState.set_run_outcome(int(p[1]), p[3])
		"perm":
			if not (p[1] in WorldState.permanent_perks):
				WorldState.permanent_perks.append(p[1])
		"finish":
			WorldState.finish_session()
		"hud":
			if HUD.has_method(p[1]):
				HUD.call(p[1])
			await _frames(1)
		"scrap":
			WorldState.scrap_unlocked = true
			WorldState.scrap = int(p[1])
			HUD.refresh_inventory()
		"floor":
			WorldState.current_floor = int(p[1])
		"run":
			WorldState.current_run = int(p[1])
		"hp":
			WorldState.player_health = int(p[1])
		"kill":
			WorldState.god_mode = false
			var pl = _player()
			if pl != null and pl.has_method("_die"):
				pl._die()           # the real death path (anim → Game.game_over)
			await _frames(1)
		"call":
			var n = get_tree().get_first_node_in_group(p[1])
			if n != null and n.has_method(p[2]):
				if p.size() > 3:
					n.call(p[2], p[3])
				else:
					n.call(p[2])
			await _frames(1)
		"eval":
			var sc = get_tree().current_scene
			if sc != null and sc.has_method(p[1]):
				sc.call(p[1])
			await _frames(1)
		_:
			push_warning("scene_capture: unknown step " + step)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/f%03d.png" % [_out, _n])
	_n += 1
	await get_tree().process_frame


func _key(name: String) -> void:
	var ev := InputEventKey.new()
	ev.keycode = OS.find_keycode_from_string(name)
	ev.physical_keycode = ev.keycode
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func _action(action: String, frames: int) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in frames:
		if frames > 1 and i % 10 == 0:
			await _shot()
		else:
			await _frames(1)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)
