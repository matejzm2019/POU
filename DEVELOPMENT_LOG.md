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

## 2026-07-15 - Explorable school expansion

### Level and player changes

- Replaced the single procedural detention classroom with a connected school measuring 46 by 58 world units.
- Added a central corridor and six distinct rooms: History, Science, English/Detention, Mathematics, Art, and Computer Science.
- Added subject-specific boards, props, desks, corridor lockers, a school directory, room signs, windows, and distributed lighting.
- Added six interactive classroom doors and centered each door leaf inside its generated opening.
- Added six named, differently colored static teacher placeholders. Teachers have no AI in this change.
- Added `model_scene` and `model_scale` to the teacher placeholder so imported visuals can replace the built-in geometry.
- Moved mouse look from `_unhandled_input` to `_input`, preventing fullscreen HUD controls from consuming rotation events.
- Added a shared yaw/pitch function with vertical clamping and a headless transform regression check.

### Architecture and fixes

- Kept the existing `test_school.tscn` entry point and procedural level architecture; Phase 2 managers, clocks, saves, menus, and progression were not rewritten.
- Assigned door and teacher scenes as exported `PackedScene` dependencies on the school scene instead of script `preload()` calls.
- This fixed two leaked `RefCounted` loader objects observed when the expanded school was loaded twice through Godot's threaded loader.
- Strengthened `validate_phase1.gd` to fail if a root script does not attach and to verify six rooms, six doors, six teachers, yaw, and pitch.

### Files created

- `characters/teachers/placeholder_teacher.gd`
- `characters/teachers/placeholder_teacher.tscn`

### Files modified

- `characters/first_person_controller.gd`
- `levels/test_school.tscn`
- `scripts/levels/test_school.gd`
- `scripts/main.gd`
- `scripts/ui/hud.gd`
- `scripts/validate_phase1.gd`
- `ui/hud.tscn`
- `README.md`
- `DEVELOPMENT_LOG.md`

### Scope boundary

- The six teachers are static visual/collision placeholders only.
- Enemy navigation, patrol, investigation, search, chase, vision, hearing, animation, and jumpscares remain unimplemented.

### Validation

```powershell
C:\Users\matej\Downloads\godot.exe --headless --path . --editor --quit
C:\Users\matej\Downloads\godot.exe --headless --path . res://scripts/validate_phase1.tscn -- --phase2-test
C:\Users\matej\Downloads\godot.exe --headless --path . res://scripts/validate_phase2.tscn -- --phase2-test
C:\Users\matej\Downloads\godot.exe --headless --path . res://scripts/validate_phase2.tscn -- --phase2-test --phase2-verify
```

- Editor/parser/resource scan: exit `0`, no parser or resource errors.
- School regression: eight scenes instantiated; six classrooms, six doors, six teachers, horizontal look, and vertical look passed; exit `0`.
- Complete Phase 2 menu/loading/night/clock/completion/save flow passed on the expanded level; exit `0`.
- Fresh-process persistence passed and removed the isolated test save; exit `0`.
- Static audit found 32 literal engine resource paths and one validated dynamic night pattern with zero missing paths.
- The Phase 2 forward-version test still emits its one expected preservation warning. No loader leaks remain.

## 2026-07-15 - Slovak homework and teacher chase expansion

### School and localization

- Expanded the building to four classroom rows: seven Slovak subject rooms plus `Kabinet` in a 46 x 77 unit school.
- Replaced the old subjects with Dejepis, Matematika, Slovenský jazyk, Elektrotechnika, Ekonomika, Aplikovaná informatika and Anglický jazyk.
- Added one interactive homework station and one subject teacher per subject.
- Rebuilt all eight door openings and frames around 1.8 x 2.9 unit leaves so closed doors fill their openings without visible side or top gaps.
- Preserved player mouse rotation and verified yaw and pitch changes headlessly.
- Translated all player-facing menu, loading, selection, completion, HUD, interaction, homework, classroom, directory and night-configuration text to Slovak.

### Homework and chase architecture

- Added `HomeworkQuestion` and `SubjectData` resources. Every subject has exactly three Slovak four-choice questions.
- Added `TeacherData` resources for seven teachers. Model scene, scale, animations, movement, sensing, media placeholders, active nights and special behavior remain external data rather than model paths in AI.
- Added `SchoolGameManager` as the third autoload to own per-night homework progress, modal input state, blackout, the active subject chase, siren reports and escape rules.
- A wrong answer activates the matching subject teacher and blacks out school fixtures. Teachers open individual doors when they reach them.
- Added active-night observer teachers. A non-chasing teacher that sees the player plays a generated two-tone siren and sends the observed position to the chaser.
- Added patrol, chase-last-known-position and return states to the teacher `CharacterBody3D`, driven by `NavigationAgent3D`.
- Added a runtime-baked `NavigationRegion3D` sourced from static level collision. Animated door bodies are excluded from the bake.
- Added automatic imported-model instantiation and recursive `AnimationPlayer` discovery. The placeholder remains only when `TeacherData.model_scene` is empty.
- Added a 12-second unseen grace period so a chase can finish even when the player leaves before the subject teacher establishes direct vision; normal escape requires five unseen seconds at least 13 units away.
- Added teacher collision to the player's mask and blocked movement/interaction while the homework modal is open.

