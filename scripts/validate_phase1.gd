extends Node

const FLOOR_HEIGHT := 4.4
const STAIR_OPENING_CENTER := Vector3(6.1, 0.0, 43.3)
const STAIR_STEPS_PER_FLIGHT := 13
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
const EXPECTED_DECORATION_FEATURES := [
	"wall_trim",
	"teaching_wall",
	"student_furniture",
	"teacher_furniture",
	"storage",
	"notices",
	"utilities",
	"ceiling_fixtures",
	"floor_detail",
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
	var classrooms := level.find_children("Classroom_*", "", true, false)
	_check(classrooms.size() == 7, "School should contain seven subject classrooms.")
	for classroom in classrooms:
		var decorations := classroom.find_children("ClassroomDecoration_*", "Node3D", true, false)
		_check(decorations.size() == 1, "%s should have exactly one decoration marker." % classroom.name)
		if decorations.size() != 1:
			continue
		var decoration := decorations[0] as Node3D
		_check(decoration.is_in_group("decorated_classroom"), "%s decoration is missing its integration group." % classroom.name)
		_check(decoration.get_meta("subject_id", "") == classroom.get_meta("subject_id", ""), "%s decoration has the wrong subject marker." % classroom.name)
		_check(decoration.get_meta("decorator_version", 0) == 1, "%s decoration version marker is invalid." % classroom.name)
		_check(Array(decoration.get_meta("features", PackedStringArray())) == EXPECTED_DECORATION_FEATURES, "%s decoration feature manifest is incomplete." % classroom.name)
		for marker in [
			["WallFinish", "classroom_wall_trim"],
			["Furniture", "classroom_furniture"],
			["Storage", "classroom_storage"],
			["Displays", "classroom_notice"],
			["Ceiling", "classroom_ceiling_fixture"],
		]:
			var category := decoration.get_node_or_null(marker[0])
			_check(category != null and category.is_in_group(marker[1]), "%s decoration is missing the %s marker." % [classroom.name, marker[1]])
	var floors := _nodes_in_level_group(level, &"school_floor")
	_check(floors.size() == 3, "School should contain exactly three floor roots.")
	var floor_indices: Dictionary = {}
	for floor in floors:
		var floor_index := int(floor.get_meta("floor_index", -1))
		floor_indices[floor_index] = true
		_check(floor.name == "SchoolFloor_%d" % (floor_index + 1), "A school floor root has an invalid name or floor_index.")
		_check(absf((floor as Node3D).global_position.y - floor_index * FLOOR_HEIGHT) < 0.01, "%s is at the wrong elevation." % floor.name)
	_check(floor_indices.has(0) and floor_indices.has(1) and floor_indices.has(2), "School floor indices should cover 0 through 2.")
	var stairs := _nodes_in_level_group(level, &"school_stair")
	_check(stairs.size() == 2, "School should contain two stair connections.")
	var visual_polish := level.get_node_or_null("SchoolVisualPolish")
	_check(visual_polish is Node3D and visual_polish.is_in_group("school_visual_polish"), "School visual polish was not integrated.")
	if visual_polish != null:
		_check(visual_polish.find_children("*", "MultiMeshInstance3D", true, false).size() == 4, "School visual polish should use four batched MultiMeshes.")
		_check(visual_polish.find_children("FloorIdentity_*", "Label3D", true, false).size() == 3, "Every floor needs one readable identity sign.")
	var stair_pairs: Dictionary = {}
	for stair in stairs:
		var from_floor := int(stair.get_meta("from_floor_index", -1))
		var to_floor := int(stair.get_meta("to_floor_index", -1))
		stair_pairs["%d:%d" % [from_floor, to_floor]] = true
		_check(to_floor == from_floor + 1, "%s does not connect adjacent floors." % stair.name)
		for part in ["FlightA", "MidLanding", "FlightB"]:
			_check(stair.get_node_or_null(part) is StaticBody3D, "%s is missing collidable %s geometry." % [stair.name, part])
		for flight_name in ["FlightA", "FlightB"]:
			var ramp := stair.get_node_or_null(flight_name)
			_check(ramp != null and ramp.find_children("*", "CollisionShape3D", true, false).size() == 1, "%s needs one smooth invisible collision ramp." % flight_name)
			_check(ramp != null and ramp.find_children("*", "MeshInstance3D", true, false).is_empty(), "%s collision ramp should remain invisible behind the visible steps." % flight_name)
			for step_index in STAIR_STEPS_PER_FLIGHT:
				var step_name := "%s_Step_%02d" % [flight_name, step_index + 1]
				_check(stair.get_node_or_null(step_name) is MeshInstance3D, "%s is missing visible stair step %s." % [stair.name, step_name])
		for access_name in ["BottomAccess", "TopAccess"]:
			var access := stair.get_node_or_null(access_name)
			_check(access is Marker3D and access.is_in_group("school_stair_access"), "%s is missing its %s accessibility marker." % [stair.name, access_name])
	_check(stair_pairs.has("0:1") and stair_pairs.has("1:2"), "Stairs should connect floors 1-2 and 2-3.")
	var access_markers := _nodes_in_level_group(level, &"school_stair_access")
	_check(access_markers.size() == 4, "School stairs should expose four accessibility markers.")
	var access_counts := {0: 0, 1: 0, 2: 0}
	for marker in access_markers:
		var floor_index := int(marker.get_meta("floor_index", -1))
		access_counts[floor_index] = int(access_counts.get(floor_index, 0)) + 1
		_check(absf((marker as Node3D).global_position.y - (floor_index * FLOOR_HEIGHT + 0.05)) < 0.3, "%s accessibility marker is off its floor." % marker.name)
	_check(access_counts == {0: 1, 1: 2, 2: 1}, "Stair accessibility markers do not cover all floor transitions.")
	for floor_index in range(1, 3):
		var opening_point := STAIR_OPENING_CENTER + Vector3.UP * floor_index * FLOOR_HEIGHT
		var opening_is_visually_clear := true
		for mesh_node in level.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := mesh_node as MeshInstance3D
			var box := mesh_instance.mesh as BoxMesh
			if box == null:
				continue
			var local_point := mesh_instance.to_local(opening_point)
			if absf(local_point.x) <= box.size.x * 0.5 and absf(local_point.y) <= box.size.y * 0.5 + 0.02 and absf(local_point.z) <= box.size.z * 0.5:
				opening_is_visually_clear = false
				break
		_check(opening_is_visually_clear, "Floor %d visually covers the stairwell opening." % (floor_index + 1))
	var upper_rooms := _nodes_in_level_group(level, &"school_upper_room")
	_check(upper_rooms.size() == 16, "School should contain sixteen upper-floor rooms.")
	var upper_room_lights := level.find_children("UpperRoomLight_*", "OmniLight3D", true, false)
	_check(upper_room_lights.size() == 64, "Every upper-floor room should have four real ceiling lights.")
	var upper_room_counts := {1: 0, 2: 0}
	for room in upper_rooms:
		var floor_index := int(room.get_meta("floor_index", -1))
		upper_room_counts[floor_index] = int(upper_room_counts.get(floor_index, 0)) + 1
		_check(room.is_in_group("school_classrooms"), "%s is missing the school classroom marker." % room.name)
		_check(not str(room.get_meta("room_id", "")).is_empty() and not str(room.get_meta("room_kind", "")).is_empty(), "%s has incomplete room metadata." % room.name)
		var anchor := room.get_node_or_null("DecorationAnchor")
		_check(anchor is Marker3D and anchor.is_in_group("school_room_decorator_anchor"), "%s is missing its decorator anchor." % room.name)
		if anchor is Marker3D:
			for light_x in [-4.0, 4.0]:
				for light_z in [-4.5, 4.5]:
					var expected_light_position := (anchor as Marker3D).global_position + Vector3(light_x, 3.55, light_z)
					var has_matching_light := upper_room_lights.any(func(light: Node) -> bool: return (light as Node3D).global_position.distance_to(expected_light_position) < 0.05)
					_check(has_matching_light, "%s has a visible ceiling fixture without a matching light." % room.name)
		var decorations := room.find_children("ClassroomDecoration_*", "Node3D", true, false)
		_check(decorations.size() == 1, "%s should have exactly one decoration root." % room.name)
		if decorations.size() == 1:
			var decoration := decorations[0]
			_check(decoration.is_in_group("decorated_classroom"), "%s decoration is missing its integration group." % room.name)
			_check(int(decoration.get_meta("floor_index", -1)) == floor_index, "%s decoration has the wrong floor_index." % room.name)
			_check(decoration.get_meta("subject_id", "") == room.get_meta("room_kind", ""), "%s decoration has the wrong room marker." % room.name)
	_check(upper_room_counts == {1: 8, 2: 8}, "Each upper floor should contain eight rooms.")
	_check(_nodes_in_level_group(level, &"school_room_decorator_anchor").size() == 16, "Every upper-floor room should expose one decorator anchor.")
	_check(_nodes_in_level_group(level, &"school_classrooms").size() == 24, "School classroom markers should include seven subjects, kabinet, and sixteen upper rooms.")
	_check(_nodes_in_level_group(level, &"decorated_classroom").size() == 23, "All seven subject and sixteen upper rooms should be decorated.")
	_check(level.find_children("*CorridorFloor_*", "MeshInstance3D", true, false).size() == 12, "Corridor floors should be split into local light-safe sections.")
	_check(get_tree().get_nodes_in_group("teacher_enemies").size() == 8, "School should contain seven subject teachers and one headmistress.")
	_check(level.find_children("ClassroomDoor_*", "", true, false).size() == 8, "School should contain eight fitted classroom doors.")
	_check(level.find_children("DeskHiding_*", "Area3D", true, false).size() == 42, "Every student desk should have a hiding spot.")
	_check(level.find_children("*ChairBack_*", "StaticBody3D", true, false).size() == 42, "Desk furniture should block teachers physically.")
	var flashlight := player.find_child("Flashlight", true, false) as SpotLight3D
	var flashlight_fill := player.find_child("FlashlightFill", true, false) as SpotLight3D
	_check(flashlight != null and flashlight.spot_range >= 30.0 and flashlight.shadow_enabled and flashlight.shadow_blur > 1.0, "Player flashlight range or shadow smoothing is incorrect.")
	_check(flashlight_fill != null and flashlight_fill.spot_range > flashlight.spot_range and not flashlight_fill.shadow_enabled, "Soft flashlight distance fill is missing.")
	_check(int(ProjectSettings.get_setting("rendering/lights_and_shadows/positional_shadow/atlas_size", 0)) >= 4096 and not bool(ProjectSettings.get_setting("rendering/lights_and_shadows/positional_shadow/atlas_16_bits", true)), "Positional shadow atlas precision is too low.")
	_check(int(ProjectSettings.get_setting("rendering/limits/opengl/max_renderable_lights", 0)) >= 128, "Compatibility renderer light budget is too low for the school.")
	var classroom_lights := level.find_children("ClassroomLight_*", "OmniLight3D", true, false)
	_check(classroom_lights.size() == 32, "Every classroom and kabinet should contain four ceiling lights.")
	for light in classroom_lights:
		_check((light as OmniLight3D).light_energy >= 1.35 and (light as OmniLight3D).omni_range >= 8.8, "A classroom light is too dim or too short-ranged.")
	var corridor_panes := level.find_children("CorridorWindowGlass_*", "StaticBody3D", true, false)
	var exterior_panes := level.find_children("ExteriorWindowGlass_*", "StaticBody3D", true, false)
	_check(corridor_panes.size() == 21, "Every subject classroom should contain three corridor-facing window panes.")
	_check(exterior_panes.size() == 42, "Every subject classroom should contain six exterior window panes.")
	_check(level.find_children("*ExteriorWindowSill_*", "StaticBody3D", true, false).size() == 7, "Every exterior classroom window needs an opaque sill.")
	_check(level.find_children("*ExteriorWindowHeader_*", "StaticBody3D", true, false).size() == 7, "Every exterior classroom window needs an opaque header.")
	_check(level.find_children("*ExteriorWindowBefore_*", "StaticBody3D", true, false).size() == 7 and level.find_children("*ExteriorWindowAfter_*", "StaticBody3D", true, false).size() == 7, "Every exterior classroom window needs opaque wall sections on both sides.")
	for pane in corridor_panes:
		_check(is_equal_approx(absf((pane as Node3D).global_position.x), 3.0), "A corridor window was not placed between the corridor and its classroom.")
	for pane in exterior_panes:
		_check(is_equal_approx(absf((pane as Node3D).global_position.x), 23.0), "An exterior window was not placed on the school facade.")
		var pane_mesh := ((pane as Node).get_node("Glass") as MeshInstance3D).mesh as BoxMesh
		_check(pane_mesh.size.y < 2.4 and (pane as Node3D).global_position.y >= 2.1, "An exterior classroom window still spans floor to ceiling.")
	var window_panes := corridor_panes + exterior_panes
	for pane in window_panes:
		var glass := pane.get_node("Glass") as MeshInstance3D
		var material := (glass.mesh as BoxMesh).material as StandardMaterial3D
		_check(material != null and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and material.albedo_color.a <= 0.25, "A classroom window is not transparent.")
		_check(material != null and material.cull_mode == BaseMaterial3D.CULL_DISABLED, "A classroom window is not visible from both sides.")
		_check(glass.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "A classroom window blocks daylight.")
	var sun := level.find_child("SunLight", true, false) as DirectionalLight3D
	var environment_node := level.find_child("WorldEnvironment", true, false) as WorldEnvironment
	_check(sun != null and environment_node != null, "The school sunrise lighting is missing.")
	if sun != null and environment_node != null:
		level.call("_update_daylight", 0.0, 1.0)
		_check(sun.light_energy >= 0.85 and environment_node.environment.ambient_light_energy >= 0.65, "Morning sunlight does not brighten the school.")
		var sky_material := environment_node.environment.sky.sky_material as ProceduralSkyMaterial
		_check(sky_material.sky_top_color.is_equal_approx(Color("4d84b3")), "Morning sky color was not applied.")
		level.call("_update_daylight", 0.0, 0.0)
		_check(sun.light_energy <= 0.05 and environment_node.environment.ambient_light_energy <= 0.35, "Night lighting did not return after the sunrise test.")
	_check(not level.has_node("DigitalClock") and not level.has_node("AnalogClock"), "The test school should not contain classroom clocks.")
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


func _nodes_in_level_group(level: Node, group_name: StringName) -> Array[Node]:
	var nodes: Array[Node] = []
	for node in get_tree().get_nodes_in_group(group_name):
		if node == level or level.is_ancestor_of(node):
			nodes.append(node)
	return nodes


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
