class_name Stealth
extends RefCounted

# STEALTH SPACES (owner round 49o; docs/STEALTH_SPACES.md): what the dead can and cannot see, by where the player is.
#
# The dead see by a RADIUS (`distance <= detection`, enemy_zombie_standard / enemy_zombie_big). A concealed player is simply outside it:
# `sight_blocked(enemy, player)` is asked in the same place the radius is, and a blocked enemy gets a detection of -1 and a reach of INF,
# so it neither chases, nor strikes, nor is "seen" by a survivor-prey check — whatever the alert (a follower that walked in locked on to
# the player, `alert_timer`, is blinded too). What it does next is what it always does when it loses someone (`EnemyMind.lose`): go to
# where it last saw them, look about, give up.
#
# HIDING IS A RISK, NOT A WALL (owner round 49q: "if the player hides when an enemy is too close, they can be discovered. And I mean too close within attack distance and one
# length more. Outside of that, while enemies may track and move toward player when spotted, if player hides ... the enemy will shamble past. That could be good for player, but
# it could result in player now being stuck with enemies between them, and now having to rethink their plan"):
#   - you can hide from a dead thing that is chasing you, as long as it is not TOO CLOSE when you commit — inside its attack reach and one more length (`too_close`). Hide
#     inside that and it SEES you go in: a beat (`DISCOVER_DELAY`, and nothing brings you out in it), then it has found you and you are thrown out, and it is on you — no second chance;
#   - outside it, a chaser that loses you does not stop at the place it last saw you and stand over you — it carries on the way it was going, through the place you hide and out
#     the far side (`pass_by`, `PASS_BEYOND`), and only then looks about. The player is left with the dead on the other side of them;
#   - a dead thing that is SEARCHING (a noise took it there) within FIND_RANGE of the hiding place for FIND_TIME seconds finds them (`tick_finding`). Walking past never does.

## How the player is concealed (Player.conceal): "none" / "cover" (crouched behind furniture, phase 2) / "hidden" (inside a piece).
const NONE := "none"
const COVER := "cover"
const HIDDEN := "hidden"

const COVER_REVEAL := 24.0         # behind cover, a dead thing this close (horizontally) sees you anyway
const TOO_CLOSE_LENGTHS := 2.0     # hide with a dead thing within this many of ITS attack reaches (its reach, and one more length) and it sees you go in
const TOO_CLOSE_MAX := 160.0       # (a spitter's "reach" is a 300 px spit: the zone is capped so it stays a few steps)
const DISCOVER_DELAY := 0.35       # the beat between the dive and "it's found me" (long enough to hear the breath and see the dark come; no way out in it — the owner: "it's on the player")
const PASS_BEYOND := 240.0         # a chaser that loses you carries on this far past the place you hide before it looks about
const FIND_RANGE := 70.0           # a searching dead thing this near the hiding place can find it...
const FIND_TIME := 2.5             # ...after this long (its search lasts EnemyMind.SEARCH_TIME 4 s)

# The dark screen (stealth_fx.gd) — kept here so the rule and the picture share their numbers.
const PLAYER_FEET_DROP := 33.0     # the player's origin is this far above their feet (a flat 320 -> 353, a corridor 386 -> 419)
const PHASE_RANGE := 56.0          # the dead that walk past a hidden player pass THROUGH the place they hide (the player's body must not wall them in)

const ENEMY_FULL := 160.0          # a dead thing this close to the hidden player is "right there": the heart is at its quickest...
const ENEMY_GONE := 420.0          # ...and it is out of the heart's reach by here
const FADE_TIME := 0.6

# LIGHT (owner 2026-11-10: "hide in total dark spaces during the night run when lighting may be out on a floor… turning off the flashlight in those dark zones would be real
# dark"; docs/TORCH_AND_DARK.md). The dead see by a radius; how far that radius reaches follows the LIGHT ON THE PLAYER (LightSense: the room's ambient + every real light
# whose cookie covers them — never their own aura or torch beam, which is how they see, not what lights them):
#   - plainly lit (any morning, any afternoon, under a working lamp, by a fire, in a window's pool): x1.0 — exactly as before;
#   - in the dark, torch off: x DARK_SIGHT standing, x DARK_SIGHT_CROUCHED crouched — they have to come close to make you out;
#   - in the dark with a LIT TORCH: x TORCH_SIGHT — a light in the dark is seen from further than a person in daylight. Switching it off is how you disappear.
# Smooth between LightSense.DARK and LIT. An alerted "it knows" (the 2000 px lock-on) is not scaled. Hiding IN the dark is the DarkSpot's job (dark_spot.gd).
const DARK_SIGHT := 0.6
const DARK_SIGHT_CROUCHED := 0.45
const TORCH_SIGHT := 1.5
const LIGHT_SENSE_MSEC := 150      # the light on the player is read at most this often (every enemy asks every frame)


