#!/usr/bin/env python3
"""Run the descent bot over many seeds and several CONFIGURATIONS, several godots at a time, and keep everything it said.

    python3 tools/bot_sweep.py <outdir> --seeds 424242,101,102 [--configs none,need,all,god] [--jobs 3] [--timeout 5400] [--speed 8]
                               [--runs 3] [--extra "--elevator"]

A configuration is a name and the bot arguments behind it (docs/BOT_RUNS.md):

    none   the briefed kit only, the crowbar handed over at the first barricade        (the round-43 baseline)
    need   scavenge while the kit is short                                              (a prudent player)
    all    scavenge every door on the way                                               (the stress test)
    safe   scavenge while the kit is short, never enter a breach room                   (a prudent player)
    god    scavenge every door, the player cannot be hurt, ride the lift when powered   (COVERAGE: walks the whole building for errors)
    god2/3 the same, but the 2nd / 3rd character only, from floor 24 down (the decayed building without a three-hour descent)

Every run gets its OWN user:// (XDG_DATA_HOME), so concurrent bots never share a save, a profile or a keybind file. Files land as
<outdir>/<config>_<seed>.{md,json,log}; after each run its log is scanned for engine errors (SCRIPT ERROR, Parse Error, ERROR:) and a
record goes into <outdir>/_done.jsonl. Re-running with the same arguments skips every run whose .json already exists, so a sweep that
was cut off is simply started again. Then:  python3 tools/bot_summary.py <outdir>
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time

CONFIGS = {
    "none": ["--loot=none", "--crowbar=liberty"],
    "need": ["--loot=need"],
    "all": ["--loot=all"],
    "safe": ["--loot=need", "--avoid-breach"],                 # a prudent scavenger: loot while short, never enter a breach room
    # (the coverage configs are handed 3 fuses and some notes — gifts that change the balance and exist ONLY so the fuse box, the lift, the shop's
    #  buy / sell and the workbench get exercised; never used for a balance number)
    "god": ["--loot=all", "--god", "--elevator", "--rest", "--balcony", "--fuses=3", "--notes=300"],
    # the later characters, started part-way down (the world has decayed N-1 time skips): run 2 and 3 content without a 3-hour descent
    "god2": ["--loot=all", "--god", "--elevator", "--rest", "--balcony", "--fuses=3", "--notes=300", "--start-run=2", "--start-floor=24"],
    "god3": ["--loot=all", "--god", "--elevator", "--rest", "--balcony", "--fuses=3", "--notes=300", "--start-run=3", "--start-floor=24"],
}

# lines the engine prints at EVERY exit of a headless run: not findings
BENIGN = re.compile(r"ObjectDB instances leaked|resources still in use|^\s+at: (cleanup|clear)\b|^\s*$|WARNING: ObjectDB|Godot Engine v")
# a finding is a line of one of these shapes
FINDING = re.compile(r"^(SCRIPT ERROR|Parse Error|ERROR|WARNING|USER ERROR|USER WARNING)\b")


def scan_log(path):
    """Distinct engine findings in a bot log, with how many times each was printed."""
    seen = {}
    try:
        with open(path, errors="replace") as f:
            lines = f.read().splitlines()
    except OSError:
        return []
    for i, line in enumerate(lines):
        if BENIGN.search(line):
            continue
        if FINDING.match(line):
            # the line after "ERROR:" often carries the location ("   at: ...")
            where = lines[i + 1].strip() if i + 1 < len(lines) and lines[i + 1].lstrip().startswith("at:") else ""
            key = (line.strip()[:240], where[:160])
            seen[key] = seen.get(key, 0) + 1
    return [{"line": k[0], "at": k[1], "count": n} for k, n in seen.items()]


def run_one(outdir, cfg, seed, args):
    name = "%s_%s" % (cfg, seed)
    md = os.path.join(outdir, name + ".md")
    log = os.path.join(outdir, name + ".log")
    xdg = os.path.join(outdir, "xdg", name)
    os.makedirs(xdg, exist_ok=True)
    cmd = ["godot", "--headless", "res://tools/bot_run.tscn", "--", "--seed=%s" % seed, "--speed=%d" % args.speed,
           "--runs=%d" % args.runs, "--keep-going", "--out=%s" % md] + CONFIGS[cfg] + (args.extra.split() if args.extra else [])
    env = dict(os.environ, XDG_DATA_HOME=xdg)
    lf = open(log, "w")
    t0 = time.time()
    proc = subprocess.Popen(cmd, stdout=lf, stderr=subprocess.STDOUT, env=env, cwd=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    return {"name": name, "cfg": cfg, "seed": seed, "proc": proc, "log": log, "t0": t0, "lf": lf, "deadline": t0 + args.timeout}


def finish(job, outdir, done_f):
    rc = job["proc"].returncode
    job["lf"].close()
    rec = {"name": job["name"], "cfg": job["cfg"], "seed": job["seed"], "exit": rc, "wall": round(time.time() - job["t0"], 1),
           "findings": scan_log(job["log"])}
    done_f.write(json.dumps(rec) + "\n")
    done_f.flush()
    bad = [f for f in rec["findings"] if not f["line"].startswith("WARNING")]
    print("%-18s exit=%s wall=%5.0fs engine-findings=%d%s" % (job["name"], rc, rec["wall"], len(bad), "  <-- TIMEOUT" if rc in (124, -9, -15) else ""), flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("outdir")
    ap.add_argument("--seeds", required=True)
    ap.add_argument("--configs", default="none,need,all,god")
    ap.add_argument("--jobs", type=int, default=3)
    ap.add_argument("--timeout", type=int, default=5400, help="wall seconds per bot run")
    ap.add_argument("--speed", type=int, default=8)
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--extra", default="")
    args = ap.parse_args()
    os.makedirs(args.outdir, exist_ok=True)
    seeds = [s.strip() for s in args.seeds.split(",") if s.strip()]
    cfgs = [c.strip() for c in args.configs.split(",") if c.strip()]
    for c in cfgs:
        if c not in CONFIGS:
            print("unknown config", c, "- known:", ", ".join(CONFIGS))
            return 2
    queue = [(c, s) for s in seeds for c in cfgs if not os.path.exists(os.path.join(args.outdir, "%s_%s.json" % (c, s)))]
    print("%d runs queued (%d skipped, already done), %d at a time" % (len(queue), len(seeds) * len(cfgs) - len(queue), args.jobs), flush=True)
    running = []
    done_f = open(os.path.join(args.outdir, "_done.jsonl"), "a")
    while queue or running:
        while queue and len(running) < args.jobs:
            c, s = queue.pop(0)
            running.append(run_one(args.outdir, c, s, args))
        time.sleep(2.0)
        for job in list(running):
            if job["proc"].poll() is not None:
                running.remove(job)
                finish(job, args.outdir, done_f)
            elif time.time() > job["deadline"]:
                job["proc"].kill()
                job["proc"].wait()
                running.remove(job)
                finish(job, args.outdir, done_f)
    done_f.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
