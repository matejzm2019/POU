class_name AnalogSchoolClock
extends Node3D

@export var smooth_movement := true
@export var show_second_hand := true
@export var face_color := Color("ded9c8")
@export var hand_color := Color("202526")
@export var second_hand_color := Color("a83e38")

@onready var _face: MeshInstance3D = $Face
@onready var _hour_hand: Node3D = $Hands/HourHand
@onready var _minute_hand: Node3D = $Hands/MinuteHand
@onready var _second_hand: Node3D = $Hands/SecondHand


func _ready() -> void:
	NightManager.time_updated.connect(_on_time_updated)
	NightManager.night_loaded.connect(_on_night_loaded)
	NightManager.night_stopped.connect(_show_fallback)
	_apply_appearance()
	_build_marks()
	_second_hand.visible = show_second_hand
	_set_time(NightManager.current_in_game_time if NightManager.is_night_running else 36600.0)


func _on_time_updated(game_time_seconds: float, _progress: float) -> void:
	_set_time(game_time_seconds)


func _on_night_loaded(_data: NightData) -> void:
	_set_time(NightManager.current_in_game_time)


func _show_fallback() -> void:
	_set_time(36600.0)


func _set_time(total_seconds: float) -> void:
	var hour_value := fposmod(total_seconds / 3600.0, 12.0)
	var minute_value := fposmod(total_seconds / 60.0, 60.0)
	var second_value := fposmod(total_seconds, 60.0)
	if not smooth_movement:
		second_value = floorf(second_value)
		minute_value = floorf(minute_value)
		hour_value = floorf(hour_value) + minute_value / 60.0
	_hour_hand.rotation.z = -TAU * hour_value / 12.0
	_minute_hand.rotation.z = -TAU * minute_value / 60.0
	_second_hand.rotation.z = -TAU * second_value / 60.0


func _apply_appearance() -> void:
	_face.material_override = _material(face_color)
	$Hands/HourHand/Mesh.material_override = _material(hand_color)
	$Hands/MinuteHand/Mesh.material_override = _material(hand_color)
	$Hands/SecondHand/Mesh.material_override = _material(second_hand_color)


func _build_marks() -> void:
	var marks := Node3D.new()
	marks.name = "HourMarks"
	add_child(marks)
	var material := _material(hand_color)
	for index in 12:
		var pivot := Node3D.new()
		pivot.rotation.z = -TAU * float(index) / 12.0
		var mark := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.055, 0.16 if index % 3 == 0 else 0.1, 0.025)
		mesh.material = material
		mark.mesh = mesh
		mark.position = Vector3(0, 0.66, 0.075)
		pivot.add_child(mark)
		marks.add_child(pivot)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material
