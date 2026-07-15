extends Node

signal homework_opened(subject: SubjectData, set_index: int, question: HomeworkQuestion)
signal homework_closed
signal homework_progress_changed(subject_id: String, completed_sets: int, total_completed: int, total_required: int)
signal homework_result(correct: bool, message: String)
signal homework_cooldown_changed(subject_id: String, remaining_seconds: int)
signal blackout_changed(active: bool)
signal chase_started(subject_id: String, teacher_name: String)
signal chase_ended
signal observer_siren(teacher_name: String)
signal player_caught(teacher_name: String, jumpscare_image: Texture2D, jumpscare_sound: AudioStream)
signal player_hidden_changed(hidden: bool)
signal main_menu_requested

const SUBJECT_PATHS := [
	"res://data/homework/dejepis.tres",
	"res://data/homework/matematika.tres",
	"res://data/homework/slovensky_jazyk.tres",
	"res://data/homework/elektrotechnika.tres",
	"res://data/homework/ekonomika.tres",
	"res://data/homework/aplikovana_informatika.tres",
	"res://data/homework/anglicky_jazyk.tres",
]
const TEACHER_PATHS := [
	"res://data/teachers/teacher_1.tres",
	"res://data/teachers/teacher_2.tres",
	"res://data/teachers/teacher_3.tres",
	"res://data/teachers/teacher_4.tres",
	"res://data/teachers/teacher_5.tres",
	"res://data/teachers/teacher_6.tres",
	"res://data/teachers/teacher_7.tres",
]
const HEADMISTRESS_PATH := "res://data/teachers/headmistress.tres"
const SETS_PER_SUBJECT := 3
const WRONG_ANSWER_COOLDOWN := 30.0
const ESCAPE_DISTANCE := 13.0
const ESCAPE_TIME := 5.0
const UNSEEN_CHASE_GRACE_TIME := 12.0

var homework_open := false
var blackout_active := false
var chase_subject_id := ""
var player_hidden := false

var _subjects: Array[SubjectData] = []
var _subjects_by_id: Dictionary = {}
var _teacher_data_by_subject: Dictionary = {}
var _headmistress_data: TeacherData
var _progress: Dictionary = {}
var _homework_cooldowns: Dictionary = {}
var _cooldown_display: Dictionary = {}
var _teachers: Array[Node] = []
var _headmistress: Node
var _player: Node3D
var _current_subject: SubjectData
var _current_set := 0
var _chaser: Node
var _escape_elapsed := 0.0
var _chase_elapsed := 0.0


func _ready() -> void:
	_load_resources()
	NightManager.night_started.connect(_on_night_started)
	NightManager.night_restarted.connect(func(_data: NightData) -> void: reset_night())
	NightManager.night_stopped.connect(reset_night)
	NightManager.morning_reached.connect(_on_morning_reached)
	set_process(true)


func _process(delta: float) -> void:
	_update_homework_cooldowns(delta)
	if not is_chase_active() or _player == null:
		return
	if player_hidden or bool(_chaser.call("is_searching")):
		return
	_chase_elapsed += delta
	if not bool(_chaser.get("has_engaged")) and _chase_elapsed < UNSEEN_CHASE_GRACE_TIME:
		return
	var chaser_3d := _chaser as Node3D
	var can_see := bool(_chaser.call("can_see_player"))
	var far_enough := chaser_3d.global_position.distance_to(_player.global_position) >= ESCAPE_DISTANCE
	_escape_elapsed = _escape_elapsed + delta if far_enough and not can_see else 0.0
	if _escape_elapsed >= ESCAPE_TIME:
		end_chase()


func get_subjects() -> Array[SubjectData]:
	return _subjects.duplicate()


func get_subject(subject_id: String) -> SubjectData:
	return _subjects_by_id.get(subject_id) as SubjectData


func get_teacher_data(subject_id: String) -> TeacherData:
	return _teacher_data_by_subject.get(subject_id) as TeacherData


func get_headmistress_data() -> TeacherData:
	return _headmistress_data


func get_homework_cooldown(subject_id: String) -> float:
	return maxf(0.0, float(_homework_cooldowns.get(subject_id, 0.0)))


func get_teacher_speed_multiplier(teacher: Node) -> float:
	if not _headmistress_boosts(teacher):
		return 1.0
	return _headmistress_data.ally_speed_boost


func get_teacher_vision_multiplier(teacher: Node) -> float:
	if not _headmistress_boosts(teacher):
		return 1.0
	return _headmistress_data.ally_vision_boost


