# Architecture — AI Agent Technical Reference

> **Purpose:** This document gives an AI coding agent everything needed to understand, navigate, and modify the Dive Heist codebase without reading every file first.
>
> **Engine:** Godot 4.6 | **Renderer:** Forward+ | **Viewport:** 320×448 (window 640×896)
> **Main scene:** `Scenes/UI/main_menu.tscn` | **Autoload:** `SFX` → `Scenes/Audio/sfx_manager.gd`
> For game design details see [GDD.md](GDD.md).

---

## 1. Architecture Overview

```
main_menu.tscn (Control — root, main_scene)
├── VBoxContainer (buttons: Start / Options / Quit)
├── OptionsPanel (Music + SFX sliders, Back button)
└── FadeRect (ColorRect — fade transitions)

world.tscn (Node2D — gameplay scene)
├── ParallaxBackground ← parallax_background.gd (3 scrolling layers)
├── Player (CharacterBody2D) ← player.gd
│   ├── Protagonista (AnimatedSprite2D)
│   └── GunPivot (Node2D)
│       ├── GunSprite (Sprite2D — visual weapon)
│       └── MuzzlePoint (Marker2D)
├── Camera2D
├── ChunkGenerator (Node2D) ← chunk_generator.gd
│   └── [dynamic] Node2D chunks → platforms, enemies, rest zones
├── LeftWall (StaticBody2D)
├── RightWall (StaticBody2D)
└── AmmoHUD (CanvasLayer) ← ammo_hud.gd
    └── AmmoBar (Control) ← ammo_bar.gd (custom _draw)
```

**Key relationships:**
- `world.gd` owns the game loop: camera, depth, game-over, screen shake, hitstop.
- `chunk_generator.gd` spawns/destroys chunks procedurally as the camera descends.
- `player.gd` is self-contained: handles movement, shooting, combos, HP, money.
- `ammo_hud.gd` is a passive state container; `ammo_bar.gd` renders it via `_draw()`.
- All enemy scripts are independent — they find the player via `get_first_node_in_group("player")`.
- Stance rooms (shop/money/weapon) are instantiated off-screen at x=600 and accessed via teleport doors. They cycle in order: shop → money → weapon → shop → …

---

## 2. Signal Flow

```
player.gd                          world.gd                     ammo_hud.gd
──────────                         ────────                     ───────────
ammo_changed(current, max)  ───→  _on_ammo_changed()      ───→  set_ammo()
hp_changed(current, max)    ───→  _on_hp_changed()        ───→  set_hp()
combo_changed(combo)        ───→  _on_combo_changed()     ───→  set_combo()
combo_reward(tier, combo)   ───→  _on_combo_reward()      ───→  show_combo_reward()
money_changed(current)      ───→  _on_money_changed()     ───→  set_money()
player_died                 ───→  _on_player_died()       ───→  show_death_screen(depth, kills, money, max_combo)

enemy.gd / drone.gd / spider.gd / floor_drone.gd
─────────────────────────────────────────────────
died                        (unused currently — future use)
take_damage() called by bullet.gd
_on_stomp_area_body_entered() → calls player.refill_ammo(), player.velocity.y = -250
_on_hitbox_body_entered()    → calls player.take_damage(1)

bullet.gd
────────
body_entered → target.take_damage(1) → if killed: player.add_combo()

shop_item.gd
────────────
purchased(item_id)  ───→  shop_stance.gd._on_item_purchased() → NPC trade animation
_try_purchase() → player.spend_money(price) → _apply_item(player) → _spawn_purchase_vfx()

room_door.gd
────────────
_teleport() → moves player.global_position, resets camera via world._reset_camera_to()

weapon_pickup.gd
────────────────
_on_body_entered() → player.heal(1) or player.increase_max_ammo(1)
```

---

## 3. Script Reference

### 3.1 `Scenes/Player/player.gd`
**Extends:** `CharacterBody2D` | **Lines:** 272 | **Group:** `"player"`

The player controller. Handles movement, jumping, shooting, stomping, combos, HP, and money.

**Signals:**
| Signal | Params | When emitted |
|--------|--------|--------------|
| `ammo_changed` | `(current: int, max_val: int)` | Ammo count changes (shoot, refill, combo reward) |
| `hp_changed` | `(current: int, max_val: int)` | HP changes (damage, heal, combo reward) |
| `player_died` | `()` | HP reaches 0 |
| `combo_changed` | `(combo: int)` | Combo count changes (kill, cash-in reset) |
| `combo_reward` | `(tier: int, combo: int)` | Landing with active combo (tier 0-3) |
| `money_changed` | `(current: int)` | Money gained or spent |

**Constants:**
| Name | Value | Purpose |
|------|-------|---------|
| `SPEED` | 130.0 | Horizontal movement speed (px/s) |
| `JUMP_VELOCITY` | -280.0 | Jump impulse (px/s) |
| `GRAVITY` | 800.0 | Gravity acceleration (px/s²) |
| `SHOOT_HANG_VELOCITY` | -160.0 | Upward push per shot (air retention) |
| `SHOOT_MAX_UPWARD` | -180.0 | Cap on upward speed from shooting |
| `SHOOT_COOLDOWN` | 0.15 | Seconds between shots |
| `MAX_HP` | 3 | Maximum HP |

