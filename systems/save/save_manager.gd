extends Node

signal save_loaded(save_data: Dictionary)
signal save_changed(save_data: Dictionary)
signal progress_reset

const SAVE_VERSION := 1
const SAVE_PATH := "user://detention_save.json"
const TEST_SAVE_PATH := "user://detention_phase2_test_save.json"
const TEMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"

var save_path := SAVE_PATH
var data: Dictionary = {}
var _save_writable := true


func _ready() -> void:
	if "--phase2-test" in OS.get_cmdline_user_args():
		save_path = TEST_SAVE_PATH
	load_save()


func load_save() -> void:
	_save_writable = true
	var parsed: Variant = _read_dictionary(save_path)
	if parsed == null:
		var backup: Variant = _read_dictionary(save_path + BACKUP_SUFFIX)
		if backup is Dictionary:
			var backup_data := backup as Dictionary
			var backup_version := _safe_int(backup_data.get("save_version", 0), 0)
			if backup_version > SAVE_VERSION:
				_save_writable = false
				data = _default_data()
				push_warning("Backup save version %d is newer than this build and was left untouched." % backup_version)
				save_loaded.emit(data.duplicate(true))
				return
			data = _sanitize_and_migrate(backup_data)
			if FileAccess.file_exists(save_path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
			save_now()
			save_loaded.emit(data.duplicate(true))
			return
	if parsed == null and not FileAccess.file_exists(save_path):
		data = _default_data()
		save_now()
		save_loaded.emit(data.duplicate(true))
		return
	if parsed == null:
		_recover_default("Save file was invalid and has been replaced with defaults.")
		return
	var incoming := parsed as Dictionary
	var incoming_version := _safe_int(incoming.get("save_version", 0), 0)
	if incoming_version > SAVE_VERSION:
		_save_writable = false
		data = _default_data()
		push_warning("Save version %d is newer than this build and was left untouched." % incoming_version)
		save_loaded.emit(data.duplicate(true))
		return
	data = _sanitize_and_migrate(incoming)
	save_now()
	save_loaded.emit(data.duplicate(true))


func save_now() -> bool:
	if not _save_writable:
		return false
	var temp_path := save_path + TEMP_SUFFIX
	var backup_path := save_path + BACKUP_SUFFIX
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write temporary save data to %s" % temp_path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	var live_absolute := ProjectSettings.globalize_path(save_path)
	var temp_absolute := ProjectSettings.globalize_path(temp_path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(backup_path) and DirAccess.remove_absolute(backup_absolute) != OK:
			DirAccess.remove_absolute(temp_absolute)
			push_error("Could not replace the previous save backup.")
			return false
		if DirAccess.rename_absolute(live_absolute, backup_absolute) != OK:
			DirAccess.remove_absolute(temp_absolute)
			push_error("Could not preserve the previous save data.")
			return false
	if DirAccess.rename_absolute(temp_absolute, live_absolute) != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_absolute, live_absolute)
		DirAccess.remove_absolute(temp_absolute)
		push_error("Could not commit save data to %s" % save_path)
		return false
	save_changed.emit(data.duplicate(true))
	return true


func is_night_unlocked(night_number: int) -> bool:
	return night_number >= 1 and night_number <= get_highest_unlocked_night()


func get_highest_unlocked_night() -> int:
	return clampi(int(data.get("highest_unlocked_night", 1)), 1, 8)


func get_continue_night() -> int:
	var selected := int(data.get("last_selected_night", 1))
	return selected if is_night_unlocked(selected) else get_highest_unlocked_night()


func select_night(night_number: int) -> bool:
	if not is_night_unlocked(night_number):
		return false
	data["last_selected_night"] = night_number
	return save_now()


func get_setting(key: String, fallback: Variant = null) -> Variant:
	var settings := data.get("settings", {}) as Dictionary
	return settings.get(key, fallback)


func set_setting(key: String, value: Variant) -> bool:
	var settings := data.get("settings", {}) as Dictionary
	settings[key] = value
	data["settings"] = settings
	return save_now()


func complete_night(night_number: int, completion_seconds: float) -> void:
	if night_number < 1 or night_number > 8:
		return
	data["last_completed_night"] = night_number
	data["highest_unlocked_night"] = maxi(get_highest_unlocked_night(), mini(8, night_number + 1))
	data["total_nights_completed"] = maxi(0, int(data.get("total_nights_completed", 0))) + 1
	var best := data.get("best_completion_time_per_night", {}) as Dictionary
	var key := str(night_number)
	if not best.has(key) or completion_seconds < float(best[key]):
		best[key] = maxf(0.0, completion_seconds)
	data["best_completion_time_per_night"] = best
	save_now()


func record_death() -> void:
	data["total_deaths"] = maxi(0, int(data.get("total_deaths", 0))) + 1
	save_now()


func reset_progress() -> void:
	_save_writable = true
	for suffix in [TEMP_SUFFIX, BACKUP_SUFFIX, ""]:
		var artifact_path: String = save_path + str(suffix)
		if FileAccess.file_exists(artifact_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(artifact_path))
	data = _default_data()
	save_now()
	progress_reset.emit()


func debug_unlock_all_nights() -> void:
	if not OS.is_debug_build():
		return
	data["highest_unlocked_night"] = 8
	save_now()


func _recover_default(message: String) -> void:
	push_warning(message)
	data = _default_data()
	save_now()
	save_loaded.emit(data.duplicate(true))


func _read_dictionary(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	return json.data if json.parse(file.get_as_text()) == OK and json.data is Dictionary else null


func _sanitize_and_migrate(source: Dictionary) -> Dictionary:
	var clean := _default_data()
	var version := maxi(0, _safe_int(source.get("save_version", 0), 0))
	if version > SAVE_VERSION:
		push_warning("Save version %d is newer than this build; known fields were preserved." % version)
	while version < SAVE_VERSION:
		match version:
			0:
				version = 1
			_:
				version = SAVE_VERSION
	clean["highest_unlocked_night"] = clampi(_safe_int(source.get("highest_unlocked_night", 1), 1), 1, 8)
	clean["last_selected_night"] = clampi(_safe_int(source.get("last_selected_night", 1), 1), 1, 8)
	clean["last_completed_night"] = clampi(_safe_int(source.get("last_completed_night", 0), 0), 0, 8)
	clean["total_deaths"] = maxi(0, _safe_int(source.get("total_deaths", 0), 0))
	clean["total_nights_completed"] = maxi(0, _safe_int(source.get("total_nights_completed", 0), 0))
	var settings: Variant = source.get("settings", {})
	clean["settings"] = settings.duplicate(true) if settings is Dictionary else {}
	var incoming_best: Variant = source.get("best_completion_time_per_night", {})
	if incoming_best is Dictionary:
		var safe_best: Dictionary = {}
		for key in incoming_best:
			var night := _safe_int(key, 0)
			var raw_value: Variant = incoming_best[key]
			var value := float(raw_value) if raw_value is int or raw_value is float else -1.0
			if night >= 1 and night <= 8 and value >= 0.0:
				safe_best[str(night)] = value
		clean["best_completion_time_per_night"] = safe_best
	clean["save_version"] = SAVE_VERSION
	return clean


func _safe_int(value: Variant, fallback: int) -> int:
	if value is int or value is float:
		return int(value)
	if value is String and (value as String).is_valid_int():
		return (value as String).to_int()
	return fallback


func _default_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"highest_unlocked_night": 1,
		"last_selected_night": 1,
		"last_completed_night": 0,
		"settings": {},
		"best_completion_time_per_night": {},
		"total_deaths": 0,
		"total_nights_completed": 0,
	}
