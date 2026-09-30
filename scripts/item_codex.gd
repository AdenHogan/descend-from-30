extends RefCounted
class_name ItemCodex

# THE ITEM CODEX — the journal's reference tab (owner round 27: "an item codex that gives the details of
# durability per item so players can actually know by reading"). Every line is DERIVED from the item's real
# data (`ItemData.items`: durability, single-use, the is_* flags) and the wear rules the game actually
# applies, so what it says can't drift from what the game does:
#   * a melee weapon spends 1 use per LANDED swing (a swing at nothing is free);
#   * forcing a lock / door spends 1 (a gun is damaged instead); tearing a barricade off spends BARRICADE_COST;
#   * a gun has WEAR MARKS, one knocked off every `ItemInstance.GUN_SHOTS_PER_MARK` rounds fired;
#   * medical items spend a use only when the heal actually happens; the toolbox one per repair; the
#     extinguisher one per spray;
#   * an item that runs out: weapons and tools stay in the pack as BROKEN (a Toolbox rebuilds them),
#     consumables are simply used up.
# Pure static functions (no nodes) so the tab and its test share one source.

const BARRICADE_COST := 2            # = door.gd BARRICADE_DURABILITY_COST (locked by a codex test)

const SECTIONS := [
	["weapons", "Weapons"],
	["tools", "Tools"],
	["medical", "Medical & supplies"],
	["keys", "Keys"],
	["ammo", "Ammunition & cash"],
	["junk", "Junk"],
]


static func is_gun(d: Dictionary) -> bool:
	return str(d.get("name", "")).to_lower() == "gun"


## Which codex section an item belongs to.
static func section_of(d: Dictionary) -> String:
	if d.get("is_weapon", false):
		return "weapons"
	if d.get("is_key", false):
		return "keys"
	if d.get("is_junk", false):
		return "junk"
	if d.get("is_ammo", false) or d.get("is_money", false) or d.get("is_scrap", false):
		return "ammo"
	if d.get("is_health_item", false) or d.get("is_speed_boost", false) or d.get("is_throwable", false):
		return "medical"
	return "tools"


## The headline: how much it can take.
static func durability_line(d: Dictionary) -> String:
	var max_d: int = int(d.get("max_durability", -1))
	if is_gun(d):
		return "%d wear marks (about %d rounds)" % [max_d, max_d * ItemInstance.GUN_SHOTS_PER_MARK]
	if d.get("single_use", false) and max_d <= 1:
		return "Single use"
	if max_d > 1:
		return "%d uses" % max_d
	if d.get("requires_battery", false):
		return "Runs on a battery"
	if d.get("is_ammo", false):
		return "One round per shot"
	return "Doesn't wear"


## HOW it wears — the rule the game applies.
static func wear_text(d: Dictionary) -> String:
	var max_d: int = int(d.get("max_durability", -1))
	if is_gun(d):
		return "One mark wears off every %d rounds fired. Forcing a lock with it damages it instead (smaller magazine, worse aim) — a Toolbox mends that." % ItemInstance.GUN_SHOTS_PER_MARK
	if d.get("is_weapon", false):
		var t := "Each swing that lands spends 1 use (a swing at nothing is free)."
		if d.get("can_force_lock", false):
			t += " Forcing a lock or door spends 1; tearing the boards off a barricade spends %d." % BARRICADE_COST
		return t
	if d.get("can_force_lock", false) and not d.get("is_tool", false):
		return "One use per lock or door forced; tearing the boards off a barricade spends %d." % BARRICADE_COST
	if d.get("is_key", false):
		return "Used up the moment it opens its door."
	if d.get("is_health_item", false):
		if max_d > 1:
			return "One use per dose that actually heals — none is spent at full health."
		return "Used up when it heals. None is spent at full health."
	if d.get("is_speed_boost", false):
		return "One use per dose (restores a third of your stamina)."
	if d.get("can_repair", false):
		return "One use per repair. Mends a damaged gun or rebuilds a broken weapon or tool."
	if d.get("is_extinguisher", false):
		return "One use per spray, and only when something is burning."
	if d.get("is_crowbar", false):
		return "Spent prying one blocked stairwell (or a locked cabinet) open."
	if d.get("is_bottle", false):
		return "Thrown away when used: it shatters on the first thing it hits — a loud smash that pulls the dead to the noise."
	if d.get("is_throwable", false):
		return "Thrown away when used: the can lands loudly and pulls the dead to the noise."
	if d.get("is_fuse", false):
		return "Fitted into the fuse box; three power the lift for one ride."
	if d.get("requires_battery", false):
		return "Drains the battery it is fed; it never wears out itself."
	if d.get("is_ammo", false):
		return "Loaded into a gun (up to 8 to a slot); each shot uses one round."
	if d.get("is_scrap", false):
		return "Emptied straight into your scrap counter — it never takes a slot."
	if d.get("is_money", false):
		return "Cash. It never wears; it lives in your wallet once you have one."
	if d.get("is_junk", false):
		return "No durability. Break it down for scrap at a workbench."
	if d.get("single_use", false):
		return "Used up when you use it."
	return "Doesn't wear."


## What becomes of it when it runs out.
static func ending_text(d: Dictionary) -> String:
	if d.get("is_junk", false) or d.get("is_money", false) or d.get("is_ammo", false) or d.get("is_scrap", false) or d.get("requires_battery", false):
		return ""
	var max_d: int = int(d.get("max_durability", -1))
	if d.get("can_force_lock", false) and not d.get("is_tool", false) and not d.get("is_weapon", false):
		return "When it runs out it stays in your pack, broken for good — a Toolbox only mends weapons and tools."
	var consumable: bool = d.get("is_health_item", false) or d.get("is_speed_boost", false) or d.get("can_repair", false) \
		or d.get("is_extinguisher", false) or d.get("is_throwable", false) or d.get("single_use", false)
	if d.get("is_weapon", false) or (max_d > 1 and not consumable):
		return "When it runs out it isn't lost: it stays in your pack BROKEN until a Toolbox rebuilds it."
	if consumable or max_d > 0:
		return "Gone once it's used up."
	return ""


## Every item as a row, grouped by section: [{section, title, items: [{id, name, desc, durability, wear, ending}]}].
static func sections() -> Array:
	var by: Dictionary = {}
	for k in SECTIONS:
		by[k[0]] = []
	var ids: Array = ItemData.items.keys()
	ids.sort()
	for id in ids:
		var d: Dictionary = ItemData.items[id]
		by[section_of(d)].append({
			"id": id,
			"name": str(d.get("name", id)),
			"desc": str(d.get("description", "")),
			"durability": durability_line(d),
			"wear": wear_text(d),
			"ending": ending_text(d),
		})
	var out: Array = []
	for k in SECTIONS:
		if not by[k[0]].is_empty():
			out.append({"section": k[0], "title": k[1], "items": by[k[0]]})
	return out


## The colour legend shown at the top of the tab — the SAME gradient the in-hand box uses.
static func legend() -> Array:
	var box = load("res://scripts/hud_equip_box.gd")
	return [
		["Fresh", box.tint_for(1.0)],
		["Worn", box.tint_for(0.6)],
		["Failing", box.tint_for(0.38)],
		["Nearly gone", box.tint_for(0.16)],
		["Broken", box.tint_for(0.0, true)],
	]
