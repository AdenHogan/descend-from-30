extends Node

# NIGHT STORM ambience for an apartment (run 3 only). One per apartment, added by
# room.gd on live night runs. Two jobs:
#  1) a looping RAIN hiss under the whole flat, and
#  2) periodic LIGHTNING that flashes EVERY window light together (localised — the flash
#     comes THROUGH the glass, not a full-screen wash) with a THUNDER rumble a beat later
#     (you see the flash, then hear it). Driving it from ONE node keeps a bolt a single
#     coherent event instead of each window flickering on its own.
# Audio is the generated storm set in assets/audio/ambience (see tools/gen_storm_audio.py).

const RAIN_STREAM := preload("res://assets/audio/ambience/rain_loop.wav")
const THUNDER_STREAMS := [
	preload("res://assets/audio/ambience/thunder_1.wav"),
	preload("res://assets/audio/ambience/thunder_2.wav"),
]

const FLASH_INTERVAL_MIN := 7.0
const FLASH_INTERVAL_MAX := 18.0
const FLASH_ENERGY_ADD := 2.4       # how much brighter a window gets at the peak of a bolt

var _rain: AudioStreamPlayer = null
var _next_flash: float = 0.0


func _ready() -> void:
	add_to_group("apt_storm")
	# Steady rain hiss. The generated WAV is authored to loop seamlessly; force LOOP so a
	# short clip runs continuously while the player is in the flat.
	_rain = AudioStreamPlayer.new()
	var s := RAIN_STREAM
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_rain.stream = s
	_rain.volume_db = -14.0
	_rain.bus = "Master"
	add_child(_rain)
	_rain.play()
	_next_flash = randf_range(2.0, 6.0)   # first bolt soon after arriving


func _process(delta: float) -> void:
	_next_flash -= delta
	if _next_flash <= 0.0:
		_next_flash = randf_range(FLASH_INTERVAL_MIN, FLASH_INTERVAL_MAX)
		_strike()


func _strike() -> void:
	# Flash every window together (a real bolt lights all the glass at once), then the
	# thunder after a short, distance-flavoured delay.
	var lit := false
	for w in get_tree().get_nodes_in_group("apt_window_light"):
		if w is PointLight2D:
			_flash_window(w)
			lit = true
	# Thunder even if a flat somehow has no windows (still a storm outside), but only bother
	# scheduling it when we're actually in a scene.
	var delay := randf_range(0.35, 1.4)         # light before sound; bigger delay = farther
	var near := delay < 0.7                     # a close strike is louder + double-flashes
	if near and lit:
		# a quick second flicker for a close bolt
		get_tree().create_timer(0.09, false).timeout.connect(func():
			for w in get_tree().get_nodes_in_group("apt_window_light"):
				if w is PointLight2D:
					_flash_window(w))
	get_tree().create_timer(delay, false).timeout.connect(_boom.bind(near))


func _flash_window(w: PointLight2D) -> void:
	var base: float = w.get_meta("base_energy", w.energy)
	var t := create_tween()
	t.tween_property(w, "energy", base + FLASH_ENERGY_ADD, 0.05)
	t.tween_property(w, "energy", base, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _boom(near: bool) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = THUNDER_STREAMS.pick_random()
	p.volume_db = -4.0 if near else -12.0
	p.pitch_scale = randf_range(0.9, 1.08)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
