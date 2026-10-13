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
var trace: bool = false                 # print the bot's state every 2 s (debugging the bot)
var _trace_t: float = 0.0
var _raw_floor: int = -1
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
		elif a == "--trace":
			trace = true
	process_mode = Node.PROCESS_MODE_ALWAYS     # the cold open pauses the tree: the bot must keep ticking to press through it
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
	WorldState.god_mode = false
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
	_swing_gate = maxf(0.0, _swing_gate - delta)
	_push_gate = maxf(0.0, _push_gate - delta)
	_heal_gate = maxf(0.0, _heal_gate - delta)
	_stairs_gate = maxf(0.0, _stairs_gate - delta)
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
			print("    [heartbeat t=%.0f] phase=%s scene=%s transition_busy=%s paused=%s player=%s dead=%s run=%d" % [t, phase, str(sc.scene_file_path) if sc != null else "none", str(Transition.busy), str(get_tree().paused), str(_player() != null), str(_player().is_dead) if _player() != null else "-", WorldState.current_run])
	var scene = get_tree().current_scene
	if scene != null and scene.scene_file_path.ends_with("game_over.tscn"):
		# the arc is over (the third character walked out, or fell): the game has swapped to its end card
		if run_rec.get("outcome", "") == "":
			_finish_run("escaped" if phase == "leaving" else "dead", "the playthrough ended")
		_finish_all()
		return
	var p = _player()
	if p == null:
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
	if t - float(run_rec["t_start"]) > MAX_RUN_TIME:
		_finish_run("timeout", "ran out of the %.0f-minute allowance" % (MAX_RUN_TIME / 60.0))
		return
	if trace and WorldState.current_floor != _raw_floor:
		print("    [trace t=%.1f] WorldState.current_floor %d -> %d (busy: transition %s pan %s cutscene %s)" % [t, _raw_floor, WorldState.current_floor, str(Transition.busy), str(StairPan.panning), str(p.is_cutscene)])
		_raw_floor = WorldState.current_floor
	var busy: bool = p.is_cutscene or p.escaping or p.is_lashing or Transition.busy or StairPan.panning or get_tree().paused
	var f: int = WorldState.current_floor
	if f != _last_floor and not StairPan.panning and not Transition.busy:
		# logged BEFORE the busy gate, so a floor passed through mid-transition still appears in the record
		_on_floor_change(f, p)
	_observe(p)
	if busy:
		_release_all()
		return
	if p.is_switching_mode or p.pack_phase != "" or p.is_listening or WorldState.loot_open:
		_release_all()
		return
	if trace:
		_trace_t += delta
		if _trace_t >= 2.0:
			_trace_t = 0.0
			var st = _down_stairs()
			print("    [trace t=%.1f] f%d x=%.0f vx=%.0f dir_keys=%s move_target=%s(%.0f) mode=%s sel=%d atk=%s stam=%.0f stairs_x=%s zs=%s" % [t, f, p.global_position.x, p.velocity.x, str(_kb), str(p.has_move_target), p.move_target_x, "scav" if WorldState.is_scavenge_mode else "combat", HUD.selected_slot, str(p.is_attacking), WorldState.stamina, str(_goal_x(st)) if st != null else "none", str(_zombies(p, SIGHT).map(func(z): return "%s@%d,y%d:%s%s hp%s" % [_type_of(z), int(z.global_position.x), int(z.global_position.y), str(z.get("state")), (" STAIR:" + str(z.get("_stair_phase"))) if z.get("stair_mode") == true else "", str(z.get("hp"))]))])
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
	# a barricaded stairwell: hand over the crowbar (logged), and make sure nothing is on the bot while it heaves
	if st != null and WorldState.is_stair_blocked(_choke(st)) and give_crowbar and not WorldState.has_crowbar():
		var cb := ItemInstance.new()
		cb.setup("035")
		WorldState.inventory.append(cb)                # outside the five slots on purpose: the kit stays as given
		floor_rec["pried"] = true
		floor_rec["notes"].append("crowbar handed over for the barricade")
		_event("CROWBAR", "floor %d: barricaded stairwell — a crowbar was handed to the bot (it has no way to scavenge one)" % f)
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
	if threat != null:
		_fight(p, threat, zs)
		_stuck_watch(p, true)
		return
	_kite_until = 0.0
	_advance(p, st, zs)
	_stuck_watch(p, false)


