# DIVE HEIST — Game Design Document (GDD)

> **Motor:** Godot 4.6 | **Género:** Roguelike vertical (estilo Downwell) | **Arte:** Pixel art Cyberpunk
> **Viewport:** 320×448 (ventana 640×896) | **Renderer:** Forward Plus
> **Última actualización:** 2026-06-14

---

## 1. Visión del juego

**Pitch:** Un roguelike de descenso vertical inspirado en Downwell, ambientado en un mundo cyberpunk. El jugador cae por un pozo disparando hacia abajo, pisoteando enemigos, acumulando combos, eligiendo perks entre niveles y comprando mejoras en salas de descanso.

**Pilares de diseño:**
- **Acción vertical constante** — Caída libre + disparo + stomps = flow continuo.
- **Riesgo/recompensa** — Los combos otorgan mejores premios, pero perder el combo cuesta. El hazard "urge" presiona al jugador a seguir bajando.
- **Progresión por eras** — 5 eras temáticas con tilesets, música, enemigos y mecánicas únicas. Cada era = 3 niveles.

**Referencia principal:** Downwell (Moppin, 2015)

---

## 2. Estructura del juego

### 2.1 Eras y niveles

| Era | Ambiente | Niveles | Enemigos | Estado |
|-----|----------|---------|----------|--------|
| 1 | Prisión | 1-3 | Prisionero, Warden, Drone, Spider, Floor Drone, Bat, Frog | ✅ Completa |
| 2 | Fábrica | 4-6 | Mismos + variantes mejoradas (tinte acero, 1.3x stats) | ✅ Completa |
| 3 | Laboratorio | 7-9 | Por diseñar | 📋 Backlog |
| 4 | Banco | 10-12 | Por diseñar | 📋 Backlog |
| 5 | Escape del Banco | 13-15 | Por diseñar | 📋 Backlog |

Cada era = 3 niveles. Cada nivel = 900m de descenso procedural.

**Fin de nivel:** 3 salas de descanso (stance rooms) → plataforma partida con gap central → caída al vacío → pantalla de LEVEL COMPLETE → selección de perk → fade out → siguiente nivel.

**Boss:** Al final del nivel 3 de cada era hay un boss. Prison Boss (Warden mejorado) implementado.

### 2.2 Ciclo de juego (game loop)

```
Inicio → Caer por el pozo → Matar enemigos (combo) → Aterrizar (cash-in combo)
    ↓                                                      ↓
Sala de descanso ← (cada 900m) ← Recoger dinero → Repetir ×3
    ↓
[Shop/Money/Weapon] → Volver al pozo
    ↓ (tras 3 salas)
Fin de nivel → Pantalla stats → Selección de Perk → Siguiente nivel
    ↓ (cada 3 niveles, fin de era)
Boss → Muerte del boss → Fin de nivel
```

**Urge Hazard:** Un hazard rojo ascendente presiona desde arriba. Se acelera si el jugador no progresa. Se pausa si hay combo activo o safe zone.

---

## 3. Mecánicas del jugador

### 3.1 Movimiento

| Parámetro | Valor | Input |
|-----------|-------|-------|
| Velocidad horizontal | 130 px/s | A/D o ←/→ |
| Gravedad | 800 px/s² | — |
| Velocidad terminal | 540 px/s (cap) | — |
| Salto | -280 px/s | Space / W / ↑ |
| Retroceso al disparar (aire) | -140 px/s (por arma, cap -180) | Automático |

### 3.2 Sistema de armas (11 armas)

Todas las armas se definen en `player.gd` via `WEAPON_DEFAULTS` + `WEAPONS`. Parámetros base:

| Parámetro | Default | Descripción |
|-----------|---------|-------------|
| fire_cooldown | 0.15s | Tiempo entre disparos |
| ammo_cost | 1 | Costo de munición por disparo |
| bullet_speed | 400 px/s | Velocidad de la bala |
| damage | 1 | Daño por impacto |
| bullet_count | 1 | Balas por disparo |
| spread_angle | 0° | Ángulo de dispersión |
| bullet_lifetime | 0.8s | Tiempo de vida de la bala |
| air_retention | -140 px/s | Retroceso al disparar en aire |

#### Armas implementadas

