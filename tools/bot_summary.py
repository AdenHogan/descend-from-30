#!/usr/bin/env python3
"""Summarise a folder of descent-bot JSON reports (tools/bot_run.tscn --out=<dir>/<name>.md writes <name>.json beside it).

    python3 tools/bot_summary.py <dir> [--groups prefix1,prefix2,...]

Files are grouped by the part of their name before the first "_" (fighter_424242.json -> group "fighter"), so one sweep folder can
hold several configurations side by side. Prints markdown: per group a table of how far each character-run got, the reach curve
(how many runs got as far as each checkpoint floor), the causes of death, the kit's wear, and the upgrades and boons taken.
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


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    folder = sys.argv[1]
    groups = load(folder)
    only = None
    if "--groups" in sys.argv:
        only = sys.argv[sys.argv.index("--groups") + 1].split(",")
    for name in sorted(groups):
        if only and name not in only:
            continue
        print(summarise(name, groups[name]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
