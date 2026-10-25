class_name ItemCompare
extends RefCounted

# WHICH WEAPON IS BETTER, AT A GLANCE (owner round 48i: "the player needs to know, without having to juggle inventory, which weapon is better, or more durable - that
# information should be more presentable"). A weapon on the floor / found in a node / under the pointer in the pack ring is set beside the one in hand:
#     Damage        3   ▲ +2
#     Reach         65  ▲ +33
#     Durability    8/8 ▼ -2
# Every number comes from the same place combat reads it (player.gd's WEAPON_* tables + the weapon's own workbench perks), so what the card says is what the swing does.
# Only like is set against like: a blade against a blade or a bat, a gun against a gun - a gun and a knife have nothing to compare.

const GOOD := Color(0.55, 0.88, 0.50)
const BAD := Color(0.95, 0.50, 0.42)
const FLAT := Color(0.78, 0.82, 0.86)


## "knife" / "sword" / "bat" / "gun" for a weapon's item data, "" for anything else - the SAME mapping player.gd's _get_weapon_type uses (item_compare_test checks they agree).
static func weapon_kind(d: Dictionary) -> String:
	if not d.get("is_weapon", false):
		return ""
	var n: String = str(d.get("name", "")).to_lower()
	if n.contains("knife") or n.contains("scalpel"):
		return "knife"
	if n.contains("sword") or n.contains("katana") or n.contains("machete"):
		return "sword"
	if n.contains("bat") or n.contains("club") or n.contains("wrench") or n.contains("hammer"):
		return "bat"
	if n.contains("gun") or n.contains("pistol") or n.contains("rifle") or n.contains("shotgun"):
		return "gun"
	return ""


static func is_melee(kind: String) -> bool:
	return kind == "knife" or kind == "sword" or kind == "bat"


## The numbers one weapon fights with: {kind, stats: [{id, label, value (float), text, higher_better}]}; {} for a non-weapon.
static func profile(inst) -> Dictionary:
	if inst == null:
		return {}
	var d: Dictionary = inst.get_data()
	var kind := weapon_kind(d)
	if kind == "":
		return {}
	var P = AllyCombat.player_script()
	var stats: Array = []
	var max_d: int = inst.get_max_durability()
	if is_melee(kind):
		var dmg: int = int(P.WEAPON_DAMAGE.get(kind, 1)) + int(inst.perk_add("damage"))
		var cd: float = float(P.WEAPON_COOLDOWN.get(kind, 0.5)) * inst.perk_mult("cooldown")
		var reach: float = float(P.WEAPON_RANGES.get(kind, 40.0)) + inst.perk_add("reach")
		var cost: float = float(P.WEAPON_STAMINA_COST.get(kind, 15.0)) * inst.perk_mult("stamina")
		stats.append({"id": "damage", "label": "Damage", "value": float(maxi(1, dmg)), "text": "%d" % maxi(1, dmg), "higher_better": true})
		stats.append({"id": "speed", "label": "Speed", "value": 1.0 / maxf(cd, 0.05), "text": "%.1f /s" % (1.0 / maxf(cd, 0.05)), "higher_better": true})
		stats.append({"id": "reach", "label": "Reach", "value": reach, "text": "%d" % int(round(reach)), "higher_better": true})
		stats.append({"id": "stamina", "label": "Stamina", "value": cost, "text": "%d" % int(round(cost)), "higher_better": false})
	else:
		var head: float = 0.25 + inst.perk_add("headshot")
		var body: float = 0.60 + inst.perk_add("body")
		stats.append({"id": "hit", "label": "Close hit", "value": clampf(head + body, 0.0, 1.0) * 100.0, "text": "%d%%" % int(round(clampf(head + body, 0.0, 1.0) * 100.0)), "higher_better": true})
		stats.append({"id": "mag", "label": "Magazine", "value": float(inst.get_mag_cap()), "text": "%d" % inst.get_mag_cap(), "higher_better": true})
	if max_d > 1:
		var cur: int = 0 if inst.is_depleted else inst.current_durability
		stats.append({"id": "durability", "label": "Durability", "value": float(cur), "text": ("BROKEN" if inst.is_depleted else "%d / %d" % [cur, max_d]), "higher_better": true})
	return {"kind": kind, "stats": stats}