| Arma | Especialidad | Daño | Cooldown | Costo | Notas |
|------|-------------|------|----------|-------|-------|
| Pistol | Default | 1 | 0.15s | 0 | Arma inicial |
| Revolver | Explosivo | 2 + 1 AoE | 0.42s | $5 | Explota al impactar (radio 26) |
| SMG | Homing | 1 | 0.085s | 0 | Balas curvan hacia enemigos |
| Scatter | Spread 3 | 1×3 | 0.30s | 0 | 3 balas, spread 14° |
| Flak | Split | 1 | 0.34s | $5 | Se fragmenta en 5 al impactar |
| Ricochet | Rebote + Piercer | 1 | 0.26s | $7 | 5 bounces, atraviesa enemigos |
| Railgun | Piercer | 2 | 0.34s | $7 | Vel 640, atraviesa enemigos |
| Assault Rifle | Burst + Piercer | 1×3 | 0.34s | $12 | Ráfaga 3, spread 6°, cuesta 2 munición |
| Shotgun | Spread 7 | 1×7 | 0.50s | $12 | 7 perdigones piercer, spread 28°, cuesta 3 |
| Laser | Hold-to-fire | 1/tick | 0.04s | $16 | Daño cada 3 ticks, ammo cada 4 ticks |
| Cannon | Piercer + Explosivo | 3 + 2 AoE | 0.55s | $18 | Atraviesa + explota (radio 42), cuesta 3 |

#### Tipos de bala (bullet.gd)
- **Piercer:** Atraviesa enemigos sin destruirse. Trackea hits para no dañar dos veces al mismo.
- **Ricochet:** Rebota en paredes (hasta max_bounces veces). Velocidad constante tras rebote.
- **Homing:** Curva hacia el enemigo más cercano (radio 130px, turn rate 3.0 rad/s).
- **Explosive:** Daño AoE al impactar o al chocar con pared.
- **Split:** Genera N fragmentos en abanico al consumirse.
- **Laser:** Tick-based. Daño en intervalos específicos para rate limit.

### 3.3 Disparo

- Solo se dispara **en el aire** (hacia abajo).
- En tierra, Jump = saltar. En aire, Jump = disparar.
- Laser: hold-to-fire mientras se mantiene Jump en aire.
- Cooldown por arma (modificable por perk Hair Trigger).
- Munición máxima base: 8 (aumentable por perks y shop).

### 3.4 Stomp

- Caer encima de un enemigo = stomp (daño 6, o daño específico por arma).
- Recarga munición + rebote (velocity.y = -250).
- Screen shake + hitstop por arma.
- Stomp invencibilidad breve (0.15s, sin parpadeo visual).

### 3.5 Vida

- 4 HP máximo (aumentable por perks).
- Invencibilidad: 1.0s tras daño (parpadeo). Ampliable por perk Adrenaline.
- Invencibilidad por stomp: breve, sin parpadeo.
- Damage flash: overlay rojo en toda la pantalla (0.15s fade).

### 3.6 Sistema de combo

Se acumula matando enemigos **en el aire** sin tocar suelo. Al aterrizar se cobra:

| Tier | Kills | Recompensa |
|------|-------|------------|
| 0 | 1-7 | Solo puntos |
| 1 | 8-14 | +1 HP |
| 2 | 15-24 | +1 HP, +3 munición bonus |
| 3 | 25+ | +1 HP, +3 munición bonus, 2s invencibilidad |

**Style Bonus:** Alternar stomp/disparo da +1 kill extra al combo.

**Vampire perk:** Heal adicional en cada cash-in independientemente del tier.

**Puntos:** cada kill suma `10 × combo` al score. Cada cash-in suma `combo × 50`.

### 3.7 Dinero

- Recogido de enemigos derrotados y cofres.
- Magnetismo: horizontal 70px (modificable por perk Coin Magnet), vertical 36px, velocidad 120 px/s.
- Se gasta en la tienda de la sala de descanso y en armas de pago.
- Perk Profiteer: +1 moneda extra por cada moneda recogida.
- Perk Gem Power: recoger monedas recarga 2 de munición.
- Perk Popping Gems: recoger monedas dispara una bala hacia arriba.

### 3.8 Score

| Acción | Puntos |
|--------|--------|
| Kill en aire | 10 × combo actual |
| Cash-in de combo | combo × 50 |

### 3.9 Perks (16 disponibles)

