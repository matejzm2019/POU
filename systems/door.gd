extends Node3D

@export_range(-170.0, 170.0, 1.0) var open_angle_degrees := -100.0
@export_range(0.15, 1.5, 0.05) var animation_duration := 0.45
@export var locked_for_player := false
@export var morning_exit := false
@export var teacher_can_open := true

var _open := false
var _target_rotation := 0.0
var _closed_rotation := 0.0
var _animation: Tween

@onready var _hinge: AnimatableBody3D = $Hinge
@onready var _collision: CollisionShape3D = $Hinge/Collision


func _ready() -> void:
	add_to_group("school_doors")
	_closed_rotation = _hinge.rotation.y
	_target_rotation = _closed_rotation


func interact(actor: Node) -> void:
	if locked_for_player and actor is FirstPersonController:
		return
	if morning_exit:
		if not NightManager.is_morning or not actor is FirstPersonController:
			return
		set_open(true)
		NightManager.complete_current_night()
		return
	set_open(not _open)


func set_open(open: bool) -> void:
	if _open == open and is_equal_approx(_hinge.rotation.y, _target_rotation):
		return
	_open = open
	_target_rotation = _closed_rotation + deg_to_rad(open_angle_degrees) if _open else _closed_rotation
	if _animation != null:
		_animation.kill()
	_animation = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var target := _hinge.rotation
	target.y = _target_rotation
	_animation.tween_property(_hinge, "rotation", target, animation_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_animation.tween_callback(_finish_animation)


func _finish_animation() -> void:
	_collision.set_deferred("disabled", _open)


func is_open() -> bool:
	return _open


func is_locked_for_player() -> bool:
	return locked_for_player


func can_teacher_open() -> bool:
	return teacher_can_open


func get_interaction_prompt() -> String:
	if locked_for_player:
		return "KABINET JE ZAMKNUTÝ"
	if morning_exit:
		return "[E] Odísť zo školy" if NightManager.is_morning else "VÝCHOD SA ODOMKNE RÁNO"
	return "[E] Zavrieť dvere" if _open else "[E] Otvoriť dvere"
