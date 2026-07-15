extends Node

var _failures: Array[String] = []
var _continue_emitted := 0
var _pause_events: Array[bool] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if "--phase2-verify" in OS.get_cmdline_user_args():
		await _verify_persistence()
	else:
		await _validate_phase2()


func _validate_phase2() -> void:
	_check(get_node_or_null("/root/SaveManager") != null, "SaveManager autoload is missing.")
	_check(get_node_or_null("/root/NightManager") != null, "NightManager autoload is missing.")
	_validate_night_resources()
	_validate_school_time()
	_validate_save_recovery()
	await _validate_natural_completion()
	await _validate_selection_locking()
	await _validate_main_flow_and_clocks()
	_finish("PHASE_2_VALIDATION_OK")


func _validate_night_resources() -> void:
	var nights := NightManager.get_all_nights()
	var expected_counts := [0, 1, 2, 3, 4, 5, 6, 6]
	_check(nights.size() == 8, "Expected eight NightData resources.")
	for index in mini(nights.size(), 8):
		var data := nights[index]
		_check(data.night_number == index + 1, "Night resource numbering is incorrect at index %d." % index)
		_check(data.active_enemy_ids.size() == expected_counts[index], "Night %d has the wrong enemy count." % data.night_number)
		for enemy_index in data.active_enemy_ids.size():
			_check(data.active_enemy_ids[enemy_index] == "teacher_%d" % (enemy_index + 1), "Night %d has an incorrect enemy ID order." % data.night_number)
		_check(data.headmistress_active == (data.night_number == 8), "Night %d headmistress flag is incorrect." % data.night_number)
		_check(data.real_world_duration_seconds > 0.0, "Night %d duration must be positive." % data.night_number)


func _validate_school_time() -> void:
	var clock := SchoolTime.new()
	clock.configure(NightManager.get_night_data(1))
	clock.paused = false
	clock.advance(clock.real_world_duration_seconds * 0.5)
	var parts := clock.get_components()
	_check(is_equal_approx(clock.normalized_progress(), 0.5), "School time midpoint progress is incorrect.")
	_check(parts.hour == 2 and parts.minute == 30, "Midnight rollover should reach 2:30 AM at Night 1 midpoint.")
	_check(SchoolTime.format_time(clock.current_game_seconds(), false, false) == "2:30 AM", "12-hour formatting is incorrect.")
	_check(SchoolTime.format_time(clock.current_game_seconds(), true, false) == "02:30", "24-hour formatting is incorrect.")
	var before_pause := clock.current_game_seconds()
	clock.paused = true
	clock.advance(20.0)
	_check(is_equal_approx(clock.current_game_seconds(), before_pause), "Paused school time advanced.")
	clock.reset()
	clock.paused = false
	clock.advance(clock.real_world_duration_seconds * 0.25)
	clock.set_time_scale(2.0)
	_check(is_equal_approx(clock.normalized_progress(), 0.25), "Changing time scale altered past elapsed time.")
	clock.paused = false
	_check(not clock.advance(clock.real_world_duration_seconds * 0.25), "Scaled school time completed too early.")
	_check(clock.advance(clock.real_world_duration_seconds * 0.125), "Scaled school time did not report completion.")


func _validate_save_recovery() -> void:
	SaveManager.reset_progress()
	_check(not FileAccess.file_exists(SaveManager.save_path + SaveManager.BACKUP_SUFFIX), "Reset progress retained an old backup.")
	_check(SaveManager.get_highest_unlocked_night() == 1, "Default save should unlock only Night 1.")
	SaveManager.data["last_selected_night"] = 8
	_check(SaveManager.get_continue_night() == 1, "Continue did not fall back from a locked saved selection.")
	var partial := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	partial.store_string('{"highest_unlocked_night":[],"best_completion_time_per_night":{"bad":{},"1":"invalid"}}')
	partial.close()
	SaveManager.load_save()
	_check(int(SaveManager.data.get("save_version", 0)) == SaveManager.SAVE_VERSION, "Missing save fields were not migrated.")
	var corrupt := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	corrupt.store_string("{not valid json")
	corrupt.close()
	SaveManager.load_save()
	_check(SaveManager.get_highest_unlocked_night() == 1, "Corrupted save did not recover to defaults.")
	SaveManager.reset_progress()
	SaveManager.save_now()
	var live_absolute := ProjectSettings.globalize_path(SaveManager.save_path)
	_check(DirAccess.remove_absolute(live_absolute) == OK, "Could not simulate interrupted save replacement.")
	SaveManager.load_save()
	_check(FileAccess.file_exists(SaveManager.save_path), "Backup save was not restored when the live file was missing.")
	var future := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	future.store_string('{"save_version":999,"future_field":"preserve"}')
	future.close()
	SaveManager.load_save()
	_check(not SaveManager.save_now(), "A newer save version remained writable.")
	var untouched := FileAccess.get_file_as_string(SaveManager.save_path)
	_check(untouched.contains('"save_version":999') and untouched.contains('"future_field":"preserve"'), "Newer save data was downgraded or overwritten.")
	SaveManager.reset_progress()