**Exported variables:**
| Name | Type | Purpose |
|------|------|---------|
| `bullet_scene` | `PackedScene` | Bullet prefab to instantiate |
| `muzzle_flash_scene` | `PackedScene` | Muzzle flash VFX prefab |

**Mutable variable:**
| Name | Default | Purpose |
|------|---------|---------|
| `MAX_AIR_AMMO` | 8 | Max shots per jump (increased by shop/pickup) |

**Public methods:**
| Method | Params | Returns | Description |
|--------|--------|---------|-------------|
| `refill_ammo()` | `amount = MAX_AIR_AMMO` | `void` | Refill ammo (stomp), won't overwrite bonus ammo above max. Also increments combo. |
| `add_combo()` | none | `void` | Add 1 kill to combo (called by bullet on airborne kill). |
| `take_damage()` | `amount = 1` | `void` | Damage player, trigger i-frames, emit hp_changed. Dies at 0. |
| `collect_money()` | `value: int` | `void` | Add money, emit money_changed. |
| `heal()` | `amount: int` | `void` | Heal HP (clamped to MAX_HP). |
| `increase_max_ammo()` | `amount: int` | `void` | Permanently increase MAX_AIR_AMMO and refill. |
| `spend_money()` | `amount: int` | `bool` | Deduct money if affordable. Returns success. |

**Onready nodes:** `sprite` ($Protagonista, AnimatedSprite2D), `gun_pivot` ($GunPivot, Node2D), `gun_sprite` ($GunPivot/GunSprite, Sprite2D), `muzzle_point` ($GunPivot/MuzzlePoint, Marker2D)

**Mutable variable:**
| Name | Default | Purpose |
|------|---------|---------|
| `current_weapon` | `"pistol"` | Equipped weapon identifier (future: weapon swapping, US-19) |

**Collision:** layer 2 (Player), mask 1 (World)

---

### 3.2 `Scenes/Enemies/enemy.gd`
**Extends:** `CharacterBody2D` | **Lines:** 146

Base walking enemy (Prisoner / Warden). Patrols back and forth on platforms.

**Signals:** `died` (unused externally)

**Exported variables:**
| Name | Type | Default | Purpose |
|------|------|---------|---------|
| `speed` | `float` | 40.0 | Patrol speed |
| `hp` | `int` | 2 | Health points |
| `walk_range` | `float` | 80.0 | Distance before turning |
| `is_warden` | `bool` | false | True for Warden variant (different death SFX, $2 drop) |

**Public methods:**
| Method | Params | Description |
|--------|--------|-------------|
| `take_damage()` | `amount = 1` | Reduce HP, die at 0. Hurt flash on survive. |

**Onready nodes:** `sprite` ($AnimatedSprite2D), `stomp_area` ($StompArea, Area2D), `hitbox` ($Hitbox, Area2D), `edge_ray` ($EdgeDetector, RayCast2D)

**Collision:** body layer 4, mask 1. StompArea/Hitbox: layer 0, mask 2 (Player).

**Death behavior:** Spawns death explosion VFX ("explosion" type), spawns 1-2 money drops, plays death SFX, disables collision, removes after animation.

**Stomp behavior:** Checks `body.velocity.y > 0` (player must be falling). Deals 6 damage. On kill: screen_shake(3.0), hitstop(0.05), player.refill_ammo(), bounce player to -250 vy.

---

### 3.3 `Scenes/Enemies/drone.gd`
**Extends:** `CharacterBody2D` | **Lines:** 128

Floating enemy that homes toward the player. Ignores gravity, bobs vertically.

**Signals:** `died`

**Exported variables:**
| Name | Type | Default | Purpose |
|------|------|---------|---------|
| `hp` | `int` | 2 | Health |
| `chase_speed` | `float` | 45.0 | Homing speed |
| `bob_amplitude` | `float` | 3.0 | Vertical bob intensity |
| `bob_speed` | `float` | 3.0 | Bob frequency |

**Public methods:** `take_damage(amount = 1)` — standard damage/die.

**Collision:** Same as enemy.gd (layer 4, mask 1; areas mask 2).

**Death:** Spawns "blue_oval" death explosion, drops $2, plays `death_electric` SFX.

---

### 3.4 `Scenes/Enemies/spider.gd`
**Extends:** `CharacterBody2D` | **Lines:** 115

Wall-crawling enemy. **Shoot-only — stomping it HURTS the player.** Moves vertically along walls.

**Signals:** `died`

**Exported variables:**
| Name | Type | Default | Purpose |
|------|------|---------|---------|
| `speed` | `float` | 20.0 | Vertical patrol speed |
| `hp` | `int` | 3 | Health (tougher than others) |
| `patrol_range` | `float` | 80.0 | Vertical distance before reversing |

**Public methods:**
| Method | Description |
|--------|-------------|
| `take_damage(amount = 1)` | Standard bullet damage. |
| `set_wall_side(left: bool)` | Set which wall the spider is on (affects rotation). |

**⚠️ Special:** Stomp area calls `body.take_damage(1)` — stomping the spider damages the **player**.

**Death:** Spawns "lightning" death explosion, drops $3, plays `death_robotic` SFX.

---

### 3.5 `Scenes/Enemies/floor_drone.gd`
**Extends:** `CharacterBody2D` | **Lines:** 135

Heavy platform enemy. **Stomp-only — bullets ricochet off it.**