### Files created

- `data/homework/homework_question.gd`
- `data/homework/subject_data.gd`
- Seven `data/homework/*.tres` subject resources
- `data/teachers/teacher_data.gd`
- `data/teachers/teacher_1.tres` through `teacher_7.tres`
- `systems/school_game_manager.gd`
- `systems/homework/homework_station.gd`
- `levels/props/homework_station.tscn`
- `scripts/ui/homework_screen.gd`
- `ui/homework/homework_screen.tscn`
- `scripts/validate_phase3.gd`
- `scripts/validate_phase3.tscn`
- Godot-generated `.uid` sidecars for the new scripts.

### Important files modified

- `project.godot`
- `levels/test_school.tscn`
- `scripts/levels/test_school.gd`
- `levels/props/classroom_door.tscn`
- `characters/teachers/placeholder_teacher.gd`
- `characters/teachers/placeholder_teacher.tscn`
- `characters/first_person_controller.gd`
- `characters/player.tscn`
- `systems/door.gd`
- `systems/interaction_component.gd`
- All eight night resources and their shared `NightData` defaults
- Menu, loading, night selection, completion and HUD scripts/scenes
- `scripts/validate_phase1.gd`
- `scripts/validate_phase2.gd`
- `README.md`
- `DEVELOPMENT_LOG.md`

### Errors and defects fixed

- Initial door leaves were narrower/shorter than the procedural wall holes. Openings, leaves, collisions and frames now share exact dimensions.
- Initial runtime navigation settings differed from the project navigation map. Cell size, cell height and agent dimensions were aligned before baking.
- A chase could remain active forever when the player escaped before first visual contact. Added a bounded unseen chase grace rule.
- The generated siren stream stayed referenced by headless audio playback at process exit. Headless tests no longer start playback, and teacher teardown stops and clears its stream; verbose validation reports no leaked objects.
- Night 8 originally listed six teachers, but the requested seven subject rooms require seven subject teachers. Night 8 now lists all seven and retains the headmistress data flag.

### Validation

```powershell
C:\Users\matej\Downloads\godot.exe --headless --path . --editor --quit
C:\Users\matej\Downloads\godot.exe --headless --path . res://scripts/validate_phase1.tscn -- --phase2-test
C:\Users\matej\Downloads\godot.exe --headless --path . res://scripts/validate_phase2.tscn -- --phase2-test
C:\Users\matej\Downloads\godot.exe --headless --path . res://scripts/validate_phase2.tscn -- --phase2-test --phase2-verify
C:\Users\matej\Downloads\godot.exe --headless --verbose --path . res://scripts/validate_phase3.tscn -- --phase2-test
```

- Godot 4.7.1 editor/parser/import scan: exit `0`, no parser or resource errors.
- Phase 1 regression: ten scenes loaded and instantiated; seven rooms, seven teachers, eight fitted doors, seven homework stations, navigation region and mouse look passed; exit `0`.
- Phase 2 behavior: night configuration, menus, shared time, clocks, completion and save recovery passed; exit `0`. Its forward-version preservation warning is intentional.
- Phase 2 cross-process persistence: passed and removed the isolated save; exit `0`.
- Homework/chase validation: seven resources, 21 questions, navigation bake, correct/wrong answers, correct subject chaser, door opening, blackout, teacher movement, observer siren, light recovery and Night 2 unlock passed; exit `0` with no leaked objects.
- Static resource audit: 60 unique `res://` paths across 49 files, zero missing literal paths. The main scene and all three autoloads are configured.

### Remaining limitations

- Imported teacher models, authored animations, chase music and jumpscare media are not bundled; their resource slots and placeholder visuals are ready.
- The headmistress is still a Night 8 configuration flag, not an instantiated AI character.
- Hiding, hearing investigation/search, final jumpscare/game-over presentation, opening detention cinematic and authored scare events remain later work.
- Homework completion is tracked for the running night; unfinished individual sets are not serialized between application launches.

## 2026-07-15 - Door traversal and verified teacher pursuit

