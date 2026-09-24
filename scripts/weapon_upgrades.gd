class_name WeaponUpgrades
extends RefCounted

# THE WORKBENCH'S RULES (docs/SCRAP_UPGRADES.md) — one data table, edited in one place.
#
# A weapon climbs SEVEN levels:
#   Lv1-3  ordinary        — every level-up grants TUNING POINTS the player spends on the weapon's
#                            own stat sheet (below), within caps; a weapon with a TREE also picks
#                            one of two perks per level (gun + hammer today).
#   Lv4    LEGENDARY       — it earns a TITLE (generated from how it was built; the player can
#                            rename it). "Hammer "Widowmaker"".
#   Lv5-7  HEIRLOOM + ++ +++ — only for a weapon that has CROSSED THE LOBBY DOOR (stashed at an
#                            escape, collected in a later game) 1 / 2 / 3 times: the new-game-plus
#                            upgrades. Scrap is paid in INSTALMENTS that ride the weapon, so several
#                            characters (and games) can feed it. Each tier grants more points and
#                            lifts every stat cap by one — the "crazy stats" only heirlooms reach.
#
# Everything rides THIS weapon instance (level, perks, tuning, title, crossings, forge_paid —
# serialized with it, carried on a corpse and through the door stash) and applies through the
# modifier fold (base × ∏mult + Σadd — never direct writes): ItemInstance.perk_add / perk_mult /
# has_perk_flag.

const MAX_LEVEL := 7
const LEGENDARY_LEVEL := 4

# Lv1→2, 2→3, 3→4: scrap + (from Lv3) a spare weapon stripped for parts (the lowest qualifying
# one is used, never a better one). The spare is the SAME weapon, or — for melee — any weapon of
# the same FAMILY (FAMILY below), so a rare blade or bat can still reach legendary.
const STEP_COST := {
	2: {"scrap": 50, "feed_level": 0},     # feed_level 0 = no spare needed
	3: {"scrap": 80, "feed_level": 1},
	4: {"scrap": 100, "feed_level": 2},
}

# Heirloom tiers: crossings needed + scrap paid in instalments (WorldState.forge_heirloom). Sized
# against tools/economy_report (docs/SCRAP_UPGRADES.md v2): a character who searches ~45 apartments
# on the way down finds ~200 scrap, so each tier is two to three characters' worth.
const HEIRLOOM := {
	5: {"crossings": 1, "scrap": 400},
	6: {"crossings": 2, "scrap": 500},
	7: {"crossings": 3, "scrap": 600},
}

const POINTS_PER_LEVEL := 2          # tuning points each level above 1 grants (Lv4 = 6, Lv7 = 12)

# Which weapons the bench works on, and their stat sheet. "melee" / "gun".
const KIND := {
	"001": "melee",   # Knife
	"002": "melee",   # Hammer
	"003": "melee",   # Sword
	"004": "gun",     # Gun
	"012": "melee",   # Golf Club
	"013": "melee",   # Cricket Bat
	"014": "melee",   # Baseball Bat
	"017": "melee",   # Aluminium Baseball Bat
}

# Melee families for upgrade feed (a spare of the same family can be stripped for parts).
const FAMILY := {
	"001": "blade", "003": "blade",
	"002": "blunt", "012": "blunt", "013": "blunt", "014": "blunt", "017": "blunt",
	"004": "gun",
}

