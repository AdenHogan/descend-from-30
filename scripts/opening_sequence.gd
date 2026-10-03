extends CanvasLayer

# THE OPENING ON A LOAD (owner round 35b — "a player loading a file might be on a run 2 or 3 save file"): choosing Continue plays the
# exterior shot (scripts/opening_exterior.gd) in the SAVE's own run — its light, its damage, this playthrough's burning floors — with the
# title, then hands back to the caller (Game.continue_game) under black to load the saved scene. A key hurries it. It owns the shot
# the way intro_overlay does on a run's start: it ticks it, and says `finished` once the picture has faded to black. It draws on layer 6
# (under Transition's black, which the caller lifts once this is up).
signal finished

var ext: Control = null
var _said := false


static func available() -> bool:
	return preload("res://scripts/opening_exterior.gd").art_present(clampi(WorldState.current_run, 1, 3))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 6
	var e: Control = preload("res://scripts/opening_exterior.gd").new()
	e.own_input = true
	add_child(e)
	if e.load_ok:
		ext = e
	else:
		e.queue_free()
		_finish.call_deferred()


func _process(delta: float) -> void:
	if ext == null or not is_instance_valid(ext):
		return
	if Transition.busy:                       # the black the caller covered with is still lifting
		return
	ext.tick(delta)
	if ext.done:
		_finish()


func _finish() -> void:
	if _said:
		return
	_said = true
	finished.emit()
