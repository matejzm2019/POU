# Vlastné zvuky

Podporované formáty: `.wav`, `.ogg` a `.mp3`. Skopíruj súbory do tohto priečinka a počkaj na dokončenie importu v Godote.

- Hudba menu a školský ambient: priraď v `res://data/audio/game_audio.tres`.
- Spoločné kroky učiteľov: nastav `default_teacher_footstep` v rovnakom resource.
- Vlastné kroky jednej postavy: nastav `footstep_sound` v jej `res://data/teachers/*.tres`.

Menu a ambient sa automaticky opakujú. Kroky sa prehrávajú pri pohybe priestorovo; počas naháňačky majú rýchlejší interval. Ak pole zostane prázdne, hra vytvorí procedurálny náhradný zvuk.
