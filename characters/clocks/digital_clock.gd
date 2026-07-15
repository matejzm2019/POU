class_name DigitalSchoolClock
extends Node3D

@export var use_24_hour := false
@export var show_seconds := false
@export var fallback_text := "--:--"
@export var text_color := Color("d56358")
@export var case_color := Color("171b1c")

@onready var _display: Label3D = $Display
@onready var _case: MeshInstance3D = $Case


func _ready() -> void:
	NightManager.time_updated.connect(_on_time_updated)
	NightManager.night_loaded.connect(_on_night_loaded)
	NightManager.night_stopped.connect(_refresh)
	_apply_appearance()
	_refresh()


func _on_time_updated(_game_time_seconds: float, _progress: float) -> void:
	_refresh()


func _on_night_loaded(_data: NightData) -> void:
	_refresh()


func _refresh() -> void:
	_display.text = NightManager.get_formatted_time(use_24_hour, show_seconds) if NightManager.is_night_running else fallback_text


func _apply_appearance() -> void:
	_display.modulate = text_color
	var material := StandardMaterial3D.new()
	material.albedo_color = case_color
	material.roughness = 0.78
	_case.material_override = material
