class_name Progression
extends RefCounted

# PLAYER PROGRESSION beyond the merchant (docs/PROGRESSION.md). Three tiers, ONE stat fold
# (base × ∏mult + Σadd, never direct writes — WorldState._stat_mods_sources folds them all):
#
#   1. MERCHANT upgrades   — STORE_DESIGN.md (unchanged): pick 1 of 2 at merchant floors,
#                             kept across the whole three-run arc.
#   2. RUN BOONS (temporary) — this CHARACTER only. At depth milestones (between merchant floors)
#                             a pick 1 of 2 from a punchier pool; the time skip wipes them.
#   3. DESCENT VALOUR (permanent) — the PROFILE, forever. At the end of a 3-run session, Valour
#                             (by how deep each run got) buys ONE of the perks acquired that
#                             session to keep for every future game (max 10, tradeable).
#   (+ per-weapon workbench perks — WeaponUpgrades, scrap.)
#
# Every number lives here. mods use the UPGRADE_POOL shape: stat → {"add": x} / {"mult": x}.

# --- Tier 2: run boons -------------------------------------------------------------------
# Offered on the FIRST arrival (this run) at each milestone floor — two floors above each merchant
# floor (25/20/15/10/5), so the descent alternates: a boon, then the merchant, then a boon…
const BOON_MILESTONES := [27, 22, 17, 12, 7]

const RUN_BOONS := {
	"B_adrenaline": {"name": "Adrenaline", "desc": "+20% move speed", "mods": {"move_speed": {"mult": 1.20}}},
	"B_second_wind": {"name": "Catch Your Breath", "desc": "+60% stamina regen", "mods": {"stamina_regen": {"mult": 1.60}}},
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

# --- Tier 3: DESCENT VALOUR (permanent) --------------------------------------------------
# The owner's design: when the THIRD character's story ends (escape or death), the session is
# scored. Each run earns Valour by how deep that character got — deeper floors are worth more
# (quadratic), and walking out adds a bonus. Valour is banked to the PROFILE (it can be saved
# for a later session). Then up to OFFER_COUNT perks the player ACQUIRED this session (merchant
# upgrades + run boons, from any of the three runs) are offered — picked uniformly at random,
# NO weighting — and ONE may be bought to keep forever. A permanent perk applies to every run of
# every new game in that save slot and is removed from the temporary pools (merchant + boons).
const VALOUR_ESCAPE_BONUS := 10
const VALOUR_PER_QUEST := 8             # each quest completed that run (owner: quests + NPCs count)
const VALOUR_PER_NPC := 4               # each NPC aided that run
const VALOUR_DEPTH_CURVE := 60.0        # floors descended d → d + floor(d² / curve)
const OFFER_COUNT := 3                   # perks offered at the end of a session
const PERMANENT_CAP := 10                # permanent perks a profile can hold at once
const TRADE_REFUND := 0.5                # trading a permanent perk out refunds this share of its cost

# Cost by the merchant's rarity weight `w` (rarer = pricier), drawbacks cheaper, boons flat.
const COST_BY_WEIGHT := {7: 30, 6: 30, 5: 40, 4: 40, 3: 55, 2: 70, 1: 90}
const DRAWBACK_DISCOUNT := 20
const BOON_COST := 60
# Explicit prices where rarity lies about permanent value (+1 slot forever is the big prize).
const COST_OVERRIDE := {"U_slot": 110, "U_db_slotstam": 70}


# Valour one run earns: floors descended below 30 (their deepest), weighted toward depth, +bonus
# for escaping, + quests completed and NPCs aided. d=5 → 5, d=15 → 18, d=20 → 26, d=30 (lobby)
# → 45 (+10 escaped = 55); each quest +8, each NPC aided +4.
static func valour_for_run(deepest_floor: int, escaped: bool, quests: int = 0, npcs: int = 0) -> int:
	var d := clampi(30 - deepest_floor, 0, 30)
	return d + int(floor(d * d / VALOUR_DEPTH_CURVE)) + (VALOUR_ESCAPE_BONUS if escaped else 0) \
		+ maxi(0, quests) * VALOUR_PER_QUEST + maxi(0, npcs) * VALOUR_PER_NPC


# Everything about a perk that can become permanent: a merchant upgrade (U_*) or a run boon (B_*).
static func perk_info(id: String) -> Dictionary:
	if id.begins_with("B_"):
		var b := boon(id)
		if b.is_empty():
			return {}
		return {"name": b["name"], "desc": b["desc"], "mods": b["mods"], "kind": "boon", "cost": BOON_COST}
	var u: Dictionary = WorldState.UPGRADE_POOL.get(id, {})
	if u.is_empty():
		return {}
	var cost: int = int(COST_BY_WEIGHT.get(int(u.get("w", 3)), 55))
	if bool(u.get("drawback", false)):
		cost -= DRAWBACK_DISCOUNT
	cost = int(COST_OVERRIDE.get(id, cost))
	return {"name": u["name"], "desc": u["desc"], "mods": u["mods"], "kind": "upgrade", "cost": cost}


static func perk_cost(id: String) -> int:
	return int(perk_info(id).get("cost", 0))


static func trade_refund(id: String) -> int:
	return int(floor(perk_cost(id) * TRADE_REFUND))


static func boon(id: String) -> Dictionary:
	return RUN_BOONS.get(id, {})
