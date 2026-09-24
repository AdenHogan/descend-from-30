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
	"B_adrenaline": {"name": "Adrenaline", "d": 4, "desc": "+20% move speed", "mods": {"move_speed": {"mult": 1.20}}},
	"B_second_wind": {"name": "Catch Your Breath", "d": 3, "desc": "+60% stamina regen", "mods": {"stamina_regen": {"mult": 1.60}}},
	"B_rage": {"name": "Rage", "d": 4, "desc": "+2 melee damage", "mods": {"melee_damage": {"add": 2}}},
	"B_steady": {"name": "Steady Nerves", "d": 3, "desc": "+12% headshot, +10% body-hit chance",
		"mods": {"headshot_bonus": {"add": 0.12}, "body_bonus": {"add": 0.10}}},
	"B_breath": {"name": "Holding Breath", "d": 3, "desc": "-40% movement noise", "mods": {"noise_mult": {"mult": 0.60}}},
	"B_eye": {"name": "Sharp Eye", "d": 3, "desc": "+15% scavenge find rate", "mods": {"scavenge_bonus": {"add": 0.15}}},
	"B_lungs": {"name": "Big Lungs", "d": 3, "desc": "+40 max stamina", "mods": {"max_stamina": {"add": 40}}},
	"B_light": {"name": "Light Feet", "d": 3, "desc": "-40% sprint stamina cost", "mods": {"sprint_drain": {"mult": 0.60}}},
	"B_brawler": {"name": "Brawler", "d": 3, "desc": "Pushes cost 40% less and shove 50% harder",
		"mods": {"push_cost": {"mult": 0.60}, "push_force": {"mult": 1.50}}},
	"B_senses": {"name": "Heightened Senses", "d": 2, "desc": "-40% listen time", "mods": {"listen_speed": {"mult": 0.60}}},
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
# THE DOOR (owner, round 4 — "a real hard choice"): an escaping character's KIT is scrapped at the
# door for Valour — every weapon's worth (DOOR_WORTH by level + a share of heirloom scrap put in) —
# UNLESS they leave one item by the door for their next game (the stash), which forfeits THAT
# item's worth and the brave bonus. So the price of keeping a weapon you built is exactly what it
# would have melted for.
const DOOR_BRAVE_BONUS := 25            # left nothing by the door — braved the unknown
# Only UPGRADED weapons count (owner, round 5: "we don't want any old junk scrappable for max valour
# at the door") — a Lv1 weapon, a tool or junk melts for nothing, and can't be left by the door.
const DOOR_WORTH := {1: 0, 2: 20, 3: 40, 4: 70, 5: 110, 6: 160, 7: 220}
const DOOR_FORGE_SHARE := 0.2           # heirloom scrap already put in counts this much toward worth
const VALOUR_DEPTH_CURVE := 60.0        # floors descended d → d + floor(d² / curve)
const OFFER_COUNT := 3                   # perks offered at the end of a session
const PERMANENT_CAP := 10                # permanent perks a profile can hold at once
const TRADE_REFUND := 0.5                # trading a permanent perk out refunds this share of its cost

# Cost by the merchant's rarity weight `w` (rarer = pricier), drawbacks cheaper, boons flat.
# SIZED (owner, round 4) so a coveted perk is a goal you work toward across games: a middling game
# (one escape, two deaths mid-building) earns ~100 Valour if you keep your best weapon by the door,
# ~200 if you scrap it — so the top perks (~450-550) take 5-6 games one way, 2-3 the other.
const COST_BY_WEIGHT := {7: 150, 6: 150, 5: 200, 4: 200, 3: 275, 2: 350, 1: 450}
const DRAWBACK_DISCOUNT := 100
const BOON_COST := 250
# Explicit prices where rarity lies about permanent value (+1 slot forever is the big prize).
const COST_OVERRIDE := {"U_slot": 550, "U_db_slotstam": 350, "U_fortune": 400}

# PERK LUCK (owner, round 6 — "a little meta: a perk that increases luck on encountering more
# desirable perks"). Every perk carries a DESIRABILITY `d` 1-5. With perk luck L (Fortune's Favour
# gives 1), every offer — the merchant's pair, a milestone's boons, the end-of-game Valour offer —
# weighs each perk by DESIRE_TILT ^ (L × (d − 3)): at L 1 a d5 perk is ~2.6× likelier, a d1 ~0.4×.
# At L 0 every draw is exactly what it was without it (the owner's "truly random" end offer
# included). The offer is still ONLY ever perks you selected this game — luck tilts, never adds.
const DESIRE_TILT := 1.6
const DESIRE_NEUTRAL := 3


# Valour one run earns: floors descended below 30 (their deepest), weighted toward depth, +bonus
# for escaping, + quests completed and NPCs aided. d=5 → 5, d=15 → 18, d=20 → 26, d=30 (lobby)
# → 45 (+10 escaped = 55); each quest +8, each NPC aided +4.
# `door` = what the character's kit was scrapped for at the lobby door (door_valour) — escapes only.
static func valour_for_run(deepest_floor: int, escaped: bool, quests: int = 0, npcs: int = 0,
		door: int = 0) -> int:
	var d := clampi(30 - deepest_floor, 0, 30)
	return d + int(floor(d * d / VALOUR_DEPTH_CURVE)) + (VALOUR_ESCAPE_BONUS if escaped else 0) \
		+ maxi(0, quests) * VALOUR_PER_QUEST + maxi(0, npcs) * VALOUR_PER_NPC \
		+ (maxi(0, door) if escaped else 0)


