class_name StealthSpot
extends Node2D

# A HIDING PLACE (owner round 49o; docs/STEALTH_SPACES.md): a wardrobe, a cupboard, a larder. Placed by `StealthSpot.add_for` on the planned pieces of a LIVE flat
# (Stealth.HIDE_PIECES) as a child of the room module, centred on the piece.
#
# It owns the PROMPT (owner: "a prompt appear for those areas where the player can hide") and the entry key:
#   in reach, crouched   ->  "Wardrobe   [W] Hide"            [W] hides
#   in reach, standing   ->  "Wardrobe   [C] Crouch to hide"  (the verb is taught by the place)
#   inside               ->  "[W] Come out"
# Search wins over hiding in SCAVENGE stance while a back-plane search spot with a live node is in reach (back_plane_spot.gd already owns [W] there); a wardrobe that
# is searched out, or the combat stance, hides (`yield_to_search`).

const REACH := 10.0                  # px beyond the piece's face the player may stand and still be offered it
const LIFT_PAD := 8.0

const KIND_FURNITURE := "furniture"      # inside a piece: its door is not silent (Stealth.EXIT_NOISE)
const KIND_WALL := "wall"                # flat against a bare wall in the dark: nothing to creak
const NOOK_HALF_W := 14.0
const NOOK_LIFT := 92.0

var kind: String = KIND_FURNITURE
var label: String = "Wardrobe"            # what the prompt calls the place
var piece_id: String = ""
var noun: String = "wardrobe"
var half_w: float = 20.0
var prompt_lift: float = 80.0        # world px above the node the prompt hangs
var yield_to_search: bool = true
var _prompt_on: bool = false


## Lay a hiding spot on every hide-able piece of `plan` (a furniture plan, scripts/furniture_planner.gd) in `module`. Returns the spots made.
static func add_for(module: Node2D, plan: Dictionary) -> Array:
	var out: Array = []
	if module == null or plan.is_empty():
		return out
	for it in plan.get("items", []):
		var id := String(it.get("id", ""))
		if not Stealth.HIDE_PIECES.has(id):
			continue
		var w: int = int(it.get("w", 40))
		var s := StealthSpot.new()
		s.name = "Hide_%s_%d" % [id, out.size()]
		s.piece_id = id
		s.noun = String(Stealth.HIDE_PIECES[id])
		s.label = s.noun.capitalize()
		s.half_w = float(w) * 0.5
		s.position = Vector2(float(it["x"]) + float(w) * 0.5, float(it["y"]))
		var rect: Rect2 = it.get("rect", Rect2())
		s.prompt_lift = (float(it["y"]) - rect.position.y) + LIFT_PAD if rect.size.y > 0.0 else 80.0
		module.add_child(s)
		out.append(s)
	return out


## The dark corner just inside a flat's front door: the player arrives on it, so the prompt is there from the first step (owner: "if a player enters
## a module and immediately has a hide prompt to hide against the module wall, enemies can move past"). `parent` is the room, `x` the arrival x in world
## space, `lane_y` the walking line.
static func add_nook(parent: Node, x: float, lane_y: float) -> StealthSpot:
	var s := StealthSpot.new()
	s.name = "Hide_wall_nook"
	s.kind = KIND_WALL
	s.label = "Against the wall"
	s.piece_id = "wall_nook"
	s.noun = "wall"
	s.half_w = NOOK_HALF_W
	s.prompt_lift = NOOK_LIFT
	parent.add_child(s)
	s.global_position = Vector2(x, lane_y)
	return s


func exit_noise() -> float:
	return Stealth.EXIT_NOISE if kind == KIND_FURNITURE else 0.0


func _ready() -> void:
	add_to_group("stealth_spot")


func _exit_tree() -> void:
	_set_prompt("")


func in_reach(p: Node2D) -> bool:
	return absf(p.global_position.x - global_position.x) <= half_w + REACH


## Would a search take the [W] press here right now? (a scavenge-stance player, a back-plane spot with a live node in reach)
func search_owns_the_key(p: Node2D) -> bool:
	if not yield_to_search or not WorldState.is_scavenge_mode:
		return false
	for sp in get_tree().get_nodes_in_group("back_plane_spot"):
		if is_instance_valid(sp) and sp.has_method("player_near") and sp.has_live_node() and sp.player_near(p):
			return true
	return false


## Can the player be offered this place at all right now?
func offered_to(p: Node) -> bool:
	if p == null or not is_instance_valid(p) or not (p is Node2D):
		return false
	if p.get("is_dead") == true or p.get("is_dying") == true or p.get("is_cutscene") == true or p.get("escaping") == true:
		return false
	if p.get("back_spot") != null or p.get("on_balcony_plane") == true:
		return false
	if InteractArbiter.world_of(self) != InteractArbiter.world_of(p):
		return false
	return in_reach(p)


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null or not is_instance_valid(p):
		_set_prompt("")
		return
	if p.get("hide_spot") == self:
		_set_prompt("[{move_up}] Come out")
		return
	if p.get("hide_spot") != null or Stealth.conceal_of(p) != Stealth.NONE:
		_set_prompt("")
		return
	if not offered_to(p) or WorldState.loot_open or search_owns_the_key(p):
		_set_prompt("")
		return
	var crouched: bool = p.get("is_crouching") == true
	if crouched:
		_set_prompt("%s   [{move_up}] Hide" % label)
		if Input.is_action_just_pressed("move_up") and p.has_method("enter_hide"):
			p.enter_hide(self)
	else:
		_set_prompt("%s   [{crouch_toggle}] Crouch to hide" % label)


func _set_prompt(text: String) -> void:
	if text == "":
		if _prompt_on:
			_prompt_on = false
			HUD.hide_world_prompt(self)
		return
	_prompt_on = true
	HUD.show_world_prompt(self, text, global_position + Vector2(0.0, -prompt_lift))


## The prompt text the player would see now (tests): "" when none shows.
func prompt_text() -> String:
	if not _prompt_on:
		return ""
	var e = HUD._world_prompts.get(get_instance_id())
	return String(e["label"].text) if e != null and e["panel"].visible else ""
