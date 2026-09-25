extends RefCounted

# THE BALCONY'S GEOMETRY — the one source for the art (tools/art/balcony.py reads these numbers), the
# player's plane (player.gd), the enemies' plane (enemy_plane.gd), the descent pan (balcony_pan.gd),
# enemy memory (world_state.gd) and the balcony zone (room.gd). Owner round 14: "move it higher, to
# the wall floor boundary line, as an actual out door area … the Y plane for the balcony needs to be
# higher, and the transition slice to go down to the floor below needs to be higher too".
#
# The balcony is a LOGGIA behind an opening in the back wall of a study / dining room: its floor
# starts at the room's wall/floor seam (the doorway's sill) and recedes UP the screen to the railing
# at the far edge; the city is beyond. World Y in a live room (the module's top is 224, so module-local
# = world - 224); x is from the module's left edge. The room's horizon is its ceiling (local 0), so a
# depth's scale is (local feet y) / 129 — the walking lane's feet (local 129) are 1.0.

const LANE_FEET := 353.0         # the room's walking line (actors' feet)
const FEET := 319.0              # out on the balcony (local 95): between the sill (324) and the rail (310)
const RISE := 34.0               # LANE_FEET - FEET: how far UP a step onto the balcony goes
const SCALE := 0.74              # an actor's size out there (95 / 129)
const HALF_WIDTH := 26.0         # how far either side of the centre an actor's origin may stand
const CENTER_DX := 50.0          # the balcony's centre from the module's left edge
const OPEN_HALF := 38.0          # the doorway's half-width (the opening is x 12..88)
const THRESHOLD_Y := 324.0       # the doorway's sill = the wall/floor seam (local 100)
const EDGE_Y := 310.0            # the far edge of the balcony floor, where the railing stands (local 86)
const RAIL_TOP_Y := 288.0        # the handrail (local 64)
const RAIL_SCALE := 0.67         # an actor's size at the rail (86 / 129)
const LINTEL_Y := 244.0          # the top of the doorway (local 20)
const PLAYER_FEET_OFF := 33.0    # the player's origin → feet (collision bottom)
