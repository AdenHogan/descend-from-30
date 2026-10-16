extends Node

# THE DESCENT BOT (owner round 43 — "send a bot run down through the building. Give the bot two hammers, one gun with eight bullets
# preloaded and two first aid kits. See how far it gets and allow it to pick upgrades at the five-floor increments. If it makes it to the
# lobby, make notes for analysis and evaluation and continue with run 2 and 3"). docs/BOT_RUNS.md has the policy, the numbers and the caveats.
#
#   godot --headless res://tools/bot_run.tscn -- --seed=424242 --speed=6 --out=/tmp/bot_424242.md [--style=fighter|runner] [--runs=3]
#                                                [--start-floor=30] [--start-run=1] [--keep-going] [--no-crowbar]
#
# It plays the REAL scenes with the REAL rules (no god mode, the real stairs / pans / merchant / lobby door), through the player's own
# controls: held move / sprint actions, the attack key as an input event, `use_item`, the push action. It sees what a player sees (one
# screen's width of the corridor) and knows what a player knows (the floor's stair side from its sign). It does NOT scavenge, loot, talk to
# anyone or enter an apartment — it has exactly the kit it was given (+ the upgrades and boon it takes at the merchant floors 25/20/15/10/5).
# The one liberty: a BARRICADED stairwell needs a crowbar the bot could never have found, so one is handed to it AT THAT MOMENT (outside the
# five slots, logged) and the real pry follows — see docs/BOT_RUNS.md.
#
# Runs in the test sandbox (res://tools/ → WorldState.data_dir()), never the player's saves. The physics is sped up the way the balance tool does
# it (tick rate AND time scale together, so every step is still 1/60 s of game).

const BotLoot := preload("res://tools/bot_loot.gd")
const BotWatch := preload("res://tools/bot_watch.gd")
const BUILDING := "res://scenes/building_floors.tscn"
const HALLWAY := "res://scenes/hallway.tscn"
const LOBBY := "res://scenes/lobby.tscn"
const SIGHT := 340.0                    # one screen of corridor each way
const MERCHANT_X := 1029.5              # the lift (the merchant lives in it)
const LOBBY_EXIT_X := 654.0
const REACH := 65.0                     # a hammer ("bat") — player.WEAPON_RANGES
const SWING_COST := 26.0                # …and its stamina — player.WEAPON_STAMINA_COST
const PUSH_COST := 28.0
const FLOOR_TIMEOUT := 150.0            # game seconds on one floor before the bot calls itself stuck
const MAX_RUN_TIME := 5400.0
const MAX_RUN_TIME_LOOT := 21600.0      # a character that searches every flat is on the clock for hours of game time
const GUN_MIN_RANGE := 70.0

# What the bot prefers at the merchant (survival for a fighter with a fixed kit); anything not listed scores 0, drawbacks are penalised.
const UPGRADE_SCORE := {
	"U_heal": 9, "U_melee_m": 9, "U_melee_s": 7, "U_stam_l": 8, "U_stam_m": 6, "U_speed_m": 6, "U_regen_m": 6, "U_quiet_m": 6,
	"U_speed_s": 5, "U_regen_s": 4, "U_stam_s": 4, "U_quiet_s": 4, "U_sprint_m": 4, "U_sprint_s": 3, "U_push": 3, "U_slot": 2,
	"U_acc": 2, "U_head_m": 2, "U_head_s": 1, "U_mag_s": 1, "U_mag_m": 1, "U_listen": 1, "U_fortune": 1, "U_nightvision": 2,
	"U_db_glass": 2, "U_db_speedquiet": -1, "U_db_headslow": -3, "U_db_quietweak": -3, "U_db_regenslow": -1,
}
const BOON_SCORE := {
	"B_rage": 9, "B_lungs": 8, "B_adrenaline": 7, "B_second_wind": 6, "B_brawler": 5, "B_breath": 5, "B_light": 4, "B_steady": 2,
	"B_senses": 1, "B_eye": 0,
}

# --- configuration ---
var seed_value: int = 424242
var speed: int = 6
var out_path: String = ""
var style: String = "fighter"           # "fighter": fights what stands in the way, kites when winded · "runner": sprints, fights only when blocked
var max_runs: int = 3
var start_floor: int = 30
var with_opener: bool = false           # debugging: leave the cold open ON for the first character (the later ones always get theirs)
var start_run: int = 1                  # debugging: begin as the Nth character (the world has decayed N-1 time skips)
var keep_going: bool = false            # keep playing after a run-1 death (default: stop there — the brief)
var give_crowbar: bool = true
var crowbar_mode: String = "fallback"      # liberty = hand one over at the first barricade · fallback = loot for one first, hand it over when the floor is exhausted · found = never
var loot_mode: String = "need"             # none (the briefed kit only) · need (loot while the kit is short) · all (every door on the way)
var god_no_saveload: bool = false      # (debugging) skip the save + load fidelity check at every third floor
var god: bool = false                  # COVERAGE runs: the player cannot be hurt, so the bot walks the whole building (balance numbers come from runs without it)
var rest_mode: bool = false             # COVERAGE: rest (T) whenever a rest is banked and the bot is winded — the building shift it causes is a world rebuild worth exercising
var balcony_first: bool = false         # (debugging) take the balcony in the first flat that has one
var balcony_mode: bool = false          # COVERAGE: leave up to three flats a character by the balcony (the rope / jump descent and its pan)
var elevator_mode: bool = false         # ride the powered elevator when there is one (it jumps five floors — skips the loot between)
var _elev_gate: float = 0.0
var _fight_since: float = -1.0
var _fight_kills: int = 0
var _ignore_threats_until: float = 0.0
var goal_override: float = -1.0         # while the looter is fighting inside a room: where "onward" is (the way out)
var debug_scrap: int = 0                # debugging ONLY (changes the balance): start every character with this much scrap
var debug_unarmed: bool = false         # … and no hammers (the gun is emptied too): how the bot copes with nothing
var debug_power: bool = false           # … and the elevator already powered
var debug_notes: int = 0                # … and this many notes (the wallet unlocked)
var debug_fuses: int = 0                # … and this many fuses
var loot = null
var watch = null
var wall_start_ms: int = 0
var only_apts: Array = []
var avoid_breach: bool = false
var dt: float = 0.0
var want_scav: bool = false
var anomalies: Array = []
var _taps: Dictionary = {}
var _afters: Array = []
var _kind: String = ""
var trace: bool = false                 # print the bot's state every 2 s (debugging the bot)
var _trace_t: float = 0.0
var _dbg_cut: bool = false
var _raw_floor: int = -1
var _last_scene: String = ""
var _room_in_t: float = -1.0               # game time the current room scene was entered
var _bounces: Dictionary = {}              # apartment id -> times the game put the player back in the corridor within 3 s of entering
var _bounce_trace: int = 0
var _hb_t: float = 0.0

# --- bookkeeping ---
var t: float = 0.0                      # game seconds
var finished: bool = false
var phase: String = "boot"              # boot · play · lobby · leaving · wait_next · over
var runs: Array = []                    # one record per character: {run, outcome, ...}
var run_rec: Dictionary = {}
var floor_rec: Dictionary = {}
var floors_log: Array = []              # every floor visited, in order
var events: Array = []
var upgrades_taken: Array = []
var boons_taken: Array = []
var _last_floor: int = -999
var _last_health: int = 0
var _known: Dictionary = {}             # instance id -> type of a zombie we have seen alive
var _timeline: Array = []               # the last few seconds, for the death write-up
var _tl_t: float = 0.0
var _seen_lobby: bool = false
var _stub: Node = null

# --- per-tick control state ---
var _kb: Dictionary = {}                # action -> pressed by us
var _swing_gate: float = 0.0
var _push_gate: float = 0.0
var _heal_gate: float = 0.0
var _stairs_gate: float = 0.0
var _slot_gate: float = 0.0
var _intro_gate: float = 0.0
var _shop_state: String = "none"        # none · walking · open · done
var _shop_gate: float = 0.0
var _shop_floor: int = -1
var _floor_enter_t: float = 0.0
var _no_progress_t: float = 0.0
var _last_x: float = 0.0
var _kite_until: float = 0.0
var _exit_gate: float = 0.0
var _leave_t: float = 0.0
var _hold_t: float = 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.substr(7))
		elif a.begins_with("--speed="):
			speed = clampi(int(a.substr(8)), 1, 16)
		elif a.begins_with("--out="):
			out_path = a.substr(6)
		elif a.begins_with("--style="):
			style = a.substr(8)
		elif a.begins_with("--runs="):
			max_runs = clampi(int(a.substr(7)), 1, 3)
		elif a.begins_with("--start-floor="):
			start_floor = clampi(int(a.substr(14)), 0, 30)
		elif a.begins_with("--start-run="):
			start_run = clampi(int(a.substr(12)), 1, 3)
		elif a == "--opener":
			with_opener = true
		elif a == "--keep-going":
			keep_going = true
		elif a == "--no-crowbar":
			give_crowbar = false
			crowbar_mode = "found"
		elif a.begins_with("--crowbar="):
			crowbar_mode = a.substr(10)
			give_crowbar = crowbar_mode != "found"
		elif a.begins_with("--loot="):
			loot_mode = a.substr(7)
		elif a.begins_with("--apt="):
			only_apts = a.substr(6).split(",")
		elif a == "--avoid-breach":
			avoid_breach = true
		elif a.begins_with("--scrap="):
			debug_scrap = int(a.substr(8))
		elif a.begins_with("--notes="):
			debug_notes = int(a.substr(8))
		elif a.begins_with("--fuses="):
			debug_fuses = int(a.substr(8))
		elif a == "--unarmed":
			debug_unarmed = true
		elif a == "--power":
			debug_power = true
		elif a == "--no-saveload":
			god_no_saveload = true
		elif a == "--god":
			god = true
		elif a == "--elevator":
			elevator_mode = true
		elif a == "--balcony":
			balcony_mode = true
		elif a == "--balcony-first":
			balcony_mode = true
			balcony_first = true
		elif a == "--rest":
			rest_mode = true
		elif a == "--trace":
			trace = true
	process_mode = Node.PROCESS_MODE_ALWAYS     # the cold open pauses the tree: the bot must keep ticking to press through it
	loot = BotLoot.new(self, loot_mode)
	loot.only_apts = only_apts
	loot.avoid_breach = avoid_breach
	watch = BotWatch.new(self)
	wall_start_ms = Time.get_ticks_msec()
	set_physics_process(false)
	await get_tree().process_frame
	# Survive the scene swaps: hand "current scene" to a stub the first change will free (the bot is a child of the root).
	_stub = Node.new()
	get_tree().root.add_child(_stub)
	get_tree().current_scene = _stub
	Engine.physics_ticks_per_second = 60 * speed
	Engine.max_physics_steps_per_frame = 64
	Engine.time_scale = float(speed)
	_new_playthrough()
	set_physics_process(true)


