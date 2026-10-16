#!/usr/bin/env python3
"""Summarise a folder of descent-bot JSON reports (tools/bot_run.tscn --out=<dir>/<name>.md writes <name>.json beside it).

    python3 tools/bot_summary.py <dir> [--groups prefix1,prefix2,...]

Files are grouped by the part of their name before the first "_" (fighter_424242.json -> group "fighter"), so one sweep folder can
hold several configurations side by side. Prints markdown: per group a table of how far each character-run got, the reach curve
(how many runs got as far as each checkpoint floor), the causes of death, the kit's wear, and the upgrades and boons taken.

A folder written by tools/bot_sweep.py (round 44) also carries the SCAVENGING record: for each group the apartments entered, what the
nodes held and what the bot did about it, the economy (scrap, notes, the workbench, the merchant), COVERAGE (which parts of the game
the bot actually exercised), ANOMALIES (invariants the watcher saw break, by kind), and the ENGINE LOG (SCRIPT ERROR / ERROR lines,
from the bot's own error hook and from scanning each run's log — `_done.jsonl`).
"""
import json
import os
import statistics
import sys
from collections import Counter, defaultdict

CHECKPOINTS = [29, 25, 20, 15, 10, 5, 1, 0]
MERCHANTS = [25, 20, 15, 10, 5]


def load(folder):
    groups = defaultdict(list)
    for fn in sorted(os.listdir(folder)):
        if not fn.endswith(".json"):
            continue
        try:
            with open(os.path.join(folder, fn)) as f:
                d = json.load(f)
        except (OSError, ValueError):
            continue
        if "runs" not in d:
            continue
        d["_name"] = fn[:-5]
        groups[fn.split("_")[0]].append(d)
    return groups


def kit_state(kit):
    hammers = [p for p in kit.split() if p.startswith("hammer")]
    broken = sum(1 for h in hammers if "broken" in h)
    gun = [p for p in kit.split() if p.startswith("gun(")]
    rounds = int(gun[0][4:-1]) if gun else -1
    kits = sum(1 for p in kit.split() if p == "kit")
    return len(hammers), broken, rounds, kits


def median(xs):
    return statistics.median(xs) if xs else float("nan")


