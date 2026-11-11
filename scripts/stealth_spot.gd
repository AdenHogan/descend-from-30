class_name StealthSpot
extends Node2D

# A HIDING PLACE (owner round 49o; docs/STEALTH_SPACES.md): a wardrobe, a bath, the back of a sofa or an armchair — a piece a person would really hide in or behind, in the room
# it stands in (`Stealth.HIDE_PIECES`, `Stealth.HOW`; owner, on a screenshot of a player hiding by a toilet: "hiding must contextually make sense") — or the wall beside a
# DOORWAY (`Stealth.WALL_HIDE`, round 49t: "hiding up against a module wall for enemies to pass by"), and only where that corner is bare. Placed by `StealthSpot.add_for` on the
# planned pieces of a LIVE flat and by `add_doorway` at its doorways (one per doorway, a child of the ROOM).
#
# It owns the PROMPT (owner: "a prompt appear for those areas where the player can hide") and the entry key — ONE press of [interact], in any stance (owner round 49q: "it should be
# automatic, not a move up or down or anything like that, just a hide prompt… and then another press and the player leaves their hiding spot"):
#   in reach             ->  "Wardrobe   [E] Hide"  /  "Bath   [E] Get in"  /  "Shower   [E] Hide behind the curtain"
#   inside               ->  "[E] Come out"  (over the player's head: the camera is close)
# The press goes through the InteractArbiter like every other [interact]: the nearest answerer takes it, and while a back-plane search spot with a live node is in reach in SCAVENGE
# stance the search owns it (`yield_to_search`); a piece that is searched out, or the combat stance, hides.
#
# A piece whose FRONT stands between the player and the room (the bath's rim) is drawn over them while they are in it: `cover` is a copy of the piece's lower rows laid over the
# player (z 1, the actors' own layer: above the player, below every dead thing added to the flat after it), and the player rises to stand in the tub (`feet_y`).

const REACH := 10.0                  # px beyond the piece's face the player may stand and still be offered it
const LIFT_PAD := 8.0
const MAX_RISE := 40.0               # the most the player rises to stand in a piece
const ENTER_FADE := 0.3              # the cover over the player comes in over the step in (the same time as the step: Player.HIDE_STEP_TIME)

var piece_id: String = ""
var noun: String = "wardrobe"
var verb: String = "Hide"
var how: String = "inside"
var noise: float = 40.0              # the noise of coming out (px)
var half_w: float = 20.0
var prompt_lift: float = 80.0        # world px above the node the prompt hangs
var yield_to_search: bool = true
var feet_y: float = INF              # world y the hidden player's feet stand on, when the piece has them stand in it (the bath); INF = they stay on the lane
var variant: String = ""             # the drawn variant's key ("bath_gold"): the lip row and the curtain depend on it
var cover_alpha: float = 1.0         # how opaque the cover is over the player (a shower curtain is plastic: a shade less than 1)
var behind_curtain: bool = false     # a drawn-shut shower curtain hangs between the player and the room (the whole sprite is the cover)
var piece_sprite: Sprite2D = null    # the piece's own sprite (to copy its front rows)
var cover_from_row: int = -1         # first row of the sprite drawn over the player, -1 = none
var shield: float = 0.0              # COVER, for a fight not built yet (Stealth.cover_info): the share of a shot the thing they are behind / in would stop...
var fire_from: bool = false          # ...and whether a person could shoot back from there
var needs_still: float = 0.0         # > 0: the prompt only shows once the player moves slower than this (px/s) — a doorway, walked through all day
var face_dir: int = 0                # +1 / -1: the way the player faces in there (their back to a doorway's wall); 0 = as they were
var quiet: bool = false              # a quiet place (a doorway): its prompt only shows when hiding is on the player's mind (Stealth.wants_hiding)
var stands: bool = false             # the player STANDS in there, flat against the wall (everywhere else they are down, crouched)
var bare_l: bool = false             # a doorway: is the corner on the left / the right of its wall bare enough to stand in
var bare_r: bool = false
var wall_offset: float = 16.0        # a doorway: the player's middle, from the wall
var _side: String = ""               # a doorway: the side taken ("l" / "r"), settled as they commit (prepare)
var jamb_x: float = INF              # a doorway's wall: the room-space x of the door frame drawn over the player (INF = none: the front door's corner has no post)
var _cover: Sprite2D = null
var _jamb: Node2D = null             # the door frame drawn over a player pressed beside a doorway
var _cover_extras: Array = []        # what stands IN FRONT of the piece (a coffee table, what is on it), copied over the cover in the room's own order
var _prompt_on: bool = false