# =============================== SET-UP ===============================================================

func _new_playthrough() -> void:
	WorldState.dev_seed = seed_value
	WorldState.packless_rule = false         # the five-slot kit is the brief; a pack-less start would overload it
	WorldState.story_rule = false            # no openers / personal quests: this is about the descent
	WorldState.new_game()
	WorldState.dev_seed = 0
	WorldState.survivor_rule = true          # the building holds its survivors, like a real New Game
	for _i in range(start_run - 1):
		WorldState.advance_run()
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.opener_seen = not with_opener
	WorldState.god_mode = god
	HUD.show_hud()
	_give_kit()
	_begin_run()
	var path := HALLWAY
	if start_floor < 30:
		WorldState.current_floor = start_floor
		WorldState.spawn_source = "stair"
		WorldState.stair_spawn_side = WorldState.canonical_stair_arrival_side(start_floor)
		WorldState.stair_direction = "down"
		path = LOBBY if start_floor == 0 else BUILDING
	get_tree().change_scene_to_file(path)
	phase = "play"


## Exactly the brief: two hammers, one gun with eight rounds in it, two first aid kits (five slots).
func _give_kit() -> void:
	WorldState.inventory.clear()
	WorldState.add_to_inventory("002")
	WorldState.add_to_inventory("002")
	WorldState.add_to_inventory("004")
	for inst in WorldState.inventory:
		if inst.item_id == "004":
			inst.mag_count = 8
	WorldState.add_to_inventory("007")
	WorldState.add_to_inventory("007")
	WorldState.is_scavenge_mode = false
	if debug_scrap > 0:
		WorldState.add_scrap(debug_scrap)
	if debug_unarmed:
		for i in range(WorldState.inventory.size() - 1, -1, -1):
			var inst0 = WorldState.inventory[i]
			if inst0.item_id == "002":
				WorldState.inventory.remove_at(i)
			elif inst0.item_id == "004":
				inst0.mag_count = 0
	if debug_power:
		WorldState.elevator_fuses_loaded = WorldState.ELEVATOR_FUSES_NEEDED
		WorldState.elevator_powered = true
	if debug_notes > 0:
		WorldState.wallet_unlocked = true
		WorldState.wallet_balance = debug_notes
	for _i in range(debug_fuses):
		WorldState.add_to_inventory("020")
	HUD.refresh_inventory()
	HUD.select_slot(0)
	if WorldState.inventory.size() != 5:
		_event("KIT", "expected 5 slots, got %d" % WorldState.inventory.size())


func _begin_run() -> void:
	run_rec = {
		"run": WorldState.current_run, "character": WorldState.character_display_name(WorldState.current_character()),
		"t_start": t, "outcome": "", "deepest": 30, "floors": 0, "kills": 0, "hits": 0, "heals": 0, "shots": 0, "pushes": 0, "swings": 0,
		"kit_end": "", "death": {}, "stuck": {},
	}
	runs.append(run_rec)
	_last_health = WorldState.player_health
	_last_floor = -999
	_known.clear()
	_shop_state = "none"
	_shop_floor = -1
	_event("RUN", "run %d begins — %s (%s), seed %d, style %s" % [WorldState.current_run, run_rec["character"], WorldState.run_name(WorldState.current_run), seed_value, style])


# =============================== THE TICK =============================================================

