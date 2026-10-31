extends Sprite2D

## A piece of furniture that CHANGES when its node is searched (owner round 34: "when you search a piece of furniture, many pieces of furniture
## change appearance… The drawer opens, or a door swings open"; round 45c: "the movement animations should happen when the player presses interact
## to begin the scavenge of the node, not after… every node, if it makes logical sense, should have an animation: search a table and a glass falls
## over, search the oven and the oven door opens, search a computer and the screen turns off").
## tools/art/openables.py bakes, per module art + anchor, a small frame sheet of the thing happening in true perspective
## (assets/rooms/open/<art>__<anchor>[_r2|_r3].png + open_meta.json: a `kind` — drawer / door_h / door_drop / lid / topple / screen_off — and the frames);
## this node lies it over the module's art, just above the baked picture and below the scavenge orbs.
## It PLAYS the moment the search BEGINS (Interactable.on_search_begin → `play`, which also notes WorldState.opened_anchors and makes the sound of
## its kind); a search walked away from leaves it open. An anchor already opened or searched (a re-entry, a load) simply shows the rest state.
## A pure view of WorldState.opened_anchors / searched_anchors — nothing here is saved.

const META_PATH := "res://assets/rooms/open/open_meta.json"
const DIR := "res://assets/rooms/open/"
const STEP := 0.11                        # seconds per frame of the opening

static var _meta: Dictionary = {}
static var _meta_loaded := false

var apartment_id := ""
var anchor_name := ""
var frames_total := 1
var kind := "drawer"
var _tween: Tween = null


static func meta() -> Dictionary:
	if not _meta_loaded:
		_meta_loaded = true
		var f := FileAccess.open(META_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_meta = parsed
	return _meta


## Lay an opening over each of this module's openable anchors. A module with no entry (every variant but
## the base art, so far) gets nothing — never an error.
static func attach(module: Node, apt: String, run: int) -> Array:
	var made: Array = []
	if module == null or module.scene_file_path == "":
		return made
	var art_name: String = module.scene_file_path.get_file().get_basename()
	var entry: Dictionary = meta().get(art_name, {})
	if entry.is_empty():
		return made
	var art := module.get_node_or_null("Art")
	for anchor_name_ in entry.keys():
		if module.get_node_or_null(String(anchor_name_)) == null:
			continue
		var d: Dictionary = entry[anchor_name_]
		var tex: Texture2D = _texture_for(art_name, String(anchor_name_), run)
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.set_script(load("res://scripts/open_furniture.gd"))
		s.name = "Open_" + String(anchor_name_)
		s.texture = tex
		s.hframes = int(d.get("frames", 1))
		s.frames_total = s.hframes
		s.kind = String(d.get("kind", "drawer"))
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(float(d["x"]), float(d["y"]))
		s.apartment_id = apt
		s.anchor_name = String(anchor_name_)
		module.add_child(s)
		if art != null:
			module.move_child(s, art.get_index() + 1)
		s.add_to_group("open_furniture")
		s.refresh()
		made.append(s)
	return made


static func _texture_for(art_name: String, anchor: String, run: int) -> Texture2D:
	for r in range(run, 0, -1):
		var p := DIR + art_name + "__" + anchor + ("" if r == 1 else "_r%d" % r) + ".png"
		if ResourceLoader.exists(p):
			return load(p)
	return null


func is_open() -> bool:
	return visible


## Show the rest state (open if pressed on or searched, hidden if not) with no animation.
func refresh() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = WorldState.is_anchor_opened(apartment_id, anchor_name)
	frame = frames_total - 1
	if visible:
		_stop_live_screens()


## The player pressed interact on this node: play the opening now (once), with the sound of its kind.
func play() -> void:
	if visible:
		return
	visible = true
	frame = 0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	for i in range(1, frames_total):
		_tween.tween_interval(STEP)
		_tween.tween_callback(func(): frame = i)
	if kind == "screen_off":
		_tween.tween_callback(_stop_live_screens)
	NodeReaction.play_kind_sound(get_parent() if get_parent() != null else self, kind, _centre())


## A search is finished: make sure it is open (it normally has been since the press). Kept as the old entry point (group call / tools).
func on_searched(apt: String, anchor: String) -> void:
	if apt == apartment_id and anchor == anchor_name:
		play()


func on_search_start(apt: String, anchor: String) -> void:
	if apt == apartment_id and anchor == anchor_name:
		play()


func _centre() -> Vector2:
	return to_global(Vector2(float(texture.get_width()) / float(maxi(1, hframes)), float(texture.get_height())) * 0.5) if texture != null else global_position


## A live screen under this patch (static, a struck TV, a blinking light) goes dark with it (scripts/module_anim.gd `screen_off`).
func _stop_live_screens() -> void:
	if kind != "screen_off" or texture == null:
		return
	# A PLANNED room builds this patch before it is in the tree (its `refresh()` runs while the room is being laid), so there is no tree to ask yet — and the live screen under it
	# (a node of the module's `Anims`) does not exist yet either. Wait until the patch is in the tree, then a frame more, and stop the screen then (found by the round-49f bot sweep:
	# "Cannot call method 'call_group' on a null value" on re-entering a flat whose monitor was already switched off).
	if not is_inside_tree():
		if not tree_entered.is_connected(_stop_live_screens_soon):
			tree_entered.connect(_stop_live_screens_soon, CONNECT_ONE_SHOT)
		return
	var size := Vector2(float(texture.get_width()) / float(maxi(1, hframes)), float(texture.get_height()))
	get_tree().call_group("module_anim", "screen_off", Rect2(global_position, size))


func _stop_live_screens_soon() -> void:
	call_deferred("_stop_live_screens")