const ModuleWalls := preload("res://scripts/module_walls.gd")
const ModuleGeo := preload("res://scripts/module_geo.gd")


## Lay a hiding spot on every hide-able piece of `plan` (a furniture plan, scripts/furniture_planner.gd) in `module`. Returns the spots made.
static func add_for(module: Node2D, plan: Dictionary) -> Array:
	var out: Array = []
	if module == null or plan.is_empty():
		return out
	for it in plan.get("items", []):
		var id := String(it.get("id", ""))
		if not Stealth.HIDE_PIECES.has(id):
			continue
		var def: Dictionary = Stealth.HIDE_PIECES[id]
		var w: int = int(it.get("w", 40))
		var s := StealthSpot.new()
		s.name = "Hide_%s_%d" % [id, out.size()]
		s.piece_id = id
		s.noun = String(def["noun"])
		s.verb = String(def["verb"])
		s.how = String(def["how"])
		s.noise = float(def["noise"])
		s.half_w = float(w) * 0.5
		s.shield = float(def.get("shield", 0.0))
		s.fire_from = bool(def.get("fire", false))
		s.position = Vector2(float(it["x"]) + float(w) * 0.5, float(it["y"]))
		var rect: Rect2 = it.get("rect", Rect2())
		s.prompt_lift = (float(it["y"]) - rect.position.y) + LIFT_PAD if rect.size.y > 0.0 else 80.0
		module.add_child(s)
		var sprite_top: float = float(it["y"]) - float(int(it.get("ry", 0)))
		s.variant = variant_key(String(it.get("file", "")))
		if s.how == "behind":
			# behind a sofa / an armchair: the whole piece (and what stands in front of it) is drawn over the player, whose feet go just behind its front edge
			s.piece_sprite = _sprite_of(module, id, float(it["x"]) - float(int(it.get("rx", 0))), sprite_top)
			if s.piece_sprite != null and s.piece_sprite.texture != null:
				s.cover_from_row = 0
				s.position.x = s.piece_sprite.position.x + float(s.piece_sprite.texture.get_width()) * 0.5      # the middle of what is DRAWN (a leaning sprite is not centred on its slot)
				s.half_w = float(s.piece_sprite.texture.get_width()) * 0.5
				s.feet_y = module.global_position.y + float(it["y"]) + float(def.get("feet_dy", 0.0))
				s.yield_to_search = true
		if def.has("lip_up"):
			s.piece_sprite = _sprite_of(module, id, float(it["x"]) - float(int(it.get("rx", 0))), sprite_top)
			if s.piece_sprite != null and s.piece_sprite.texture != null:
				s.cover_from_row = maxi(0, int(it.get("ry", 0)) - lip_rows(def, String(it.get("file", ""))))
				var curtain: Dictionary = def.get("curtain", {})
				if curtain.has(s.variant):
					s.behind_curtain = true
					s.cover_from_row = 0
					s.cover_alpha = float(curtain[s.variant]["alpha"])
					s.noun = String(curtain[s.variant]["noun"])
					s.verb = String(curtain[s.variant]["verb"])
					s.shield = float(curtain[s.variant].get("shield", s.shield))
					s.fire_from = bool(curtain[s.variant].get("fire", s.fire_from))
		if def.has("stand_up"):
			s.feet_y = module.global_position.y + float(it["y"]) - float(def["stand_up"])
		out.append(s)
	return out


## THE WALL BESIDE A DOORWAY (Stealth.WALL_HIDE): ONE hiding place per doorway, a child of the room, standing on the join between two rooms (or at the flat's front
## door). `xb` = the doorway's x in the room's space; `post` = a doorway between two rooms (its frame's jamb is drawn over whoever stands beside it) rather than the front
## door; `sides` = which side of that wall has a bare corner to stand in: {"l": bool, "r": bool} ("l" = left of the wall). Returns the spot, or null when neither is bare.
static func add_doorway(room: Node, xb: float, post: bool, sides: Dictionary) -> StealthSpot:
	if room == null or not (bool(sides.get("l", false)) or bool(sides.get("r", false))):
		return null
	var def: Dictionary = Stealth.WALL_HIDE
	var s := StealthSpot.new()
	s.name = "Hide_doorway_%d" % int(round(xb))
	s.piece_id = "doorway"
	s.noun = String(def["noun"])
	s.verb = String(def["verb"])
	s.how = "against"
	s.noise = float(def["noise"])
	s.half_w = float(def["reach"]) - REACH
	s.shield = float(def["shield"])
	s.fire_from = bool(def["fire"])
	s.needs_still = float(def["still"])
	s.quiet = true
	s.stands = true
	s.yield_to_search = false
	s.bare_l = bool(sides.get("l", false))
	s.bare_r = bool(sides.get("r", false))
	s.wall_offset = float(def["offset"])
	s.position = Vector2(xb, float(def["floor_y"]))
	room.add_child(s)
	s.feet_y = s.global_position.y              # (the room's own floor depth where the doorway's opening begins)
	if post:
		s.jamb_x = xb
	return s


