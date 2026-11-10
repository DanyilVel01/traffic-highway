# Traffic Dodge 3D

An endless highway arcade game for Godot 4. Control your speed, switch lanes, overtake traffic, and follow coin trails through the gaps.

## Run locally

1. Open Godot 4.5.1 or a compatible Godot 4 release and import `project.godot`.
2. Press **F5** to open the main menu. For **F6**, open `scenes/main.tscn` first.
3. Choose **Play**. Hold **W** / **Up** to accelerate or **S** / **Down** to brake. The car holds its speed when you release the pedals. Press **A** / **D** or **Left** / **Right** to change lanes. Hold **Space** while changing lanes above 50 km/h to drift with the handbrake. Press **Esc** or click **Pause** to pause the run.

**Play** opens a 50-second voiced garage prologue with English subtitles. After the car merges onto the highway, you take the wheel. Press **Esc** to skip the prologue. Restarting a run takes you straight to the highway.

The game uses the Compatibility renderer and includes all models, materials, and synthesized audio in the project. No plug-ins or separate asset downloads are required.

## Runs and progress

- Each meter adds one point. Passing a vehicle adds 25 points, with 10 extra points for a close pass in the game. Each coin adds 10 points.
- The highway has cars, buses, and trucks. Traffic passes in waves with different speeds. As the run advances, the gaps get shorter and more waves block two lanes.
- At 1,800 m, the highway drops into Crystal Cavern. Giant beetles take over the three lanes underground, where coin trails still mark the safe route.
- The climb out reaches the highway at 4,000 m. Take the marked right lane at 5,000 m to jump through the clouds to the Skyway, where divine chariots take over the traffic. The ramp boosts slower cars to 150 km/h and carries them to the landing. The other lanes stay on the highway.
- Reach 10,000 m on the Skyway to play the castle raid finale. The driver and a partner fight through the stairs and throne hall, take the princess, and make their getaway.
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

The first pass checks 10,000 seeded traffic waves, actual lane input and physical collisions, restart, pause, a long run with bounded object counts, and garage purchases. The second process reloads the saved score, unlock, and settings.

