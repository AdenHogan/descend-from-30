extends Resource
class_name ItemInstance

var item_id: String = ""
var current_durability: int = 0
var is_depleted: bool = false
var target_apartment: String = ""  # Only used for is_key items — "Key — Apt XXXX"
var count: int = 1  # Only used for stackable items (Bank Notes, Bullets)
# Guns: loaded rounds + damage state (forcing doors with a gun damages it —
# worse accuracy, smaller magazine — until repaired with a toolbox).
var mag_count: int = 0
var is_damaged: bool = false
# Guns WEAR (owner): one durability mark is knocked off every GUN_SHOTS_PER_MARK rounds fired.
var shots_since_mark: int = 0
# Workbench upgrades (docs/SCRAP_UPGRADES.md): the weapon's level (1-4) and the perks picked on the
# way up. They ride THIS weapon (serialized with it, kept as it levels) and apply through the
# modifier fold below — never by writing stats directly. Rules/perks: WeaponUpgrades.
var level: int = 1
var perks: Array = []
# Tuning (docs/SCRAP_UPGRADES.md "Tuning"): the points the player put into this weapon's own stat
# sheet — {stat id: ranks}. WeaponUpgrades.STATS says what each rank does.
var tuning: Dictionary = {}
# Legendary (Lv4+): its TITLE ("Widowmaker" — generated, renamable) and who forged it.
var title: String = ""
var forged_by: String = ""          # "<character id>:<run>" when it became legendary
# Heirloom (Lv5-7): times it crossed the lobby door into a later game, and scrap already paid
# toward its next heirloom tier (instalments ride the weapon).
var crossings: int = 0
var forge_paid: int = 0

const MAG_CAP = 18          # Met-issue Glock: 17+1
const MAG_CAP_DAMAGED = 10
const GUN_SHOTS_PER_MARK = 6   # rounds fired per durability mark (Durable Hand Cannon doubles it)


func shots_per_mark() -> int:
	return maxi(1, int(round(GUN_SHOTS_PER_MARK * perk_mult("shots_per_mark"))))


# A round was fired from this gun: count it, and every shots_per_mark() knock a durability mark
# off. Returns true when a mark was knocked (the gun may now be worn out — is_depleted).
func register_shot() -> bool:
	if get_max_durability() <= 0 or is_depleted:
		return false
	shots_since_mark += 1
	if shots_since_mark < shots_per_mark():
		return false
	shots_since_mark = 0
	current_durability -= 1
	if current_durability <= 0:
		current_durability = 0
		is_depleted = true
	return true


func get_mag_cap() -> int:
	var base = MAG_CAP_DAMAGED if is_damaged else MAG_CAP
	return base + WorldState.get_gun_mag_bonus() + int(perk_add("mag"))


# --- the per-weapon modifier fold (base × ∏mult + Σadd) -----------------------------
# Two sources: the perks picked on the way up (each a flat add / a multiplier) and the tuning
# ranks (each rank adds `add`, or moves the multiplier by `mult` — ×(1 + ranks × mult)).
func perk_add(stat: String) -> float:
	var total := 0.0
	for p in perks:
		total += float(WeaponUpgrades.perk(p).get("mods", {}).get(stat, {}).get("add", 0.0))
	for id in tuning:
		total += int(tuning[id]) * float(WeaponUpgrades.stat(id).get("mods", {}).get(stat, {}).get("add", 0.0))
	return total


func perk_mult(stat: String) -> float:
	var total := 1.0
	for p in perks:
		total *= float(WeaponUpgrades.perk(p).get("mods", {}).get(stat, {}).get("mult", 1.0))
	for id in tuning:
		var step := float(WeaponUpgrades.stat(id).get("mods", {}).get(stat, {}).get("mult", 0.0))
		if step != 0.0:
			total *= maxf(0.1, 1.0 + int(tuning[id]) * step)
	return total


func has_perk_flag(flag: String) -> bool:
	for p in perks:
		if flag in WeaponUpgrades.perk(p).get("flags", []):
			return true
	return false


# This weapon's durability ceiling: the item's base × its perks (Reinforced Handle doubles it).
func get_max_durability() -> int:
	var base := int(get_data().get("max_durability", -1))
	if base <= 0:
		return base
	return int(round(base * perk_mult("durability")))


func setup(id: String) -> void:
	item_id = id
	var data = ItemData.items.get(id, {})
	if data.is_empty():
		push_error("Item ID not found: " + id)
		return
	if data["single_use"]:
		current_durability = 1
	elif data["max_durability"] > 0:
		current_durability = data["max_durability"]
	else:
		current_durability = -1  # ammo-dependent or battery-dependent


func setup_key(id: String, apartment_id: String) -> void:
	setup(id)
	target_apartment = apartment_id


func get_display_name() -> String:
	var data = get_data()
	if data.get("is_key", false) and target_apartment != "":
		return "Key — Apt " + target_apartment
	if title != "":
		return '%s "%s"' % [data.get("name", "Unknown"), title]
	return data.get("name", "Unknown")


# The level as a player reads it: "", "Lv2", "Lv3", "Legendary", "Legendary +" … "+++".
func tier_label() -> String:
	return "" if level <= 1 else WeaponUpgrades.tier_name(level)


# Short form for the HUD slot tag: "Lv2", "Lv3", "LEG", "LEG+" … "LEG+++".
func tier_tag() -> String:
	if level <= 1:
		return ""
	if level < WeaponUpgrades.LEGENDARY_LEVEL:
		return "Lv%d" % level
	return "LEG" + "+".repeat(level - WeaponUpgrades.LEGENDARY_LEVEL)


func get_data() -> Dictionary:
	return ItemData.items.get(item_id, {})


func use() -> bool:
	if is_depleted:
		return false
	if current_durability == -1:
		return true  # gun/flashlight, handled externally
	current_durability -= 1
	if current_durability <= 0:
		is_depleted = true
	return true


func is_repairable() -> bool:
	# A damaged gun, or a broken (depleted) durability weapon/tool.
	var d = get_data()
	if is_damaged:
		return true
	if is_depleted and int(d.get("max_durability", -1)) > 0 \
			and (d.get("is_weapon", false) or d.get("is_tool", false)):
		return true
	return false


func repair_full() -> void:
	# Toolbox restore: un-break, un-damage, refill durability.
	is_damaged = false
	shots_since_mark = 0
	var max_d = get_max_durability()
	if max_d > 0:
		current_durability = max_d
		is_depleted = false


func repair(amount: int) -> void:
	var data = get_data()
	if data.get("single_use", false):
		return
	var max_d = get_max_durability()
	if max_d <= 0:
		return
	current_durability = min(current_durability + amount, max_d)
	is_depleted = false


func get_item_name() -> String:
	return get_display_name()