## The light on the player right now (LightSense.level_at, their own lights left out) — read fresh.
static func light_now(player: Node) -> float:
	if player == null or not is_instance_valid(player) or not (player is Node2D) or not player.is_inside_tree():
		return 1.0
	var root: Node = WorldState.owning_scene_root(player)
	if root == null:
		root = player.get_parent()
	return LightSense.level_at((player as Node2D).global_position, root, player)


## The same, remembered for LIGHT_SENSE_MSEC (what the dead's sight asks every frame).
static func light_on(player: Node) -> float:
	if player == null or not is_instance_valid(player):
		return 1.0
	var now: int = Time.get_ticks_msec()
	if player.has_meta("light_msec") and now - int(player.get_meta("light_msec")) < LIGHT_SENSE_MSEC:
		return float(player.get_meta("light_level", 1.0))
	var v: float = light_now(player)
	player.set_meta("light_msec", now)
	player.set_meta("light_level", v)
	return v


## Read the light afresh on the next ask (a torch just switched, a test that moved a lamp).
static func forget_light(player: Node) -> void:
	if player != null and is_instance_valid(player) and player.has_meta("light_msec"):
		player.remove_meta("light_msec")


static func torch_lit(player: Node) -> bool:
	return player != null and is_instance_valid(player) and player.has_method("torch_lit") and bool(player.torch_lit())


## Does the player stand in the dark with no light of their own showing?
static func in_the_dark(player: Node) -> bool:
	return light_on(player) <= LightSense.DARK and not torch_lit(player)


## What the dead's sight radius is multiplied by for this player, by the light on them (see LIGHT above). 1.0 whenever they are plainly lit.
static func sight_scale(player: Node) -> float:
	if player == null or not is_instance_valid(player):
		return 1.0
	return sight_scale_for(light_on(player), torch_lit(player), player.get("is_crouching") == true)


## The rule itself, as a pure function (tests pin it).
static func sight_scale_for(level: float, torch: bool, crouched: bool) -> float:
	var dark_share: float = 1.0 - LightSense.lit_share(level)
	if dark_share <= 0.0:
		return 1.0
	if torch:
		return lerpf(1.0, TORCH_SIGHT, dark_share)
	return lerpf(1.0, DARK_SIGHT_CROUCHED if crouched else DARK_SIGHT, dark_share)


## HIDING MUST MAKE SENSE (owner round 49o: "hiding beside a toilet is unnatural — it would make more sense to jump into the bathtub and hide in there"; "hiding must
## contextually make sense"; round 49t: "jumping behind a sofa, hiding behind or beside a chair, hiding up against a module wall for enemies to pass by, hiding behind a shower
## curtain or in a bathtub or in a wardrobe… when the furniture has physical real shape, we can specifically identify a place where a player can actively hide within or beside
## or behind"). A place to hide is a PIECE a person would hide in, behind or beside, in the room it stands in — or the wall beside a DOORWAY, where a person can flatten
## themselves behind the frame and be passed (`WALL_HIDE`, and only where that stretch of wall is bare: never "beside a toilet"). Each way of hiding states the only rooms it
## can happen in, the least a piece must measure (a person has to fit) and, for hiding BEHIND, that the piece stands out from the wall (there has to be a behind);
## `hide_rule_problems()` re-checks the table against the furniture library and the test proves it fails on a toilet, a wardrobe in a kitchen and a sofa "inside".
const HOW := {
	"inside": {"rooms": ["bedroom"], "min_w": 34, "min_h": 60, "why": "a person fits in a wardrobe and pulls the door to"},
	"in": {"rooms": ["bathroom"], "min_w": 90, "min_h": 40, "why": "a person can climb into a bath and keep down below its rim"},
	"behind": {"rooms": ["living_room", "bedroom", "study", "dining_room"], "min_w": 30, "min_h": 36, "planes": ["front"],
		"why": "a person crouched behind a sofa or an armchair that stands out from the wall is covered to the eyes"},
}