def summarise(name, docs):
    out = []
    out.append("## %s — %d playthroughs" % (name, len(docs)))
    by_run = defaultdict(list)           # run number -> [(seed, run record, floors of that run)]
    for d in docs:
        floors_by_run = defaultdict(list)
        for fl in d["floors"]:
            floors_by_run[int(fl["run"])].append(fl)
        for r in d["runs"]:
            by_run[int(r["run"])].append((d["seed"], r, floors_by_run[int(r["run"])], d))
    out.append("")
    out.append("| run | n | deepest floor: min / median / mean / max | reached lobby | died | stuck/timeout | median time (s) | median kills |")
    out.append("|---|---|---|---|---|---|---|---|")
    for rn in sorted(by_run):
        rows = by_run[rn]
        deep = [int(r["deepest"]) for _, r, _, _ in rows]
        lobby = sum(1 for _, r, _, _ in rows if int(r["deepest"]) == 0)
        dead = sum(1 for _, r, _, _ in rows if r.get("outcome") == "dead")
        stuck = sum(1 for _, r, _, _ in rows if r.get("outcome") in ("stuck", "timeout"))
        times = [float(r["t_end"]) - float(r["t_start"]) for _, r, _, _ in rows if "t_end" in r]
        kills = [int(r["kills"]) for _, r, _, _ in rows]
        out.append("| %d | %d | %d / %.0f / %.1f / %d | %d | %d | %d | %.0f | %.0f |" % (
            rn, len(rows), min(deep), median(deep), statistics.mean(deep), max(deep), lobby, dead, stuck, median(times), median(kills)))
    # reach curve
    out.append("")
    out.append("Reach curve (characters that got AT LEAST as deep as each floor; 30 = everyone):")
    out.append("")
    out.append("| run | " + " | ".join("floor ≤%d" % c if c else "lobby" for c in CHECKPOINTS) + " |")
    out.append("|---|" + "---|" * len(CHECKPOINTS))
    for rn in sorted(by_run):
        rows = by_run[rn]
        cells = []
        for c in CHECKPOINTS:
            n = sum(1 for _, r, _, _ in rows if int(r["deepest"]) <= c)
            cells.append("%d / %d" % (n, len(rows)))
        out.append("| %d | " % rn + " | ".join(cells) + " |")
    # where they died + by whom
    out.append("")
    deaths = [(rn, r) for rn in by_run for _, r, _, _ in by_run[rn] if r.get("outcome") == "dead" and r.get("death")]
    if deaths:
        floors = Counter(int(r["death"]["floor"]) for _, r in deaths)
        out.append("Deaths by floor: " + ", ".join("%d×f%d" % (n, f) for f, n in sorted(floors.items(), reverse=True)))
        killers = Counter()
        for _, r in deaths:
            near = r["death"].get("near") or []
            kinds = sorted(set(n.split()[0] for n in near))
            killers[",".join(kinds) if kinds else "(none close)"] += 1
        out.append("")
        out.append("What stood near at death: " + "; ".join("%s ×%d" % (k, n) for k, n in killers.most_common()))
        t_death = [float(r["death"]["t"]) for _, r in deaths]
        out.append("")
        out.append("Time alive before death: median %.0f s, range %.0f–%.0f s" % (median(t_death), min(t_death), max(t_death)))
    # the barricade story
    out.append("")
    pry_total = 0
    died_after_pry = 0
    first_barr = []
    for rn in by_run:
        for _, r, fls, _ in by_run[rn]:
            prs = [fl for fl in fls if fl.get("pried")]
            pry_total += len(prs)
            if prs:
                first_barr.append(min(int(fl["floor"]) for fl in prs) if False else max(int(fl["floor"]) for fl in prs))
                if r.get("outcome") == "dead" and r.get("death"):
                    last = min(int(fl["floor"]) for fl in prs)
                    if last - int(r["death"]["floor"]) <= 3:
                        died_after_pry += 1
    out.append("Barricaded stairwells met: %d across %d character-runs (%.1f per run); %d runs ended within 3 floors below their last one." % (
        pry_total, sum(len(v) for v in by_run.values()), pry_total / max(1, sum(len(v) for v in by_run.values())), died_after_pry))
    # kit wear
    out.append("")
    both_broken = []
    gun_empty = []
    first_broken = []
    for rn in by_run:
        for _, r, fls, _ in by_run[rn]:
            fb = bb = ge = None
            for fl in fls:
                ham, brk, rounds, _ = kit_state(fl.get("kit_out", fl.get("kit_in", "")))
                if brk >= 1 and fb is None:
                    fb = int(fl["floor"])
                if ham and brk >= ham and bb is None:
                    bb = int(fl["floor"])
                if rounds == 0 and ge is None:
                    ge = int(fl["floor"])
            if fb is not None:
                first_broken.append(fb)
            if bb is not None:
                both_broken.append(bb)
            if ge is not None:
                gun_empty.append(ge)
    n_runs = sum(len(v) for v in by_run.values())
    out.append("Kit wear (over %d character-runs): first hammer broke by floor %s (median, %d runs); both hammers broke by floor %s (%d runs); gun empty by floor %s (%d runs)." % (
        n_runs, "%.0f" % median(first_broken) if first_broken else "—", len(first_broken),
        "%.0f" % median(both_broken) if both_broken else "—", len(both_broken),
        "%.0f" % median(gun_empty) if gun_empty else "—", len(gun_empty)))
    hits_per_run = [int(r["hits"]) for rn in by_run for _, r, _, _ in by_run[rn]]
    heals = [int(r["heals"]) for rn in by_run for _, r, _, _ in by_run[rn]]
    out.append("")
    out.append("Stage-hits absorbed per character-run: median %.0f (min %d, max %d); first aids used: median %.0f. "
               "(Health is five stages and a first aid restores three, so a character that spends both kits and dies has absorbed 11.)" % (
                   median(hits_per_run), min(hits_per_run), max(hits_per_run), median(heals)))
    # merchants
    ups, boons, visits = Counter(), Counter(), Counter()
    offers = sum(len(d.get("upgrades", [])) for d in docs)
    for d in docs:
        for u in d.get("upgrades", []):
            ups[(u.get("name") or u.get("taken") or "?") if isinstance(u, dict) else str(u)] += 1
        for b in d.get("boons", []):
            boons[(b.get("name") or b.get("taken") or "?") if isinstance(b, dict) else str(b)] += 1
        for fl in d["floors"]:
            if int(fl["floor"]) in MERCHANTS:
                visits[int(fl["floor"])] += 1
    out.append("")
    out.append("Merchant floors entered: " + ", ".join("f%d ×%d" % (f, visits[f]) for f in MERCHANTS if visits[f]) +
               "; upgrade picks taken: %d." % offers)
    if ups:
        out.append("")
        out.append("Upgrades taken: " + "; ".join("%s ×%d" % (k, n) for k, n in ups.most_common()))
    if boons:
        out.append("")
        out.append("Boons taken: " + "; ".join("%s ×%d" % (k, n) for k, n in boons.most_common()))
    # per-floor damage: which floors hurt
    out.append("")
    hurt = defaultdict(lambda: [0, 0, 0])      # floor -> [entries, stage-hits, deaths]
    for d in docs:
        for fl in d["floors"]:
            h = hurt[int(fl["floor"])]
            h[0] += 1
            h[1] += int(fl.get("hits", 0))
            h[2] += 1 if fl.get("died") else 0
    worst = sorted(((h[1] / h[0], f, h) for f, h in hurt.items() if h[0] >= 3), reverse=True)[:8]
    out.append("Hardest floors (stage-hits per entry, floors entered ≥3 times): " + "; ".join(
        "f%d %.1f/entry (%d entries, %d deaths)" % (f, per, h[0], h[2]) for per, f, h in worst))
    out.append("")
    return "\n".join(out)


