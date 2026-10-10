class_name EnemyMind
extends RefCounted

# THE DEAD THINK A LITTLE (owner: "our enemies will also need to start having better intelligence too").
# docs/NPC_AI.md has the pattern table; in one breath:
#
#   HEAR   a noise tells a zombie WHERE, not where you are now. It walks to the noise's SOURCE (investigate), and on
#          arrival LOOKS about for a few seconds (search, "?"); it chases only what it actually sees. (The old
#          behaviour — any noise made it know your exact position across the whole floor — is kept only for the
#          callers that mean it: the dead mustered at a stairwell you pried open, a pull from the floor above.)
#   LOSE   when you slip out of its sight it does not forget you the same frame: it goes to where it LAST SAW you,
#          searches there, then gives up and stands.
#   SPOT   the moment it commits to a chase it marks "!" and the dead standing close by turn toward the commotion.
#   PREY   it goes for the nearer meal: a survivor standing closer than you is bitten first. (Spitters ignore this —
#          they only shoot at you.)
#
# Shared by the standard family and the big zombie as static helpers over the enemy's own fields: mind, mind_x,
# mind_t, prey, _seen_x, _seen_valid, _look_t, _spread_cd, ai_tell, plus state / velocity / animated_sprite / player.

const SEARCH_TIME := 4.0            # how long it looks about after arriving
const LOOK_EVERY := 1.1             # it turns its head this often while searching
const ARRIVE := 18.0                # close enough to the noise / last-seen spot
const SPREAD_RANGE := 170.0         # the dead this near a lunge turn toward it
const SPREAD_COOLDOWN := 4.0
const SIGHT_STICKY := 30.0          # a current prey stays prey unless something is this much nearer
const NO_MIND_STATES := ["hit", "recovering", "knockdown", "attack", "distracted", "dead"]


static func tell(e: Node, kind: String, hold: float = 1.1) -> void:
	var t = e.get("ai_tell")
	if t != null and is_instance_valid(t):
		t.show_mark(kind, hold)


## True when this enemy can think at all right now (not scripted, not on the stairs, not a riser lying there).
static func can_think(e: Node) -> bool:
	if e.get("is_dead") == true or e.get("tutorial_scripted") == true or e.get("stair_mode") == true:
		return false
	var ph = e.get("riser_phase")
	if ph != null and str(ph) != "":
		return false
	return true


## A noise was made at `source`. Walk to it — unless I am already on the player or a survivor.
static func hear(e: Node2D, source_x: float) -> void:
	if not can_think(e) or e.get("is_distracted") == true:
		return
	if str(e.get("state")) in ["hit", "recovering", "knockdown", "attack"]:
		return
	var pr = e.get("prey")
	if pr != null and is_instance_valid(pr) and str(e.get("state")) == "chase":
		return                                  # already on someone; a noise doesn't pull it off them
	if str(e.get("mind")) != "investigate":
		tell(e, "search")
	e.set("mind", "investigate")
	e.set("mind_x", source_x)
	e.set("_seen_valid", false)


## It was on me and has lost me: go to where I was last seen.
static func lose(e: Node2D) -> void:
	if not can_think(e):
		return
	e.set("mind", "investigate")
	e.set("mind_x", float(e.get("_seen_x")))
	e.set("_seen_valid", false)
	tell(e, "search")


