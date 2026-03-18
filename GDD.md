# DIVE HEIST — Game Design Document (GDD)

> **Motor:** Godot 4.6 | **Género:** Roguelike vertical (estilo Downwell) | **Arte:** Pixel art Cyberpunk  
> **Viewport:** 320×448 (ventana 640×896) | **Renderer:** Forward Plus  
> **Última actualización:** 2026-03-18

---

## 1. Visión del juego

**Pitch:** Un roguelike de descenso vertical inspirado en Downwell, ambientado en un mundo cyberpunk. El jugador cae por un pozo disparando hacia abajo, pisoteando enemigos, acumulando combos y comprando mejoras en salas de descanso entre niveles.

**Pilares de diseño:**
- **Acción vertical constante** — Caída libre + disparo + stomps = flow continuo.
- **Riesgo/recompensa** — Los combos otorgan mejores premios, pero perder el combo duele.
- **Progresión por fases** — 5 ambientes temáticos con enemigos y mecánicas únicas.

**Referencia principal:** Downwell (Moppin, 2015)

---

## 2. Estructura del juego

### 2.1 Fases y niveles

| Fase | Ambiente | Niveles | Estado |
|------|----------|---------|--------|
| 1 | Prisión | 3 | 🔨 En desarrollo |
| 2 | Fábrica | 3 | 📋 Backlog |
| 3 | Laboratorio | 3 | 📋 Backlog |
| 4 | Banco | 3 | 📋 Backlog |
| 5 | Escape del Banco | 3 | 📋 Backlog |

Cada nivel = 600m de profundidad procedural. Cada 600m aparece una **sala de descanso**.

### 2.2 Ciclo de juego (game loop)

```
Inicio → Caer por el pozo → Matar enemigos (combo) → Aterrizar (cash-in combo)
    ↓                                                      ↓
Sala de descanso ← (cada 600m) ← Recoger dinero → Repetir
    ↓
Comprar mejoras / Abrir cofre / Recoger arma → Volver al pozo
```

---

## 3. Mecánicas del jugador

### 3.1 Movimiento
| Parámetro | Valor | Input |
|-----------|-------|-------|
| Velocidad horizontal | 130 px/s | A/D o ←/→ |
| Gravedad | 800 px/s² | — |
| Salto | -280 px/s | Space / W / ↑ |
| Retroceso al disparar (aire) | -160 px/s (cap -180) | Automático |

### 3.2 Disparo
- Solo se dispara **en el aire** (hacia abajo).
- Cooldown: 0.15s
- Munición: 8 balas máx (se recarga al tocar suelo o stomps).
- Bala: 400 px/s, daño 1, despawn 2s.

### 3.3 Stomp
- Caer encima de un enemigo = stomp (daño 6).
- Recarga munición + rebote (velocity.y = -250).
- Screen shake 3.0 + hitstop 0.05s.

### 3.4 Vida
- 3 HP máximo.
- Invencibilidad: 1.0s tras daño (parpadeo).
- Invencibilidad por stomp: breve, sin parpadeo.

### 3.5 Sistema de combo
Se acumula matando enemigos **en el aire** sin tocar suelo. Al aterrizar se cobra:

| Tier | Kills | Recompensa |
|------|-------|------------|
| 0 | 1-7 | Solo puntos |
| 1 | 8-14 | +1 HP |
| 2 | 15-24 | +1 HP, +3 munición |
| 3 | 25+ | +1 HP, +3 munición, 2s invencibilidad |

**Style Bonus:** Alternar stomp/disparo da +1 kill extra al combo.

### 3.6 Dinero
- Recogido de enemigos derrotados y cofres.
- Magnetismo: horizontal 70px, vertical 36px, velocidad 120 px/s.
- Se gasta en la tienda de la sala de descanso.

---

## 4. Enemigos

### 4.1 Tabla de enemigos (Fase 1 — Prisión)

| Enemigo | HP | Velocidad | Drops | Daño al jugador | Debilidad |
|---------|----|-----------|-------|------------------|-----------|
| Prisionero | 2 | 40 | $1 | Contacto | Bala / Stomp |
| Guardia (Warden) | 2 | 40 | $2 | Contacto | Bala / Stomp |
| Drone | 2 | 45 (chase) | $2 | Contacto | Bala / Stomp |
| Spider | 3 | 20 (pared) | $3 | Contacto + Stomp daña | Solo bala |
| Floor Drone | 6 | 15 | $5 | Contacto | Solo stomp |

### 4.2 Spawn por chunk (escala con profundidad 0→3000m)
| Tipo | Probabilidad inicio | Probabilidad máx |
|------|---------------------|-------------------|
| Enemigo en plataforma | 60% | 90% |
| Ratio guardia vs prisionero | 30% | 55% |
| Drone (aire) | 20% | 50% |
| Spider (pared) | 15% | 35% |
| Floor Drone (plataforma ancha) | 10% | 25% |