func _physics_process(delta: float) -> void:
	if finished:
		return
	t += delta
	dt = delta
	_run_taps_and_afters()
	_swing_gate = maxf(0.0, _swing_gate - delta)
	_push_gate = maxf(0.0, _push_gate - delta)
	_heal_gate = maxf(0.0, _heal_gate - delta)
	_stairs_gate = maxf(0.0, _stairs_gate - delta)
	_stance_gate = maxf(0.0, _stance_gate - delta)
	_slot_gate = maxf(0.0, _slot_gate - delta)
	_shop_gate = maxf(0.0, _shop_gate - delta)
	_exit_gate = maxf(0.0, _exit_gate - delta)
	_intro_gate = maxf(0.0, _intro_gate - delta)
	_skip_intro()
	if phase == "over":
		return
	if trace:
		_hb_t += delta
		if _hb_t >= 5.0:
			_hb_t = 0.0
			var sc = get_tree().current_scene
			var hp = _player()
			print("    [heartbeat t=%.0f] phase=%s scene=%s transition_busy=%s paused=%s player=%s dead=%s run=%d | cutscene=%s escaping=%s lashing=%s panning=%s switching=%s pack=%s listening=%s loot_open=%s dying=%s" % [t, phase, str(sc.scene_file_path) if sc != null else "none", str(Transition.busy), str(get_tree().paused), str(hp != null), str(hp.is_dead) if hp != null else "-", WorldState.current_run, str(hp.is_cutscene) if hp != null else "-", str(hp.escaping) if hp != null else "-", str(hp.is_lashing) if hp != null else "-", str(StairPan.panning), str(hp.is_switching_mode) if hp != null else "-", str(hp.pack_phase) if hp != null else "-", str(hp.is_listening) if hp != null else "-", str(WorldState.loot_open), str(WorldState.is_dying)])
			if hp != null:
				print("    [heartbeat+] p.is_dying=%s physics_processing=%s process_mode=%d switch_timer=%.3f is_hit=%s god=%s hp=%d can_process=%s parent_mode=%d parent=%s frames=%d time_scale=%.1f tps=%d pos=(%.0f,%.0f) balcony_pan=%s cam_y=%s" % [str(hp.is_dying), str(hp.is_physics_processing()), hp.process_mode, hp.mode_switch_timer, str(hp.is_hit), str(WorldState.god_mode), WorldState.player_health, str(hp.can_process()), hp.get_parent().process_mode, str(hp.get_parent().name), Engine.get_physics_frames(), Engine.time_scale, Engine.physics_ticks_per_second, hp.global_position.x, hp.global_position.y, str(BalconyPan.panning), str(hp.get_node_or_null("Camera2D").position.y) if hp.get_node_or_null("Camera2D") != null else "-"])
	var scene = get_tree().current_scene
	if scene != null and scene.scene_file_path.ends_with("game_over.tscn"):
		# the arc is over (the third character walked out, or fell): the game has swapped to its end card
		if run_rec.get("outcome", "") == "":
			_finish_run("escaped" if phase == "leaving" else "dead", "the playthrough ended")
		_finish_all()
		return
	var p = _player()
	if watch != null:
		watch.tick(p, delta, _activity_text())
		if watch.stall_trace > 0 and p != null:
			watch.stall_trace -= 1
			_print_stall_frame(p)
	if p == null:
		var sc0 = get_tree().current_scene
		if sc0 != null and str(sc0.scene_file_path).ends_with("/elevator_interior.tscn") and phase == "play":
			_release_all()
			_elev_gate -= delta
			if _elev_gate <= 0.0:
				_elev_gate = 1.5
				# down, unless the car would overshoot the ground (WorldState.elevator_destination clamps)
				tap("move_down" if WorldState.elevator_destination(-1) != WorldState.current_floor else "move_up", 0.15)
				if loot != null:
					loot.count("elevator_rider_presses")
			return
		_release_all()
		return
	if p.is_dead:
		_on_death(p)
		return
	if run_rec.is_empty() or int(run_rec.get("run", 0)) != WorldState.current_run:
		# the game moved on to the next character
		if run_rec.get("outcome", "") == "":
			_finish_run("escaped" if phase == "leaving" else "dead", "walked out of the lobby" if phase == "leaving" else "the character fell")
			if phase == "over":
				return
		_on_new_character(p)
		return
	var allowance: float = MAX_RUN_TIME if loot_mode == "none" else MAX_RUN_TIME_LOOT
	if t - float(run_rec["t_start"]) > allowance:
		_finish_run("timeout", "ran out of the %.0f-minute allowance" % (allowance / 60.0))
		return
	if trace and WorldState.current_floor != _raw_floor:
		print("    [trace t=%.1f] WorldState.current_floor %d -> %d (busy: transition %s pan %s cutscene %s)" % [t, _raw_floor, WorldState.current_floor, str(Transition.busy), str(StairPan.panning), str(p.is_cutscene)])
		_raw_floor = WorldState.current_floor
	if trace and p.is_cutscene != _dbg_cut:
		_dbg_cut = p.is_cutscene
		print("    [trace t=%.2f] is_cutscene -> %s (floor %d, scene %s, on_balcony_plane %s, panning %s)" % [t, str(_dbg_cut), WorldState.current_floor, _kind, str(p.on_balcony_plane), str(BalconyPan.get("panning"))])
	var sp: String = str(get_tree().current_scene.scene_file_path) if get_tree().current_scene != null else ""
	if sp != _last_scene and sp != "":
		if _last_scene != "":
			_event("SCENE", "%s -> %s (floor %d, x=%d, keys=%s, apartment=%s)" % [_last_scene.get_file(), sp.get_file(), WorldState.current_floor, int(p.global_position.x), str(_kb), str(WorldState.current_apartment_id)])
			# a flat the game puts the player straight back out of (seen once in 36 runs: 60 enter / leave cycles of one door in 150 s)
			if _last_scene.ends_with("/room.tscn") and _room_in_t >= 0.0 and t - _room_in_t < 3.0 and (loot == null or loot.room_started() == false):
				var apt := str(WorldState.current_apartment_id)
				_bounces[apt] = int(_bounces.get(apt, 0)) + 1
				if int(_bounces[apt]) == 2:
					_bounce_trace = 150
				if int(_bounces[apt]) >= 4 and loot != null:
					_anomaly("ENTER_EXIT_LOOP", "floor %d apt %s: the game put the player back in the corridor %d times within 3 s of entering (x=%d, keys=%s)" % [WorldState.current_floor, apt, int(_bounces[apt]), int(p.global_position.x), str(_kb)])
					loot.done[apt] = "bounced out by the game"
					_bounces[apt] = 0
		_last_scene = sp
		_room_in_t = t if sp.ends_with("/room.tscn") else -1.0
	if _bounce_trace > 0 and get_tree().current_scene != null and str(get_tree().current_scene.scene_file_path).ends_with("/room.tscn"):
		_bounce_trace -= 1
		var ex = loot.exit_node(get_tree().current_scene) if loot != null else null
		print("      [bounce] t=%.2f x=%.1f vx=%.0f busy=%s cut=%s keys=%s exit_x=%s overlaps=%s stairs_pan=%s" % [t, p.global_position.x, p.velocity.x, str(Transition.busy), str(p.is_cutscene), str(_kb), str(ex.global_position.x) if ex != null else "-", str(ex.overlaps_body(p)) if ex != null else "-", str(StairPan.panning)])
	var kind_now := _scene_kind(get_tree().current_scene)
	if kind_now != _kind:
		if _kind in ["room", "maint"] and loot != null:
			loot.left_room()
		_kind = kind_now
	if _kind in ["room", "maint"] or (loot != null and loot.cur_door != null):
		_floor_enter_t += delta                 # looting is not being stuck: the floor clock waits while the bot is at a door or inside
	var busy: bool = p.is_cutscene or p.escaping or p.is_lashing or Transition.busy or StairPan.panning or get_tree().paused
	var f: int = WorldState.current_floor
	if f != _last_floor and not StairPan.panning and not Transition.busy:
		# logged BEFORE the busy gate, so a floor passed through mid-transition still appears in the record
		_on_floor_change(f, p)
	_observe(p)
	if busy and get_tree().paused and _kind == "maint" and loot != null and loot.bench_ui_visible(get_tree().current_scene):
		loot.room_tick(p, get_tree().current_scene, "maint")      # the workbench pauses the tree; the bot is driving its screen
		return
	if busy:
		_release_all()
		return
	if p.is_switching_mode or p.pack_phase != "" or p.is_listening or (WorldState.loot_open and not (_kind in ["room", "maint"])):
		_release_all()
		return
	if phase == "play" and (_kind == "room" or _kind == "maint") and loot != null:
		loot.room_tick(p, get_tree().current_scene, "flat" if _kind == "room" else "maint")
		return
	if trace:
		_trace_t += delta
		if _trace_t >= 2.0:
			_trace_t = 0.0
			var st = _down_stairs()
			print("    [trace t=%.1f] f%d x=%.0f vx=%.0f dir_keys=%s move_target=%s(%.0f) mode=%s sel=%d atk=%s stam=%.0f stairs_x=%s zs=%s | %s" % [t, f, p.global_position.x, p.velocity.x, str(_kb), str(p.has_move_target), p.move_target_x, "scav" if WorldState.is_scavenge_mode else "combat", HUD.selected_slot, str(p.is_attacking), WorldState.stamina, str(_goal_x(st)) if st != null else "none", str(_zombies(p, SIGHT).map(func(z): return "%s@%d,y%d:%s%s hp%s" % [_type_of(z), int(z.global_position.x), int(z.global_position.y), str(z.get("state")), (" STAIR:" + str(z.get("_stair_phase"))) if z.get("stair_mode") == true else "", str(z.get("hp"))])), loot.state_line() if loot != null else ""])
	match phase:
		"play":
			if f == 0:
				_play_lobby(p)
			else:
				_play_floor(p, f)
		"leaving":
			_release_all()
			if t - _leave_t > 25.0 and f == 0:
				phase = "play"          # the door never took the press: try again
		_:
			_release_all()


## Each tick: damage / heals / kills / stamina and the rolling timeline.
func _observe(p) -> void:
	if floor_rec.is_empty():
		return
	var hs: int = WorldState.player_health
	if hs > _last_health:
		var n: int = hs - _last_health
		floor_rec["hits"] = int(floor_rec.get("hits", 0)) + n
		run_rec["hits"] = int(run_rec["hits"]) + n
		var by := _nearest_type(p)
		floor_rec["hit_by"][by] = int(floor_rec["hit_by"].get(by, 0)) + n
	_last_health = hs
	floor_rec["hp_worst"] = maxi(int(floor_rec.get("hp_worst", 0)), hs)
	floor_rec["stamina_min"] = minf(float(floor_rec.get("stamina_min", 999.0)), WorldState.stamina)
	# kills: a zombie we saw alive that is now dead (freed ones left with the scene — not a kill)
	var ids: Array = _known.keys()
	for id in ids:
		var z = instance_from_id(id)
		if z == null or not is_instance_valid(z):
			_known.erase(id)
		elif z.get("is_dead") == true:
			var ty: String = _known[id]
			floor_rec["kills"][ty] = int(floor_rec["kills"].get(ty, 0)) + 1
			run_rec["kills"] = int(run_rec["kills"]) + 1
			_known.erase(id)
	for z in _zombies(p, 99999.0):
		var zid: int = z.get_instance_id()
		if not _known.has(zid):
			_known[zid] = _type_of(z)
			floor_rec["seen"][_type_of(z)] = int(floor_rec["seen"].get(_type_of(z), 0)) + 1
	# timeline (every 0.5 s, last 12 entries)
	_tl_t += get_physics_process_delta_time()
	if _tl_t >= 0.5:
		_tl_t = 0.0
		var near: Array = []
		for z in _zombies(p, 260.0):
			near.append("%s@%d" % [_type_of(z), int(z.global_position.x - p.global_position.x)])
		_timeline.append("t=%.1f f%d x=%d hp=%s sta=%d near=%s" % [t, WorldState.current_floor, int(p.global_position.x), WorldState.health_word(), int(WorldState.stamina), ",".join(near)])
		if _timeline.size() > 14:
			_timeline.pop_front()


func _on_floor_change(f: int, p) -> void:
	if not floor_rec.is_empty():
		_close_floor(false)
	_last_floor = f
	_new_floor_rec(f, p)
	run_rec["deepest"] = mini(int(run_rec["deepest"]), f)
	run_rec["floors"] = int(run_rec["floors"]) + 1
	_floor_enter_t = t
	_no_progress_t = 0.0
	_last_x = p.global_position.x
	_kite_until = 0.0
	_shop_state = "none"
	_shop_floor = f
	_known.clear()
	if loot != null:
		loot.on_floor_change(f)
	if watch != null and f >= 1 and f % 3 == 0 and not god_no_saveload:
		watch.check_save_load("floor %d" % f)
	print("  [run %d] floor %2d  t=%6.1fs  hp=%s  stamina=%d  kit: %s" % [WorldState.current_run, f, t - float(run_rec["t_start"]), WorldState.health_word(), int(WorldState.stamina), _kit_summary()])
	if f == 0:
		_seen_lobby = true


func _new_floor_rec(f: int, p) -> void:
	var extra: Array = []
	if WorldState.is_stair_blocked(f) and f > 1:
		extra.append("barricaded stairwell")
	if WorldState.fire_intensity(f) >= 0:
		extra.append("fire (stage %d)" % WorldState.fire_intensity(f))
	if WorldState.floor_has_boss(f):
		extra.append("boss floor")
	if f in WorldState.MERCHANT_FLOORS:
		extra.append("merchant floor")
	if WorldState.haven_floor(f):
		extra.append("HAVEN (a survivor was helped here earlier)")
	var stair_dead := 0
	if f > 1 and f < 30:
		stair_dead = WorldState.stair_enemy_count(f)
	floor_rec = {
		"run": WorldState.current_run, "floor": f, "t_in": t, "t_out": t, "hp_in": WorldState.player_health, "hp_out": WorldState.player_health,
		"hp_worst": WorldState.player_health, "stamina_min": WorldState.stamina, "hits": 0, "hit_by": {}, "kills": {}, "seen": {},
		"swings": 0, "shots": 0, "pushes": 0, "heals": 0, "notes": extra, "planned_dead": WorldState.get_floor_zombie_count(f) if f < 30 and f > 0 else -1,
		"stair_dead": stair_dead, "kite_s": 0.0, "stuck": false, "pried": false, "kit_in": _kit_summary(),
	}


