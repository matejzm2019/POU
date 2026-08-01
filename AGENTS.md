# Godot workspace safety

- Reuse the already-open Godot editor. Never launch a second GUI editor for validation.
- Do not run `--headless --editor --quit` while the GUI editor has this project open; both instances may touch the same editor/import state.
- Run gameplay validation with persistent project scenes and a dedicated log, for example `--headless --path . --log-file .godot/phase1-headless.log res://...`.
- Every simultaneous Godot process must have a different `--log-file`; the live editor and a headless test must never rotate the same `user://logs/godot.log`.
- Prefer `powershell -ExecutionPolicy Bypass -File scripts/validate_project.ps1`; it gives each validation run isolated `APPDATA`, `LOCALAPPDATA`, save data, and log files.
- Never create a temporary scene, open it in the live editor, then delete it while the editor still references it.
- Never delete or replace a `.tscn` currently open in the editor. Switch to a persistent scene and confirm the old tab is closed first.
- Let Godot child processes exit normally and wait for them before starting another validation process.
- Keep temporary logs and user data outside `res://`; remove them only after every Godot process using them has exited.