## The card for `inst`: rows [{label, text, delta ("" / "▲ +2" / "▼ -2"), tone (1 better, -1 worse, 0 same / no comparison)}], set against `held` when it is the same sort of weapon
## (`vs` = its name, "" when there is nothing to compare). {} for a non-weapon.
static func card(inst, held) -> Dictionary:
	var mine: Dictionary = profile(inst)
	if mine.is_empty():
		return {}
	var theirs: Dictionary = {}
	if held != null and held != inst:
		var h: Dictionary = profile(held)
		if not h.is_empty() and is_melee(String(h["kind"])) == is_melee(String(mine["kind"])):
			theirs = h
	var by_id: Dictionary = {}
	for s in theirs.get("stats", []):
		by_id[s["id"]] = s
	var rows: Array = []
	for s in mine["stats"]:
		var delta := ""
		var tone := 0
		if by_id.has(s["id"]):
			var diff: float = float(s["value"]) - float(by_id[s["id"]]["value"])
			if absf(diff) >= (0.05 if s["id"] == "speed" else 0.5):
				var better: bool = (diff > 0.0) == bool(s["higher_better"])
				tone = 1 if better else -1
				delta = "%s %s" % ["▲" if diff > 0.0 else "▼", _signed(diff, s["id"])]
		rows.append({"label": s["label"], "text": s["text"], "delta": delta, "tone": tone})
	var vs := ""
	if not theirs.is_empty():
		vs = held.get_display_name()
	return {"rows": rows, "vs": vs, "kind": mine["kind"]}


static func _signed(diff: float, id: String) -> String:
	if id == "speed":
		return "%+.1f" % diff
	if id == "hit":
		return "%+d%%" % int(round(diff))
	return "%+d" % int(round(diff))


## The weapon the player holds (or null): what a found weapon is measured against.
static func held_weapon():
	var i: int = HUD.selected_slot
	if i >= 0 and i < WorldState.inventory.size() and profile(WorldState.inventory[i]).size() > 0:
		return WorldState.inventory[i]
	return null


## A compact BBCode form for the floor pill: "Damage  3  ▲ +2" per row, coloured, a header naming what it's set against. (The found-item panel and the rings draw the same card themselves —
## scripts/lamp_rows.gd, scripts/lamp.gd — with drawn arrows.)
static func bbcode(c: Dictionary) -> String:
	if c.is_empty():
		return ""
	var out := ""
	if String(c["vs"]) != "":
		out += "[color=#9aa0a8]compared with your %s[/color]\n" % String(c["vs"])
	for r in c["rows"]:
		var col: Color = GOOD if int(r["tone"]) > 0 else (BAD if int(r["tone"]) < 0 else FLAT)
		out += "[color=#9aa0a8]%s[/color]  [color=#%s]%s[/color]" % [r["label"], FLAT.to_html(false), r["text"]]
		if String(r["delta"]) != "":
			out += "  [color=#%s]%s[/color]" % [col.to_html(false), r["delta"]]
		out += "\n"
	return out.strip_edges()


## One line for a world pill: "▲ dmg +2 · ▼ dur -2" (only what differs), "" when there is nothing to say.
static func pill_suffix(c: Dictionary) -> String:
	if c.is_empty() or String(c["vs"]) == "":
		return ""
	var bits: PackedStringArray = []
	var short := {"Damage": "dmg", "Speed": "spd", "Reach": "reach", "Stamina": "stam", "Durability": "dur", "Close hit": "aim", "Magazine": "mag"}
	for r in c["rows"]:
		if String(r["delta"]) != "":
			bits.append("%s %s" % [short.get(r["label"], String(r["label"]).to_lower()), String(r["delta"])])
	return "  ·  ".join(bits)
