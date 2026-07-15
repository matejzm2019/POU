# Development Log

## 2026-07-15 - Initial validation

- Confirmed `project.godot` opens in Godot 4.7.1.
- Added and configured a minimal startup scene.
- Completed headless validation with exit code `0`.

## 2026-07-15 - Phase 1

### Project foundation

- Renamed the project to **Detention: After Hours**.
- Added the requested modular folder structure.
- Configured a 1280x720 viewport, GL Compatibility renderer, Jolt Physics, and Phase 1 input actions.
- Replaced the temporary startup node with a scene-flow coordinator.

### Menu and loading UI

- Added a responsive main menu with a late-night school visual theme.
- Added working Start, Settings preview, Credits, and Quit controls.
- Marked Continue and Night Select as Phase 2 features instead of implementing them early.
- Added a threaded loading screen with progress, status text, and error state.

### Player and interaction

- Added first-person movement, mouse look, sprint, stamina, crouch, jump, and mouse-release pause handling.
- Added a reusable raycast interaction component that discovers interactable parents without coupling to specific props.
- Added an animated interactive classroom door.
- Added a HUD with crosshair, prompt, stamina, objective, placeholder school clock, controls, and pause overlay.

### Placeholder school room

- Added a test school scene with environment lighting and fog.
- Added runtime-generated collision geometry, classroom walls, desks, chairs, teacher desk, lockers, blackboard, and fluorescent lights.
- Used only built-in meshes and materials; no external game assets were introduced.

### Phase boundary

- Did not implement enemies, homework, saves, night resources, synchronized time, audio, scripted scares, or completion/failure flows.
- README documents the intended future content workflows without creating Phase 2 systems.

### Validation

- Fixed a duplicate unique-name collision found by the runtime validator in the menu overlay buttons.
- Confirmed all 17 `res://` references in project files resolve to existing files.
- Loaded and instantiated all seven Phase 1 scenes with `scripts/validate_phase1.gd`.
- Exercised the main menu -> loading screen -> test school transition headlessly.
- Final runtime validation: exit code `0`, no warnings or errors.
- Final editor validation (`--headless --path . --editor --quit`): exit code `0`, no parser or resource errors.

## 2026-07-15 - Phase 2

### Baseline audit

- Read the complete Phase 1 project, README, and development log before editing.
- Confirmed `project.godot`, `main.tscn`, all seven Phase 1 scenes, nine GDScript files, shader, and 17 resource references were valid.
- Confirmed no autoloads or equivalent night/save systems existed.
- Baseline editor and runtime validation both exited `0`.

### Architecture

- Added two autoloads only: `SaveManager` loads first, followed by `NightManager`.
- Kept `scripts/main.gd` as the single scene-flow coordinator.
- Made `SchoolTime` a `RefCounted` object owned by `NightManager`, not a third singleton.
- Used one 0.1-second `Timer` plus monotonic tick deltas; clocks contain no independent time logic.
- Kept future enemy identifiers as `PackedStringArray` values in night resources.
- Isolated automated saves in `user://detention_phase2_test_save.json`.

### Systems created

- `NightData`: exported night metadata, schedule, duration, placeholder homework/events/music, enemy IDs, multipliers, headmistress flag, and difficulty text.
- Eight night resources with the required 0/1/2/3/4/5/6/6 teacher progression and Night 8 headmistress.
- `SchoolTime`: non-retroactive scaling, pause/resume, rollover, 12/24-hour formatting, seconds, and normalized progress.
- `NightManager`: load/start/restart/stop/pause/fail/complete, synchronized updates, signals, and later-phase difficulty queries.
- `SaveManager`: automatic versioned JSON load/save, temporary-file commit, backup recovery, forward-version protection, defaults, field sanitization, migration, progression, best times, deaths, clean reset, and debug unlock.
- Night Selection: eight focusable entries, visible lock enforcement, configuration previews, keyboard/mouse focus, guarded start, and saved selection.
- Main flow: New Game, Continue, Night Select, selected-night loading, completion, and next-night start.
- Reusable digital and analog clocks driven by `NightManager.time_updated`.
- Modular Phase 2 HUD state: current night, synchronized time, progress, start notice, pause, and debug hint.
- Development-only `F8` completion, capped at Night 8.

### Existing Phase 1 fixes

