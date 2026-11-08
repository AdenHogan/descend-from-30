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
# Hiding is a risk, not a wall: a dead thing that is SEARCHING (it reached a noise or a last-seen spot) within FIND_RANGE of the hidden
# player for FIND_TIME seconds finds them (`tick_finding`). Walking past never does.

## How the player is concealed (Player.conceal): "none" / "cover" (crouched behind furniture, phase 2) / "hidden" (inside a piece).
const NONE := "none"
const COVER := "cover"
const HIDDEN := "hidden"

const COVER_REVEAL := 24.0         # behind cover, a dead thing this close (horizontally) sees you anyway
const SEEN_RANGE := 260.0          # a dead thing in chase / attack within this is looking for you RIGHT NOW: you cannot hide from it
const FIND_RANGE := 70.0           # a searching dead thing this near the hiding place can find it...
const FIND_TIME := 2.5             # ...after this long (its search lasts EnemyMind.SEARCH_TIME 4 s)

# The grey screen (stealth_fx.gd) — kept here so the rule and the picture share their numbers. There is NO camera zoom any more (owner: "a really weird zoom").
const PLAYER_FEET_DROP := 33.0     # the player's origin is this far above their feet (a flat 320 -> 353, a corridor 386 -> 419)
const PHASE_RANGE := 56.0          # the dead that walk past a hidden player pass THROUGH the place they hide (the player's body must not wall them in)

const ENEMY_FULL := 120.0          # a dead thing this close to the hidden player is a full black silhouette...
const ENEMY_GONE := 340.0          # ...and is gone into the grey by here: you see it come, you do not see the room
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
	"hidden": {"sees": "blocked", "reach": false, "noise": "silent", "screen": "washed", "prompt": "{piece}  [{move_up}] Hide / Get in"},
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


## The dead that are looking for the player right now (chasing or striking, near enough to matter) — hiding is refused while any exist.
static func seen_by(player: Node) -> Array:
	var out: Array = []
	if player == null or not is_instance_valid(player):
		return out
	for z in player.get_tree().get_nodes_in_group("zombie"):
		if not AiMind.present(z):
			continue
		if str(z.get("state")) not in ["chase", "attack"]:
			continue
		if AiMind.gap(z, player) <= SEEN_RANGE:
			out.append(z)
	return out


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


## 0..1: how fully a dead thing at horizontal `gap` from the hidden player stays in colour on the washed-out screen (full inside ENEMY_FULL,
## nothing by ENEMY_GONE — it comes into the light as it nears and washes out again as it moves off).
static func focus_for_gap(gap: float) -> float:
	if gap >= ENEMY_GONE:
		return 0.0
	if gap <= ENEMY_FULL:
		return 1.0
	var u := (gap - ENEMY_FULL) / (ENEMY_GONE - ENEMY_FULL)
	return 1.0 - u * u * (3.0 - 2.0 * u)         # smoothstep down


## A dead thing that was locked on to the player with NO source (a follower that walked in after them, a stairwell muster: `alert_timer`, the 2000
## "it knows" case) cannot find a player it cannot see. It stops knowing: the lock-on ends, and it goes to where it last saw them (or, never having
## seen them, where it stands) and looks about — `EnemyMind.lose`. If that is within FIND_RANGE of the hiding place, the search finds them
## (`tick_finding`); if the player hid further off, it gives up and stands. Ending the lock-on matters: left running, it would charge across the
## flat the moment the player came out.
static func lose_track(e: Node2D) -> void:
	e.set("alert_timer", 0.0)
	e.set("_alert_positional", false)
	if not bool(e.get("_seen_valid")):
		e.set("_seen_x", e.global_position.x)
	EnemyMind.lose(e)


## The living dead within `radius` (horizontal) of the player, on their plane — what a footstep of that loudness would reach.
static func dead_within(player: Node, radius: float) -> Array:
	var out: Array = []
	if player == null or not is_instance_valid(player):
		return out
	for z in player.get_tree().get_nodes_in_group("zombie"):
		if AiMind.present(z) and AiMind.gap(z, player) <= radius:
			out.append(z)
	return out