func _close_floor(left_by_death: bool) -> void:
	if floor_rec.is_empty():
		return
	floor_rec["t_out"] = t
	floor_rec["hp_out"] = WorldState.player_health
	floor_rec["kit_out"] = _kit_summary()
	floor_rec["died"] = left_by_death
	floors_log.append(floor_rec)
	floor_rec = {}


# =============================== PLAYING A FLOOR =======================================================

func _play_floor(p, f: int) -> void:
	var st = _down_stairs()
	var zs := _zombies(p, SIGHT)
	var threat = _pick_threat(p, zs, st)
	_manage_kit(p, zs)
	if _try_heal(p, zs):
		return
	# a barricaded stairwell needs a crowbar. liberty: hand one over now · fallback: only once the floor's doors have been tried ·
	# found: never (the bot is stuck here, and the report says so)
	if st != null and WorldState.is_stair_blocked(_choke(st)) and not WorldState.has_crowbar() and crowbar_mode != "found":
		floor_rec["blocked"] = true
		var exhausted: bool = crowbar_mode == "liberty" or loot_mode == "none" or (loot != null and threat == null and loot.floor_exhausted(p, get_tree().current_scene))
		if exhausted:
			var cb := ItemInstance.new()
			cb.setup("035")
			cb.set_meta("bot_gift", true)
			WorldState.inventory.append(cb)                # outside the five slots on purpose
			floor_rec["pried"] = true
			floor_rec["notes"].append("crowbar handed over for the barricade (%s)" % ("liberty" if crowbar_mode == "liberty" or loot_mode == "none" else "after the floor's doors gave none"))
			_event("CROWBAR", "floor %d: barricaded stairwell — a crowbar was handed to the bot (%s)" % [f, crowbar_mode])
			if loot != null:
				loot.count("crowbar_liberties")
	if st != null and st.is_prying:
		if threat != null and _edge(p, threat) < 80.0:
			st._cancel_pry("The bot breaks off to fight.")
		else:
			_release_all()
			return
	# the merchant (floors 25 / 20 / 15 / 10 / 5): the upgrade pick and the boon
	if f in WorldState.MERCHANT_FLOORS and _shop_state != "done" and (threat == null or _edge(p, threat) > 200.0):
		if _visit_merchant(p, f):
			return
	# a fight that has gone nowhere for a long while (nobody dies, nobody is hurt — the dance in a crowd that overlaps the bot, most
	# often with god mode on) is dropped for a few seconds: get on with the floor
	if threat != null:
		if _fight_since < 0.0 or int(run_rec["kills"]) != _fight_kills:
			_fight_since = t
			_fight_kills = int(run_rec["kills"])
		elif t - _fight_since > 14.0 and t >= _ignore_threats_until:
			_ignore_threats_until = t + 7.0
			_fight_since = -1.0
			if loot != null:
				loot.count("fights_dropped")
			_event("FIGHT", "floor %d: 14 s of fighting and no kill — walking on" % f)
		if t < _ignore_threats_until:
			threat = null
	else:
		_fight_since = -1.0
	if threat != null:
		want_scav = false                     # a fight is fought drawn: without this the door-work's "scavenge" stance and the fight's drew-the-weapon stance toggle for ever
		_fight(p, threat, zs)
		_stuck_watch(p, true)
		return
	_kite_until = 0.0
	if loot != null and loot_mode != "none" and not (st != null and st.is_prying):
		if loot.corridor_tick(p, get_tree().current_scene):
			_stuck_watch(p, false)
			return
	if rest_mode and WorldState.rest_available and threat == null and WorldState.stamina < WorldState.get_max_stamina() * 0.7 and not p.is_attacking and _stairs_gate <= 0.0:
		_stairs_gate = 1.0
		var rest_ev := InputEventAction.new()
		rest_ev.action = "rest"
		rest_ev.pressed = true
		get_viewport().push_input(rest_ev)
		if loot != null:
			loot.count("rests")
	if elevator_mode and loot != null and WorldState.can_ride_elevator() and f >= 8 and not (f in WorldState.MERCHANT_FLOORS) and _ride_elevator(p):
		return
	want_scav = false
	_advance(p, st, zs)
	_stuck_watch(p, false)


## Who is worth fighting right now: anything chasing/attacking within reach distance, then the nearest thing in the way ahead.
func _pick_threat(p, zs: Array, st):
	if zs.is_empty():
		return null
	if god and not _armed() and _slot_of_gun() < 0:
		return null                       # nothing to fight with and nothing can hurt it: walk on (the unjam valve lets it through a body)
	var goal := _goal_x(st)
	var dir_goal: float = signf(goal - p.global_position.x)
	var best = null
	var best_score := INF
	for z in zs:
		var dx: float = z.global_position.x - p.global_position.x
		var edge := absf(dx) - float(p._zombie_body_radius(z))
		var ahead: bool = signf(dx) == dir_goal
		var coming: bool = _on_me(p, z)
		var score := edge
		if style == "runner" or not _armed():
			# a runner (or anyone with no hammer left) only deals with what blocks it or is already on it
			if not coming and not (ahead and edge < 70.0):
				continue
			if not ahead and edge > 90.0:
				continue
		else:
			if not coming and not ahead and edge > 60.0:
				continue
			if not coming and ahead and edge > 220.0:
				continue
		if _type_of(z) in ["big", "spitter"]:
			score -= 30.0         # the ones that hurt come first
		if score < best_score:
			best_score = score
			best = z
	return best


func _fight(p, z, zs: Array) -> void:
	var dx: float = z.global_position.x - p.global_position.x
	var facing_right: bool = not p.animated_sprite.flip_h
	# a body standing ON the bot has no side: keep the way we face, or the turn-round step flip-flops for ever against a wall
	var dirx: float = signf(dx) if absf(dx) > 14.0 else (1.0 if facing_right else -1.0)
	var edge := _edge(p, z)
	var stam: float = WorldState.stamina
	var max_stam: float = WorldState.get_max_stamina()
	var winded: bool = stam < max_stam * 0.25 + 1.0 or stam < _cur_cost
	var ty := _type_of(z)
	_sprint(false)
	# winded and nothing is actually coming for us (the dead in reach are standing idle): catch the breath where we stand — kiting away from
	# an idle body only ping-pongs against whatever walks us back (the looter's walk to its node)
	if winded:
		var active := false
		for o in zs:
			if _edge(p, o) < 260.0 and str(o.get("state")) in ["chase", "attack", "hit"]:
				active = true
		if not active:
			_walk(0.0)
			return
	# the gun: for the ones that are worst to meet with a hammer, while it has rounds and they are not in our face
	var gun_slot := _slot_of_gun()
	var gun_ok: bool = (ty in ["big", "spitter"]) or (z.get("is_corridor_boss") == true) or not _armed()
	var cornered_winded: bool = winded and edge < 130.0 and not _room_behind(p, dirx)
	var unarmed_gun: bool = gun_slot >= 0 and not _armed()          # nothing else to hit with: the gun, at any range
	if gun_slot >= 0 and ((gun_ok and edge > GUN_MIN_RANGE) or unarmed_gun or (winded and edge < 160.0) or cornered_winded) and edge < 240.0:
		if _select(gun_slot):
			if (dirx > 0.0) != facing_right:
				_walk(dirx)
				return
			_walk(0.0)
			if _swing_gate <= 0.0 and not p.is_attacking:
				_swing_gate = 0.7
				_press_attack()
				floor_rec["shots"] = int(floor_rec["shots"]) + 1
				run_rec["shots"] = int(run_rec["shots"]) + 1
			return
	# the hammer
	var w := _best_hammer_slot()
	if w < 0:
		_brawl(p, z, zs)
		return
	if not _select(w):
		_walk(0.0)
		return
	_note_weapon(WorldState.inventory[w])
	# shove: two or more on us, or a big one in our face, and the wind for it
	var adjacent := 0
	for o in zs:
		if absf(o.global_position.x - p.global_position.x) < 55.0:
			adjacent += 1
	if (adjacent >= 2 or (ty == "big" and edge < 50.0)) and stam >= PUSH_COST and _push_gate <= 0.0 and not p.is_pushing and not p.is_attacking:
		if (dirx > 0.0) != facing_right:
			_walk(dirx)
			return
		_push_gate = 1.4
		tap("push", 0.3)
		floor_rec["pushes"] = int(floor_rec["pushes"]) + 1
		run_rec["pushes"] = int(run_rec["pushes"]) + 1
		return
	# out of wind: walk away from it until there is some (they are slower than we are)
	if winded and style == "fighter" and edge < 140.0 and _room_behind(p, dirx):
		_kite_until = t + 1.2
	if t < _kite_until and style == "fighter":
		floor_rec["kite_s"] = float(floor_rec["kite_s"]) + get_physics_process_delta_time()
		_walk(-dirx)
		_sprint(WorldState.stamina > 12.0 and edge < 90.0)
		return
	if (dirx > 0.0) != facing_right:
		_walk(dirx)                           # one step to turn round
		return
	if edge > _cur_reach * 0.85:
		var coming: bool = _on_me(p, z)
		_hold_t = _hold_t + get_physics_process_delta_time() if (coming and edge < _cur_reach + 60.0) else 0.0
		if coming and edge < _cur_reach + 60.0 and _hold_t < 1.2:
			_walk(0.0)                        # let it come: the first swing is ours (but not for ever)
		else:
			_walk(dirx)
			_sprint(style == "runner" and edge > 160.0 and WorldState.stamina > 40.0)
		return
	_walk(0.0)
	if _swing_gate <= 0.0 and not p.is_attacking and not winded:
		_swing_gate = 0.35
		_press_attack()
		floor_rec["swings"] = int(floor_rec["swings"]) + 1
		run_rec["swings"] = int(run_rec["swings"]) + 1


