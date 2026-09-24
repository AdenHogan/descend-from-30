class_name WeaponUpgrades
extends RefCounted

# THE WORKBENCH'S RULES (docs/SCRAP_UPGRADES.md) — one data table, edited in one place.
#
# Each supported weapon has a static tree: at every level (2, 3, 4) the player PICKS ONE of two
# perks. A weapon KEEPS every perk it has as it levels (they accumulate up the tiers). Perks are
# per-ITEM-INSTANCE (they ride the weapon, like durability) and apply through the modifier fold
# (base × ∏mult + Σadd — never direct writes): ItemInstance.perk_add / perk_mult / has_perk_flag.
#
# Cost of each step = scrap + (from Lv3) a spare copy of the SAME weapon as feed material:
#   Lv1 → Lv2: 50 scrap
#   Lv2 → Lv3: a spare Lv1 + 80 scrap
#   Lv3 → Lv4: a spare Lv2 + 100 scrap          (the doc's worked example)
# The weapon being upgraded is the TARGET (keeps its perks); the feed is consumed.

const MAX_LEVEL := 4

const STEP_COST := {
	2: {"scrap": 50, "feed_level": 0},     # feed_level 0 = no spare needed
	3: {"scrap": 80, "feed_level": 1},
	4: {"scrap": 100, "feed_level": 2},
}

# Item id → {level: [perk A, perk B]}. Gun + Hammer first (owner's call); add a weapon by adding
# a tree here.
const TREES := {
	"004": {   # Gun
		2: ["G_aim", "G_durable"],
		3: ["G_silencer", "G_pierce"],
		4: ["G_lucky", "G_bang"],
	},
	"002": {   # Hammer — PLACEHOLDER perks: the doc leaves the hammer tree to the owner. Rename /
		# rebalance freely in PERKS below; the ids only need to stay unique.
		2: ["H_heavy", "H_reinforced"],
		3: ["H_doorbreaker", "H_sweep"],
		4: ["H_skull", "H_feather"],
	},
}

# mods: stat → {"add": x} and/or {"mult": x}; flags: qualitative behaviours read by the combat code.
const PERKS := {
	# --- Gun (the doc's tree) ---
	"G_aim": {"name": "Aim Assist", "desc": "Steadier aim: +10% headshot and +10% body-hit chance.",
		"mods": {"headshot": {"add": 0.10}, "body": {"add": 0.10}}},
	# The doc's "doubles durability" — a gun has no durability (it runs on ammo, and forcing a door
	# DAMAGES it instead), so its toughness perk makes it immune to that damage + a bigger magazine.
	"G_durable": {"name": "Durable Hand Cannon", "desc": "Forcing a door never damages it, and it holds 6 more rounds.",
		"mods": {"mag": {"add": 6}}, "flags": ["no_force_damage"]},
	"G_silencer": {"name": "Silencer", "desc": "Shots are barely louder than footsteps — they no longer rouse the floor.",
		"flags": ["silenced"]},
	"G_pierce": {"name": "Through-and-Through", "desc": "A shot that lands also hits the enemy behind the target.",
		"flags": ["pierce"]},
	"G_lucky": {"name": "Lucky Bullet", "desc": "30% chance a shot doesn't use up a round.",
		"mods": {"free_shot": {"add": 0.30}}},
	"G_bang": {"name": "Bigger Bang", "desc": "Volatile rounds: a hit also blasts every enemy close to the target.",
		"flags": ["blast"]},
	# --- Hammer (PLACEHOLDER — owner to define) ---
	"H_heavy": {"name": "Heavy Head", "desc": "+1 damage with every blow.",
		"mods": {"damage": {"add": 1}}},
	"H_reinforced": {"name": "Reinforced Handle", "desc": "Twice the durability.",
		"mods": {"durability": {"mult": 2.0}}},
	"H_doorbreaker": {"name": "Door Breaker", "desc": "Forcing locks and tearing down barricades costs it no durability.",
		"flags": ["free_force"]},
	"H_sweep": {"name": "Sweeping Blow", "desc": "A swing also strikes a second enemy in reach.",
		"flags": ["sweep"]},
	"H_skull": {"name": "Skull Splitter", "desc": "15% chance a blow drops an ordinary enemy outright.",
		"mods": {"execute": {"add": 0.15}}},
	"H_feather": {"name": "Featherweight", "desc": "Swings cost 40% less stamina.",
		"mods": {"stamina": {"mult": 0.6}}},
}


static func has_tree(item_id: String) -> bool:
	return TREES.has(item_id)


static func perk(id: String) -> Dictionary:
	return PERKS.get(id, {})


# The two perks offered for this weapon's NEXT level ([] at max level / no tree).
static func next_choices(inst) -> Array:
	if inst == null or not has_tree(inst.item_id) or inst.level >= MAX_LEVEL:
		return []
	return TREES[inst.item_id].get(inst.level + 1, [])


static func step_cost(to_level: int) -> Dictionary:
	return STEP_COST.get(to_level, {})


# Index (in `inventory`) of the spare copy that would be consumed as feed for `inst`'s next step,
# or -1. The lowest-level qualifying copy is used, so a better spare is never burnt by accident.
static func find_feed(inst, inventory: Array) -> int:
	var cost := step_cost(inst.level + 1)
	var need: int = int(cost.get("feed_level", 0))
	if need <= 0:
		return -1
	var best := -1
	for i in inventory.size():
		var other = inventory[i]
		if other == inst or other.item_id != inst.item_id or other.level < need:
			continue
		if best == -1 or other.level < inventory[best].level:
			best = i
	return best


# Can `inst` go up a level right now? {ok, reason, scrap, feed_level, feed_index}.
static func check(inst, inventory: Array, scrap: int) -> Dictionary:
	var out := {"ok": false, "reason": "", "scrap": 0, "feed_level": 0, "feed_index": -1}
	if inst == null or not has_tree(inst.item_id):
		out["reason"] = "The bench can't rework this."
		return out
	if inst.level >= MAX_LEVEL:
		out["reason"] = "Fully upgraded."
		return out
	var cost := step_cost(inst.level + 1)
	out["scrap"] = int(cost.get("scrap", 0))
	out["feed_level"] = int(cost.get("feed_level", 0))
	if out["feed_level"] > 0:
		out["feed_index"] = find_feed(inst, inventory)
		if out["feed_index"] == -1:
			out["reason"] = "Needs a spare Lv%d %s to strip for parts." % [out["feed_level"], inst.get_display_name()]
			return out
	if scrap < out["scrap"]:
		out["reason"] = "Needs %d scrap (you have %d)." % [out["scrap"], scrap]
		return out
	out["ok"] = true
	return out
