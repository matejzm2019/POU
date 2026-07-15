class_name InteractionComponent
extends RayCast3D

signal prompt_changed(prompt: String)

var _target: Node
var _prompt := ""


func _physics_process(_delta: float) -> void:
	force_raycast_update()
	var next_target := _find_interactable(get_collider()) if is_colliding() else null
	var next_prompt := ""
	if is_instance_valid(next_target):
		next_prompt = str(next_target.call("get_interaction_prompt"))
	_set_target(next_target, next_prompt)


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or NightManager.is_night_paused or SchoolGameManager.homework_open:
		return
	if event.is_action_pressed("interact") and is_instance_valid(_target):
		_target.call("interact", owner)
		get_viewport().set_input_as_handled()


func _find_interactable(collider: Object) -> Node:
	var node := collider as Node
	while node != null:
		if node.has_method("interact") and node.has_method("get_interaction_prompt"):
			return node
		node = node.get_parent()
	return null


func _set_target(target: Node, prompt: String) -> void:
	if target == _target and prompt == _prompt:
		return
	_target = target
	_prompt = prompt
	prompt_changed.emit(_prompt)