Se eligen al final de cada nivel (3 opciones, navegar con ←/→, confirmar con Jump).

| Perk | Efecto | Color |
|------|--------|-------|
| Reinforced Hull | +1 Max HP + full heal | Rojo |
| Extended Mag | +2 Max Ammo | Azul |
| Hair Trigger | Fire 20% más rápido | Verde |
| Coin Magnet | +1 rango de magnetismo de monedas | Dorado |
| Profiteer | +1 moneda extra por moneda | Naranja |
| Swift Boots | +18% velocidad movimiento | Cian |
| Spring Legs | +15% altura salto | Verde claro |
| Sharpshooter | +1 daño de bala | Lavanda |
| Glass Cannon | +2 daño, -1 Max HP | Rojo intenso |
| Adrenaline | +0.4s i-frames al recibir daño | Rosa |
| Vampire | Heal 1 HP en cada cash-in de combo | Rojo oscuro |
| Blast Stomp | Stomps explotan (radio 40, daño 3 AoE) | Naranja |
| Gem Power | Monedas recargan 2 de munición | Cian |
| Popping Gems | Monedas disparan bala arriba | Amarillo |
| Jetpack | Hover (caída lenta) sin munición | Azul claro |
| Youth | +1 opción de perk + heal 1 HP | Verde |

### 3.10 Safety Jetpack

Si el jugador tiene el perk Jetpack, está en el aire sin munición y mantiene Jump: velocity.y se fija en 50 px/s (caída controlada).

---

## 4. Enemigos

### 4.1 Tabla de enemigos

| Enemigo | HP | Velocidad | Drops | Daño al jugador | Comportamiento |
|---------|----|-----------|-------|-----------------|----------------|
| Prisionero | 2 | 40 | $1 | Contacto | Patrulla horizontal. Bala/Stomp |
| Guardia (Warden) | 2 | 40 | $2 | Contacto | Como prisionero. Bala/Stomp |
| Drone | 2 | 45 (chase) | $2 | Contacto | Planea, sigue al jugador. Bob vertical. Bala/Stomp |
| Spider | 3 | 20 (pared) | $3 | Contacto. Stomp DAÑA al jugador | Trepa paredes. Solo bala |
| Floor Drone | 6 | 15 | $5 | Contacto | Patrulla lento. Solo stomp (bullets ricochet) |
| Bat | 2 | 130/80 dive | $2 | Contacto | Planea en posición, se lanza en picado al detectar jugador (180px). Bala/Stomp |
| Frog | 3 | 70 jump | $3 | Contacto | Wind-up 1.5-3s, salta en arco. Bala/Stomp |
| Boss Warden | 20 | 28 | $24 total | Ataques varios | Boss de prisión (nivel 3). 4 ataques |

### 4.2 Variantes por era

En la era **Factory**, los enemigos reciben:
- Tinte azul acero (`Color(0.6, 0.78, 1.0)`)
- Stats mejorados: speed ×1.35, chase_speed ×1.4, patrol_speed ×1.3, dive_speed ×1.3, detection_range ×1.3
- Windup reducido (frogs: ×0.6), +1 HP

### 4.3 Boss Warden (prisión, nivel 3)

| Ataque | Condición | Daño | Telegrafía |
|--------|-----------|------|------------|
| Punch | Cercano (< 52px) | 1 | Animación Attack2 |
| Charge | Lejos horizontal (> 56px) | 1 | Special wind-up 0.6s → dash vel 170 |
| Beam | Arriba + lejos | 1 | Láser con telegraph 0.5s, activo 0.32s |
| Cone | Default | 1 | Cono 90° con telegraph 0.6s, activo 0.3s |

**Arena:** Piso sólido, 2 elevadores laterales (suben 140px al pararse encima).
**Muerte:** Llama a `_on_level_complete()`, suelta 8×$3, pantalla shake 6.0.

### 4.4 Spawn por fase de nivel

Cada nivel se divide en 3 fases según progreso dentro del nivel:

| Fase | Progreso | Max plataformas | Min/Max ancho | Enemy chance | Squad chance |
|------|----------|----------------|---------------|--------------|--------------|
| Intro | 0-20% | 3 | 56-96px | 55% | 15% |
| Escalation | 20-70% | 3 | 44-88px | 75% | 35% |
| Climax | 70-100% | 2 | 36-72px | 90% | 55% |