# THE STAT SHEET — what a player can put their points into. Per rank: `add` adds to a fold stat,
# `mult` moves a fold stat's multiplier by that much (×(1 + ranks × mult)). `cap` = most ranks at
# Lv1-4; each heirloom tier lifts every cap by one. Fold stat names are the ones combat reads
# (ItemInstance.perk_add / perk_mult): damage, execute, reach, cooldown, stamina, durability,
# headshot, body, mag, shots_per_mark, free_shot.
const STATS := {
	# --- melee ---
	"T_weight": {"kind": "melee", "name": "Weight", "desc": "+1 damage", "cap": 1,
		"mods": {"damage": {"add": 1}}},
	"T_edge": {"kind": "melee", "name": "Edge", "desc": "+4% to drop an ordinary enemy", "cap": 3,
		"mods": {"execute": {"add": 0.04}}},
	"T_reach": {"kind": "melee", "name": "Reach", "desc": "+6 px reach", "cap": 3,
		"mods": {"reach": {"add": 6.0}}},
	"T_handling": {"kind": "melee", "name": "Handling", "desc": "8% faster swings", "cap": 3,
		"mods": {"cooldown": {"mult": -0.08}}},
	"T_balance": {"kind": "melee", "name": "Balance", "desc": "-10% swing stamina", "cap": 3,
		"mods": {"stamina": {"mult": -0.10}}},
	"T_temper": {"kind": "melee", "name": "Temper", "desc": "+25% durability", "cap": 4,
		"mods": {"durability": {"mult": 0.25}}},
	# --- gun ---
	"T_sights": {"kind": "gun", "name": "Sights", "desc": "+4% head + body hits", "cap": 3,
		"mods": {"headshot": {"add": 0.04}, "body": {"add": 0.04}}},
	"T_drum": {"kind": "gun", "name": "Magazine", "desc": "+2 rounds", "cap": 3,
		"mods": {"mag": {"add": 2}}},
	"T_oiled": {"kind": "gun", "name": "Oiled", "desc": "wears 25% slower", "cap": 4,
		"mods": {"shots_per_mark": {"mult": 0.25}}},
	"T_handload": {"kind": "gun", "name": "Hand-loaded", "desc": "+5% free shots", "cap": 3,
		"mods": {"free_shot": {"add": 0.05}}},
}

# Item id → {level: [perk A, perk B]}. A weapon WITH a tree picks one of these two at Lv2-4. Every
# OTHER level-up — a tree-less weapon's Lv2-4, and EVERY heirloom tier — offers two SPECIAL MODS
# (MODS below, seeded per weapon + level). Add a weapon's tree here.
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
		"mods": {"headshot": {"add": 0.10}, "body": {"add": 0.10}}, "title": "T_sights"},
	# The doc's "doubles durability": a gun wears a mark every 6 shots — this makes it every 12
	# (the owner's call), and forcing a door never damages it.
	"G_durable": {"name": "Durable Hand Cannon", "desc": "Wears half as fast (a durability mark every 12 shots, not 6), and forcing a door never damages it.",
		"mods": {"shots_per_mark": {"mult": 2.0}}, "flags": ["no_force_damage"], "title": "T_oiled"},
	"G_silencer": {"name": "Silencer", "desc": "Shots are barely louder than footsteps — they no longer rouse the floor.",
		"flags": ["silenced"], "title": "silent"},
	"G_pierce": {"name": "Through-and-Through", "desc": "A shot that lands also hits the enemy behind the target.",
		"flags": ["pierce"], "title": "T_sights"},
	"G_lucky": {"name": "Lucky Bullet", "desc": "30% chance a shot doesn't use up a round.",
		"mods": {"free_shot": {"add": 0.30}}, "title": "T_handload"},
	"G_bang": {"name": "Bigger Bang", "desc": "Volatile rounds: a hit also blasts every enemy close to the target.",
		"flags": ["blast"], "title": "boom"},
	# --- Hammer (PLACEHOLDER — owner to define) ---
	"H_heavy": {"name": "Heavy Head", "desc": "+1 damage with every blow.",
		"mods": {"damage": {"add": 1}}, "title": "T_weight"},
	"H_reinforced": {"name": "Reinforced Handle", "desc": "Twice the durability.",
		"mods": {"durability": {"mult": 2.0}}, "title": "T_temper"},
	"H_doorbreaker": {"name": "Door Breaker", "desc": "Forcing locks and tearing down barricades costs it no durability.",
		"flags": ["free_force"], "title": "T_temper"},
	"H_sweep": {"name": "Sweeping Blow", "desc": "A swing also strikes a second enemy in reach.",
		"flags": ["sweep"], "title": "T_reach"},
	"H_skull": {"name": "Skull Splitter", "desc": "15% chance a blow drops an ordinary enemy outright.",
		"mods": {"execute": {"add": 0.15}}, "title": "T_edge"},
	"H_feather": {"name": "Featherweight", "desc": "Swings cost 40% less stamina.",
		"mods": {"stamina": {"mult": 0.6}}, "title": "T_balance"},
}

