class_name GameHUD
extends CanvasLayer

@onready var _prompt: Label = %InteractionPrompt
@onready var _stamina_bar: ProgressBar = %StaminaBar
@onready var _stamina_group: Control = %StaminaGroup
@onready var _pause_overlay: Control = %PauseOverlay
@onready var _clock: Label = %Clock
@onready var _progress: ProgressBar = %NightProgress
@onready var _start_message: Label = %NightStartMessage


func _ready() -> void:
	NightManager.time_updated.connect(_on_time_updated)
	NightManager.night_started.connect(_on_night_started)
	%StartMessageTimer.timeout.connect(func() -> void: _start_message.hide())
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


func _on_night_started(data: NightData) -> void:
	_apply_night(data)
	_start_message.text = "NIGHT %d\n%s" % [data.night_number, data.display_name.to_upper()]
	_start_message.show()
	%StartMessageTimer.start()


func _apply_night(data: NightData) -> void:
	%NightKicker.text = "CURRENT NIGHT  /  %d OF 8" % data.night_number
	%Objective.text = data.display_name


func _on_time_updated(_game_time_seconds: float, progress: float) -> void:
	_clock.text = "%s  •  NIGHT %d" % [NightManager.get_formatted_time(false, false), NightManager.current_night_number]
	_progress.value = progress * 100.0
