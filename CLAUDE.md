# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Dive Heist** — a vertical-descent roguelike (Downwell-inspired) built in **Godot 4.6** with GDScript. Cyberpunk prison setting. Core loop: fall, shoot downward, stomp enemies, chain air combos, spend loot in rest rooms.

- **Engine:** Godot 4.6, Forward+ renderer
- **Viewport:** 320×448 (window 640×896) — pixel art resolution
- **Main scene:** `Scenes/UI/main_menu.tscn`
- **Autoload singleton:** `SFX` → `Scenes/Audio/sfx_manager.gd`

## Running the Project

Open in Godot 4.6 editor and press **F5**. No test framework — manual playtesting only.

## Development Commands

**GDScript linting:**
```bash
gdlint Scenes/                    # Lint all GDScript files
gdlint Scenes/Player/player.gd   # Lint a single file
```

**GDScript formatting:**
```bash
gdformat Scenes/                  # Format all files in-place
gdformat --diff Scenes/           # Preview formatting changes
gdformat Scenes/Player/player.gd  # Format a single file
```

**Godot headless validation:**
```bash
Godot_v4.6.1-stable_win64.exe --headless --check-only --script res://Scenes/Player/player.gd
```

**Config:** `.gdlintrc` sets max line length to 120 (project uses longer draw calls).

## Architecture & Key Docs

- **`ARCHITECTURE.md`** — Full technical reference: signal flow, collision system, procedural generation pipeline, every script's API, and modification guides. **Read this first for any non-trivial change.**
- **`GDD.md`** — Game Design Document (in Spanish). Mechanics, enemy specs, combo tiers, audio design.
- **`plans/`** — Sprint planning docs.

## Scene Hierarchy

```
main_menu.tscn → fade → world.tscn
  ├── ParallaxBackground (3-layer scrolling)
  ├── Player (CharacterBody2D) — movement, shooting, combos, HP, money
  ├── Camera2D — only descends, never rises (Downwell-style)
  ├── ChunkGenerator — procedural chunk spawn/despawn around camera
  └── AmmoHUD (CanvasLayer) → AmmoBar (custom _draw renderer)
```

ChunkGenerator spawns stance rooms at x=600 (off-screen), accessed via teleport doors. Stances cycle: **Shop → Money → Weapon → repeat**. Every 3 stances = one level, followed by an end-of-level trigger.

## Critical Conventions

- **Collision layers:** 1=World, 2=Player, 4=Enemies (bitmask powers of 2)
- **Signals:** Connected in `_ready()` via code, never in editor
- **SFX:** Always via `SFX.play_*()` autoload — never direct AudioStreamPlayer
- **Player lookup:** `get_tree().get_first_node_in_group("player")` — player is in group `"player"`
- **World access:** `get_tree().current_scene` for `screen_shake()`, `hitstop()`, adding child nodes
- **Code in English**, design docs in Spanish
- **Naming:** `snake_case` for files/variables/functions, `PascalCase` for nodes/classes

## Key Behavioral Gotchas

- **Camera never moves up** — `_max_camera_y` only increases
- **Shoot = Jump button** — in air, jump input triggers shooting instead
- **Spider stomp hurts the player** (not the spider)
- **Floor Drone:** `take_damage()` is a no-op (bullets ricochet); only `stomp_damage()` works
- **Combo cash-in** only triggers on landing (`_was_on_floor` transition)
- **Bonus ammo above max** preserved — `refill_ammo()` uses `maxi()` to not overwrite
- **Style bonus** — alternating stomp/shoot kills gives +1 combo per kill
- **`world.gd`** uses `process_mode = PROCESS_MODE_ALWAYS` so hitstop timers work while tree is paused

## Notification on Task Complete

After finishing a task or when waiting for user input, run a Windows toast notification with sound:

```bash
powershell -c "Add-Type -AssemblyName System.Windows.Forms; [System.Media.SystemSounds]::Asterisk.Play(); \$n=New-Object System.Windows.Forms.NotifyIcon; \$n.Icon=[System.Drawing.SystemIcons]::Information; \$n.BalloonTipTitle='Claude Code'; \$n.BalloonTipText='Waiting for your input'; \$n.Visible=\$true; \$n.ShowBalloonTip(3000); Start-Sleep 4; \$n.Dispose()"
```

## Adding New Content

See `ARCHITECTURE.md` §6 for step-by-step guides on adding: enemy types, shop items, weapons/pickups, SFX, phases/tilesets, and HUD elements.
