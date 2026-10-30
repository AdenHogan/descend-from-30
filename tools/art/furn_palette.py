"""COLOUR HARMONY RULES for the planned rooms (owner round 47h: "recheck colours to make sure furnishings and decorations aren't really too garish against modules… colour matchups need to look
appropriate and appealing… assess the colour wheel").

A piece's colourways were chosen without knowing which wall they would stand against: a rose armchair in the rose-papered parlour, a teal one in the teal living room, an olive sofa under green
wallpaper, a green filing cabinet in the green study — each vanished into the wall (or, in the pink bathroom, a pink tub stood on pink tile). The rule here is the plain one: **a large piece never
shares the hue, saturation and lightness of what it stands against** — the room reads as a flat wash of one colour — so a variant that does is NOT USED in that style (`not` in the variant's params,
read by FurniturePlanner._vid / _any_variant_for and re-checked by validate_state). The browns of wood and leather are exempt: a room may be full of them.

AVOID is generated, then read by a person:  python3 tools/art/colour_audit.py --avoid   (it lists every variant that blends into the wall — or the floor, for a floor piece or a rug — of a style
it can stand in, when the piece has another variant to use). The gate runs `colour_audit.py --check`, which fails when that list is NOT empty after AVOID is applied, so a new piece, variant or
shell that blends in is caught the day it is added.

The other half of the harmony pass lives in the module art itself (one palette, shared by the baked modules and the planned shells): floors and walls are kept from being loud (saturation x value
<= ~0.33: the avocado bathroom's orange lino, the country kitchen's terracotta and the diner's orange parquet were all well past it), and a room is given a complementary or neutral partner for its
main hue (the pink bathroom is pink fixtures on MINT tile; the teen's teal wall has a warm taupe carpet) — see docs/FURNITURE.md "Colour".
"""
import furnlib as FL

AVOID = {
    'armchair': {'club_rose_l58': ['parlour'], 'club_rose_r58': ['parlour'], 'club_rose_l35': ['parlour'], 'club_rose_r35': ['parlour'],
                 'club_teal_l58': ['mid'], 'club_teal_r58': ['mid'], 'club_teal_l35': ['mid'], 'club_teal_r35': ['mid'],
                 'wing_rose_l58': ['parlour'], 'wing_rose_r58': ['parlour'], 'wing_rose_l35': ['parlour'], 'wing_rose_r35': ['parlour'],
                 'wing_teal_l58': ['mid'], 'wing_teal_r58': ['mid'], 'wing_teal_l35': ['mid'], 'wing_teal_r35': ['mid']},
    'filing_cabinet': {'green': ['den']},
    'loveseat': {'olive': ['cosy']},
    'piano_upright': {'ebonised': ['adult', 'formal']},
    'picture_portrait': {'p00': ['adult', 'formal'], 'p11': ['adult', 'formal'], 'p30': ['parlour']},
    'rug_oblong': {'mauve': ['adult', 'teen']},
    'sideboard': {'cream': ['party']},
    'sofa': {'olive': ['cosy']},
    'stool_piano': {'black_maroon': ['cosy', 'den', 'library', 'lodge', 'parlour', 'party', 'sick'], 'black_rose': ['adult'], 'oak_blue': ['studio'],
                    'walnut_rose': ['adult', 'den', 'lodge', 'party', 'sick', 'teen']},
    'trunk': {'green': ['den']},
}


def apply():
    """Write each avoided style into its variant's params as `not` (a piece of a room type that is not built is simply absent)."""
    for pid, variants in AVOID.items():
        pc = FL.REGISTRY.get(pid)
        if pc is None:
            continue
        for vid, styles in variants.items():
            if vid not in pc.variants:
                raise SystemExit('furn_palette: %s has no variant %s' % (pid, vid))
            pc.variants[vid]['not'] = sorted(styles)
