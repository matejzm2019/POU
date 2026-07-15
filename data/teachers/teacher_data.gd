class_name TeacherData
extends Resource

@export var teacher_id := ""
@export var display_name := "Učiteľ"
@export var subject_id := ""
@export var model_scene: PackedScene
@export var model_scale := Vector3.ONE
@export var idle_animation := "Idle"
@export var run_animation := "Run"
@export_range(1.0, 10.0, 0.1) var walk_speed := 2.4
@export_range(1.0, 14.0, 0.1) var chase_speed := 5.2
@export_range(1.0, 50.0, 0.5) var hearing_range := 14.0
@export_range(1.0, 60.0, 0.5) var vision_range := 18.0
@export_range(10.0, 170.0, 1.0) var vision_angle_degrees := 80.0
@export var chase_music: AudioStream
@export var footstep_sound: AudioStream
@export var jumpscare_image: Texture2D
@export var jumpscare_sound: AudioStream
@export var active_nights: PackedInt32Array
@export var is_headmistress := false
@export_range(1.0, 2.0, 0.05) var ally_speed_boost := 1.0
@export_range(1.0, 2.0, 0.05) var ally_vision_boost := 1.0
@export_multiline var special_behavior := "Spustí sirénový krik, keď zbadá hráča počas cudzieho prenasledovania."
