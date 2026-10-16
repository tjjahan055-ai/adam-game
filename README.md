# Adam: City Fixer (working title)

A single-player puzzle adventure for mobile (ages 10-17). Adam repairs a broken modern city, one district at a time.

**Status:** Milestone 1 greybox prototype. Plain shapes, no final art. Design documents are kept in the SkillNexus360 Venture Cell project folder.

## What works now
- Mechanic 2, **routing**: lay cable from the substation to every building, using a limited set of pieces (straight, corner, splitter). Tap a square to place, tap a cable to turn it, press and hold to take it back.
- Three levels (`levels/route/r01.json` to `r03.json`), a level map, stars (solve / best cable count / no hints), a hint that shows the next move of a shortest solution, and progress saved on the device.
- No network use, no accounts, no ads, no data collected.

## Engine and setup
- Godot **4.5.1** stable (GDScript), Compatibility renderer, portrait 720x1280.
- Open the folder in Godot 4.5.1 and press Play. No plugins or add-ons.

## Project layout
| Path | Purpose |
|---|---|
| `scripts/route/route_board.gd` | Rules of the routing puzzle (no drawing) |
| `scripts/route/route_solver.gd` | Finds a shortest solution; used by tests and the hint |
| `scripts/route/route_view.gd` | Draws the board and turns taps into moves |
| `scripts/core/level_loader.gd` | Reads level JSON files |
| `scripts/core/save_game.gd` | Local save with backup (autoload `SaveGame`) |
| `scripts/ui/` | Map screen, level screen, shared UI helpers |
| `levels/route/` | Level data |
| `tests/` | Automated tests |

## Level file format
```json
{"id": "r01", "title": "Kiosk Row", "intro": "One-line briefing.",
 "width": 5, "height": 3, "par": 3,
 "cells": [{"x": 0, "y": 1, "type": "source", "sides": "E"},
           {"x": 4, "y": 1, "type": "target"},
           {"x": 1, "y": 0, "type": "block"}],
 "inventory": {"straight": 3, "corner": 0, "tee": 0}}
```
`type` is `source`, `target`, `block` or `wire` (a fixed cable). `sides` lists open sides (N, E, S, W). `par` must equal the length of the shortest solution; the tests enforce this.

## Tests
```
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd          # rules, every level solvable at par, save/load
xvfb-run godot --path . --script res://tests/playthrough.gd -- /tmp/shots   # plays each level with real taps, saves screenshots
```

## Builds
GitHub Actions (`.github/workflows/build.yml`) runs the tests and exports an Android APK and a web build on every pull request. On `main` it also publishes the APK as the **prototype** release and the web build to the `gh-pages` branch. The APK is signed with a throwaway debug key: for playtests only, not for the Play Store.

See `CHANGELOG.md` for changes and known issues.