### 4.3 Generación procedural
- Chunks de 90px de alto.
- 1-3 plataformas por chunk (baja a 1-2 con dificultad).
- Plataformas: 48-96px ancho (se estrechan con profundidad).

---

## 5. Salas de descanso

Aparecen cada 600m. Plataforma verde one-way con puerta en la pared del pozo.

### 5.1 Layout de la sala (rest_room.tscn)
- **Dimensiones:** 320×200 px (off-screen en x=600)
- **Estructura:** Suelo, techo, paredes con tiles de prisión
- **Contenido:**
  - Cofre de gemas (izquierda): 3 HP, suelta 12 monedas
  - Tienda (centro): Heal $3, Ammo Up $5, Armor $8
  - Pickup de arma (derecha): +HP o +Munición máx
  - Puerta de salida

### 5.2 Ítems de tienda

| Ítem | Precio | Efecto |
|------|--------|--------|
| Heal | $3 | +1 HP |
| Ammo Up | $5 | +1 munición máx (permanente) |
| Armor | $8 | Full heal |

---

## 6. Audio

### 6.1 Arquitectura
- **Autoload SFX:** Pool de 12 AudioStreamPlayer en bus "SFX".
- **Bus Music:** Separado, -6dB.

### 6.2 Catálogo de SFX

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

## 7. Interfaz (HUD)

Dibujado con `_draw()` custom en ammo_bar.gd:

| Elemento | Posición | Descripción |
|----------|----------|-------------|
| Barra de munición | Derecha, vertical | Segmentos amarillo/gris |
| HP Pips | Arriba-izquierda | 3 cuadrados rojos |
| Dinero | Izquierda, bajo HP | "$X" dorado |
| Profundidad | Abajo-izquierda | Metros descendidos |
| Combo | Centro | Kill count actual |
| Reward popup | Centro | Tier text 1.5s fade |
| Game Over | Full screen | Overlay con mensaje |

---

## 8. Arquitectura técnica

### 8.1 Capas de colisión
| Layer | Uso |
|-------|-----|
| 1 | World (suelo, paredes, plataformas) |
| 2 | Player |
| 4 | Enemies (las balas detectan layer 4) |

### 8.2 Estructura de carpetas
```
Scenes/
├── Audio/        sfx_manager.gd
├── Collectibles/ money.gd/.tscn, gem_crate.gd/.tscn
├── Enemies/      enemy.gd, drone.gd, spider.gd, floor_drone.gd + .tscn
├── Levels/       world.gd/.tscn, chunk_generator.gd
├── Player/       player.gd/.tscn
├── Rooms/        room_door.gd/.tscn, shop_item.gd/.tscn,
│                 weapon_pickup.gd/.tscn, rest_room.gd/.tscn
├── UI/           ammo_hud.gd/.tscn, ammo_bar.gd
└── Weapons/      bullet.gd/.tscn, muzzle_flash.gd/.tscn
```

### 8.3 Autoloads
| Nombre | Script | Propósito |
|--------|--------|-----------|
| SFX | Scenes/Audio/sfx_manager.gd | Pool de sonido global |

### 8.4 Inputs registrados
| Acción | Teclas |
|--------|--------|
| move_left | A, ← |
| move_right | D, → |
| jump | Space, W, ↑ |
| interact | S, ↓ |

---

## 9. Assets disponibles (no integrados)

| Asset | Ruta | Uso potencial |
|-------|------|---------------|
| Arms dealer (Idle/Trade) | Sprites/Craftpix/1.Personajes/trader-cyberpunk-pixel-art/ | NPC comerciante visual |
| 10 sprites de armas | Sprites/Craftpix/free-guns-pack-2/ | Sistema de armas visual |
| Business Center tiles | Sprites/Craftpix/2. Escenarios/business-center-tileset/ | Fase Banco |
| Factory tileset | Sprites/Craftpix/2. Escenarios/factory-pixel-art-32x32/ | Fase Fábrica |
| Lab tileset | Sprites/Craftpix/2. Escenarios/lab-game-tileset/ | Fase Laboratorio |
| Parallax backgrounds | Sprites/Craftpix/3. Backgrounds/ | Fondo parallax |
| Explosiones | Sprites/Craftpix/Free Pixel Art Explosions/ | Efectos VFX |
| Drones pack | Sprites/Craftpix/craftpix-net-902201-free-drones-pack/ | Variantes de drone |
| City/Business enemies | Sprites/Craftpix/4. Enemies/ | Enemigos fase 2+ |

---

## 10. Product Backlog

> Priorizado por valor (MoSCoW) para sprints futuros.