#### Enemy roster por nivel (prisión)

| Nivel | Enemigos disponibles |
|-------|---------------------|
| 1 | prisoner, bat, drone |
| 2 | prisoner, warden, bat, drone, spider, frog |
| 3 | prisoner, warden, bat, drone, spider, frog, floor_drone |

### 4.5 Squad system (13 formaciones predefinidas)

| Tier | Miembros |
|------|----------|
| Easy | 2 prisoners; prisoner+bat; floor_drone; drone+frog; bat+spider |
| Medium | 2 spiders+bat; 2 frogs; floor_drone+bat; warden+frog+drone |
| Hard | 2 bats+drone; 2 spiders+frog+bat; floor_drone+2 bats; 2 spiders+floor_drone+frog |

### 4.6 Zone templates (8 tipos)

Zonas multi-chunk (3 chunks, 270px) que reemplazan chunks normales:

| Zona | Descripción |
|------|-------------|
| Corridor | Plataformas centradas, columnas laterales, spiders en paredes |
| Chamber | Muchas plataformas dispersas, drones + bats + spiders |
| Staircase | Zigzag izquierda/derecha |
| Bottleneck | Paredes escalonadas que se angostan hacia el centro |
| Cascade | Plataformas escalonadas como cascada, frogs + floor drones |
| Crossfire | Alta densidad, todos los tipos de enemigos |
| Shaft | Perchas alternadas, carril de caída libre amplio |
| Ledges | Plataformas laterales anchas, gap de caída alternado |

---

## 5. Generación procedural

### 5.1 Chunks
- Chunks de 90px de alto.
- 1-3 plataformas por chunk (menos con dificultad).
- Gap mínimo entre plataformas: 20px.
- Paso mínimo garantizado: 48px.

### 5.2 Tipos de plataforma

| Tipo | Nivel mínimo | Peso | Comportamiento |
|------|-------------|------|----------------|
| Static | 1 | 7 | One-way estándar |
| Thin | 1 | 3 | Angosta (24-32px), altura 12px |
| Breakable | 1 | 3 | Se rompe 0.5s tras pisar/disparar |
| Solid | 2 | 2 | Two-way (no se salta desde abajo) |
| Moving | 2 | 3 | Oscila horizontal (rango 60, vel 40) |
| Heated | 2 | 2 | Warm-up 0.5s, daño cada 1s |

### 5.3 Decoración de prisión

Los chunks de prisión pueden generar viñetas coherentes en plataformas largas (≥78px):
- **Desk:** Silla + mesa con taza
- **Crates:** Cajas apiladas
- **Plate:** Placa de presión en el suelo

Paredes: switches ocasionales (22% por chunk).

### 5.4 Peligros de fábrica

- **Wall traps:** Pinchos rojos en paredes (30-60% según fase). Área de daño que daña al jugador al contacto (intervalo 0.75s).
- **Spikes:** Pinchos individuales en el suelo (10-35% según fase). Daño 1 al contacto.

### 5.5 Breathing rooms

Chunks sin enemigos (5-30% según fase). Zona de descanso antes del siguiente encuentro.

### 5.6 Dificultad

```gdscript
var difficulty := clampf(current_depth / 3000.0, 0.0, 1.0)
```
- 0m = más fácil
- 3000m+ = máxima dificultad
- Ancho de plataformas decrece
- Número de plataformas disminuye
- Probabilidad de enemigos aumenta
- Wardens vs prisoners ratio aumenta

---

## 6. Salas de descanso

Cada 900m. Plataforma verde one-way con puerta en la pared del pozo.

### 6.1 Ciclo de salas

3 salas por nivel, orden aleatorio:
1. **Shop** → NPC + 3 ítems comprables
2. **Money** → Cofre rompible con dinero
3. **Weapon** → 3 cartas de arma para elegir

### 6.2 Shop Stance

**NPC:** Arms Dealer con animaciones Idle/Trade. Reproduce "trade" al comprar.

**Ítems de tienda:**

| Ítem | Precio | Efecto |
|------|--------|--------|
| Heal | $3 | +1 HP |
| Ammo Up | $5 | +1 munición máx (permanente) |
| Armor | $8 | Full heal |

**Feedback:** Partículas doradas + texto "SOLD!" flotante.

