# Tactical Commands: Frontlines

PC RTS card game built with Godot 4 (GDScript). Design: `docs/TCF_交接摘要.md`.

## Run
1. Install Godot 4.7 (standard build, not .NET): https://godotengine.org/download
2. Open Godot, Import, pick `project.godot` in this folder, then press F5.

Controls: left-click select, left-drag box select (Shift adds), right-click move (on an enemy: attack), Ctrl + right-click force-attack any unit, H hold position (infantry), X stop. Camera: wheel zoom, middle-drag or Space + left-drag pan, WASD / arrows / screen edge scroll, F fit map, G grid.

## Test
```sh
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
```

## Layout
- `scripts/sim/` simulation data and rules. No nodes, no rendering, no engine physics; integer grids so it stays deterministic. `Simulation` runs at 20 ticks/s and changes only through `SimCommand`s; randomness comes from `SimRng`.
- `scripts/data/` loading maps from disk.
- `scripts/render/`, `scripts/input/`, `scripts/ui/` what the player sees and touches.
- `scenes/main.tscn` the map view.
- `maps/<id>/` `terrain.png` (1 px = 1 cell), `height.png` (4 grey levels), `map.json`. Map PNGs must be imported as **Image** (Import dock, Import As: Image).

The earlier TypeScript + Phaser version was removed; it is in git history up to commit `5777bc0`.