# SPECIAL MODS (owner, round 5: "add fire to your sword so striking an enemy has a 20% chance of
# setting it on fire — real upgrades that make a weapon special"). Offered in pairs at every level-up
# that has no tree perk; a weapon never gets the same mod twice. `proc` = what it does on a landed
# hit / kill (player._weapon_mods_on_hit): ignite (WeaponAffliction burn), bleed (a wound), knockdown
# (an ordinary enemy — not a big/boss — is knocked flat), shove (a real push), kill_stamina (a kill
# refunds that share of max stamina), kill_mend (a killing blow costs no durability). `chance` grows
# by `per_tier` with each heirloom tier the weapon reaches — heirlooms make their specials sing.
# Plain stat mods use `mods` / `flags` like any perk.
const MODS := {
	"X_fire": {"name": "Fuel-Soaked", "pool": ["melee"], "proc": "ignite", "chance": 0.20, "per_tier": 0.05, "title": "fire",
		"desc": "A hit has a %d%% chance to set the enemy alight. (Burning enemies hit twice as hard — finish them.)"},
	"X_incendiary": {"name": "Incendiary Rounds", "pool": ["gun"], "proc": "ignite", "chance": 0.20, "per_tier": 0.05, "title": "fire",
		"desc": "A shot that lands has a %d%% chance to set the enemy alight. (Burning enemies hit twice as hard.)"},
	"X_serrated": {"name": "Serrated", "pool": ["melee"], "proc": "bleed", "chance": 0.30, "per_tier": 0.05, "title": "bleed",
		"desc": "A hit has a %d%% chance to open a wound: 3 more damage over the next few seconds."},
	"X_bell": {"name": "Bell-Ringer", "pool": ["melee"], "proc": "knockdown", "chance": 0.25, "per_tier": 0.05, "title": "stagger",
		"desc": "A hit has a %d%% chance to knock an ordinary enemy flat."},
	"X_stopping": {"name": "Stopping Power", "pool": ["gun"], "proc": "knockdown", "chance": 0.30, "per_tier": 0.05, "title": "stagger",
		"desc": "A shot that lands has a %d%% chance to knock an ordinary enemy flat."},
	"X_homerun": {"name": "Home Run", "pool": ["melee"], "proc": "shove", "chance": 1.0, "per_tier": 0.0, "title": "shove",
		"desc": "Every hit shoves the enemy back, like a push."},
	"X_wind": {"name": "Second Wind", "pool": ["melee", "gun"], "proc": "kill_stamina", "chance": 0.30, "per_tier": 0.05, "title": "wind",
		"desc": "A kill with it gives back %d%% of your stamina."},
	"X_mend": {"name": "Mended", "pool": ["melee"], "proc": "kill_mend", "chance": 1.0, "per_tier": 0.0, "title": "T_temper",
		"desc": "A killing blow doesn't wear it."},
	"X_cleave": {"name": "Cleave", "pool": ["melee"], "flags": ["sweep"], "title": "T_reach",
		"desc": "A swing also strikes a second enemy in reach."},
	"X_quick": {"name": "Quick Hands", "pool": ["gun"], "mods": {"gun_cooldown": {"mult": 0.70}}, "title": "T_drum",
		"desc": "Fires 30% faster."},
}

