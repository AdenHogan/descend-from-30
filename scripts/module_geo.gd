extends RefCounted

## ONE place that knows how wide a room module is (docs/MODULE_WIDTH.md; owner round 49h: "modules are 20-25 % too wide").
## A flat is `span` modules side by side from LEFT_WALL_X; the art tools (tools/art/pixlib.py `PAD`, `MW`) crop every export to the same width. Anything that needs
## "a module's width", "the flat's right wall" or "where a window sits" asks here, so the change from 320 to 240 is one constant and a regenerate.
## (Not a class_name: preload it, like BalconyGeo.)

const WIDTH := 320                 # a module's width in px (the 144 px height and every Y plane are unchanged)
const LEFT_WALL_X := 113           # world x of the flat's left wall
const WINDOW_INSET := 72.0         # how far in from a module's edge a wall window's centre sits (tools/art/pixlib.WIN_INSET)
const DESIGN_PAD := 0              # columns the ART's design canvas (320 wide, vanishing point x 160) has beyond the module on each side: design x = module x + DESIGN_PAD
                                   # (tools/art/pixlib.PAD — must be equal; furniture lean buckets are keyed by DESIGN x)


## World x of the right wall of a flat of `span` modules.
static func right_x(span: int) -> float:
	return float(LEFT_WALL_X + span * WIDTH)


## The module's own centre (its vanishing point), module-local.
static func centre() -> float:
	return float(WIDTH) * 0.5
