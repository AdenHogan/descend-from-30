#!/usr/bin/env python3
"""WORDING AUDIT — what the enemies are CALLED where the player can read it (owner 2026-11-14: "then fix text", after the zombies became original monsters).

The enemies are "the things". Nothing the player reads may call them zombies, the dead, the undead, the infected or walkers (CLAUDE.md "Context": nothing may
name or imply what the event IS). Scanned: every item name and description in data/Items.json, and the player-facing strings of the scripts that speak
(HUD, codex, map key, run traces, the rescue line). Code identifiers, groups, scene paths and developer comments are not text and are not scanned.

    python3 tools/wording_audit.py --check
"""
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
BAD = re.compile(r"\b(zombies?|undead|the dead|the infected|infected|walkers?)\b", re.I)
SCRIPTS = ['hud.gd', 'item_codex.gd', 'building_map.gd', 'survivor.gd', 'tutorial_manager.gd', 'quests.gd', 'character_stories.gd', 'loot_ui.gd', 'pause_menu.gd']
STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')


def scan():
    problems = []
    items = json.load(open(os.path.join(ROOT, 'data', 'Items.json')))

    def walk(o, path):
        if isinstance(o, dict):
            for k, v in o.items():
                if k in ('ITEM_NAME', 'ITEM_DESCRIPTION') and isinstance(v, str) and BAD.search(v):
                    problems.append('data/Items.json %s: %r' % (path, v[:90]))
                else:
                    walk(v, path + '/' + str(k))
        elif isinstance(o, list):
            for i, v in enumerate(o):
                walk(v, path + '[%d]' % i)
    walk(items, '')
    for name in SCRIPTS:
        p = os.path.join(ROOT, 'scripts', name)
        if not os.path.exists(p):
            continue
        for ln, line in enumerate(open(p, encoding='utf-8'), 1):
            code = line.split('#')[0] if line.lstrip().startswith('#') is False else ''
            for m in STRING.finditer(code):
                t = m.group(1)
                if 'res://' in t or (' ' not in t and t == t.lower()):
                    continue                                                  # a path, a group or a key (zombie, zombies): an identifier, not text
                if BAD.search(t):
                    problems.append('scripts/%s:%d  %r' % (name, ln, t[:90]))
    # world_state's rescue line lives in a big file: look only at the sentence table's values
    ws = open(os.path.join(ROOT, 'scripts', 'world_state.gd'), encoding='utf-8').read()
    for m in re.finditer(r'"(?:rescue|hider|quest)":\s*"((?:[^"\\]|\\.)*)"', ws):
        if BAD.search(m.group(1)):
            problems.append('scripts/world_state.gd event line: %r' % m.group(1)[:90])
    return problems


def selftest():
    assert BAD.search('loud enough to draw the dead to the noise') and BAD.search('zombie skulls') and BAD.search('Undead') and not BAD.search('draw the things to the noise')
    assert not BAD.search('a dead torch') and not BAD.search('Dead Plant'), 'a battery or a plant being dead is not the word'
    return True


if __name__ == '__main__':
    selftest()
    pr = scan()
    if '--check' in sys.argv:
        if pr:
            print('WORDING: the enemies are "the things" in anything the player reads:')
            print('\n'.join(pr))
            sys.exit(1)
        print('WORDING: nothing the player reads calls the enemies zombies, the dead, the undead or the infected (Items.json + %d scripts)' % len(SCRIPTS))
    else:
        print('\n'.join(pr) or 'clean')
