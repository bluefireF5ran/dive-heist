# AGENTS.md

Dive Heist — Godot 4.6 vertical-descent roguelike (GDScript).

## Quick start

- **Run:** Open in Godot 4.6 editor, press **F5**. No test framework — manual playtesting only.
- **Read first:** `ARCHITECTURE.md` (technical reference) and `GDD.md` (game design, Spanish).

## Commands

```bash
gdlint Scenes/                    # Lint all GDScript
gdformat Scenes/                  # Format all files in-place
```

## Scene hierarchy

```
main_menu.tscn → fade → world.tscn
  ├── Player (CharacterBody2D, group "player")
  ├── Camera2D (only descends, never rises)
  ├── ChunkGenerator (procedural spawn/despawn)
  └── AmmoHUD (CanvasLayer → AmmoBar _draw renderer)
```

## Critical conventions

- **Collision layers:** 1=World, 2=Player, 4=Enemies (powers of 2)
- **Signals:** Connected in `_ready()` via code, never in editor
- **SFX:** Always `SFX.play_*()` via autoload — never direct AudioStreamPlayer
- **Player lookup:** `get_tree().get_first_node_in_group("player")`
- **World access:** `get_tree().current_scene` for `screen_shake()`, `hitstop()`, adding children
- **`world.gd`** uses `process_mode = PROCESS_MODE_ALWAYS` so hitstop timers work while tree is paused
- **Code in English**, design docs (GDD.md) in Spanish
- **Naming:** `snake_case` for files/variables/functions, `PascalCase` for nodes/classes

## Behavioral gotchas

- **Camera never moves up** — `_max_camera_y` only increases
- **Shoot = Jump button** — in air, jump input triggers shooting
- **Spider stomp hurts the player** (not the spider)
- **Floor Drone:** `take_damage()` is a no-op (bullets ricochet); only `stomp_damage()` works
- **Combo cash-in** only triggers on landing (`_was_on_floor` transition)
- **Bonus ammo above max** preserved — `refill_ammo()` uses `maxi()` to not overwrite
- **Style bonus** — alternating stomp/shoot kills gives +1 combo per kill
- **Stance rooms** cycle: Shop → Money → Weapon → repeat. Spawned at x=600 (off-screen), accessed via teleport doors
- **Every 3 stances** = one level, followed by end-of-level trigger