# ---------------------------------------------------------------------------------------------------------------- round 44 sections

EXPECTED_COVERAGE = [
    ("doors_entered", "an apartment door entered"), ("doors_forced", "a shut door forced open"), ("locks_forced", "a locked door forced"),
    ("keys_used", "a key used on its door"), ("barricades_torn", "a barricaded door torn open"), ("breach_entered", "a breach room entered"),
    ("nodes_opened", "a scavenge node searched"), ("items_taken", "an item taken from a node"), ("items_left", "an item left on a node"),
    ("discards", "an item put down for a better one"), ("drops_picked", "a world drop picked up"), ("back_plane_steps", "a set-back node reached"),
    ("ruin_scrap_taken", "scrap taken from a burnt flat"), ("maintenance_entered", "a maintenance room entered"),
    ("fuse_box_pressed", "the fuse box used"), ("fuses_fitted", "a fuse fitted"), ("elevator_powered", "the elevator powered"),
    ("elevator_rides_started", "the elevator ridden"), ("bench_sessions", "the workbench opened"), ("bench_upgrades", "a weapon upgraded"),
    ("bench_tuned", "a weapon tuned"), ("bench_salvaged", "a broken item salvaged"), ("shop_visits", "the merchant's shop used"),
    ("shop_bought", "something bought"), ("shop_sold", "something sold"), ("reloads", "the gun reloaded from the bag"),
    ("repairs", "something mended with a toolbox"), ("molotovs_thrown", "a Molotov thrown"), ("crowbar_liberties", "a crowbar handed over"),
]


def aggregate_cov(docs):
    tot = Counter()
    for d in docs:
        for k, v in (d.get("loot", {}).get("cov", {}) or {}).items():
            try:
                tot[k] += int(v)
            except (TypeError, ValueError):
                pass
    return tot


def band_of(fl):
    return "high 21-29" if fl >= 21 else ("mid 11-20" if fl >= 11 else ("low 1-10" if fl >= 1 else "lobby"))


