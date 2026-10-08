extends Area2D

# An invisible tripwire on the walking lane that fires ONE story beat when the player walks into it (owner round 37: Alex's neighbour on
# floor 29 — `CharacterStory.on_alex_body`). Placed by corridor_decals beside the scripted body; frees itself once it has fired. The beat
# itself guards "only in the right character's run, only once" so a re-entered floor just re-arms a harmless trigger.

var story: String = ""
var half_width: float = 150.0


func _ready() -> void:
	add_to_group("story_trigger")
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(half_width * 2.0, 90.0)
	cs.shape = shape
	cs.position = Vector2(0, -30)
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	match story:
		"alex_body":
			CharacterStory.on_alex_body()
	if CharacterStory.flag("alex_body") or story == "":
		queue_free()