**Signals:** `died`

**Exported variables:**
| Name | Type | Default | Purpose |
|------|------|---------|---------|
| `speed` | `float` | 15.0 | Slow patrol speed |
| `hp` | `int` | 6 | Very tough |
| `walk_range` | `float` | 60.0 | Patrol distance |

**Public methods:**
| Method | Description |
|--------|-------------|
| `take_damage(_amount)` | **Override:** Does nothing. Plays ricochet SFX. Bullets bounce off. |
| `stomp_damage(amount = 6)` | Only way to damage this enemy. Called by stomp area. |

**⚠️ Special:** `take_damage()` is a no-op. Stomp area calls `stomp_damage(6)` instead. Screen shake 4.0, hitstop 0.06 on kill.

**Death:** Spawns "nuclear" death explosion, drops $5, plays `death_heavy_drone` SFX.

---

### 3.6 `Scenes/Levels/world.gd`
**Extends:** `Node2D` | **Lines:** ~200

Game orchestrator. Manages camera, HUD updates, screen shake, hitstop, game-over, music, and cumulative run stats.

**Onready nodes:** `player`, `ammo_hud` (CanvasLayer), `camera` (Camera2D), `chunk_gen` (Node2D), `left_wall`, `right_wall` (StaticBody2D)

**Cumulative run stats:**
| Name | Purpose |
|------|---------|
| `_total_kills` | Total enemies killed across all levels |
| `_total_money_earned` | Total money collected across all levels |
| `_overall_max_combo` | Highest combo achieved in the run |

**Public methods:**
| Method | Params | Description |
|--------|--------|-------------|
| `screen_shake()` | `intensity = 2.5` | Trigger camera shake (decays at 8.0/s). |
| `hitstop()` | `duration = 0.04` | Freeze entire tree for impact frames. Uses `process_mode = ALWAYS`. |
| `_reset_camera_to()` | `pos: Vector2` | Snap camera to position (used by room doors). |

**Camera behavior:**
- Only moves **down** (`_max_camera_y` never decreases — Downwell style).
- X centers at 128 (well center) normally, follows player when x > 400 (in rest room).
- Walls follow camera Y when player is in the well.

**Game over:** Stops music, shows death screen with cumulative stats (depth, kills, money, max combo), waits for jump input to `change_scene_to_file("res://Scenes/UI/main_menu.tscn")`.

---

### 3.7 `Scenes/Levels/chunk_generator.gd`
**Extends:** `Node2D` | **Lines:** ~330

Procedural level generator. Spawns platform chunks below the camera, despawns above. Every `LEVEL_LENGTH` (600m) a rest zone spawns with one of 3 cycling stance rooms.

**Constants:**
| Name | Value | Purpose |
|------|-------|---------|
| `WELL_LEFT` | 0.0 | Left boundary of the well |
| `WELL_RIGHT` | 256.0 | Right boundary |
| `CHUNK_HEIGHT` | 90.0 | Vertical spacing between chunks |
| `SPAWN_AHEAD` | 600.0 | Pre-generate this far below camera |
| `DESPAWN_BEHIND` | 400.0 | Remove chunks this far above camera |
| `LEVEL_LENGTH` | 600.0 | Distance between rest zones |
| `MIN_PLATFORM_W` | 48.0 | Minimum platform width |
| `MAX_PLATFORM_W` | 96.0 | Maximum platform width |
| `STANCE_SCENES` | `[shop, money, weapon]` | 3 stance room PackedScenes, cycled in order |

**Exported variables (set in editor):**
| Name | Type | Purpose |
|------|------|---------|
| `prisoner_scene` | `PackedScene` | Prisoner enemy prefab |
| `warden_scene` | `PackedScene` | Warden enemy prefab |
| `drone_scene` | `PackedScene` | Drone enemy prefab |
| `spider_scene` | `PackedScene` | Spider enemy prefab |
| `floor_drone_scene` | `PackedScene` | Floor drone prefab |
| `platform_tile` | `Texture2D` | Platform visual sprite |
| `bg_tiles` | `Array[Texture2D]` | Background tile textures |

**Public methods:**
| Method | Description |
|--------|-------------|
| `setup(start_y: float)` | Initialize generator. Call once from world.gd. |

**Key variables:**
| Name | Purpose |
|------|---------|
| `current_depth` | Set by world.gd each frame, drives difficulty scaling |
| `_stance_index` | Cycles 0→1→2→0… to pick which stance room spawns next |

**Difficulty formula:** `difficulty = clamp(current_depth / 3000.0, 0.0, 1.0)` — scales from 0 to 1 over 3000m.

**Spawn chances (scale with difficulty):**
| Element | Start → Max | Condition |
|---------|-------------|-----------|
| Platform enemy | 60% → 90% | Per platform |
| Warden ratio | 30% → 55% | Of platform enemies |
| Air drone | 20% → 50% | Per chunk |
| Wall spider | 15% → 35% | Per chunk |
| Floor drone | 10% → 25% | On platforms ≥ 64px wide, max 1/chunk |

**Rest zone (level system):** Every `LEVEL_LENGTH` (600m). Green one-way platform against a wall, door → off-screen stance room at x=600. Stance rooms cycle: **Shop** → **Money** → **Weapon** → Shop → …

