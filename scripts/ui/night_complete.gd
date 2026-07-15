class_name NightCompleteScreen
extends Control

signal next_night_requested(night_number: int)
signal night_selection_requested
signal main_menu_requested

var _next_night := 0


func _ready() -> void:
	%NextButton.pressed.connect(_start_next)
	%NightSelectButton.pressed.connect(func() -> void: night_selection_requested.emit())
	%MainMenuButton.pressed.connect(func() -> void: main_menu_requested.emit())


func setup(data: NightData, completion_seconds: float) -> void:
	%CompletedNight.text = "NOC %d DOKONČENÁ" % data.night_number
	%NightName.text = data.display_name.to_upper()
	%CompletionTime.text = "PREŽITÝ ČAS %s" % _format_duration(completion_seconds)
	_next_night = data.night_number + 1 if data.night_number < 8 else 0
	%NextButton.visible = _next_night > 0
	if _next_night > 0:
		%NextButton.text = "POKRAČOVAŤ NA NOC %d" % _next_night
		%NextButton.grab_focus()
	else:
		%NightSelectButton.grab_focus()


func _start_next() -> void:
	if _next_night > 0 and SaveManager.is_night_unlocked(_next_night):
		next_night_requested.emit(_next_night)


func _format_duration(seconds: float) -> String:
	return "%02d:%02d" % [floori(seconds / 60.0), floori(seconds) % 60]
