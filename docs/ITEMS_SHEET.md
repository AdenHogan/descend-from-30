# DF30 — Items Sheet

> Converted from `DF30__ITEMS_SHEET.xlsx` (tabs: ITEMS, ROOM_SPAWN_POOLS).
> **NOTE:** the runtime source of truth is `data/Items.json` — this doc is the
> design reference. If they diverge, `data/Items.json` wins in-game; update
> both when changing item design.
>
> Item **031 Empty Wallet** is listed as junk here but is SUPERSEDED by
> `STORE_DESIGN.md`: the wallet becomes functional (unlocks the HUD wallet).
> Bank Notes are planned as a new id in the 03x range.

## ITEMS

| ID | Name | Properties | Durability / Use | Spawn rarity | Description |
|---|---|---|---|---|---|
| 001 | Knife | is_weapon, is_tool | 7 uses | 2.0 | Point sharp end away from user. The knife is a versatile weapon and tool, but its range is limited. |
| 002 | Hammer | is_weapon, is_tool, can_force_lock | 10 uses | 2.0 | Blunt object goes thwack. Hammers are durable tools that make short work of weak locks and zombie skulls. |
| 003 | Sword | is_weapon | 15 uses | 1.0 | Study the blade. Swords are uncommon but make light slicey work of the zombie menace! |
| 004 | Gun | is_weapon | needs ammo | 1.0 | Pew, pew, pew. Have you ever fired a gun before indoors? They make a lot of noise, and noise draws in enemies! |
| 005 | Canned Food | is_throwable | single use, throwable object | 3.0 | You might not be hungry, but a thrown can makes a lot of noise. Could be a useful distraction. |
| 006 | Bandages | is_health_item | single use, heals 2 states | 2.0 | Walk it off! For boo boos and scrapes, the trusty bandage can get you back on your feet. |
| 007 | First Aid Kit | is_health_item | single use, heals 3 states | 1.0 | When a bandage just won't cut it, turn to the first aid kit. It could save your life. If you manage to find one! |
| 008 | Clothes | is_tool | single use | 3.0 | This is no time for fashion, but clothing could provide new opportunities for the descent. |
| 009 | Torn Clothes | is_health_item | single use, heals 1 state | 2.0 | This fabric is no good for making ropes, but they sure could come in handy as a bandage! |
| 010 | Painkillers | is_health_item | 2 uses, heals 1 state each use | 2.0 | Not feeling your finest? Take a chill pill. Or an actual pill. Seriously, it will help. |
| 011 | Ice Pack | is_speed_boost | 2 uses, restores run ability | 2.0 | For light sprains and minor injuries, the faithful ice pack has helped many a swollen ankle. |
| 012 | Golf Club | is_weapon, can_force_lock | 7 uses | 1.0 | Get a hole in one… zombie skull! A sturdy club can bash brains and locks, no polo shirt required! |
| 013 | Cricket Bat | is_weapon, can_force_lock | 10 uses | 1.0 | This is no test match, this is survival, and a good cricket bat will make light work of wickets, locks, and skulls. |
| 014 | Baseball Bat | is_weapon, can_force_lock | 8 uses | 2.0 | Batter, batter, swing… The baseball bat is a quality blunt force instrument, perfect for bashing brains and doors. |
| 015 | Flashlight | is_tool | requires battery | 2.0 | Hey, who turned out the lights?! It's shocking that at the end of the world, some people didn't pay their electricity bill! |
| 016 | Bullets | is_ammo | per bullet | 2.0 | You can't pew, pew, pew without the metal and gunpowder. You need pew, you need ammo! |
| 017 | Aluminium Baseball Bat | is_weapon, can_force_lock | 15 uses | 1.0 | Light, sturdy and even more durable than a wooden bat. Aluminium is a real… home run! |
| 018 | Rope | is_tool | single use | 1.0 | You were home playing games, and now you're abseiling to the floor below. You really didn't think this through. |
| 019 | Toolbox | is_tool, can_repair | 3 uses | 1.0 | It's like a first aid kit but for items. Need to fix a circuit and get the power back on, or repair an item? YOU NEED TO HAVE YOUR TOOLS! |
| 020 | Fuse | is_tool | single use | 1.0 | Sometimes, a blown fuse is the difference between life and death. Fortunately all building circuit breakers use the same fuses! |
| 021 | Battery | is_tool | single use, holds charge state for power | 2.0 | Who would have thought that the humble battery could be so useful for powering up lights, and elevators. For a time… |
| 022 | Apartment Key | is_key | single use | — | There's a lot of trusting neighbours in this building. |
| 023 | Broken Glass | is_junk | — | — | Useless junk. Sharp enough to cut yourself on, not much else. |
| 024 | Empty Bottle | is_junk | — | — | Useless junk. Could make noise if thrown, but then there would be glass everywhere! |
| 025 | Old Magazine | is_junk | — | — | Useless junk. The crossword is half done. 6 down is Giraffe.. Why did they write Albania?!?!?! |
| 026 | Takeaway Boxes | is_junk | — | — | Useless junk. Whatever was in here, it's long gone. |
| 027 | Dead Plant | is_junk | — | — | Useless junk. Nobody was watering this before the apocalypse either. |
| 028 | Broken Remote | is_junk | — | — | Useless junk. No batteries, no signal, no use. |
| 029 | Pile of Paperwork | is_junk | — | — | Useless junk. Oh, okay, well, that's a lot of bank statements. Wow, that's a lot of debt! |
| 030 | Old Shoes | is_junk | — | — | Useless junk. Wrong size anyway. |
| 031 | Empty Wallet | is_junk → **becomes functional Wallet** | — | — | Useless junk. Money means nothing now. *(Superseded: see STORE_DESIGN.md — unlocks the HUD wallet.)* |
| 032 | Broken Umbrella | is_junk | — | — | Useless junk. Wasn't much use before the world ended either. |