## No working melee weapon left (and nothing worth a round): get through. Shove what stands in the way, keep pushing for the stairs — the
## game phases a player through a body after half a second of leaning on it.
func _brawl(p, z, zs: Array) -> void:
	var st = _down_stairs()
	var goal_dir: float = signf(_goal_x(st) - p.global_position.x)
	var dx: float = z.global_position.x - p.global_position.x
	var edge := _edge(p, z)
	var facing_right: bool = not p.animated_sprite.flip_h
	var stam: float = WorldState.stamina
	if edge < 50.0 and stam >= PUSH_COST and _push_gate <= 0.0 and not p.is_pushing and (dx > 0.0) == facing_right:
		_push_gate = 1.3
		tap("push", 0.3)
		floor_rec["pushes"] = int(floor_rec["pushes"]) + 1
		run_rec["pushes"] = int(run_rec["pushes"]) + 1
	_walk(goal_dir if goal_dir != 0.0 else signf(dx))
	_sprint(stam > 25.0)
	# on the steps already: take them (anything that chases follows, as it would a person)
	if st != null and absf(_goal_x(st) - p.global_position.x) < 24.0 and _stairs_gate <= 0.0 and not st.is_prying:
		_stairs_gate = 0.3
		st.request_auto_descend()


func _armed() -> bool:
	return _best_hammer_slot() >= 0


var _cur_reach: float = REACH
var _cur_cost: float = SWING_COST


## The reach and stamina cost of the melee weapon in hand (the game's own tables).
func _note_weapon(inst) -> void:
	var ty := _weapon_type(inst)
	var p = _player()
	if p == null or not p.WEAPON_RANGES.has(ty):
		return
	_cur_reach = float(p.WEAPON_RANGES[ty])
	_cur_cost = float(p.WEAPON_STAMINA_COST[ty])


## Nothing to fight: walk (sprint when the way is clear and there is wind to spare) to the down stairs and take them.
func _advance(p, st, zs: Array) -> void:
	if st == null:
		_release_all()
		return
	var goal := _goal_x(st)
	var x: float = p.global_position.x
	var far: bool = absf(goal - x) > 200.0
	var burning := _fire_ahead(p, signf(goal - x))
	var wind_ok: bool = WorldState.stamina > WorldState.get_max_stamina() * (0.45 if _kb.get("sprint", false) else 0.7)       # (hysteresis: start at 70%, drop out at 45%)
	_sprint(((zs.is_empty() and far and wind_ok) or burning) and WorldState.stamina > 8.0)
	if _stairs_gate <= 0.0:
		_stairs_gate = 0.3
		if not st.is_prying:
			st.request_auto_descend()
	else:
		pass
	if not p.has_move_target and absf(goal - x) > 6.0:
		_walk(signf(goal - x))
	elif p.has_move_target:
		_walk(0.0)                             # the click-move is steering; keys would cancel it


func _goal_x(st) -> float:
	if goal_override >= 0.0:
		return goal_override
	if st == null:
		return 600.0
	return float(st.auto_target_x())


func _choke(st) -> int:
	return int(st._choke_floor())


func _down_stairs():
	var scene = get_tree().current_scene
	if scene == null:
		return null
	for n in scene.get_children():
		if n is Area2D and n.get("direction") == "down" and n.process_mode != Node.PROCESS_MODE_DISABLED and n.has_method("_perform_transition"):
			return n
	return null


## The kit's upkeep: the working hammer in hand, mode combat.
func _manage_kit(p, _zs: Array) -> void:
	if god and not _armed() and _slot_of_gun() < 0:
		# COVERAGE runs only: a god-mode character cannot die, so unarmed it just stands pinned among the dead for hours. Hand it a hammer
		# (outside the slots, like the crowbar) so it clears its way and the run goes on to the parts of the game it is there to visit.
		var hm := ItemInstance.new()
		hm.setup("002")
		hm.set_meta("bot_gift", true)
		WorldState.inventory.append(hm)
		if loot != null:
			loot.count("god_hammers")
	if WorldState.is_scavenge_mode != want_scav and not p.is_switching_mode and not WorldState.loot_open:
		p.request_mode_toggle()
	if loot != null:
		loot.maintain_kit(p, _zs)


func _try_heal(p, zs: Array) -> bool:
	if _heal_gate > 0.0:
		return false
	var hs: int = WorldState.player_health
	if hs < 2:
		return false
	var slot := _pick_heal_slot(hs)
	if slot < 0:
		return false
	if hs < 3 and WorldState.inventory[slot].item_id == "007":
		return false                      # a first aid is for a real wound
	var close := 0
	for z in zs:
		if _edge(p, z) < 60.0:
			close += 1
	if hs < 5 and close > 0:
		return false                     # fight first unless it's dire
	_heal_gate = 1.0
	_release_all()
	var used_id: String = WorldState.inventory[slot].item_id
	var used_name: String = WorldState.inventory[slot].get_item_name()
	p.use_item(slot)
	floor_rec["heals"] = int(floor_rec["heals"]) + 1
	run_rec["heals"] = int(run_rec["heals"]) + 1
	if loot != null:
		loot.count("heal_" + used_id)
	_event("HEAL", "floor %d: %s at %s" % [WorldState.current_floor, used_name, WorldState.HEALTH_WORDS[clampi(hs, 0, 5)]])
	return true


## The health item that covers the wound with the least waste (or the biggest one there is).
func _pick_heal_slot(hs: int) -> int:
	var best := -1
	var best_h := 0
	var big := -1
	var big_h := 0
	for i in WorldState.inventory.size():
		var inst = WorldState.inventory[i]
		if not inst.get_data().get("is_health_item", false):
			continue
		var h: int = inst.base_heals() + WorldState.get_heal_bonus()
		if h >= hs and (best < 0 or h < best_h):
			best = i
			best_h = h
		if h > big_h:
			big = i
			big_h = h
	return best if best >= 0 else big


# --- the merchant -----------------------------------------------------------------------------------

func _visit_merchant(p, f: int) -> bool:
	var merchant = null
	var scene = get_tree().current_scene
	if scene != null:
		for n in scene.get_children():
			if n.has_method("_open_shop"):
				merchant = n
	if merchant == null:
		if _shop_state != "done":
			_shop_state = "done"
			floor_rec["notes"].append("no merchant out (sheltering from fire?)")
		return false
	if t - _floor_enter_t > 70.0 and _shop_state != "open":
		_shop_state = "done"
		floor_rec["notes"].append("gave up on the merchant after 70 s")
		return false
	match _shop_state:
		"none", "walking":
			_shop_state = "walking"
			if merchant.player_nearby:
				_walk(0.0)
				if _shop_gate <= 0.0:
					_shop_gate = 0.5
					Input.action_press("interact")
					_kb["interact"] = true
					_shop_state = "open"
					_shop_gate = 0.8
				return true
			if absf(p.global_position.x - MERCHANT_X) > 12.0:
				if _stairs_gate <= 0.0:
					_stairs_gate = 0.25
					p.set_move_target(MERCHANT_X)
				if not p.has_move_target:
					_walk(signf(MERCHANT_X - p.global_position.x))
				_sprint(false)
			return true
		"open":
			_release_all()
			if _shop_gate > 0.0:
				return true
			var ui = merchant.shop_ui
			if ui == null or not is_instance_valid(ui) or not ui.visible:
				if _shop_gate <= 0.0:
					_shop_state = "walking"
					_shop_gate = 0.6
				return true
			_shop_choices(ui, f)
			if loot != null:
				loot.shop_trade(ui, f)
			_shop_state = "done"
			ui.close()
			return false
	return false


func _shop_choices(ui, f: int) -> void:
	# the upgrade (pick-1-of-2) …
	if not WorldState.is_upgrade_offer_resolved(f):
		var pair: Array = WorldState.get_upgrade_pair(f)
		var best := ""
		var best_score := -999
		for id in pair:
			var sc: int = int(UPGRADE_SCORE.get(id, 0))
			if sc > best_score:
				best_score = sc
				best = id
		if best != "":
			ui._on_take_upgrade(best)
			upgrades_taken.append({"run": WorldState.current_run, "floor": f, "taken": best, "name": WorldState.UPGRADE_POOL[best]["name"], "offered": pair.duplicate()})
			floor_rec["notes"].append("upgrade: %s (offered %s)" % [WorldState.UPGRADE_POOL[best]["name"], str(pair)])
			_event("UPGRADE", "floor %d: took %s — %s (offered %s)" % [f, best, WorldState.UPGRADE_POOL[best]["name"], str(pair)])
	# … then this character's boon
	if f in WorldState.pending_boon_floors:
		var offer: Array = WorldState.boon_offer(f)
		var bb := ""
		var bs := -999
		for id in offer:
			var sc2: int = int(BOON_SCORE.get(id, 0))
			if sc2 > bs:
				bs = sc2
				bb = id
		if bb != "":
			var err: String = ui.take_boon(bb)
			if err == "":
				boons_taken.append({"run": WorldState.current_run, "floor": f, "taken": bb, "offered": offer.duplicate()})
				floor_rec["notes"].append("boon: %s (offered %s)" % [bb, str(offer)])
				_event("BOON", "floor %d: took %s (offered %s)" % [f, bb, str(offer)])


