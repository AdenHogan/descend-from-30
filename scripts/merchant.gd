extends Area2D

# The merchant squats in the jammed-open elevator on floors 25/20/15/10/5
# (docs/STORE_DESIGN.md). Placeholder visuals until art lands.
# TODO(store step 6): first interaction each visit must lead with the
# upgrade pair BEFORE the shop opens — blocked on the upgrade pool design.

const GREETINGS = [
	"Got wares, if you've got notes, friend.",
	"The lady on 22 cleaned me out of bandages, heh.",
	"Don't ask how the elevator moves. Trade secret.",
	"Heh heh... always a pleasure, neighbour.",
	"Everything's for sale. Except the elevator.",
]

var player_nearby: bool = false
var shop_ui: CanvasLayer = null

@onready var proximity_label: Label = $ProximityLabel


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	proximity_label.visible = false


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
	if not player_nearby:
		return
	if Input.is_action_just_pressed("interact"):
		if shop_ui == null or not shop_ui.visible:
			_open_shop()


func _open_shop() -> void:
	if shop_ui == null:
		shop_ui = preload("res://scenes/shop_ui.tscn").instantiate()
		add_child(shop_ui)
	shop_ui.open(WorldState.current_floor, get_greeting())


func _draw() -> void:
	# Placeholder merchant: a hooded figure sketched in primitives, sized to
	# stand alongside the 3x-scaled character sprites. Replace with real art.
	var coat = Color(0.28, 0.32, 0.24, 1.0)
	var hood = Color(0.2, 0.23, 0.17, 1.0)
	var skin = Color(0.75, 0.62, 0.5, 1.0)
	draw_rect(Rect2(-16, -18, 32, 62), coat)
	draw_circle(Vector2(0, -30), 13.0, hood)
	draw_circle(Vector2(0, -27), 8.0, skin)
	draw_rect(Rect2(-20, -14, 8, 34), coat)
	draw_rect(Rect2(12, -14, 8, 34), coat)
