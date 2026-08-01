@tool
class_name PlaceholderTeacher
extends CharacterBody3D

enum State { IDLE, PATROL, CHASE, SEARCH }

const DOOR_OPEN_DISTANCE := 2.25
const DOOR_CLOSE_DISTANCE := 3.2

@export var teacher_data: TeacherData
@export var fallback_model_scene: PackedScene
@export var fallback_model_scale := Vector3.ONE
@export var outfit_color := Color("394a52")

var teacher_name := "Učiteľ"
var subject_id := ""
var subject_name := "Kabinet"
var has_engaged := false

var _state := State.IDLE
var _observer_active := false
var _player: Node3D
var _home_position := Vector3.ZERO
var _patrol_points := PackedVector3Array()
var _patrol_index := 0
var _patrol_direction := 1
var _last_known_position := Vector3.ZERO
var _last_navigation_target := Vector3.INF
var _sighting_cooldown := 0.0
var _caught_reported := false
var _released := false
var _footstep_elapsed := 0.0
var _doors_to_close: Array[Node3D] = []
var _animation_player: AnimationPlayer
var _custom_model_bounds := AABB()

@onready var _placeholder: Node3D = $Placeholder
@onready var _model_anchor: Node3D = $ModelAnchor
@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _steps: AudioStreamPlayer3D = $Steps


func configure(data: TeacherData, home_position: Vector3, patrol_points: PackedVector3Array, color: Color) -> void:
	teacher_data = data
	_home_position = home_position
	_patrol_points = patrol_points
	outfit_color = color
	_initialize_patrol_phase()


func _ready() -> void:
	if _home_position == Vector3.ZERO:
		_home_position = global_position
	_apply_teacher_data()
	_build_visual()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	_agent.path_desired_distance = 0.5
	_agent.target_desired_distance = 0.8
	_agent.radius = 0.38
	_agent.height = 2.3
	floor_constant_speed = true
	floor_snap_length = 0.3
	_steps.stream = teacher_data.footstep_sound if teacher_data != null and teacher_data.footstep_sound != null else AudioManager.get_teacher_footstep()
	_steps.volume_db = AudioManager.get_footstep_volume_db()
	SchoolGameManager.register_teacher(self)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	_steps.stop()
	SchoolGameManager.unregister_teacher(self)


func _physics_process(delta: float) -> void:
	_sighting_cooldown = maxf(0.0, _sighting_cooldown - delta)
	if NightManager.is_night_paused:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if _state == State.PATROL or _state == State.CHASE or _state == State.SEARCH:
		_update_nearby_doors()
	match _state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase(delta)
		State.SEARCH:
			_search(delta)
		_:
			_stop_horizontal(delta)
	_update_animation()
	_update_footsteps(delta)
	_check_observer_sighting()


func set_observer_active(active: bool) -> void:
	_observer_active = active
	if _state == State.CHASE or _state == State.SEARCH:
		return
	_state = State.PATROL if (active or _released) and not _patrol_points.is_empty() else State.IDLE
	if _state == State.PATROL:
		_select_next_patrol_target(false)
	else:
		_play_animation(teacher_data.idle_animation if teacher_data != null else "Idle")


func set_player_reference(player: Node3D) -> void:
	_player = player


func start_chase(player: Node3D) -> void:
	_player = player
	_released = true
	_state = State.CHASE
	has_engaged = false
	_caught_reported = false
	_last_known_position = player.global_position
	_set_navigation_target(_last_known_position)
	_play_animation(teacher_data.run_animation if teacher_data != null else "RunFast")


func stop_chase() -> void:
	has_engaged = false
	_caught_reported = false
	_state = State.PATROL if not _patrol_points.is_empty() else State.IDLE
	if _state == State.PATROL:
		_select_next_patrol_target()


func reset_for_night() -> void:
	_released = false
	has_engaged = false
	_caught_reported = false
	_state = State.IDLE
	_initialize_patrol_phase()
	_last_navigation_target = Vector3.INF
	global_position = _home_position
	velocity = Vector3.ZERO
	_doors_to_close.clear()


func set_last_known_position(position: Vector3) -> void:
	if _state == State.CHASE or _state == State.SEARCH:
		_state = State.CHASE
		_last_known_position = position
		_set_navigation_target(position)
		_play_animation(teacher_data.run_animation if teacher_data != null else "RunFast")


func lose_player_and_search() -> void:
	if _state != State.CHASE and _state != State.SEARCH:
		return
	_state = State.SEARCH
	_set_navigation_target(_last_known_position)
	_play_animation(teacher_data.walk_animation if teacher_data != null else "Walking")


