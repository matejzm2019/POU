extends Node

var _failures: Array[String] = []
var _siren_events := 0
var _caught_events := 0

const EXPECTED_TEACHER_NAMES := {
	"dejepis": "Jindra Kanyicsková",
	"matematika": "Alžbeta Kéryová",
	"slovensky_jazyk": "Miroslav Broniš",
	"elektrotechnika": "Mária Šumná",
	"ekonomika": "Marián Kováč",
	"aplikovana_informatika": "Miloš Palaj",
	"anglicky_jazyk": "Jana Palajová",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	_check(get_node_or_null("/root/SchoolGameManager") != null, "SchoolGameManager autoload is missing.")
	_validate_resources()
	SaveManager.reset_progress()
	var level := (load("res://levels/test_school.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	_check(NightManager.load_night(1), "Could not load Night 1 for gameplay validation.")
	_check(NightManager.start_night(), "Could not start Night 1 for gameplay validation.")
	await _validate_navigation(level)
	await _validate_pause_menu(level)
	await _validate_homework_and_chase(level)
	level.queue_free()
	NightManager.stop_night()
	await get_tree().process_frame

	var catch_level := (load("res://levels/test_school.tscn") as PackedScene).instantiate()
	add_child(catch_level)
	await get_tree().process_frame
	_check(NightManager.load_night(1), "Could not reload Night 1 for stationary-player validation.")
	_check(NightManager.start_night(), "Could not restart Night 1 for stationary-player validation.")
	await _validate_navigation(catch_level)
	await _validate_stationary_player_catch(catch_level)
	catch_level.queue_free()
	NightManager.stop_night()
	await get_tree().process_frame
	_cleanup_test_save()
	_finish()


func _validate_resources() -> void:
	var subjects := SchoolGameManager.get_subjects()
	_check(subjects.size() == 7, "Expected seven Slovak subject resources.")
	var subject_ids: Dictionary = {}
	var teacher_ids: Dictionary = {}
	for subject in subjects:
		_check(not subject.subject_id.is_empty() and not subject_ids.has(subject.subject_id), "Subject IDs must be non-empty and unique.")
		subject_ids[subject.subject_id] = true
		_check(subject.homework_sets.size() == 3, "%s must contain exactly three homework sets." % subject.display_name)
		for question in subject.homework_sets:
			_check(question != null and question.choices.size() == 4, "%s has an invalid homework question." % subject.display_name)
			_check(question != null and question.correct_index >= 0 and question.correct_index < question.choices.size(), "%s has an invalid correct answer index." % subject.display_name)
		var teacher := SchoolGameManager.get_teacher_data(subject.subject_id)
		_check(teacher != null, "%s has no TeacherData resource." % subject.display_name)
		if teacher != null:
			_check(not teacher_ids.has(teacher.teacher_id), "Teacher IDs must be unique.")
			teacher_ids[teacher.teacher_id] = true
			_check(teacher.subject_id == subject.subject_id, "Teacher subject mapping is incorrect for %s." % subject.display_name)
			_check(not teacher.active_nights.is_empty() and teacher.active_nights.has(8), "%s has invalid active nights." % teacher.display_name)
			_check(teacher.chase_speed >= 3.8 and teacher.chase_speed <= 4.4, "%s does not use the slower chase configuration." % teacher.display_name)
			_check(teacher.display_name == EXPECTED_TEACHER_NAMES.get(subject.subject_id, ""), "%s has the wrong teacher name." % subject.display_name)
	var headmistress := SchoolGameManager.get_headmistress_data()
	_check(headmistress != null and headmistress.display_name == "Zuzana Čižmáriková", "Headmistress Zuzana Čižmáriková is missing.")
	if headmistress != null:
		_check(headmistress.is_headmistress and headmistress.active_nights.has(8), "Headmistress must be active only through the Night 8 configuration.")
		_check(is_equal_approx(headmistress.ally_speed_boost, 1.2) and is_equal_approx(headmistress.ally_vision_boost, 1.25), "Headmistress teacher boosts are incorrect.")
	_check(get_node_or_null("/root/AudioManager") != null and ResourceLoader.exists("res://data/audio/game_audio.tres"), "Replaceable game audio configuration is missing.")


func _validate_navigation(level: Node) -> void:
	var region := level.find_child("NavigationRegion3D", true, false) as NavigationRegion3D
	_check(region != null, "NavigationRegion3D is missing.")
	if region == null:
		return
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline and region.navigation_mesh.get_polygon_count() == 0:
		await get_tree().process_frame
	_check(region.navigation_mesh.get_polygon_count() > 0, "Runtime navigation mesh did not bake.")
	_check(not FileAccess.get_file_as_string("res://scripts/levels/test_school.gd").contains("map_force_update"), "Runtime level still force-locks NavigationServer after baking.")
	await get_tree().physics_frame
	await get_tree().physics_frame


func _validate_pause_menu(level: Node) -> void:
	var player := level.find_child("Player", true, false) as FirstPersonController
	var hud := player.find_child("HUD", false, false) as GameHUD if player != null else null
	var environment_node := level.find_child("WorldEnvironment", true, false) as WorldEnvironment
	_check(player != null and hud != null and environment_node != null, "Pause menu validation setup is incomplete.")
	if player == null or hud == null or environment_node == null:
		return
	var pause_event := InputEventAction.new()
	pause_event.action = "ui_cancel"
	pause_event.pressed = true
	var time_before := NightManager.current_in_game_time
	var position_before := player.global_position
	player._input(pause_event)
	await get_tree().process_frame
	_check(get_tree().paused and NightManager.is_night_paused, "ESC did not stop the game.")
	_check((hud.get_node("Root/PauseOverlay") as Control).visible, "ESC did not show the pause menu.")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Pause menu did not release the mouse.")
	Input.action_press("move_forward")
	await get_tree().create_timer(0.15).timeout
	Input.action_release("move_forward")
	_check(player.global_position.distance_to(position_before) < 0.001, "The player moved while the game was paused.")
	_check(is_equal_approx(time_before, NightManager.current_in_game_time), "School time advanced while paused.")
	var brightness_slider := hud.get_node("%BrightnessSlider") as HSlider
	brightness_slider.value = 1.25
	_check(is_equal_approx(environment_node.environment.adjustment_brightness, 1.25), "Brightness was not applied to the school environment.")
	await get_tree().create_timer(0.4).timeout
	_check(is_equal_approx(float(SaveManager.get_setting("brightness", 0.0)), 1.25), "Brightness was not saved.")
	(hud.get_node("%ResumeButton") as Button).pressed.emit()
	await get_tree().process_frame
	_check(not get_tree().paused and not NightManager.is_night_paused, "Continue did not resume the game.")
	_check(not (hud.get_node("Root/PauseOverlay") as Control).visible, "Pause menu stayed visible after continuing.")
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Continuing did not capture the mouse.")


func _validate_homework_and_chase(level: Node) -> void:
	var player := level.find_child("Player", true, false) as Node3D
	_check(player != null, "School player is missing.")
	_check(level.find_children("Homework_*", "", true, false).size() == 7, "Expected one homework station in each subject classroom.")
	_check(level.find_children("Teacher_*", "", true, false).size() == 7, "Expected seven subject teachers in kabinet.")
	_check(level.find_child("Headmistress_Zuzana_Cizmarikova", true, false) != null, "Expected Zuzana Čižmáriková in kabinet.")
	_check(level.find_children("DeskHiding_*", "Area3D", true, false).size() == 42, "Expected one hiding spot under every student desk.")
	if player == null:
		return
	var classroom_door := level.find_child("ClassroomDoor_07_anglicky_jazyk", true, false) as Node3D
	var exit_door := level.find_child("SchoolExitDoor", true, false) as Node3D
	_check(classroom_door != null, "English classroom door is missing.")
	_check(exit_door != null and str(exit_door.call("get_interaction_prompt")).contains("RÁNO"), "The corridor exit is not locked until morning.")
	if classroom_door != null:
		var interaction := player.get_node("Head/Camera3D/InteractionRay") as InteractionComponent
		var resolved := interaction.call("_find_interactable", classroom_door.get_node("InteractionZone")) as Node
		_check(resolved == classroom_door, "The interaction ray cannot resolve a door from its collider child.")
		var hinge := classroom_door.get_node("Hinge") as Node3D
		var mesh := classroom_door.get_node("Hinge/Mesh") as MeshInstance3D
		var root_rotation: float = classroom_door.rotation.y
		var closed_rotation: float = hinge.rotation.y
		var closed_mesh_position := mesh.global_position
		classroom_door.call("interact", player)
		await get_tree().create_timer(float(classroom_door.get("animation_duration")) + 0.1).timeout
		var door_collision := classroom_door.get_node("Hinge/Collision") as CollisionShape3D
		var open_rotation: float = hinge.rotation.y
		_check(absf(angle_difference(open_rotation, closed_rotation)) > 1.5, "Classroom door opening animation did not reach its open angle.")
		_check(mesh.global_position.distance_to(closed_mesh_position) > 1.0, "The visible door leaf did not move out of the doorway.")
		_check(is_equal_approx(classroom_door.rotation.y, root_rotation), "Opening a door changed its wall alignment.")
		_check(door_collision.disabled, "The open visual leaf still blocked the doorway.")
		_check(interaction.call("_find_interactable", classroom_door.get_node("InteractionZone")) == classroom_door, "The open door lost its separate E interaction target.")
		var passage_query := PhysicsRayQueryParameters3D.create(Vector3(-4.0, 1.0, 28.5), Vector3(-2.0, 1.0, 28.5), 1)
		_check(get_viewport().get_world_3d().direct_space_state.intersect_ray(passage_query).is_empty(), "The open doorway still contains an invisible barrier.")
		await get_tree().create_timer(0.35).timeout
		_check(absf(angle_difference(hinge.rotation.y, open_rotation)) < 0.01 and bool(classroom_door.call("is_open")), "The door closed itself after opening.")
		classroom_door.call("interact", player)
		await get_tree().create_timer(float(classroom_door.get("animation_duration")) + 0.1).timeout
		await get_tree().physics_frame
		_check(absf(angle_difference(hinge.rotation.y, closed_rotation)) < 0.01, "Classroom door closing animation did not return to its frame.")
		_check(mesh.global_position.distance_to(closed_mesh_position) < 0.02, "The visible door leaf did not return to the frame after the second E interaction.")
		_check(not door_collision.disabled, "Closed classroom door collision was not restored.")

	var movement_start := player.global_position
	Input.action_press("move_forward")
	for _frame in 20:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	_check(player.global_position.distance_to(movement_start) > 0.25, "The player stopped responding to movement input.")

	var history := SchoolGameManager.get_subject("dejepis")
	_check(SchoolGameManager.open_homework(history.subject_id, player), "Could not open Dejepis homework.")
	_check(SchoolGameManager.homework_open, "Homework input lock did not activate.")
	_check(SchoolGameManager.submit_answer(history.get_question(0).correct_index), "Correct homework answer was rejected.")
	_check(SchoolGameManager.get_completed_sets("dejepis") == 1, "Correct homework did not advance the set.")

	var math := SchoolGameManager.get_subject("matematika")
	_check(SchoolGameManager.open_homework(math.subject_id, player), "Could not open Matematika homework.")
	var math_question := math.get_question(0)
	var wrong_index := (math_question.correct_index + 1) % math_question.choices.size()
	_check(not SchoolGameManager.submit_answer(wrong_index), "Wrong homework answer was accepted.")
	await get_tree().process_frame
	_check(SchoolGameManager.get_homework_cooldown(math.subject_id) > 29.0, "Wrong answer did not start the 30-second retry cooldown.")
	_check(not SchoolGameManager.open_homework(math.subject_id, player), "Homework reopened during its retry cooldown.")
	_check(SchoolGameManager.blackout_active, "Wrong answer did not trigger the blackout.")
	_check(SchoolGameManager.is_chase_active(), "Wrong answer did not start the subject teacher chase.")
	_check(str(SchoolGameManager.get_chaser().get("subject_id")) == "matematika", "The wrong subject teacher started chasing.")
	var school_light := level.find_child("CorridorLight_00", true, false) as Light3D
	_check(school_light != null and not school_light.visible, "School lights did not turn off.")

	var chaser := SchoolGameManager.get_chaser() as Node3D
	var start_position := chaser.global_position
	var move_deadline := Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < move_deadline and chaser.global_position.distance_to(start_position) < 0.15:
		await get_tree().physics_frame
	_check(chaser.global_position.distance_to(start_position) >= 0.15, "Chasing teacher did not move toward the player.")
	var hiding_spot := level.find_child("DeskHiding_*", true, false) as Node3D
	_check(hiding_spot != null, "No desk hiding spot was available for the player.")
	if hiding_spot != null:
		_check(not hiding_spot.has_method("interact"), "A desk still uses E instead of physical crouch hiding.")
		Input.action_press("crouch")
		for _frame in 20:
			await get_tree().physics_frame
		var approach := hiding_spot.global_position + Vector3(0.0, -0.37, -1.15)
		player.global_position = approach
		player.look_at(Vector3(hiding_spot.global_position.x, approach.y, hiding_spot.global_position.z), Vector3.UP)
		Input.action_press("move_forward")
		var hiding_deadline := Time.get_ticks_msec() + 1800
		while not bool(player.call("is_hidden")) and Time.get_ticks_msec() < hiding_deadline:
			await get_tree().physics_frame
		Input.action_release("move_forward")
		_check(bool(player.call("is_hidden")) and SchoolGameManager.player_hidden, "The player did not enter the desk hiding state.")
		_check(bool(chaser.call("is_searching")), "The chaser did not start roaming after the player hid.")
		_check(not bool(chaser.call("can_see_player")), "A teacher can still see the player under a desk.")
		var hidden_position := player.global_position
		Input.action_press("move_forward")
		for _frame in 4:
			await get_tree().physics_frame
		Input.action_release("move_forward")
		_check(player.global_position.distance_to(hidden_position) > 0.03, "The player froze after crouching under a desk.")
		Input.action_release("crouch")
		for _frame in 3:
			await get_tree().physics_frame
		_check(bool(player.call("is_hidden")), "The player stood up through the desk instead of remaining crouched.")
		Input.action_press("move_backward")
		var exit_deadline := Time.get_ticks_msec() + 1800
		while bool(player.call("is_hidden")) and Time.get_ticks_msec() < exit_deadline:
			await get_tree().physics_frame
		Input.action_release("move_backward")
		_check(not bool(player.call("is_hidden")) and not SchoolGameManager.player_hidden, "Walking out from under the desk did not end hiding.")
		_check(SchoolGameManager.open_homework(history.subject_id, player), "Homework stayed blocked while the chaser was searching.")
		_check(SchoolGameManager.submit_answer(history.get_question(1).correct_index), "Homework could not be completed during the teacher search.")

	SchoolGameManager.observer_siren.connect(_capture_siren)
	var observer := level.find_child("Teacher_01_*", true, false)
	if observer == chaser:
		observer = level.find_child("Teacher_03_*", true, false)
	observer.call("play_siren")
	SchoolGameManager.report_sighting(observer, player.global_position)
	_check(_siren_events == 1, "Another subject teacher did not emit a siren alert.")
	SchoolGameManager.end_chase()
	await get_tree().process_frame
	_check(not SchoolGameManager.blackout_active and school_light.visible, "Lights did not recover after escape.")
	_check(bool(chaser.call("has_been_released")) and bool(chaser.call("is_patrolling")), "Escaped teacher returned to kabinet instead of roaming the school.")
	var patrol_points: PackedVector3Array = chaser.get("_patrol_points")
	_check(patrol_points.size() >= 9 and absf(patrol_points[1].x) > 10.0, "Teacher patrol does not enter classrooms.")
	SchoolGameManager.call("_update_homework_cooldowns", SchoolGameManager.WRONG_ANSWER_COOLDOWN)
	_check(is_zero_approx(SchoolGameManager.get_homework_cooldown(math.subject_id)), "Homework cooldown did not expire.")

	for subject in SchoolGameManager.get_subjects():
		var completed_before := SchoolGameManager.get_completed_sets(subject.subject_id)
		for _set_index in range(completed_before, SchoolGameManager.SETS_PER_SUBJECT):
			var current_index := SchoolGameManager.get_completed_sets(subject.subject_id)
			var question := subject.get_question(current_index)
			_check(SchoolGameManager.open_homework(subject.subject_id, player), "Could not open %s set %d." % [subject.display_name, current_index + 1])
			_check(SchoolGameManager.submit_answer(question.correct_index), "Correct %s answer was rejected." % subject.display_name)
	_check(NightManager.is_night_running, "Completing all 21 sets ended the night before morning.")
	_check(SaveManager.get_highest_unlocked_night() == 1, "Homework completion unlocked Night 2 before the school exit.")
	NightManager.call("_reach_morning")
	await get_tree().process_frame
	_check(NightManager.is_night_running and NightManager.is_morning, "The end-of-timer morning state is not playable.")
	_check(exit_door != null and str(exit_door.call("get_interaction_prompt")).contains("Odísť"), "The exit did not unlock in the morning.")
	if exit_door != null:
		exit_door.call("interact", player)
	await get_tree().process_frame
	_check(not NightManager.is_night_running, "Using the morning exit did not complete the level.")
	_check(SaveManager.get_highest_unlocked_night() == 2, "The morning exit did not unlock Night 2.")


func _validate_stationary_player_catch(level: Node) -> void:
	var player := level.find_child("Player", true, false) as Node3D
	var classroom_door := level.find_child("ClassroomDoor_07_anglicky_jazyk", true, false) as Node3D
	var kabinet_door := level.find_child("ClassroomDoor_08_Kabinet", true, false) as Node3D
	_check(player != null and classroom_door != null, "Stationary-player chase setup is incomplete.")
	if player == null or classroom_door == null:
		return
	_caught_events = 0
	if not SchoolGameManager.player_caught.is_connected(_capture_caught):
		SchoolGameManager.player_caught.connect(_capture_caught)
	var math := SchoolGameManager.get_subject("matematika")
	var question := math.get_question(0)
	_check(SchoolGameManager.open_homework(math.subject_id, player), "Could not open chase test homework.")
	_check(not SchoolGameManager.submit_answer((question.correct_index + 1) % question.choices.size()), "Chase test answer was not rejected.")
	var deadline := Time.get_ticks_msec() + 18000
	while _caught_events == 0 and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	_check(bool(classroom_door.call("is_open")), "The teacher did not open the classroom door.")
	_check(kabinet_door != null and not bool(kabinet_door.call("is_open")), "The teacher did not close the kabinet door after leaving.")
	await get_tree().physics_frame
	_check((classroom_door.get_node("Hinge/Collision") as CollisionShape3D).disabled, "The teacher-opened door retained an invisible barrier.")
	_check(_caught_events == 1, "A teacher could not reach and catch a stationary player inside the classroom.")
	var jumpscare := player.find_child("JumpscareOverlay", true, false)
	var jumpscare_root := jumpscare.get_node("Root") as Control if jumpscare != null else null
	_check(jumpscare_root != null and jumpscare_root.visible, "Catching the player did not show the jumpscare.")
	if jumpscare != null:
		_check((jumpscare.find_child("TeacherName", true, false) as Label).text == "ALŽBETA KÉRYOVÁ", "Jumpscare did not show the catching teacher's name.")
	_check(not NightManager.is_night_running and SchoolGameManager.get_total_completed_sets() == 0, "Failure did not reset the current night progress.")
	if _caught_events == 1:
		_check(NightManager.load_night(1) and NightManager.start_night(), "The failed night could not restart from the beginning.")
		_check(SchoolGameManager.get_total_completed_sets() == 0, "Restarted night retained homework progress.")


func _capture_siren(_teacher_name: String) -> void:
	_siren_events += 1


func _capture_caught(_teacher_name: String, _jumpscare_image: Texture2D, _jumpscare_sound: AudioStream) -> void:
	_caught_events += 1


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _cleanup_test_save() -> void:
	SaveManager.reset_progress()
	for suffix in ["", SaveManager.TEMP_SUFFIX, SaveManager.BACKUP_SUFFIX]:
		var path: String = SaveManager.save_path + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish() -> void:
	if _failures.is_empty():
		print("PHASE_3_HOMEWORK_CHASE_OK")
		get_tree().quit(0)
	else:
		print("PHASE_3_HOMEWORK_CHASE_FAILED: %d checks failed." % _failures.size())
		get_tree().quit(1)