## THE WALL BESIDE A DOORWAY (owner round 49o: "if a player enters a module and immediately has a hide prompt to hide against the module wall, enemies can move past"; round 49t:
## "hiding up against a module wall for enemies to pass by", and on the first capture of it: "it should be more like a standing flat and straight up against the wall on
## either side, up from the main y plane so as to indicate the player has moved to a spot out of sight of enemies. Then the contextual left or right side based on where
## enemies might be coming from. This needs to not be an overwhelming prompt").
## Between the back wall and the door's opening every doorway has a stub of wall with the frame's jamb on it (module_walls.gd: the opening starts at floor depth 338). A person
## STANDING flat against that stub, stepped back off the walking line, is behind the frame for anything coming through the door. ONE place per doorway — between two rooms,
## and at the flat's front door — and WHICH SIDE of the wall they stand on is the game's choice, not a second prompt: the side AWAY from the nearest of the dead (one coming
## from the right-hand room finds nobody: they are flat against the left of the wall); with nobody about, the side they are already on. A side is only ever used if its corner
## is bare: `clear_from`..`clear_to` px from the wall, measured off the room's own furniture (a planned room's pieces, a baked room's clear-floor skyline), must hold nothing
## standing — never "beside a toilet". If the side that would hide them is not bare the doorway offers nothing (the other side is in plain view of what is coming).
## A solid end wall with no door has no such place: nothing passes it.
## NOT OVERWHELMING: the prompt is two words ("[E] Hide"), it shows only once they have all but stopped beside the doorway (`still`: a doorway is walked through all day)
## and only when hiding is on their mind — they are crouched, or one of the dead is up and within THREAT_RANGE.
## `offset` = where the player's middle is, from the wall (the whole standing figure on its own side of the frame, back to the wall, facing the room).
const WALL_HIDE := {"noun": "", "verb": "Hide", "noise": 0.0, "offset": 16.0, "reach": 30.0, "clear_from": 1, "clear_to": 29, "clear_rows": 62,
	"floor_y": 338.0, "still": 30.0, "shield": 1.0, "fire": true}
const THREAT_RANGE := 420.0        # one of the dead, up and this near, puts hiding on the player's mind: the quiet prompts (a doorway, the dark) show without a crouch