### 6.3 Money Stance (6 variantes)

| Variante | Piso | Descripción |
|----------|------|-------------|
| Vault | Seguro | Escalera fácil, cofre grande jackpot (~30 monedas) + cofres laterales |
| Crossing | Pinchos | Plataformas pequeñas en zigzag sobre pinchos, cofre en el centro |
| Crumbling | Pinchos | Plataformas que se rompen 0.7s tras pisarlas |
| Greed Tower | Pinchos | Torre vertical de 4 alturas, cofres más valiosos arriba |
| Mimic | Seguro | 7 cofres, 2 son trampas (dañan al abrir en lugar de soltar loot) |
| Gallery | Seguro | Cofres fuera del alcance, hay que dispararlos desde abajo |

### 6.4 Weapon Stance

| Arma | Precio |
|------|--------|
| Pistol, SMG, Scatter | FREE |
| Revolver, Flak | $5 |
| Ricochet, Railgun | $7 |
| Assault Rifle, Shotgun | $12 |
| Laser | $16 |
| Cannon | $18 |

**Desbloqueo por nivel:**
- Nivel 1: pistolas (7 armas)
- Nivel 2: + assault_rifle, shotgun (9 armas)
- Nivel 3: + laser, cannon (11 armas)

Presentación: 3 cartas flotantes con sprite, nombre y precio. Layout aleatorio (fila plana, pico, valle). Al seleccionar, fade out de las demás cartas.

### 6.5 Safe zones

Las áreas de sala de descanso congelan el movimiento de todos los enemigos activos. El combo se preserva mientras el jugador esté en safe zone.

---

## 7. Urge Hazard

Mecánica de presión ascendente. Una banda roja desciende desde arriba de la pantalla.

| Parámetro | Valor |
|-----------|-------|
| Velocidad base | 28 px/s |
| Velocidad máxima | 170 px/s |
| Aceleración | 22 px/s² (tras grace period) |
| Grace period | 2.5s |
| Receso (al progresar) | 450 px/s |
| Margen de reposo | 70px sobre el borde superior |

**Cuándo se pausa/recede:**
- Combo activo (> 0)
- Safe zone
- Cerca del fin de nivel
- Boss activo
- En stance room (x > 400)
- El jugador está progresando (max_camera_y aumentando)

**Cuando atrapa al jugador:**
- Daño 1
- Empuja hacia abajo (velocity.y = 200)
- Screen shake 2.0

**Visual:** Banda roja semitransparente, borde inferior pulsante, dientes triangulares animados.

---

## 8. Audio

### 8.1 Arquitectura
- **Autoload SFX:** Pool de 12 AudioStreamPlayer en bus "SFX".
- **Bus Music:** Separado, -6dB.
- **Autoload Achievements:** Reproduce sonidos propios.

### 8.2 Música por era

| Era | Pista | Estado |
|-----|-------|--------|
| Prisión | Prison1.5.mp3 | ✅ |
| Fábrica | Factory.mp3 | ✅ |
| Laboratorio | — | 📋 |
| Banco | — | 📋 |
| Escape | — | 📋 |

### 8.3 Catálogo de SFX

| Categoría | Sonidos |
|-----------|---------|
| Jugador | shoot, jump×2, landing, damage_taken, death, empty_click |
| Enemigos | death_bones, death_disappear, death_electric, death_robotic, death_heavy_drone |
| Stomp | stomp_bones, stomp_material |
| Bala | bullet_impact, bullet_ricochet×2 |
| Combo | combo_increase, combo_tier_1/2/3 |
| Ambiente | drone_buzz, spider_patrol, invincibility |
| UI | game_over, restart_menu |
| Coleccionables | coin_pickup |

---

## 9. Interfaz (HUD)

Dibujado con `_draw()` custom en `ammo_bar.gd` + `ammo_hud.gd` como contenedor de estado.

