#!/usr/bin/env python3
"""CONTEXT AUDIT — the art must match the game's context (owner round 47i).

    "We don't want anything related to outbreaks, so no newspapers etc saying evacuate or go north. This event is
     happening brand new so preparedness is not a thing."

The event is SUDDEN and it is happening NOW (one day: morning -> afternoon -> night). So the art may show REACTION —
panic, blood, a barricade made of furniture in a hurry, HELP sheets, boards nailed up today — and it may show ordinary
life interrupted, but it never shows:

    PREPARATION   stockpiles, supply lists, go-bags, camping gear, a survivor's radio room, a map of a safe zone
    AUTHORITY     evacuation / curfew / quarantine notices, rescue teams' marks, news headlines about it
    ELAPSED TIME  tally marks, MISSING posters, "NO FOOD" — anything that needs days to have passed

This gate reads every STRING in the art generators (docstrings and comments are prose about the art, not the art, and
are skipped), every piece id / note / variant in data/furniture.json, and the file names of the generated sprites and
corridor decals, and fails when one matches a pattern below. Run `--check` (the gate does); `--list` prints what it scanned.

To add a new banned idea, add a (label, regex, flags) row to BANNED — and a sample to SAMPLES, which `--check` proves
the row really matches (a check that cannot fail is not a check).
"""
import ast
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ART = os.path.join(ROOT, 'tools', 'art')
SELF = os.path.abspath(__file__)

I = re.IGNORECASE
BANNED = [
    ('evacuation', r'evacuat', I),
    ('outbreak', r'outbreak', I),
    ('quarantine', r'quarantin', I),
    ('curfew', r'curfew', I),
    ('go north / stay in', r'go north|stay in\b|stay indoors|stay inside', I),
    ('a safe zone', r'safe zone|\bSAFE\b', 0),
    ('"no food"', r'no food', I),
    ('"do not open the door"', r"don'?t open|do not open|dont open", I),
    ('a missing-person poster', r'\bMISSING\b|poster_missing|missing_poster|missing_lucy|draw_missing', 0),
    ('ammunition', r'(?<![a-z])ammo(?![a-z])|ammunition', I),
    ('fuel / water stockpile', r'jerry ?can', I),
    ('days counted off', r'\btally\b|tally_marks', I),
    ('survivalist kit', r'prepper|survivalist|stockpil|go-bag|gas mask|gas_mask|survivor radio|survivor\'s radio', I),
    ('camping out', r'camp(ing)? (stove|bed|lantern)|camp_bed|lantern_battery|crates_stove', I),
    ('a stores list', r'\bWATER\b.*\bTINS\b|\bMEDS\b|\bBATTS\b|note_stores', 0),
    ('a rescue mark', r'rescue team|search mark|search_x|door_x\b', I),
    ('biohazard', r'biohazard|hazmat', I),
    ('an old style name', r"\brefuge\b|'barricade'|\"barricade\"", I),
]
SAMPLES = {
    'evacuation': 'EVACUATE', 'outbreak': 'OUTBREAK', 'quarantine': 'notice_quarantine', 'curfew': 'CURFEW 8PM',
    'go north / stay in': 'GO NORTH', 'a safe zone': 'SAFE', '"no food"': 'NO FOOD', '"do not open the door"': 'DONT OPEN',
    'a missing-person poster': 'MISSING', 'ammunition': 'crates_ammo', 'fuel / water stockpile': 'jerrycans',
    'days counted off': 'tally_marks', 'survivalist kit': 'a prepper', 'camping out': 'camping stove',
    'a stores list': 'WATER TINS MEDS BATTS', 'a rescue mark': 'search_x', 'biohazard': 'biohazard',
    'an old style name': 'refuge',
}
COMPILED = [(label, re.compile(pat, fl)) for (label, pat, fl) in BANNED]


def hits(text):
    return [label for (label, rx) in COMPILED if rx.search(text)]


def _py_strings(path):
    """Every string constant in a generator, minus docstrings. -> [(line, text)]"""
    tree = ast.parse(open(path).read(), path)
    skip = set()
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            body = getattr(node, 'body', [])
            if body and isinstance(body[0], ast.Expr) and isinstance(getattr(body[0], 'value', None), ast.Constant) \
                    and isinstance(body[0].value.value, str):
                skip.add(id(body[0].value))
    out = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Constant) and isinstance(node.value, str) and id(node) not in skip:
            out.append((node.lineno, node.value))
    return out


