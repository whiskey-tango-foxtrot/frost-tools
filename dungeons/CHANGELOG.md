# Frost Tools: Dungeons — Changelog

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