| Elemento | Posición | Descripción |
|----------|----------|-------------|
| Barra de munición | Derecha, vertical | Segmentos coloreados por arma, bonus en verde |
| Nombre de arma | Arriba-derecha | Texto en color del arma |
| HP Pips | Arriba-izquierda | Cuadrados rojos (8×8px, gap 3px) |
| Dinero | Izquierda, bajo HP | "$X" dorado |
| Score | Izquierda, bajo money | Puntaje azul claro |
| Profundidad | Arriba-centro | "Xm" blanco |
| Combo | Centro | Escala en color (gris→amarillo→naranja→rojo→rosa) |
| Reward popup | Centro, bajo combo | Texto fade 1.5s |
| Weapon name | Arriba-derecha, sobre ammo bar | "PISTOL", "RAILGUN", etc. |
| Perk icons | Arriba-derecha | Íconos 12×12px, hasta 8 por fila |
| Game Over | Full screen | Overlay oscuro + stats + "JUMP to restart" |
| Level Complete | Full screen | Overlay stats + perk selection overlay |
| Achievement toast | Arriba-centro | Banner deslizante dorado |

### 9.1 Pantalla de Level Complete

| Elemento | Descripción |
|----------|-------------|
| Overlay | Fondo semitransparente |
| Título | "LEVEL X COMPLETE" en verde |
| Stats | Kills, Money, Max Combo, Depth |
| Perk select | 3 cartas de perk superpuestas (navegable con ←/→, confirmar con Jump) |
| Hint | "JUMP to continue" (oculto mientras se muestran perks) |

---

## 10. Logros (Achievements)

Autoload `Achievements` con persistencia en `user://dive_heist_save.cfg`.

### 10.1 Catálogo (17 logros)

| ID | Título | Descripción |
|----|--------|-------------|
| first_kill | First Blood | Derrota a tu primer enemigo |
| combo_10 | Chain Reaction | Alcanza combo x10 |
| combo_25 | Unstoppable | Alcanza combo x25 |
| combo_50 | Bullet Ballet | Alcanza combo x50 |
| depth_500 | Going Down | Desciende 500m en una run |
| depth_1500 | Deep Diver | Desciende 1500m en una run |
| depth_3000 | The Abyss | Desciende 3000m en una run |
| level_1 | Breakout | Completa la prisión (nivel 1) |
| factory | Factory Floor | Alcanza la fábrica (nivel 2) |
| kills_100 | Exterminator | Derrota 100 enemigos totales |
| kills_1000 | Rampage | Derrota 1000 enemigos totales |
| money_500 | Big Heist | Recolecta $500 totales |
| rich | High Roller | Ten $50 en una run |
| gun_nut | Gun Nut | Usa 5 armas diferentes |
| perks_5 | Loaded Out | Ten 5 perks en una run |
| first_death | Welcome to the Heist | Muere por primera vez |
| untouchable | Untouchable | Supera un nivel sin recibir daño |

---

## 11. Arquitectura técnica

### 11.1 Capas de colisión

| Layer | Binario | Uso |
|-------|---------|-----|
| 1 | 0001 | World (suelo, paredes, plataformas) |
| 2 | 0010 | Player |
| 4 | 0100 | Enemies + gem_crate |
| 8 | 1000 | Soft/elevator platforms (player collide, bullets pass through) |

Player collision mask: 1 | 8 (world platforms + elevator platforms).

### 11.2 Estructura de carpetas

```
Scenes/
├── Audio/          sfx_manager.gd
├── Collectibles/   money.gd/.tscn, gem_crate.gd/.tscn
├── Enemies/        enemy.gd, drone.gd, spider.gd, floor_drone.gd,
│                   bat.gd/.tscn, frog.gd/.tscn,
│                   boss_warden.gd/.tscn, boss_beam.gd, boss_cone.gd,
│                   boss_projectile.gd
├── Levels/         world.gd/.tscn, chunk_generator.gd,
│                   parallax_background.gd,
│                   level_end_trigger.gd,
│                   moving_platform.gd, breakable_platform.gd,
│                   heated_platform.gd, elevator_platform.gd,
│                   wall_trap.gd, urge_hazard.gd
├── Player/         player.gd/.tscn
├── Rooms/          room_door.gd/.tscn, shop_item.gd/.tscn,
│                   weapon_pickup.gd/.tscn, weapon_card.gd/.tscn,
│                   rest_room.gd/.tscn, base_room.gd,
│                   shop_stance.gd/.tscn, money_stance.gd/.tscn,
│                   weapon_stance.gd/.tscn
├── Systems/        achievements.gd
├── UI/             ammo_hud.gd/.tscn, ammo_bar.gd,
│                   main_menu.gd/.tscn,
│                   perk_select.gd, perk_panel.gd,
│                   achievement_toast.gd
├── VFX/            death_explosion.gd/.tscn, text_popup.gd/.tscn,
│                   purchase_particles.gd/.tscn
└── Weapons/        bullet.gd/.tscn, muzzle_flash.gd/.tscn
```