func register_player(player: Node3D) -> void:
	_player = player
	for teacher in _teachers:
		if is_instance_valid(teacher):
			teacher.call("set_player_reference", player)


func unregister_player(player: Node3D) -> void:
	if _player == player:
		_player = null


func register_teacher(teacher: Node) -> void:
	if not _teachers.has(teacher):
		_teachers.append(teacher)
	if _player != null:
		teacher.call("set_player_reference", _player)
	var data := teacher.get("teacher_data") as TeacherData
	if data != null and data.is_headmistress:
		_headmistress = teacher
	_sync_teacher_activity(teacher)


func unregister_teacher(teacher: Node) -> void:
	_teachers.erase(teacher)
	if _headmistress == teacher:
		_headmistress = null
	if _chaser == teacher:
		_chaser = null


func open_homework(subject_id: String, actor: Node3D = null) -> bool:
	if homework_open or NightManager.is_morning:
		return false
	if get_homework_cooldown(subject_id) > 0.0:
		return false
	if is_chase_active() and not bool(_chaser.call("is_searching")):
		return false
	var subject := get_subject(subject_id)
	if subject == null or get_completed_sets(subject_id) >= SETS_PER_SUBJECT:
		return false
	if actor != null:
		register_player(actor)
	_current_subject = subject
	_current_set = get_completed_sets(subject_id)
	var question := subject.get_question(_current_set)
	if question == null or question.choices.size() < 2:
		push_error("Predmet %s nemá platnú sadu úloh %d." % [subject_id, _current_set + 1])
		return false
	homework_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	homework_opened.emit(subject, _current_set, question)
	return true


func submit_answer(choice_index: int) -> bool:
	if not homework_open or _current_subject == null:
		return false
	var question := _current_subject.get_question(_current_set)
	if question == null or choice_index < 0 or choice_index >= question.choices.size():
		return false
	var subject_id := _current_subject.subject_id
	var correct := choice_index == question.correct_index
	_close_homework()
	if correct:
		_progress[subject_id] = mini(SETS_PER_SUBJECT, get_completed_sets(subject_id) + 1)
		var completed := get_completed_sets(subject_id)
		homework_result.emit(true, "Správne. Sada %d z %d je hotová." % [completed, SETS_PER_SUBJECT])
		homework_progress_changed.emit(subject_id, completed, get_total_completed_sets(), get_total_required_sets())
	else:
		_set_homework_cooldown(subject_id, WRONG_ANSWER_COOLDOWN)
		homework_result.emit(false, "Nesprávna odpoveď. Ďalší pokus o 30 sekúnd.")
		start_chase(subject_id)
	return correct


func cancel_homework() -> void:
	if homework_open:
		_close_homework()


func get_completed_sets(subject_id: String) -> int:
	return clampi(int(_progress.get(subject_id, 0)), 0, SETS_PER_SUBJECT)


func get_total_completed_sets() -> int:
	var total := 0
	for value in _progress.values():
		total += int(value)
	return total


func get_total_required_sets() -> int:
	return _subjects.size() * SETS_PER_SUBJECT


func is_chase_active() -> bool:
	return is_instance_valid(_chaser) and not chase_subject_id.is_empty()


func get_chaser() -> Node:
	return _chaser


func set_player_hidden(hidden: bool) -> void:
	if player_hidden == hidden:
		return
	player_hidden = hidden
	if hidden and is_chase_active():
		_chaser.call("lose_player_and_search")
	player_hidden_changed.emit(hidden)


func request_main_menu() -> void:
	if homework_open:
		_close_homework()
	NightManager.stop_night()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main_menu_requested.emit()


func start_chase(subject_id: String) -> bool:
	if is_chase_active() or _player == null:
		return false
	for teacher in _teachers:
		if is_instance_valid(teacher) and str(teacher.get("subject_id")) == subject_id:
			_chaser = teacher
			break
	if not is_instance_valid(_chaser):
		push_error("Pre predmet %s nie je zaregistrovaný učiteľ." % subject_id)
		return false
	chase_subject_id = subject_id
	_escape_elapsed = 0.0
	_chase_elapsed = 0.0
	_set_blackout(true)
	_chaser.call("start_chase", _player)
	chase_started.emit(subject_id, str(_chaser.get("teacher_name")))
	return true


