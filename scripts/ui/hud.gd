class_name GameHUD
extends CanvasLayer

signal resume_requested
signal main_menu_requested

@onready var _prompt: Label = %InteractionPrompt
@onready var _stamina_bar: ProgressBar = %StaminaBar
@onready var _stamina_group: Control = %StaminaGroup
@onready var _pause_overlay: Control = %PauseOverlay
@onready var _clock: Label = %Clock
@onready var _progress: ProgressBar = %NightProgress
@onready var _start_message: Label = %NightStartMessage
@onready var _alert: Label = %AlertMessage
@onready var _brightness_slider: HSlider = %BrightnessSlider
@onready var _brightness_value: Label = %BrightnessValue

var _school_environment: Environment


func _ready() -> void:
	NightManager.time_updated.connect(_on_time_updated)
	NightManager.night_started.connect(_on_night_started)
	NightManager.morning_reached.connect(_on_morning_reached)
	%StartMessageTimer.timeout.connect(func() -> void: _start_message.hide())
	%AlertTimer.timeout.connect(func() -> void: _alert.hide())
	SchoolGameManager.homework_progress_changed.connect(_on_homework_progress)
	SchoolGameManager.homework_result.connect(_on_homework_result)
	SchoolGameManager.chase_ended.connect(_on_chase_ended)
	SchoolGameManager.observer_siren.connect(_on_observer_siren)
	%ResumeButton.pressed.connect(func() -> void: resume_requested.emit())
	%MainMenuButton.pressed.connect(func() -> void: main_menu_requested.emit())
	_brightness_slider.value_changed.connect(_on_brightness_changed)
	%BrightnessSaveTimer.timeout.connect(_save_brightness)
	var environment_node := get_tree().get_first_node_in_group("school_environment") as WorldEnvironment
	if environment_node != null:
		_school_environment = environment_node.environment
	var saved_brightness := clampf(float(SaveManager.get_setting("brightness", 1.0)), 0.5, 1.5)
	_brightness_slider.set_value_no_signal(saved_brightness)
	_apply_brightness(saved_brightness)
	%DebugCompleteHint.visible = OS.is_debug_build()
	if NightManager.current_night_data != null:
		_apply_night(NightManager.current_night_data)
		_on_time_updated(NightManager.current_in_game_time, NightManager.get_night_progress())


func set_interaction_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = not text.is_empty()


func set_stamina(current: float, maximum: float) -> void:
	_stamina_bar.max_value = maximum
	_stamina_bar.value = current
	_stamina_group.visible = current < maximum - 0.1


func set_paused(paused: bool) -> void:
	_pause_overlay.visible = paused
	if paused:
		%ResumeButton.grab_focus()
	else:
		%ResumeButton.release_focus()


func get_brightness() -> float:
	return float(_brightness_slider.value)


func _on_brightness_changed(value: float) -> void:
	_apply_brightness(value)
	%BrightnessSaveTimer.start()


func _apply_brightness(value: float) -> void:
	_brightness_value.text = "%d %%" % roundi(value * 100.0)
	if _school_environment != null:
		_school_environment.adjustment_enabled = true
		_school_environment.adjustment_brightness = value


func _save_brightness() -> void:
	SaveManager.set_setting("brightness", get_brightness())


func _on_night_started(data: NightData) -> void:
	_apply_night(data)
	_start_message.text = "NOC %d\n%s" % [data.night_number, data.display_name.to_upper()]
	_start_message.show()
	%StartMessageTimer.start()


func _apply_night(data: NightData) -> void:
	%NightKicker.text = "AKTUÁLNA NOC  /  %d Z 8" % data.night_number
	_on_homework_progress("", 0, SchoolGameManager.get_total_completed_sets(), SchoolGameManager.get_total_required_sets())


func _on_time_updated(_game_time_seconds: float, progress: float) -> void:
	_clock.text = "%s  •  NOC %d" % [NightManager.get_formatted_time(true, false), NightManager.current_night_number]
	_progress.value = progress * 100.0


func _on_homework_progress(_subject_id: String, _completed: int, total: int, required: int) -> void:
	if not NightManager.is_morning:
		%Objective.text = "Domáce úlohy: %d/%d sád" % [total, required]


func _on_homework_result(correct: bool, message: String) -> void:
	if correct:
		_show_alert(message, Color("74bf91"), 2.8)


func _on_chase_ended() -> void:
	_show_alert("UŠIEL SI\nSVETLÁ SA ZAPÍNAJÚ", Color("7ec79a"), 3.0)


func _on_observer_siren(teacher_name: String) -> void:
	_show_alert("%s SPUSTIL SIRÉNOVÝ KRIK!" % teacher_name.to_upper(), Color("ef9b45"), 3.0)


func _on_morning_reached(_data: NightData) -> void:
	%Objective.text = "RÁNO: choď k východu na konci chodby"
	_show_alert("JE RÁNO\nDOSTAŇ SA K VÝCHODU", Color("8fd2aa"), 5.0)


func _show_alert(text: String, color: Color, duration: float) -> void:
	_alert.text = text
	_alert.modulate = color
	_alert.show()
	%AlertTimer.start(duration)