# What one item melts for at the lobby door: UPGRADED weapons by level (+ a share of heirloom scrap
# already put in); anything else — a Lv1 weapon, tools, junk — is worth nothing there.
static func door_worth(inst) -> int:
	if inst == null or not WeaponUpgrades.can_upgrade(inst.item_id) or inst.level < 2:
		return 0
	var lvl := clampi(inst.level, 1, WeaponUpgrades.MAX_LEVEL)
	return int(DOOR_WORTH.get(lvl, 0)) + int(floor(maxi(0, inst.forge_paid) * DOOR_FORGE_SHARE))


# The Valour a kit scraps for at the door. `stashed` = the index left by the door (-1 = none: every
# item melts AND — if there was an upgraded weapon to give up — the brave bonus is earned).
static func door_valour(items: Array, stashed: int = -1) -> int:
	var v := 0
	var any := false
	for i in items.size():
		var w := door_worth(items[i])
		any = any or w > 0
		if i != stashed:
			v += w
	return v + (DOOR_BRAVE_BONUS if stashed < 0 and any else 0)


# Everything about a perk that can become permanent: a merchant upgrade (U_*) or a run boon (B_*).
static func perk_info(id: String) -> Dictionary:
	if id.begins_with("B_"):
		var b := boon(id)
		if b.is_empty():
			return {}
		return {"name": b["name"], "desc": b["desc"], "mods": b["mods"], "kind": "boon", "cost": BOON_COST,
			"d": int(b.get("d", DESIRE_NEUTRAL))}
	var u: Dictionary = WorldState.UPGRADE_POOL.get(id, {})
	if u.is_empty():
		return {}
	var cost: int = int(COST_BY_WEIGHT.get(int(u.get("w", 3)), 55))
	if bool(u.get("drawback", false)):
		cost -= DRAWBACK_DISCOUNT
	cost = int(COST_OVERRIDE.get(id, cost))
	return {"name": u["name"], "desc": u["desc"], "mods": u["mods"], "kind": "upgrade", "cost": cost,
		"d": int(u.get("d", DESIRE_NEUTRAL)), "w": int(u.get("w", 3)), "drawback": bool(u.get("drawback", false))}


static func perk_cost(id: String) -> int:
	return int(perk_info(id).get("cost", 0))


static func trade_refund(id: String) -> int:
	return int(floor(perk_cost(id) * TRADE_REFUND))


static func boon(id: String) -> Dictionary:
	return RUN_BOONS.get(id, {})


# --- perk luck -------------------------------------------------------------------------------
static func desirability(id: String) -> int:
	return int(perk_info(id).get("d", DESIRE_NEUTRAL))


# How much likelier perk `id` is to turn up under perk luck `luck` (1.0 at luck 0).
static func desire_weight(id: String, luck: float) -> float:
	if luck <= 0.0:
		return 1.0
	return pow(DESIRE_TILT, luck * float(desirability(id) - DESIRE_NEUTRAL))


# Draw `count` distinct ids from `pool`, each with probability ∝ `base_weight(id) × desire_weight`.
# Deterministic for a given rng state. Never returns duplicates; returns fewer if the pool is short.
static func weighted_draw(rng: RandomNumberGenerator, pool: Array, count: int, luck: float,
		base_weight: Callable = Callable()) -> Array:
	var left: Array = pool.duplicate()
	var out: Array = []
	while out.size() < count and not left.is_empty():
		var weights: Array = []
		var total := 0.0
		for id in left:
			var w: float = (float(base_weight.call(id)) if base_weight.is_valid() else 1.0) * desire_weight(id, luck)
			w = maxf(w, 0.0001)
			weights.append(w)
			total += w
		var r := rng.randf() * total
		var pick := left.size() - 1
		for i in left.size():
			r -= float(weights[i])
			if r <= 0.0:
				pick = i
				break
		out.append(left.pop_at(pick))
	return out


# THE PERK TABLE (docs/PERKS.md) — generated from the live data so it can never drift: the
# owner edits `w` / `d` in the pools, runs tools/perk_table.tscn, and the doc follows.
# progression_test fails if the committed doc is out of date.
static func perk_table_markdown() -> String:
	var lines: PackedStringArray = []
	lines.append("# Perk list (generated — do not edit by hand)")
	lines.append("")
	lines.append("Regenerate with `godot --headless res://tools/perk_table.tscn` after changing a perk.")
	lines.append("Edit the data in `scripts/world_state.gd` `UPGRADE_POOL` (merchant upgrades) and")
	lines.append("`scripts/progression.gd` `RUN_BOONS` (run boons). Columns:")
	lines.append("")
	lines.append("- **Rarity `w`** — how often the merchant offers it (higher = more common; boons are drawn evenly).")
	lines.append("- **Desirability `d`** — 1-5, how much a player wants it (5 = coveted). Only matters under")
	lines.append("  perk luck (Fortune's Favour): offers tilt toward high-`d` perks (x%.1f per step from 3)." % DESIRE_TILT)
	lines.append("- **Keep forever** — its Descent Valour price to make it permanent.")
	lines.append("")
	lines.append("| Id | Perk | Kind | What it does | Rarity w | Desirability d | Keep forever |")
	lines.append("|---|---|---|---|---|---|---|")
	var ids: Array = WorldState.UPGRADE_POOL.keys()
	ids.append_array(RUN_BOONS.keys())
	for id in ids:
		var d: Dictionary = perk_info(id)
		var kind := "Run boon" if d.get("kind", "") == "boon" else ("Merchant (drawback)" if d.get("drawback", false) else "Merchant")
		var w := "—" if d.get("kind", "") == "boon" else str(d.get("w", ""))
		lines.append("| `%s` | %s | %s | %s | %s | %d | %d |" % [id, d.get("name", id), kind,
			String(d.get("desc", "")).replace("|", "/"), w, int(d.get("d", DESIRE_NEUTRAL)), int(d.get("cost", 0))])
	lines.append("")
	return "\n".join(lines)