def _gd_strings(path):
    out = []
    for i, line in enumerate(open(path).read().split('\n'), 1):
        line = line.split('#', 1)[0]                                    # the comments are prose
        for m in re.finditer(r'"([^"\n]*)"', line):
            out.append((i, m.group(1)))
    return out


def scan():
    """-> (problems [str], scanned counts {what: n})"""
    problems = []
    n = {'generator strings': 0, 'furniture.json entries': 0, 'sprite / decal names': 0, 'gd strings': 0}
    for fn in sorted(os.listdir(ART)):
        p = os.path.join(ART, fn)
        if not fn.endswith('.py') or os.path.abspath(p) == SELF:
            continue
        for (ln, text) in _py_strings(p):
            n['generator strings'] += 1
            for h in hits(text):
                problems.append('tools/art/%s:%d  %s — %r' % (fn, ln, h, text[:70]))
    fj = os.path.join(ROOT, 'data', 'furniture.json')
    if os.path.exists(fj):
        data = json.load(open(fj))
        for pid, rec in (data.get('items') or {}).items():
            texts = [pid, str(rec.get('note', ''))] + [str(v) for v in (rec.get('variants') or {})] + [str(s) for s in (rec.get('styles') or {})]
            for t in texts:
                n['furniture.json entries'] += 1
                for h in hits(t):
                    problems.append('data/furniture.json  piece %s  %s — %r' % (pid, h, t[:70]))
        for key in (data.get('recipes') or {}):
            n['furniture.json entries'] += 1
            for h in hits(key):
                problems.append('data/furniture.json  recipe %s  %s' % (key, h))
    for sub in (('assets', 'corridor', 'decals'), ('assets', 'furniture')):
        d = os.path.join(ROOT, *sub)
        if os.path.isdir(d):
            for fn in sorted(os.listdir(d)):
                if fn.endswith('.png'):
                    n['sprite / decal names'] += 1
                    for h in hits(fn):
                        problems.append('%s/%s  %s' % ('/'.join(sub), fn, h))
    gd = os.path.join(ROOT, 'scripts', 'corridor_decals.gd')
    if os.path.exists(gd):
        for (ln, text) in _gd_strings(gd):
            n['gd strings'] += 1
            for h in hits(text):
                problems.append('scripts/corridor_decals.gd:%d  %s — %r' % (ln, h, text[:70]))
    return problems, n


def selftest():
    """Every banned idea must really match its sample — otherwise a typo in a pattern would let the idea through."""
    bad = []
    for (label, _pat, _fl) in BANNED:
        s = SAMPLES.get(label)
        if s is None:
            bad.append('no sample for %r' % label)
        elif label not in hits(s):
            bad.append('the %r pattern does not match its own sample %r' % (label, s))
    for ok in ('FIRE EXIT', 'PARCELS', 'WET PAINT', 'PIANO', 'RENT DUE FRI!', 'CAT FOOD', 'the safety plate', 'a bedsit', 'houseshare', 'lost cat'):
        if hits(ok):
            bad.append('%r is ordinary life but matched %s' % (ok, hits(ok)))
    return bad


def main():
    bad = selftest()
    problems, n = scan()
    if '--list' in sys.argv:
        print(json.dumps(n, indent=1))
    for b in bad:
        print('CONTEXT: selftest — ' + b)
    for p in problems:
        print('CONTEXT: ' + p)
    if sum(n.values()) < 500:
        print('CONTEXT: only %d strings scanned — the scan has gone blind' % sum(n.values()))
        bad.append('blind')
    if bad or problems:
        print('CONTEXT: %d problem(s) — the art must match a sudden event that is happening NOW (see this file\'s docstring)' % (len(problems) + len(bad)))
        return 1
    print('CONTEXT: nothing in the art is about preparation, authority or elapsed time (%s)' % ', '.join('%d %s' % (v, k) for k, v in n.items()))
    return 0


if __name__ == '__main__':
    sys.exit(main())