**End-of-level zone:** After 3 stances, the next rest zone is a full-width platform with a 64px center gap (no enemies). An `Area2D` trigger below the gap detects the player falling through and calls `world._on_level_complete()`.

**Stance-specific setup (`_configure_stance`):**
- **Weapon stance:** Randomizes `pickup_type` (0=LIFE, 1=ENERGY).

---

### 3.7a `Scenes/Levels/level_end_trigger.gd`
**Extends:** `Area2D` | **Lines:** ~20

Trigger zone placed below the center gap in end-of-level zones. Detects player body entering (collision mask 2). Fires `world._on_level_complete()` once, then disables itself.

---

### 3.8 `Scenes/Weapons/bullet.gd`
**Extends:** `Area2D` | **Lines:** 32

Downward projectile. Moves at 400 px/s. Auto-destroys after 2s.

**Behavior on body enter:**
1. Call `body.take_damage(1)`
2. Play bullet hit SFX
3. If killed: screen_shake(2.0), hitstop(0.03)
4. If player airborne and target killed: `player.add_combo()`
5. `queue_free()`

**Collision:** layer 0, mask detects layer 4 (Enemies) and layer 1 (World).

---

### 3.9 `Scenes/Weapons/muzzle_flash.gd`
**Extends:** `AnimatedSprite2D` | **Lines:** 6

Auto-playing, auto-destroying VFX. Plays "flash" animation then `queue_free()`.

---

### 3.10 `Scenes/Audio/sfx_manager.gd`
**Extends:** `Node` | **Lines:** 145 | **Autoload:** `SFX`

Global singleton. Preloads all SFX as `AudioStream` vars. Manages a pool of 12 `AudioStreamPlayer` nodes on bus "SFX".

**Core method:**
```
play(stream: AudioStream, volume_db = 0.0, pitch = 1.0) -> AudioStreamPlayer
```
Finds first idle player, or steals player[0] if all busy.

**Helper methods (all call `play()` with preset volume/pitch):**
| Method | Sound | Volume | Pitch range |
|--------|-------|--------|-------------|
| `play_shoot()` | shoot_base | -8 dB | 0.9–1.1 |
| `play_jump()` | jump1 or jump2 | -12 dB | 0.95–1.05 |
| `play_stomp_bones()` | stomp_bones | -5 dB | 0.9–1.1 |
| `play_stomp_material()` | stomp_material | -5 dB | 0.9–1.1 |
| `play_death_prisoner()` | death_bones | -7 dB | 0.9–1.1 |
| `play_death_warden()` | death_disappear | -7 dB | 0.9–1.1 |
| `play_death_drone()` | death_electric | -7 dB | 0.9–1.1 |
| `play_death_spider()` | death_robotic | -7 dB | 0.9–1.1 |
| `play_death_floor_drone()` | death_heavy_drone | -4 dB | 0.9–1.05 |
| `play_bullet_hit()` | bullet_impact | -9 dB | 0.9–1.1 |
| `play_ricochet()` | bullet_ricochet | -7 dB | 0.9–1.1 |
| `play_combo_reward(tier)` | tier 1/2/3 sounds | varies | 1.0 |
| `play_coin_pickup()` | coin_pickup (heal_pickup_2) | -16 dB | 1.2–1.4 |

**Preloaded streams:** shoot_base, jump1, jump2, landing, damage_taken, player_death, empty_click, death_bones, death_electric, death_robotic, death_disappear, death_heavy_drone, stomp_bones, stomp_material, bullet_impact, bullet_ricochet, bullet_ricochet_2, combo_increase, combo_tier_1, combo_tier_2, combo_tier_3, drone_buzz, spider_patrol, invincibility, game_over, restart_menu, coin_pickup.

---

### 3.11 `Scenes/UI/ammo_hud.gd`
**Extends:** `CanvasLayer` | **Lines:** 123

Passive HUD state container. Stores display values and triggers `bar_container.queue_redraw()`.

**State variables:** `max_ammo`, `current_ammo`, `max_hp`, `current_hp`, `depth`, `combo`, `money`, `game_over`, `reward_text`, `reward_timer`

**Death screen state:** `death_screen`, `ds_depth`, `ds_kills`, `ds_money`, `ds_max_combo`

**Level complete state:** `level_complete`, `lc_level`, `lc_kills`, `lc_money_earned`, `lc_max_combo`, `lc_depth`

**Setter methods:** `set_ammo()`, `set_max_ammo()`, `set_hp()`, `set_max_hp()`, `set_depth()`, `set_combo()`, `set_money()`, `show_combo_reward(tier, combo_val)`, `show_game_over()`, `show_death_screen(depth, kills, money, max_combo)`, `show_level_complete(level, kills, money, max_combo, depth)`, `hide_level_complete()`

**Onready:** `bar_container` ($AmmoBar, Control) — the node that actually draws.

---

### 3.12 `Scenes/UI/ammo_bar.gd`
**Extends:** `Control` | **Lines:** 239

Custom `_draw()` renderer. Reads state from parent `ammo_hud.gd` and draws all HUD elements:

| Element | Position | Details |
|---------|----------|---------|
| Ammo bar | Right edge, vertical | Yellow segments (filled/empty) with borders |
| HP pips | Top-left | Red squares, 8×8px with 3px gap |
| Money | Below HP pips | Gold "$X" text |
| Depth | Top-center | White "Xm" text |
| Combo | Center, y=39 | Color/size scales with tier (grey→yellow→orange→red→pink) |
| Reward popup | Center, y=56 | Tier text, fades over 1.5s, floats upward |
| Death screen | Full screen | Dark overlay + "GAME OVER" + stats (depth/kills/money/combo) + pulsing "JUMP to restart" |
| Level complete | Full screen | Dim overlay + "LEVEL X COMPLETE" + stats + "JUMP to continue" |
| Game over (fallback) | Full screen | Dim overlay + "GAME OVER" + "JUMP to restart" |

**Font:** `CyberpunkCraftpixPixel.otf` loaded from Sprites/Scraper.

---

### 3.13 `Scenes/Collectibles/money.gd`
**Extends:** `Area2D` | **Lines:** 93

Collectible money drop. Falls with gravity, lands on platforms, magnetizes to player.

**Constants:**
| Name | Value | Purpose |
|------|-------|---------|
| `GRAVITY` | 400.0 | Fall acceleration |
| `MAGNET_RANGE_H` | 70.0 | Horizontal magnet range |
| `MAGNET_RANGE_V` | 36.0 | Vertical magnet range |
| `MAGNET_RANGE` | 36.0 | Omni-range (very close) |
| `MAGNET_SPEED` | 120.0 | Speed when magnetized |
| `DESPAWN_TIME` | 8.0 | Auto-remove after 8s |

**Exported:** `value := 1` (money amount)

**Behavior:** Pops up on spawn with random spread. Falls and snaps to platforms via raycast (layer 1). Magnetizes when player is within range. Collected on body contact → `player.collect_money(value)`.

**Collision:** layer 0, mask 2 (Player).

---

### 3.14 `Scenes/Collectibles/gem_crate.gd`
**Extends:** `StaticBody2D` | **Lines:** 47

Breakable crate in rest rooms. Shoot or stomp to break.

**Exported:** `money_count := 12`, `money_value := 1`, `hp := 3`

**Behavior:** `take_damage()` reduces HP. At 0: spawns `money_count` money drops in a burst, plays "Open" animation, then `queue_free()`.

**Collision:** layer 4 (same as enemies so bullets hit it), mask 0.

---

### 3.15 `Scenes/Rooms/base_room.gd`
**Extends:** `Node2D` | **Lines:** ~80

Base script shared by all stance rooms. Provides background tiling and decoration logic. Each stance extends this script.

**Constants:** `ROOM_WIDTH = 320.0`, `ROOM_HEIGHT = 200.0`, `TILE_SIZE = 32.0`

**Onready:** `exit_door` ($ExitDoor, Area2D)

**Behavior on `_ready()`:** Fills background with random prison tiles and adds random decorations.

---

### 3.15a `Scenes/Rooms/shop_stance.gd`
**Extends:** `base_room.gd` | **Lines:** ~30

Shop stance room. Contains an NPC Arms Dealer with animated sprite and 3 shop item slots.

**Onready:** `npc_sprite` ($NPC/AnimatedSprite2D), `shop_items` array [$ShopSlot1, $ShopSlot2, $ShopSlot3]

**NPC animations:** "idle" (Arms Dealer Idle.png) and "trade" (Trade.png). Plays "trade" on item purchase, returns to "idle" after 0.5s.

**Scene contents:** NPC node with AnimatedSprite2D, 3 `ShopItem` instances (heal $3, ammo_up $5, armor $8), exit door.

---

### 3.15b `Scenes/Rooms/money_stance.gd`
**Extends:** `base_room.gd` | **Lines:** ~8

Money stance room. Contains a breakable `GemCrate` that drops money when shot/stomped.

**Onready:** `gem_crate` ($GemCrate, StaticBody2D)

**Scene contents:** GemCrate (centered), exit door.

---

### 3.15c `Scenes/Rooms/weapon_stance.gd`
**Extends:** `base_room.gd` | **Lines:** ~8

Change weapon stance room. Contains a weapon pickup that heals or increases max ammo.

**Onready:** `weapon_pickup` ($WeaponPickup, Area2D)

**Scene contents:** WeaponPickup (centered), exit door.

**Setup by chunk_generator:** `weapon_pickup.pickup_type` is randomized (0=LIFE, 1=ENERGY).

---

### 3.15d `Scenes/Rooms/rest_room.gd` (legacy)
**Extends:** `Node2D` | **Lines:** 83

Legacy rest zone room (still exists but no longer spawned by chunk_generator). Replaced by the 3 stance rooms above.

---

### 3.16 `Scenes/Rooms/room_door.gd`
**Extends:** `Area2D` | **Lines:** 58

Teleport door. Player presses interact while on floor to teleport.

**Exported:**
| Name | Type | Default | Purpose |
|------|------|---------|---------|
| `target_position` | `Vector2` | ZERO | Destination coordinates |
| `is_exit` | `bool` | false | Visual distinction (unused currently) |

**Behavior:** On interact → moves player.global_position, resets camera via `world._reset_camera_to()`, 0.5s cooldown to prevent double-trigger.

---

### 3.17 `Scenes/Rooms/shop_item.gd`
**Extends:** `Area2D` | **Lines:** 80

Buyable item. Player stands on it and presses interact.

**Signals:** `purchased(item_id: String)`

