class_name Progression
extends RefCounted

# PLAYER PROGRESSION beyond the merchant (docs/PROGRESSION.md). Three tiers, ONE stat fold
# (base × ∏mult + Σadd, never direct writes — WorldState._stat_mods_sources folds them all):
#
#   1. MERCHANT upgrades   — STORE_DESIGN.md (unchanged): pick 1 of 2 at merchant floors,
#                             kept across the whole three-run arc.
#   2. RUN BOONS (temporary) — this CHARACTER only. At depth milestones (between merchant floors)
#                             a pick 1 of 2 from a punchier pool; the time skip wipes them.
#   3. LEGACY (permanent)  — the PROFILE, forever. Each character earns Legacy by how deep they got
#                             (+ a bonus for escaping); spend it on ranked perks at the profile
#                             screen. Ranks stack across every run and every playthrough.
#   (+ per-weapon workbench perks — WeaponUpgrades, scrap.)
#
# Every number lives here. mods use the UPGRADE_POOL shape: stat → {"add": x} / {"mult": x}.

# --- Tier 2: run boons -------------------------------------------------------------------
# Offered on the FIRST arrival (this run) at each milestone floor — two floors above each merchant
# floor (25/20/15/10/5), so the descent alternates: a boon, then the merchant, then a boon…
const BOON_MILESTONES := [27, 22, 17, 12, 7]

const RUN_BOONS := {
	"B_adrenaline": {"name": "Adrenaline", "desc": "+20% move speed", "mods": {"move_speed": {"mult": 1.20}}},
	"B_second_wind": {"name": "Second Wind", "desc": "+60% stamina regen", "mods": {"stamina_regen": {"mult": 1.60}}},
	"B_rage": {"name": "Rage", "desc": "+2 melee damage", "mods": {"melee_damage": {"add": 2}}},
	"B_steady": {"name": "Steady Nerves", "desc": "+12% headshot, +10% body-hit chance",
		"mods": {"headshot_bonus": {"add": 0.12}, "body_bonus": {"add": 0.10}}},
	"B_breath": {"name": "Holding Breath", "desc": "-40% movement noise", "mods": {"noise_mult": {"mult": 0.60}}},
	"B_eye": {"name": "Sharp Eye", "desc": "+15% scavenge find rate", "mods": {"scavenge_bonus": {"add": 0.15}}},
	"B_lungs": {"name": "Big Lungs", "desc": "+40 max stamina", "mods": {"max_stamina": {"add": 40}}},
	"B_light": {"name": "Light Feet", "desc": "-40% sprint stamina cost", "mods": {"sprint_drain": {"mult": 0.60}}},
	"B_brawler": {"name": "Brawler", "desc": "Pushes cost 40% less and shove 50% harder",
		"mods": {"push_cost": {"mult": 0.60}, "push_force": {"mult": 1.50}}},
	"B_senses": {"name": "Heightened Senses", "desc": "-40% listen time", "mods": {"listen_speed": {"mult": 0.60}}},
}

# --- Tier 3: legacy ----------------------------------------------------------------------
# Earned when a character's story ends: 1 per floor descended below 30 (their deepest), +10 if
# they walked out of the lobby.
const LEGACY_PER_FLOOR := 1
const LEGACY_ESCAPE_BONUS := 10

# Each perk: per-RANK mods (applied rank times: add × rank, mult ^ rank) and the cost of each
# next rank (its length is the max rank).
const LEGACY_PERKS := {
	"L_conditioning": {"name": "Conditioning", "desc": "+8 max stamina per rank",
		"mods": {"max_stamina": {"add": 8}}, "costs": [15, 25, 40, 60, 85]},
	"L_recovery": {"name": "Recovery", "desc": "+8% stamina regen per rank",
		"mods": {"stamina_regen": {"mult": 1.08}}, "costs": [20, 35, 55]},
	"L_tread": {"name": "Light Tread", "desc": "-6% movement noise per rank",
		"mods": {"noise_mult": {"mult": 0.94}}, "costs": [15, 25, 40]},
	"L_eye": {"name": "Knows Where To Look", "desc": "+3% scavenge find rate per rank",
		"mods": {"scavenge_bonus": {"add": 0.03}}, "costs": [20, 35, 55]},
	"L_range": {"name": "Range Practice", "desc": "+4% body-hit chance per rank",
		"mods": {"body_bonus": {"add": 0.04}}, "costs": [20, 35, 55]},
	"L_muscle": {"name": "Muscle Memory", "desc": "+1 melee damage",
		"mods": {"melee_damage": {"add": 1}}, "costs": [90]},
}


static func boon(id: String) -> Dictionary:
	return RUN_BOONS.get(id, {})


static func legacy_perk(id: String) -> Dictionary:
	return LEGACY_PERKS.get(id, {})


static func legacy_max_rank(id: String) -> int:
	return legacy_perk(id).get("costs", []).size()


# Cost of the NEXT rank (-1 when maxed / unknown).
static func legacy_next_cost(id: String, rank: int) -> int:
	var costs: Array = legacy_perk(id).get("costs", [])
	return int(costs[rank]) if rank < costs.size() else -1


# A perk's mods at `rank` (add × rank, mult ^ rank) — one fold source.
static func legacy_mods_at(id: String, rank: int) -> Dictionary:
	var out := {}
	if rank <= 0:
		return out
	var mods: Dictionary = legacy_perk(id).get("mods", {})
	for stat in mods:
		var m: Dictionary = mods[stat]
		var scaled := {}
		if m.has("add"):
			scaled["add"] = float(m["add"]) * rank
		if m.has("mult"):
			scaled["mult"] = pow(float(m["mult"]), rank)
		out[stat] = scaled
	return out


# Legacy a character earns when their story ends.
static func legacy_for_run(deepest_floor: int, escaped: bool) -> int:
	var floors := maxi(0, 30 - deepest_floor)
	return floors * LEGACY_PER_FLOOR + (LEGACY_ESCAPE_BONUS if escaped else 0)
