class_name SubjectData
extends Resource

@export var subject_id := ""
@export var display_name := ""
@export var room_code := ""
@export var teacher_id := ""
@export var accent_color := Color("4f5d63")
@export var homework_sets: Array[HomeworkQuestion] = []


func get_question(set_index: int) -> HomeworkQuestion:
	return homework_sets[set_index] if set_index >= 0 and set_index < homework_sets.size() else null
