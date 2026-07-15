class_name HomeworkScreen
extends CanvasLayer

@onready var _root: Control = $Root
@onready var _answers: Array[Button] = [%AnswerA, %AnswerB, %AnswerC, %AnswerD]


func _ready() -> void:
	for index in _answers.size():
		_answers[index].pressed.connect(func() -> void: SchoolGameManager.submit_answer(index))
	%CancelButton.pressed.connect(SchoolGameManager.cancel_homework)
	SchoolGameManager.homework_opened.connect(_on_homework_opened)
	SchoolGameManager.homework_closed.connect(func() -> void: _root.hide())
	_root.hide()


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and event.is_action_pressed("ui_cancel"):
		SchoolGameManager.cancel_homework()
		get_viewport().set_input_as_handled()


func _on_homework_opened(subject: SubjectData, set_index: int, question: HomeworkQuestion) -> void:
	%Subject.text = "%s  /  %s" % [subject.room_code, subject.display_name.to_upper()]
	%SetNumber.text = "SADA %d Z %d" % [set_index + 1, SchoolGameManager.SETS_PER_SUBJECT]
	%Question.text = question.prompt
	for index in _answers.size():
		var button := _answers[index]
		button.visible = index < question.choices.size()
		button.text = "%s)  %s" % [String.chr(65 + index), question.choices[index]] if button.visible else ""
	_root.show()
	_answers[0].grab_focus()