func _validate_natural_completion() -> void:
	var data := NightManager.get_night_data(1)
	var original_duration := data.real_world_duration_seconds
	data.real_world_duration_seconds = 0.2
	_check(NightManager.load_night(1), "Natural-completion test could not load Night 1.")
	data.real_world_duration_seconds = original_duration
	_check(NightManager.start_night(), "Natural-completion test could not start Night 1.")
	var deadline := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < deadline and NightManager.is_night_running:
		await get_tree().process_frame
	_check(not NightManager.is_night_running, "NightManager did not complete at the configured end time.")
	_check(SaveManager.get_highest_unlocked_night() == 2, "Natural completion did not unlock Night 2.")
	SaveManager.reset_progress()


func _validate_selection_locking() -> void:
	var scene := load("res://ui/night_selection/night_selection.tscn") as PackedScene
	var selection := scene.instantiate() as NightSelectionScreen
	add_child(selection)
	await get_tree().process_frame
	var night_one := selection.find_child("NightButton1", true, false) as Button
	var night_eight := selection.find_child("NightButton8", true, false) as Button
	_check(night_one != null and not night_one.disabled, "Night 1 should be selectable.")
	_check(night_eight != null and bool(night_eight.get_meta("locked")), "Night 8 should be visibly locked in a default save.")
	night_eight.grab_focus()
	await get_tree().process_frame
	_check(selection.get_node("%NightName").text == "THE HEADMISTRESS", "Locked Night 8 details are not keyboard-accessible.")
	_check((selection.get_node("%StartNightButton") as Button).disabled, "Locked Night 8 can be started.")
	night_eight.pressed.emit()
	_check(int(SaveManager.data.get("last_selected_night", 1)) == 1, "Locked Night 8 was selected.")
	selection.queue_free()
	await get_tree().process_frame
	var menu := (load("res://ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	add_child(menu)
	menu.continue_requested.connect(_capture_continue)
	(menu.find_child("ContinueButton", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	_check(_continue_emitted == 1, "Continue did not emit the last valid night.")
	(menu.find_child("SettingsButton", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	_check((menu.find_child("StartButton", true, false) as Button).disabled, "Settings modal did not disable underlying actions.")
	_check(get_viewport().gui_get_focus_owner() == menu.find_child("SettingsBackButton", true, false), "Settings modal did not trap focus on its control.")
	(menu.find_child("SettingsBackButton", true, false) as Button).pressed.emit()
	_check(not (menu.find_child("StartButton", true, false) as Button).disabled, "Closing Settings did not restore menu actions.")
	menu.queue_free()
	await get_tree().process_frame


func _validate_main_flow_and_clocks() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	NightManager.pause_state_changed.connect(_capture_pause)
	add_child(main)
	await get_tree().process_frame
	var menu := main.find_child("MainMenu", false, false) as MainMenu
	_check(menu != null, "Main scene did not open the menu.")
	if menu == null:
		return
	_check(not (menu.find_child("ContinueButton", true, false) as Button).disabled, "Continue button is disabled.")
	_check(not (menu.find_child("NightSelectButton", true, false) as Button).disabled, "Night Select button is disabled.")
	(menu.find_child("NightSelectButton", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	var routed_selection := main.find_child("NightSelection", false, false) as NightSelectionScreen
	_check(routed_selection != null, "Main menu did not open Night Select.")
	if routed_selection != null:
		routed_selection.back_requested.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		menu = main.find_child("MainMenu", false, false) as MainMenu
	_check(menu != null, "Night Select did not return to the main menu.")
	if menu == null:
		main.queue_free()
		return
	menu.start_requested.emit()
	var level := await _wait_for_child(main, "TestSchool", 5000)
	_check(level != null, "New Game did not reach the test school.")
	_check(NightManager.is_night_running and NightManager.current_night_number == 1, "Night 1 did not start.")
	if level == null:
		main.queue_free()
		return
	await get_tree().create_timer(0.25).timeout
	var digital := level.find_child("DigitalClock", true, false) as DigitalSchoolClock
	var analog := level.find_child("AnalogClock", true, false) as AnalogSchoolClock
	_check(digital != null, "Digital classroom clock is missing.")
	_check(analog != null, "Analog classroom clock is missing.")
	if digital != null:
		_check(digital.get_node("Display").text == NightManager.get_formatted_time(false, false), "Digital clock is not synchronized.")
	if analog != null:
		var total := NightManager.current_in_game_time
		var expected_hour := -TAU * fposmod(total / 3600.0, 12.0) / 12.0
		var expected_minute := -TAU * fposmod(total / 60.0, 60.0) / 60.0
		var expected_second := -TAU * fposmod(total, 60.0) / 60.0
		_check(absf(angle_difference(analog.get_node("Hands/HourHand").rotation.z, expected_hour)) < 0.15, "Analog hour hand rotation is incorrect.")
		_check(absf(angle_difference(analog.get_node("Hands/MinuteHand").rotation.z, expected_minute)) < 0.15, "Analog minute hand rotation is incorrect.")
		_check(absf(angle_difference(analog.get_node("Hands/SecondHand").rotation.z, expected_second)) < 0.3, "Analog second hand rotation is incorrect.")
		var stepped := (load("res://characters/clocks/analog_clock.tscn") as PackedScene).instantiate() as AnalogSchoolClock
		stepped.smooth_movement = false
		level.add_child(stepped)
		stepped.call("_on_time_updated", 36661.9, 0.0)
		_check(absf(angle_difference(stepped.get_node("Hands/MinuteHand").rotation.z, -TAU * 11.0 / 60.0)) < 0.001, "Stepped analog minute hand is not discrete.")
		stepped.queue_free()
	var time_before_pause := NightManager.current_in_game_time
	NightManager.set_paused(true)
	await get_tree().create_timer(0.25).timeout
	_check(is_equal_approx(time_before_pause, NightManager.current_in_game_time), "Paused NightManager time advanced.")
	_check(NightManager.restart_current_night(), "Night restart failed.")
	_check(_pause_events.size() >= 2 and _pause_events[-2] and not _pause_events[-1], "Restart did not emit the resumed pause state.")
	await get_tree().create_timer(0.25).timeout
	_check(NightManager.current_in_game_time != NightManager.current_night_data.start_time_seconds(), "Restarted NightManager time did not advance.")
	_check(NightManager.get_active_enemy_ids().is_empty(), "Night 1 enemy query should be empty.")
	NightManager.set_paused(true)
	NightManager.stop_night()
	await get_tree().process_frame
	_check(_pause_events.size() >= 4 and _pause_events[-2] and not _pause_events[-1], "Stopping a paused night did not emit resume state.")
	if digital != null:
		_check(digital.get_node("Display").text == digital.fallback_text, "Digital clock did not show fallback after stop.")
	NightManager.start_night()
	var debug_event := InputEventAction.new()
	debug_event.action = "debug_complete_night"
	debug_event.pressed = true
	NightManager._unhandled_input(debug_event)
	await get_tree().process_frame
	await get_tree().process_frame
	var complete_screen := main.find_child("NightComplete", false, false) as NightCompleteScreen
	_check(complete_screen != null, "Night-complete placeholder did not open.")
	_check(SaveManager.get_highest_unlocked_night() == 2, "Completing Night 1 did not unlock Night 2.")
	_check(int(SaveManager.data.get("last_completed_night", 0)) == 1, "Completed night was not saved.")
	if complete_screen != null:
		(complete_screen.find_child("NextButton", true, false) as Button).pressed.emit()
		var deadline := Time.get_ticks_msec() + 5000
		while Time.get_ticks_msec() < deadline and (NightManager.current_night_number != 2 or not NightManager.is_night_running):
			await get_tree().process_frame
		_check(NightManager.current_night_number == 2 and NightManager.is_night_running, "Continue to Night 2 did not start the unlocked night.")
	var selection := (load("res://ui/night_selection/night_selection.tscn") as PackedScene).instantiate() as NightSelectionScreen
	add_child(selection)
	await get_tree().process_frame
	_check(not bool((selection.find_child("NightButton2", true, false) as Button).get_meta("locked")), "Night 2 was not unlocked in Night Select.")
	_check(bool((selection.find_child("NightButton3", true, false) as Button).get_meta("locked")), "Night 3 unlocked too early.")
	selection.queue_free()
	main.queue_free()
	NightManager.stop_night()
	await get_tree().process_frame


func _verify_persistence() -> void:
	_check(int(SaveManager.data.get("save_version", 0)) == SaveManager.SAVE_VERSION, "Persisted save version is invalid.")
	_check(SaveManager.get_highest_unlocked_night() == 2, "Night 2 unlock did not persist across restart.")
	_check(int(SaveManager.data.get("last_completed_night", 0)) == 1, "Last completed night did not persist.")
	_check(int(SaveManager.data.get("total_nights_completed", 0)) == 1, "Completion total did not persist.")
	var best := SaveManager.data.get("best_completion_time_per_night", {}) as Dictionary
	_check(best.has("1"), "Best Night 1 completion time did not persist.")
	_check(int(SaveManager.data.get("last_selected_night", 0)) == 2, "Selected Night 2 did not persist.")
	_check(SaveManager.get_continue_night() == 2, "Continue did not use the last selected unlocked night.")
	SaveManager.reset_progress()
	for suffix in ["", SaveManager.TEMP_SUFFIX, SaveManager.BACKUP_SUFFIX]:
		var path: String = SaveManager.save_path + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_finish("PHASE_2_PERSISTENCE_OK")


func _wait_for_child(parent: Node, child_name: String, timeout_ms: int) -> Node:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		var child := parent.find_child(child_name, false, false)
		if child != null:
			return child
		await get_tree().process_frame
	return null


func _capture_continue(night_number: int) -> void:
	_continue_emitted = night_number


func _capture_pause(paused: bool) -> void:
	_pause_events.append(paused)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish(success_message: String) -> void:
	if _failures.is_empty():
		print(success_message)
		get_tree().quit(0)
	else:
		print("PHASE_2_VALIDATION_FAILED: %d checks failed." % _failures.size())
		get_tree().quit(1)
