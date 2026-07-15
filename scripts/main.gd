extends Node

const MENU_SCENE := preload("res://ui/main_menu.tscn")
const LOADING_SCENE := preload("res://ui/loading_screen.tscn")
const NIGHT_SELECTION_SCENE := preload("res://ui/night_selection/night_selection.tscn")
const NIGHT_COMPLETE_SCENE := preload("res://ui/night_complete.tscn")
const SCHOOL_PATH := "res://levels/test_school.tscn"

var _active_screen: Node
var _loading := false


func _ready() -> void:
	NightManager.night_completed.connect(_on_night_completed)
	_show_menu()


func _show_menu() -> void:
	_loading = false
	NightManager.stop_night()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var menu := MENU_SCENE.instantiate() as MainMenu
	_replace_screen(menu)
	menu.start_requested.connect(_start_new_game)
	menu.continue_requested.connect(_load_school)
	menu.night_selection_requested.connect(_show_night_selection)


func _start_new_game() -> void:
	_load_school(1)


func _show_night_selection() -> void:
	NightManager.stop_night()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var selection := NIGHT_SELECTION_SCENE.instantiate() as NightSelectionScreen
	_replace_screen(selection)
	selection.night_selected.connect(_load_school)
	selection.back_requested.connect(_show_menu)


func _load_school(night_number: int) -> void:
	if _loading or not SaveManager.is_night_unlocked(night_number):
		return
	var night_data := NightManager.get_night_data(night_number)
	if night_data == null or not NightManager.load_night(night_number):
		return
	SaveManager.select_night(night_number)
	_loading = true
	var loading := LOADING_SCENE.instantiate() as LoadingScreen
	_replace_screen(loading)
	loading.set_night(night_number, night_data.display_name)
	loading.set_status("Unlocking the east wing")

	var request_error := ResourceLoader.load_threaded_request(SCHOOL_PATH)
	if request_error != OK:
		loading.show_error("Could not begin loading the school.")
		_loading = false
		return

	var progress: Array = []
	while true:
		var status := ResourceLoader.load_threaded_get_status(SCHOOL_PATH, progress)
		if not progress.is_empty():
			loading.set_progress(float(progress[0]))
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			loading.show_error("The school scene could not be loaded.")
			_loading = false
			return
		await get_tree().process_frame

	var school := ResourceLoader.load_threaded_get(SCHOOL_PATH) as PackedScene
	if school == null:
		loading.show_error("The loaded school resource is invalid.")
		_loading = false
		return
	loading.set_progress(1.0)
	loading.set_status("Detention begins")
	await get_tree().create_timer(0.3).timeout
	_replace_screen(school.instantiate())
	NightManager.start_night()
	_loading = false


func _on_night_completed(night_data: NightData, completion_seconds: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var screen := NIGHT_COMPLETE_SCENE.instantiate() as NightCompleteScreen
	_replace_screen(screen)
	screen.setup(night_data, completion_seconds)
	screen.next_night_requested.connect(_load_school)
	screen.night_selection_requested.connect(_show_night_selection)
	screen.main_menu_requested.connect(_show_menu)


func _replace_screen(next_screen: Node) -> void:
	if is_instance_valid(_active_screen):
		_active_screen.queue_free()
	_active_screen = next_screen
	add_child(_active_screen)
