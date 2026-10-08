class_name CharacterStory
extends RefCounted

# THE FOUR OPENINGS (owner round 37; docs/CHARACTER_STORIES.md). Every run opens on ITS character's own
# small story instead of one shared lockout: a black-screen CUE (a sound) + their first line, then — for the
# two who are locked out of their flat — the knock at 3001, or — for the two who aren't — a single line and on
# they go. Each carries a personal QUEST (an objective that turns over once, when the story's hook happens) that
# shows as a banner and in the journal's Quests page:
#
#   Joe      — banging on his door, locked out, no spare key: he chooses to DESCEND (the tutorial's character, ALWAYS —
#              `WorldState.joe_opens`).
#   Alex     — the super hears a SCREAM from the stairwell and goes to look; on floor 29 he finds a neighbour dead in the
#              corridor ("Mr Hale", whom he knew — the one who screamed), and chooses to descend.
#   Vivianne — her black CAT has got out; she goes after it (the cat is about: a foreground dash + a meow now and then,
#              and on some floors, on the corridor plane — `cat_actor.gd` / `fg_cat.gd`). The cat never dies.
#   Amina    — hungry, nothing in the flat, locked out: she descends to find something to eat — and then to survive.
#
# EVERY LINE BELOW IS A PLACEHOLDER the owner rewrites (like TutorialManager.LINES): keep the keys / structure. Joe's
# lines stay in TutorialManager.LINES (the tutorial's single edit point) and are looked up from there.
# The story hooks (`on_floor_arrival`, `on_item_gained`, `on_cat_seen`, `on_alex_body`) only act once a run's quest has
# BEGUN (WorldState.run_story_stage >= 0) — so a plain `new_game()` in a test never meets one.

const JOE := "blond_man"
const ALEX := "bald_man"
const VIVIANNE := "blond_woman"
const AMINA := "dark_woman"

## The corridor body Alex finds (floor, local x on the corridor art, sprite) — on his way down, mid-corridor.
const ALEX_BODY_FLOOR := 29
const ALEX_BODY_X := 500.0
const ALEX_BODY_SPRITE := "dead_3"
## How often a floor 1-29 has the cat on its corridor plane in Vivianne's run (seeded per floor + run).
const CAT_FLOOR_CHANCE := 0.34


# --- the opening ----------------------------------------------------------------------------------------------

## What a character's run opens with: {cue, line, knock, lockout, walkout}. `cue` is the black-screen sound
## (intro_overlay: "bang" | "scream" | "meow" | "growl"), `line` the first line over it, `knock` whether they step up to
## 3001 and find it locked (then `lockout` plays at the door), else `walkout` is the one line said as they set off.
static func opener(cid: String) -> Dictionary:
	var L: Dictionary = TutorialManager.LINES
	match cid:
		ALEX:
			return {"cue": "scream", "knock": false, "lockout": [],
				"line": "That scream... it came from the stairwell. Somebody's hurt. I'm the super - if anyone's going to check, it's me.",
				"walkout": "The stairwell. That's where it came from."}
		VIVIANNE:
			return {"cue": "meow", "knock": false, "lockout": [],
				"line": "Where did you get to this time? Come on, you never go past the end of the hall...",
				"walkout": "The stairwell door is propped open. She can't have gone far - I'm not leaving her in this."}
		AMINA:
			return {"cue": "growl", "knock": true, "walkout": "",
				"line": "Nothing in the fridge. Nothing in the cupboards. I haven't eaten since yesterday morning...",
				"lockout": ["Great. The door locked behind me - and my keys are inside.",
					"Someone downstairs will have food. Somebody always does."]}
	# Joe (and any character not named above): the original — the knock on his own door.
	return {"cue": "bang", "knock": true, "walkout": "", "line": L["opener_1"],
		"lockout": [L["opener_4"], L["opener_5"] if WorldState.is_first_run else L["opener_5_free"]]}


## The lockout lines for a character, with — for a LATER run — a nod to how the previous character's run ended
## (the old shared lockout's best line, kept for the two who knock).
static func lockout_lines(cid: String, run: int) -> Array:
	var out: Array = opener(cid)["lockout"].duplicate()
	if out.is_empty() or run <= 1:
		return out
	var L: Dictionary = TutorialManager.LINES
	match str(WorldState.chronicle_entry(run - 1).get("outcome", "")):
		"fell": out.append(L["run_after_fell"])
		"escaped": out.append(L["run_after_escaped"])
	return out


# --- the quest ------------------------------------------------------------------------------------------------

## A character's personal quest: {title, stages: [opening objective, the objective once the hook has happened]}.
static func quest(cid: String) -> Dictionary:
	match cid:
		ALEX:
			return {"title": "The scream", "stages": ["Find out who screamed.",
				"Whatever did this is still in the building. Get down."]}
		VIVIANNE:
			return {"title": "Lost cat", "stages": ["Find your cat.", "She keeps running ahead - follow her down."]}
		AMINA:
			return {"title": "Hungry", "stages": ["Find something to eat.", "Eat. Then survive - get out of the building."]}
	return {"title": "Locked out",
		"stages": ["Get the spare key from 3003." if WorldState.is_first_run else "Find a way out of the building.",
			"Get out of the building."]}


