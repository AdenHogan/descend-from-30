#!/usr/bin/env python3
"""Build the Descend From 30 art brief PDF for contracting artists.

Combines the written brief with the generated reference sheets and the in-game
screenshots into a designed, multi-page PDF. Screenshots that aren't present yet are
drawn as labelled placeholders (drop them into docs/art_reference/screenshots/, see the
README there, and re-run). Needs Pillow.

  python3 tools/build_art_brief_pdf.py   ->   docs/art_reference/Descend_From_30_Art_Brief.pdf
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REF = os.path.join(ROOT, "docs/art_reference/")
SHOTS = os.path.join(REF, "screenshots/")
OUT = os.path.join(REF, "Descend_From_30_Art_Brief.pdf")

# Page: ~150dpi A4 portrait.
PW, PH = 1240, 1754
MARGIN = 78
CW = PW - MARGIN * 2
BG = (24, 20, 30)
INK = (231, 226, 236)
SUB = (156, 148, 166)
ACCENT = (206, 150, 120)
BOX = (44, 38, 52)
LINE = (66, 58, 74)


def font(bold, size):
    n = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/" + n, size)

F = {
    "title": font(True, 46), "h1": font(True, 30), "h2": font(True, 21),
    "body": font(False, 17), "bodyb": font(True, 17), "small": font(False, 14),
    "cap": font(False, 13),
}


class Doc:
    def __init__(self):
        self.pages = []
        self._new()

    def _new(self):
        self.img = Image.new("RGB", (PW, PH), BG)
        self.dr = ImageDraw.Draw(self.img)
        self.y = MARGIN
        self.pages.append(self.img)
        self.dr.line([(MARGIN, PH - 54), (PW - MARGIN, PH - 54)], fill=LINE)
        self.dr.text((MARGIN, PH - 46), "Descend From 30  ·  Art Brief", font=F["small"], fill=SUB)
        n = str(len(self.pages))
        self.dr.text((PW - MARGIN - F["small"].getbbox(n)[2], PH - 46), n, font=F["small"], fill=SUB)

    def space(self, px):
        self.y += px

    def need(self, px):
        if self.y + px > PH - 80:
            self._new()

    def _wrap(self, text, fnt, width):
        words, lines, cur = text.split(), [], ""
        for w in words:
            t = (cur + " " + w).strip()
            if self.dr.textlength(t, font=fnt) <= width:
                cur = t
            else:
                if cur:
                    lines.append(cur)
                cur = w
        if cur:
            lines.append(cur)
        return lines

    def para(self, text, fnt="body", color=INK, lead=7, x=MARGIN, width=CW):
        f = F[fnt]
        lh = f.getbbox("Ag")[3] + lead
        for ln in self._wrap(text, f, width):
            self.need(lh + 4)
            self.dr.text((x, self.y), ln, font=f, fill=color)
            self.y += lh
        self.y += 4

    def heading(self, text, sub=None):
        self.need(70)
        self.space(10)
        self.dr.text((MARGIN, self.y), text, font=F["h1"], fill=INK)
        self.y += F["h1"].getbbox("Ag")[3] + 6
        self.dr.line([(MARGIN, self.y), (MARGIN + 60, self.y)], fill=ACCENT, width=3)
        self.y += 14
        if sub:
            self.para(sub, "small", SUB)

    def subhead(self, text):
        self.need(40)
        self.space(6)
        self.dr.text((MARGIN, self.y), text, font=F["h2"], fill=ACCENT)
        self.y += F["h2"].getbbox("Ag")[3] + 8

    def bullets(self, items):
        f = F["body"]
        lh = f.getbbox("Ag")[3] + 7
        for it in items:
            lines = self._wrap(it, f, CW - 34)
            self.need(lh * len(lines) + 6)
            self.dr.ellipse([(MARGIN + 4, self.y + 8), (MARGIN + 12, self.y + 16)], fill=ACCENT)
            for i, ln in enumerate(lines):
                self.dr.text((MARGIN + 28, self.y), ln, font=f, fill=INK)
                self.y += lh
            self.y += 4

    def image(self, path, caption=None, max_w=CW, ph_label=None, ph_h=360):
        if path and os.path.exists(path):
            im = Image.open(path).convert("RGB")
            w = min(max_w, im.width)
            h = int(im.height * w / im.width)
            self.need(h + 40)
            im = im.resize((w, h), Image.LANCZOS)
            x = MARGIN + (CW - w) // 2
            self.img.paste(im, (x, self.y))
            self.dr.rectangle([x - 1, self.y - 1, x + w, self.y + h], outline=LINE)
            self.y += h + 6
        else:
            self.need(ph_h + 40)
            x0, x1 = MARGIN, MARGIN + CW
            self.dr.rectangle([x0, self.y, x1, self.y + ph_h], fill=BOX, outline=ACCENT, width=2)
            msg = "DROP: " + (ph_label or "screenshot")
            self.dr.text(((PW - self.dr.textlength(msg, font=F["h2"])) // 2, self.y + ph_h // 2 - 20),
                         msg, font=F["h2"], fill=ACCENT)
            hint = "place in docs/art_reference/screenshots/ then re-run the builder"
            self.dr.text(((PW - self.dr.textlength(hint, font=F["small"])) // 2, self.y + ph_h // 2 + 16),
                         hint, font=F["small"], fill=SUB)
            self.y += ph_h + 6
        if caption:
            self.para(caption, "cap", SUB)

    def two_up(self, items, ph_h=190):
        # Small screenshots laid out two per row (saves space vs one big image per line).
        gap = 26
        cell_w = (CW - gap) // 2
        capf = F["cap"]
        caplh = capf.getbbox("Ag")[3] + 3
        i = 0
        while i < len(items):
            pair = items[i:i + 2]
            cells = []
            for (path, cap, lab) in pair:
                if path and os.path.exists(path):
                    im = Image.open(path).convert("RGB")
                    h = int(im.height * cell_w / im.width)
                    cells.append(("img", im.resize((cell_w, h), Image.LANCZOS), h, cap))
                else:
                    cells.append(("ph", lab, ph_h, cap))
            img_h = max(c[2] for c in cells)
            cap_lines = max(len(self._wrap(c[3], capf, cell_w)) for c in cells)
            row_h = img_h + 8 + cap_lines * caplh + 12
            self.need(row_h)
            y0 = self.y
            for idx, c in enumerate(cells):
                x = MARGIN + idx * (cell_w + gap)
                if c[0] == "img":
                    self.img.paste(c[1], (x, y0))
                    self.dr.rectangle([x - 1, y0 - 1, x + cell_w, y0 + c[2]], outline=LINE)
                else:
                    self.dr.rectangle([x, y0, x + cell_w, y0 + ph_h], fill=BOX, outline=ACCENT, width=2)
                    msg = "DROP: " + c[1]
                    self.dr.text((x + (cell_w - self.dr.textlength(msg, font=F["small"])) // 2,
                                  y0 + ph_h // 2 - 8), msg, font=F["small"], fill=ACCENT)
                cy = y0 + img_h + 8
                for ln in self._wrap(c[3], capf, cell_w):
                    self.dr.text((x, cy), ln, font=capf, fill=SUB)
                    cy += caplh
            self.y = y0 + row_h
            i += 2

    def save(self):
        self.pages[0].save(OUT, save_all=True, append_images=self.pages[1:], resolution=150.0)
        print("wrote", OUT, "(%d pages)" % len(self.pages))
        if os.environ.get("DUMP_PNG"):
            for i, pg in enumerate(self.pages):
                p = os.path.join(os.path.dirname(OUT), "_page%d.png" % (i + 1))
                pg.save(p)
                print("dumped", p)


d = Doc()

# ---- Cover ---------------------------------------------------------------
d.dr.text((MARGIN, d.y), "DESCEND FROM 30", font=F["title"], fill=INK)
# Studio + contact block, right-aligned against the title.
_studio = "Mammoth Games"
d.dr.text((PW - MARGIN - d.dr.textlength(_studio, font=F["h2"]), d.y + 6), _studio, font=F["h2"], fill=ACCENT)
for _i, _line in enumerate(["Project lead: Aden Hogan", "adenhoganej@gmail.com"]):
    d.dr.text((PW - MARGIN - d.dr.textlength(_line, font=F["small"]), d.y + 40 + _i * 20),
              _line, font=F["small"], fill=SUB)
d.y += F["title"].getbbox("Ag")[3] + 8
d.dr.text((MARGIN, d.y), "Art brief for contracting artists", font=F["h2"], fill=ACCENT)
d.y += F["h2"].getbbox("Ag")[3] + 18
d.para("A 2D side-scrolling roguelike (Godot 4.6). Survivors descend a 30-floor apartment "
       "building during a zombie outbreak, scavenging apartments and fighting through corridors, "
       "floor by floor, to the lobby. One playthrough is three characters (a morning, an "
       "afternoon and a night run) through the same building as it decays. Everything plays on "
       "a single flat walking plane; the camera scrolls left and right.")
d.space(6)
d.subhead("Tone: “cozy horror”")
d.para("Warm, lived-in apartments turned dangerous. The dread comes mostly from atmosphere, "
       "light and decay, but blood and gore are welcome as an element where a scene earns it "
       "(a mauled corpse, a blood-slick floor, a spatter up a wall). Grounded, slightly muted "
       "palette; strong, readable silhouettes. The title art below is the mood target.")
d.space(4)
d.subhead("Art style: open")
d.para("Pixel art is one good fit but NOT the only one. A painterly / cartoon full-art style "
       "would suit this vibe just as well, for example Valiant Hearts: The Great War. Pitch "
       "whichever style you are strongest in; what matters is the tone and readability set out "
       "here, not the medium. (The current placeholders happen to be pixel art.)")
d.space(4)
d.subhead("Scope at a glance")
d.para("This is a full game art package, not a one-off: player character sprites (multiple "
       "survivors), enemy sprites, NPCs, inventory and in-world items, environments (varied "
       "corridors, modular rooms, stairwells, elevator, lobby), UI and HUD, and player "
       "health-state portraits. Sections below break each down.", "small", SUB)
d.space(4)
d.subhead("First priority: the game logo")
d.para("Before the full asset sets, we need a real GAME LOGO / title wordmark for "
       "“Descend From 30”, the single most visible piece of art (title screen, store "
       "page, marketing, app icon). The title screen today uses a plain pixel font (see below) "
       "and needs a designed logo. Deliver: (1) the full logo (any mark plus the wordmark), "
       "(2) a wordmark-only lockup, and (3) a small square app-icon / favicon mark that still "
       "reads at about 32-64 px. Supply light-on-dark and dark-on-light versions on transparent "
       "backgrounds, make it scalable (vector or high-resolution), and carry the cozy-horror tone "
       "(an ordinary building gone wrong, a sense of descent). Studio name for any credit lockup: "
       "Mammoth Games.")
d.space(4)
d.image(os.path.join(SHOTS, "title.png"),
        "Title screen: the tone and mood we are aiming for (and the plain placeholder title the "
        "new logo replaces).", ph_label="title.png", ph_h=420)

# ---- Current in-game look -----------------------------------------------
d.heading("Where it is today",
          "Current build with placeholder art (what you would be replacing or adding to). "
          "These are quick flavour scenes, shown small for reference.")
d.two_up([
    (os.path.join(SHOTS, "menu.png"),
     "Save-slot / Play menu: UI style + survivor portraits (three runs per save).", "menu.png"),
    (os.path.join(SHOTS, "settings.png"),
     "Controls / Settings: UI style, list rows, rebind buttons.", "settings.png"),
])
d.two_up([
    (os.path.join(SHOTS, "run1_morning.png"),
     "Run 1 (Morning): corridor combat. Bright daytime, healthy portrait, sword equipped. "
     "The colourful blocky figure is the PLACEHOLDER player.", "run1_morning.png"),
    (os.path.join(SHOTS, "run2_afternoon.png"),
     "Run 2 (Afternoon): a modular apartment room (Bathroom). Wounded portrait, gun equipped, "
     "a broken weapon greyed in the hotbar.", "run2_afternoon.png"),
])
d.two_up([
    (os.path.join(SHOTS, "merchant.png"),
     "Merchant floor: trades from the elevator. Note the warm ceiling light cones (engine "
     "lighting), the wall fire-extinguisher, and a corpse on the floor.", "merchant.png"),
    (os.path.join(SHOTS, "attack.png"),
     "Combat swing: the melee attack VFX (sword, the pink slash) inside an apartment "
     "(Bedroom).", "attack.png"),
])

# ---- Critical conventions -----------------------------------------------
d.heading("Critical conventions (read first, these prevent re-work)")
d.bullets([
    "ONE FEET BASELINE. Every character and enemy stands on the same floor line. Author each "
    "sheet so the character's FEET sit at a fixed row in the frame, identical across all frames "
    "and all characters; tell us that feet offset. (Our placeholder rigs were authored at "
    "different scales and paddings, so their drawn feet don't line up: the #1 thing to fix.)",
    "AUTHOR ART FLAT / NEUTRALLY LIT: the engine does the lighting. The game adds REAL dynamic "
    "2D lighting on top (warm lamp pools, fire glow, cool moonlight, darkness). So no baked hard "
    "highlights or cast shadows on characters or props (a soft contact-shadow under the feet is "
    "welcome). Every asset must still read when the only light on it is a single warm pool in a "
    "near-black room (night).",
    "AUTHOR FACING RIGHT: the engine mirrors for left. Avoid asymmetric details that break "
    "when flipped.",
    "MEDIUM: pixel art OR painterly / cartoon full-art are both welcome. If pixel, keep it "
    "pixel-perfect (integer frames, nearest-neighbour, crisp edges). If full-art, deliver clean "
    "high-resolution art with transparent backgrounds; we scale to fit.",
    "Transparent background, no baked scenery inside a character sheet.",
])
d.subhead("Scale & density")
d.bullets([
    "The game renders at 1152x648. Standard humanoids read about 90-110 px tall on screen; "
    "deliver at a comfortable native size plus the intended in-game scale and we scale to fit.",
    "Bigger creatures are TALLER, not lower; feet still on the same floor line.",
    "CONSISTENT CHARACTER HEIGHT (important, a live gameplay issue): today's PLACEHOLDER player "
    "reads only about 56 px tall while the zombies are 84-99 px, so the player is the odd one "
    "out and tall enemies (Long Arm, Spitter) tower, their attacks reading as passing over the "
    "player's head. New art must fix this: the player and a standard zombie should stand at "
    "ROUGHLY the same height, with attack reach at a matching level; bigger types (Big) are "
    "taller but proportioned so their hits still land. All feet on the shared baseline.",
])

# ---- Characters & enemies ----------------------------------------------
d.heading("Characters & enemies", "Placeholder rigs shown at true in-game scale, feet aligned.")
d.image(os.path.join(REF, "enemy_lineup.png"))
d.para("Five enemies. They currently SHARE one rig (reskins), so we need DISTINCT silhouettes: "
       "the Standard zombie; the Big (a larger, heavier zombie with a heavy attack); the Crawler "
       "(low, dragging along the ground); the Long Arm (extended reach); and the Spitter (ranged, "
       "with a spit projectile). Each needs idle, walk or move, attack, hit or stagger, death.",
       "small", SUB)
d.image(os.path.join(REF, "player_poses.png"))
d.para("The four poses above are stills; the placeholder player rig ALSO already includes full "
       "attack animation sheets (melee swing and gun shoot) and the walk / run / crouch / hurt / "
       "death cycles, all available as reference for timing and frame counts.", "small", SUB)
d.bullets([
    "Player: full set. Idle, walk, run, crouch-idle/walk, scavenge, melee attack, gun "
    "(idle/walk/run/shoot), hurt, death, door-approach and knock, balcony rope-lash and climb.",
    "Enemies: Standard, Big (larger, heavy attack), Crawler, Long Arm, Spitter.",
    "NPCs: the Merchant already exists in-game (trades from inside the elevator car); MORE NPCs "
    "will need designing later (e.g. a barricade-keeper survivor, and others as the story grows).",
])

# ---- Health stages ------------------------------------------------------
d.heading("Player health stages", "The character visibly deteriorates as they take damage.")
d.image(os.path.join(REF, "health_stages.png"))
d.para("Six HUD portrait states, Healthy to Dying (shown bottom-left of the HUD). These are "
       "TEMPORARY and show ONE player character. We plan MULTIPLE playable characters, male and "
       "female body types, up to about 8 potential survivors, and EACH needs the same six "
       "health-state portraits (escalating injury, blood and exhaustion) plus its own full body "
       "sprite set. Match this progression per character.", "small", SUB)

# ---- Environment --------------------------------------------------------
d.heading("Environment & modular rooms")
d.bullets([
    "Corridor / hallway set: wall, baseboard/trim, ceiling, floor, WITH VARIETY. The player "
    "descends 30 floors; the corridor must NOT feel like the same background 30 times. We need "
    "several corridor variants (layout, decor, wear) plus immersion differences so each stretch "
    "feels distinct as you go down (this is separate from the top-to-bottom decay below).",
    "Apartment doors BY STATE: closed, open, locked, weak/damaged, barricaded, breached.",
    "Stairwells (an up flight and a dark down shaft); windows (stairwell and apartment balcony, "
    "daylight and moonlight come through these).",
    "Elevator (corridor doors and the interior car), maintenance room (workbench, fuse box), "
    "lobby, and the floor-30 hallway.",
    "MODULAR apartment rooms: bedroom, kitchen, bathroom, study, living room, dining room; each "
    "a self-contained ~320 px-wide module (three sit side by side per apartment), furnished for "
    "scavenging (see the Bathroom shot). Same anti-repetition rule: a FEW variations per room "
    "type, not the same bathroom every time.",
    "Props: crate-stack barricade, corpse, world-drop pickups, keys, wall fire-extinguisher.",
])
d.subhead("Exact scene dimensions (measured in-engine)")
d.para("The world is a 16x16 px tile grid at scale 1.0, and all corridor actors share one "
       "feet/floor line at world-Y 419. Author environment art to these footprints (native px) "
       "or a clean multiple, and tell us your tile size:")
d.bullets([
    "Screen / viewport: 1152 x 648 px (fixed render resolution).",
    "Corridor, floors 1-29 (the main repeated set): 1120 x 192 px (70 x 12 tiles). Feet line "
    "Y 419; visible floor-to-ceiling band Y 243-435. Needs the variety + decay variants.",
    "Hallway, floor 30 (tutorial): 1120 x 240 px, same width as a corridor.",
    "Lobby (ground floor): 1120 x 176 px.",
    "Apartment shell: 992 x 160 px, the container the three room modules sit inside; floor Y 352.",
    "Apartment ROOM MODULE: 320 x 144 px (20 x 9 tiles), one furnished room. THREE sit side by "
    "side to form an apartment, this is the key modular unit; author each room type to exactly "
    "320 x 144 with the floor at the bottom.",
    "Maintenance room: 416 x 176 px (workbench + fuse box).",
    "Elevator car interior: 192 x 160 px, the drawn car (roomy enough for a second occupant), "
    "centred in a full-screen dark shaft, so also supply the surrounding shaft/void treatment.",
])
d.subhead("Sectional identity: the descent DECAYS (a key pillar)")
d.para("The infection is worst at the bottom, so the building should visibly rot the lower you "
       "go. Deliver corridor and door (ideally room-dressing) variants across three bands:")
d.bullets([
    "Floors 30-21 (top): clean, intact, lived-in.",
    "Floors 20-11 (mid): disturbed, damage, blood, disorder, breaking down.",
    "Floors 10-1 and the lobby (bottom): grotesque, heavy infection growth, corruption, ruin.",
])

# ---- Time of day --------------------------------------------------------
d.heading("Time of day", "The ENGINE lights and tints each run dynamically, so author art once, neutrally lit.")
d.bullets([
    "MORNING (run 1): bright daytime. Near-fully lit, minimal shadow, art reads at true colour "
    "and the dynamic lighting barely intrudes (see the Morning shot).",
    "AFTERNOON (run 2): a cooler dusk. Warm interior light pools begin to matter against a colder "
    "fill; the cozy-horror contrast starts here (see the Afternoon shot).",
    "NIGHT (run 3): NOT YET FINAL (in development, no shippable night scene to show). Target: "
    "near-black corridors lit ONLY by lamp pools, fire, moonlight through windows, and the "
    "player's faint aura. Enemies lurk unseen in the dark until you are on them (jump-scares). "
    "Deep dread, the building at its most hostile. We want art that survives this: readable in a "
    "single warm pool, sinister in shadow.",
])
d.para("Because the engine handles the light, do NOT deliver separate day and night versions of "
       "an asset unless we ask; one neutral version is lit three ways.", "small", SUB)

# ---- Items & UI ---------------------------------------------------------
d.heading("Items & UI")
d.para("We also need ITEM art: inventory icons and in-world pickups (weapons, tools, medical, "
       "food, junk, keys, cash, and so on), readable at small HUD size. There are about 36 items; "
       "a full per-item spec exists on our side and we will share it when we get to this. For now, "
       "just flagging that item design is part of the scope.")
d.para("And UI: the HUD (portrait frame, hotbar slots, floor and mode readouts) and menu screens "
       "(title, save-slots, settings), see the shots on page 2 for the current placeholder style. "
       "A cohesive UI pass is part of the package.", "small", SUB)

# ---- Deliverables -------------------------------------------------------
d.heading("Deliverables & naming")
d.bullets([
    "Clean art with transparent backgrounds. Sprite sheets as horizontal strips (one animation "
    "per row) or per-file frames; be consistent and tell us the layout.",
    "Per animation: name, frame count, frame size, suggested fps, loop or one-shot, feet offset.",
    "Naming: subject_anim.png, e.g. player_walk.png, zombie_standard_attack.png, "
    "door_barricaded.png, corridor_wall_mid.png.",
    "FIRST: a palette / style swatch and one “hero” mock of a lit corridor with a "
    "character, so we can lock the look before full sets.",
])

d.save()
