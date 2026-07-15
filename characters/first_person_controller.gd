class_name FirstPersonController
extends CharacterBody3D

@export_group("Movement")
@export var walk_speed := 4.0
@export var sprint_speed := 7.0
@export var crouch_speed := 2.2
@export var acceleration := 18.0
@export var jump_velocity := 4.2
@export_group("View")
@export_range(0.01, 0.5, 0.01) var mouse_sensitivity := 0.08
@export var standing_height := 1.8
@export var crouching_height := 0.72
@export var crouch_transition_speed := 4.5
@export_group("Stamina")
@export var max_stamina := 100.0
@export var stamina_drain_rate := 24.0
@export var stamina_recovery_rate := 17.0

@onready var _head: Node3D = $Head
@onready var _collider: CollisionShape3D = $CollisionShape3D
@onready var _clearance: ShapeCast3D = $StandingClearance
@onready var _interaction: InteractionComponent = $Head/Camera3D/InteractionRay
@onready var _hud: GameHUD = $HUD

var _pitch := 0.0
var _stamina := 100.0
var _crouching := false
var _desk_hiding_spots: Array[Node3D] = []
var _hidden := false


func _ready() -> void:
	_stamina = max_stamina
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	SchoolGameManager.register_player(self)
	_interaction.prompt_changed.connect(_hud.set_interaction_prompt)
	_hud.resume_requested.connect(func() -> void: _set_paused(false))
	_hud.main_menu_requested.connect(_return_to_main_menu)
	_hud.set_stamina(_stamina, max_stamina)


func _exit_tree() -> void:
	if get_tree().paused:
		get_tree().paused = false
	SchoolGameManager.set_player_hidden(false)
	SchoolGameManager.unregister_player(self)


func _input(event: InputEvent) -> void:
	if not NightManager.is_night_running:
		return
	if event.is_action_pressed("ui_cancel"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused or SchoolGameManager.homework_open:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_apply_look(motion.relative)
		get_viewport().set_input_as_handled()


func _apply_look(relative_motion: Vector2) -> void:
	rotate_y(deg_to_rad(-relative_motion.x * mouse_sensitivity))
	_pitch = clampf(_pitch - deg_to_rad(relative_motion.y * mouse_sensitivity), deg_to_rad(-85.0), deg_to_rad(85.0))
	_head.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	if not NightManager.is_night_running or NightManager.is_night_paused or SchoolGameManager.homework_open:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if not is_on_floor():
		velocity += get_gravity() * delta

	var wants_to_crouch := Input.is_action_pressed("crouch")
	_crouching = wants_to_crouch or (_crouching and not _can_stand())
	_update_height(delta)
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var sprinting := not _crouching and Input.is_action_pressed("sprint") and not direction.is_zero_approx() and _stamina > 0.0
	var speed := crouch_speed if _crouching else (sprint_speed if sprinting else walk_speed)

	if sprinting:
		_stamina = maxf(0.0, _stamina - stamina_drain_rate * delta)
	else:
		_stamina = minf(max_stamina, _stamina + stamina_recovery_rate * delta)
	_hud.set_stamina(_stamina, max_stamina)

	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	if Input.is_action_just_pressed("jump") and is_on_floor() and not _crouching:
		velocity.y = jump_velocity
	move_and_slide()
	_sync_hidden_state()


func _can_stand() -> bool:
	_clearance.force_shapecast_update()
	return not _clearance.is_colliding()


func _update_height(delta: float) -> void:
	var capsule := _collider.shape as CapsuleShape3D
	var target_height := crouching_height if _crouching else standing_height
	var height := move_toward(capsule.height, target_height, crouch_transition_speed * delta)
	capsule.height = height
	_collider.position.y = height * 0.5
	_head.position.y = move_toward(_head.position.y, height - 0.12, crouch_transition_speed * delta)


func set_desk_overlap(spot: Node3D, inside: bool) -> void:
	if inside:
		if not _desk_hiding_spots.has(spot):
			_desk_hiding_spots.append(spot)
	else:
		_desk_hiding_spots.erase(spot)
	_sync_hidden_state()


func is_hidden() -> bool:
	return _hidden


func _sync_hidden_state() -> void:
	var inside_desk := false
	for index in range(_desk_hiding_spots.size() - 1, -1, -1):
		var spot := _desk_hiding_spots[index]
		if not is_instance_valid(spot):
			_desk_hiding_spots.remove_at(index)
		elif spot.has_method("contains_player") and bool(spot.call("contains_player", self)):
			inside_desk = true
	var next_hidden := _crouching and inside_desk
	if next_hidden == _hidden:
		return
	_hidden = next_hidden
	SchoolGameManager.set_player_hidden(_hidden)


func _set_paused(paused: bool) -> void:
	if paused:
		NightManager.set_paused(true)
		_hud.set_paused(true)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
	else:
		get_tree().paused = false
		NightManager.set_paused(false)
		_hud.set_paused(false)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _return_to_main_menu() -> void:
	_set_paused(false)
	SchoolGameManager.request_main_menu()