- Removed the wrong-answer and chase-start HUD warnings; the blackout and moving teacher now communicate the chase directly.
- Open doors immediately disable the leaf collision and restore it only after fully closing, removing the invisible doorway barrier.
- Added eight bidirectional `NavigationLink3D` door portals. The baked room/corridor surfaces were separate islands even though both contained valid polygons; the links now route teachers through the actual openings.
- Teachers open nearby closed doors during patrol, chase and return instead of opening every school door globally.
- Added periodic `NavigationAgent3D` target refresh so a chase started before runtime navigation synchronization recovers automatically.
- Narrowed the teacher navigation/collision radius for reliable single-door passage.
- Expanded the built-in replaceable humanoid placeholders with hair, eyes and a mouth. Imported models still replace the complete placeholder visual.
- Confirmed animation clips are optional; movement translates the complete teacher body even without an `AnimationPlayer`.
- Strengthened Phase 3 validation: an open doorway must have no collision/raycast barrier, and a mathematics teacher must leave the cabinet, open the closed English classroom door and catch a stationary player.

## 2026-07-15 - Locked kabinet, door tween and jumpscare restart

- Changed the kabinet door to start closed and reject player interaction with the Slovak prompt `KABINET JE ZAMKNUTÝ`.
- Added `KabinetPlayerBarrier` on collision layer 3. The player mask includes it; teacher masks do not, so teachers may use the door while the player can never enter behind them.
- Replaced exponential per-frame door interpolation with a 0.45-second sine-eased tween. Opening disables the leaf collider immediately; closing restores it only after the visual reaches the frame.
- Added `JumpscareOverlay`, a full-screen procedural fallback face, flash/scale/shake tween and generated placeholder scream.
- Jumpscare image and sound are read from the catching teacher's `TeacherData`; imported media replaces the fallback without AI changes.
- Suppressed the escape notification on capture, froze player movement after night failure, extended the failure presentation to 2.4 seconds and reloaded the same night with cleared homework progress.
- Updated teacher names: Jindra Kanyicsková, Alžbeta Kéryová, Miroslav Broniš, Mária Šumná, Marián Kováč, Miloš Palaj and Jana Palajová.
- Expanded Phase 1 to 11 scenes and Phase 3 to verify exact names, full door open/close motion, cabinet lock/barrier, both teacher-opened doors, jumpscare visibility/name and clean same-night restart.
- Fixed a validator parser error caused by using inferred typing on a dynamically found door node; the door is now explicitly cast to `Node3D`.

## 2026-07-15 - Desk hiding, persistent doors and morning exit

- Moved each door leaf under a local `Hinge` node. The tween no longer modifies a wall-aligned root transform, so an opened door reaches one unambiguous angle and stays there until explicitly closed.
- Kept the leaf collision disabled for the full open state and restored it only after the closing tween finishes.
- Added collisions to desk legs, chair backs and teacher-desk fronts; increased teacher body/agent radius to `0.38` and baked clearance to `0.5` so furniture is treated as a real obstacle.
- Added 42 `DeskHidingSpot` areas, one under every student desk, plus player enter/exit posture and a dedicated Slovak interaction prompt.
- Hidden players cannot be seen or caught. The subject teacher enters `SEARCH`, roams between school patrol points and can reacquire the player later.
- Search continues while homework UI is open, and homework in other classrooms is allowed while the chaser is searching.
- Reduced all teacher walk/chase speeds to the `1.7-2.0` and `3.8-4.4` ranges.
- Set Night 1 to exactly `600` real seconds. Reaching the synchronized end time now enters a playable morning state instead of completing the night immediately.
- Added a fitted `VÝCHOD` door at the north end of the corridor. It stays locked to the player and unavailable to AI until morning; interacting with it completes the level and unlocks the next night.
- Added `assets/models/teachers/README.md` documenting the `.glb`, `.gltf` and `.fbx` import location.
- Updated Phase 1-3 validators for the hinge hierarchy, persistent open state, furniture, 42 hiding areas, search behavior, ten-minute configuration and morning-exit completion.

### Validation

- Godot 4.7.1 editor/parser/import scan: exit `0`.
- Phase 1 scene regression: 11 scenes, 42 hiding spots, collision furniture and morning exit passed; exit `0`.
- Phase 2 systems test: ten-minute Night 1 and timer-to-morning-to-exit lifecycle passed; exit `0`.
- Phase 3 gameplay test: persistent doors, hiding/search, homework during search, teacher traversal/catch, jumpscare and morning exit passed; exit `0`.

## 2026-07-15 - Native freeze and interaction repair

