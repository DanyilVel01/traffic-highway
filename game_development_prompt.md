# System Prompt for Game Modification & Feature Integration (Modular Architecture)

## Objective

Continue the development of the existing game project by integrating a first-person skydiving sequence, first-person player controls, an expanded map, and one-hit death mechanics.

The code must be organized into a **clean modular structure** across dedicated files/components rather than bundled into a single file.

## Project File Architecture

Implement and organize the code into the following distinct modules:

1. `SkydivingSystem` — Freefall physics, mid-air steering, air resistance, and speed effects.
2. `CameraController` — First-person view handling, dynamic camera tilt, motion blur, and wind shake.
3. `UIManager` — On-screen control tutorials/prompts, altimeter, speedometer, and Game Over screen.
4. `Environment / Map` — Extended city map generation/loading, volumetric cloud layer, dynamic rendering, and terrain.
5. `Health / DamageSystem` — Detection and handling of fatal events (impact, vehicle collision, gunshot).
6. `NPCManager` — Teammate/friend AI trajectories ensuring split landings across distant points on the map.

## 1. Skydiving Sequence (Skydiving Phase)

* **Camera System:**
  * Instantly transition to a immersive **First-Person View** upon jumping out of the vehicle.
  * Implement camera shake, motion blur based on fall speed, and procedural camera leaning when turning.

* **Flight Controls:**
  * Full player control over descent trajectory and tilt (`W/A/S/D` for movement + Mouse for free look).
  * Smooth pitch and roll handling to simulate real body flight dynamics.

* **UI & HUD Prompts:**
  * Display clear context-sensitive control instructions on screen (`[W/A/S/D] — Maneuver in air`, `[Space] — Deploy Parachute`).
  * Include a working HUD altimeter and descent speedometer.

* **Graphics & Visual Environment:**
  * High-altitude volumetric clouds that the player passes through.
  * High-detail city view from above (skyscrapers, roads, landmarks) scaling smoothly down to ground level.

* **Squad/Friend Separation:**
  * Teammates jump alongside the player, but their path curves toward random distant landing zones across the map. The player must land independently.

## 2. Seamless Ground Transition & Open World (Ground Phase)

* Parachute deployment seamlessly transitions control to standard ground-level First-Person Shooter (FPS) mechanics upon landing (Walk/Run/Jump).
* **Map Design:** A large, fully navigable city map with buildings, streets, cover, and high-altitude drop points for free exploration.

## 3. High-Stakes Death Mechanics (One-Hit / Critical Damage System)

Integrate instant death triggers that trigger a "Game Over" state and prompt restart via the `UIManager`:

1. **Fall Damage / Crash Death:** Hitting the ground without deploying a parachute or colliding at high speed into buildings/objects during descent.
2. **Vehicle Impact Death:** Getting hit by a moving vehicle on the ground.
3. **Bullet Fatal Death:** Instant death upon receiving a single bullet hit from an enemy NPC or sniper.

## Code Standards & Integration Instructions

* Integrate cleanly with the existing code base without breaking previous functions.
* Keep all code modular, highly optimized, scalable, and commented.