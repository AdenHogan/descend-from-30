extends Area2D

# The merchant squats in the jammed-open elevator on floors 25/20/15/10/5
# (docs/STORE_DESIGN.md). The scene renders its own elevator: two door
# sprites (left/right halves of Elevator.png) slide open when the player
# approaches, revealing the merchant inside. The static hallway Elevator
# sprite is hidden on merchant floors (see building_floors.gd).
# Merchant body reuses the player idle sheet as a stand-in — art task open.
# TODO(store step 6): first interaction each visit must lead with the
# upgrade pair BEFORE the shop opens — blocked on the upgrade pool design.

const GREETINGS = [
	"Got wares, if you've got notes, friend.",
	"The lady on 22 cleaned me out of bandages, heh.",
	"Don't ask how the elevator moves. Trade secret.",
	"Heh heh... always a pleasure, neighbour.",
	"Everything's for sale. Except the elevator.",
]

const DOOR_OPEN_DISTANCE = 150.0
const DOOR_TWEEN_TIME = 0.35
const DOOR_CLOSED_X = 15.75
const DOOR_OPEN_X = 29.0
const DOOR_CLOSED_SCALE_X = 0.95454395
const DOOR_OPEN_SCALE_X = 0.06
const IDLE_FPS = 8.0
const IDLE_FRAME_COUNT = 10

const DING_STREAM = preload("res://assets/audio/elevator_ding.wav")

var player_nearby: bool = false
var shop_ui: CanvasLayer = null
var doors_open: bool = false
var door_tween: Tween = null
var idle_timer: float = 0.0
var ding_player: AudioStreamPlayer2D = null

@onready var proximity_label: Label = $ProximityLabel
@onready var door_left: Sprite2D = $DoorLeft
@onready var door_right: Sprite2D = $DoorRight
@onready var merchant_sprite: Sprite2D = $MerchantSprite


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	proximity_label.visible = false
	ding_player = AudioStreamPlayer2D.new()
	ding_player.stream = DING_STREAM
	ding_player.volume_db = -8.0
	ding_player.max_distance = 600.0
	add_child(ding_player)


func get_greeting() -> String:
	# Legendary-hold flavour takes priority — the doc's "Been saving this one
	# for you" is the player-facing signal that the savings goal is stable.
	var stock = WorldState.get_merchant_stock(WorldState.current_floor)
	for entry in stock:
		if entry["band"] == "legendary" and not entry["sold"]:
			if int(WorldState.legendary_hold.get("visits_left", 0)) < WorldState.LEGENDARY_HOLD_VISITS:
				return "Been saving this one for you."
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "greeting" + str(WorldState.current_floor) + str(WorldState.current_run))
	return GREETINGS[rng.randi() % GREETINGS.size()]


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = true
		proximity_label.text = "[E] Talk to Merchant"
		proximity_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		proximity_label.visible = false
		if shop_ui != null and shop_ui.visible:
			shop_ui.close()


func _process(_delta: float) -> void:
	# The merchant sprite is a plain Sprite2D over the idle sheet; step its
	# frame here so he breathes instead of freezing on frame 0.
	idle_timer += _delta
	merchant_sprite.frame = int(idle_timer * IDLE_FPS) % IDLE_FRAME_COUNT
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		var near = global_position.distance_to(player.global_position) <= DOOR_OPEN_DISTANCE
		if near != doors_open:
			_set_doors_open(near)
	if player_nearby and Input.is_action_just_pressed("interact"):
		if shop_ui == null or not shop_ui.visible:
			_open_shop()


func _set_doors_open(open: bool) -> void:
	# Doors slide sideways while collapsing horizontally, so they read as
	# retracting into the frame's side pockets instead of overlapping the wall.
	doors_open = open
	ding_player.pitch_scale = 1.0 if open else 0.92
	ding_player.play()
	if door_tween != null:
		door_tween.kill()
	door_tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var x = DOOR_OPEN_X if open else DOOR_CLOSED_X
	var sx = DOOR_OPEN_SCALE_X if open else DOOR_CLOSED_SCALE_X
	door_tween.tween_property(door_left, "position:x", -x, DOOR_TWEEN_TIME)
	door_tween.tween_property(door_right, "position:x", x, DOOR_TWEEN_TIME)
	door_tween.tween_property(door_left, "scale:x", sx, DOOR_TWEEN_TIME)
	door_tween.tween_property(door_right, "scale:x", sx, DOOR_TWEEN_TIME)


func _open_shop() -> void:
	if shop_ui == null:
		shop_ui = preload("res://scenes/shop_ui.tscn").instantiate()
		add_child(shop_ui)
	shop_ui.open(WorldState.current_floor, get_greeting())