# LEGENDARY TITLES — word banks keyed by what the weapon is best at (its highest-ranked stat, or
# the flavour of its perks). One is drawn (seeded, stable) when it reaches Lv4; the player can
# rename it at the bench. Add words freely.
const TITLE_BANKS := {
	"T_weight": ["Widowmaker", "Bonebreaker", "The Last Word", "Heavy Heart", "Doorstop"],
	"T_edge": ["Lights Out", "Mercy", "Coin Toss", "Quiet Night", "Goodnight"],
	"T_reach": ["Long Goodbye", "Arm's Length", "Keep Away", "Stay Back", "The Long Arm"],
	"T_handling": ["Hummingbird", "Quickstep", "Rattle", "Flicker", "Twitch"],
	"T_balance": ["Tireless", "Second Wind", "Featherfall", "Easy Does It", "Night Shift"],
	"T_temper": ["Old Faithful", "The Unbroken", "Stubborn Thing", "Ironside", "Heirloom"],
	"T_sights": ["Dead Eye", "True North", "The Surgeon", "Pinhole", "Steady Hand"],
	"T_drum": ["Chatterbox", "Long Sermon", "Full House", "Loudmouth", "Encore"],
	"T_oiled": ["Old Reliable", "Workhorse", "Never Jams", "Clockwork", "Sweetheart"],
	"T_handload": ["Lucky Penny", "Four-Leaf", "Borrowed Time", "Last Chance", "Rabbit's Foot"],
	"silent": ["Hush", "Lullaby", "Whisper", "Library", "Sleepwalker"],
	"boom": ["Housewarming", "Fireworks", "Thunderclap", "Big Finish", "Landlord"],
	"fire": ["Firestarter", "Kindling", "Matchstick", "Hearthside", "Bonfire"],
	"bleed": ["Paper Cut", "Letter Opener", "Red Ribbon", "Tenderiser", "The Barber"],
	"stagger": ["Doorbell", "Knock Knock", "Wake-Up Call", "Last Orders", "Bedtime"],
	"shove": ["Home Run", "Eviction Notice", "Moving Day", "Out You Go", "Bouncer"],
	"wind": ["Second Wind", "Deep Breath", "Pick-Me-Up", "Morning Coffee", "Stairmaster"],
	"any": ["Keepsake", "The Survivor", "Stairwell", "Floor Thirty", "Good Neighbour"],
}
const TITLE_MAX_LEN := 18


static func can_upgrade(item_id: String) -> bool:
	return KIND.has(item_id)


# Kept for callers that ask "does the bench rework this?" (any weapon on the sheet now).
static func has_tree(item_id: String) -> bool:
	return can_upgrade(item_id)


static func has_perk_tree(item_id: String) -> bool:
	return TREES.has(item_id)


static func perk(id: String) -> Dictionary:
	if MODS.has(id):
		return MODS[id]
	return PERKS.get(id, {})


static func is_mod(id: String) -> bool:
	return MODS.has(id)


# The chance a mod's proc fires on THIS weapon: its base, + per_tier for each heirloom tier.
static func mod_chance(inst, id: String) -> float:
	var m: Dictionary = MODS.get(id, {})
	return clampf(float(m.get("chance", 0.0)) + float(m.get("per_tier", 0.0)) * maxi(0, inst.level - LEGENDARY_LEVEL), 0.0, 1.0)


# A perk / mod's description, with this weapon's live chance filled in ("20%" → "30%" at ++).
static func describe(inst, id: String) -> String:
	var d: Dictionary = perk(id)
	var text := String(d.get("desc", ""))
	if MODS.has(id) and text.contains("%d"):
		var c: float = mod_chance(inst, id) if inst != null else float(d.get("chance", 0.0))
		return text % int(round(c * 100.0))
	return text


# The weapon's mods with a given proc, as [[mod id, chance], ...].
static func procs(inst, proc: String) -> Array:
	var out: Array = []
	if inst == null:
		return out
	for p in inst.perks:
		if MODS.has(p) and String(MODS[p].get("proc", "")) == proc:
			out.append([p, mod_chance(inst, p)])
	return out


# Two special mods for this weapon's next level: from its kind's pool, never one it already has
# (nor Cleave on a weapon that already sweeps), seeded per weapon + level so the offer is stable
# while you think about it (and across a save).
static func mod_pair(inst) -> Array:
	var kind := kind_of(inst.item_id)
	var pool: Array = []
	for id in MODS:
		if not (kind in MODS[id]["pool"]) or id in inst.perks:
			continue
		if "sweep" in MODS[id].get("flags", []) and inst.has_perk_flag("sweep"):
			continue
		pool.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "mods" + inst.item_id + str(inst.level) + ",".join(PackedStringArray(inst.perks)))
	var out: Array = []
	while out.size() < 2 and not pool.is_empty():
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out


static func stat(id: String) -> Dictionary:
	return STATS.get(id, {})


static func kind_of(item_id: String) -> String:
	return String(KIND.get(item_id, ""))


