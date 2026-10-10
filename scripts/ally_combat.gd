class_name AllyCombat
extends RefCounted

# HOW A SURVIVOR FIGHTS (owner: "they will do half damage of the player because obviously we still need the
# player to take initiative"). Everything is DERIVED from the player's own numbers — the weapon tables are read
# off player.gd, not copied — so a retune of the player's hammer retunes every survivor's hammer too, at half.
#
#   melee  — damage = FRACTION × the player's damage for that weapon type (knife 1 → 0.5, sword 1 → 0.5, bat 3 → 1.5),
#            at the player's own reach and swing rhythm. The fraction is carried between swings (`take_swing`) so a
#            knife lands 1 every second swing and a bat 1, 2, 1, 2 … — exactly half, no luck, nothing rounds away.
#   gun    — a hit does FRACTION × the player's body shot (2 → 1). It never headshots (an instant kill would be MORE
#            than the player's average) and the hit odds are the player's own body odds. Rounds are finite.
#   fists  — the player cannot hurt anything bare-handed, so neither can a survivor: an unarmed survivor hides.
#
# Zombies hit a survivor for their ordinary ATTACK_DAMAGE — the dead are no gentler with them than with you.

# (player.gd is loaded LAZILY: WorldState reaches this file through Quests → Survivor, and player.gd reaches WorldState —
# a preload here made a compile cycle that broke type inference in player.gd itself.)
static var _player_script: GDScript = null
const FRACTION := 0.5
const GUN_BODY_DAMAGE := 2            # what the player's body shot does to a zombie (enemy.receive_hit_from_gun "body")
const GUN_RANGE := 250.0              # player.GUN_RANGE_MID — a survivor's gun reaches no further than yours
const GUN_CLOSE := 120.0              # player.GUN_RANGE_CLOSE
const GUN_COOLDOWN := 0.65            # the player's shot rhythm (player._do_gun_attack)


## The weapon type of an item id, by the SAME name test the player uses (player._get_weapon_type): "knife" |
## "sword" | "bat" | "gun" — or "fists" for no weapon / not a weapon. A test pins this to the real function.
static func kind_of(item_id: String) -> String:
	if item_id == "":
		return "fists"
	var data: Dictionary = ItemData.get_item(item_id)
	if not data.get("is_weapon", false):
		return "fists"
	var n: String = str(data.get("name", "")).to_lower()
	if n.contains("knife") or n.contains("scalpel"):
		return "knife"
	if n.contains("sword") or n.contains("katana") or n.contains("machete"):
		return "sword"
	if n.contains("bat") or n.contains("club") or n.contains("wrench") or n.contains("hammer"):
		return "bat"
	if n.contains("gun") or n.contains("pistol") or n.contains("rifle") or n.contains("shotgun"):
		return "gun"
	return "fists"


static func player_script() -> GDScript:
	if _player_script == null:
		_player_script = load("res://scripts/player.gd")
	return _player_script


## The player's own swing / slice sounds (player.gd MELEE_THUNK / MELEE_SLICE).
static func melee_sounds(kind: String) -> Array:
	return player_script().MELEE_SLICE if kind in ["knife", "sword"] else player_script().MELEE_THUNK


static func is_melee(kind: String) -> bool:
	return kind in ["knife", "sword", "bat"]


## The damage type the zombie's own receive_damage reads (blade survives some killing blows, bludgeon knocks down).
static func damage_type(kind: String) -> String:
	match kind:
		"knife", "sword": return "blade"
		"bat": return "bludgeon"
		"gun": return "bullet"
	return "blunt"


## What the PLAYER does with this weapon type in one landed hit.
static func player_damage(kind: String) -> float:
	if kind == "gun":
		return float(GUN_BODY_DAMAGE)
	return float(player_script().WEAPON_DAMAGE.get(kind, 0))


## What a SURVIVOR does: half of that.
static func ally_damage(kind: String) -> float:
	return player_damage(kind) * FRACTION


static func reach(kind: String) -> float:
	if kind == "gun":
		return GUN_RANGE
	return float(player_script().WEAPON_RANGES.get(kind, 0.0))


static func cooldown(kind: String) -> float:
	if kind == "gun":
		return GUN_COOLDOWN
	return float(player_script().WEAPON_COOLDOWN.get(kind, 0.5))


## One swing's worth of damage out of a running `carry` (the fraction left over from earlier swings). Returns
## {"amount": whole points to deal now, "carry": what is left over}. Exactly half over time; deterministic.
static func take_swing(carry: float, kind: String) -> Dictionary:
	var total := carry + ally_damage(kind)
	var whole := int(floor(total + 0.0001))
	return {"amount": whole, "carry": total - float(whole)}


## Whether a gun shot at `distance` hits. Seeded by the caller's `roll` (0..1): the player's own BODY odds at that
## range with no headshots — so on average a survivor lands exactly what a player with no bonuses would, at half
## the damage.
static func gun_hits(distance: float, roll: float) -> bool:
	var body: float
	if distance <= GUN_CLOSE:
		body = 0.60
	elif distance <= GUN_RANGE:
		body = 0.52
	else:
		body = 0.23
	return roll < body