# --- the lobby ----------------------------------------------------------------------------------------

func _play_lobby(p) -> void:
	var zs := _zombies(p, SIGHT)
	var threat = _pick_lobby_threat(p, zs)
	_manage_kit(p, zs)
	if _try_heal(p, zs):
		return
	if not floor_rec.has("lobby_reached"):
		floor_rec["lobby_reached"] = true
		_event("LOBBY", "reached the lobby on run %d at %.0f s (hp %s)" % [WorldState.current_run, t - float(run_rec["t_start"]), WorldState.health_word()])
	if threat != null:
		_fight(p, threat, zs)
		return
	_sprint(false)
	var ex = _lobby_exit()
	if ex != null and ex.get("_player_near") == true:
		_walk(0.0)
		if _exit_gate <= 0.0:
			_exit_gate = 0.5
			Input.action_press("interact")
			_kb["interact"] = true
			phase = "leaving"
			_leave_t = t
			_event("EXIT", "pressed the door")
		return
	if _stairs_gate <= 0.0:
		_stairs_gate = 0.25
		p.set_move_target(LOBBY_EXIT_X)
	if not p.has_move_target and absf(p.global_position.x - LOBBY_EXIT_X) > 6.0:
		_walk(signf(LOBBY_EXIT_X - p.global_position.x))


func _pick_lobby_threat(p, zs: Array):
	var best = null
	var bs := INF
	for z in zs:
		var dx: float = z.global_position.x - p.global_position.x
		var edge := absf(dx) - float(p._zombie_body_radius(z))
		var coming: bool = _on_me(p, z)
		if (coming or (signf(dx) == signf(LOBBY_EXIT_X - p.global_position.x) and edge < 200.0)) and edge < bs:
			bs = edge
			best = z
	return best


func _lobby_exit():
	for n in get_tree().get_nodes_in_group("lobby_exit"):
		return n
	return null


# =============================== RUN BOUNDARIES ========================================================

func _on_death(p) -> void:
	if phase == "over" or run_rec.get("outcome", "") != "":
		return
	var near: Array = []
	var scene = get_tree().current_scene
	for z in get_tree().get_nodes_in_group("zombie"):
		# straight from the group: AiMind.gap reads "no reach" for a dead player, which emptied this list
		if not is_instance_valid(z) or z.get("is_dead") == true or z.is_in_group("pan_scenery"):
			continue
		if scene != null and not scene.is_ancestor_of(z):
			continue
		if absf(z.global_position.x - p.global_position.x) <= 400.0:
			near.append("%s %d px %s" % [_type_of(z), int(absf(z.global_position.x - p.global_position.x)), str(z.get("state"))])
	for r in get_tree().get_nodes_in_group("resident_npc"):
		if is_instance_valid(r) and r.get("is_dead") != true and scene != null and scene.is_ancestor_of(r) and absf(r.global_position.x - p.global_position.x) <= 400.0:
			near.append("RESIDENT %s %d px %s%s" % [str(r.get("temper")), int(absf(r.global_position.x - p.global_position.x)), str(r.get("state")), " VIOLENT" if r.get("violent") == true else ""])
	run_rec["death"] = {
		"floor": WorldState.current_floor, "t": t - float(run_rec["t_start"]), "near": near, "timeline": _timeline.duplicate(), "scene": _kind,
		"room": (loot.room_id if loot != null and loot.in_room else ""),
		"kit": _kit_summary(), "was_dying": WorldState.is_dying,
	}
	_event("DEATH", "run %d: died on floor %d after %.0f s — near: %s" % [WorldState.current_run, WorldState.current_floor, t - float(run_rec["t_start"]), str(near)])
	_close_floor(true)
	_finish_run("dead", "died on floor %d" % WorldState.current_floor)


func _finish_run(outcome: String, why: String) -> void:
	if run_rec.get("outcome", "") != "":
		return
	run_rec["outcome"] = outcome
	run_rec["why"] = why
	run_rec["t_end"] = t
	run_rec["kit_end"] = _kit_summary()
	run_rec["scrap_end"] = WorldState.scrap
	run_rec["notes_end"] = WorldState.get_money_total()
	run_rec["fuses_loaded"] = WorldState.elevator_fuses_loaded
	run_rec["fuses_carried"] = WorldState.fuse_count()
	run_rec["powered"] = WorldState.elevator_powered
	run_rec["searched_total"] = WorldState.run_scavenged
	run_rec["wall_s"] = snappedf(float(Time.get_ticks_msec() - wall_start_ms) / 1000.0, 0.1)
	if outcome == "stuck" or outcome == "timeout":
		_close_floor(false)
	_release_all()
	_write_report()                 # after EVERY character: a sweep that is cut off still leaves what it had
	var stop: bool = int(run_rec["run"]) >= max_runs
	if outcome == "stuck" or outcome == "timeout":
		stop = true
	if outcome == "dead" and int(run_rec["run"]) == 1 and not keep_going:
		stop = true                 # the brief: only a bot that reaches the lobby goes on to runs 2 and 3
	if stop:
		_finish_all()
		return
	phase = "wait_next"             # the game's own end-of-run flow takes the character from here (death card / lobby door)


func _on_new_character(p) -> void:
	# a new run began (the game advanced it): once its hallway is up, a fresh kit and a fresh record
	if phase == "over":
		return
	if p.get_parent() == null or str(p.get_parent().scene_file_path) != HALLWAY or Transition.busy:
		_release_all()
		return
	_give_kit()
	_begin_run()
	phase = "play"


func _finish_all() -> void:
	phase = "over"
	finished = true
	_release_all()
	if watch != null:
		watch.tick(null, 0.6, "finishing")       # one last sweep of the engine log
	_write_report()
	if watch != null:
		watch.detach()
	print("=== bot run done: ", _headline(), " ===")
	get_tree().quit(0)


# =============================== SENSES + CONTROLS =====================================================

func _player():
	var p = get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		return null
	var scene = get_tree().current_scene
	if scene != null and p.get_parent() != scene:
		return null
	return p


## The living dead on the player's plane within `rng` px along the lane, nearest first.
func _zombies(p, rng: float) -> Array:
	var out: Array = []
	var scene = get_tree().current_scene
	for z in get_tree().get_nodes_in_group("zombie"):
		if not is_instance_valid(z) or not AiMind.present(z) or z.is_in_group("pan_scenery"):
			continue
		if scene != null and not scene.is_ancestor_of(z):
			continue
		if AiMind.gap(p, z) >= AiMind.NO_REACH:
			continue
		if absf(z.global_position.x - p.global_position.x) <= rng:
			out.append(z)
	out.sort_custom(func(a, b): return absf(a.global_position.x - p.global_position.x) < absf(b.global_position.x - p.global_position.x))
	return out


## Is this one coming for ME (chasing the player, or on the player) — not busy with a survivor?
func _on_me(p, z) -> bool:
	var pr = z.get("prey")
	if pr != null and is_instance_valid(pr):
		return pr == p
	return str(z.get("state")) == "chase"


func _edge(p, z) -> float:
	return absf(z.global_position.x - p.global_position.x) - float(p._zombie_body_radius(z))


func _type_of(z) -> String:
	if (z.get("is_corridor_boss") == true):
		return "boss"
	return z.scene_file_path.get_file().get_basename().replace("enemy_zombie_", "")


func _nearest_type(p) -> String:
	var zs := _zombies(p, 120.0)
	if zs.is_empty():
		# a resident who has turned on us (survivors behind locked doors) is not in the `zombie` group
		for r in get_tree().get_nodes_in_group("resident_npc"):
			if is_instance_valid(r) and r.get("is_dead") != true and r.get("violent") == true and absf(r.global_position.x - p.global_position.x) < 120.0:
				return "resident"
		# standing in flame (a corridor blaze or an apartment fire share the fire_field interface)
		for f in get_tree().get_nodes_in_group("fire_field"):
			if is_instance_valid(f) and f.has_method("is_burning_at") and f.is_burning_at(p.global_position.x):
				return "fire"
		# a spit, a pounce that has already landed, a body that bit and was shoved off: the nearest dead within a screen, by how it was acting
		var far := _zombies(p, 400.0)
		if not far.is_empty():
			return "far:%s:%s" % [_type_of(far[0]), str(far[0].get("state"))]
		return "unknown"
	return _type_of(zs[0])


func _room_behind(p, dirx: float) -> bool:
	var x: float = p.global_position.x
	return (x - 200.0 > 190.0) if dirx > 0.0 else (x + 200.0 < 1180.0)


func _fire_ahead(p, dirx: float) -> bool:
	for fld in get_tree().get_nodes_in_group("fire_field"):
		if not is_instance_valid(fld):
			continue
		for dx in [20.0, 60.0, 100.0]:
			if fld.has_method("is_burning_at") and fld.is_burning_at(p.global_position.x + dirx * dx):
				return true
	return false


func _walk(d: float) -> void:
	if d > 0.0:
		_set_key("move_right", true)
		_set_key("move_left", false)
	elif d < 0.0:
		_set_key("move_left", true)
		_set_key("move_right", false)
	else:
		_set_key("move_left", false)
		_set_key("move_right", false)


func _sprint(on: bool) -> void:
	_set_key("sprint", on)


