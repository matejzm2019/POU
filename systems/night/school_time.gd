class_name SchoolTime
extends RefCounted

const DAY_SECONDS := 86400.0

var start_seconds := 0.0
var end_seconds := 0.0
var real_world_duration_seconds := 1.0
var elapsed_real_seconds := 0.0
var elapsed_scaled_seconds := 0.0
var time_scale := 1.0
var paused := true


func configure(data: NightData) -> void:
	start_seconds = data.start_time_seconds()
	end_seconds = data.end_time_seconds()
	real_world_duration_seconds = maxf(data.real_world_duration_seconds, 1.0)
	time_scale = 1.0
	reset()


func reset() -> void:
	elapsed_real_seconds = 0.0
	elapsed_scaled_seconds = 0.0
	paused = true


func advance(delta: float) -> bool:
	if paused or delta <= 0.0:
		return false
	elapsed_real_seconds += delta
	elapsed_scaled_seconds += delta * time_scale
	return is_complete()


func set_time_scale(value: float) -> void:
	time_scale = clampf(value, 0.01, 100.0)


func normalized_progress() -> float:
	return clampf(elapsed_scaled_seconds / real_world_duration_seconds, 0.0, 1.0)


func current_game_seconds() -> float:
	var span := end_seconds - start_seconds
	if span <= 0.0:
		span += DAY_SECONDS
	return fposmod(start_seconds + span * normalized_progress(), DAY_SECONDS)


func is_complete() -> bool:
	return normalized_progress() >= 1.0


func get_components() -> Dictionary:
	var total := current_game_seconds()
	return {
		"hour": floori(total / 3600.0) % 24,
		"minute": floori(total / 60.0) % 60,
		"second": floori(total) % 60,
	}


static func format_time(total_seconds: float, use_24_hour := false, include_seconds := true) -> String:
	var normalized := fposmod(total_seconds, DAY_SECONDS)
	var hour := floori(normalized / 3600.0) % 24
	var minute := floori(normalized / 60.0) % 60
	var second := floori(normalized) % 60
	if use_24_hour:
		return "%02d:%02d:%02d" % [hour, minute, second] if include_seconds else "%02d:%02d" % [hour, minute]
	var display_hour := hour % 12
	display_hour = 12 if display_hour == 0 else display_hour
	var suffix := "AM" if hour < 12 else "PM"
	return "%d:%02d:%02d %s" % [display_hour, minute, second, suffix] if include_seconds else "%d:%02d %s" % [display_hour, minute, suffix]
