extends Sprite2D

## A piece of furniture that CHANGES once its node has been searched (owner round 34: "when you search a
## piece of furniture, many pieces of furniture change appearance when you're done. The drawer opens, or
## a door swings open"). tools/art/openables.py bakes, per module art + anchor, a small frame sheet of the
## furniture opening in true perspective (assets/rooms/open/<art>__<anchor>[_r2|_r3].png + open_meta.json);
## this node lies it over the module's art, just above the baked picture and below the scavenge orbs.
## loot_ui calls `on_searched` the moment a search finishes (group "open_furniture"): the frames play once;
## an anchor already searched (a re-entry, a load) simply shows the open look. Pure view of
## WorldState.searched_anchors — nothing here is saved.

const META_PATH := "res://assets/rooms/open/open_meta.json"
const DIR := "res://assets/rooms/open/"
const STEP := 0.085                       # seconds per frame of the opening

static var _meta: Dictionary = {}
static var _meta_loaded := false

var apartment_id := ""
var anchor_name := ""
var frames_total := 1
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


## Show the rest state (open if searched, hidden if not) with no animation.
func refresh() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = WorldState.is_anchor_searched(apartment_id, anchor_name)
	frame = frames_total - 1


func on_searched(apt: String, anchor: String) -> void:
	if apt != apartment_id or anchor != anchor_name or visible:
		return
	visible = true
	frame = 0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	for i in range(1, frames_total):
		_tween.tween_interval(STEP)
		_tween.tween_callback(func(): frame = i)
