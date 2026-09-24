class_name Salvage
extends RefCounted

# BREAKING ITEMS DOWN FOR SCRAP (docs/SCRAP_UPGRADES.md, "Salvage") — ONLY at a maintenance-room
# workbench (owner: inventory must not be in-and-out easily, or the small pockets lose their
# tension). Without help it pays RUBBISH scrap (YIELD_BASE); the "Tinkerer" merchant upgrade
# (offered at the every-five-floors merchant pick) raises the yield. BASE is the value at FULL
# yield. Every number lives here.
#
#   value = (BASE[id] × wear × (0.7 if a damaged gun) × stack count  + 40% of any workbench
#            scrap the weapon had sunk into it) × yield,  rounded, at least 1.
#   yield = YIELD_BASE × WorldState salvage_yield fold (Tinkerer ×2.5 → full).
#   wear  = 0.4 + 0.6 × (durability left / max)  — a broken item still gives 40%.
# Not salvageable (value 0): healing items, clothes/rope, ammo, keys, money, the Scrap Bag.

const BASE := {
	# Junk (common) — cheap, but finally worth picking up.
	"023": 3,   # Broken Glass
	"024": 3,   # Empty Bottle
	"025": 2,   # Old Magazine
	"026": 2,   # Takeaway Boxes
	"027": 2,   # Dead Plant
	"028": 6,   # Broken Remote — circuit board, screws
	"029": 2,   # Pile of Paperwork
	"030": 3,   # Old Shoes — eyelets, rubber
	"031": 4,   # Empty Wallet — zip, clasp
	"032": 6,   # Broken Umbrella — steel ribs
	# Weapons
	"001": 10,  # Knife
	"002": 14,  # Hammer
	"003": 20,  # Sword
	"004": 25,  # Gun
	"012": 12,  # Golf Club
	"013": 8,   # Cricket Bat (wood)
	"014": 8,   # Baseball Bat (wood)
	"017": 16,  # Aluminium Baseball Bat
	# Tools & bits
	"005": 2,   # Canned Food (the tin)
	"015": 8,   # Flashlight
	"019": 16,  # Toolbox
	"020": 4,   # Fuse
	"021": 3,   # Battery
	"034": 6,   # Screwdriver
	"035": 14,  # Crowbar
	"036": 12,  # Fire Extinguisher
}

const YIELD_BASE := 0.4            # rubbish scrap without the Tinkerer upgrade
const WORN_FLOOR := 0.4             # what a broken / fully worn item is still worth
const DAMAGED_GUN := 0.7
const INVESTED_REFUND := 0.4        # share of workbench scrap an upgraded weapon gives back


static func can_salvage(inst) -> bool:
	return inst != null and BASE.has(inst.item_id)


static func value_of(inst) -> int:
	if not can_salvage(inst):
		return 0
	var v: float = float(BASE[inst.item_id])
	var max_d: int = inst.get_max_durability()
	if max_d > 0 and not inst.get_data().get("single_use", false):
		var left: float = 0.0 if inst.is_depleted else clampf(float(inst.current_durability) / max_d, 0.0, 1.0)
		v *= WORN_FLOOR + (1.0 - WORN_FLOOR) * left
	if inst.is_damaged:
		v *= DAMAGED_GUN
	v *= maxi(1, inst.count)
	var invested := 0
	for lvl in range(2, inst.level + 1):
		invested += int(WeaponUpgrades.step_cost(lvl).get("scrap", 0))
	v += invested * INVESTED_REFUND
	return maxi(1, int(round(v * yield_mult())))


# How well this character strips things down: YIELD_BASE, lifted by upgrades (Tinkerer).
static func yield_mult() -> float:
	return YIELD_BASE * WorldState.get_salvage_yield_mult()


# Worth confirming first (a second press) — anything that isn't plain junk.
static func needs_confirm(inst) -> bool:
	return inst != null and not inst.get_data().get("is_junk", false)
