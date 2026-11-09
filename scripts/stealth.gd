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

## HIDING MUST MAKE SENSE (owner round 49o: "hiding beside a toilet is unnatural — it would make more sense to jump into the bathtub and hide in there"; "hiding must
## contextually make sense"). A place to hide is a PIECE a person would hide in, in the room it stands in — never a bare patch of wall. Each way of hiding states the only
## rooms it can happen in and the least a piece must measure (a person has to fit); `hide_rule_problems()` re-checks the table against the furniture library and
## the test proves it fails on a toilet, a sofa and a wardrobe in a kitchen.
const HOW := {
	"inside": {"rooms": ["bedroom"], "min_w": 34, "min_h": 60, "why": "a person fits in a wardrobe and pulls the door to"},
	"in": {"rooms": ["bathroom"], "min_w": 90, "min_h": 40, "why": "a person can climb into a bath and keep down below its rim"},
}

## Pieces you can hide in (planned rooms): piece id -> how, the noun and verb the prompt uses, the noise of getting out (px: a wardrobe's door, water slopping off a bath),
## and for a piece whose FRONT must stand between the player and the dead (the bath's lip) `lip_up`: how many sprite rows ABOVE the piece's feet line the front lip's top edge is,
## per drawn variant (read off the sprites: the roll-top's lip is 17-18 rows up, the shower-bath's 21-23) — the rows from there down are drawn over the player — and `stand_up`: how
## far above the piece's feet line the player's feet stand once they are in (a person sits down in the tub; the lip hides their shins). A bath with its curtain DRAWN across it
## (`curtain`: the wetroom's shower-bath) is hidden behind: the whole curtain is laid over the player, a shade less than opaque so a dark figure shows through the plastic, and it
## fades in as they step in (the player is sliced by it as they go behind). The pulled-back curtain of the pink bath hides nobody, so that tub hides by its lip. Not yet: under a bed (needs a lying figure
## and the dark gap drawn), behind a sofa or a table (that is COVER, phase 2), a walk-in shower (glass — you would be seen).
const HIDE_PIECES := {
	"wardrobe_wood": {"how": "inside", "noun": "wardrobe", "verb": "Hide", "noise": 40.0},
	"wardrobe_mirror": {"how": "inside", "noun": "wardrobe", "verb": "Hide", "noise": 40.0},
	"wardrobe_small": {"how": "inside", "noun": "wardrobe", "verb": "Hide", "noise": 40.0},
	"bath": {"how": "in", "noun": "bath", "verb": "Get in", "noise": 55.0, "stand_up": 6.0, "lip_default": 20,
		"lip_up": {"bath_claw": 18, "bath_gold": 17, "bath_panel": 21, "bath_curtain": 23, "bath_tiled": 22},
		"curtain": {"bath_curtain": {"alpha": 0.9, "noun": "shower", "verb": "Hide behind the curtain"}}},
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


## The living dead within `radius` (horizontal) of the player, on their plane — what a footstep of that loudness would reach.
static func dead_within(player: Node, radius: float) -> Array:
	var out: Array = []
	if player == null or not is_instance_valid(player):
		return out
	for z in player.get_tree().get_nodes_in_group("zombie"):
		if AiMind.present(z) and AiMind.gap(z, player) <= radius:
			out.append(z)
	return out
