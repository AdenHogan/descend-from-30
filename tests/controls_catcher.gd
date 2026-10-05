extends Node

# Test helper: records whether an input EVENT for `action` reached an _input handler (not just polling).
var action: String = ""
var got: bool = false


func _input(event: InputEvent) -> void:
	if action != "" and event.is_action_pressed(action):
		got = true
