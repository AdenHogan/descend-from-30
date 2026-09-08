extends Node2D

# The Spitter's projectile: a blob of bile that flies horizontally toward the player,
# hits once for 1 damage, and despawns on contact or at the end of its range. Frames
# are sliced from the purchased SpittingZombie - Projectile sheet at runtime (6 frames
# of 64x64), so no extra .tres is needed. Kept deliberately simple — a straight-line
# horizontal shot on the spit's own plane.

const SHEET := preload("res://assets/Enemies/SpittingZombie/SpittingZombie/SpittingZombie - Projectile.png")
const FRAME := 64
const SPEED := 260.0
const MAX_DIST := 360.0
const HIT_RADIUS := 30.0

var _dir: float = 1.0
var _travelled: float = 0.0
var _hit: bool = false
var _sprite: AnimatedSprite2D = null
var _player: Node2D = null


func launch(dir: float) -> void:
	_dir = 1.0 if dir >= 0.0 else -1.0


func _ready() -> void:
	z_index = 1                     # actor layer, like the bodies
	_player = get_tree().get_first_node_in_group("player")
	_sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("fly")
	frames.set_animation_speed("fly", 12.0)
	frames.set_animation_loop("fly", true)
	var n: int = int(SHEET.get_width() / FRAME)
	for i in range(n):
		var at := AtlasTexture.new()
		at.atlas = SHEET
		at.region = Rect2(i * FRAME, 0, FRAME, FRAME)
		frames.add_frame("fly", at)
	_sprite.sprite_frames = frames
	_sprite.scale = Vector2(2, 2)
	_sprite.flip_h = _dir < 0.0
	add_child(_sprite)
	_sprite.play("fly")


func _physics_process(delta: float) -> void:
	if _hit:
		return
	var step: float = SPEED * delta
	position.x += _dir * step
	_travelled += step
	if _player != null and is_instance_valid(_player):
		if global_position.distance_to(_player.global_position) <= HIT_RADIUS:
			if _player.has_method("receive_hit"):
				_player.receive_hit(1)
			_hit = true
			queue_free()
			return
	if _travelled >= MAX_DIST:
		queue_free()
