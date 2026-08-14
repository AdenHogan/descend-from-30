extends Node2D

# A thin draw surface for the fire's depth layers (see fire_field.gd's render
# notes). It carries no state of its own — it just asks the parent FireField to
# draw the given layer onto it every frame, at whatever z / blend mode the field
# set when it spawned this node. This is how the fire renders BEHIND the player
# (back glow), level with them (main flames), IN FRONT (additive licks) and the
# smoke on top — a single node can only sit at one z, so each layer is its own.

var field                          # the FireField that owns this layer
var layer: int = 0                 # which of FireField's LYR_* to draw


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if field != null and is_instance_valid(field):
		field.draw_layer(self, layer)
