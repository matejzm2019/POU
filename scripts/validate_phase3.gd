extends Node

const FLOOR_HEIGHT := 4.4

var _failures: Array[String] = []
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
	await _validate_teacher_stair_navigation(level)
	await _validate_teacher_desk_navigation(level)
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
			_check(teacher.walk_animation == "Walking" and teacher.run_animation == "RunFast", "%s does not use the shared movement animation names." % teacher.display_name)
	var headmistress := SchoolGameManager.get_headmistress_data()
	_check(headmistress != null and headmistress.display_name == "Zuzana Čižmáriková", "Headmistress Zuzana Čižmáriková is missing.")
	if headmistress != null:
		_check(headmistress.is_headmistress and headmistress.active_nights.has(8), "Headmistress must be active only through the Night 8 configuration.")
		_check(is_equal_approx(headmistress.ally_speed_boost, 1.2) and is_equal_approx(headmistress.ally_vision_boost, 1.25), "Headmistress teacher boosts are incorrect.")
	_check(get_node_or_null("/root/AudioManager") != null and ResourceLoader.exists("res://data/audio/game_audio.tres"), "Replaceable game audio configuration is missing.")


func _validate_navigation(level: Node) -> void:
	var regions := level.find_children("*", "NavigationRegion3D", true, false)
	_check(not regions.is_empty(), "NavigationRegion3D is missing.")
	if regions.is_empty():
		return
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		var all_baked := true
		for region in regions:
			if (region as NavigationRegion3D).navigation_mesh == null or (region as NavigationRegion3D).navigation_mesh.get_polygon_count() == 0:
				all_baked = false
				break
		if all_baked:
			break
		await get_tree().process_frame
	for region in regions:
		_check((region as NavigationRegion3D).navigation_mesh != null and (region as NavigationRegion3D).navigation_mesh.get_polygon_count() > 0, "%s navigation mesh did not bake." % region.name)
	_check(not FileAccess.get_file_as_string("res://scripts/levels/test_school.gd").contains("map_force_update"), "Runtime level still force-locks NavigationServer after baking.")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var access_markers := _nodes_in_level_group(level, &"school_stair_access")
	var lower_access: Node3D
	var upper_access: Node3D
	for marker in access_markers:
		if int(marker.get_meta("floor_index", -1)) == 0:
			lower_access = marker as Node3D
		elif int(marker.get_meta("floor_index", -1)) == 2:
			upper_access = marker as Node3D
	_check(lower_access != null and upper_access != null, "Three-floor navigation access markers are incomplete.")
	if lower_access != null and upper_access != null:
		var navigation_map := (level.find_child("NavigationAgent3D", true, false) as NavigationAgent3D).get_navigation_map()
		var map_deadline := Time.get_ticks_msec() + 15000
		while NavigationServer3D.map_get_iteration_id(navigation_map) == 0 and Time.get_ticks_msec() < map_deadline:
			await get_tree().physics_frame
		_check(NavigationServer3D.map_get_iteration_id(navigation_map) > 0, "Navigation map did not synchronize after baking.")
		var path := NavigationServer3D.map_get_path(navigation_map, lower_access.global_position, upper_access.global_position, true)
		while path.size() < 2 and Time.get_ticks_msec() < map_deadline:
			await get_tree().physics_frame
			path = NavigationServer3D.map_get_path(navigation_map, lower_access.global_position, upper_access.global_position, true)
		_check(path.size() > 1, "Navigation map has no path from floor 1 to floor 3.")
		if path.size() > 1:
			var minimum_y := path[0].y
			var maximum_y := path[0].y
			for point in path:
				minimum_y = minf(minimum_y, point.y)
				maximum_y = maxf(maximum_y, point.y)
			_check(maximum_y - minimum_y > FLOOR_HEIGHT * 1.5, "Navigation path does not traverse all three floors.")
	var patrol_markers := _nodes_in_level_group(level, &"teacher_patrol_marker")
	_check(patrol_markers.size() == 8, "Expected four teacher patrol markers on each upper floor.")
	var patrol_counts := {1: 0, 2: 0}
	for marker in patrol_markers:
		var floor_index := int(marker.get_meta("floor_index", -1))
		patrol_counts[floor_index] = int(patrol_counts.get(floor_index, 0)) + 1
		_check(absf((marker as Node3D).global_position.y - (floor_index * FLOOR_HEIGHT + 0.05)) < 0.3, "%s patrol marker is off its floor." % marker.name)
	_check(patrol_counts == {1: 4, 2: 4}, "Upper-floor patrol markers are not evenly distributed.")
	for teacher in _nodes_in_level_group(level, &"teacher_enemies"):
		var patrol_points: PackedVector3Array = teacher.get("_patrol_points")
		for marker in patrol_markers:
			var includes_marker := false
			for point in patrol_points:
				if point.distance_to((marker as Node3D).global_position) < 0.05:
					includes_marker = true
					break
			_check(includes_marker, "%s patrol route omits %s." % [teacher.name, marker.name])