## Runs the investigate / search patterns on a frame the enemy has nothing to chase. Returns true if it owned the
## frame (it set velocity + animation); false = carry on idling.
static func idle_tick(e, delta: float, speed: float) -> bool:
	var mind: String = str(e.get("mind"))
	if mind == "" or not can_think(e):
		return false
	var spr: AnimatedSprite2D = e.get("animated_sprite")
	match mind:
		"investigate":
			var d: float = float(e.get("mind_x")) - e.global_position.x
			if absf(d) <= ARRIVE:
				e.set("mind", "search")
				e.set("mind_t", SEARCH_TIME)
				e.set("_look_t", LOOK_EVERY)
				e.set("velocity", Vector2(0.0, e.velocity.y))
				spr.play("Idle")
				tell(e, "search", SEARCH_TIME)
				return true
			e.state = "idle"                    # (never "chase": that word means "on the player")
			e.velocity.x = signf(d) * speed
			spr.flip_h = d < 0.0
			spr.play("Walk")
			return true
		"search":
			e.state = "idle"
			e.velocity.x = 0.0
			spr.play("Idle")
			var t: float = float(e.get("mind_t")) - delta
			e.set("mind_t", t)
			var lk: float = float(e.get("_look_t")) - delta
			if lk <= 0.0:
				lk = LOOK_EVERY
				spr.flip_h = not spr.flip_h      # turns its head: the "searching" pattern
			e.set("_look_t", lk)
			if t <= 0.0:
				e.set("mind", "")
				e.set("_seen_valid", false)
				return false
			return true
	return false


## The enemy has just committed to a chase from standing: mark "!" and rouse the dead standing close.
static func spotted(e: Node2D, who: Node2D) -> void:
	e.set("mind", "")
	e.set("_seen_valid", true)
	tell(e, "alert", 0.9)
	if float(e.get("_spread_cd")) > 0.0:
		return
	e.set("_spread_cd", SPREAD_COOLDOWN)
	for z in e.get_tree().get_nodes_in_group("zombie"):
		if z == e or not (z is Node2D) or not can_think(z):
			continue
		if str(z.get("state")) != "idle" or str(z.get("mind")) != "":
			continue
		if AiMind.gap(e, z) <= SPREAD_RANGE:
			hear(z, who.global_position.x)


## The nearer meal: a survivor in sight and nearer than the player (or the player out of sight). null = go for the
## player as usual. `sight` is the enemy's own detection range (NOT the 2000 of a legacy alert); `player_reach` is
## its reach_to_player (INF when off the plane).
static func pick_prey(e: Node2D, sight: float, player_reach: float, player_in_sight: bool) -> Node2D:
	if not can_think(e) or (e.has_method("allows_survivor_prey") and not e.allows_survivor_prey()):
		return null
	var current = e.get("prey")
	var best: Node2D = null
	var best_gap := INF
	for s in e.get_tree().get_nodes_in_group("survivor_prey"):
		var g := AiMind.gap(e, s)
		if g > sight:
			continue
		var bias: float = SIGHT_STICKY if s == current else 0.0
		if player_in_sight and g >= player_reach + bias:
			continue
		if g - bias < best_gap:
			best_gap = g - bias
			best = s
	return best


## Close on / strike a survivor. `windup` = this type's attack wind-up (the standard 0.8 s, the big 1.2 s).
static func tick_ally(e, ally: Node2D, speed: float, windup: float) -> void:
	var spr: AnimatedSprite2D = e.get("animated_sprite")
	e.set("prey", ally)
	e.set("mind", "")
	var dir := signf(ally.global_position.x - e.global_position.x)
	spr.flip_h = dir < 0.0
	if AiMind.gap(e, ally) <= e._attack_reach():
		e.state = "attack"
		e.state_timer = windup
		e.velocity.x = 0.0
		spr.play("Attack")
	else:
		e.state = "chase"
		e.velocity.x = dir * speed
		spr.play("Walk")


## The moment a bite on a survivor lands (the attack wind-up ended).
static func deliver_ally_attack(e, damage: int) -> void:
	var a = e.get("prey")
	if a == null or not is_instance_valid(a) or not a.has_method("receive_damage"):
		return
	if AiMind.gap(e, a) <= e._attack_reach() + 10.0:
		a.receive_damage(damage, "bite")


## True while the enemy's current prey is a survivor (not the player).
static func prey_is_ally(e: Node) -> bool:
	var a = e.get("prey")
	return a != null and is_instance_valid(a) and not a.is_in_group("player")
