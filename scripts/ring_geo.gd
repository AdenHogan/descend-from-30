extends RefCounted

# RING GEOMETRY + the rules for when an inventory ring may open — what the backpack ring (pack_wheel.gd)
# needs. (Owner round 33: the Tab quick wheel was removed as redundant with the pack; this is the part of
# it the pack still uses.)

## Which item of n a pointer offset from the centre points at (item 0 straight up, clockwise); -1 in the dead zone.
static func index_for(offset: Vector2, n: int, dead_zone: float = 40.0) -> int:
	if n <= 0 or offset.length() < dead_zone:
		return -1
	var a: float = fposmod(atan2(offset.x, -offset.y), TAU)        # 0 = straight up, clockwise
	var wedge: float = TAU / float(n)
	return int(round(a / wedge)) % n


## Where item k of n sits on a ring of radius r about c (item 0 at the top, clockwise).
static func slot_position(c: Vector2, k: int, n: int, r: float = 124.0) -> Vector2:
	var a: float = -PI * 0.5 + float(k) * TAU / float(maxi(n, 1))
	return c + Vector2(cos(a), sin(a)) * r


## Why an inventory ring can't open right now, or "" when it can.
static func ui_block_reason(tree: SceneTree) -> String:
	if not HUD.visible:
		return "hud hidden"
	if tree.paused:
		return "paused"
	if not WorldState.has_backpack:
		return "no backpack"            # pockets only: no ring (docs/BACKPACK.md)
	var p = tree.get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		return "no player"
	for flag in ["is_dead", "is_dying", "is_cutscene", "escaping", "is_lashing", "is_listening"]:
		if bool(p.get(flag)):
			return flag
	for m in tree.get_nodes_in_group("modal_panel"):
		if is_instance_valid(m) and m.visible:
			return "a panel is open"
	for m in tree.get_nodes_in_group("loot_ui"):
		if is_instance_valid(m) and "visible" in m and m.visible and not (m.has_method("can_share_screen") and m.can_share_screen()):
			return "loot is open"      # (a found item waiting to be taken CAN share the screen with the pack — make room, then take it)
	if HUD.dialogue_panel != null and HUD.dialogue_panel.visible:
		return "dialogue"
	if HUD.character_panel != null and HUD.character_panel.visible:
		return "journal"
	return ""