**Exported:**
| Name | Type | Default | Purpose |
|------|------|---------|---------|
| `item_id` | `String` | "heal" | Item identifier for match |
| `price` | `int` | 5 | Cost in dollars |
| `description` | `String` | "" | Display text (unused) |

**Item effects (in `_apply_item()`):**
| item_id | Effect |
|---------|--------|
| `"heal"` | `player.heal(1)` |
| `"ammo_up"` | `player.increase_max_ammo(1)` |
| `"armor"` | `player.heal(player.MAX_HP)` (full heal) |

**Purchase flow:** `spend_money(price)` → if success: apply item, spawn purchase VFX (gold particles + "SOLD!" text popup), fade out, queue_free.

---

### 3.18 `Scenes/Rooms/weapon_pickup.gd`
**Extends:** `Area2D` | **Lines:** 58

Walk-over pickup in rest rooms. Bobs up and down.

**Enum:** `PickupType { LIFE, ENERGY }`

**Exported:** `pickup_type: PickupType = LIFE`

**Effects:**
| Type | Effect |
|------|--------|
| `LIFE` | `player.heal(1)` |
| `ENERGY` | `player.increase_max_ammo(1)` |

---

### 3.19 `Scenes/UI/main_menu.gd`
**Extends:** `Control` | **Lines:** ~170

Title screen scene. Drawn via `_draw()` for title/subtitle/decorations, with Control nodes for buttons and sliders.

**Scene structure:**
```
MainMenu (Control) ← main_menu.gd
├── VBoxContainer (Start / Options / Quit buttons)
├── OptionsPanel (Music + SFX HSliders, Back button)
└── FadeRect (ColorRect — black overlay for transitions)
```

**Behavior:**
- `_draw()` renders: scan lines, "DIVE HEIST" title with glow, subtitle, decorative line, version text.
- Start → fade to black (0.5s tween) → `change_scene_to_file("res://Scenes/Levels/world.tscn")`.
- Options → shows panel with Music/SFX volume sliders controlling AudioServer bus volumes.
- Quit → `get_tree().quit()` (hidden on Web builds).
- Jump input also triggers Start (keyboard shortcut).
- Fade-in from black on boot.
- `_apply_theme()` recursively styles all Button/Label nodes with cyberpunk font and flat StyleBoxFlat overrides.

**Font:** `CyberpunkCraftpixPixel.otf`

---

### 3.20 `Scenes/Levels/parallax_background.gd`
**Extends:** `ParallaxBackground` | **Lines:** ~45

Creates 3 parallax scrolling layers behind the well using futuristic city backgrounds.

**Layers:**
| Layer | Texture | motion_scale | Tint | Purpose |
|-------|---------|-------------|------|---------|
| Far | city 4/1.png | 0.05 | Color(0.15, 0.15, 0.2, 0.6) | Deep sky/background |
| Mid | city 4/5.png | 0.15 | Color(0.5, 0.5, 0.55, 0.5) | Distant buildings |
| Near | city 4/8.png | 0.35 | Color(0.4, 0.4, 0.45, 0.4) | Close structures |

**Implementation:** Creates TextureRect nodes with STRETCH_TILE per layer in `_ready()`. Uses `motion_mirroring` set to texture height for infinite vertical scrolling. ParallaxBackground auto-follows the camera.

---

### 3.21 `Scenes/VFX/death_explosion.gd`
**Extends:** `Node2D` | **Lines:** ~40

Animated explosion VFX. Builds SpriteFrames dynamically at runtime from PNG sequences.

**Exported:** `explosion_type: String = "explosion"`

**Supported types:**
| Type | Frames | FPS | Scale | Path pattern |
|------|--------|-----|-------|-------------|
| `"explosion"` | 10 | 15 | 1.0 | `Explosion/Explosion%d.png` |
| `"blue_oval"` | 10 | 15 | 1.0 | `Explosion_blue_oval/Explosion_blue_oval%d.png` |
| `"nuclear"` | 10 | 12 | 1.5 | `Nuclear_explosion/Nuclear_explosion%d.png` |
| `"lightning"` | 4 | 12 | 1.2 | `Lightning/Lightning_spot%d.png` |

**Behavior:** Creates AnimatedSprite2D in `_ready()`, builds frames from CONFIGS dict, plays animation, auto-frees on `animation_finished`.

**Usage by enemies:**
- `enemy.gd` → `"explosion"`
- `drone.gd` → `"blue_oval"`
- `spider.gd` → `"lightning"`
- `floor_drone.gd` → `"nuclear"`

---

### 3.22 `Scenes/VFX/text_popup.gd`
**Extends:** `Node2D` | **Lines:** ~30

Floating text popup. Draws text via `_draw()`, drifts upward, fades over `duration` seconds, auto-frees.

**Exported:**
| Name | Type | Default | Purpose |
|------|------|---------|---------|
| `popup_text` | `String` | "SOLD!" | Text to display |
| `popup_color` | `Color` | Gold (1, 0.9, 0.3) | Text color |
| `float_speed` | `float` | -30.0 | Upward drift speed (px/s) |
| `duration` | `float` | 0.8 | Seconds before fade-out complete |

**Font:** `CyberpunkCraftpixPixel.otf`, size 10

---

### 3.23 `Scenes/VFX/purchase_particles.gd`
**Extends:** `CPUParticles2D` | **Lines:** ~8

