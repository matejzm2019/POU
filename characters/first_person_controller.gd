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
@export var crouching_height := 1.15
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


func _ready() -> void:
	_stamina = max_stamina
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_interaction.prompt_changed.connect(_hud.set_interaction_prompt)
	_hud.set_stamina(_stamina, max_stamina)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var paused := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
		NightManager.set_paused(paused)
		_hud.set_paused(paused)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		NightManager.set_paused(false)
		_hud.set_paused(false)
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(deg_to_rad(-motion.relative.x * mouse_sensitivity))
		_pitch = clampf(_pitch - deg_to_rad(motion.relative.y * mouse_sensitivity), deg_to_rad(-85.0), deg_to_rad(85.0))
		_head.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	if NightManager.is_night_paused:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta

	var wants_to_crouch := Input.is_action_pressed("crouch")
	_crouching = wants_to_crouch or (_crouching and not _can_stand())
	_update_height(delta)
	var controls_active := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward") if controls_active else Vector2.ZERO
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var sprinting := controls_active and not _crouching and Input.is_action_pressed("sprint") and not direction.is_zero_approx() and _stamina > 0.0
	var speed := crouch_speed if _crouching else (sprint_speed if sprinting else walk_speed)

	if sprinting:
		_stamina = maxf(0.0, _stamina - stamina_drain_rate * delta)
	else:
		_stamina = minf(max_stamina, _stamina + stamina_recovery_rate * delta)
	_hud.set_stamina(_stamina, max_stamina)

	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	if controls_active and Input.is_action_just_pressed("jump") and is_on_floor() and not _crouching:
		velocity.y = jump_velocity
	move_and_slide()


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
