extends Node

signal night_loaded(night_data: NightData)
signal night_started(night_data: NightData)
signal night_restarted(night_data: NightData)
signal time_updated(game_time_seconds: float, progress: float)
signal night_completed(night_data: NightData, completion_seconds: float)
signal night_failed(night_data: NightData, reason: String)
signal pause_state_changed(paused: bool)
signal night_stopped

const NIGHT_PATH := "res://data/nights/night_%d.tres"
const UPDATE_INTERVAL := 0.1

var current_night_data: NightData
var current_night_number := 0
var is_night_running := false
var is_night_paused := false
var elapsed_night_time := 0.0
var current_in_game_time := 0.0

var _school_time := SchoolTime.new()
var _timer: Timer
var _last_tick_usec := 0
var _cache: Dictionary = {}


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = UPDATE_INTERVAL
	_timer.timeout.connect(_on_time_tick)
	add_child(_timer)
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed("debug_complete_night"):
		complete_current_night()
		get_viewport().set_input_as_handled()


func get_night_data(night_number: int) -> NightData:
	if night_number < 1 or night_number > 8:
		return null
	if _cache.has(night_number):
		return _cache[night_number] as NightData
	var resource := load(NIGHT_PATH % night_number) as NightData
	if resource != null:
		_cache[night_number] = resource
	return resource


func get_all_nights() -> Array[NightData]:
	var nights: Array[NightData] = []
	for number in range(1, 9):
		var data := get_night_data(number)
		if data != null:
			nights.append(data)
	return nights


func load_night(night_number: int) -> bool:
	var data := get_night_data(night_number)
	if data == null:
		push_error("Night %d could not be loaded." % night_number)
		return false
	stop_night()
	current_night_data = data
	current_night_number = data.night_number
	_school_time.configure(data)
	_sync_time_state()
	night_loaded.emit(data)
	return true


func start_night(night_number := 0) -> bool:
	if night_number > 0 and not load_night(night_number):
		return false
	if current_night_data == null:
		return false
	_school_time.reset()
	is_night_running = true
	_set_pause_state(false)
	_last_tick_usec = Time.get_ticks_usec()
	_timer.start()
	_sync_time_state()
	time_updated.emit(current_in_game_time, get_night_progress())
	night_started.emit(current_night_data)
	return true


func restart_current_night() -> bool:
	if current_night_data == null:
		return false
	_school_time.reset()
	is_night_running = true
	_set_pause_state(false)
	_last_tick_usec = Time.get_ticks_usec()
	_timer.start()
	_sync_time_state()
	time_updated.emit(current_in_game_time, get_night_progress())
	night_restarted.emit(current_night_data)
	return true


func stop_night() -> void:
	var was_running := is_night_running
	is_night_running = false
	if _timer != null:
		_timer.stop()
	_set_pause_state(false)
	if was_running:
		night_stopped.emit()


func complete_current_night() -> bool:
	if not is_night_running or current_night_data == null:
		return false
	var completed_data := current_night_data
	var completion_seconds := elapsed_night_time
	stop_night()
	SaveManager.complete_night(completed_data.night_number, completion_seconds)
	night_completed.emit(completed_data, completion_seconds)
	return true


func fail_current_night(reason := "Night failed") -> bool:
	if not is_night_running or current_night_data == null:
		return false
	var failed_data := current_night_data
	stop_night()
	SaveManager.record_death()
	night_failed.emit(failed_data, reason)
	return true


func set_paused(paused: bool) -> void:
	if not is_night_running or is_night_paused == paused:
		return
	_set_pause_state(paused)


func set_time_scale(scale: float) -> void:
	_school_time.set_time_scale(scale)


func get_night_progress() -> float:
	return _school_time.normalized_progress()


func get_formatted_time(use_24_hour := false, include_seconds := true) -> String:
	if current_night_data == null:
		return "--:--"
	return SchoolTime.format_time(current_in_game_time, use_24_hour, include_seconds)


func get_time_components() -> Dictionary:
	return _school_time.get_components() if current_night_data != null else {"hour": 0, "minute": 0, "second": 0}


func get_active_enemy_ids() -> PackedStringArray:
	return current_night_data.active_enemy_ids.duplicate() if current_night_data != null else PackedStringArray()


func get_difficulty_multipliers() -> Dictionary:
	if current_night_data == null:
		return {"speed": 1.0, "vision": 1.0, "hearing": 1.0}
	return {
		"speed": current_night_data.enemy_speed_multiplier,
		"vision": current_night_data.enemy_vision_multiplier,
		"hearing": current_night_data.enemy_hearing_multiplier,
	}


func _on_time_tick() -> void:
	var now := Time.get_ticks_usec()
	var delta := float(now - _last_tick_usec) / 1000000.0
	_last_tick_usec = now
	if not is_night_running or _school_time.paused:
		return
	var reached_end := _school_time.advance(delta)
	_sync_time_state()
	time_updated.emit(current_in_game_time, get_night_progress())
	if reached_end:
		complete_current_night()


func _sync_time_state() -> void:
	elapsed_night_time = _school_time.elapsed_real_seconds
	current_in_game_time = _school_time.current_game_seconds()


func _set_pause_state(paused: bool) -> void:
	var changed := is_night_paused != paused
	is_night_paused = paused
	_school_time.paused = paused if is_night_running else true
	_last_tick_usec = Time.get_ticks_usec()
	if changed:
		pause_state_changed.emit(paused)
