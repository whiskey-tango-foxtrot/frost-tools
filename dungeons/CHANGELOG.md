# Frost Tools: Dungeons — Changelog

## 1.0.2

### Fixed

**World of Warcraft 12.1.5 / MythicDungeonTools 6.3 compatibility.**

- The TOC now declares Interface `120105` (12.1.5) alongside `120100`, so the
  addon is no longer flagged out of date on a 12.1.5 client.
- MDT 6.2.17 and later dungeon files call `MDT:RegisterDungeonLocation(...)`
  instead of writing `MDT.zoneIdToDungeonIdx` directly. Because this addon
  loads those files into its own adapter table, that method has to exist
  there: without it every Midnight dungeon file errored on load before it had
  assigned its map, forces-total and enemy tables, so every dungeon showed as
  having no enemy data. The adapter now provides it, with the same
  shared-zone / entrance-subzone priority rules as MDT's own implementation.
- Dungeon auto-detection outside a keystone now uses that zone + subzone
  lookup, matching how MDT resolves zones several dungeons share (e.g.
  Eversong Woods).

Requires MythicDungeonTools 6.3.6 or newer on 12.1.5.

## 1.0.1

### New

**Boss tactics callout** — the Forces & Bloodlust panel now surfaces a short
reminder for the next upcoming boss pull, a few trash pulls ahead of time
rather than only on the boss's own pull.

- Auto-detects the next boss in your route and shows up to 2 short tips for
  it, with `TANK:`/`HEAL:`/`DPS:` prefixes color-coded when a tip calls out
  a role.
- If the window has enough room, additional upcoming bosses stack in below
  as "Then: `<boss>`" cards — the window is never resized to make room on
  its own, so this only appears when you've sized the window for it.
- Ships with starter tips for all 8 current-season dungeons in
  `Modules/TacticsData.lua`, keyed by the boss name MDT itself reports.
  These are a starting point, not a guarantee of accuracy — verify boss-name
  keys and tip text against `/ftd debug`, which now also prints each boss
  pull's exact name and whether tactics data matched it.
- Fully edit-your-own: add, remove, or rewrite entries in
  `Modules/TacticsData.lua` freely.
