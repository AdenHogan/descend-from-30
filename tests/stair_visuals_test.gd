extends Node

# Which staircase art each side of a floor shows, for every way you can arrive.
# Lobby_* is the UP stairwell (the lobby is the building's bottom);
# Hallway_Staircase_* is the DOWN one (floor 30 is the top). The side you arrived
# on offers the way back, the far side carries on — so exactly one side is up and
# one is down, and the descent zig-zags across the corridor.
# Regression: the art used to ignore stair_direction on left arrivals, so floors
# 25 and 26 showed the same stairwell and a side whose arrow said "up" was drawn
# descending.
# Run:  godot --headless res://tests/stair_visuals_test.tscn

var fails := 0
func chk(c: bool, m: String) -> void:
	print(("  PASS  " if c else "  FAIL  ") + m); if not c: fails += 1
func _ready() -> void:
	WorldState.new_game()
	WorldState.current_floor = 25
	# side arrived, direction travelled -> which side should show UP art
	for case in [["left","down",true],["left","up",false],["right","down",false],["right","up",true]]:
		WorldState.stair_spawn_side = case[0]
		WorldState.stair_direction = case[1]
		var bf = load("res://scenes/building_floors.tscn").instantiate()
		bf.setup_floor = 25; bf.passive = true
		add_child(bf)
		for i in range(3): await get_tree().process_frame
		var ll = bf.get_node("LobbyLeft"); var hl = bf.get_node("HallwayStaircaseLeft")
		var lr = bf.get_node("LobbyRight"); var hr = bf.get_node("HallwayStaircaseRight")
		var want_left_up: bool = case[2]
		var tag := "arrive %s going %s" % [case[0], case[1]]
		chk(ll.visible == want_left_up and hl.visible != want_left_up, "%s: left shows %s" % [tag, "UP" if want_left_up else "DOWN"])
		chk(lr.visible != want_left_up and hr.visible == want_left_up, "%s: right shows %s" % [tag, "DOWN" if want_left_up else "UP"])
		chk(int(ll.visible) + int(hl.visible) == 1, "%s: exactly one left sprite" % tag)
		chk(int(lr.visible) + int(hr.visible) == 1, "%s: exactly one right sprite" % tag)
		# front layer must be cut from the art that is actually visible
		var fl = bf.get_node("StairFrontLeft")
		var vis_left = ll if ll.visible else hl
		chk(fl.texture == vis_left.texture, "%s: left front layer uses the visible art" % tag)
		var fr = bf.get_node("StairFrontRight")
		var vis_right = lr if lr.visible else hr
		chk(fr.texture == vis_right.texture, "%s: right front layer uses the visible art" % tag)
		bf.free()
		await get_tree().process_frame
	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)