- Confirmed three Windows `Application Hang` events for Godot 4.7.1; this was a native/main-thread stall, not an intentional player state.
- Removed `NavigationServer3D.map_force_update()` from the asynchronous navigation bake callback and validator. Godot now synchronizes the completed map normally at the end of the next physics frame.
- Increased navigation `cell_size` from `0.25` to `0.5`, reducing runtime voxel work while preserving 1.8 m door passages.
- Disabled unused `NavigationAgent3D` avoidance processing for the seven teachers.
- Fixed unreachable parent traversal in `InteractionComponent._find_interactable()`. Ray hits on a door leaf now resolve to the interactive door root.
- Removed the FPS controller's dependency on `Input.mouse_mode` for keyboard movement. Temporary cursor release no longer zeroes `WASD`, sprint or jump; explicit pause and homework states still stop movement.
- Added gameplay regressions for real movement input, door-child interaction resolution and the absence of runtime force-sync code.
- Preserved all built-in teacher placeholder models. Added a guard explaining that custom visuals belong in `TeacherData.model_scene`, not in the AI wrapper slot.

### Validation after repair

- Isolated Godot 4.7.1 editor/parser/import scan: exit `0`.
- Phase 1: 11 scenes loaded and instantiated; exit `0`.
- Phase 2 and fresh-process persistence: both passed; exit `0`.
- Phase 3: actual `Input.action_press("move_forward")` moved the player, door-child interaction resolved, navigation baked without force-sync, teacher pursuit/catch and all gameplay checks passed; exit `0`.
- Windows Application log recorded zero new Godot hang events during the isolated post-fix runs.

## 2026-07-15 - Pause menu, physical desk hiding and verified door animation

- Added a full `Esc` pause menu. It pauses the complete SceneTree and `NightManager`, releases the mouse, focuses Continue, and resumes through either `Esc` or the button.
- Added a live 50–150 % brightness/gamma slider backed by `Environment.adjustment_brightness`; its value is persisted through `SaveManager.settings`.
- Added a safe Main Menu action that unpauses the tree, closes homework, stops the current night and routes back through `main.gd`.
- Removed the old click-anywhere resume behavior so pause-menu controls cannot accidentally restart gameplay.
- Replaced `E`/teleport/freeze desk hiding with a real body-overlap sensor. The player must hold `C` and physically walk under a raised desk, can keep moving there, cannot stand through the tabletop, and becomes visible again after leaving.
- Reduced crouch capsule height to `0.72 m` and adjusted student desk clearance/legs so the player fits while teachers still treat the furniture as an obstacle.
- Changed the animated door hinge itself to `AnimatableBody3D`, so the visible mesh and physical leaf share the exact same transform.
- Added a persistent non-blocking interaction zone at every frame. The open leaf may disable its blocking collision, but a second `E` can always resolve the door and close it.
- Updated Phase 1–3 validators to use the new hierarchy and to exercise pause/resume, brightness persistence, return-to-menu, two-way door interaction, visible mesh travel, crouch overlap, movement while hidden and AI search.

### Validation

- Godot 4.7.1 editor/parser/import scan: exit `0`, no parser or resource errors.
- Phase 1 scene regression: 11 scenes passed; exit `0`.
- Phase 2 systems and fresh-process persistence tests: both passed; exit `0`.
- Phase 3 gameplay test: pause, brightness, physical hiding, door open/close, navigation, chase, catch, jumpscare and morning exit passed; exit `0`.
- Manual Godot GUI check: pause panel rendered correctly, brightness changed live, Main Menu returned safely, the door leaf visibly rotated away from the frame and a second `E` visibly closed it.

## 2026-07-15 - Headmistress, persistent school roaming, cooldown and replaceable audio

- Added Headmistress Zuzana Čižmáriková as an eighth configurable `TeacherData`-driven placeholder character for Night 8.
- Her active presence boosts subject-teacher movement by 20% and vision range by 25%; her model, animations, footsteps and media remain replaceable through `data/teachers/headmistress.tres`.
- Expanded patrol routes from two corridor points to nine destinations covering the corridor and all seven classrooms.
- A subject teacher released by a wrong answer now keeps patrolling for the rest of the night instead of returning to kabinet, including when that teacher was not normally active on the current night.
- Teachers track the locked kabinet door they opened and close it behind them once the doorway is clear.
- Added a per-subject 30-second retry cooldown after a wrong answer with a live Slovak station prompt and label.
- Added `GameAudioData` and `AudioManager` for replaceable menu music, school ambient and default footsteps. Each `TeacherData` can override its own footstep clip; empty fields use procedural placeholder audio.
- Updated Phase 1 and Phase 3 regressions for eight enemies, the named headmistress, boost values, cooldown blocking/expiry, classroom patrol points, persistent roaming, audio configuration and kabinet-door closure.

### Validation

- Godot 4.7.1 editor/parser/import scan: exit `0`.
- Phase 1: 11 scenes loaded and instantiated; exit `0`.
- Phase 2 systems and fresh-process persistence: both passed; exit `0`.
- Phase 3 gameplay, navigation, cooldown, roaming and door behavior: `PHASE_3_HOMEWORK_CHASE_OK`; exit `0`.
