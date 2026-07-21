extends Node
class_name TutorialHints

# Floor-30 first-run tutorial: control hints scrawled in blood on the walls
# (diegetic — no popup boxes). Key names are pulled live from SettingsManager
# so a rebind shows the player's actual key. Positions are constants tuned in
# the editor; gating (first run + floor 30) is the caller's job.

static func _key(action: String) -> String:
	return SettingsManager.binding_label(action)


# [x, y, text, font_size]. Placed on the corridor wall above the doors.
static func hallway_hints() -> Array:
	return [
		[170, 250, "MOVE   A · D   or CLICK where you run", 20],
		[150, 292, "they hear you. RUN [%s] and they come" % _key("sprint"), 16],
		[430, 246, "LISTEN at the doors — hold [%s]" % _key("listen"), 20],
		[470, 288, "hear what waits inside", 15],
		[600, 250, "[%s] or CLICK a door to enter" % _key("interact"), 18],
		[726, 246, "STRIKE  [%s]     stance  [%s]" % [_key("attack"), _key("mode_toggle")], 18],
		[905, 250, "REST  [%s]  while you still can" % _key("rest"), 18],
	]


# Hints inside the first tutorial apartments.
static func room_hints() -> Array:
	return [
		[240, 250, "SEARCH the marks — CLICK them", 18],
		[560, 250, "PUSH it off you  [%s]" % _key("push"), 18],
		[400, 292, "HEAL before the grey takes you", 15],
	]


static func spawn(parent: Node, hints: Array) -> void:
	var scene = load("res://scripts/blood_text.gd")
	for h in hints:
		var node = scene.new()
		node.setup(h[2], h[3])
		node.position = Vector2(h[0], h[1])
		parent.add_child(node)
