class_name RoomFurniture
extends RefCounted

## Lays a furniture PLAN (scripts/furniture_planner.gd) into a room module as real nodes (owner round 47): each piece is a Sprite2D in the module's draw order (just above the shell's Art, in
## the plan's own order, so a bed stands in front of a dresser and a lamp on top of its table), each scavenge node a Marker2D exactly like the ones the baked modules carry (room.gd takes
## every direct Marker2D child; `back_plane` marks a step-up node), each light a Node2D under `Lights` (apartment_lights.gd lights them, seeded per flat + run), and a piece that opens when
## searched (a drawer, a wardrobe door) gets an `Open_<anchor>` overlay — the same node the baked rooms use (scripts/open_furniture.gd), so Interactable.on_search_begin finds it.
##
## The furniture is drawn at its morning look; the run's grime is a tint on every sprite (the shell's own art carries the damp and cracks).

const RUN_TINT := [Color(1.0, 1.0, 1.0), Color(0.95, 0.94, 0.93), Color(0.87, 0.86, 0.87)]

static var _tex_cache: Dictionary = {}


static func texture(file: String) -> Texture2D:
	if not _tex_cache.has(file):
		var p := FurniturePlanner.SPRITE_DIR + file + ".png"
		_tex_cache[file] = load(p) if ResourceLoader.exists(p) else null
	return _tex_cache[file]


static func tint_for(run: int) -> Color:
	return RUN_TINT[clampi(run - 1, 0, 2)]


## Build `pl` into `module`. Returns {sprites, anchors, lights, opens} (the nodes made), for tests and tools.
static func build(module: Node2D, pl: Dictionary, apt: String, run: int) -> Dictionary:
	var made := {"sprites": [], "anchors": [], "lights": [], "opens": [], "anims": []}
	if module == null or pl.is_empty():
		return made
	var art := module.get_node_or_null("Art")
	var at: int = (art.get_index() + 1) if art != null else 0
	var tint := tint_for(run)
	var n := 0
	for it in pl["items"]:
		var tex := texture(String(it["file"]))
		if tex == null:
			continue                                                    # a missing sprite is a missing piece, never a crash
		var s := Sprite2D.new()
		s.name = "F%02d_%s" % [n, String(it["id"])]
		s.texture = tex
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(int(it["x"]) - int(it["rx"]), int(it["y"]) - int(it["ry"]))
		s.modulate = tint
		s.set_meta("furniture", String(it["id"]))
		s.set_meta("plane", String(it["plane"]))
		module.add_child(s)
		module.move_child(s, at)
		at += 1
		n += 1
		made["sprites"].append(s)
		if String(it.get("opens", "")) != "" and String(it.get("open_file", "")) != "":
			var o := _open_overlay(module, it, tex, apt, tint)
			if o != null:
				module.add_child(o)
				module.move_child(o, at)
				at += 1
				made["opens"].append(o)
	for a in pl["anchors"]:
		var m := Marker2D.new()
		m.name = String(a["name"])
		m.position = Vector2(int(a["x"]), int(a["y"]))
		if bool(a["bp"]):
			m.set_meta("back_plane", true)
		module.add_child(m)
		made["anchors"].append(m)
	if not pl["lights"].is_empty():
		var holder := module.get_node_or_null("Lights")
		if holder == null:
			holder = Node2D.new()
			holder.name = "Lights"
			module.add_child(holder)
		var k := holder.get_child_count()
		for l in pl["lights"]:
			var ln := Node2D.new()
			ln.name = "lamp_%d" % k
			k += 1
			ln.position = Vector2(int(l["x"]), int(l["y"]))
			ln.set_meta("kind", String(l["kind"]))
			holder.add_child(ln)
			made["lights"].append(ln)
	if not pl.get("anims", []).is_empty():
		var aholder := module.get_node_or_null("Anims")
		if aholder == null:
			aholder = Node2D.new()
			aholder.name = "Anims"
			module.add_child(aholder)
		var ai := aholder.get_child_count()
		for an in pl["anims"]:
			var a := Node2D.new()
			a.name = "anim_%d" % ai
			ai += 1
			a.position = Vector2(int(an["x"]), int(an["y"]))
			a.set_script(load("res://scripts/module_anim.gd"))
			for k in ["kind", "fall", "color", "w", "h"]:
				if an.has(k):
					a.set_meta(k, an[k])
			aholder.add_child(a)
			made["anims"].append(a)
	return made


## The open state of a piece: a strip (closed cell, then the opening frames) over its own sprite, played when its anchor's search begins (open_furniture.gd).
static func _open_overlay(module: Node2D, it: Dictionary, closed: Texture2D, apt: String, tint: Color) -> Sprite2D:
	var tex := texture("open/" + String(it["open_file"]))
	if tex == null or closed == null:
		return null
	var frames: int = maxi(1, int(round(float(tex.get_width()) / float(maxi(1, closed.get_width())))))
	var s := Sprite2D.new()
	s.set_script(load("res://scripts/open_furniture.gd"))
	s.name = "Open_" + String(it["opens"])
	s.texture = tex
	s.hframes = frames
	s.frames_total = frames
	s.kind = String(it.get("kind", "drawer"))
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = Vector2(int(it["x"]) - int(it["rx"]), int(it["y"]) - int(it["ry"]))
	s.modulate = tint
	s.apartment_id = apt
	s.anchor_name = String(it["opens"])
	s.add_to_group("open_furniture")
	s.refresh()
	return s