## Pieces you can hide in (planned rooms): piece id -> how, the noun and verb the prompt uses, the noise of getting out (px: a wardrobe's door, water slopping off a bath),
## and for a piece whose FRONT must stand between the player and the dead (the bath's lip) `lip_up`: how many sprite rows ABOVE the piece's feet line the front lip's top edge is,
## per drawn variant (read off the sprites: the roll-top's lip is 17-18 rows up, the shower-bath's 21-23) — the rows from there down are drawn over the player — and `stand_up`: how
## far above the piece's feet line the player's feet stand once they are in (a person sits down in the tub; the lip hides their shins). A bath with its curtain DRAWN across it
## (`curtain`: the wetroom's shower-bath) is hidden behind: the whole curtain is laid over the player, a shade less than opaque so a dark figure shows through the plastic, and it
## fades in as they step in (the player is sliced by it as they go behind). The pulled-back curtain of the pink bath hides nobody, so that tub hides by its lip. Not yet: under a bed (needs a lying figure
## and the dark gap drawn), behind a sofa or a table (that is COVER, phase 2), a walk-in shower (glass — you would be seen).
##
## BEHIND a piece (`how: "behind"`, round 49t): the player crouches on the wall side of a sofa / loveseat / armchair and the piece — with everything standing in front of it
## (the coffee table, what is on it) — is drawn over them, so the eyes and the top of the head show over its back. `feet_dy` = how far below the piece's own feet line the
## player's feet go (still behind its front edge), which is what sets how much head shows.
##
## COVER, for a fight that does not exist yet (owner round 49t: "hide beside a chair, it can be cover to avoid bullets from a neighbour who is shooting… and then the player
## if they have a gun can shoot from cover. I'm not saying we need it now, but if we have the tools ready"): every place states `shield` — the share of a shot the thing
## would stop (cast iron stops nearly all, a wardrobe door very little, a curtain nothing, a wall everything) — and `fire`, whether a person could shoot back from there
## (over a sofa's back, round a door frame: yes; from inside a wardrobe or behind a curtain: no). `Stealth.cover_info(player)` reads them. NOTHING consumes it yet.
const HIDE_PIECES := {
	"wardrobe_wood": {"how": "inside", "noun": "wardrobe", "verb": "Hide", "noise": 40.0, "shield": 0.25, "fire": false},
	"wardrobe_mirror": {"how": "inside", "noun": "wardrobe", "verb": "Hide", "noise": 40.0, "shield": 0.25, "fire": false},
	"wardrobe_small": {"how": "inside", "noun": "wardrobe", "verb": "Hide", "noise": 40.0, "shield": 0.25, "fire": false},
	"bath": {"how": "in", "noun": "bath", "verb": "Get in", "noise": 55.0, "stand_up": 6.0, "lip_default": 20, "shield": 0.9, "fire": true,
		"lip_up": {"bath_claw": 18, "bath_gold": 17, "bath_panel": 21, "bath_curtain": 23, "bath_tiled": 22},
		"curtain": {"bath_curtain": {"alpha": 0.9, "noun": "shower", "verb": "Hide behind the curtain", "shield": 0.0, "fire": false}}},
	"sofa": {"how": "behind", "noun": "sofa", "verb": "Hide behind it", "noise": 30.0, "feet_dy": 0.0, "shield": 0.6, "fire": true},
	"loveseat": {"how": "behind", "noun": "sofa", "verb": "Hide behind it", "noise": 30.0, "feet_dy": 0.0, "shield": 0.6, "fire": true},
	"armchair": {"how": "behind", "noun": "armchair", "verb": "Hide behind it", "noise": 30.0, "feet_dy": 0.0, "shield": 0.5, "fire": true},
}


## The table checked against the furniture library: every problem as a sentence (empty = it makes sense). `table` / `library` are parameters so a test can hand it a bad one.
static func hide_rule_problems(table: Dictionary = HIDE_PIECES, library: Dictionary = {}) -> Array:
	var lib: Dictionary = library if not library.is_empty() else FurniturePlanner.data().get("items", {})
	var out: Array = []
	for id in table:
		var def: Dictionary = table[id]
		var how := String(def.get("how", ""))
		if not HOW.has(how):
			out.append("%s: '%s' is not a way of hiding" % [id, how])
			continue
		if not lib.has(id):
			out.append("%s: not a piece in the furniture library" % id)
			continue
		var rec: Dictionary = lib[id]
		var rule: Dictionary = HOW[how]
		for room in rec.get("rooms", {}):
			if not (String(room) in rule["rooms"]):
				out.append("%s: stands in a %s, but you can only hide %s in a %s (%s)" % [id, room, how, " or ".join(rule["rooms"]), rule["why"]])
		if rule.has("planes") and not (String(rec.get("plane", "")) in rule["planes"]):
			out.append("%s: stands on the %s plane — there is no %s it (%s)" % [id, String(rec.get("plane", "?")), how, rule["why"]])
		if float(def.get("shield", -1.0)) < 0.0 or float(def.get("shield", -1.0)) > 1.0 or not def.has("fire"):
			out.append("%s: no cover numbers (shield 0..1, fire yes / no)" % id)
		if int(rec.get("w", 0)) < int(rule["min_w"]) or int(rec.get("h", 0)) < int(rule["min_h"]):
			out.append("%s: %dx%d is too small to hide %s (needs %dx%d)" % [id, int(rec.get("w", 0)), int(rec.get("h", 0)), how, int(rule["min_w"]), int(rule["min_h"])])
		if float(def.get("noise", -1.0)) < 0.0 or String(def.get("noun", "")) == "" or String(def.get("verb", "")) == "":
			out.append("%s: no noun / verb / noise given" % id)
	return out


