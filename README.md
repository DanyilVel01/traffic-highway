# Traffic Dodge 3D

An endless highway arcade game for Godot 4. Control your speed, switch lanes, overtake traffic, and follow coin trails through the gaps.

## Run locally

1. Open Godot 4.5.1 or a compatible Godot 4 release and import `project.godot`.
2. Press **F5** to open the main menu. For **F6**, open `scenes/main.tscn` first.
3. Choose **Play**. Hold **W** / **Up** to accelerate or **S** / **Down** to brake. The car holds its speed when you release the pedals. Press **A** / **D** or **Left** / **Right** to change lanes. Hold **Space** while changing lanes above 50 km/h to drift with the handbrake. Press **Esc** or click **Pause** to pause the run.

**Play** opens a 50-second voiced garage prologue with English subtitles. After the car merges onto the highway, you take the wheel. Press **Esc** to skip the prologue. Restarting a run takes you straight to the highway.

Open **Chapters** to jump to a section, including **Skydive and city**. The driver's jump from the helicopter also starts the first-person descent. Use **WASD** and the mouse to steer, then **Space** to deploy the parachute. After landing, hold **Shift** to sprint, press **Space** to jump, and use **LMB** to fire. Marked drop points let you jump again. High-speed falls are fatal. Enemy bullets take health from a 200 HP pool. A moving vehicle knocks you back, with the strength of the impact depending on its speed.

In the air, hold **W** to dive or **S** to flare. The HUD shows altitude above the surface below you and both vertical and horizontal speed. Coastal City and Ridge City are connected by a highway through the river valley. Approach a driver's door and press **F** to hijack the vehicle. Use **WASD** to drive, **Space** for the handbrake, and **F** to exit.

Press **E** near the café or market entrance to open the door. Pedestrians visit both venues, wait for buses, and may flee or call the police when they hear gunfire.

After landing, follow the story marker to reunite with the crew and broadcast the ledger. **Chapters → Helicopter Wreck** starts on foot by the crashed helicopter, before the pilot's rescue. The city chapter has 16 animated sequences of at least 20 seconds each, including 15 scenes with synthesized English dialogue and subtitles. The two-minute countdown pauses during cinematics. **Chapters → Two Minutes to Impact** starts the final pursuit. Drive to the launch site, exit the vehicle with **F**, and press **E** at the boarding lift before the countdown runs out. Police respond in escalating waves with up to 19 reinforcement officers and five cruisers on the highway. Pistol fire can kill guards, pedestrians, and drivers. Story companions are protected from gunfire.

Erik takes control of the rocket after boarding. Hold **W** to raise launch thrust to 70%. Select **Chapters → Vesper Flight** to start in space. During transfer, use **A/D** to strafe, **Up/Down** to move vertically, **W/S** to adjust throttle, and **Space** to brake. Asteroid impacts damage the hull.

At Vesper, **A/D** and **Up/Down** tilt the lander, **W/S** control thrust, and **Space** fires the lateral braking thrusters. Hover thrust is about 46%. Touch down within 3.2 m of the pad center, with downward speed under 3.4 m/s, lateral drift under 1.85 m/s, and tilt around 7° or less. A failed descent can be retried from the landing checkpoint. Crew dialogue plays in an animated cockpit view while Erik flies.

The game uses the Compatibility renderer and includes all models, materials, and synthesized audio in the project. No plug-ins or separate asset downloads are required.

## Runs and progress

- Each meter adds one point. Passing a vehicle adds 25 points, with 10 extra points for a close pass in the game. Each coin adds 10 points.
- The highway has cars, buses, and trucks. Traffic passes in waves with different speeds. As the run advances, the gaps get shorter and more waves block two lanes.
- At 1,800 m, the highway drops into Crystal Cavern. Giant beetles take over the three lanes underground, where coin trails still mark the safe route.
- The climb out reaches the highway at 4,000 m. Take the marked right lane at 5,000 m to jump through the clouds to the Skyway, where divine chariots take over the traffic. The ramp boosts slower cars to 150 km/h and carries them to the landing. The other lanes stay on the highway.
- Reach 10,000 m on the Skyway to play the castle raid. Drive back for 800 m through oncoming traffic to reach the edge, where the crew makes its helicopter escape.
- The coin trail marks one reachable lane in each wave. Passing waves always leave a gap within one lane of the previous gap.
- Speed and distance are arcade values. A collision ends the run and opens the results screen.
- Completed or abandoned runs bank coins. Spend 30 coins on the **Sunset GT** or 75 on the **Violet Sport** in the Garage. Paint and trim are cosmetic.
- Best score, best distance, coin balance, selected vehicle, unlocks, and settings are stored in `user://save.json`. On Windows the default location is `%APPDATA%\Godot\app_userdata\Traffic Dodge 3D\save.json`.

## Source layout

- `scenes/main.tscn` and `scripts/app.gd` own the menus, HUD, and game states.
- `scenes/game.tscn` and `scripts/game.gd` coordinate the run. The player, camera, traffic scheduler, traffic vehicles, score, and recycled road have separate scripts.
- `scripts/vehicle_visual.gd` builds the vehicle meshes for the game and garage. To use a local GLB, replace the visual factory while preserving the vehicle origin and separately sized collision shape.
- `scripts/save_manager.gd` validates profile data. `scripts/audio_manager.gd` generates music, engine audio, and sound cues and routes them through separate volume buses.
- Set `random_seed` in `scenes/game.tscn` to a nonnegative value for repeatable traffic. The default `-1` randomizes each run.

## Verify

With Godot available on the command line, run `godot --headless --path . --editor --import` to verify import and `godot --headless --path . --quit-after 30` for a startup check.

Run both smoke checks against an isolated profile. This Windows PowerShell example assumes `godot` is on PATH:

```powershell
$previousAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $env:TEMP ('traffic-dodge-smoke-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    godot --headless --path . --fixed-fps 60 --script res://tests/smoke.gd
    if ($LASTEXITCODE -ne 0) { throw 'Gameplay smoke test failed.' }
    godot --headless --path . --script res://tests/smoke.gd -- --check-save
    if ($LASTEXITCODE -ne 0) { throw 'Persistence smoke test failed.' }
} finally {
    $env:APPDATA = $previousAppData
}
```

The first pass checks 10,000 seeded traffic waves, lane input, physical collisions, restarts, purchases, and the city chapter. City checks include parachute landing, gunfire, cutscene durations, police reinforcements, and the countdown. Flight checks include the handoff to Erik, keyboard steering, asteroid damage, landing failures, checkpoint retries, and mission completion. The second process reloads the saved score, unlock, and settings.