### 11.3 Autoloads

| Nombre | Script | Propósito |
|--------|--------|-----------|
| SFX | Scenes/Audio/sfx_manager.gd | Pool de sonido global |
| Achievements | Scenes/Systems/achievements.gd | Logros + persistencia |

### 11.4 Inputs registrados

| Acción | Teclas |
|--------|--------|
| move_left | A, ← |
| move_right | D, → |
| jump | Space, W, ↑ |
| interact | S, ↓ |

---

## 12. Assets disponibles (no integrados)

| Asset | Ruta | Uso potencial |
|-------|------|---------------|
| Arms dealer (Idle/Trade) | Sprites/Craftpix/1.Personajes/trader-cyberpunk-pixel-art/ | NPC comerciante ✅ Integrado |
| 10 sprites de armas | Sprites/Craftpix/free-guns-pack-2/ | Sistema de armas ✅ Integrado |
| Business Center tiles | Sprites/Craftpix/2. Escenarios/business-center-tileset/ | Era Banco |
| Lab tileset | Sprites/Craftpix/2. Escenarios/lab-game-tileset/ | Era Laboratorio |
| Parallax backgrounds | Sprites/Active_Sprites/backgrounds/ | ✅ Integrado (prison ciudad + factory robot) |
| Explosiones | Sprites/Craftpix/Free Pixel Art Explosions/ | Death VFX ✅ Integrado |
| Drones pack | Sprites/Craftpix/craftpix-net-902201-free-drones-pack/ | Variantes de drone (Back/Forward/Death/Idle) |
| City/Business enemies | Sprites/Craftpix/4. Enemies/ | Enemigos eras 3+ |
| Bosses Prison | Sprites/Craftpix/Personajes y enemigos/Bosses_Prison/ | Boss Warden ✅ Integrado |

---

## 13. Product Backlog

> Priorizado por valor (MoSCoW). Items del Sprint 2 marcados completos.

### 🔴 Must Have (Sprint actual — Prison & Factory Alpha)

| ID | Historia de usuario | Estado |
|----|---------------------|--------|
| US-01 | Caer por el pozo disparando y pisando enemigos | ✅ Done |
| US-02 | HUD: munición, vida, combo, dinero | ✅ Done |
| US-03 | Recoger dinero de enemigos | ✅ Done |
| US-04 | Salas de descanso con tienda | ✅ Done |
| US-05 | Tileset de prisión en salas | ✅ Done |
| US-06 | 5 tipos de enemigos + bat + frog | ✅ Done |
| US-07 | Dificultad progresiva | ✅ Done |
| US-08 | Menú principal (Start, Opciones) | ✅ Done |
| US-09 | Pantalla de muerte con stats y retry | ✅ Done |
| US-10 | Parallax background en el pozo | ✅ Done (2 eras) |
| US-11 | NPC comerciante visual en sala | ✅ Done |
| US-12 | Feedback visual de compra (partículas) | ✅ Done |
| US-13 | Sistema de armas visual (11 armas) | ✅ Done |
| US-14 | Partículas de muerte de enemigos | ✅ Done |
| US-15 | Input "interact" como acción formal | ✅ Done |
| US-26 | Sistema de perks (16 perks, selección post-nivel) | ✅ Done |
| US-27 | Urge hazard (presión ascendente) | ✅ Done |
| US-28 | Variedad de plataformas (moving, breakable, heated, elevator) | ✅ Done |
| US-29 | Era Fábrica (tileset, backgrounds, música, enemigos mejorados) | ✅ Done |
| US-30 | Sistema de niveles (fin de nivel, transiciones) | ✅ Done |
| US-31 | Sistema de logros (17 logros con persistencia) | ✅ Done |
| US-32 | Score system | ✅ Done |
| US-33 | Zone templates (8 tipos de zonas multi-chunk) | ✅ Done |
| US-34 | Variantes de sala de dinero (6 layouts) | ✅ Done |
| US-35 | Boss: Warden de prisión (nivel 3) | ✅ Done |
| US-36 | Sistema de squads (13 formaciones enemigas) | ✅ Done |
| US-37 | Peligros de fábrica (wall traps, spikes) | ✅ Done |

