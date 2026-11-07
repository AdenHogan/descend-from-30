class_name StealthSpot
extends Node2D

# A HIDING PLACE (owner round 49o; docs/STEALTH_SPACES.md): a wardrobe, a bath — a piece a person would really hide in, in the room it stands in (`Stealth.HIDE_PIECES`,
# `Stealth.HOW`; owner, on a screenshot of a player hiding by a toilet: "hiding must contextually make sense"). Placed by `StealthSpot.add_for` on the planned pieces of a LIVE
# flat as a child of the room module, centred on the piece. There is no generic "against the wall" spot: a bare wall is nowhere to hide.
#
# It owns the PROMPT (owner: "a prompt appear for those areas where the player can hide") and the entry key:
#   in reach, crouched   ->  "Wardrobe   [W] Hide"  /  "Bath   [W] Get in"
#   in reach, standing   ->  "Wardrobe   [C] Crouch to hide"  /  "Bath   [C] Crouch to get in"   (the verb is taught by the place)
#   inside               ->  "[W] Come out"  (over the player's head: the camera is close)
# Search wins over hiding in SCAVENGE stance while a back-plane search spot with a live node is in reach (back_plane_spot.gd already owns [W] there); a piece that is searched
# out, or the combat stance, hides (`yield_to_search`).
#
# A piece whose FRONT stands between the player and the room (the bath's rim) is drawn over them while they are in it: `cover` is a copy of the piece's lower rows laid over the
# player (z 1, the actors' own layer: above the player, below every dead thing added to the flat after it), and the player rises to stand in the tub (`feet_y`).

const REACH := 10.0                  # px beyond the piece's face the player may stand and still be offered it
const LIFT_PAD := 8.0
const INSIDE_LIFT := 62.0            # the "Come out" pill hangs this far above the player's origin while they are hidden
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
var _cover: Sprite2D = null
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
		s.position = Vector2(float(it["x"]) + float(w) * 0.5, float(it["y"]))
		var rect: Rect2 = it.get("rect", Rect2())
		s.prompt_lift = (float(it["y"]) - rect.position.y) + LIFT_PAD if rect.size.y > 0.0 else 80.0
		module.add_child(s)
		var sprite_top: float = float(it["y"]) - float(int(it.get("ry", 0)))
		s.variant = variant_key(String(it.get("file", "")))
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
		if def.has("stand_up"):
			s.feet_y = module.global_position.y + float(it["y"]) - float(def["stand_up"])
		out.append(s)
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


## The player is in: the piece's front rows are laid over them.
func on_hide_begin() -> void:
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


func on_hide_end() -> void:
	_drop_cover(true)


## `fade`: let the cover go as the player steps back out (it frees itself); otherwise it is gone at once (the node is leaving the tree).
func _drop_cover(fade: bool = false) -> void:
	if _cover != null and is_instance_valid(_cover):
		if fade and _cover.is_inside_tree():
			var old := _cover
			var tw := old.create_tween()
			tw.tween_property(old, "modulate:a", 0.0, ENTER_FADE).set_trans(Tween.TRANS_SINE)
			tw.tween_callback(old.queue_free)
		else:
			_cover.queue_free()
	_cover = null


func has_cover() -> bool:
	return _cover != null and is_instance_valid(_cover)


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
		_set_prompt("[{move_up}] Come out", p.global_position + Vector2(0.0, -INSIDE_LIFT))     # over the player's head: the camera is close, the place's own pill would be off the screen
		return
	if p.get("hide_spot") != null or Stealth.conceal_of(p) != Stealth.NONE:
		_set_prompt("")
		return
	if not offered_to(p) or WorldState.loot_open or search_owns_the_key(p):
		_set_prompt("")
		return
	var crouched: bool = p.get("is_crouching") == true
	if crouched:
		_set_prompt("%s   [{move_up}] %s" % [label(), verb])
		if Input.is_action_just_pressed("move_up") and p.has_method("enter_hide"):
			p.enter_hide(self)
	else:
		_set_prompt("%s   [{crouch_toggle}] Crouch to %s" % [label(), verb.to_lower()])


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