func _set_key(action: String, on: bool) -> void:
	var was: bool = bool(_kb.get(action, false))
	if on and not was:
		Input.action_press(action)
		_kb[action] = true
	elif not on and was:
		Input.action_release(action)
		_kb[action] = false


func _release_all() -> void:
	for a in _kb.keys():
		if bool(_kb[a]):
			Input.action_release(a)
			_kb[a] = false


func _press_attack() -> void:
	var ev := InputEventAction.new()
	ev.action = "attack"
	ev.pressed = true
	get_viewport().push_input(ev)


# --- helpers the looter (bot_loot.gd) uses ---------------------------------------------------------------

## Press an action for `dur` seconds of game time (a polled `is_action_just_pressed` needs the frame to see it down).
## Press an action for `dur` game seconds. A tap that is still down is NOT extended: the game polls `is_action_just_pressed`, which needs a
## fresh press edge, and a key re-tapped every tick is simply held down for ever (the first press can be lost — a stance still
## switching, a door not yet in reach — and nothing would ever press again). Long enough to span an idle frame at the sped-up tick rate.
func tap(action: String, dur: float = 0.4) -> void:
	if _taps.has(action):
		return
	Input.action_press(action)
	_taps[action] = t + dur


func after(secs: float, cb: Callable) -> void:
	_afters.append([t + secs, cb])


func _run_taps_and_afters() -> void:
	for a in _taps.keys():
		if t >= float(_taps[a]):
			Input.action_release(a)
			_taps.erase(a)
	var keep: Array = []
	for e in _afters:
		if t >= float(e[0]):
			if e[1].is_valid():
				e[1].call()
		else:
			keep.append(e)
	_afters = keep


## The stance the looter wants (scavenge = hands free to search, combat = a weapon up). True once it is the stance we are in.
func stance_settled(scav: bool) -> bool:
	if WorldState.is_scavenge_mode == scav and not _player().is_switching_mode:
		return true
	if not _player().is_switching_mode and not WorldState.loot_open and _stance_gate <= 0.0:
		_stance_gate = 0.6
		_player().request_mode_toggle()
	return false


var _stance_gate: float = 0.0


func select_slot(slot: int) -> void:
	if slot >= 0 and slot < WorldState.inventory.size() and HUD.selected_slot != slot and _slot_gate <= 0.0:
		_slot_gate = 0.25
		HUD.select_slot(slot)


func is_player_busy(p) -> bool:
	return p.is_cutscene or p.is_switching_mode or p.get("_back_stepping") == true or p.is_attacking or p.is_pushing


func try_heal_now(p, zs: Array) -> bool:
	return _try_heal(p, zs)


func _scene_kind(scene: Node) -> String:
	if scene == null:
		return ""
	var sp: String = str(scene.scene_file_path)
	if sp.ends_with("/room.tscn"):
		return "room"
	if sp.ends_with("/maintenance.tscn"):
		return "maint"
	if sp.ends_with("/hallway.tscn"):
		return "hallway"
	if sp.ends_with("/lobby.tscn"):
		return "lobby"
	if sp.ends_with("/building_floors.tscn"):
		return "corridor"
	return "other"


## Walk to the powered lift and press [interact]; the car takes it from there (elevator_interior.gd, polled keys).
func _ride_elevator(p) -> bool:
	var ex := 1029.5
	if absf(p.global_position.x - ex) > 24.0:
		_walk(signf(ex - p.global_position.x))
		_sprint(absf(ex - p.global_position.x) > 220.0)
		return true
	_walk(0.0)
	_stairs_gate -= get_physics_process_delta_time()
	if _stairs_gate <= 0.0:
		_stairs_gate = 2.0
		WorldState.interaction_handled = false
		tap("interact")
		loot.count("elevator_rides_started")
	return true


## What the bot is in the middle of, in words (the watcher quotes it when nothing has changed for a while).
## One physics frame of detail about a stall (after a NO_PROGRESS): where the player is, what it is told to do, and every body about it.
func _print_stall_frame(p) -> void:
	var near: Array = []
	for z in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(z) and absf(z.global_position.x - p.global_position.x) < 160.0 and not z.is_in_group("pan_scenery"):
			near.append("%s@%.1f:%s%s%s" % [_type_of(z), z.global_position.x, str(z.get("state")), "(S)" if z.collision_layer & 1 != 0 else "", "(X)" if p.get_collision_exceptions().has(z) else ""])
	var cols: Array = []
	for i in p.get_slide_collision_count():
		var o = p.get_slide_collision(i).get_collider()
		cols.append("%s@%.0f" % [str(o.name), o.global_position.x if o is Node2D else -1.0])
	print("      [stall] f=%d x=%.2f vx=%.0f stuck=%.2f phased=%d keys=%s atk=%s push=%s cols=%s zs=%s | %s" % [Engine.get_physics_frames(), p.global_position.x, p.velocity.x, float(p._stuck_time), p._phased_bodies.size(), str(_kb), str(p.is_attacking), str(p.is_pushing), str(cols), str(near), _activity_text().left(110)])


func _activity_text() -> String:
	var bits: Array = ["phase=" + phase, "scene=" + _kind, "shop=" + _shop_state]
	if loot != null:
		if loot.in_room:
			bits.append("room=%s anchor=%s stage=%s exiting=%s panel=%s" % [loot.room_id, str(loot.cur_anchor.name) if loot.cur_anchor != null and is_instance_valid(loot.cur_anchor) else "-", loot.anchor_stage, str(loot.exiting), str(WorldState.loot_open)])
		elif loot.cur_door != null and is_instance_valid(loot.cur_door):
			bits.append("door=%s stage=%s state=%s" % [str(loot.cur_door.apartment_id), loot.door_stage, loot._state_name(int(loot.cur_door.current_state))])
	return " ".join(bits)


## A thing that should not happen: logged, counted, written into the report (and the sweep summary).
func _anomaly(kind: String, msg: String) -> void:
	anomalies.append({"t": snappedf(t, 0.1), "run": WorldState.current_run, "floor": WorldState.current_floor, "kind": kind, "msg": msg})
	print("  [ANOMALY] %s: %s" % [kind, msg])


# slots ---------------------------------------------------------------------------------------------------

func _slot_of_gun() -> int:
	for i in WorldState.inventory.size():
		var inst = WorldState.inventory[i]
		if inst.item_id == "004" and inst.mag_count > 0 and not inst.is_depleted:
			return i
	return -1


## The best working melee weapon (any kind the game has): a bat-class weapon over a sword over a knife, then by uses left.
func _best_hammer_slot() -> int:
	var best := -1
	var best_s := -1.0
	for i in WorldState.inventory.size():
		var inst = WorldState.inventory[i]
		if inst.is_depleted or not inst.get_data().get("is_weapon", false):
			continue
		var ty := _weapon_type(inst)
		if ty == "gun" or ty == "":
			continue
		var sc: float = float(BotLoot.MELEE_RANK.get(ty, 0)) + float(inst.current_durability)
		if sc > best_s:
			best_s = sc
			best = i
	return best


func _weapon_type(inst) -> String:
	return _weapon_type_of_data(inst.get_data())


func _weapon_type_of_data(d: Dictionary) -> String:
	var p = _player()
	if p == null:
		return ""
	return str(p.call("_get_weapon_type", d))


func _slot_of_kit() -> int:
	for i in WorldState.inventory.size():
		var inst = WorldState.inventory[i]
		if inst.item_id == "007":
			return i
	return -1


## Equip a slot (HUD.select_slot toggles when re-selecting the same one, so only when it differs). True once it is in hand.
func _select(slot: int) -> bool:
	if HUD.selected_slot == slot:
		return true
	if _slot_gate > 0.0:
		return false
	_slot_gate = 0.25
	HUD.select_slot(slot)
	return HUD.selected_slot == slot


func _kit_summary() -> String:
	var parts: Array = []
	for inst in WorldState.inventory:
		match inst.item_id:
			"002":
				parts.append("hammer%s" % ("(broken)" if inst.is_depleted else "(%d)" % inst.current_durability))
			"004":
				parts.append("gun(%d)" % inst.mag_count)
			"007":
				parts.append("kit")
			"035":
				parts.append("crowbar")
			_:
				parts.append(inst.item_id)
	return " ".join(parts)


func _stuck_watch(p, _fighting: bool) -> void:
	var x: float = p.global_position.x
	if t - _floor_enter_t > FLOOR_TIMEOUT:
		floor_rec["stuck"] = true
		var st = _down_stairs()
		var why := "no way down in %.0f s" % FLOOR_TIMEOUT
		if st != null:
			why += " (stairs at x=%d, bot at x=%d, blocked=%s, crowbar=%s, prying=%s)" % [int(_goal_x(st)), int(x), str(WorldState.is_stair_blocked(_choke(st))), str(WorldState.has_crowbar()), str(st.is_prying)]
		run_rec["stuck"] = {"floor": WorldState.current_floor, "why": why}
		_event("STUCK", "floor %d: %s" % [WorldState.current_floor, why])
		_finish_run("stuck", why)


