extends Node

const SCENES = {
	"title": "res://scenes/title_screen.tscn",
	"profiles": "res://scenes/profile_select.tscn",
	"hallway": "res://scenes/hallway.tscn",
	"room": "res://scenes/room.tscn",
	"maintenance": "res://scenes/maintenance.tscn",
	"elevator_interior": "res://scenes/elevator_interior.tscn",
	"lobby": "res://scenes/lobby.tscn",
	"building_floors": "res://scenes/building_floors.tscn"
}

var music_player: AudioStreamPlayer = null          # the exploration bed (dread_loop) — always playing, ducked while a claim wants another mood
var breach_player: AudioStreamPlayer = null         # the breach-room track (breach_loop) — runs only while something claims the "breach" mood

# A dedicated bus for enemy SFX (zombie moans). The stair ascent fades THIS bus
# out as the player climbs away, so the floor's zombies recede without touching
# the music. Everything else stays on Master.
const ENEMY_BUS := "Enemies"
const MUSIC_BUS := "Music"

# --- MUSIC MOODS (owner round 46: "a more pulse pounding track… for entering breach rooms") ----------------------------------------------------
# One mood plays at a time. A scene that wants a mood CLAIMS it (`music_claim(self, "breach")`) and releases it when its reason is over; a claim
# whose node is freed / out of the tree is dropped on its own, so a scene change, a death or a quit can never leave the pulse stuck on. The newest
# claim wins; with none the mood is "calm". Moods cross-fade in real time (not game time — a slow-motion beat must not stretch a fade) and keep
# running through the pause menu. The calm loop is only DUCKED during a breach (it keeps its place), the breach loop starts over each entry.
## `in` / `out` = seconds for the mood to rise to full / fall to silence. The pulse comes in FAST (the first boom + beat must land as the door opens, under the fade
## from black), the bed drops away fast to make room, and each hands back SLOWLY — the bed swells back over 3.2 s, the pulse drains over 3.2 s — the way tension does.
const MUSIC_MOODS := {
	"calm": {"stream": "res://assets/audio/music/dread_loop.ogg", "db": -10.0, "in": 3.2, "out": 0.6},
	"breach": {"stream": "res://assets/audio/music/breach_loop.ogg", "db": -9.0, "in": 0.25, "out": 3.2},
}
const SILENT_DB := -80.0
var music_mood := "calm"
var music_fade_scale := 1.0           # tests raise this to cross-fade in a blink
var _music_claims: Array = []         # [{"node": Node, "mood": String}], oldest first
var _mood_gain := {"calm": 1.0, "breach": 0.0}     # linear 0..1 each mood is currently at
var _music_tick_msec := 0


func _ready() -> void:
	# Must keep handling input while the tree is paused, so Esc can un-pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_enemy_bus()
	_ensure_music_bus()
	_ensure_master_limiter()
	# Background music (assets/audio/music) — lives on this autoload so it survives scene changes and keeps droning through the pause menu.
	music_player = _make_music_player("MusicPlayer", "calm")
	music_player.play()
	breach_player = _make_music_player("BreachMusicPlayer", "breach")      # silent and stopped until something claims the mood
	_music_tick_msec = Time.get_ticks_msec()


func _make_music_player(node_name: String, mood: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	var stream = load(String(MUSIC_MOODS[mood]["stream"]))
	if stream != null and "loop" in stream:
		stream.loop = true
	p.stream = stream
	p.bus = MUSIC_BUS
	p.volume_db = float(MUSIC_MOODS[mood]["db"]) if mood == "calm" else SILENT_DB
	add_child(p)
	return p


func _ensure_enemy_bus() -> void:
	# There's no bus layout resource, so create the enemy bus at runtime and
	# route it to Master. Idempotent — safe if it already exists.
	if AudioServer.get_bus_index(ENEMY_BUS) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, ENEMY_BUS)
	AudioServer.set_bus_send(idx, "Master")


func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, MUSIC_BUS)
	AudioServer.set_bus_send(idx, "Master")


## The last net under every sound (owner round 46: "static and noise"): several loud sounds at once (a crowd's moans, a gunshot over a door slam) used to sum
## past full scale on the Master bus and hard-CLIP, which is a crackle. A limiter on Master rounds those peaks off instead. Idempotent.
func _ensure_master_limiter() -> void:
	var master := AudioServer.get_bus_index("Master")
	for i in range(AudioServer.get_bus_effect_count(master)):
		if AudioServer.get_bus_effect(master, i) is AudioEffectLimiter:
			return
	var lim := AudioEffectLimiter.new()
	lim.ceiling_db = -1.0
	lim.threshold_db = -4.0
	AudioServer.add_bus_effect(master, lim)


## Ask for a music mood on behalf of `node` ("breach"). The newest claim wins; the claim ends with `music_release(node)` or when the node is freed.
func music_claim(node: Node, mood: String) -> void:
	if node == null or not MUSIC_MOODS.has(mood):
		return
	music_release(node)
	_music_claims.append({"node": node, "mood": mood})


