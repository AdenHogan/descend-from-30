class_name Crafting
extends RefCounted

# CRAFTING / MERGING (owner round 30: "crafting now / merging items will happen from the item wheel in the backpack — players
# can drag items to items in the wheel"). Pure rules + one action, no UI: the backpack ring (pack_wheel.gd) asks `preview` while a
# drag hovers a wedge and calls `craft` on the drop. Recipes are DATA (RECIPES); every input is matched by item id or by a flag from
# data/Items.json, and an input spends ONE unit (a stack of bottles loses one bottle, not the stack).
#
#   Molotov Cocktail (039) = an Empty Bottle (any `is_bottle`, never the Broken Bottle) + one Torn Clothes (009).
#   Rope (018)             = three Clothes (008) — the same three a balcony lash would knot (a Rope is just carried ready).
#
# The two dragged slots are always two of the recipe's inputs (either way round); a recipe with more inputs (the rope) finds its
# remaining ones elsewhere in the pack. Nothing is destroyed silently (CLAUDE.md robustness rule 5): if the result won't fit once the
# ingredients are spent, the whole craft is undone and the pack is exactly as it was.

const RECIPES := [
	{"id": "molotov", "name": "Molotov Cocktail", "result": "039",
		"inputs": [{"flag": "is_bottle"}, {"item": "009"}]},
	{"id": "rope", "name": "Rope", "result": "018",
		"inputs": [{"item": "008"}, {"item": "008"}, {"item": "008"}]},
]


static func _matches(inst, spec: Dictionary) -> bool:
	if inst == null:
		return false
	if spec.has("item"):
		return inst.item_id == str(spec["item"])
	if spec.has("flag"):
		return bool(ItemData.get_item(inst.item_id).get(str(spec["flag"]), false))
	return false


## Units a slot can give (a stack gives up to its count; a single item gives one).
static func _units(inst) -> int:
	return maxi(1, int(inst.count)) if inst != null else 0


## Can the item in `slot_a` be merged with the one in `slot_b`? {ok, recipe (id), name, result, uses {slot: units}, why}.
## `ok` false with a `why` when the pair is a recipe's start but something is missing (so the UI can say what), and an empty
## Dictionary when the two have nothing to do with each other.
static func plan(slot_a: int, slot_b: int) -> Dictionary:
	var inv: Array = WorldState.inventory
	if slot_a == slot_b or slot_a < 0 or slot_b < 0 or slot_a >= inv.size() or slot_b >= inv.size():
		return {}
	var a = inv[slot_a]
	var b = inv[slot_b]
	if a == null or b == null:
		return {}
	var missing := {}
	for r in RECIPES:
		var inputs: Array = r["inputs"]
		for i in range(inputs.size()):
			for j in range(inputs.size()):
				if i == j or not _matches(a, inputs[i]) or not _matches(b, inputs[j]):
					continue
				# a -> input i, b -> input j. Spend one unit each; find the rest elsewhere.
				var uses := {slot_a: 1}
				uses[slot_b] = int(uses.get(slot_b, 0)) + 1
				if int(uses[slot_a]) > _units(a) or int(uses[slot_b]) > _units(b):
					continue
				var short := ""
				for k in range(inputs.size()):
					if k == i or k == j:
						continue
					var found := false
					for s in range(inv.size()):
						if _matches(inv[s], inputs[k]) and int(uses.get(s, 0)) < _units(inv[s]):
							uses[s] = int(uses.get(s, 0)) + 1
							found = true
							break
					if not found:
						short = "Needs %d %s." % [inputs.size(), _input_name(inputs[k])]
				if short == "":
					return {"ok": true, "recipe": str(r["id"]), "name": str(r["name"]), "result": str(r["result"]), "uses": uses, "why": ""}
				missing = {"ok": false, "recipe": str(r["id"]), "name": str(r["name"]), "result": str(r["result"]), "uses": {}, "why": short}
	return missing


static func _input_name(spec: Dictionary) -> String:
	if spec.has("item"):
		var n: String = str(ItemData.get_item(str(spec["item"])).get("name", "items"))
		return n.to_lower() if n.to_lower() != "clothes" else "clothes"
	return "matching items"


## Do it. {ok, name, why}. On ANY failure the pack is left exactly as it was.
static func craft(slot_a: int, slot_b: int) -> Dictionary:
	var pl: Dictionary = plan(slot_a, slot_b)
	if pl.is_empty():
		return {"ok": false, "name": "", "why": "Those don't go together."}
	if not bool(pl["ok"]):
		return {"ok": false, "name": str(pl["name"]), "why": str(pl["why"])}
	var inv: Array = WorldState.inventory
	var before: Array = inv.duplicate()
	var counts: Array = []
	for inst in before:
		counts.append(inst.count)
	var held = null
	if HUD.selected_slot >= 0 and HUD.selected_slot < inv.size():
		held = inv[HUD.selected_slot]
	# spend the ingredients (highest slot first so the indexes stay true)
	var slots: Array = (pl["uses"] as Dictionary).keys()
	slots.sort()
	slots.reverse()
	for s in slots:
		var inst = inv[int(s)]
		var units: int = int(pl["uses"][s])
		if int(inst.count) > units:
			inst.count -= units
		else:
			inv.remove_at(int(s))
	if not WorldState.add_to_inventory(str(pl["result"])):
		# no room for the result: undo everything
		inv.clear()
		inv.append_array(before)
		for i in range(before.size()):
			before[i].count = counts[i]
		return {"ok": false, "name": str(pl["name"]), "why": "No room in the pack for it."}
	HUD.selected_slot = inv.find(held) if held != null else -1
	HUD.refresh_inventory()
	return {"ok": true, "name": str(pl["name"]), "why": ""}
