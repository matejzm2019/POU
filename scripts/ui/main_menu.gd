class_name MainMenu
extends Control

signal start_requested
signal continue_requested(night_number: int)
signal night_selection_requested

@onready var _settings_panel: Control = %SettingsPanel
@onready var _credits_panel: Control = %CreditsPanel
@onready var _resolution_option: OptionButton = %ResolutionOption
@onready var _window_mode_option: OptionButton = %WindowModeOption


func _ready() -> void:
	_setup_display_settings()
	%StartButton.pressed.connect(func() -> void: start_requested.emit())
	%ContinueButton.pressed.connect(func() -> void: continue_requested.emit(SaveManager.get_continue_night()))
	%NightSelectButton.pressed.connect(func() -> void: night_selection_requested.emit())
	%SettingsButton.pressed.connect(_show_panel.bind(_settings_panel, %SettingsBackButton))
	%CreditsButton.pressed.connect(_show_panel.bind(_credits_panel, %CreditsBackButton))
	%SettingsBackButton.pressed.connect(_hide_panels)
	%CreditsBackButton.pressed.connect(_hide_panels)
	%QuitButton.pressed.connect(get_tree().quit)
	%ContinueButton.text = "POKRAČOVAŤ V NOCI %d" % SaveManager.get_continue_night()
	%StartButton.grab_focus()


func _setup_display_settings() -> void:
	for resolution in SaveManager.SUPPORTED_RESOLUTIONS:
		_resolution_option.add_item("%d × %d" % [resolution.x, resolution.y])
	_window_mode_option.add_item("V OKNE")
	_window_mode_option.add_item("CELÁ OBRAZOVKA")
	_resolution_option.select(SaveManager.get_resolution_index())
	_window_mode_option.select(1 if SaveManager.is_fullscreen_enabled() else 0)
	_resolution_option.item_selected.connect(_on_display_settings_changed)
	_window_mode_option.item_selected.connect(_on_display_settings_changed)


func _on_display_settings_changed(_index: int) -> void:
	SaveManager.set_display_settings(_resolution_option.selected, _window_mode_option.selected == 1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (_settings_panel.visible or _credits_panel.visible):
		_hide_panels()
		get_viewport().set_input_as_handled()


func _show_panel(panel: Control, back_button: Button) -> void:
	_settings_panel.hide()
	_credits_panel.hide()
	_set_main_controls_enabled(false)
	panel.visible = true
	back_button.grab_focus()


func _hide_panels() -> void:
	_settings_panel.hide()
	_credits_panel.hide()
	_set_main_controls_enabled(true)
	%StartButton.grab_focus()


func _set_main_controls_enabled(enabled: bool) -> void:
	for button in [%StartButton, %ContinueButton, %NightSelectButton, %SettingsButton, %CreditsButton, %QuitButton]:
		button.disabled = not enabled