func can_see_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if _player.has_method("is_hidden") and bool(_player.call("is_hidden")):
		return false
	var eye := global_position + Vector3.UP * 1.75
	var target := _player.global_position + Vector3.UP * 1.1
	var offset := target - eye
	var vision_range := (teacher_data.vision_range if teacher_data != null else 18.0) * SchoolGameManager.get_teacher_vision_multiplier(self)
	if offset.length() > vision_range:
		return false
	var forward := global_transform.basis.z.normalized()
	var vision_angle := teacher_data.vision_angle_degrees if teacher_data != null else 80.0
	if forward.dot(offset.normalized()) < cos(deg_to_rad(vision_angle * 0.5)):
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, 3, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == _player


func is_chasing() -> bool:
	return _state == State.CHASE


func is_searching() -> bool:
	return _state == State.SEARCH


func is_patrolling() -> bool:
	return _state == State.PATROL


func has_been_released() -> bool:
	return _released


func get_patrol_destination() -> Vector3:
	return _patrol_points[_patrol_index] if not _patrol_points.is_empty() else Vector3.INF


func get_custom_model_bounds() -> AABB:
	return _custom_model_bounds


func get_jumpscare_focus_position() -> Vector3:
	for child in find_children("*", "Skeleton3D", true, false):
		var skeleton := child as Skeleton3D
		for bone_index in skeleton.get_bone_count():
			var bone_name := skeleton.get_bone_name(bone_index).to_lower()
			if bone_name.ends_with("head") and not bone_name.contains("end"):
				return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin) + Vector3.DOWN * 0.12
	if not _custom_model_bounds.size.is_zero_approx():
		var center := _custom_model_bounds.get_center()
		center.y = _custom_model_bounds.position.y + _custom_model_bounds.size.y * 0.82
		return _model_anchor.to_global(center)
	return global_position + Vector3.UP * 2.05


func prepare_jumpscare(viewer_position: Vector3) -> void:
	_state = State.IDLE
	velocity = Vector3.ZERO
	set_physics_process(false)
	var facing_target := Vector3(viewer_position.x, global_position.y, viewer_position.z)
	if global_position.distance_squared_to(facing_target) > 0.001:
		look_at(facing_target, Vector3.UP, true)
	_play_animation(teacher_data.run_animation if teacher_data != null else "RunFast")
	if _animation_player != null:
		_animation_player.advance(0.16)
		_animation_player.pause()
	$Nameplate.hide()


func is_jumpscare_locked() -> bool:
	return not is_physics_processing()


func _patrol(delta: float) -> void:
	if _patrol_points.is_empty():
		_state = State.IDLE
		return
	var target := _patrol_points[_patrol_index]
	if global_position.distance_to(target) < 1.1:
		_select_next_patrol_target()
		target = _patrol_points[_patrol_index]
	_move_toward_target(target, teacher_data.walk_speed if teacher_data != null else 2.4, delta)