def loot_sections(name, docs, done):
    """The scavenging half of the report for one configuration. Empty when the group did not scavenge."""
    docs_l = [d for d in docs if d.get("loot", {}).get("apartments") is not None and d.get("loot_mode", "none") != "none"]
    if not docs_l:
        return ""
    out = []
    out.append("### %s — scavenging" % name)
    out.append("")
    apts = [(d["seed"], a) for d in docs_l for a in d["loot"]["apartments"]]
    flats = [(sd, a) for sd, a in apts if a["kind"] == "flat"]
    maint = [(sd, a) for sd, a in apts if a["kind"] == "maint"]
    chars = sum(len(d["runs"]) for d in docs_l)
    out.append("Over %d character-runs the bot went into **%d apartments** and **%d maintenance rooms** (%.1f flats and %.1f staff rooms per character)." % (
        chars, len(flats), len(maint), len(flats) / max(1, chars), len(maint) / max(1, chars)))
    if flats:
        secs = [a["t"] for _, a in flats]
        nodes = [a["nodes"] for _, a in flats]
        srch = [a["searched"] for _, a in flats]
        zin = [a["zombies"] for _, a in flats]
        hurt = sum(1 for _, a in flats if int(a.get("hits", 0)) > 0)
        out.append("")
        out.append("Per flat: %.0f s inside (median; %.0f–%.0f), %.1f nodes opened, %.1f of them held something, %.1f dead met at most at once; the bot took at least one hit in **%d of %d** (%.0f%%)." % (
            median(secs), min(secs), max(secs), statistics.mean(nodes), statistics.mean(srch), statistics.mean(zin), hurt, len(flats), 100.0 * hurt / len(flats)))
        by_run = defaultdict(list)
        for _, a in flats:
            by_run[int(a["run"])].append(a)
        out.append("")
        out.append("| run | flats | s inside (median) | nodes opened / flat | items shown / flat | dead met / flat | kills / flat | stage-hits / flat | flats with a hit |")
        out.append("|---|---|---|---|---|---|---|---|---|")
        for rn in sorted(by_run):
            rows = by_run[rn]
            out.append("| %d | %d | %.0f | %.1f | %.2f | %.1f | %.1f | %.2f | %d%% |" % (rn, len(rows), median([a["t"] for a in rows]), statistics.mean([a["nodes"] for a in rows]),
                                                                          statistics.mean([a["searched"] for a in rows]), statistics.mean([a["zombies"] for a in rows]),
                                                                          statistics.mean([a.get("kills", 0) for a in rows]), statistics.mean([a.get("hits", 0) for a in rows]),
                                                                          100 * sum(1 for a in rows if int(a.get("hits", 0)) > 0) / len(rows)))
        # by how the door stood
        by_door = defaultdict(list)
        for _, a in flats:
            by_door[a.get("door", "") or "?"].append(a)
        out.append("")
        out.append("By how the door stood: " + "; ".join("%s — %d flats, %.2f hits, %.1f kills, %.1f dead met" % (k, len(v), statistics.mean([a.get("hits", 0) for a in v]), statistics.mean([a.get("kills", 0) for a in v]), statistics.mean([a["zombies"] for a in v])) for k, v in sorted(by_door.items(), key=lambda kv: -len(kv[1]))))
        # how a flat ended
        ended = Counter(a.get("ended", "") or "?" for _, a in flats)
        out.append("")
        out.append("How the flats ended: " + ", ".join("%s ×%d" % (k, n) for k, n in ended.most_common()))
    # what the nodes held
    finds = [f for d in docs_l for f in d["loot"].get("finds", [])]
    nodes_opened = sum(int(a["nodes"]) for _, a in apts)
    if finds:
        out.append("")
        out.append("**What the nodes held** (%d items shown across %d nodes opened — %.0f%% of nodes held something):" % (len(finds), nodes_opened, 100.0 * len(finds) / max(1, nodes_opened)))
        by_item = Counter()
        took_item = Counter()
        why_left = Counter()
        for f in finds:
            by_item[f["item"]] += 1
            if f.get("took"):
                took_item[f["item"]] += 1
            else:
                why_left[f.get("why", "?")] += 1
        names = item_names()
        rows = []
        for iid, n in by_item.most_common(14):
            rows.append("%s ×%d (taken %d)" % (names.get(iid, iid), n, took_item[iid]))
        out.append("")
        out.append("; ".join(rows))
        out.append("")
        out.append("Why things were left: " + ", ".join("%s ×%d" % (k, n) for k, n in why_left.most_common()))
        # finds per flat by kind of thing
        def per_flat(pred):
            return sum(1 for f in finds if pred(f["item"])) / max(1, len(flats))
        out.append("")
        out.append("Finds per flat entered: weapons %.2f · bullets %.2f · first aid / bandages / painkillers %.2f · keys %.2f · scrap bags %.2f · cash %.2f · empty wallets %.2f · crowbars %.2f · fuses %.2f" % (
            per_flat(lambda i: i in WEAPONS), per_flat(lambda i: i == "016"), per_flat(lambda i: i in HEALS), per_flat(lambda i: i in KEYS or i.startswith("KEY")),
            per_flat(lambda i: i == "037"), per_flat(lambda i: i == "033"), per_flat(lambda i: i == "031"), per_flat(lambda i: i == "035"), per_flat(lambda i: i == "020")))
        # by band
        out.append("")
        out.append("| band | flats | items shown / flat | weapons / flat | bullets / flat | heals / flat |")
        out.append("|---|---|---|---|---|---|")
        for band in ["high 21-29", "mid 11-20", "low 1-10", "high 21-29+30"]:
            pass
        bands = defaultdict(lambda: [0, 0, 0, 0, 0])
        for _, a in flats:
            bands[band_of(int(a["floor"]))][0] += 1
        for f in finds:
            b = bands[band_of(int(f["floor"]))]
            b[1] += 1
            b[2] += 1 if f["item"] in WEAPONS else 0
            b[3] += 1 if f["item"] == "016" else 0
            b[4] += 1 if f["item"] in HEALS else 0
        for band in ["high 21-29", "mid 11-20", "low 1-10"]:
            b = bands[band]
            if b[0]:
                out.append("| %s | %d | %.2f | %.2f | %.2f | %.2f |" % (band, b[0], b[1] / b[0], b[2] / b[0], b[3] / b[0], b[4] / b[0]))
    # doors passed over
    skips = [sk for d in docs_l for sk in d["loot"].get("skips", [])]
    if skips:
        out.append("")
        out.append("Doors the bot did NOT go through (%d): " % len(skips) + ", ".join("%s ×%d" % (k, n) for k, n in Counter(sk["why"] for sk in skips).most_common()))
    out.append("")
    # economy
    out.append("**Economy per character** (end of the character's life): scrap median %.0f (max %d), notes median %.0f (max %d); workbench upgrades %d, tunings %d, salvaged %d; shop: %d visits, %d things bought, %d notes spent, %d sold." % (
        median([r.get("scrap_end", 0) for d in docs_l for r in d["runs"]]), max([int(r.get("scrap_end", 0)) for d in docs_l for r in d["runs"]] or [0]),
        median([r.get("notes_end", 0) for d in docs_l for r in d["runs"]]), max([int(r.get("notes_end", 0)) for d in docs_l for r in d["runs"]] or [0]),
        sum(int(d["loot"]["cov"].get("bench_upgrades", 0)) for d in docs_l), sum(int(d["loot"]["cov"].get("bench_tuned", 0)) for d in docs_l),
        sum(int(d["loot"]["cov"].get("bench_salvaged", 0)) for d in docs_l), sum(int(d["loot"]["cov"].get("shop_visits", 0)) for d in docs_l),
        sum(int(d["loot"]["cov"].get("shop_bought", 0)) for d in docs_l), sum(int(d["loot"]["cov"].get("shop_notes_spent", 0)) for d in docs_l),
        sum(int(d["loot"]["cov"].get("shop_sold", 0)) for d in docs_l)))
    blocked = Counter()
    for d in docs_l:
        for k, v in d["loot"]["cov"].items():
            if k.startswith("bench_blocked"):
                blocked[k[len("bench_blocked: "):]] += int(v)
    if blocked:
        out.append("")
        out.append("What stopped a weapon going up a level at the bench: " + ", ".join("“%s” ×%d" % (k, n) for k, n in blocked.most_common()))
    out.append("")
    return "\n".join(out)


