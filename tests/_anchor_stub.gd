extends Node2D

## A stand-in scavenge node for tests (loot_ui reads INTERACT_DISTANCE off the node it searches and calls on_search_begin / on_loot_closed if they exist).
const INTERACT_DISTANCE := 90.0

var apartment_id: String = ""      # the node's flat (loot_ui's preview asks which flat's memory to read)
var is_in_range: bool = false      # the real node sets this from the player's distance; a test sets it by hand