### 🔴 Must Have (Sprint actual — Prison Alpha)

| ID | Historia de usuario | Criterio de aceptación | Estado |
|----|---------------------|------------------------|--------|
| US-01 | Como jugador, quiero caer por un pozo disparando y pisando enemigos | Movimiento, gravedad, disparo, stomp funcionan | ✅ Done |
| US-02 | Como jugador, quiero ver mi munición, vida y combo en pantalla | HUD muestra ammo bar, HP pips, combo, dinero | ✅ Done |
| US-03 | Como jugador, quiero recoger dinero de enemigos | Drops magnéticos, se muestran en HUD | ✅ Done |
| US-04 | Como jugador, quiero salas de descanso con tienda | Puerta → sala con cofre, tienda, pickup, salida | ✅ Done |
| US-05 | Como jugador, quiero que las salas usen tiles del tileset | Paredes, suelo, techo, fondo, decoraciones del Prison tileset | ✅ Done |
| US-06 | Como jugador, quiero 5 tipos de enemigos con comportamiento distinto | Prisionero, guardia, drone, spider, floor drone | ✅ Done |
| US-07 | Como jugador, quiero dificultad progresiva | Más enemigos, plataformas estrechas con profundidad | ✅ Done |

### 🟡 Should Have (Sprint 2 — Polish & Feel)

| ID | Historia | Notas |
|----|----------|-------|
| US-08 | Menú principal (Start, Opciones) | Escena separada, transición a world |
| US-09 | Pantalla de muerte con stats y retry | Mostrar profundidad, kills, dinero. Botón reiniciar |
| US-10 | Parallax background en el pozo | Usar craftpix backgrounds, 2-3 capas |
| US-11 | NPC comerciante visual en sala | Sprite Arms dealer Idle/Trade, animación al comprar |
| US-12 | Feedback visual de compra (particulas) | Efecto al comprar, texto "SOLD" |
| US-13 | Sistema de armas visual | Sprite de arma cambia, usando gun sprites pack |
| US-14 | Partículas de muerte de enemigos | Explosión pixel, sprites del pack explosiones |
| US-15 | Input "interact" como acción formal | ~~Registrar en project.godot, no hardcodear S/Down~~ ✅ Done |

### 🟢 Could Have (Sprint 3 — Content)

| ID | Historia | Notas |
|----|----------|-------|
| US-16 | Fase 2: Fábrica (tileset + enemigos) | factory-tileset, nuevos enemigos |
| US-17 | Fase 3: Laboratorio | lab-tileset, nuevos enemigos |
| US-18 | Boss al final de cada fase (cada 3 niveles) | Diseño por definir |
| US-19 | Power-ups / armas con mecánicas diferentes | Spread, laser, burst — cambian disparo |
| US-20 | Música dinámica por fase | Tracks distintos por ambiente |
| US-21 | Leaderboard local (high scores) | Guardar en user:// |
| US-22 | Variantes de sala de descanso | Layouts aleatorios, no siempre la misma |

### ⚪ Won't Have (ahora)

| ID | Historia | Razón |
|----|----------|-------|
| US-23 | Multijugador | Fuera de scope v1 |
| US-24 | Plataformas móviles/destructibles | Complejidad excesiva para alpha |
| US-25 | Sistema de logros | Post-lanzamiento |

---

## 11. Definición de Done (DoD)

Una historia de usuario está **Done** cuando:
1. El código compila sin errores ni warnings.
2. La funcionalidad es jugable en la escena principal.
3. Los SFX y visuales básicos están integrados.
4. No hay regresiones en features existentes.

---

## 12. Deuda técnica conocida

| Problema | Impacto | Prioridad |
|----------|---------|-----------|
| ~~Input "interact" hardcodeado~~ | ~~Dificulta remapeo~~ | ✅ Resuelto |
| ~~`character_body_2d.tscn` en raíz sin uso~~ | ~~Archivo huérfano~~ | ✅ Resuelto |
| weapon_pickup no cambia arma realmente | Feature incompleta | Alta |
| Shop items sin sprite visual del ítem | UX pobre | Media |
| Combo reward text usa Label default | Inconsistencia visual | Baja |

---

## 13. Convenciones del proyecto

- **Idioma del código:** Inglés (variables, funciones, comentarios técnicos).
- **Idioma del diseño:** Español (GDD, backlog, comunicación).
- **Naming:** snake_case para scripts/scenes, PascalCase para nodos.
- **Collision layers:** 1=World, 2=Player, 4=Enemies (potencias de 2).
- **Señales:** Conectar en `_ready()` vía código, no en el editor.
- **SFX:** Todo vía autoload `SFX.play_*()`, nunca AudioStreamPlayer directo.
- **Escenas reutilizables:** Prefabs como .tscn con script adjunto.