def item_names():
    names = {}
    try:
        here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        with open(os.path.join(here, "data", "Items.json")) as f:
            data = json.load(f)
        items = data.get("ITEMS", data)
        for k, v in items.items():
            names[k] = v.get("ITEM_NAME", k)
    except (OSError, ValueError):
        pass
    return names


WEAPONS = {"001", "002", "003", "004", "012", "013", "014", "017"}
HEALS = {"006", "007", "010"}
KEYS = {"022", "038"}


def coverage_section(name, docs):
    tot = aggregate_cov(docs)
    out = ["### %s — coverage" % name, ""]
    hit, miss = [], []
    for key, label in EXPECTED_COVERAGE:
        (hit if tot.get(key, 0) > 0 else miss).append((key, label))
    out.append("Exercised: " + ", ".join("%s ×%d" % (label, tot[key]) for key, label in hit) if hit else "Exercised: nothing")
    out.append("")
    out.append("**Never exercised in this configuration:** " + (", ".join(label for _, label in miss) if miss else "(everything on the list was)"))
    out.append("")
    return "\n".join(out)


def anomaly_section(name, docs, done):
    out = ["### %s — anomalies and engine errors" % name, ""]
    by_kind = defaultdict(list)
    for d in docs:
        for a in d.get("anomalies", []):
            by_kind[a["kind"]].append((d["_name"], a))
    if not by_kind:
        out.append("No anomaly was raised by the watcher or the bot in %d playthroughs." % len(docs))
    else:
        out.append("| kind | occurrences | playthroughs | first example |")
        out.append("|---|---|---|---|")
        for kind, rows in sorted(by_kind.items(), key=lambda kv: -len(kv[1])):
            ex = rows[0][1]
            out.append("| %s | %d | %d | %s |" % (kind, len(rows), len(set(n for n, _ in rows)), ("run %d floor %d: %s" % (ex["run"], ex["floor"], ex["msg"].replace("|", "/")))[:230]))
    out.append("")
    # engine log: the bot's own hook ...
    eng = defaultdict(lambda: {"count": 0, "seeds": set(), "rec": None})
    for d in docs:
        for e in (d.get("watch", {}) or {}).get("engine_errors", []):
            if e.get("kind") == "WARNING":
                continue
            r = eng[e["sig"]]
            r["count"] += int(e["count"])
            r["seeds"].add(d["_name"])
            r["rec"] = r["rec"] or e
    if eng:
        out.append("Engine errors caught by the in-game hook (distinct): %d" % len(eng))
        out.append("")
        for sig, r in sorted(eng.items(), key=lambda kv: -kv[1]["count"]):
            e = r["rec"]
            out.append("- **%s/%s** ×%d in %d playthroughs — `%s:%d` %s (first on floor %d, %s)" % (e["kind"], e["owner"], r["count"], len(r["seeds"]), e["file"], e["line"], str(e["msg"])[:200], e["floor"], str(e["scene"]).split("/")[-1]))
        out.append("")
    # … and the log scan
    findings = defaultdict(lambda: {"count": 0, "runs": set(), "at": ""})
    timeouts = []
    for rec in done:
        if rec.get("cfg") != name:
            continue
        if rec.get("exit") not in (0, None):
            timeouts.append(rec)
        for fnd in rec.get("findings", []):
            if fnd["line"].startswith("WARNING"):
                continue
            r = findings[fnd["line"]]
            r["count"] += int(fnd["count"])
            r["runs"].add(rec["name"])
            r["at"] = r["at"] or fnd.get("at", "")
    if findings:
        out.append("Engine findings in the run logs (excluding the exit-time leak notices): %d distinct" % len(findings))
        out.append("")
        for line, r in sorted(findings.items(), key=lambda kv: -kv[1]["count"]):
            out.append("- ×%d in %d runs — `%s` %s" % (r["count"], len(r["runs"]), line, r["at"]))
        out.append("")
    elif done:
        out.append("The run logs held no engine errors (SCRIPT ERROR / ERROR) beyond the exit-time leak notices.")
        out.append("")
    if timeouts:
        out.append("Runs that did not exit cleanly: " + ", ".join("%s (exit %s, %.0f s)" % (r["name"], r["exit"], r["wall"]) for r in timeouts))
        out.append("")
    stuck = [(d["_name"], r) for d in docs for r in d["runs"] if r.get("outcome") in ("stuck", "timeout")]
    if stuck:
        out.append("**Characters the bot could not get further** (stuck / out of time):")
        out.append("")
        for n, r in stuck:
            out.append("- %s run %d (%s) on floor %s: %s" % (n, r["run"], r.get("character", "?"), (r.get("stuck") or {}).get("floor", "?"), str((r.get("stuck") or {}).get("why", r.get("why", "")))[:400]))
        out.append("")
    return "\n".join(out)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    folder = sys.argv[1]
    groups = load(folder)
    only = None
    if "--groups" in sys.argv:
        only = sys.argv[sys.argv.index("--groups") + 1].split(",")
    done = []
    dp = os.path.join(folder, "_done.jsonl")
    if os.path.exists(dp):
        with open(dp) as f:
            for line in f:
                try:
                    done.append(json.loads(line))
                except ValueError:
                    pass
    for name in sorted(groups):
        if only and name not in only:
            continue
        print(summarise(name, groups[name]))
        ls = loot_sections(name, groups[name], done)
        if ls:
            print(ls)
        print(coverage_section(name, groups[name]))
        print(anomaly_section(name, groups[name], done))
    return 0


if __name__ == "__main__":
    sys.exit(main())
