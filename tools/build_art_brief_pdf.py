#!/usr/bin/env python3
"""Build the Descend From 30 art brief PDF for contracting artists.

Combines the written brief with the generated reference sheets and the in-game
screenshots into a designed, multi-page PDF. Screenshots that aren't present yet are
drawn as labelled placeholders (drop them into docs/art_reference/screenshots/ — see the
README there — and re-run). Needs Pillow.

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
    "cap": font(False, 14),
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
        # footer rule
        self.dr.line([(MARGIN, PH - 54), (PW - MARGIN, PH - 54)], fill=LINE)
        self.dr.text((MARGIN, PH - 46), "Descend From 30 — Art Brief", font=F["small"], fill=SUB)
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
            lab = ph_label or "screenshot"
            msg = "DROP: " + lab
            self.dr.text(((PW - self.dr.textlength(msg, font=F["h2"])) // 2, self.y + ph_h // 2 - 20),
                         msg, font=F["h2"], fill=ACCENT)
            hint = "place in docs/art_reference/screenshots/ then re-run the builder"
            self.dr.text(((PW - self.dr.textlength(hint, font=F["small"])) // 2, self.y + ph_h // 2 + 16),
                         hint, font=F["small"], fill=SUB)
            self.y += ph_h + 6
        if caption:
            self.para(caption, "cap", SUB)

    def save(self):
        self.pages[0].save(OUT, save_all=True, append_images=self.pages[1:], resolution=150.0)
        print("wrote", OUT, "(%d pages)" % len(self.pages))


d = Doc()

# ---- Cover ---------------------------------------------------------------
d.dr.text((MARGIN, d.y), "DESCEND FROM 30", font=F["title"], fill=INK)
d.y += F["title"].getbbox("Ag")[3] + 8
d.dr.text((MARGIN, d.y), "Art Brief for contracting pixel artists", font=F["h2"], fill=ACCENT)
d.y += F["h2"].getbbox("Ag")[3] + 18
d.para("A 2D side-scrolling pixel-art roguelike (Godot 4.6). Survivors descend a 30-floor "
       "apartment building during a zombie outbreak — scavenging apartments and fighting "
       "through corridors, floor by floor, to the lobby. One playthrough is three characters "
       "(a morning, an afternoon and a night run) through the same building as it decays. "
       "Everything plays on a single flat walking plane; the camera scrolls left/right.")
d.space(6)
d.subhead("Tone — “cozy horror”")
d.para("Warm, lived-in apartments turned quietly dangerous. Dread comes from atmosphere, "
       "light and decay — not gore-splatter. Grounded, slightly muted palette; strong, "
       "readable silhouettes. The title art below is the mood target.")
d.space(4)
d.subhead("Scope at a glance")
d.para("This is a full game art package, not a one-off: player character sprites (multiple "
       "survivors), enemy sprites, NPCs, inventory + in-world items, environments (varied "
       "corridors, modular rooms, stairwells, elevator, lobby), UI / HUD, and player "
       "health-state portraits. Sections below break each down.", "small", SUB)
d.space(4)
d.image(os.path.join(SHOTS, "title.png"),
        "Title screen — the tone/mood we are aiming for.", ph_label="title.png", ph_h=420)

# ---- Current in-game look -----------------------------------------------
d.heading("Where it is today", "Current build with placeholder art — what you'd be replacing/adding to.")
d.image(os.path.join(SHOTS, "menu.png"),
        "Save-slot / Play menu — UI style + survivor portraits (three runs per save).",
        ph_label="menu.png", ph_h=330)
d.image(os.path.join(SHOTS, "settings.png"),
        "Controls / Settings — UI style, list rows, rebind buttons.",
        ph_label="settings.png", ph_h=330)
d.image(os.path.join(SHOTS, "run1_morning.png"),
        "Run 1 (Morning) — corridor combat. Bright daytime; healthy portrait; sword equipped; "
        "hotbar + floor counter. The colourful blocky figure is the PLACEHOLDER player rig.",
        ph_label="run1_morning.png", ph_h=330)
d.image(os.path.join(SHOTS, "run2_afternoon.png"),
        "Run 2 (Afternoon) — apartment interior (a modular room: Bathroom). Wounded portrait; "
        "gun equipped; a broken/depleted weapon shown greyed in the hotbar.",
        ph_label="run2_afternoon.png", ph_h=330)
d.image(os.path.join(SHOTS, "merchant.png"),
        "Merchant floor — the merchant trades from inside the elevator. Note the warm ceiling "
        "light cones (the engine's dynamic lighting), the wall-mounted fire extinguisher, and a "
        "corpse on the floor. The window sits at the stairwell (right).",
        ph_label="merchant.png", ph_h=330)

# ---- Critical conventions -----------------------------------------------
d.heading("Critical conventions (read first — these prevent re-work)")
d.bullets([
    "ONE FEET BASELINE. Every character/enemy stands on the same floor line. Author each "
    "sheet so the character's FEET sit at a fixed row in the frame, identical across all "
    "frames and all characters; tell us that feet offset. (Our placeholder rigs were authored "
    "at different scales/paddings, so their drawn feet don't line up — the #1 thing to fix.)",
    "AUTHOR ART FLAT / NEUTRALLY LIT — the engine does the lighting. The game adds REAL "
    "dynamic 2D lighting on top (warm lamp pools, fire glow, cool moonlight, darkness). So "
    "NO baked hard highlights or cast shadows on characters/props (a soft contact-shadow "
    "under the feet is welcome). Every asset must still read when the only light on it is a "
    "single warm pool in a near-black room (night).",
    "AUTHOR FACING RIGHT — the engine mirrors for left. Avoid asymmetric details that break "
    "when flipped.",
    "Transparent background, no baked scenery in a character sheet. Pixel-perfect: integer "
    "frames, crisp edges, nearest-neighbour safe.",
])
d.subhead("Scale & density")
d.bullets([
    "Game renders 1152×648, chunky pixels. Standard humanoids read ~90–110 px tall on "
    "screen; author at a tight native frame (~64² for a human, larger for the Big) and we "
    "scale in-engine — deliver native px + the intended scale factor.",
    "Bigger creatures are TALLER, not lower — feet still on the same floor line.",
    "CONSISTENT CHARACTER HEIGHT (important — a live gameplay issue): today's PLACEHOLDER "
    "player reads only ~56 px tall while the zombies are ~84–99 px, so the player is the "
    "odd one out — tall enemies (Long Arm, Spitter) tower and their attacks read as passing "
    "over the player's head. New art must fix this: the player and a standard zombie should "
    "stand at ROUGHLY the same height, with attack reach at a matching level; bigger types "
    "(Big) are taller but proportioned so their hits still land on the player. All feet on "
    "the shared baseline.",
])

# ---- Characters & enemies ----------------------------------------------
d.heading("Characters & enemies", "Placeholder rigs shown at true in-game scale, feet aligned.")
d.image(os.path.join(REF, "enemy_lineup.png"))
d.para("Five enemies. They currently SHARE one rig (reskins) — we need DISTINCT silhouettes: "
       "the Standard zombie; the Big (a larger, heavier zombie with a heavy attack); the Crawler "
       "(low, dragging along the ground); the Long Arm (extended reach); and the Spitter (ranged, "
       "with a spit projectile). Each needs: idle, walk/move, attack, hit/stagger, death.",
       "small", SUB)
d.image(os.path.join(REF, "player_poses.png"))
d.para("The four poses above are stills; the placeholder player rig ALSO already includes full "
       "attack animation sheets (melee swing + gun shoot) and the walk/run/crouch/hurt/death "
       "cycles — all available as reference for timing and frame counts.", "small", SUB)
d.bullets([
    "Player — full set: idle, walk, run, crouch-idle/walk, scavenge, melee attack, gun "
    "(idle/walk/run/shoot), hurt, death, door-approach + knock, balcony rope-lash + climb.",
    "Enemies — Standard, Big (larger, heavy attack), Crawler, Long Arm, Spitter.",
    "NPCs — the Merchant already exists in-game (trades from inside the elevator car); MORE "
    "NPCs will need designing later (e.g. a barricade-keeper survivor, and others as the story "
    "grows).",
])

# ---- Health stages ------------------------------------------------------
d.heading("Player health stages", "The character visibly deteriorates as they take damage.")
d.image(os.path.join(REF, "health_stages.png"))
d.para("Six HUD portrait states, Healthy → Dying (shown bottom-left of the HUD). These are "
       "TEMPORARY and show ONE player character. We plan MULTIPLE playable characters — male "
       "and female body types, up to ~8 potential survivors — and EACH needs the same six "
       "health-state portraits (escalating injury, blood and exhaustion) plus its own full body "
       "sprite set. Match this progression per character.", "small", SUB)

# ---- Environment --------------------------------------------------------
d.heading("Environment & modular rooms")
d.bullets([
    "Corridor / hallway set: wall, baseboard/trim, ceiling, floor — with VARIETY. The player "
    "descends 30 floors; the corridor must NOT feel like the same background 30 times. We need "
    "several corridor variants (layout/decor/wear) AND day-state/immersion differences, so each "
    "stretch feels distinct as you go down (this is separate from the top→bottom decay below).",
    "Apartment doors BY STATE: closed, open, locked, weak/damaged, barricaded, breached.",
    "Stairwells (an up flight + a dark down shaft); windows (stairwell + apartment balcony — "
    "daylight/moonlight comes through these).",
    "Elevator (corridor doors + the interior car), maintenance room (workbench, fuse box), "
    "lobby, and the floor-30 hallway.",
    "MODULAR apartment rooms — bedroom, kitchen, bathroom, study, living room, dining room; "
    "each a self-contained ~320 px-wide module (three sit side by side per apartment), furnished "
    "for scavenging (see the Bathroom shot). Same anti-repetition rule: a FEW variations per room "
    "type, not the same bathroom every time.",
    "Props: crate-stack barricade, corpse, world-drop pickups, keys, wall fire-extinguisher.",
])
d.subhead("Sectional identity — the descent DECAYS (a key pillar)")
d.para("The infection is worst at the bottom, so the building should visibly rot the lower "
       "you go. Deliver corridor + door (ideally room-dressing) variants across three bands:")
d.bullets([
    "Floors 30–21 (top): clean, intact, lived-in.",
    "Floors 20–11 (mid): disturbed — damage, blood, disorder, breaking down.",
    "Floors 10–1 + lobby (bottom): grotesque — heavy infection growth, corruption, ruin.",
])

# ---- Time of day --------------------------------------------------------
d.heading("Time of day", "The ENGINE lights and tints each run dynamically — author art once, neutrally lit.")
d.bullets([
    "MORNING (run 1): bright daytime. Near-fully lit, minimal shadow — art reads at true "
    "colour, the dynamic lighting barely intrudes (see the Morning shot).",
    "AFTERNOON (run 2): a cooler dusk. Warm interior light pools begin to matter against a "
    "colder fill — the cozy-horror contrast starts here (see the Afternoon shot).",
    "NIGHT (run 3): NOT YET FINAL (in development — no shippable night scene to show). Target: "
    "near-black corridors lit ONLY by lamp pools, fire, moonlight through windows, and the "
    "player's faint aura. Enemies lurk unseen in the dark until you're on them (jump-scares). "
    "Deep dread; the building at its most hostile. We want art that survives this: readable in "
    "a single warm pool, sinister in shadow.",
])
d.para("Because the engine handles the light, do NOT deliver separate day/night versions of "
       "an asset unless we ask — one neutral version is lit three ways.", "small", SUB)

# ---- Items --------------------------------------------------------------
d.heading("Items & UI")
d.para("We also need ITEM art — inventory icons and in-world pickups (weapons, tools, medical, "
       "food, junk, keys, cash, etc.), readable at small HUD size. There are ~36 items; a full "
       "per-item spec exists on our side and we'll share it when we get to this — for now, just "
       "flagging that item design is part of the scope.")
d.para("And UI: the HUD (portrait frame, hotbar slots, floor/mode readouts) and menu screens "
       "(title, save-slots, settings) — see the shots on page 2 for the current placeholder "
       "style. A cohesive UI pass is part of the package.", "small", SUB)

# ---- Deliverables -------------------------------------------------------
d.heading("Deliverables & naming")
d.bullets([
    "PNG, transparent, nearest-filter-safe. Sprite sheets as horizontal strips (one animation "
    "per row) or per-file frames — be consistent and tell us the layout.",
    "Per animation: name, frame count, frame size, suggested fps, loop/one-shot, feet offset.",
    "Naming: subject_anim.png — e.g. player_walk.png, zombie_standard_attack.png, "
    "door_barricaded.png, corridor_wall_mid.png.",
    "FIRST: a palette swatch + one “hero” mock of a lit corridor with a character, so we can "
    "lock the look before full sets.",
])

d.save()
