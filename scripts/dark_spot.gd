class_name DarkSpot
extends Node2D

## DARKNESS IS A HIDING PLACE (owner 2026-11-10: "hiding [in This War of Mine] is reserved for shadowy alcoves mainly, so it's somewhat underutilised. We need something more
## robust, like also being able to hide in total dark spaces during the night run when lighting may be out on a floor"; docs/TORCH_AND_DARK.md).
##
## Every player carries one of these. Wherever the light on them is at or under `LightSense.DARK` — a night corridor between dead sconces, the far end of a flat with no power —
## and their torch is off, the dark itself is a place to hide: the same ONE [interact] press, the same prompt over the head, and from then on every rule of a hiding place
## (`Player.enter_hide`, docs/STEALTH_SPACES.md §4): a dead thing too close when they commit has them, a chaser further off shambles past, a searcher that lingers finds them, a
## hit throws them out, one more press brings them out. It is not a piece of furniture, so it has its own two rules:
##   - it is only OFFERED while hiding is on their mind — crouched, or one of the dead up and near (Stealth.wants_hiding: a night corridor is dark from end to end, and a
##     prompt that never left would be noise);
##   - LIGHT ENDS IT. A lamp that stutters back on, a fire, a blast-lit window: `BREAK_LEVEL` of light on them for `BREAK_TIME` and the dark is gone — out they come.
## It answers [interact] LAST: a door, a body, a drop, a wardrobe — anything else that would answer the press — is nearer by the arbiter's rule.

const BREAK_LEVEL := 0.30      # this much light on a player hidden in the dark...
const BREAK_TIME := 0.35       # ...for this long (a lightning flash is shorter) and they are lit: the hiding is over
const SENSE_EVERY := 0.1       # how often the light is read while hidden
const FAR := 100000.0          # where it says it is for the arbiter: further than anything else that could answer

var piece_id: String = "darkness"
var noun: String = "darkness"
var verb: String = "Hide"
var how: String = "dark"
var _prompt_on: bool = false
var _lit_t: float = 0.0
var _sense_t: float = 0.0


## The player's own dark spot (made once, a child of the player so it is always where they are and always in their world).
static func ensure(player: Node2D) -> DarkSpot:
	if player == null or not is_instance_valid(player):
		return null
	var have := player.get_node_or_null("DarkSpot") as DarkSpot
	if have != null:
		return have
	var s := DarkSpot.new()
	s.name = "DarkSpot"
	player.add_child(s)
	return s


func _ready() -> void:
	add_to_group("dark_spot")
	add_to_group(InteractArbiter.GROUP)
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _exit_tree() -> void:
	_set_prompt("")


func _player() -> Node2D:
	return get_parent() as Node2D


## Coming out of the dark makes no noise of its own (a wardrobe has a door; the dark has nothing).
func exit_noise() -> float:
	return 0.0


func label() -> String:
	return "Darkness"


## Is a real hiding place (a wardrobe, a sofa, a doorway) offering itself to the player right now? It wins: the dark is everywhere, a piece is here.
func piece_offers(_p: Node2D) -> bool:
	for s in get_tree().get_nodes_in_group("stealth_spot"):
		if is_instance_valid(s) and s.has_method("interact_ready") and s.interact_ready():
			return true
	return false


## Could the player hide in the dark right here, right now?
func offered_to(p: Node) -> bool:
	if p == null or not is_instance_valid(p) or not (p is Node2D):
		return false
	if p.get("is_dead") == true or p.get("is_dying") == true or p.get("is_cutscene") == true or p.get("escaping") == true:
		return false
	if p.get("back_spot") != null or p.get("on_balcony_plane") == true or p.get("is_lashing") == true or p.get("is_listening") == true:
		return false
	if str(p.get("pack_phase")) != "" and p.get("pack_phase") != null:
		return false
	if not Stealth.in_the_dark(p):
		return false
	return Stealth.wants_hiding(p)          # crouched, or one of the dead up and near (Stealth.THREAT_RANGE): the dark is everywhere at night — it must not nag


## An [interact] member (InteractArbiter): the dark answers only when nothing else would.
func interact_ready() -> bool:
	var p := _player()
	if p == null or not is_instance_valid(p) or p.get("hide_spot") != null or Stealth.conceal_of(p) != Stealth.NONE:
		return false
	return offered_to(p) and not WorldState.loot_open


func interact_x() -> float:
	var p := _player()
	return (p.global_position.x if p != null else 0.0) + FAR


func interact_rank() -> int:
	return InteractArbiter.RANK_THING


func _process(delta: float) -> void:
	var p := _player()
	if p == null or not is_instance_valid(p):
		_set_prompt("")
		return
	if p.get("hide_spot") == self:
		_set_prompt("[{interact}] Come out", _over_head(p))
		_sense_t += delta
		if _sense_t >= SENSE_EVERY:
			_watch_the_light(p, _sense_t)
			_sense_t = 0.0
		return
	_lit_t = 0.0
	_sense_t = 0.0
	if p.get("hide_spot") != null or not interact_ready() or piece_offers(p):
		_set_prompt("")
		return
	_set_prompt("Darkness   [{interact}] Hide", _over_head(p))
	if Input.is_action_just_pressed("interact") and InteractArbiter.take(self) and p.has_method("enter_hide"):
		p.enter_hide(self)


## Hidden in the dark: if light stays on the player (a lamp back on, a fire, a torch that is not theirs) the dark is gone and so is the hiding place.
func _watch_the_light(p: Node2D, dt: float) -> void:
	if Stealth.light_now(p) >= BREAK_LEVEL:
		_lit_t += dt
		if _lit_t >= BREAK_TIME:
			_lit_t = 0.0
			if p.has_method("leave_hide"):
				p.leave_hide()
			HUD.show_feedback("The light's on me.", true)
	else:
		_lit_t = 0.0


func _over_head(p: Node2D) -> Vector2:
	return p.head_top_position() if p.has_method("head_top_position") else p.global_position + Vector2(0.0, -26.0)


func _set_prompt(text: String, at: Vector2 = Vector2.INF) -> void:
	if text == "":
		if _prompt_on:
			_prompt_on = false
			HUD.hide_world_prompt(self)
		return
	_prompt_on = true
	HUD.show_world_prompt(self, text, at if at != Vector2.INF else global_position)


## The prompt text the player would see now (tests): "" when none shows.
func prompt_text() -> String:
	if not _prompt_on:
		return ""
	var e = HUD._world_prompts.get(get_instance_id())
	return String(e["label"].text) if e != null and e["panel"].visible else ""
