# Detention: After Hours

A Godot 4 first-person school-horror project. Phase 2 adds the complete eight-night configuration, synchronized school time, classroom clocks, save persistence, night selection, Continue flow, and temporary development completion flow on top of the Phase 1 first-person prototype.

## Current scope

Implemented:

- Main menu, threaded loading screen, Night Select, and night-complete placeholder
- First-person movement, sprint/stamina, crouch clearance, jump, interaction, and real pause behavior
- Eight data-driven `NightData` resources
- `NightManager` with start, restart, pause, fail, completion, and difficulty queries
- Timer-driven synchronized school time with midnight rollover and time scaling
- Reusable signal-driven digital and analog classroom clocks
- Versioned JSON save data with recovery, migration defaults, reset, and debug unlock support
- New Game, Continue, locked-night selection, progression, and Night 8 cap
- Development-only `F8` night completion
- Automated Phase 1 regression, Phase 2 behavior, and cross-process persistence validation

Not implemented: homework minigames, enemy AI, navigation, hiding, jumpscares, chase/audio systems, power events, or the opening cinematic. Those remain later phases.

## Project structure

```text
res://
|- assets/                         Future textures and imported 3D models
|- audio/                          Future ambience, music, and effects
|- characters/
|  |- clocks/                      Reusable analog and digital clock scenes
|  `- player.tscn                  First-person player and HUD
|- data/nights/                    Night 1 through Night 8 resources
|- enemies/                        Future enemy scenes
|- levels/                         Test classroom and props
|- scripts/
|  |- levels/                      Placeholder room builder
|  |- ui/                          Menu, selection, loading, HUD, completion
|  `- validate_phase*.{gd,tscn}    Headless validation scenes
|- systems/
|  |- night/                       NightData, SchoolTime, NightManager
|  |- save/                        SaveManager
|  |- door.gd
|  `- interaction_component.gd
|- ui/                             Player-facing UI scenes
|- shaders/                        Menu background shader
|- main.tscn                       Project entry scene
`- project.godot                   Inputs, autoloads, renderer, project settings
```

## Controls

| Action | Input |
|---|---|
| Move | `W`, `A`, `S`, `D` |
| Look | Mouse |
| Sprint | Left `Shift` |
| Crouch | `C` |
| Jump | `Space` |
| Interact | `E` |
| Pause/release mouse | `Esc` |
| Resume/capture mouse | Left click |
| Complete active night (debug builds only) | `F8` |

## Run the project

```powershell
C:\Users\matej\Downloads\godot.exe --path . --editor
```

Press `F5` to start at the main menu. No manual scene or autoload setup is required.

## Night system overview

`SaveManager` and `NightManager` are the only autoloads. `NightManager` owns one `SchoolTime` object, so clocks and HUD elements never maintain independent time. A 0.1-second manager timer samples monotonic engine time, updates the shared clock, and emits `time_updated`.

Typical flow:

```text
Main menu / Night Select
        -> SaveManager validates and stores selection
        -> NightManager loads NightData
        -> loading screen loads test school
        -> NightManager starts SchoolTime
        -> HUD and every clock receive the same signal
        -> completion updates save and unlocks at most Night 8
```

`NightManager` exposes active enemy IDs and speed, vision, and hearing multipliers for later AI phases; Phase 2 does not instantiate enemies.

## NightData resources

Night files are `res://data/nights/night_1.tres` through `night_8.tres`. Each resource configures:

- Number and display name
- Start hour/minute and end hour/minute
- Real-world duration in seconds
- Placeholder homework count
- Active teacher string IDs
- Speed, vision, and hearing multipliers
- Headmistress flag
- Placeholder chase intensity and event IDs
- Player-facing difficulty description

### Configure duration

Edit `real_world_duration_seconds` in the Inspector or `.tres` file. At normal `time_scale = 1.0`, the complete in-game interval is mapped onto this many real seconds. Runtime tests can call `NightManager.set_time_scale(value)`; loading another night restores normal scale.

### Configure start and end time

Edit `start_hour`, `start_minute`, `end_hour`, and `end_minute` using 24-hour values. Midnight rollover is automatic: an end time earlier than or equal to the start is treated as the next day. Example: `23:00` to `06:00` spans seven in-game hours.

### Add or edit a night

To edit a night, open its `.tres` resource and change exported fields. To restore a missing configuration, create a `NightData` resource at `res://data/nights/night_<number>.tres` and keep its `night_number` aligned with the filename.

The game is intentionally capped at eight nights. Supporting Night 9+ would require changing the `NightData` range, `NightManager.get_all_nights()`, save clamps, and selection UI; Phase 2 never unlocks Night 9.

Progression is currently:

| Night | Active IDs | Headmistress |
|---|---:|---|
| 1 | None | No |
| 2 | `teacher_1` | No |
| 3 | `teacher_1`-`teacher_2` | No |
| 4 | `teacher_1`-`teacher_3` | No |
| 5 | `teacher_1`-`teacher_4` | No |
| 6 | `teacher_1`-`teacher_5` | No |
| 7 | `teacher_1`-`teacher_6` | No |
| 8 | `teacher_1`-`teacher_6` | Yes |

## Synchronized clocks

`NightManager.current_in_game_time` is the only source of truth. It provides 12-hour/24-hour formatting, seconds, elapsed real time, and normalized progress.

- `digital_clock.tscn` selects 12/24-hour display and optional seconds, then updates only on manager signals.
- `analog_clock.tscn` derives all hand rotations from the same emitted timestamp. `smooth_movement` uses fractional values; stepped mode uses discrete seconds/minutes.
- Neither scene owns a timer. Adding multiple instances cannot create drift between clocks.
- The digital clock shows its configured fallback when no night is running.

Place clock scenes anywhere in a 3D level. One of each is already on the north classroom wall.

## Save system

`SaveManager` loads automatically and writes JSON to `user://detention_save.json`. Data includes:

- `save_version`
- `highest_unlocked_night`
- `last_selected_night`
- `last_completed_night`
- `settings` placeholder
- `best_completion_time_per_night`
- `total_deaths`
- `total_nights_completed`

Missing or wrong-typed fields are sanitized. Invalid JSON recovers from the last valid backup, or from defaults if no backup exists. Saves are flushed to a temporary file before the live file is replaced, and the previous live file is retained as `.bak`. `save_version` is migrated through a dedicated version step before known fields are sanitized. Saves created by a newer build are left untouched and treated as read-only by the older build.

Continue uses the last selected night when it is unlocked; otherwise it falls back to the highest unlocked night.

### Reset development progress

Use either method:

1. Run `SaveManager.reset_progress()` from a temporary debug/editor script.
2. Close the game, choose **Project > Open User Data Folder**, and delete `detention_save.json`, `detention_save.json.bak`, and `detention_save.json.tmp` if present.

`SaveManager.debug_unlock_all_nights()` unlocks all eight only in debug builds. It is intentionally absent from normal menus.

## Test Phase 2

Manual test:

1. Start the project and choose **Night Select**. Only Night 1 should be available.
2. Start Night 1 and compare the HUD, digital clock, and analog clock.
3. Press `Esc`; school time should stop. Left-click to resume.
4. Press `F8`; the completion screen should appear and Night 2 should unlock.
5. Start Night 2 or return to the menu and use **Continue**.
6. Restart the project and confirm the selected night and unlock persist.

Automated validation uses an isolated `user://detention_phase2_test_save.json`; the second command verifies a fresh-process load and removes it:

```powershell
C:\Users\matej\Downloads\godot.exe --headless --path . --editor --quit
C:\Users\matej\Downloads\godot.exe --headless --path . res://scripts/validate_phase1.tscn -- --phase2-test
C:\Users\matej\Downloads\godot.exe --headless --path . res://scripts/validate_phase2.tscn -- --phase2-test
C:\Users\matej\Downloads\godot.exe --headless --path . res://scripts/validate_phase2.tscn -- --phase2-test --phase2-verify
```

Run the two Phase 2 commands in order. The first deliberately exercises corrupt, interrupted, wrong-typed, and newer-version saves. The newer-version preservation warning is expected.

## Future content workflows

### Teacher models and animations

1. Put `.glb`, `.gltf`, or `.fbx` files under `res://assets/models/enemies/<enemy_name>/`; GLB is preferred.
2. Verify meter scale, Y-up orientation, skeleton, materials, and clips in Advanced Import Settings.
3. Save an inherited model scene under `res://enemies/` if node changes are needed.
4. In the future enemy resource, assign the imported `PackedScene` and map idle, walk, investigate, search, chase, and jumpscare clips. Do not hardcode model or animation paths in AI.

### Jumpscare media

Place images under `res://assets/images/jumpscares/` and audio under `res://audio/jumpscares/`, then assign both to the future enemy resource.

### Homework questions

Future homework resources will live under `res://data/homework/`. Question text is not implemented in Phase 2.

## Export a Windows build

1. Install matching templates from **Editor > Manage Export Templates**.
2. Choose **Project > Export > Add... > Windows Desktop**.
3. Configure executable name, icon, architecture, and output path.
4. Export and test outside the project folder.

After creating a `Windows Desktop` preset:

```powershell
C:\Users\matej\Downloads\godot.exe --headless --path . --export-release "Windows Desktop" build\DetentionAfterHours.exe
```