## Is the corner at that EDGE of a room ("l" / "r" = the module's own left / right edge) bare enough to stand in? Nothing standing in the columns
## WALL_HIDE.clear_from..clear_to from the wall: `standing` = module-local [x0, x1] spans of what stands there; `skyline` = a baked room's clear rows per column.
static func wall_is_bare(edge: String, standing: Array, skyline: Array) -> bool:
	var def: Dictionary = Stealth.WALL_HIDE
	var w: int = ModuleGeo.WIDTH
	var c0: int = int(def["clear_from"]) if edge == "l" else w - int(def["clear_to"])
	var c1: int = int(def["clear_to"]) if edge == "l" else w - int(def["clear_from"])
	for span in standing:
		if float(span[1]) > float(c0) and float(span[0]) < float(c1):
			return false
	if not skyline.is_empty():
		for x in range(c0, c1):
			if x < 0 or x >= skyline.size() or int(skyline[x]) < int(def["clear_rows"]):
				return false
	return true


## A doorway's wall: which side of it would hide the player right now ("l" / "r"), or "" for neither. Away from the nearest of the dead that are up — and only if that
## side's corner is bare (the other side is in plain view of what is coming); with nobody about, the side they are on, else the other.
func side_for(p: Node2D) -> String:
	if how != "against" or p == null:
		return ""
	var nearest: Node2D = null
	var best := INF
	for z in Stealth.threats(p):
		var d: float = absf((z as Node2D).global_position.x - global_position.x)
		if d < best:
			best = d
			nearest = z
	if nearest != null:
		var away: String = "l" if nearest.global_position.x > global_position.x else "r"
		return away if (bare_l if away == "l" else bare_r) else ""
	var own: String = "l" if p.global_position.x < global_position.x else "r"
	if bare_l if own == "l" else bare_r:
		return own
	var other: String = "r" if own == "l" else "l"
	return other if (bare_l if other == "l" else bare_r) else ""


## Called by the player as they commit (Player.enter_hide): settle which side of the wall they take and which way they face (back to the wall, facing the room).
func prepare(p: Node2D) -> void:
	if how != "against":
		return
	_side = side_for(p)
	if _side == "":
		_side = "l" if bare_l else "r"
	face_dir = -1 if _side == "l" else 1


## Where the player's middle goes (world x): the piece's middle — or, at a doorway, `wall_offset` out from the wall on the side `prepare` chose.
func hide_x() -> float:
	if how == "against":
		return global_position.x + (-wall_offset if _side == "l" else wall_offset)
	return global_position.x


## What stands in a planned room, as module-local [x0, x1] spans: every wall / front / floor piece (pictures, rugs, ceiling lights and things on top of furniture do not).
static func standing_spans(plan: Dictionary) -> Array:
	var out: Array = []
	for it in plan.get("items", []):
		if not (String(it.get("plane", "")) in ["wall", "front", "floor"]):
			continue
		var rect: Rect2 = it.get("rect", Rect2())
		if rect.size.x > 0.0:
			out.append([rect.position.x, rect.end.x])
		else:
			var x0: float = float(it.get("x", 0)) - float(int(it.get("rx", 0)))
			out.append([x0, x0 + float(int(it.get("w", 0)))])
	return out


## How many rows above the piece's feet line the front lip of the variant drawn in `file` ("bath_gold_b3") begins: the drawn variant's own number, else the default.
static func lip_rows(def: Dictionary, file: String) -> int:
	var table: Dictionary = def.get("lip_up", {})
	return int(table.get(variant_key(file), def.get("lip_default", 20)))