func _chase(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		stop_chase()
		return
	if _player.has_method("is_hidden") and bool(_player.call("is_hidden")):
		lose_player_and_search()
		return
	if can_see_player():
		has_engaged = true
		_last_known_position = _player.global_position
		_set_navigation_target(_last_known_position)
	_move_toward_target(_last_known_position, teacher_data.chase_speed if teacher_data != null else 5.2, delta)
	if not _caught_reported and global_position.distance_to(_player.global_position) < 1.15:
		_caught_reported = true
		SchoolGameManager.teacher_caught_player(self)


func _search(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		stop_chase()
		return
	if can_see_player():
		_state = State.CHASE
		has_engaged = true
		_last_known_position = _player.global_position
		_set_navigation_target(_last_known_position)
		_play_animation(teacher_data.run_animation if teacher_data != null else "RunFast")
		return
	if global_position.distance_to(_last_known_position) < 1.1:
		_select_next_search_target()
	_move_toward_target(_last_known_position, teacher_data.walk_speed if teacher_data != null else 2.0, delta)


func _select_next_search_target() -> void:
	if _patrol_points.is_empty():
		_last_known_position = _home_position
	else:
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		_last_known_position = _patrol_points[_patrol_index]
	_set_navigation_target(_last_known_position)


func _move_toward_target(target: Vector3, speed: float, delta: float) -> void:
	speed *= SchoolGameManager.get_teacher_speed_multiplier(self)
	_set_navigation_target(target)
	var next_position := _agent.get_next_path_position()
	var direction := next_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0025:
		_stop_horizontal(delta)
		return
	direction = direction.normalized()
	var desired_velocity := direction * speed
	if is_on_floor():
		desired_velocity = desired_velocity.slide(get_floor_normal()).normalized() * speed
		velocity.y = desired_velocity.y
	else:
		velocity += get_gravity() * delta
	velocity.x = move_toward(velocity.x, desired_velocity.x, speed * 6.0 * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, speed * 6.0 * delta)
	move_and_slide()
	if not direction.is_zero_approx():
		look_at(global_position + direction, Vector3.UP, true)


func _stop_horizontal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()


func _set_navigation_target(target: Vector3) -> void:
	var navigation_map := _agent.get_navigation_map()
	if not navigation_map.is_valid() or NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
		return
	if _last_navigation_target.distance_squared_to(target) > 0.25 or _agent.is_navigation_finished():
		_last_navigation_target = target
		_agent.target_position = NavigationServer3D.map_get_closest_point(navigation_map, target)


func _update_nearby_doors() -> void:
	for door in get_tree().get_nodes_in_group("school_doors"):
		if not door is Node3D or not bool(door.call("can_teacher_open")):
			continue
		var door_3d := door as Node3D
		var distance := global_position.distance_to(door_3d.global_position)
		if distance <= DOOR_OPEN_DISTANCE and not bool(door.call("is_open")):
			door.call("set_open", true)
			if bool(door.call("is_locked_for_player")) and not _doors_to_close.has(door_3d):
				_doors_to_close.append(door_3d)
	for door in _doors_to_close.duplicate():
		if not is_instance_valid(door):
			_doors_to_close.erase(door)
		elif global_position.distance_to(door.global_position) >= DOOR_CLOSE_DISTANCE and _door_is_clear(door):
			door.call("set_open", false)
			_doors_to_close.erase(door)


func _door_is_clear(door: Node3D) -> bool:
	for teacher in get_tree().get_nodes_in_group("teacher_enemies"):
		if teacher is Node3D and (teacher as Node3D).global_position.distance_to(door.global_position) < DOOR_OPEN_DISTANCE:
			return false
	return true


func _select_next_patrol_target(advance: bool = true) -> void:
	if _patrol_points.is_empty():
		return
	var first_step := 1 if advance else 0
	for step in range(first_step, _patrol_points.size() + first_step):
		var candidate_index := posmod(_patrol_index + step * _patrol_direction, _patrol_points.size())
		var candidate := _patrol_points[candidate_index]
		var claimed := false
		for teacher in get_tree().get_nodes_in_group("teacher_enemies"):
			if teacher == self or not teacher.has_method("get_patrol_destination") or not bool(teacher.call("is_patrolling")):
				continue
			if candidate.distance_squared_to(teacher.call("get_patrol_destination") as Vector3) < 0.25:
				claimed = true
				break
		if not claimed:
			_patrol_index = candidate_index
			break
	_set_navigation_target(_patrol_points[_patrol_index])


func _initialize_patrol_phase() -> void:
	if _patrol_points.is_empty() or teacher_data == null:
		return
	var slot := 8 if teacher_data.is_headmistress else maxi(0, teacher_data.teacher_id.get_slice("_", 1).to_int() - 1)
	var floor_levels := PackedFloat32Array()
	for point in _patrol_points:
		var known_floor := false
		for floor_y in floor_levels:
			if absf(point.y - floor_y) < 1.0:
				known_floor = true
				break
		if not known_floor:
			floor_levels.append(point.y)
	floor_levels.sort()
	var desired_floor := slot % floor_levels.size()
	var floor_points := PackedInt32Array()
	for index in _patrol_points.size():
		if absf(_patrol_points[index].y - floor_levels[desired_floor]) < 1.0:
			floor_points.append(index)
	_patrol_index = floor_points[(slot / floor_levels.size()) % floor_points.size()]
	_patrol_direction = 1 if slot % 2 == 0 else -1


func _update_footsteps(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3
	if not moving:
		_footstep_elapsed = 0.0
		return
	_footstep_elapsed -= delta
	if _footstep_elapsed <= 0.0:
		_footstep_elapsed = 0.34 if _state == State.CHASE else 0.56
		if DisplayServer.get_name() != "headless":
			_steps.play()


func _check_observer_sighting() -> void:
	if not _observer_active or _state == State.CHASE or _state == State.SEARCH or _sighting_cooldown > 0.0:
		return
	if SchoolGameManager.is_chase_active() and can_see_player():
		_sighting_cooldown = 7.0
		SchoolGameManager.report_sighting(self, _player.global_position)


func _apply_teacher_data() -> void:
	if teacher_data == null:
		return
	teacher_name = teacher_data.display_name
	subject_id = teacher_data.subject_id
	var subject := load("res://data/homework/%s.tres" % subject_id) as SubjectData if Engine.is_editor_hint() else SchoolGameManager.get_subject(subject_id)
	subject_name = "Riaditeľka" if teacher_data.is_headmistress else (subject.display_name if subject != null else ("Telesná a športová výchova" if subject_id == "telocvik" else subject_id))
	$Nameplate.text = "%s\n%s" % [teacher_name, subject_name]


func _build_visual() -> void:
	var selected_model := teacher_data.model_scene if teacher_data != null and teacher_data.model_scene != null else fallback_model_scene
	if selected_model != null:
		var instance := selected_model.instantiate()
		if not instance is Node3D:
			instance.queue_free()
			push_warning("Model učiteľa musí mať koreň typu Node3D.")
			return
		var model := instance as Node3D
		_placeholder.hide()
		var fit_node := Node3D.new()
		fit_node.name = "ModelFit"
		_model_anchor.add_child(fit_node)
		fit_node.add_child(model)
		_fit_custom_model(model, fit_node)
		var players := model.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			_animation_player = players[0] as AnimationPlayer
	else:
		var material := StandardMaterial3D.new()
		material.albedo_color = outfit_color
		material.roughness = 0.86
		for mesh in [$Placeholder/Body, $Placeholder/LeftArm, $Placeholder/RightArm]:
			(mesh as MeshInstance3D).material_override = material


func _fit_custom_model(model: Node3D, fit_node: Node3D) -> void:
	var manual_scale := teacher_data.model_scale if teacher_data != null else fallback_model_scale
	model.scale = Vector3.ONE
	model.rotation_degrees = teacher_data.model_rotation_degrees if teacher_data != null else Vector3.ZERO
	var bounds := _calculate_visual_bounds(model, fit_node)
	if bounds.size.y <= 0.001:
		push_warning("Model učiteľa nemá použiteľnú 3D geometriu na automatické zarovnanie.")
		return
	var fit_scale := manual_scale
	if teacher_data == null or teacher_data.auto_fit_model:
		var target_height := teacher_data.model_height if teacher_data != null else 2.3
		fit_scale *= target_height / bounds.size.y
	fit_node.scale = fit_scale
	var center := bounds.get_center()
	var ground_offset := teacher_data.model_ground_offset if teacher_data != null else 0.0
	fit_node.position = Vector3(
		-center.x * fit_scale.x,
		-bounds.position.y * fit_scale.y + ground_offset,
		-center.z * fit_scale.z
	)
	_custom_model_bounds = _calculate_visual_bounds(fit_node, _model_anchor)


func _calculate_visual_bounds(root: Node3D, relative_to: Node3D) -> AABB:
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.push_front(root)
	var combined := AABB()
	var has_bounds := false
	var inverse := relative_to.global_transform.affine_inverse()
	for child in meshes:
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var transformed := (inverse * mesh_instance.global_transform) * mesh_instance.get_aabb()
		if transformed.size.is_zero_approx():
			continue
		combined = combined.merge(transformed) if has_bounds else transformed
		has_bounds = true
	return combined


func _update_animation() -> void:
	if _animation_player == null:
		return
	var moving := Vector2(velocity.x, velocity.z).length() > 0.1
	if not moving:
		var idle_name := teacher_data.idle_animation if teacher_data != null else "Idle"
		if not idle_name.is_empty() and _animation_player.has_animation(idle_name):
			_play_animation(idle_name)
		elif _animation_player.is_playing():
			_animation_player.pause()
		return
	var animation_name := (
		teacher_data.run_animation if teacher_data != null else "RunFast"
	) if _state == State.CHASE else (
		teacher_data.walk_animation if teacher_data != null else "Walking"
	)
	_play_animation(animation_name)


func _play_animation(animation_name: String) -> void:
	if _animation_player == null or animation_name.is_empty() or not _animation_player.has_animation(animation_name):
		return
	var animation := _animation_player.get_animation(animation_name)
	if animation != null and animation.loop_mode == Animation.LOOP_NONE:
		animation.loop_mode = Animation.LOOP_LINEAR
	if _animation_player.current_animation != animation_name or not _animation_player.is_playing():
		_animation_player.play(animation_name)
