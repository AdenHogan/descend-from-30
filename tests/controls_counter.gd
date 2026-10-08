extends Node

# Test helper: counts the press and release EVENTS of one action that reach an _input handler.
var action: String = ""
var presses: int = 0
var releases: int = 0


func _input(event: InputEvent) -> void:
	if action == "" or not event.is_action(action):
		return
	if event.is_pressed():
		presses += 1
	else:
		releases += 1
