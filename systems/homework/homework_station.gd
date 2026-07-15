class_name HomeworkStation
extends StaticBody3D

@export var subject_id := ""

var _subject: SubjectData


func configure(subject: SubjectData) -> void:
	_subject = subject
	subject_id = subject.subject_id


func _ready() -> void:
	if _subject == null:
		_subject = SchoolGameManager.get_subject(subject_id)
	SchoolGameManager.homework_progress_changed.connect(_on_progress_changed)
	SchoolGameManager.homework_cooldown_changed.connect(_on_cooldown_changed)
	_refresh_label()


func interact(actor: Node) -> void:
	if SchoolGameManager.get_completed_sets(subject_id) < SchoolGameManager.SETS_PER_SUBJECT:
		SchoolGameManager.open_homework(subject_id, actor as Node3D)


func get_interaction_prompt() -> String:
	if _subject == null:
		return ""
	var completed := SchoolGameManager.get_completed_sets(subject_id)
	if completed >= SchoolGameManager.SETS_PER_SUBJECT:
		return "%s: všetky úlohy sú hotové" % _subject.display_name
	var cooldown := ceili(SchoolGameManager.get_homework_cooldown(subject_id))
	if cooldown > 0:
		return "%s: ďalší pokus o %d s" % [_subject.display_name, cooldown]
	return "[E] %s - sada %d z %d" % [_subject.display_name, completed + 1, SchoolGameManager.SETS_PER_SUBJECT]


func _on_progress_changed(changed_subject_id: String, _completed: int, _total: int, _required: int) -> void:
	if changed_subject_id.is_empty() or changed_subject_id == subject_id:
		_refresh_label()


func _on_cooldown_changed(changed_subject_id: String, _remaining_seconds: int) -> void:
	if changed_subject_id == subject_id:
		_refresh_label()


func _refresh_label() -> void:
	if _subject == null:
		return
	var completed := SchoolGameManager.get_completed_sets(subject_id)
	var cooldown := ceili(SchoolGameManager.get_homework_cooldown(subject_id))
	$Label.text = "%s\nPOČKAJ %d SEKÚND" % [_subject.display_name.to_upper(), cooldown] if cooldown > 0 else "%s\nDOMÁCA ÚLOHA  %d/%d" % [_subject.display_name.to_upper(), completed, SchoolGameManager.SETS_PER_SUBJECT]
	$Paper.material_override = _make_material(Color("305e4c") if completed >= SchoolGameManager.SETS_PER_SUBJECT else _subject.accent_color.lightened(0.25))


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material