# The stat ids this weapon can be tuned in, in display order.
static func stats_for(item_id: String) -> Array:
	var k := kind_of(item_id)
	var out: Array = []
	for id in STATS:
		if STATS[id]["kind"] == k:
			out.append(id)
	return out


static func tier_name(level: int) -> String:
	if level < LEGENDARY_LEVEL:
		return "Lv%d" % level
	if level == LEGENDARY_LEVEL:
		return "Legendary"
	return "Legendary " + "+".repeat(level - LEGENDARY_LEVEL)


static func is_heirloom_step(to_level: int) -> bool:
	return HEIRLOOM.has(to_level)


# The two choices for this weapon's NEXT level: its tree's pair at Lv2-4, otherwise two special
# mods ([] at max level / not a weapon the bench works on).
static func next_choices(inst) -> Array:
	if inst == null or not can_upgrade(inst.item_id) or inst.level >= MAX_LEVEL:
		return []
	if has_perk_tree(inst.item_id) and TREES[inst.item_id].has(inst.level + 1):
		return TREES[inst.item_id][inst.level + 1]
	return mod_pair(inst)


static func step_cost(to_level: int) -> Dictionary:
	if HEIRLOOM.has(to_level):
		return {"scrap": int(HEIRLOOM[to_level]["scrap"]), "feed_level": 0}
	return STEP_COST.get(to_level, {})


# --- tuning --------------------------------------------------------------------------------
static func points_earned(inst) -> int:
	return POINTS_PER_LEVEL * maxi(0, inst.level - 1)


static func points_spent(inst) -> int:
	var n := 0
	for id in inst.tuning:
		n += int(inst.tuning[id])
	return n


static func points_free(inst) -> int:
	return maxi(0, points_earned(inst) - points_spent(inst))


# Most ranks this weapon can hold in `stat_id` at its level: the base cap, +1 per heirloom tier.
static func cap_for(inst, stat_id: String) -> int:
	return int(STATS.get(stat_id, {}).get("cap", 0)) + maxi(0, inst.level - LEGENDARY_LEVEL)


# Can `alloc` ({stat: extra ranks}) be added to this weapon now? "" = yes, else why not.
static func tuning_error(inst, alloc: Dictionary) -> String:
	if inst == null or not can_upgrade(inst.item_id):
		return "The bench can't rework this."
	var total := 0
	var valid: Array = stats_for(inst.item_id)
	for id in alloc:
		var n := int(alloc[id])
		if n < 0:
			return "Points, once set, are set."
		if n == 0:
			continue
		if not (id in valid):
			return "That isn't something this weapon can take."
		if int(inst.tuning.get(id, 0)) + n > cap_for(inst, id):
			return "%s is maxed at this level." % STATS[id]["name"]
		total += n
	if total == 0:
		return "Nothing to set."
	if total > points_free(inst):
		return "Only %d point%s to spend." % [points_free(inst), "" if points_free(inst) == 1 else "s"]
	return ""


# --- feed ---------------------------------------------------------------------------------
static func _feeds(inst, other) -> bool:
	if other == inst:
		return false
	if other.item_id == inst.item_id:
		return true
	var fam := String(FAMILY.get(inst.item_id, ""))
	return fam != "" and fam != "gun" and String(FAMILY.get(other.item_id, "")) == fam


# Index (in `inventory`) of the spare that would be consumed as feed for `inst`'s next step, or -1.
# The lowest-level qualifying spare is used, so a better one is never burnt by accident; an exact
# copy is preferred over a family member at the same level. A titled (legendary) weapon is never fed.
static func find_feed(inst, inventory: Array) -> int:
	var cost := step_cost(inst.level + 1)
	var need: int = int(cost.get("feed_level", 0))
	if need <= 0:
		return -1
	var best := -1
	for i in inventory.size():
		var other = inventory[i]
		if other == inst or other.level < need or other.level >= LEGENDARY_LEVEL or not _feeds(inst, other):
			continue
		if best == -1:
			best = i
			continue
		var b = inventory[best]
		if other.level < b.level or (other.level == b.level and other.item_id == inst.item_id and b.item_id != inst.item_id):
			best = i
	return best


