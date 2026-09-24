class_name WeaponAffliction
extends Node

# What a SPECIAL weapon mod leaves on an enemy (docs/SCRAP_UPGRADES.md "Special mods"): a child
# node that burns or bleeds it on a timer, then frees itself. Works on every enemy rig (standard,
# crawler, long-arm, spitter, big/boss) through what they all share: current_hp, _die(), on_fire,
# burn_tick() and a `weapon_lit` flag that keeps a weapon-set fire from being put out by the floor's
# own fire bookkeeping (building_floors / room reset on_fire every frame from the fire field).

const NODE_NAME := "WeaponAffliction"
const BURN_SECONDS := 6.0          # a weapon-set fire burns this long (refreshed by another proc)
const BLEED_INTERVAL := 1.5
const BLEED_TICKS := 3             # a wound: 1 damage every 1.5 s, three times

var enemy: Node = null
var burn_left: float = 0.0
var bleed_ticks: int = 0
var _bleed_acc: float = 0.0


# The enemy's affliction node, created on first use.
static func on(target: Node) -> WeaponAffliction:
	if target == null or not is_instance_valid(target):
		return null
	var a = target.get_node_or_null(NODE_NAME)
	if a == null:
		a = WeaponAffliction.new()
		a.name = NODE_NAME
		a.enemy = target
		target.add_child(a)
	return a


static func can_afflict(target: Node) -> bool:
	if target == null or not is_instance_valid(target) or not ("current_hp" in target):
		return false
	if ("is_dead" in target) and target.is_dead:
		return false
	return not (("tutorial_scripted" in target) and target.tutorial_scripted)


static func ignite(target: Node) -> bool:
	if not can_afflict(target) or not ("on_fire" in target):
		return false
	var a := on(target)
	a.burn_left = BURN_SECONDS
	target.set("weapon_lit", true)
	target.on_fire = true
	return true


static func bleed(target: Node) -> bool:
	if not can_afflict(target):
		return false
	var a := on(target)
	a.bleed_ticks = BLEED_TICKS
	a._bleed_acc = 0.0
	return true


func _physics_process(delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy) or (("is_dead" in enemy) and enemy.is_dead):
		_end()
		return
	if burn_left > 0.0:
		burn_left -= delta
		if enemy.has_method("burn_tick"):
			enemy.burn_tick(delta)
		if burn_left <= 0.0:
			enemy.set("weapon_lit", false)
			enemy.on_fire = false
	if bleed_ticks > 0:
		_bleed_acc += delta
		if _bleed_acc >= BLEED_INTERVAL:
			_bleed_acc = 0.0
			bleed_ticks -= 1
			enemy.current_hp -= 1
			if enemy.current_hp <= 0 and enemy.has_method("_die"):
				enemy._die()
	if burn_left <= 0.0 and bleed_ticks <= 0:
		_end()


func _end() -> void:
	if enemy != null and is_instance_valid(enemy):
		enemy.set("weapon_lit", false)
	queue_free()
