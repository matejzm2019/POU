class_name HomeworkQuestion
extends Resource

@export_multiline var prompt := ""
@export var choices: PackedStringArray
@export_range(0, 3, 1) var correct_index := 0