static func feed_label(inst, feed_level: int) -> String:
	var fam := String(FAMILY.get(inst.item_id, ""))
	if fam == "blade":
		return "a spare Lv%d blade (knife or sword)" % feed_level
	if fam == "blunt":
		return "a spare Lv%d bat, club or hammer" % feed_level
	return "a spare Lv%d %s" % [feed_level, inst.get_data().get("name", "weapon")]


# Can `inst` go up a level right now? {ok, reason, scrap, feed_level, feed_index, heirloom}.
# An heirloom step is paid in instalments (forge_paid), so `scrap` is what's STILL owed.
static func check(inst, inventory: Array, scrap: int) -> Dictionary:
	var out := {"ok": false, "reason": "", "scrap": 0, "feed_level": 0, "feed_index": -1, "heirloom": false}
	if inst == null or not can_upgrade(inst.item_id):
		out["reason"] = "The bench can't rework this."
		return out
	if inst.level >= MAX_LEVEL:
		out["reason"] = "Fully upgraded."
		return out
	var to: int = inst.level + 1
	var cost := step_cost(to)
	if is_heirloom_step(to):
		out["heirloom"] = true
		out["scrap"] = maxi(0, int(cost["scrap"]) - inst.forge_paid)
		var need: int = int(HEIRLOOM[to]["crossings"])
		if inst.crossings < need:
			out["reason"] = "Only a weapon carried through the lobby door into a later game can go further (%d/%d crossings)." % [inst.crossings, need]
			return out
		if out["scrap"] > 0:
			out["reason"] = "Forge it: %d more scrap to put in." % out["scrap"]
			return out
		out["ok"] = true
		return out
	out["scrap"] = int(cost.get("scrap", 0))
	out["feed_level"] = int(cost.get("feed_level", 0))
	if out["feed_level"] > 0:
		out["feed_index"] = find_feed(inst, inventory)
		if out["feed_index"] == -1:
			out["reason"] = "Needs %s to strip for parts." % feed_label(inst, out["feed_level"])
			return out
	if scrap < out["scrap"]:
		out["reason"] = "Needs %d scrap (you have %d)." % [out["scrap"], scrap]
		return out
	out["ok"] = true
	return out


# Every bit of workbench scrap this weapon has swallowed (levels, heirloom tiers, instalments) —
# salvage refunds a share, and it's part of what the weapon is worth at the door.
static func scrap_sunk(inst) -> int:
	var n := 0
	for lvl in range(2, inst.level + 1):
		n += int(step_cost(lvl).get("scrap", 0))
	return n + maxi(0, inst.forge_paid)


# --- titles -------------------------------------------------------------------------------
# What the weapon is best at: its newest special mod, else its highest-ranked tuning (ties → sheet
# order), else the flavour of its latest perk, else "any".
static func title_theme(inst) -> String:
	# A SPECIAL mod names it first (a fire sword is a Firestarter), newest first…
	for i in range(inst.perks.size() - 1, -1, -1):
		if MODS.has(inst.perks[i]) and TITLE_BANKS.has(String(MODS[inst.perks[i]].get("title", ""))):
			return String(MODS[inst.perks[i]]["title"])
	# …then its best-tuned stat, then a tree perk's flavour.
	var best := ""
	var best_n := 0
	for id in stats_for(inst.item_id):
		var n := int(inst.tuning.get(id, 0))
		if n > best_n:
			best_n = n
			best = id
	if best != "":
		return best
	for i in range(inst.perks.size() - 1, -1, -1):
		var t := String(perk(inst.perks[i]).get("title", ""))
		if TITLE_BANKS.has(t):
			return t
	return "any"


static func generate_title(inst, seed_text: String) -> String:
	var bank: Array = TITLE_BANKS.get(title_theme(inst), TITLE_BANKS["any"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	return String(bank[rng.randi() % bank.size()])


# A player-typed name, made safe: printable ASCII only (the pixel font), trimmed, capped. "" = invalid.
static func clean_title(text: String) -> String:
	var out := ""
	for ch in text.strip_edges():
		var c := ch.unicode_at(0)
		if c >= 32 and c < 127 and ch != "\"":
			out += ch
	out = out.strip_edges()
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.left(TITLE_MAX_LEN).strip_edges()