## "bath_gold_b3" (the sprite file of a lean bucket) -> "bath_gold" (the drawn variant).
static func variant_key(file: String) -> String:
	var cut := file.rfind("_b")
	if cut > 0 and file.substr(cut + 2).is_valid_int():
		return file.substr(0, cut)
	return file


static func _sprite_of(module: Node2D, id: String, x: float, y: float) -> Sprite2D:
	for c in module.get_children():
		if c is Sprite2D and String(c.get_meta("furniture", "")) == id and absf(c.position.x - x) < 0.6 and absf(c.position.y - y) < 0.6:
			return c
	return null


func _ready() -> void:
	add_to_group("stealth_spot")
	add_to_group(InteractArbiter.GROUP)      # hiding is an [interact] press (round 49q): the nearest answerer takes it, like every other [interact]


func _exit_tree() -> void:
	_set_prompt("")
	_drop_cover()


## The noise of coming out of this place (px).
func exit_noise() -> float:
	return noise


## What the prompt calls the place ("Wardrobe", "Bath").
func label() -> String:
	return noun.capitalize()


## How far (px) a player whose origin is at `player_origin_y` rises to stand in this piece (the bath's tub); 0 = they stay where they are.
func rise_for(player_origin_y: float) -> float:
	if feet_y == INF:
		return 0.0
	return clampf((player_origin_y + Stealth.PLAYER_FEET_DROP) - feet_y, 0.0, MAX_RISE)


## The player is in: the piece's front rows are laid over them (a doorway: its frame's jamb).
func on_hide_begin() -> void:
	if jamb_x != INF and _jamb == null:
		var j := _JambCover.new()
		j.name = "HideJamb"
		j.xb = jamb_x
		j.z_index = 1
		get_parent().add_child(j)       # (a doorway's spot is a child of the room: the frame is drawn in the room's own space, like the walls)
		_jamb = j
	if cover_from_row < 0 or piece_sprite == null or not is_instance_valid(piece_sprite) or _cover != null:
		return
	var tex := piece_sprite.texture
	var c := Sprite2D.new()
	c.name = "HideCover"
	c.texture = tex
	c.centered = false
	c.region_enabled = true
	c.region_rect = Rect2(0, cover_from_row, tex.get_width(), tex.get_height() - cover_from_row)
	c.position = piece_sprite.position + Vector2(0, cover_from_row)
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var want: Color = piece_sprite.modulate
	want.a *= cover_alpha
	c.modulate = Color(want.r, want.g, want.b, 0.0)      # fades in as the player steps in: they are sliced by it as they go behind / down
	c.z_index = 1                                    # the actors' layer: over the player (the module was added after them), under the dead (added later still)
	piece_sprite.get_parent().add_child(c)
	c.create_tween().tween_property(c, "modulate:a", want.a, ENTER_FADE).set_trans(Tween.TRANS_SINE)
	_cover = c
	# What stands IN FRONT of the piece was drawn after it in the room — a coffee table across a sofa's front, what is on that table, a basket before a bath. The cover is
	# drawn over the player and would wipe them out, so each is copied over it too, in the room's own order: the picture is exactly the room's, with the player slipped in behind.
	var area := Rect2(c.position, Vector2(tex.get_width(), tex.get_height() - cover_from_row))
	var seen := false
	for sib in piece_sprite.get_parent().get_children():
		if sib == piece_sprite:
			seen = true
			continue
		if not seen or not (sib is Sprite2D) or sib == c or sib in _cover_extras:
			continue
		var sp := sib as Sprite2D
		if sp.texture == null or not sp.visible or not (sp.has_meta("furniture") or String(sp.name).begins_with("Open_")):
			continue
		var fw: float = float(sp.texture.get_width()) / float(maxi(1, sp.hframes))
		if not area.intersects(Rect2(sp.position, Vector2(fw, float(sp.texture.get_height()) / float(maxi(1, sp.vframes))))):
			continue
		var e := Sprite2D.new()
		e.name = "HideCoverFront"
		e.texture = sp.texture
		e.centered = false
		e.hframes = sp.hframes
		e.vframes = sp.vframes
		e.frame = sp.frame
		e.position = sp.position
		e.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		e.modulate = Color(sp.modulate.r, sp.modulate.g, sp.modulate.b, 0.0)
		e.z_index = 1
		piece_sprite.get_parent().add_child(e)
		e.create_tween().tween_property(e, "modulate:a", sp.modulate.a, ENTER_FADE).set_trans(Tween.TRANS_SINE)
		_cover_extras.append(e)