## ROOM_SPAWN_POOLS

Spawn weights per room module (0 = never spawns there):

| ID | Name | bedroom | kitchen | bathroom | study | living_room | dining_room |
|---|---|---|---|---|---|---|---|
| 001 | Knife | 1 | 2 | 0 | 0 | 0 | 2 |
| 002 | Hammer | 1 | 1 | 0 | 1 | 2 | 1 |
| 003 | Sword | 1 | 0 | 0 | 1 | 1 | 0 |
| 004 | Gun | 1 | 0 | 0 | 1 | 1 | 0 |
| 005 | Canned Food | 0 | 3 | 0 | 0 | 0 | 3 |
| 006 | Bandages | 2 | 0 | 3 | 1 | 0 | 0 |
| 007 | First Aid Kit | 0 | 0 | 2 | 0 | 0 | 1 |
| 008 | Clothes | 3 | 0 | 1 | 0 | 1 | 0 |
| 009 | Torn Clothes | 2 | 0 | 1 | 0 | 1 | 1 |
| 010 | Painkillers | 1 | 0 | 3 | 1 | 0 | 0 |
| 011 | Ice Pack | 0 | 0 | 2 | 0 | 1 | 2 |
| 012 | Golf Club | 1 | 0 | 0 | 0 | 2 | 0 |
| 013 | Cricket Bat | 0 | 0 | 0 | 1 | 2 | 0 |
| 014 | Baseball Bat | 1 | 0 | 0 | 0 | 2 | 0 |
| 015 | Flashlight | 2 | 1 | 1 | 2 | 1 | 1 |
| 016 | Bullets | 1 | 0 | 0 | 1 | 1 | 1 |
| 017 | Aluminium Baseball Bat | 1 | 0 | 0 | 0 | 1 | 0 |
| 018 | Rope | 1 | 0 | 0 | 0 | 1 | 0 |
| 019 | Toolbox | 0 | 1 | 0 | 1 | 0 | 1 |
| 020 | Fuse | 0 | 0 | 0 | 2 | 1 | 0 |
| 021 | Battery | 2 | 1 | 1 | 3 | 1 | 1 |
| 022 | Apartment Key | 0 | 0 | 0 | 0 | 0 | 0 |
| 023 | Broken Glass | 2 | 3 | 2 | 1 | 2 | 2 |
| 024 | Empty Bottle | 1 | 3 | 1 | 1 | 2 | 3 |
| 025 | Old Magazine | 3 | 0 | 2 | 3 | 3 | 1 |
| 026 | Takeaway Boxes | 1 | 3 | 0 | 1 | 2 | 3 |
| 027 | Dead Plant | 2 | 1 | 0 | 2 | 3 | 2 |
| 028 | Broken Remote | 2 | 0 | 0 | 2 | 3 | 1 |
| 029 | Pile of Paperwork | 1 | 0 | 0 | 4 | 1 | 2 |
| 030 | Old Shoes | 3 | 0 | 2 | 0 | 1 | 0 |
| 031 | Empty Wallet | 2 | 1 | 1 | 2 | 2 | 1 |
| 032 | Broken Umbrella | 1 | 0 | 0 | 1 | 2 | 1 |

> **Items added after this snapshot** (see `data/Items.json` — the runtime
> source of truth — for full flags + spawn weights):
> - **033 Bank Notes** (`is_money`) — see `docs/STORE_DESIGN.md`.
> - **034 Screwdriver** (`can_force_lock`, 5 uses).
> - **035 Crowbar** (`is_tool, is_crowbar`, single-use/consumed) — the one
>   tool that pries through a stairwell choked with the dead; **not** a weapon.
>   See `docs/STAIR_HORDES.md`.
