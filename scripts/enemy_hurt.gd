extends RefCounted

# THE HURT BLINK (owner: "attacked enemies, when hurt, blink white and don't attack"). A hit enemy
# flashes white for its hurt window. It is NOT immune while hurt — every hit still lands — but it
# can't attack, you can slip past it (like a pushed one), and the player's swing prefers an UNHURT
# enemy in reach, so a pack can be worked through one by one. Hitting a hurt enemy again and again
# costs a little accuracy (player._hurt_miss_chance, up to +10%).
# Shared by the standard family and the big zombie.

const FLASH_SHADER := """
shader_type canvas_item;
uniform float flash = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}
"""
const PERIOD := 0.12          # one white-on / off cycle
const FLASH := 0.85           # how white at the peak

static var _shader: Shader = null


static func blink(e: Node, duration: float) -> void:
	var spr = e.get("animated_sprite")
	if spr == null or not is_instance_valid(spr):
		return
	var mat: ShaderMaterial = e.get_meta("hurt_flash_mat") if e.has_meta("hurt_flash_mat") else null
	if mat == null:
		if _shader == null:
			_shader = Shader.new()
			_shader.code = FLASH_SHADER
		mat = ShaderMaterial.new()
		mat.shader = _shader
		e.set_meta("hurt_flash_mat", mat)
	if spr.material != null and spr.material != mat:
		return        # a stairwell slice owns the sprite (a hit pulls it off the stairs first)
	spr.material = mat
	if e.has_meta("hurt_flash_tween"):
		var old = e.get_meta("hurt_flash_tween")
		if old is Tween and old.is_valid():
			old.kill()
	var tw: Tween = e.create_tween()
	var n := maxi(1, int(ceil(duration / PERIOD)))
	for i in range(n):
		tw.tween_callback(func(): mat.set_shader_parameter("flash", FLASH))
		tw.tween_interval(PERIOD * 0.5)
		tw.tween_callback(func(): mat.set_shader_parameter("flash", 0.0))
		tw.tween_interval(PERIOD * 0.5)
	tw.tween_callback(func():
		if is_instance_valid(spr) and spr.material == mat:
			spr.material = null)
	e.set_meta("hurt_flash_tween", tw)


static func is_blinking(e: Node) -> bool:
	var spr = e.get("animated_sprite")
	return spr != null and e.has_meta("hurt_flash_mat") and spr.material == e.get_meta("hurt_flash_mat")
