class_name DeskHidingSpot
extends Area3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	add_to_group("desk_hiding_spots")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func contains_player(player: Node3D) -> bool:
	var local_position := to_local(player.global_position)
	return absf(local_position.x) <= 0.68 and absf(local_position.z) <= 0.36


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("set_desk_overlap"):
		body.call("set_desk_overlap", self, true)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("set_desk_overlap"):
		body.call("set_desk_overlap", self, false)
