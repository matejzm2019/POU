class_name NightData
extends Resource

@export_range(1, 8, 1) var night_number := 1
@export var display_name := "First Detention"
@export_group("School Time")
@export_range(0, 23, 1) var start_hour := 23
@export_range(0, 59, 1) var start_minute := 0
@export_range(0, 23, 1) var end_hour := 6
@export_range(0, 59, 1) var end_minute := 0
@export_range(1.0, 7200.0, 1.0, "suffix:s") var real_world_duration_seconds := 600.0
@export_group("Objectives")
@export_range(0, 99, 1) var required_homework_count := 0
@export var optional_special_event_ids := PackedStringArray()
@export_group("Threat Configuration")
@export var active_enemy_ids := PackedStringArray()
@export_range(0.0, 5.0, 0.05) var enemy_speed_multiplier := 1.0
@export_range(0.0, 5.0, 0.05) var enemy_vision_multiplier := 1.0
@export_range(0.0, 5.0, 0.05) var enemy_hearing_multiplier := 1.0
@export var headmistress_active := false
@export_range(0.0, 1.0, 0.05) var chase_music_intensity := 0.0
@export_multiline var difficulty_description := "No threats are active. Learn the school."


func start_time_seconds() -> float:
	return float(start_hour * 3600 + start_minute * 60)


func end_time_seconds() -> float:
	return float(end_hour * 3600 + end_minute * 60)