func music_release(node: Node) -> void:
	for i in range(_music_claims.size() - 1, -1, -1):
		if _music_claims[i]["node"] == node:
			_music_claims.remove_at(i)


## The mood the claims ask for right now ("calm" with none). Dead claims are dropped here — a freed node, or one no longer in the tree.
func wanted_music_mood() -> String:
	for i in range(_music_claims.size() - 1, -1, -1):
		var n = _music_claims[i]["node"]
		if not is_instance_valid(n) or not (n as Node).is_inside_tree():
			_music_claims.remove_at(i)
	return String(_music_claims[_music_claims.size() - 1]["mood"]) if not _music_claims.is_empty() else "calm"


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var dt := minf(float(now - _music_tick_msec) / 1000.0, 0.25)             # real seconds, clamped (a hitch must not jump a fade)
	_music_tick_msec = now
	if music_player == null:
		return
	music_mood = wanted_music_mood()
	for mood in _mood_gain.keys():
		var want := 1.0 if mood == music_mood else 0.0
		var g: float = _mood_gain[mood]
		var span: float = float(MUSIC_MOODS[mood]["in" if want > g else "out"])
		g = move_toward(g, want, dt * music_fade_scale / span)
		_mood_gain[mood] = g
	_apply_music_levels()


func _apply_music_levels() -> void:
	for mood in ["calm", "breach"]:
		var p: AudioStreamPlayer = music_player if mood == "calm" else breach_player
		if p == null:
			continue
		var g: float = _mood_gain[mood]
		if g <= 0.001:
			p.volume_db = SILENT_DB
			if mood == "breach" and p.playing:
				p.stop()                                                      # the pulse starts again from its first beat on the next entry
			continue
		if mood == "breach" and not p.playing:
			p.play()
		p.volume_db = float(MUSIC_MOODS[mood]["db"]) + linear_to_db(g)


func _input(event: InputEvent) -> void:
	# PauseMenu is an autoload now (not embedded in every scene), so it no
	# longer blankets the editor viewport and each world scene stays editable.
	if not HUD.visible or event.is_echo():
		return
	# Typing into a text box (a profile name, a dev prompt) is never a command.
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	# THE PAUSE KEY (Esc / Start by default) opens the pause menu or steps back out of whatever is open.
	# Esc ALSO always works, whatever `pause` is bound to — the way back to a menu can never be unbound.
	# BACK (ui_cancel — Esc, or B on a pad) only ever CLOSES something: B is also "push" in play, so it
	# must never open the pause menu on its own.
	var is_pause: bool = event.is_action_pressed("pause") \
		or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE)
	var is_back: bool = event.is_action_pressed("ui_cancel")
	if event.is_action_pressed("open_journal") and not is_pause:
		_toggle_journal()
		return
	if not (is_pause or is_back):
		return
	# The character journal is a pausing overlay of its own: ESC closes IT first. This handler
	# runs before the journal's own input, so without this ESC opened the pause menu ON TOP of
	# the journal — and Resume then unpaused the live game behind a still-open journal.
	# Any open modal panel (the workbench, …) closes first, same as the journal below.
	for m in get_tree().get_nodes_in_group("modal_panel"):
		if m.visible and m.has_method("close"):
			m.close()
			get_viewport().set_input_as_handled()
			return
	var journal = HUD.get("character_panel")
	if journal != null and is_instance_valid(journal) and journal.visible:
		journal.close()
		get_viewport().set_input_as_handled()
		return
	# Back (B) also closes a search panel — it is how a pad leaves one without taking anything.
	if is_back and not is_pause and not PauseMenu.visible and WorldState.loot_open:
		get_tree().call_group("loot_ui", "leave")
		get_viewport().set_input_as_handled()
		return
	if is_pause or PauseMenu.visible:
		PauseMenu.handle_cancel()
		get_viewport().set_input_as_handled()


## The journal key: opens the book, or closes it if it is already open. Refuses while anything else owns the screen.
func _toggle_journal() -> void:
	var journal = HUD.get("character_panel")
	if journal == null or not is_instance_valid(journal):
		return
	if journal.visible:
		journal.close()
		get_viewport().set_input_as_handled()
		return
	if PauseMenu.visible or get_tree().paused or WorldState.loot_open:
		return
	for m in get_tree().get_nodes_in_group("modal_panel"):
		if m.visible:
			return
	HUD.open_character_panel()
	get_viewport().set_input_as_handled()

func go_to_scene(scene_name: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENES[scene_name])