func _validate_teacher_stair_navigation(level: Node) -> void:
	var teacher := level.find_child("Teacher_01_*", true, false) as PlaceholderTeacher
	var player := level.find_child("Player", true, false) as Node3D
	var bottom_access: Node3D
	var upper_target: Node3D
	for marker in _nodes_in_level_group(level, &"school_stair_access"):
		if int(marker.get_meta("floor_index", -1)) == 0:
			bottom_access = marker as Node3D
			break
	for marker in _nodes_in_level_group(level, &"teacher_patrol_marker"):
		if int(marker.get_meta("floor_index", -1)) == 1:
			upper_target = marker as Node3D
			break
	_check(teacher != null and bottom_access != null and upper_target != null, "Teacher stair navigation setup is incomplete.")
	if teacher == null or bottom_access == null or upper_target == null:
		return
	var target := Node3D.new()
	level.add_child(target)
	target.global_position = upper_target.global_position
	teacher.global_position = bottom_access.global_position
	teacher.velocity = Vector3.ZERO
	await get_tree().physics_frame
	teacher.start_chase(target)
	var deadline := Time.get_ticks_msec() + 14000
	while teacher.global_position.y < upper_target.global_position.y - 0.8 and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	_check(teacher.global_position.y >= upper_target.global_position.y - 0.8, "Teacher could not follow the navigation path up the stairs.")
	teacher.stop_chase()
	teacher.reset_for_night()
	teacher.set_observer_active(false)
	teacher.set_player_reference(player)
	target.queue_free()
	await get_tree().physics_frame