One-shot gold particle burst for shop purchases. Auto-frees on `finished` signal.

**Particle config:** 12 particles, explosiveness 0.9, gold color, 40-80 px/s velocity, -200 gravity (float up), 0.5s lifetime.

---

## 4. Collision System

### Layer Assignments
| Layer | Binary | Used by |
|-------|--------|---------|
| 1 | `0001` | World — walls, floors, platforms (StaticBody2D) |
| 2 | `0010` | Player body (CharacterBody2D) |
| 4 | `0100` | Enemies + gem_crate (CharacterBody2D / StaticBody2D) |

### How Enemies Detect the Player
Enemies do **not** use collision masks to detect the player directly. Instead:
- `StompArea` (Area2D): layer 0, mask 2 — detects Player entering from above.
- `Hitbox` (Area2D): layer 0, mask 2 — detects Player touching enemy body.

### Stomp vs Hitbox Priority
In `enemy.gd` `_on_hitbox_body_entered()`: if `body.velocity.y > 0` AND `body.global_position.y < enemy.global_position.y`, the hit is **ignored** (treated as a stomp instead).

### Special Cases
| Enemy | Bullet behavior | Stomp behavior |
|-------|----------------|----------------|
| Prisoner/Warden | `take_damage(1)` — normal | `take_damage(6)` — kills, bounces player |
| Drone | `take_damage(1)` — normal | `take_damage(6)` — kills, bounces player |
| Spider | `take_damage(1)` — normal | **Hurts player** — `body.take_damage(1)` |
| Floor Drone | `take_damage()` — **no-op**, ricochet SFX | `stomp_damage(6)` — only way to kill |

---

## 5. Procedural Generation Pipeline

### Chunk Lifecycle
```
_physics_process():
  1. Get camera Y position
  2. While _next_chunk_y < cam_y + SPAWN_AHEAD:
     a. If _next_chunk_y >= _next_rest_zone_y → spawn rest zone
     b. Else → spawn normal chunk
     c. _next_chunk_y += CHUNK_HEIGHT (90px)
  3. Despawn chunks where y < cam_y - DESPAWN_BEHIND (400px)
```

### Chunk Population (per chunk)
1. **Background tiles** — random prison tiles, 8 columns × ~3 rows
2. **Platforms** — 1-3 per chunk (fewer at high difficulty), 48-96px wide (narrower at depth)
3. **Platform enemies** — Prisoner or Warden on random platforms
4. **Air drone** — floating in open space
5. **Wall spider** — on left or right wall
6. **Floor drone** — on wide platforms (≥64px), max 1 per chunk

### Rest Zone / Level System (every 600m)
1. Green one-way platform against random wall
2. Door on that wall → teleports to stance room at x=600
3. Stance rooms cycle in order: **Shop** → **Money** → **Weapon** → repeat
   - **Shop stance:** NPC + 3 buyable items (heal, ammo_up, armor)
   - **Money stance:** Breakable crate that drops money
   - **Weapon stance:** Weapon pickup (+HP or +Max Ammo)
4. Exit door teleports back to the green platform
5. After all 3 stances, the next rest zone is an **End-of-Level Zone**

### End-of-Level Zone
After every 3 stances (one full level), a special zone spawns:
1. Full-width green platform with a **64px center gap** (no enemies)
2. Player falls through the gap → triggers `level_end_trigger.gd`
3. `world.gd._on_level_complete()` fires → shows **"LEVEL X COMPLETE"** overlay
4. Stats displayed: kills, money earned, max combo, depth
5. Player presses **JUMP** to continue to the next level
6. Level counter increments, stats reset for the new level

### Difficulty Scaling
All spawn chances and platform widths interpolate based on:
```gdscript
var difficulty := clampf(current_depth / 3000.0, 0.0, 1.0)
```
- 0m = easiest (60% enemies, wide platforms, 3 per chunk)
- 3000m = hardest (90% enemies, narrow platforms, 2 per chunk)

---

## 6. Common Modification Guides

### 6.1 Add a New Enemy Type

1. **Create scene** `Scenes/Enemies/new_enemy.tscn`:
   - Root: `CharacterBody2D` with script `new_enemy.gd`
   - Children: `AnimatedSprite2D`, `StompArea` (Area2D + CollisionShape2D), `Hitbox` (Area2D + CollisionShape2D)
   - Optional: `EdgeDetector` (RayCast2D) for platform patrol

2. **Write script** extending `CharacterBody2D`:
   ```gdscript
   extends CharacterBody2D
   signal died
   const MONEY_SCENE := preload("res://Scenes/Collectibles/money.tscn")
   
   func _ready() -> void:
       collision_layer = 4   # Enemy layer
       collision_mask = 1    # Detect world
       # Areas detect player
       stomp_area.collision_layer = 0
       stomp_area.collision_mask = 2
       hitbox.collision_layer = 0
       hitbox.collision_mask = 2
   ```
   - Implement `take_damage(amount)` and `_die()` following existing patterns.
   - For stomp-only: override `take_damage()` as no-op, add `stomp_damage()` method.
   - For shoot-only with stomp penalty: see `spider.gd` pattern.

3. **Register in chunk_generator.gd**:
   - Add `@export var new_enemy_scene: PackedScene`
   - Add spawn logic in `_spawn_chunk()` with difficulty-scaled chance
   - Add `_add_new_enemy()` helper method