- Routed pause through `NightManager` and stopped player physics while paused.
- Blocked interaction while paused or while the mouse is released.
- Added standing clearance detection before uncrouching.
- Made door opening relative to each instance's closed rotation.

### Files created

- `systems/night/night_data.gd`
- `systems/night/school_time.gd`
- `systems/night/night_manager.gd`
- `systems/save/save_manager.gd`
- `data/nights/night_1.tres` through `data/nights/night_8.tres`
- `characters/clocks/digital_clock.gd`
- `characters/clocks/digital_clock.tscn`
- `characters/clocks/analog_clock.gd`
- `characters/clocks/analog_clock.tscn`
- `scripts/ui/night_selection.gd`
- `scripts/ui/night_complete.gd`
- `ui/night_selection/night_selection.tscn`
- `ui/night_complete.tscn`
- `scripts/validate_phase1.tscn`
- `scripts/validate_phase2.gd`
- `scripts/validate_phase2.tscn`
- Godot-generated `.uid` sidecars for new scripts and shaders where applicable.

### Files modified

- `project.godot`
- `scripts/main.gd`
- `scripts/ui/main_menu.gd`
- `scripts/ui/loading_screen.gd`
- `scripts/ui/hud.gd`
- `ui/main_menu.tscn`
- `ui/loading_screen.tscn`
- `ui/hud.tscn`
- `characters/first_person_controller.gd`
- `characters/player.tscn`
- `systems/interaction_component.gd`
- `systems/door.gd`
- `levels/test_school.tscn`
- `scripts/validate_phase1.gd`
- `README.md`
- `DEVELOPMENT_LOG.md`

### Errors and defects found

- The Phase 1 `--script` validator bypassed normal project autoload creation. Replaced the entry point with `validate_phase1.tscn` and created a normal-scene Phase 2 validator.
- `JSON.parse_string()` logged an engine error for intentionally corrupt input even though recovery succeeded. Replaced it with `JSON.new().parse()` and explicit error handling.
- Corrupt-but-valid JSON could contain wrong-typed numeric or best-time fields. Added safe numeric conversion and per-entry validation.
- The initial pause overlay was cosmetic, interaction remained available while paused, uncrouching ignored ceiling clearance, and rotated door instances lost their base rotation. All four were fixed.
- A review found that changing time scale could retroactively change elapsed school time, saves could be truncated during replacement, and newer-version saves could be downgraded. Time now accumulates scaled deltas, saves use temporary/backup rotation, and forward-version files remain untouched and read-only.
- Locked-night previews, Settings/Credits modal focus, restart/stop pause signals, and clock fallback after a stopped night were hardened for consistent keyboard and listener behavior.
- Reset now removes live, temporary, and backup artifacts before writing defaults, preventing an old backup from reviving cleared progress.

### Validation commands

```powershell
C:\Users\matej\Downloads\godot.exe --headless --path . --editor --quit
C:\Users\matej\Downloads\godot.exe --headless --path . res://scripts/validate_phase1.tscn -- --phase2-test
C:\Users\matej\Downloads\godot.exe --headless --path . res://scripts/validate_phase2.tscn -- --phase2-test
C:\Users\matej\Downloads\godot.exe --headless --path . res://scripts/validate_phase2.tscn -- --phase2-test --phase2-verify
```

- Editor scan: exit `0`.
- Phase 1 regression: seven scenes loaded and instantiated, exit `0`.
- Phase 2 behavior: eight resources and exact enemy-ID progression; rollover, formatting, and mid-night scaling; wrong-typed/corrupt/interrupted/forward-version save handling; keyboard-accessible locking and modal focus; menu routing; natural and F8 completion; analog/digital clock modes and fallback; pause/restart/stop events; unlock; and direct Night 2 start passed; exit `0`.
- Persistence: a second Godot process loaded the saved Night 2 unlock, completion data, selected night, count, and best time, then removed the test save; exit `0`.
- The forward-version preservation test emits one intentional warning and no engine error.

### Remaining Phase 2 limitations

- Homework count, event IDs, enemy IDs/multipliers, settings, chase intensity, deaths, and best-time consumers are data placeholders for later phases.
- No enemy AI, navigation, hiding, homework, jumpscares, audio, power events, or detention cinematic was started.
- Completion and start presentation remain deliberately temporary.
- The analog clock uses built-in placeholder geometry.
- Normal player progress is not reset by automated tests; validators use a separate save file.
