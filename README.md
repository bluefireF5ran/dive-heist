# 🎮 Dive Heist

![Godot 4.6](https://img.shields.io/badge/Godot-4.6-blue?logo=godot-engine)
![Platform](https://img.shields.io/badge/platform-Desktop-lightgrey)
![Status](https://img.shields.io/badge/status-Alpha-orange)

> A vertical roguelike inspired by Downwell, set in a cyberpunk prison.  
> Fall. Shoot. Stomp. Combo. Repeat.

---

## 📖 About

**Dive Heist** is a vertical-descent roguelike built in [Godot 4.6](https://godotengine.org/). You play as a prisoner escaping through a deep well — shooting downward, stomping enemies, chaining air combos, and spending your loot in rest rooms between levels.

**Design pillars:**

- **Constant vertical action** — Free-fall + shooting + stomps = non-stop flow.
- **Risk / reward** — Higher combos yield better rewards, but losing your combo hurts.
- **Phased progression** — 5 themed environments with unique enemies and mechanics.

---

## 📸 Screenshots

<!-- Replace the placeholders below with actual screenshots or a gameplay GIF -->

| Gameplay | Rest Room |
|----------|-----------|
| ![Gameplay placeholder](https://placehold.co/320x448/1a1a2e/e0e0e0?text=Gameplay+Screenshot) | ![Rest room placeholder](https://placehold.co/320x448/1a1a2e/e0e0e0?text=Rest+Room+Screenshot) |

---

## ✨ Features

- **Combo system** — Chain kills in the air; land to cash in tiered rewards (HP, ammo, invincibility).
- **5 enemy types** — Prisoners, Wardens, Drones, Spiders, and Floor Drones, each with unique behavior.
- **Procedural levels** — Chunk-based generation that scales difficulty with depth.
- **Rest rooms** — Shops, gem crates, and weapon pickups every 600m.
- **Custom HUD** — Ammo bar, HP pips, combo counter, depth meter, and money display drawn with `_draw()`.
- **SFX pool** — 12-voice AudioStreamPlayer pool managed by a global autoload singleton.
- **Pixel art cyberpunk** — Prison tilesets, character sprites, and VFX from Craftpix and Scraper.

> **Current status:** Phase 1 — Prison Alpha (all core mechanics implemented).

---

## 🎮 Controls

| Action | Keys |
|--------|------|
| Move Left | `A` or `←` |
| Move Right | `D` or `→` |
| Jump | `Space` / `W` / `↑` |
| Shoot | Automatic when airborne |
| Interact | `S` or `↓` |

---

## 🚀 Getting Started

### Prerequisites

- [Godot 4.6](https://godotengine.org/download) or newer (Forward+ renderer)
- Git

### Clone & Run

```bash
git clone https://github.com/YOUR_USERNAME/dive-heist.git
cd dive-heist
```

1. Open the project in Godot (`Import → select folder → Import & Edit`).
2. Press **F5** or click the **Play** button.

The main scene is [`Scenes/Levels/world.tscn`](Scenes/Levels/world.tscn), configured in [`project.godot`](project.godot).

---

## 📁 Project Structure

```
dive-heist/
├── project.godot              # Engine config, input mappings, autoloads
├── GDD.md                     # Full Game Design Document (Spanish)
├── icon.svg                   # Project icon
│
├── Audio/
│   ├── SFX/                   # Sound effects (.wav)
│   └── Soundtrack/            # Music tracks (.mp3)
│
├── Scenes/
│   ├── Audio/                 # SFX autoload singleton (sfx_manager.gd)
│   ├── Collectibles/          # Money drops, gem crates
│   ├── Enemies/               # Base enemy + 4 variants (drone, spider, floor_drone, prisoner, warden)
│   ├── Levels/                # World scene + procedural chunk generator
│   ├── Player/                # Player controller (movement, shooting, combos)
│   ├── Rooms/                 # Rest room, shop items, weapon pickups, doors
│   ├── UI/                    # HUD — ammo bar, HP, combo, depth, money
│   └── Weapons/               # Bullet + muzzle flash
│
└── Sprites/
    ├── Craftpix/              # Prison tileset, backgrounds, explosions, guns, characters
    └── Scraper/               # Cyberpunk assets — drones, prisoners, prison tiles
```

---

## ⚙️ Game Mechanics (Summary)

### Movement & Combat
- **Horizontal movement** at 130 px/s with gravity at 800 px/s².
- **Shoot downward** only while airborne (0.15s cooldown, 8 max ammo, refills on landing or stomps).
- **Stomp** enemies by landing on them (6 damage, ammo refill, bounce).

### Combo System
Kill enemies in the air without touching the ground. Land to cash in:

| Tier | Kills | Reward |
|------|-------|--------|
| 0 | 1–7 | Points only |
| 1 | 8–14 | +1 HP |
| 2 | 15–24 | +1 HP, +3 ammo |
| 3 | 25+ | +1 HP, +3 ammo, 2s invincibility |

Alternating between stomps and shots grants a **style bonus** (+1 kill to combo).

### Rest Rooms
Every 600m a rest room appears with a **gem crate** (12 coins), a **shop** (heal, ammo up, armor), and a **weapon pickup**.

> For full details see the [Game Design Document (GDD.md)](GDD.md).

---

## 🎨 Assets & Attribution

| Asset | Source | Usage |
|-------|--------|-------|
| Prison Tileset | [Craftpix](https://craftpix.net) — Prison Tileset Pixel Art | Phase 1 environment |
| Character Sprites | [Craftpix](https://craftpix.net) — Cyberpunk characters | NPCs, trader |
| Explosion VFX | [Craftpix](https://craftpix.net) — Free Pixel Art Explosions | Death effects |
| Gun Sprites | [Craftpix](https://craftpix.net) — Free Guns Pack | Weapon visuals |
| Drones, Prisoners, Tiles | Scraper — Cyberpunk Assets | Enemy sprites, environment |
| Soundtrack | `Audio/Soundtrack/Prison1.5.mp3` | Background music |

---

## 📚 Documentation

- [**GDD.md**](GDD.md) — Full Game Design Document (in Spanish) covering vision, mechanics, enemies, audio, HUD, architecture, backlog, and conventions.

---

## 📄 License

<!-- Add your license here. For example:
This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
-->

TODO: Add license information.

---

<p align="center">
  Built with ❤️ and <a href="https://godotengine.org">Godot Engine</a>
</p>
