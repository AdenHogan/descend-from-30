class_name Salvage
extends RefCounted

# BREAKING ITEMS DOWN FOR SCRAP (docs/SCRAP_UPGRADES.md, "Salvage") — ONLY at a maintenance-room
# workbench (owner: inventory must not be in-and-out easily, or the small pockets lose their
# tension). Without help it pays most of BASE (YIELD_BASE); the "Tinkerer" merchant upgrade
# (offered at the merchant's pick of three) lifts the yield above BASE. BASE is the value of a
# whole, unworn item at yield 1.0. Every number lives here. (Owner round 49f: "it's almost not
# worth breaking things down here because the rates are so low" - a screenshot had a gun at +10,
# a crowbar +6 and a worn hammer +2; the yield and the table were raised.)
#
#   value = BASE[id] × wear × (0.7 if a damaged gun) × stack count × yield  + 40% of any workbench
#           scrap the weapon had sunk into it (flat - not scaled by the yield),  rounded, at least 1.
#   yield = YIELD_BASE × WorldState salvage_yield fold (Tinkerer ×1.6).
#   wear  = 0.5 + 0.5 × (durability left / max)  — a broken item still gives half.
# Not salvageable (value 0): healing items, clothes/rope, ammo, keys, money, the Scrap Bag.

const BASE := {
	# Junk (common) — cheap, but finally worth picking up.
	"023": 3,   # Broken Bottle
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
	"001": 12,  # Knife
	"002": 18,  # Hammer
	"003": 26,  # Sword
	"004": 32,  # Gun
	"012": 14,  # Golf Club
	"013": 10,  # Cricket Bat (wood)
	"014": 10,  # Baseball Bat (wood)
	"017": 20,  # Aluminium Baseball Bat
	# Tools & bits
	"005": 2,   # Canned Food (the tin)
	"015": 10,  # Flashlight
	"019": 20,  # Toolbox
	"020": 5,   # Fuse
	"021": 4,   # Battery
	"034": 8,   # Screwdriver
	"035": 18,  # Crowbar
	"036": 14,  # Fire Extinguisher
}

const YIELD_BASE := 0.75           # of BASE without the Tinkerer upgrade (a Tinkerer lifts it to 1.2)
const WORN_FLOOR := 0.5             # what a broken / fully worn item is still worth
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
	# The scrap the player sank into an upgraded weapon comes back at a flat share - it is THEIR scrap, so how well they strip
	# things down (the yield) does not touch it (it used to be multiplied by the yield too: 40% of 40% = 16% back).
	var refund: float = WeaponUpgrades.scrap_sunk(inst) * INVESTED_REFUND     # levels, heirloom tiers, instalments
	return maxi(1, int(round(v * yield_mult() + refund)))


# How well this character strips things down: YIELD_BASE, lifted by upgrades (Tinkerer).
static func yield_mult() -> float:
	return YIELD_BASE * WorldState.get_salvage_yield_mult()


# Worth confirming first (a second press) — anything that isn't plain junk.
static func needs_confirm(inst) -> bool:
	return inst != null and not inst.get_data().get("is_junk", false)
