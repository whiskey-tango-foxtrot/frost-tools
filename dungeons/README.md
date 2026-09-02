## Frost Tools: Dungeons

A companion AddOn for [Mythic Dungeon Tools](https://www.curseforge.com/wow/addons/mythic-dungeon-tools) that shows the whole current floor as a map, plots every pull from your saved MDT route on it, and tracks live progress against that route as you clear it.

## Requirements

- **World of Warcraft: Retail**, Midnight (Interface 120100).
- **[Mythic Dungeon Tools](https://www.curseforge.com/wow/addons/mythic-dungeon-tools) must be installed and enabled.** This addon has no route data or dungeon map art of its own — it reads MDT's saved presets (`MythicDungeonToolsDB`) and MDT's own dungeon map/enemy data files at runtime. It will not function without MDT present.
- No other addon dependency. It does **not** require `MythicDungeonTools_NextPullTracker` — progress tracking here is a separate, independent engine (see below), not a read of NPT's state.
- A Bloodlust-class effect landing on you (Bloodlust/Heroism/Time Warp/Ancient Hysteria/Fury of the Aspects/an Engineering item like Drums of Rage) is picked up automatically for the bloodlust readout — no setup needed, but see the caveat under Known Limitations.

## Description

Mythic Dungeon Tools lets you plan pulls on a map. This addon takes that plan into the run: it shows the full floor (not just a zoomed fragment), plots every pull from your route, and tracks how far through it you are by watching the scenario's enemy-forces progress — the same "Enemy Forces" percentage the game's own UI shows — and attributing each increase to your planned pulls in order.

An earlier version of this addon confirmed individual mob kills via the combat log instead. That's no longer possible: Midnight (patch 12.0, March 2026) restricted `COMBAT_LOG_EVENT_UNFILTERED` for addons, the same change that ended WeakAuras' Midnight support and broke the classic approach behind DBM/BigWigs/Plater. Forces-delta tracking — the same technique [MythicDungeonTools_NextPullTracker](https://www.curseforge.com/wow/addons/mdt-next-pull-tracker) uses — is the option that's actually still available. It's a real precision trade-off: no more naming the exact mob you missed, just how far off the planned % you are.

Live map coordinates for a "you are here" dot were also investigated and dropped — not reliably available either, and (before the above was confirmed) the combat log doesn't carry position data regardless.

## Features

- Full-floor route map showing every mob clone on the floor, not just the route: pull-assigned clones are colored by that pull's state (completed / active / next / upcoming) with an MDT-style convex-hull outline and pull number around each group, bosses shown as diamonds, and clones the route intentionally skips shown dimmed — reusing MDT's own dungeon map art
- Live pull tracking from the scenario's enemy-forces progress, including correct handling of boss pulls (usually 0 trash-forces, confirmed via their own scenario completion criterion instead)
- Route-drift warning banner: how far behind/ahead of the planned forces % you currently are
- Bloodlust/Heroism tracking: marks which pull it was used on and counts down to when the shared debuff falls off, without caring who cast it or from what source
- Dungeon / route / floor pickers; floor auto-follows whichever floor the current pull is on
- Pull rows auto-size to their content — a pull with six mob types wraps to fit instead of overlapping the row below, and boss pulls get a ♦ marker matching the map
- Two window layouts, switchable live from Settings without losing your dungeon/route selection:
  - **Single Window** — map, pull list, forces, and bloodlust together in one movable/resizable window
  - **Split Windows** — Map (with the Dungeon/Route/Floor picker built into its top), Pulls, and Forces & Bloodlust as three independently movable and resizable windows
- Standalone — reads MDT's saved route directly, no dependency on any other tracking addon

## Slash Commands

- `/ftd` (or `/fdt`) — toggle the map window (shows it again if you've closed it)
- `/ftd reset` — re-detect the current dungeon and refresh the map
- `/ftd settings` — open the settings panel (drift-warning toggle/threshold, minimap icon)
- `/ftd debug` — print tracking diagnostics to chat (detected dungeon, current pull, forces per pull) — useful if progress ever looks stuck

Click the titlebar's Dungeon / Route / Floor buttons to pick a specific one; by default the dungeon auto-detects from your current zone and the route follows whatever preset MDT itself has selected.

A minimap icon is also available (left-click: toggle the window, right-click: open settings).

## Dependencies

- [MythicDungeonTools](https://www.curseforge.com/wow/addons/mythic-dungeon-tools) (required)

## Known Limitations

- The shared Bloodlust-class debuff is matched against a small table of spell ids (Exhaustion/Sated/Temporal Displacement/Insanity/Fatigued) seeded from general knowledge, not verified against the live game — if a cast isn't picked up, that table is the first thing to check.
- Progress tracking is a forces-percentage estimate, not per-mob confirmation (see Description) — it can't name a specific missed or extra mob, only how far off the planned % you are.
- No live "you are here" position marker — not reliably available to addons.