func _validate_teacher_desk_navigation(level: Node) -> void:
	var player := level.find_child("Player", true, false) as FirstPersonController
	var teacher := level.find_child("Teacher_01_*", true, false) as PlaceholderTeacher
	_check(player != null and teacher != null, "Teacher-desk navigation setup is incomplete.")
	if player == null or teacher == null:
		return
	var player_position := player.global_position
	var start := Vector3(-20.5, 0.05, 21.9)
	var target := Vector3(-14.5, 0.05, 21.9)
	teacher.global_position = start
	teacher.velocity = Vector3.ZERO
	player.global_position = target
	teacher.start_chase(player)
	var animation_players := teacher.find_children("*", "AnimationPlayer", true, false)
	_check(not animation_players.is_empty(), "Teacher 1 custom model has no AnimationPlayer.")
	if not animation_players.is_empty():
		var animation_player := animation_players[0] as AnimationPlayer
		_check(animation_player.has_animation("RunFast"), "Teacher 1 custom model has no RunFast animation.")
		if animation_player.has_animation("RunFast"):
			_check(animation_player.get_animation("RunFast").loop_mode == Animation.LOOP_LINEAR, "Teacher 1 RunFast animation is not looping.")
			var animation_deadline := Time.get_ticks_msec() + 1000
			while Vector2(teacher.velocity.x, teacher.velocity.z).length() <= 0.1 and Time.get_ticks_msec() < animation_deadline:
				await get_tree().physics_frame
			var moving := Vector2(teacher.velocity.x, teacher.velocity.z).length() > 0.1
			_check(moving, "Teacher 1 did not start moving for animation validation.")
			if moving:
				var animation_position := animation_player.current_animation_position
				for _frame in 4:
					await get_tree().physics_frame
				_check(animation_player.is_playing() and animation_player.current_animation == "RunFast", "Teacher 1 RunFast animation stopped during movement.")
				_check(not is_equal_approx(animation_player.current_animation_position, animation_position), "Teacher 1 RunFast animation is stuck on one frame.")
	var maximum_detour := 0.0
	var deadline := Time.get_ticks_msec() + 7000
	while teacher.global_position.distance_to(target) > 1.4 and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		maximum_detour = maxf(maximum_detour, absf(teacher.global_position.z - start.z))
	_check(teacher.global_position.distance_to(target) <= 1.4, "A teacher got stuck while navigating around a teacher desk.")
	_check(maximum_detour > 0.65, "Teacher navigation crossed the desk instead of routing around it.")
	teacher.stop_chase()
	teacher.reset_for_night()
	teacher.set_observer_active(false)
	player.global_position = player_position
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
	var player := level.find_child("Player", true, false) as FirstPersonController
	_check(player != null, "School player is missing.")
	_check(level.find_children("Homework_*", "", true, false).size() == 7, "Expected one homework station in each subject classroom.")
	_check(level.find_children("Teacher_*", "", true, false).size() == 7, "Expected seven subject teachers in kabinet.")
	_check(level.find_child("Headmistress_Zuzana_Cizmarikova", true, false) != null, "Expected Zuzana Čižmáriková in kabinet.")
	_check(level.find_children("DeskHiding_*", "Area3D", true, false).size() == 42, "Expected one hiding spot under every student desk.")
	for teacher_node in level.find_children("Teacher_*", "", true, false):
		var data := teacher_node.get("teacher_data") as TeacherData
		if data == null or data.model_scene == null:
			continue
		var bounds: AABB = teacher_node.call("get_custom_model_bounds")
		if data.auto_fit_model:
			_check(absf(bounds.size.y - data.model_height) < 0.05, "%s custom model was not normalized to character height." % data.display_name)
		_check(absf(bounds.position.y - data.model_ground_offset) < 0.03, "%s custom model is not grounded." % data.display_name)
		_check(bounds.size.x < 3.0 and bounds.size.z < 3.0, "%s custom model is large enough to span the school." % data.display_name)
	var jana_data := SchoolGameManager.get_teacher_data("anglicky_jazyk")
	if jana_data != null and jana_data.model_scene != null:
		var jana_teacher := level.find_child("Teacher_07_*", true, false) as PlaceholderTeacher
		if jana_teacher != null:
			var jana_bounds := jana_teacher.get_custom_model_bounds()
			var skeletons := jana_teacher.find_children("*", "Skeleton3D", true, false)
			var skeleton := skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
			var head_bone := skeleton.find_bone("Head") if skeleton != null else -1
			_check(head_bone >= 0, "Jana Palajová head bone could not be identified.")
			if head_bone >= 0:
				var head_position: Vector3 = jana_teacher.get_node("ModelAnchor").to_local(skeleton.to_global(skeleton.get_bone_global_pose(head_bone).origin))
				_check(head_position.y > jana_bounds.get_center().y, "Jana Palajová is upside down or looking into the floor.")
	if player == null:
		return
	var flashlight := player.get_node("Head/Camera3D/Flashlight") as SpotLight3D
	var flashlight_fill := player.get_node("Head/Camera3D/FlashlightFill") as SpotLight3D
	var flashlight_event := InputEventKey.new()
	flashlight_event.physical_keycode = KEY_F
	flashlight_event.pressed = true
	player._input(flashlight_event)
	_check(not flashlight.visible and not flashlight_fill.visible and not player.is_flashlight_enabled(), "F did not turn both flashlight layers off.")
	player._input(flashlight_event)
	_check(flashlight.visible and flashlight_fill.visible and player.is_flashlight_enabled(), "F did not turn both flashlight layers back on.")
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
	var last_seen_classroom_position := Vector3(-13.0, 0.05, 28.5)
	player.global_position = Vector3(-20.0, 0.05, 28.5)
	chaser.call("set_last_known_position", last_seen_classroom_position)
	chaser.set("has_engaged", true)
	SchoolGameManager.set("_escape_elapsed", SchoolGameManager.ESCAPE_TIME)
	SchoolGameManager.call("_process", 0.01)
	var chase_agent := chaser.get_node("NavigationAgent3D") as NavigationAgent3D
	var expected_last_seen_target := NavigationServer3D.map_get_closest_point(chase_agent.get_navigation_map(), last_seen_classroom_position)
	_check(SchoolGameManager.is_chase_active() and bool(chaser.call("is_searching")), "Losing sight of the player ended the chase instead of starting a classroom search.")
	_check(chase_agent.target_position.distance_to(expected_last_seen_target) < 0.01, "The teacher forgot the classroom where the player was last seen.")
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

	var observer := level.find_child("Teacher_01_*", true, false)
	if observer == chaser:
		observer = level.find_child("Teacher_03_*", true, false)
	_check(observer.get_node_or_null("Siren") == null, "Silent observer still contains a siren audio player.")
	var reported_position := player.global_position + Vector3(0.4, 0.0, 0.4)
	SchoolGameManager.report_sighting(observer, reported_position)
	_check((chaser.get("_last_known_position") as Vector3).is_equal_approx(reported_position), "Another subject teacher did not silently report the player position.")
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
	_check(jumpscare_root != null and jumpscare_root.visible, "Catching the player did not start the jumpscare.")
	if jumpscare != null:
		var catching_teacher := jumpscare.call("get_target_teacher") as Node3D
		_check(bool(jumpscare.call("is_3d_sequence_active")), "The 3D jumpscare camera sequence is inactive.")
		_check(catching_teacher != null and str(catching_teacher.get("subject_id")) == "matematika", "The 3D jumpscare did not target the catching teacher.")
		_check((jumpscare.call("get_camera_target_position") as Vector3) != Vector3.ZERO, "The 3D jumpscare did not calculate a close camera position.")
		_check(catching_teacher != null and bool(catching_teacher.call("is_jumpscare_locked")), "The catching teacher kept running instead of posing for the jumpscare.")
	_check(not NightManager.is_night_running and SchoolGameManager.get_total_completed_sets() == 0, "Failure did not reset the current night progress.")
	if _caught_events == 1:
		_check(NightManager.load_night(1) and NightManager.start_night(), "The failed night could not restart from the beginning.")
		_check(SchoolGameManager.get_total_completed_sets() == 0, "Restarted night retained homework progress.")


func _capture_caught(_teacher: Node3D, _teacher_name: String, _jumpscare_image: Texture2D, _jumpscare_sound: AudioStream) -> void:
	_caught_events += 1


func _nodes_in_level_group(level: Node, group_name: StringName) -> Array[Node]:
	var nodes: Array[Node] = []
	for node in get_tree().get_nodes_in_group(group_name):
		if node == level or level.is_ancestor_of(node):
			nodes.append(node)
	return nodes


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
