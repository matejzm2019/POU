extends Node3D

@export_range(-170.0, 170.0, 1.0) var open_angle_degrees := -100.0
@export_range(1.0, 12.0, 0.5) var movement_speed := 6.0

var _open := false
var _target_rotation := 0.0
var _closed_rotation := 0.0


func _ready() -> void:
	_closed_rotation = rotation.y
	_target_rotation = _closed_rotation


func _process(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, _target_rotation, minf(movement_speed * delta, 1.0))


func interact(_actor: Node) -> void:
	_open = not _open
	_target_rotation = _closed_rotation + deg_to_rad(open_angle_degrees) if _open else _closed_rotation


func get_interaction_prompt() -> String:
	return "[E] Close classroom door" if _open else "[E] Open classroom door"