func on_hide_end() -> void:
	_drop_cover(true)


## `fade`: let the cover go as the player steps back out (it frees itself); otherwise it is gone at once (the node is leaving the tree).
func _drop_cover(fade: bool = false) -> void:
	for old in [_cover] + _cover_extras:
		if old != null and is_instance_valid(old):
			if fade and old.is_inside_tree():
				var tw: Tween = old.create_tween()
				tw.tween_property(old, "modulate:a", 0.0, ENTER_FADE).set_trans(Tween.TRANS_SINE)
				tw.tween_callback(old.queue_free)
			else:
				old.queue_free()
	_cover = null
	_cover_extras.clear()
	if _jamb != null and is_instance_valid(_jamb):
		_jamb.queue_free()
	_jamb = null


## The door frame of the doorway a player is pressed beside, drawn again over them (the same drawing the walls make): the jamb is what they are behind.
class _JambCover extends Node2D:
	var xb: float = 0.0
	func _draw() -> void:
		ModuleWalls.draw_door_frame(self, xb, true)


func has_cover() -> bool:
	return _cover != null and is_instance_valid(_cover)


func in_reach(p: Node2D) -> bool:
	return absf(p.global_position.x - global_position.x) <= half_w + REACH


## Would a search take the [interact] press here right now? (a scavenge-stance player, a back-plane spot with a live node in reach)
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
	if needs_still > 0.0 and p is CharacterBody2D and absf((p as CharacterBody2D).velocity.x) > needs_still:
		return false                    # a doorway: offered once they have all but stopped beside it, not on every walk through
	if quiet and not Stealth.wants_hiding(p):
		return false                    # …and only when hiding is on their mind (crouched, or the dead are up and near): never a prompt that nags
	if how == "against" and side_for(p as Node2D) == "":
		return false                    # no side of this wall would hide them from what is coming
	return in_reach(p)


## An [interact] member (InteractArbiter): offered to the player in reach, not while they are already in a place, not while a live search up here owns the press.
func interact_ready() -> bool:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null or not is_instance_valid(p) or p.get("hide_spot") != null or Stealth.conceal_of(p) != Stealth.NONE:
		return false
	return offered_to(p) and not WorldState.loot_open and not search_owns_the_key(p)


func interact_x() -> float:
	return global_position.x


func interact_rank() -> int:
	return InteractArbiter.RANK_THING


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null or not is_instance_valid(p):
		_set_prompt("")
		return
	if p.get("hide_spot") == self:
		_set_prompt("[{interact}] Come out", _over_head(p))     # right over the player's head, like a speech bubble (owner round 49q: "the text for come out is just too damn high")
		return
	if p.get("hide_spot") != null or Stealth.conceal_of(p) != Stealth.NONE:
		_set_prompt("")
		return
	if not interact_ready():
		_set_prompt("")
		return
	# ONE press, any stance: the prompt says what it does and the press does it (owner round 49q — no up / crouch to learn).
	_set_prompt(("%s   [{interact}] %s" % [label(), verb]) if noun != "" else ("[{interact}] %s" % verb), _over_head(p))
	if Input.is_action_just_pressed("interact") and InteractArbiter.take(self) and p.has_method("enter_hide"):
		p.enter_hide(self)


## Where the prompt hangs: the top of the player's head (a bath's curtain rail or a wardrobe's top is not where a person looks).
func _over_head(p: Node2D) -> Vector2:
	return p.head_top_position() if p.has_method("head_top_position") else p.global_position + Vector2(0.0, -26.0)


func _set_prompt(text: String, at: Vector2 = Vector2.INF) -> void:
	if text == "":
		if _prompt_on:
			_prompt_on = false
			HUD.hide_world_prompt(self)
		return
	_prompt_on = true
	HUD.show_world_prompt(self, text, at if at != Vector2.INF else global_position + Vector2(0.0, -prompt_lift))


## The prompt text the player would see now (tests): "" when none shows.
func prompt_text() -> String:
	if not _prompt_on:
		return ""
	var e = HUD._world_prompts.get(get_instance_id())
	return String(e["label"].text) if e != null and e["panel"].visible else ""


## For tools / the capture steps: where this place is.
func describe() -> void:
	print("STEALTH_SPOT ", piece_id, " x ", global_position.x, " y ", global_position.y, " how ", how, " feet_y ", feet_y)