### 🟡 Should Have (Sprint 3 — Content)

| ID | Historia | Notas |
|----|----------|-------|
| US-16 | Era Laboratorio (tileset, enemigos, música) | Assets listos en craftpix |
| US-17 | Era Banco (tileset, enemigos, música) | Business center tileset listo |
| US-20 | Música dinámica por era | Prison1.5 + Factory mp3 listos |
| US-21 | Leaderboard local (high scores) | Usar sistema de persistencia existente |
| US-22 | Variantes de sala de armas | Layouts aleatorios |
| US-38 | Más variantes de sala de descanso | Más allá de las 6 actuales |
| US-39 | Boss de fábrica | Diseño por definir |
| US-40 | Decoración de chunks de fábrica | Props industriales |

### 🟢 Could Have (Sprint 4 — Polishing)

| ID | Historia | Notas |
|----|----------|-------|
| US-17 | Era Banco | 3 niveles |
| US-18 | Boss al final de cada era | Prison boss ✅, falta Factory, Lab, Bank, Escape |
| US-19 | Power-ups / armas con mecánicas adicionales | 11 armas ✅, beam weapons, deployables |
| US-41 | Era Escape (ascenso en lugar de descenso) | Mecánica inversa |
| US-42 | Más perks (15 disponibles, expandir a 20+) | |
| US-43 | Logros adicionales | 17 actuales |
| US-44 | Pantalla de opciones completa | Controles remapeables |

### ⚪ Won't Have (ahora)

| ID | Historia | Razón |
|----|----------|-------|
| US-23 | Multijugador | Fuera de scope v1 |
| US-24 | Plataformas móviles/destructibles | ✅ Implementado como moving/breakable |
| US-25 | Sistema de logros | ✅ Implementado |

---

## 14. Definición de Done (DoD)

Una historia de usuario está **Done** cuando:
1. El código compila sin errores ni warnings.
2. La funcionalidad es jugable en la escena principal.
3. Los SFX y visuales básicos están integrados.
4. No hay regresiones en features existentes.

---

## 15. Deuda técnica conocida

| Problema | Impacto | Prioridad |
|----------|---------|-----------|
| Input "interact" hardcodeado resuelto | — | ✅ Resuelto |
| `character_body_2d.tscn` en raíz sin uso resuelto | — | ✅ Resuelto |
| Sistema de armas funcional (11 armas vía WEAPON_DATA + equip_weapon()) | — | ✅ Resuelto |
| Shop items con sprites visuales (ITEM_ICONS) | — | ✅ Resuelto |
| Fuente CyberpunkCraftpixPixel.otf en toda la UI | — | ✅ Resuelto |
| `rest_room.tscn` huérfano (reemplazado por sistema de 3 stances) | Archivo sin uso | Baja |
| Música: solo Prison1.5.mp3 + Factory.mp3, sin tracks para Lab/Bank/Escape | Sin variedad auditiva | Media |
| No existe boss de fábrica/lab/bank/escape | Sin climax al final de cada era | Alta |
| Enemigos de eras 3+ sin diseñar (Lab, Bank, Escape) | Contenido incompleto | Alta |
| `_PRISON_BREAKABLE` hardcodeado en chunk_generator (debería ser era-aware como el resto) | Inconsistencia | Baja |

---

## 16. Convenciones del proyecto

- **Idioma del código:** Inglés (variables, funciones, comentarios técnicos).
- **Idioma del diseño:** Español (GDD, backlog, comunicación).
- **Naming:** snake_case para scripts/scenes, PascalCase para nodos.
- **Collision layers:** 1=World, 2=Player, 4=Enemies, 8=Soft platforms (potencias de 2).
- **Señales:** Conectar en `_ready()` vía código, no en el editor.
- **SFX:** Todo vía autoload `SFX.play_*()`, nunca AudioStreamPlayer directo.
- **Escenas reutilizables:** Prefabs como .tscn con script adjunto.
- **Player lookup:** `get_tree().get_first_node_in_group("player")`.
- **World access:** `get_tree().current_scene` para screen_shake(), hitstop(), add_child.
- **world.gd:** process_mode = PROCESS_MODE_ALWAYS (hitstop timers funcionan con árbol pausado).