## The cold open of runs 2 and 3: any key hurries / dismisses it.
func _skip_intro() -> void:
	if _intro_gate > 0.0:
		return
	var scene = get_tree().current_scene
	if scene == null:
		return
	for n in scene.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("intro_overlay.gd"):
			_intro_gate = 0.15
			if n.has_method("skip_to_line") and not n.get("line_shown"):
				n.skip_to_line()
			var ev := InputEventKey.new()
			ev.keycode = KEY_SPACE
			ev.physical_keycode = KEY_SPACE
			ev.pressed = true
			get_viewport().push_input(ev)
			return
	# a pausing line (the two locked-out characters' lockout lines at 3001, any teaching beat): the press it waits for
	if TutorialManager.get("_awaiting") == true:
		_intro_gate = 0.15
		var ev2: InputEvent
		if TutorialManager.get("_await_strict") == true:
			var ea := InputEventAction.new()
			ea.action = str(TutorialManager.get("_await_action"))
			ea.pressed = true
			ev2 = ea
		else:
			var ek := InputEventKey.new()
			ek.keycode = KEY_SPACE
			ek.physical_keycode = KEY_SPACE
			ek.pressed = true
			ev2 = ek
		get_viewport().push_input(ev2)


# =============================== REPORT ================================================================

func _event(kind: String, msg: String) -> void:
	events.append({"t": snappedf(t, 0.1), "run": WorldState.current_run, "kind": kind, "msg": msg})
	if kind in ["RUN", "LOBBY", "DEATH", "STUCK", "UPGRADE", "BOON", "CROWBAR", "EXIT", "KIT", "SCENE"]:
		print("  [%s] %s" % [kind, msg])


func _headline() -> String:
	var bits: Array = []
	for r in runs:
		bits.append("run %d %s (deepest floor %d, %d kills, %d hits, %d heals)" % [r["run"], r.get("outcome", "?"), r["deepest"], r["kills"], r["hits"], r["heals"]])
	return "; ".join(bits)


func _write_report() -> void:
	var md: Array = []
	md.append("# Descent bot — seed %d (%s style)" % [seed_value, style])
	md.append("")
	md.append("Generated by `tools/bot_run.tscn` (docs/BOT_RUNS.md). Game time, not wall time. %d physics steps/s at %dx." % [60 * speed, speed])
	md.append("")
	md.append("**Result:** " + _headline())
	md.append("")
	for r in runs:
		md.append("## Run %d — %s (%s)" % [r["run"], r["character"], WorldState.run_name(int(r["run"]))])
		md.append("")
		md.append("- outcome: **%s** — %s" % [r.get("outcome", "?"), r.get("why", "")])
		md.append("- deepest floor: **%d** · floors entered: %d · time: %.0f s" % [r["deepest"], r["floors"], float(r.get("t_end", t)) - float(r["t_start"])])
		md.append("- kills %d · hits taken %d · first aids used %d · swings %d · shots %d · shoves %d" % [r["kills"], r["hits"], r["heals"], r["swings"], r["shots"], r["pushes"]])
		md.append("- kit at the end: %s" % r.get("kit_end", ""))
		if not (r["death"] as Dictionary).is_empty():
			var d: Dictionary = r["death"]
			md.append("- **death** on floor %d after %.0f s; near: %s; kit: %s" % [d["floor"], d["t"], str(d["near"]), d["kit"]])
			md.append("")
			md.append("Last seconds:")
			md.append("```")
			for l in d["timeline"]:
				md.append(l)
			md.append("```")
		if not (r["stuck"] as Dictionary).is_empty():
			md.append("- **stuck** on floor %d: %s" % [r["stuck"]["floor"], r["stuck"]["why"]])
		md.append("")
		md.append("| floor | time in | hp in→out (worst) | hits (by) | kills | seen | swings/shots/shoves | heals | notes |")
		md.append("|---|---|---|---|---|---|---|---|---|")
		for fr in floors_log:
			if int(fr["run"]) != int(r["run"]):
				continue
			md.append("| %d | %.0f s | %s→%s (%s) | %d %s | %s | %s | %d/%d/%d | %d | %s |" % [
				fr["floor"], float(fr["t_out"]) - float(fr["t_in"]), _hw(fr["hp_in"]), _hw(fr["hp_out"]), _hw(fr["hp_worst"]), fr["hits"], str(fr["hit_by"]).replace("{", "").replace("}", ""),
				str(fr["kills"]).replace("{", "").replace("}", ""), str(fr["seen"]).replace("{", "").replace("}", ""),
				fr["swings"], fr["shots"], fr["pushes"], fr["heals"], "; ".join(fr["notes"]) + ("; planned dead %d, on stairs %d" % [fr["planned_dead"], fr["stair_dead"]] if int(fr["planned_dead"]) >= 0 else "")])
		md.append("")
	md.append("## Upgrades and boons taken")
	md.append("")
	for u in upgrades_taken:
		md.append("- run %d, floor %d: **%s** (offered %s)" % [u["run"], u["floor"], u["name"], str(u["offered"])])
	for b in boons_taken:
		md.append("- run %d, floor %d: boon **%s** (offered %s)" % [b["run"], b["floor"], b["taken"], str(b["offered"])])
	if upgrades_taken.is_empty() and boons_taken.is_empty():
		md.append("- none (never reached a merchant floor with a merchant out)")
	md.append("")
	md.append_array(_scavenge_md())
	md.append("## Event log")
	md.append("")
	md.append("```")
	for e in events:
		md.append("%7.1f  run %d  %-8s %s" % [e["t"], e["run"], e["kind"], e["msg"]])
	md.append("```")
	var text := "\n".join(md) + "\n"
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(text)
			f.close()
			var jf := FileAccess.open(out_path.get_basename() + ".json", FileAccess.WRITE)
			if jf != null:
				jf.store_string(JSON.stringify({"seed": seed_value, "style": style, "loot_mode": loot_mode, "runs": runs, "floors": floors_log, "events": events, "upgrades": upgrades_taken, "boons": boons_taken,
					"loot": {"apartments": loot.apartments, "finds": loot.finds, "skips": loot.skips, "cov": loot.cov} if loot != null else {},
					"anomalies": anomalies, "watch": watch.summary() if watch != null else {}, "wall_s": snappedf(float(Time.get_ticks_msec() - wall_start_ms) / 1000.0, 0.1)}, "  "))
				jf.close()
	else:
		print(text)


## The scavenging, anomaly and coverage sections of the markdown report.
func _scavenge_md() -> Array:
	var md: Array = []
	md.append("## Scavenging (loot mode: %s)" % loot_mode)
	md.append("")
	if loot == null or loot_mode == "none":
		md.append("- the bot did not scavenge in this run")
		md.append("")
	else:
		for r in runs:
			var rn: int = int(r["run"])
			var flats := 0
			var maint := 0
			var nodes := 0
			var searched := 0
			var secs := 0.0
			var took: Dictionary = {}
			var left: Dictionary = {}
			var worst_hp := 0
			var zomb := 0
			for a in loot.apartments:
				if int(a["run"]) != rn:
					continue
				if a["kind"] == "maint":
					maint += 1
				else:
					flats += 1
				nodes += int(a["nodes"])
				searched += int(a["searched"])
				secs += float(a["t"])
				zomb += int(a["zombies"])
				worst_hp = maxi(worst_hp, int(a["hp_out"]))
				for k in a["took"]:
					took[k] = int(took.get(k, 0)) + int(a["took"][k])
				for k in a["left"]:
					left[k] = int(left.get(k, 0)) + int(a["left"][k])
			md.append("- **run %d**: %d apartments + %d maintenance rooms entered, %d nodes opened, %d items shown, %.0f s inside; zombies met inside %d; scrap at the end %s, notes %s" % [
				rn, flats, maint, nodes, searched, secs, zomb, str(r.get("scrap_end", "?")), str(r.get("notes_end", "?"))])
			md.append("  - taken: %s" % (_names(took) if not took.is_empty() else "nothing"))
			md.append("  - left behind: %s" % (_names(left) if not left.is_empty() else "nothing"))
		md.append("")
		md.append("Coverage counters: " + ", ".join(PackedStringArray((loot.cov.keys() as Array).map(func(k): return "%s=%s" % [k, str(loot.cov[k])]))))
		md.append("")
		if not loot.skips.is_empty():
			md.append("Doors passed over (%d): " % loot.skips.size() + "; ".join(PackedStringArray((loot.skips as Array).slice(0, 40).map(func(k): return "f%d %s (%s)" % [int(k["floor"]), str(k["apt"]), str(k["why"])]))))
			md.append("")
	md.append("## Anomalies (%d)" % anomalies.size())
	md.append("")
	if anomalies.is_empty():
		md.append("- none")
	for a in anomalies:
		md.append("- t=%.0f run %d floor %d **%s** — %s" % [a["t"], a["run"], a["floor"], a["kind"], a["msg"]])
	md.append("")
	if watch != null:
		md.append("Watcher: %d invariant sweeps; repeats: %s" % [watch.checks_run, str(watch.seen)])
		if not watch.engine_errors.is_empty():
			md.append("")
			md.append("Engine log (distinct errors / warnings):")
			for e in watch.engine_errors:
				md.append("- [%s/%s] x%d %s:%d %s (first at t=%.0f, run %d floor %d, %s)" % [e["kind"], e["owner"], int(e["count"]), e["file"], int(e["line"]), str(e["msg"]).left(160), float(e["first_t"]), int(e["run"]), int(e["floor"]), str(e["scene"]).get_file()])
		md.append("")
	return md


func _names(counts: Dictionary) -> String:
	var parts: Array = []
	for id in counts:
		var d: Dictionary = ItemData.get_item(str(id))
		parts.append("%s ×%d" % [d.get("name", id), int(counts[id])])
	return ", ".join(PackedStringArray(parts))


func _hw(i) -> String:
	return ["ok", "hurt", "injured", "wounded", "severe", "dying"][clampi(int(i), 0, 5)]