## Who is worth fighting right now: anything chasing/attacking within reach distance, then the nearest thing in the way ahead.
func _pick_threat(p, zs: Array, st):
	if zs.is_empty():
		return null
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
	var dirx: float = signf(dx) if absf(dx) > 6.0 else (1.0 if facing_right else -1.0)
	var edge := _edge(p, z)
	var stam: float = WorldState.stamina
	var max_stam: float = WorldState.get_max_stamina()
	var winded: bool = stam < max_stam * 0.25 + 1.0 or stam < SWING_COST
	var ty := _type_of(z)
	_sprint(false)
	# the gun: for the ones that are worst to meet with a hammer, while it has rounds and they are not in our face
	var gun_slot := _slot_of_gun()
	var gun_ok: bool = (ty in ["big", "spitter"]) or (z.get("is_corridor_boss") == true) or not _armed()
	var cornered_winded: bool = winded and edge < 130.0 and not _room_behind(p, dirx)
	if gun_slot >= 0 and ((gun_ok and edge > GUN_MIN_RANGE) or (winded and edge < 160.0) or cornered_winded) and edge < 240.0:
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
		Input.action_press("push")
		_kb["push"] = true
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
	if edge > REACH * 0.85:
		var coming: bool = _on_me(p, z)
		_hold_t = _hold_t + get_physics_process_delta_time() if (coming and edge < REACH + 60.0) else 0.0
		if coming and edge < REACH + 60.0 and _hold_t < 1.2:
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
		Input.action_press("push")
		_kb["push"] = true
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
	if WorldState.is_scavenge_mode and not p.is_switching_mode:
		p.request_mode_toggle()


func _try_heal(p, zs: Array) -> bool:
	if _heal_gate > 0.0:
		return false
	var hs: int = WorldState.player_health
	if hs < 3:
		return false
	var slot := _slot_of_kit()
	if slot < 0:
		return false
	var close := 0
	for z in zs:
		if _edge(p, z) < 60.0:
			close += 1
	if hs < 5 and close > 0:
		return false                     # fight first unless it's dire
	_heal_gate = 1.0
	_release_all()
	p.use_item(slot)
	floor_rec["heals"] = int(floor_rec["heals"]) + 1
	run_rec["heals"] = int(run_rec["heals"]) + 1
	_event("HEAL", "floor %d: first aid at %s" % [WorldState.current_floor, WorldState.HEALTH_WORDS[clampi(hs, 0, 5)]])
	return true


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
	run_rec["death"] = {
		"floor": WorldState.current_floor, "t": t - float(run_rec["t_start"]), "near": near, "timeline": _timeline.duplicate(),
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
	_write_report()
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
		return "fire/ranged/other"
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


# slots ---------------------------------------------------------------------------------------------------

func _slot_of_gun() -> int:
	for i in WorldState.inventory.size():
		var inst = WorldState.inventory[i]
		if inst.item_id == "004" and inst.mag_count > 0 and not inst.is_depleted:
			return i
	return -1


func _best_hammer_slot() -> int:
	for i in WorldState.inventory.size():
		var inst = WorldState.inventory[i]
		if inst.item_id == "002" and not inst.is_depleted:
			return i
	return -1


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
	if kind in ["RUN", "LOBBY", "DEATH", "STUCK", "UPGRADE", "BOON", "CROWBAR", "EXIT", "KIT"]:
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
				jf.store_string(JSON.stringify({"seed": seed_value, "style": style, "runs": runs, "floors": floors_log, "events": events, "upgrades": upgrades_taken, "boons": boons_taken}, "  "))
				jf.close()
	else:
		print(text)


func _hw(i) -> String:
	return ["ok", "hurt", "injured", "wounded", "severe", "dying"][clampi(int(i), 0, 5)]