4. **Add death SFX** in `sfx_manager.gd`:
   - Add `var new_death: AudioStream = preload(...)` 
   - Add `play_death_new_enemy()` helper method

5. **Assign scene** in the Godot editor: select ChunkGenerator node → drag scene to new export.

### 6.2 Add a New Shop Item

1. **Duplicate** an existing `ShopItem` node in `rest_room.tscn` (or add via code).
2. **Set exports:** `item_id`, `price`, `description`.
3. **Add effect** in [`shop_item.gd`](Scenes/Rooms/shop_item.gd) `_apply_item()`:
   ```gdscript
   match item_id:
       # ... existing items ...
       "speed_boost":
           if player.has_method("increase_speed"):
               player.increase_speed(20.0)
   ```
4. **Add the method** to `player.gd` if needed.

### 6.3 Add a New Weapon/Pickup Type

1. **Add to enum** in [`weapon_pickup.gd`](Scenes/Rooms/weapon_pickup.gd):
   ```gdscript
   enum PickupType { LIFE, ENERGY, SHIELD }
   ```
2. **Add label** in `_update_label()`.
3. **Add effect** in `_on_body_entered()`:
   ```gdscript
   if pickup_type == PickupType.SHIELD:
       if body.has_method("activate_shield"):
           body.activate_shield(5.0)
   ```
4. **Add the method** to `player.gd`.

### 6.4 Add a New SFX

1. **Place .wav file** in `Audio/SFX/`.
2. **Add preload** in [`sfx_manager.gd`](Scenes/Audio/sfx_manager.gd):
   ```gdscript
   var new_sound: AudioStream = preload("res://Audio/SFX/new_sound.wav")
   ```
3. **Add helper method** (optional but recommended):
   ```gdscript
   func play_new_sound() -> void:
       play(new_sound, -7.0, randf_range(0.9, 1.1))
   ```
4. **Call it** from the appropriate script via `SFX.play_new_sound()`.

### 6.5 Add a New Phase/Tileset

1. **Prepare tileset assets** in `Sprites/`.
2. **Create new background textures** array (like `bg_tiles` in chunk_generator).
3. **Modify chunk_generator.gd** to support phase-aware generation:
   - Add phase detection based on depth ranges (0-1800 = Prison, 1800-3600 = Factory, etc.)
   - Swap `platform_tile` and `bg_tiles` per phase
   - Adjust enemy spawn tables per phase
4. **Create new enemy scenes** for the phase.
5. **Add new music track** and swap in `world.gd` based on depth.

### 6.6 Add a New HUD Element

1. **Add state variable** to [`ammo_hud.gd`](Scenes/UI/ammo_hud.gd) and a setter method.
2. **Add draw call** in [`ammo_bar.gd`](Scenes/UI/ammo_bar.gd) `_draw()`:
   ```gdscript
   func _draw() -> void:
       # ... existing draws ...
       _draw_new_element(hud.new_value)
   ```
3. **Implement `_draw_new_element()`** using Godot's `draw_*()` methods.
4. **Connect signal** in `world.gd` if the data comes from the player.

---

## 7. Gotchas & Conventions

### Critical Behavioral Quirks
- **Camera never moves up** — `_max_camera_y` only increases. If the player jumps, the camera stays at the lowest point reached.
- **Combo cash-in only on landing** — detected via `_was_on_floor` transition (was not on floor → now on floor).
- **Style bonus** — alternating stomp/shoot kills gives +1 extra combo per kill.
- **Bonus ammo above max** — Tier 2+ combo reward sets `_air_ammo = MAX_AIR_AMMO + 3`. `refill_ammo()` won't overwrite bonus ammo (uses `maxi()`).
- **Floor drone uses `stomp_damage()` not `take_damage()`** — bullets call `take_damage()` which is a no-op that plays ricochet.
- **Spider stomp hurts the player** — its `_on_stomp_area_body_entered` calls `body.take_damage(1)`.
- **Shoot = Jump button** — in the air, the jump input triggers shooting instead.

### Code Conventions
- **Language:** Code in English, design docs (GDD) in Spanish.
- **Naming:** `snake_case` for files/variables/functions, `PascalCase` for nodes/classes.
- **Collision layers:** 1=World, 2=Player, 4=Enemies (powers of 2).
- **Signals:** Connected in `_ready()` via code, never in the editor.
- **SFX:** Always via `SFX.play_*()` autoload, never direct `AudioStreamPlayer`.
- **Scenes:** Reusable prefabs as `.tscn` with attached script.
- **World access:** `get_tree().current_scene` used for `screen_shake()`, `hitstop()`, and adding child nodes (bullets, money).
- **Player lookup:** `get_tree().get_first_node_in_group("player")` — player is in group `"player"`.

### Technical Notes
- `world.gd` uses `process_mode = PROCESS_MODE_ALWAYS` so hitstop timers work while tree is paused.
- Platforms use `one_way_collision = true` — player can jump through from below.
- Money drops use `call_deferred("add_child")` to avoid physics sync issues.
- `gem_crate.gd` uses collision layer 4 (enemy layer) so bullets can hit it.
- Stance rooms are built at x=600 (off-screen right) and accessed via teleport, not physical proximity. They cycle: shop → money → weapon → shop → …