## The plane context table (docs/STEALTH_SPACES.md §2): every plane answers the same questions, in one place, so a new plane cannot forget one.
## sees: who can see you there — "radius" = the dead's normal sight, "blocked" = the piece blocks it. noise: "gait" or "silent".
const PLANES := {
	"lane": {"sees": "radius", "reach": true, "noise": "gait", "screen": "normal", "prompt": "doors, lifts, bodies"},
	"back": {"sees": "radius", "reach": true, "noise": "gait", "screen": "normal", "prompt": "tutorial arrow only"},
	"balcony": {"sees": "radius", "reach": true, "noise": "gait", "screen": "normal", "prompt": "standing pill"},
	"cover": {"sees": "blocked", "reach": true, "noise": "gait", "screen": "normal", "prompt": "Duck behind the {piece}  [{move_up}]"},
	"hidden": {"sees": "blocked", "reach": false, "noise": "silent", "screen": "dark", "prompt": "{piece}  [{interact}] Hide / Come out"},
}
# (Round 49t: "behind a sofa" was designed as the COVER plane above — crouch-walk behind it, seen only from close. It was built instead as a HIDDEN place like the wardrobe:
# one press, the same rules. The cover row stays for the creeping version, still not built; darkness is a HIDDEN place too — dark_spot.gd.)


## What the player is behind / in right now, as COVER (see HIDE_PIECES): {"shield": 0..1, "fire": bool, "piece": id} — {"shield": 0, "fire": true, "piece": ""} in the open.
## A tool for a fight that is not built: nothing reads it yet.
static func cover_info(player: Node) -> Dictionary:
	var open := {"shield": 0.0, "fire": true, "piece": ""}
	if player == null or not is_instance_valid(player):
		return open
	var spot = player.get("hide_spot")
	if spot == null or not is_instance_valid(spot):
		return open
	return {"shield": clampf(float(spot.get("shield")) if spot.get("shield") != null else 0.0, 0.0, 1.0),
		"fire": spot.get("fire_from") == true, "piece": String(spot.get("piece_id")) if spot.get("piece_id") != null else ""}


## Would a shot at the player be stopped by what they are behind? `roll` is the caller's own 0..1 draw (seeded by them): under the shield, it is stopped.
static func shot_stopped(player: Node, roll: float) -> bool:
	return roll < float(cover_info(player)["shield"])


static func conceal_of(player: Node) -> String:
	if player == null or not is_instance_valid(player):
		return NONE
	var c = player.get("conceal")
	return str(c) if c != null else NONE


## Can this enemy NOT see the player right now? (The detection radius is the other half of sight; this removes it.)
static func sight_blocked(enemy: Node, player: Node) -> bool:
	match conceal_of(player):
		HIDDEN:
			return true
		COVER:
			var g := AiMind.gap(enemy, player)
			return g > COVER_REVEAL
	return false


## The dead too close for the player to hide from: awake (not knocked down, not lying as a body, not on the stairs), within TOO_CLOSE_LENGTHS of their own attack reach — capped at TOO_CLOSE_MAX —
## horizontally, on the player's plane. Asked once, at the moment they commit to a hiding place.
static func too_close(player: Node) -> Array:
	var out: Array = []
	if player == null or not is_instance_valid(player):
		return out
	for z in player.get_tree().get_nodes_in_group("zombie"):
		if not AiMind.present(z) or not EnemyMind.can_think(z):
			continue
		if str(z.get("state")) in ["knockdown", "dead"]:
			continue
		if AiMind.gap(z, player) <= zone_of(z):
			out.append(z)
	return out


## How near is "too close" for this dead thing: its attack reach and one more (TOO_CLOSE_LENGTHS), never more than TOO_CLOSE_MAX.
static func zone_of(z: Node) -> float:
	var reach: float = float(z.call("_attack_reach")) if z.has_method("_attack_reach") else 40.0
	return minf(reach * TOO_CLOSE_LENGTHS, TOO_CLOSE_MAX)


