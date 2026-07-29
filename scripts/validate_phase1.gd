extends Node

const SCENES := [
	"res://main.tscn",
	"res://ui/main_menu.tscn",
	"res://ui/loading_screen.tscn",
	"res://ui/hud.tscn",
	"res://ui/homework/homework_screen.tscn",
	"res://ui/jumpscare/jumpscare_overlay.tscn",
	"res://characters/player.tscn",
	"res://characters/teachers/placeholder_teacher.tscn",
	"res://levels/props/classroom_door.tscn",
	"res://levels/props/homework_station.tscn",
	"res://levels/test_school.tscn",
]

var _failures: Array[String] = []


func _ready() -> void:
	_validate.call_deferred()


func _validate() -> void:
	for path in SCENES:
		var resource := load(path) as PackedScene
		if resource == null:
			_check(false, "Could not load %s" % path)
			continue
		var instance := resource.instantiate()
		get_tree().root.add_child(instance)
		await get_tree().process_frame
		_check(instance.get_script() != null, "Root script did not attach for %s" % path)
		if path == "res://characters/player.tscn":
			_validate_player_rotation(instance as FirstPersonController)
		elif path == "res://levels/props/classroom_door.tscn":
			_validate_door(instance)
		elif path == "res://levels/test_school.tscn":
			_validate_school(instance)
		instance.queue_free()
		await get_tree().process_frame
	if _failures.is_empty():
		print("PHASE_1_SCENE_REGRESSION_OK: %d scenes loaded and instantiated." % SCENES.size())
	if "--phase2-test" in OS.get_cmdline_user_args():
		for suffix in ["", SaveManager.TEMP_SUFFIX, SaveManager.BACKUP_SUFFIX]:
			var path: String = SaveManager.save_path + str(suffix)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _validate_player_rotation(player: FirstPersonController) -> void:
	var head := player.get_node("Head") as Node3D
	var yaw_before: float = player.rotation.y
	var pitch_before: float = head.rotation.x
	player._apply_look(Vector2(90.0, -45.0))
	_check(not is_equal_approx(player.rotation.y, yaw_before), "Horizontal mouse look did not rotate the player.")
	_check(not is_equal_approx(head.rotation.x, pitch_before), "Vertical mouse look did not rotate the camera head.")


func _validate_school(level: Node) -> void:
	var player := level.find_child("Player", true, false) as FirstPersonController
	_check(level.find_children("Classroom_*", "", true, false).size() == 7, "School should contain seven subject classrooms.")
	_check(get_tree().get_nodes_in_group("teacher_enemies").size() == 8, "School should contain seven subject teachers and one headmistress.")
	_check(level.find_children("ClassroomDoor_*", "", true, false).size() == 8, "School should contain eight fitted classroom doors.")
	_check(level.find_children("DeskHiding_*", "Area3D", true, false).size() == 42, "Every student desk should have a hiding spot.")
	_check(level.find_children("*ChairBack_*", "StaticBody3D", true, false).size() == 42, "Desk furniture should block teachers physically.")
	var flashlight := player.find_child("Flashlight", true, false) as SpotLight3D
	var flashlight_fill := player.find_child("FlashlightFill", true, false) as SpotLight3D
	_check(flashlight != null and flashlight.spot_range >= 30.0 and flashlight.shadow_enabled and flashlight.shadow_blur > 1.0, "Player flashlight range or shadow smoothing is incorrect.")
	_check(flashlight_fill != null and flashlight_fill.spot_range > flashlight.spot_range and not flashlight_fill.shadow_enabled, "Soft flashlight distance fill is missing.")
	_check(int(ProjectSettings.get_setting("rendering/lights_and_shadows/positional_shadow/atlas_size", 0)) >= 4096 and not bool(ProjectSettings.get_setting("rendering/lights_and_shadows/positional_shadow/atlas_16_bits", true)), "Positional shadow atlas precision is too low.")
	var classroom_lights := level.find_children("ClassroomLight_*", "OmniLight3D", true, false)
	_check(classroom_lights.size() == 32, "Every classroom and kabinet should contain four ceiling lights.")
	for light in classroom_lights:
		_check((light as OmniLight3D).light_energy >= 1.35 and (light as OmniLight3D).omni_range >= 8.8, "A classroom light is too dim or too short-ranged.")
	_check(level.find_children("DoorNavigationLink_*", "NavigationLink3D", true, false).size() == 8, "Every classroom door should have a bidirectional teacher navigation link.")
	_check(level.find_children("Homework_*", "", true, false).size() == 7, "School should contain seven homework stations.")
	_check(level.find_child("Kabinet", true, false) != null, "Kabinet učiteľov is missing.")
	_check(level.find_child("SchoolDirectory", true, false) != null, "Expanded school directory sign is missing.")
	_check(level.find_child("NavigationRegion3D", true, false) != null, "Teacher navigation region is missing.")
	var exit_door := level.find_child("SchoolExitDoor", true, false)
	_check(exit_door != null and not bool(exit_door.call("can_teacher_open")), "The morning-only school exit is missing or available to teachers.")
	var kabinet_door := level.find_child("ClassroomDoor_08_Kabinet", true, false)
	var barrier := level.find_child("KabinetPlayerBarrier", true, false) as StaticBody3D
	_check(kabinet_door != null and bool(kabinet_door.call("is_locked_for_player")) and not bool(kabinet_door.call("is_open")), "Kabinet door should start closed and locked for the player.")
	_check(barrier != null and barrier.collision_layer == 4, "Kabinet needs a player-only access barrier.")
	if kabinet_door != null:
		kabinet_door.call("interact", level.find_child("Player", true, false))
		_check(not bool(kabinet_door.call("is_open")), "The player opened the locked kabinet door.")


func _validate_door(door: Node) -> void:
	var mesh_node := door.get_node("Hinge/Mesh") as MeshInstance3D
	var collision_node := door.get_node("Hinge/Collision") as CollisionShape3D
	var mesh := mesh_node.mesh as BoxMesh
	var shape := collision_node.shape as BoxShape3D
	_check(mesh != null and mesh.size.is_equal_approx(Vector3(1.8, 2.9, 0.12)), "Door mesh does not fill the 1.8 x 2.9 opening.")
	_check(shape != null and shape.size.is_equal_approx(Vector3(1.8, 2.9, 0.12)), "Door collision does not match the fitted door mesh.")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