static func quest_objective(cid: String, stage: int) -> String:
	var st: Array = quest(cid)["stages"]
	return str(st[clampi(stage, 0, st.size() - 1)])


## The current quest of THIS run's character as shown in the journal: {title, stage, objective, earlier: [done objectives]}.
## Empty when this run's quest hasn't begun.
static func current_quest() -> Dictionary:
	var stage: int = WorldState.run_story_stage
	if stage < 0:
		return {}
	var cid: String = WorldState.current_character()
	var q: Dictionary = quest(cid)
	var earlier: Array = []
	for k in range(mini(stage, q["stages"].size())):
		earlier.append(q["stages"][k])
	return {"title": q["title"], "stage": stage, "objective": quest_objective(cid, stage), "earlier": earlier}


## Begin this run's quest (once): the banner says so. Called when the opening ends (hallway).
static func begin_run_quest() -> void:
	if WorldState.run_story_stage >= 0:
		return
	WorldState.run_story_stage = 0
	var cid: String = WorldState.current_character()
	HUD.show_quest_banner("NEW QUEST", str(quest(cid)["title"]), quest_objective(cid, 0))


## Move the quest on to `to_stage` (never backwards) with an optional spoken line; the banner says so.
static func advance(to_stage: int, say_line: String = "") -> void:
	if to_stage <= WorldState.run_story_stage:
		return
	WorldState.run_story_stage = to_stage
	var cid: String = WorldState.current_character()
	HUD.show_quest_banner("OBJECTIVE UPDATED", str(quest(cid)["title"]), quest_objective(cid, to_stage))
	if say_line != "":
		HUD.show_dialogue(say_line)


static func flag(name: String) -> bool:
	return bool(WorldState.run_story_flags.get(name, false))


static func set_flag(name: String) -> void:
	WorldState.run_story_flags[name] = true


# --- the hooks (each only acts in its own character's run, once, and only after the quest has begun) -------------

## Joe's first descent: he did choose to leave the floor.
static func on_floor_arrival(floor_num: int) -> void:
	if WorldState.run_story_stage != 0 or floor_num > 29:
		return
	if WorldState.current_character() == JOE:
		advance(1)


const AMINA_FOOD := "005"      # Canned Food — the only food there is

static func on_item_gained(item_id: String) -> void:
	if item_id != AMINA_FOOD or WorldState.run_story_stage != 0 or WorldState.current_character() != AMINA:
		return
	advance(1, "Food. A real can of food. Now I just have to survive long enough to open it.")


## Vivianne sees her cat (the foreground dash, or on a floor): the first time says so and the quest turns over.
static func on_cat_seen() -> void:
	if WorldState.current_character() != VIVIANNE or flag("cat_seen") or WorldState.run_story_stage < 0:
		return                       # (during the opening itself nothing is "seen" — the flag must not be spent before the quest begins)
	set_flag("cat_seen")
	advance(1, "There you are! Wait - come back!")


# --- Alex's body on floor 29 -------------------------------------------------------------------------------------

## The scripted corpse in the corridor of this floor, or {} — {name (sprite), pos (local to the corridor art), flip, idx}.
static func alex_body(floor_num: int) -> Dictionary:
	if not WorldState.story_rule or floor_num != ALEX_BODY_FLOOR or WorldState.current_character() != ALEX:
		return {}
	return {"name": ALEX_BODY_SPRITE, "pos": Vector2(ALEX_BODY_X, 0.0), "flip": false, "idx": 90}


## Alex reaches the body: a beat (he knew them), the quest turns over, he chooses to go on down. Once per run.
static func on_alex_body() -> void:
	if WorldState.current_character() != ALEX or flag("alex_body"):
		return
	set_flag("alex_body")
	TutorialManager.prompt("No... Mr Hale. 2904. I fixed his sink last week. He's the one who was screaming.",
		"interact", _alex_body_done, "[continue]")


static func _alex_body_done() -> void:
	advance(1, "There's nothing I can do for him. Whatever did this is still in the building. I'm not staying up here.")


# --- Vivianne's cat -----------------------------------------------------------------------------------------------

## Is the cat on this corridor floor (1-29) in this run? Only in Vivianne's run, a third of the floors, seeded per floor.
static func cat_on_floor(floor_num: int) -> bool:
	if not WorldState.story_rule or WorldState.current_character() != VIVIANNE or floor_num < 1 or floor_num > 29:
		return false
	return cat_roll(floor_num, WorldState.current_run) < CAT_FLOOR_CHANCE


static func cat_roll(floor_num: int, run: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "cat_floor" + str(floor_num) + str(run))
	return rng.randf()


## Where along the corridor the cat starts (world X), seeded per floor + run.
static func cat_start_x(floor_num: int, run: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "cat_x" + str(floor_num) + str(run))
	return rng.randf_range(260.0, 1060.0)