func new_game() -> void:
	# Fade the menu out to black first, THEN start: the run opens on its own black cold open
	# (intro_overlay), so the reveal below is invisible — it just hands black to black instead
	# of the menu hard-cutting away. (The cold open waits while Transition is busy.)
	await Transition.cover(0.45)
	WorldState.packless_rule = true          # every real game starts with pockets only (docs/BACKPACK.md)
	WorldState.story_rule = true             # …and each run opens on its own character's story (docs/CHARACTER_STORIES.md)
	WorldState.survivor_rule = true          # …and the building holds its survivors and quest givers (docs/NPC_AI.md, docs/QUESTS.md)
	WorldState.new_game()
	HUD.show_hud()
	go_to_scene("hallway")
	await get_tree().process_frame
	await get_tree().process_frame
	await Transition.reveal(0.2)

func continue_game() -> void:
	var scene_path = WorldState.load_game()
	if scene_path == "":
		return
	get_tree().paused = false
	# Loading a save opens on the exterior shot in the SAVE's run (its light, its damage, the floors that are really burning) — then
	# the saved scene comes up out of black. A missing piece of art just loads, as before.
	var Seq := preload("res://scripts/opening_sequence.gd")
	var seq: Node = null
	if Seq.available():
		await Transition.cover(0.45)
		seq = Seq.new()
		get_tree().root.add_child(seq)
		if seq.ext != null and is_instance_valid(seq.ext):
			await Transition.reveal(0.05)
			await seq.finished
			await Transition.cover(0.05)
	HUD.show_hud()
	get_tree().change_scene_to_file(scene_path)
	if seq != null:
		await get_tree().process_frame
		await get_tree().process_frame
		if is_instance_valid(seq):
			seq.queue_free()
		await Transition.reveal(0.5)

func save_and_quit(go_to_desktop: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var at: Vector2 = player.lane_position() if player.has_method("lane_position") else player.global_position
		WorldState.saved_player_x = at.x
		WorldState.saved_player_y = at.y
		# Remember if we were out on a balcony plane, so the load can re-establish
		# it (the saved Y alone can't — see player.restore_balcony_plane).
		WorldState.saved_on_balcony_plane = bool(player.get("on_balcony_plane"))
	var scene_path = get_tree().current_scene.scene_file_path
	WorldState.save_game(scene_path)
	get_tree().paused = false
	HUD.hide_hud()
	if go_to_desktop:
		get_tree().quit()
	else:
		go_to_scene("title")

func quit_without_saving() -> void:
	# Returns to title WITHOUT touching the save file — the player keeps whatever
	# they last saved. (Permadeath on death is handled separately in game_over.)
	HUD.hide_hud()
	go_to_scene("title")

func game_over() -> void:
	# A character of the arc has died. Per docs/THREE_RUN_ARC.md a death is NOT the
	# end of the session — it triggers the SAME time skip an exit does, and the next
	# character takes over. Only when the THIRD character falls is the playthrough
	# truly over (a dead character leaves a recoverable corpse — store step 7, future).
	WorldState.set_run_outcome(WorldState.current_run, "dead")
	# Record the fallen character's body so the NEXT character can recover its notes + items
	# (STORE_DESIGN step 7). Only when there IS a next character — the 3rd death ends the arc,
	# with no one to recover into. Captured now, while the player node + this run's
	# inventory/wallet still exist (advance_run wipes them below).
	if WorldState.current_run < WorldState.RUN_NAMES.size():
		var dead = get_tree().get_first_node_in_group("player")
		if dead != null:
			var scene_path: String = get_tree().current_scene.scene_file_path
			var apt: String = WorldState.current_apartment_id if scene_path == SCENES["room"] else ""
			# FEET, not origin — the body must lie on the floor line, not float above it.
			var feet: Vector2 = dead.feet_position() if dead.has_method("feet_position") \
				else dead.global_position + Vector2(0, WorldState.PLAYER_FEET_OFFSET)
			WorldState.record_player_corpse(WorldState.current_floor, scene_path, apt, feet)
	get_tree().paused = false
	# THE END CARD: fade to black on "YOU DIED — <name> fell on Floor N." (the bookend to the
	# cold open every run starts with). It leaves the screen BLACK, so advance_run()'s world
	# mutation (new barricades/props/door states) never pops in over the death scene.
	var here: String = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	var who: String = WorldState.character_display_name(WorldState.current_character())
	if not await Transition.end_card(TutorialManager.LINES["end_died"],
			"%s fell %s." % [who, WorldState.place_in_words(here)], Transition.END_DIED_COLOR):
		await Transition.cover()
	var arc_over: bool = WorldState.advance_run()
	if arc_over:
		# The final character has fallen — the playthrough ends. Reveal onto the game-over card.
		WorldState.finish_session()      # score the session → Descent Valour + the perk offer
		WorldState.delete_save()
		HUD.hide_hud()
		get_tree().change_scene_to_file("res://scenes/game_over.tscn")
		await get_tree().process_frame
		await get_tree().process_frame
		await Transition.reveal()
		return
	# The next character wakes at Floor 30 after the skip. Persist the fresh run
	# WITHOUT recording the dead scene's zombies, then time-skip into the hallway.
	WorldState.save_game("res://scenes/hallway.tscn", false)
	Transition.to_run_start("res://scenes/hallway.tscn")   # → the cold open's time card
