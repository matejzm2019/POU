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
var _last_known_position := Vector3.ZERO
var _last_navigation_target := Vector3.INF
var _navigation_refresh_elapsed := 0.0
var _siren_cooldown := 0.0
var _caught_reported := false
var _released := false
var _footstep_elapsed := 0.0
var _doors_to_close: Array[Node3D] = []
var _animation_player: AnimationPlayer

@onready var _placeholder: Node3D = $Placeholder
@onready var _model_anchor: Node3D = $ModelAnchor
@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _siren: AudioStreamPlayer3D = $Siren
@onready var _steps: AudioStreamPlayer3D = $Steps


func configure(data: TeacherData, home_position: Vector3, patrol_points: PackedVector3Array, color: Color) -> void:
	teacher_data = data
	_home_position = home_position
	_patrol_points = patrol_points
	outfit_color = color


func _ready() -> void:
	if _home_position == Vector3.ZERO:
		_home_position = global_position
	_apply_teacher_data()
	_build_visual()
	_agent.path_desired_distance = 0.65
	_agent.target_desired_distance = 0.8
	_agent.radius = 0.38
	_agent.height = 2.3
	_siren.stream = _create_siren_stream()
	_steps.stream = teacher_data.footstep_sound if teacher_data != null and teacher_data.footstep_sound != null else AudioManager.get_teacher_footstep()
	_steps.volume_db = AudioManager.get_footstep_volume_db()
	SchoolGameManager.register_teacher(self)


func _exit_tree() -> void:
	_siren.stop()
	_steps.stop()
	_siren.stream = null
	SchoolGameManager.unregister_teacher(self)


func _physics_process(delta: float) -> void:
	_siren_cooldown = maxf(0.0, _siren_cooldown - delta)
	_navigation_refresh_elapsed = maxf(0.0, _navigation_refresh_elapsed - delta)
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
	_update_footsteps(delta)
	_check_siren_sighting()


func set_observer_active(active: bool) -> void:
	_observer_active = active
	if _state == State.CHASE or _state == State.SEARCH:
		return
	_state = State.PATROL if (active or _released) and not _patrol_points.is_empty() else State.IDLE
	if _state == State.PATROL:
		_set_navigation_target(_patrol_points[_patrol_index])
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
	_play_animation(teacher_data.run_animation if teacher_data != null else "Run")


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
	global_position = _home_position
	velocity = Vector3.ZERO
	_doors_to_close.clear()


func set_last_known_position(position: Vector3) -> void:
	if _state == State.CHASE or _state == State.SEARCH:
		_state = State.CHASE
		_last_known_position = position
		_set_navigation_target(position)
		_play_animation(teacher_data.run_animation if teacher_data != null else "Run")


func lose_player_and_search() -> void:
	if _state != State.CHASE and _state != State.SEARCH:
		return
	_state = State.SEARCH
	_select_next_search_target()
	_play_animation(teacher_data.run_animation if teacher_data != null else "Run")


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


func play_siren() -> void:
	if DisplayServer.get_name() != "headless" and not _siren.playing:
		_siren.play()


func is_chasing() -> bool:
	return _state == State.CHASE


func is_searching() -> bool:
	return _state == State.SEARCH


func is_patrolling() -> bool:
	return _state == State.PATROL


func has_been_released() -> bool:
	return _released


func _patrol(delta: float) -> void:
	if _patrol_points.is_empty():
		_state = State.IDLE
		return
	var target := _patrol_points[_patrol_index]
	if global_position.distance_to(target) < 1.1:
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		target = _patrol_points[_patrol_index]
		_set_navigation_target(target)
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
		_play_animation(teacher_data.run_animation if teacher_data != null else "Run")
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
		direction = target - global_position
		direction.y = 0.0
	direction = direction.normalized()
	velocity.x = move_toward(velocity.x, direction.x * speed, speed * 6.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, speed * 6.0 * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
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
	if _navigation_refresh_elapsed <= 0.0 or _last_navigation_target.distance_squared_to(target) > 0.25:
		_last_navigation_target = target
		_agent.target_position = target
		_navigation_refresh_elapsed = 0.5


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


func _select_next_patrol_target() -> void:
	if _patrol_points.is_empty():
		return
	_patrol_index = (_patrol_index + 1) % _patrol_points.size()
	_set_navigation_target(_patrol_points[_patrol_index])


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


func _check_siren_sighting() -> void:
	if not _observer_active or _state == State.CHASE or _state == State.SEARCH or _siren_cooldown > 0.0:
		return
	if SchoolGameManager.is_chase_active() and can_see_player():
		_siren_cooldown = 7.0
		play_siren()
		SchoolGameManager.report_sighting(self, _player.global_position)


func _apply_teacher_data() -> void:
	if teacher_data == null:
		return
	teacher_name = teacher_data.display_name
	subject_id = teacher_data.subject_id
	var subject := SchoolGameManager.get_subject(subject_id)
	subject_name = "Riaditeľka" if teacher_data.is_headmistress else (subject.display_name if subject != null else subject_id)
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
		model.scale = teacher_data.model_scale if teacher_data != null else fallback_model_scale
		_model_anchor.add_child(model)
		var players := model.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			_animation_player = players[0] as AnimationPlayer
	else:
		var material := StandardMaterial3D.new()
		material.albedo_color = outfit_color
		material.roughness = 0.86
		for mesh in [$Placeholder/Body, $Placeholder/LeftArm, $Placeholder/RightArm]:
			(mesh as MeshInstance3D).material_override = material


func _play_animation(animation_name: String) -> void:
	if _animation_player != null and _animation_player.has_animation(animation_name) and _animation_player.current_animation != animation_name:
		_animation_player.play(animation_name)


func _create_siren_stream() -> AudioStreamWAV:
	const MIX_RATE := 22050
	const DURATION := 0.9
	var sample_count := int(MIX_RATE * DURATION)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in sample_count:
		var time := float(index) / MIX_RATE
		var frequency := 760.0 if int(time / 0.13) % 2 == 0 else 1040.0
		var envelope := minf(1.0, time * 10.0) * minf(1.0, (DURATION - time) * 8.0)
		bytes.encode_s16(index * 2, int(sin(TAU * frequency * time) * 10500.0 * envelope))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
