class_name LoadingScreen
extends Control

@onready var _status_label: Label = %StatusLabel
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _percent_label: Label = %PercentLabel
@onready var _night_label: Label = %NightLabel
@onready var _title_label: Label = %TitleLabel

var _status := "Preparing detention"
var _elapsed := 0.0


func _ready() -> void:
	set_progress(0.0)


func _process(delta: float) -> void:
	_elapsed += delta
	var dots := ".".repeat(int(_elapsed * 2.0) % 4)
	_status_label.text = _status + dots


func set_progress(value: float) -> void:
	var normalized := clampf(value, 0.0, 1.0)
	_progress_bar.value = normalized * 100.0
	_percent_label.text = "%d%%" % roundi(normalized * 100.0)


func set_status(text: String) -> void:
	_status = text
	_elapsed = 0.0


func set_night(night_number: int, display_name: String) -> void:
	_night_label.text = "NIGHT %d" % night_number
	_title_label.text = display_name.to_upper()


func show_error(message: String) -> void:
	_status = message
	_status_label.modulate = Color("e45b5b")
	set_process(false)