## Run every frame on an enemy that can think. A dead thing SEARCHING within FIND_RANGE of a hidden player for FIND_TIME finds them.
## Returns true on the frame it finds them (the player has been thrown out of the hiding place).
static func tick_finding(enemy: Node2D, player: Node, delta: float) -> bool:
	var t: float = float(enemy.get_meta("stealth_find_t", 0.0))
	if conceal_of(player) != HIDDEN:
		if t != 0.0:
			enemy.set_meta("stealth_find_t", 0.0)
		return false
	var looking: bool = str(enemy.get("mind")) == "search" and AiMind.gap(enemy, player) <= FIND_RANGE
	t = t + delta if looking else maxf(0.0, t - delta)
	if t >= FIND_TIME:
		enemy.set_meta("stealth_find_t", 0.0)
		if player.has_method("found_hiding"):
			player.found_hiding(enemy)
		return true
	enemy.set_meta("stealth_find_t", t)
	return false


## 0..1: how fully a dead thing at horizontal `gap` from the hidden player shows on the dark screen (full inside ENEMY_FULL, nothing by ENEMY_GONE — it comes out of the dark as it
## nears and goes back into it as it moves off).
static func focus_for_gap(gap: float) -> float:
	if gap >= ENEMY_GONE:
		return 0.0
	if gap <= ENEMY_FULL:
		return 1.0
	var u := (gap - ENEMY_FULL) / (ENEMY_GONE - ENEMY_FULL)
	return 1.0 - u * u * (3.0 - 2.0 * u)         # smoothstep down


## A dead thing that was locked on to the player with NO source (a follower that walked in after them, a stairwell muster: `alert_timer`, the 2000
## "it knows" case) cannot find a player it cannot see. It stops knowing: the lock-on ends, and it carries on past the hiding place the way it was going
## (`pass_by`) and looks about on the far side. Ending the lock-on matters: left running, it would charge across the flat the moment the player came out.
static func lose_track(e: Node2D, player: Node = null) -> void:
	e.set("alert_timer", 0.0)
	e.set("_alert_positional", false)
	if player != null and is_instance_valid(player) and conceal_of(player) == HIDDEN:
		pass_by(e, player)
		return
	if not bool(e.get("_seen_valid")):
		e.set("_seen_x", e.global_position.x)
	EnemyMind.lose(e)


## A chaser has lost a player who has hidden: it does NOT go and stand where it last saw them (that is the hiding place — it would stand over them and find them). It carries
## on the way it was going, through the place they hide (the player's body lets it pass: `Player._hide_phase`) and PASS_BEYOND px out the far side, and only there looks about.
## The player is left with the dead on the other side of them.
static func pass_by(e: Node2D, player: Node) -> void:
	if not EnemyMind.can_think(e) or player == null or not is_instance_valid(player):
		return
	var px: float = player.global_position.x
	var dir: float = signf(px - e.global_position.x)
	if dir == 0.0:
		var spr = e.get("animated_sprite")
		dir = -1.0 if (spr != null and spr.flip_h) else 1.0
	EnemyMind.investigate(e, px + dir * PASS_BEYOND)
	EnemyMind.tell(e, "search")


## The dead that are UP (not lying as a body, not knocked down, able to think) in the player's own world — the ones a hiding place is about.
static func threats(player: Node) -> Array:
	var out: Array = []
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return out
	for z in player.get_tree().get_nodes_in_group("zombie"):
		if not AiMind.present(z) or not EnemyMind.can_think(z) or not AiMind.same_world(z, player):
			continue
		if str(z.get("state")) in ["knockdown", "dead"]:
			continue
		out.append(z)
	return out


## Is one of them within THREAT_RANGE of the player?
static func threat_near(player: Node) -> bool:
	if not (player is Node2D):
		return false
	for z in threats(player):
		if absf((z as Node2D).global_position.x - (player as Node2D).global_position.x) <= THREAT_RANGE:
			return true
	return false


## Is hiding on the player's mind? Crouched, or one of the dead up and near. The quiet hiding places (a doorway's wall, the dark) only show their prompt then.
static func wants_hiding(player: Node) -> bool:
	return player != null and is_instance_valid(player) and (player.get("is_crouching") == true or threat_near(player))


## The living dead within `radius` (horizontal) of the player, on their plane — what a footstep of that loudness would reach.
static func dead_within(player: Node, radius: float) -> Array:
	var out: Array = []
	if player == null or not is_instance_valid(player):
		return out
	for z in player.get_tree().get_nodes_in_group("zombie"):
		if AiMind.present(z) and AiMind.gap(z, player) <= radius:
			out.append(z)
	return out