func end_chase(notify := true) -> void:
	if is_instance_valid(_chaser):
		_chaser.call("stop_chase")
	_chaser = null
	chase_subject_id = ""
	_escape_elapsed = 0.0
	_chase_elapsed = 0.0
	_set_blackout(false)
	_sync_all_teachers()
	if notify:
		chase_ended.emit()


func report_sighting(observer: Node, player_position: Vector3) -> void:
	if not is_chase_active() or observer == _chaser:
		return
	_chaser.call("set_last_known_position", player_position)
	observer_siren.emit(str(observer.get("teacher_name")))


func teacher_caught_player(teacher: Node) -> void:
	if teacher != _chaser or player_hidden:
		return
	var name := str(teacher.get("teacher_name"))
	var data := teacher.get("teacher_data") as TeacherData
	player_caught.emit(name, data.jumpscare_image if data != null else null, data.jumpscare_sound if data != null else null)
	end_chase(false)
	NightManager.fail_current_night("Učiteľ ťa chytil.")


func reset_night() -> void:
	if homework_open:
		_close_homework()
	if is_chase_active() or blackout_active:
		end_chase()
	_progress.clear()
	_homework_cooldowns.clear()
	_cooldown_display.clear()
	set_player_hidden(false)
	for subject in _subjects:
		_progress[subject.subject_id] = 0
	homework_progress_changed.emit("", 0, 0, get_total_required_sets())
	for teacher in _teachers:
		if is_instance_valid(teacher):
			teacher.call("reset_for_night")
	_sync_all_teachers()


func _load_resources() -> void:
	for path in SUBJECT_PATHS:
		var subject := load(path) as SubjectData
		if subject != null and subject.homework_sets.size() == SETS_PER_SUBJECT:
			_subjects.append(subject)
			_subjects_by_id[subject.subject_id] = subject
			_progress[subject.subject_id] = 0
		else:
			push_error("Neplatný predmet alebo počet sád: %s" % path)
	for path in TEACHER_PATHS:
		var data := load(path) as TeacherData
		if data != null:
			_teacher_data_by_subject[data.subject_id] = data
		else:
			push_error("Neplatné údaje učiteľa: %s" % path)
	_headmistress_data = load(HEADMISTRESS_PATH) as TeacherData
	if _headmistress_data == null or not _headmistress_data.is_headmistress:
		push_error("Neplatné údaje riaditeľky: %s" % HEADMISTRESS_PATH)


func _close_homework() -> void:
	homework_open = false
	_current_subject = null
	_current_set = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	homework_closed.emit()


func _set_blackout(active: bool) -> void:
	if blackout_active == active:
		return
	blackout_active = active
	blackout_changed.emit(active)


func _on_night_started(_data: NightData) -> void:
	reset_night()


func _on_morning_reached(_data: NightData) -> void:
	if homework_open:
		_close_homework()
	if is_chase_active() or blackout_active:
		end_chase(false)


func _sync_all_teachers() -> void:
	for teacher in _teachers:
		if is_instance_valid(teacher):
			_sync_teacher_activity(teacher)


func _sync_teacher_activity(teacher: Node) -> void:
	var data := teacher.get("teacher_data") as TeacherData
	var active := data != null and data.active_nights.has(NightManager.current_night_number)
	if data != null and data.is_headmistress:
		active = active and NightManager.current_night_data != null and NightManager.current_night_data.headmistress_active
	teacher.call("set_observer_active", active)


func _headmistress_boosts(teacher: Node) -> bool:
	return is_instance_valid(_headmistress) and teacher != _headmistress and _headmistress_data != null and NightManager.current_night_data != null and NightManager.current_night_data.headmistress_active


func _set_homework_cooldown(subject_id: String, seconds: float) -> void:
	_homework_cooldowns[subject_id] = seconds
	_cooldown_display[subject_id] = ceili(seconds)
	homework_cooldown_changed.emit(subject_id, ceili(seconds))


func _update_homework_cooldowns(delta: float) -> void:
	for subject_id in _homework_cooldowns.keys():
		var remaining := maxf(0.0, float(_homework_cooldowns[subject_id]) - delta)
		_homework_cooldowns[subject_id] = remaining
		var display := ceili(remaining)
		if display != int(_cooldown_display.get(subject_id, -1)):
			_cooldown_display[subject_id] = display
			homework_cooldown_changed.emit(str(subject_id), display)
		if remaining <= 0.0:
			_homework_cooldowns.erase(subject_id)
			_cooldown_display.erase(subject_id)
