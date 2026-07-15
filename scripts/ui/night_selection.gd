class_name NightSelectionScreen
extends Control

signal night_selected(night_number: int)
signal back_requested

@onready var _grid: GridContainer = %NightGrid
@onready var _template: Button = %NightButtonTemplate
@onready var _start_button: Button = %StartNightButton

var _selected_night := 1
var _displayed_night := 1
var _buttons: Array[Button] = []
var _button_group := ButtonGroup.new()


func _ready() -> void:
	%BackButton.pressed.connect(func() -> void: back_requested.emit())
	_start_button.pressed.connect(_start_selected_night)
	_populate_nights()
	_select_night(SaveManager.get_continue_night())
	_buttons[_selected_night - 1].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()


func _populate_nights() -> void:
	for data in NightManager.get_all_nights():
		var button := _template.duplicate() as Button
		var locked := not SaveManager.is_night_unlocked(data.night_number)
		button.name = "NightButton%d" % data.night_number
		button.visible = true
		button.text = "NOC %d%s\n%s" % [data.night_number, "  •  ZAMKNUTÁ" if locked else "", data.display_name]
		button.tooltip_text = data.difficulty_description if not locked else "Zamknuté: najprv dokonči noc %d." % (data.night_number - 1)
		button.button_group = _button_group
		button.set_meta("night_number", data.night_number)
		button.set_meta("locked", locked)
		if locked:
			button.add_theme_color_override("font_color", Color("59615f"))
			button.add_theme_stylebox_override("normal", _template.get_theme_stylebox("disabled"))
		button.focus_entered.connect(_preview_night.bind(data.night_number))
		button.mouse_entered.connect(_preview_night.bind(data.night_number))
		button.pressed.connect(_select_night.bind(data.night_number))
		_grid.add_child(button)
		_buttons.append(button)
	_template.queue_free()


func _select_night(night_number: int) -> void:
	if not SaveManager.is_night_unlocked(night_number):
		for button in _buttons:
			button.button_pressed = int(button.get_meta("night_number")) == _selected_night
		return
	_selected_night = night_number
	SaveManager.select_night(night_number)
	for button in _buttons:
		button.button_pressed = int(button.get_meta("night_number")) == night_number
	_preview_night(night_number)
	_start_button.text = "ZAČAŤ NOC %d" % night_number


func _preview_night(night_number: int) -> void:
	var data := NightManager.get_night_data(night_number)
	if data == null:
		return
	_displayed_night = night_number
	%NightNumber.text = "NOC %d" % night_number
	%NightName.text = data.display_name.to_upper()
	%Difficulty.text = data.difficulty_description
	%Schedule.text = "%s  —  %s" % [SchoolTime.format_time(data.start_time_seconds(), true, false), SchoolTime.format_time(data.end_time_seconds(), true, false)]
	%Duration.text = "%d MINÚT SKUTOČNÉHO ČASU" % roundi(data.real_world_duration_seconds / 60.0)
	var teacher_count := data.active_enemy_ids.size()
	%Threats.text = "%d AKTÍVNY UČITEĽ" % teacher_count if teacher_count == 1 else ("%d AKTÍVNI UČITELIA" % teacher_count if teacher_count >= 2 and teacher_count <= 4 else "%d AKTÍVNYCH UČITEĽOV" % teacher_count)
	%Headmistress.text = "RIADITEĽKA AKTÍVNA" if data.headmistress_active else "RIADITEĽKA NEPRÍTOMNÁ"
	%LockStatus.text = "DOSTUPNÁ" if SaveManager.is_night_unlocked(night_number) else "ZAMKNUTÁ"
	_start_button.disabled = not SaveManager.is_night_unlocked(night_number)
	_start_button.text = "ZAČAŤ NOC %d" % night_number


func _start_selected_night() -> void:
	if SaveManager.select_night(_displayed_night):
		_selected_night = _displayed_night
		night_selected.emit(_displayed_night)
