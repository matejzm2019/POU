extends Node3D

const ROOM_ROWS := [-28.5, -9.5, 9.5, 28.5]
const SCHOOL_HALF_Z := 38.5
const DESK_HIDING_SPOT_SCRIPT := preload("res://systems/hiding/desk_hiding_spot.gd")

@export var door_scene: PackedScene
@export var teacher_scene: PackedScene
@export var homework_station_scene: PackedScene

var _materials: Dictionary = {}


func _ready() -> void:
	add_to_group("school_navigation_source")
	_build_shell()
	_build_corridor()
	_place_exit_door()
	_build_subject_classrooms()
	_build_kabinet()
	_build_lighting()
	_build_navigation()
	SchoolGameManager.blackout_changed.connect(_set_blackout)


func _build_shell() -> void:
	var wall := Color("34373a")
	_box("SchoolFloor", Vector3(0, -0.1, 0), Vector3(46, 0.2, 77), Color("25282a"))
	_box("SchoolCeiling", Vector3(0, 4.2, 0), Vector3(46, 0.2, 77), Color("17191b"))
	_box("NorthExteriorWallLeft", Vector3(-11.95, 2.05, -SCHOOL_HALF_Z), Vector3(22.1, 4.3, 0.3), wall)
	_box("NorthExteriorWallRight", Vector3(11.95, 2.05, -SCHOOL_HALF_Z), Vector3(22.1, 4.3, 0.3), wall)
	_box("NorthExitHeader", Vector3(0, 3.55, -SCHOOL_HALF_Z), Vector3(1.8, 1.3, 0.3), wall)
	_box("SouthExteriorWall", Vector3(0, 2.05, SCHOOL_HALF_Z), Vector3(46, 4.3, 0.3), wall)
	_box("WestExteriorWall", Vector3(-23, 2.05, 0), Vector3(0.3, 4.3, 77), wall)
	_box("EastExteriorWall", Vector3(23, 2.05, 0), Vector3(0.3, 4.3, 77), wall)

	for divider_z in [-19.0, 0.0, 19.0]:
		_box("WestRoomDivider_%s" % str(divider_z), Vector3(-13, 2.05, divider_z), Vector3(20, 4.3, 0.25), wall)
		_box("EastRoomDivider_%s" % str(divider_z), Vector3(13, 2.05, divider_z), Vector3(20, 4.3, 0.25), wall)

	for row_index in ROOM_ROWS.size():
		var row_z: float = ROOM_ROWS[row_index]
		for side_value in [-1.0, 1.0]:
			var side := float(side_value)
			var wall_x := side * 3.0
			var side_name := "West" if side < 0.0 else "East"
			_box("%sCorridorWallA_%d" % [side_name, row_index], Vector3(wall_x, 2.05, row_z - 5.2), Vector3(0.25, 4.3, 8.6), wall)
			_box("%sCorridorWallB_%d" % [side_name, row_index], Vector3(wall_x, 2.05, row_z + 5.2), Vector3(0.25, 4.3, 8.6), wall)
			_box("%sDoorHeader_%d" % [side_name, row_index], Vector3(wall_x, 3.55, row_z), Vector3(0.25, 1.3, 1.8), wall)


func _build_corridor() -> void:
	_box("CorridorFloor", Vector3(0, 0.015, 0), Vector3(5.7, 0.03, 76.4), Color("1d2426"), false)
	for z in range(-36, 38, 4):
		_box("CorridorTile_%d" % z, Vector3(0, 0.035, z), Vector3(5.6, 0.012, 0.055), Color("394044"), false)
	for side_value in [-1.0, 1.0]:
		var side := float(side_value)
		var side_name := "West" if side < 0.0 else "East"
		var locker_positions := [-36.0, -19.0, 0.0, 19.0, 36.0]
		for locker_index in locker_positions.size():
			_box("%sLockerBank_%d" % [side_name, locker_index], Vector3(side * 2.72, 1.15, locker_positions[locker_index]), Vector3(0.38, 2.3, 2.5), Color("35464d"))
	var directory := Label3D.new()
	directory.name = "SchoolDirectory"
	directory.text = "NOČNÁ ŠKOLA\nDEJEPIS  |  MATEMATIKA\nSLOVENSKÝ JAZYK  |  ELEKTROTECHNIKA\nEKONOMIKA  |  APLIKOVANÁ INFORMATIKA\nANGLICKÝ JAZYK  |  KABINET"
	directory.font_size = 34
	directory.pixel_size = 0.0055
	directory.outline_size = 7
	directory.modulate = Color("a9b6ad")
	directory.position = Vector3(-2.82, 2.35, -33.0)
	directory.rotation.y = PI * 0.5
	directory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(directory)


func _build_subject_classrooms() -> void:
	var placements := [
		{"subject": "dejepis", "side": -1.0, "z": -28.5},
		{"subject": "matematika", "side": 1.0, "z": -28.5},
		{"subject": "slovensky_jazyk", "side": -1.0, "z": -9.5},
		{"subject": "elektrotechnika", "side": 1.0, "z": -9.5},
		{"subject": "ekonomika", "side": -1.0, "z": 9.5},
		{"subject": "aplikovana_informatika", "side": 1.0, "z": 9.5},
		{"subject": "anglicky_jazyk", "side": -1.0, "z": 28.5},
	]
	for index in placements.size():
		var placement: Dictionary = placements[index]
		var subject := SchoolGameManager.get_subject(str(placement["subject"]))
		if subject == null:
			push_error("Chýbajú údaje predmetu %s." % str(placement["subject"]))
			continue
		var side := float(placement["side"])
		var center := Vector3(side * 13.0, 0, float(placement["z"]))
		_build_classroom(subject, center, side, index)


func _build_classroom(subject: SubjectData, center: Vector3, side: float, index: int) -> void:
	var room := Node3D.new()
	room.name = "Classroom_%02d_%s" % [index + 1, subject.subject_id]
	room.set_meta("subject_id", subject.subject_id)
	room.add_to_group("school_classrooms")
	add_child(room)

	_box("%sFloor" % subject.subject_id, center + Vector3(0, 0.012, 0), Vector3(19.6, 0.025, 18.6), subject.accent_color.darkened(0.68), false, 0.0, room)
	_box("%sBlackboard" % subject.subject_id, center + Vector3(0, 2.45, -9.28), Vector3(8.2, 1.8, 0.12), subject.accent_color.darkened(0.55), false, 0.0, room)
	_box("%sChalkTray" % subject.subject_id, center + Vector3(0, 1.5, -9.1), Vector3(8.35, 0.1, 0.28), Color("9c978b"), false, 0.0, room)
	_box("%sWindow" % subject.subject_id, Vector3(side * 22.82, 2.4, center.z + 3.5), Vector3(0.08, 1.65, 5.0), Color("07141c"), false, 0.18, room)
	_add_board_label(subject.display_name, subject.room_code, center, room)

	var desk_index := 0
	for local_z in [-2.2, 2.8]:
		for local_x in [-4.2, 0.0, 4.2]:
			desk_index += 1
			_build_student_desk(subject.subject_id, desk_index, center + Vector3(local_x, 0, local_z), subject.accent_color, room)
	var teacher_desk_position := center + Vector3(-4.5, 0, -6.6)
	_build_teacher_desk(subject.subject_id, teacher_desk_position, subject.accent_color, room)
	_build_subject_props(subject.subject_id, center, subject.accent_color, room)
	_place_homework_station(subject, teacher_desk_position + Vector3(0, 1.0, 0), room)
	_place_door(subject.subject_id, Vector3(side * 3.0, 0, center.z), side, room, index, false)
	_place_room_sign("%s  %s" % [subject.room_code, subject.display_name], Vector3(side * 2.82, 3.03, center.z), side, room)


func _build_kabinet() -> void:
	var center := Vector3(13, 0, 28.5)
	var accent := Color("4b4e47")
	var room := Node3D.new()
	room.name = "Kabinet"
	room.add_to_group("school_classrooms")
	add_child(room)
	_box("KabinetFloor", center + Vector3(0, 0.012, 0), Vector3(19.6, 0.025, 18.6), Color("202320"), false, 0.0, room)
	_box("KabinetBoard", center + Vector3(0, 2.45, -9.28), Vector3(8.2, 1.8, 0.12), Color("292d29"), false, 0.0, room)
	_add_board_label("KABINET UČITEĽOV", "K-401", center, room)
	for index in 4:
		_box("FilingCabinet_%d" % index, center + Vector3(8.2, 1.2, -6.5 + index * 4.0), Vector3(1.1, 2.4, 2.3), Color("303a3d"), true, 0.0, room)
	for index in 3:
		_build_teacher_desk("Kabinet_%d" % index, center + Vector3(-5.0 + index * 5.0, 0, -5.2), accent, room)
	_place_door("Kabinet", Vector3(3.0, 0, center.z), 1.0, room, 7, false, true)
	_place_room_sign("K-401  KABINET UČITEĽOV", Vector3(2.82, 3.03, center.z), 1.0, room)
	_place_teachers(room)


func _place_teachers(parent: Node3D) -> void:
	if teacher_scene == null:
		push_error("Škola nemá priradenú scénu učiteľa.")
		return
	var subjects := SchoolGameManager.get_subjects()
	for index in subjects.size():
		var subject := subjects[index]
		var data := SchoolGameManager.get_teacher_data(subject.subject_id)
		if data == null:
			continue
		var column := index % 4
		var row := index / 4
		var home := Vector3(8.2 + column * 3.0, 0.05, 24.0 + row * 7.0)
		_spawn_teacher(data, home, _school_patrol(index), subject.accent_color.darkened(0.1), "Teacher_%02d_%s" % [index + 1, subject.subject_id], parent)
	var headmistress := SchoolGameManager.get_headmistress_data()
	if headmistress != null:
		_spawn_teacher(headmistress, Vector3(17.2, 0.05, 31.0), _school_patrol(subjects.size()), Color("552f45"), "Headmistress_Zuzana_Cizmarikova", parent)


func _spawn_teacher(data: TeacherData, home: Vector3, patrol: PackedVector3Array, color: Color, enemy_name: String, parent: Node3D) -> void:
	var teacher_instance := teacher_scene.instantiate()
	var teacher := teacher_instance as PlaceholderTeacher
	if teacher == null:
		teacher_instance.queue_free()
		push_error("teacher_scene musí zostať wrapper PlaceholderTeacher; vlastný model priraď do TeacherData.model_scene.")
		return
	teacher.name = enemy_name
	teacher.position = home
	teacher.configure(data, home, patrol, color)
	teacher.add_to_group("teacher_enemies")
	parent.add_child(teacher)


func _school_patrol(offset: int) -> PackedVector3Array:
	var base := PackedVector3Array([
		Vector3(0, 0.05, -34.0),
		Vector3(-13, 0.05, -28.5),
		Vector3(13, 0.05, -28.5),
		Vector3(-13, 0.05, -9.5),
		Vector3(13, 0.05, -9.5),
		Vector3(-13, 0.05, 9.5),
		Vector3(13, 0.05, 9.5),
		Vector3(-13, 0.05, 28.5),
		Vector3(0, 0.05, 34.0),
	])
	var patrol := PackedVector3Array()
	for index in base.size():
		patrol.append(base[(index + offset) % base.size()])
	return patrol


func _build_student_desk(prefix: String, index: int, origin: Vector3, accent: Color, parent: Node3D) -> void:
	var wood := accent.lightened(0.08)
	var metal := Color("303638")
	_box("%sDeskTop_%02d" % [prefix, index], origin + Vector3(0, 0.9, 0), Vector3(1.8, 0.12, 0.82), wood, true, 0.0, parent)
	for x in [-0.72, 0.72]:
		for z in [-0.34, 0.34]:
			_box("%sDeskLeg_%02d" % [prefix, index], origin + Vector3(x, 0.43, z), Vector3(0.08, 0.86, 0.08), metal, true, 0.0, parent)
	_box("%sChairSeat_%02d" % [prefix, index], origin + Vector3(0, 0.46, 1.0), Vector3(0.92, 0.1, 0.75), wood, true, 0.0, parent)
	_box("%sChairBack_%02d" % [prefix, index], origin + Vector3(0, 0.92, 1.34), Vector3(0.92, 0.82, 0.1), wood, true, 0.0, parent)
	var hiding_spot := DESK_HIDING_SPOT_SCRIPT.new() as Area3D
	hiding_spot.name = "DeskHiding_%s_%02d" % [prefix, index]
	hiding_spot.position = origin + Vector3(0, 0.42, 0)
	var hiding_collision := CollisionShape3D.new()
	var hiding_shape := BoxShape3D.new()
	hiding_shape.size = Vector3(1.45, 0.8, 0.82)
	hiding_collision.shape = hiding_shape
	hiding_spot.add_child(hiding_collision)
	parent.add_child(hiding_spot)


func _build_teacher_desk(prefix: String, origin: Vector3, accent: Color, parent: Node3D) -> void:
	_box("%sTeacherDesk" % prefix, origin + Vector3(0, 0.84, 0), Vector3(3.2, 0.18, 1.2), accent.darkened(0.18), true, 0.0, parent)
	_box("%sTeacherDeskFront" % prefix, origin + Vector3(0, 0.43, -0.48), Vector3(3.0, 0.72, 0.1), accent.darkened(0.3), true, 0.0, parent)


func _build_subject_props(subject_id: String, center: Vector3, accent: Color, parent: Node3D) -> void:
	match subject_id:
		"dejepis":
			_box("HistoryDisplay", center + Vector3(0, 1.1, 7.9), Vector3(7.5, 2.1, 0.65), accent.darkened(0.3), true, 0.0, parent)
		"matematika":
			for index in 5:
				_box("MathBlock_%d" % index, center + Vector3(-2.0 + index, 0.35 + index * 0.12, 7.3), Vector3(0.7, 0.7, 0.7), accent.lightened(index * 0.05), true, 0.0, parent)
		"slovensky_jazyk", "anglicky_jazyk":
			for index in 4:
				_box("LanguageBook_%d" % index, center + Vector3(-2.4 + index * 1.6, 1.05 + index * 0.025, 7.7), Vector3(1.1, 0.12, 0.75), accent.lightened(index * 0.05), false, 0.0, parent)
		"elektrotechnika":
			_box("ElectricalBench", center + Vector3(0, 1.05, 6.8), Vector3(7.0, 0.16, 1.2), accent, true, 0.0, parent)
			for index in 4:
				_box("ElectricalPart_%d" % index, center + Vector3(-2.4 + index * 1.6, 1.24, 6.8), Vector3(0.28, 0.32, 0.28), Color("d2aa43"), false, 0.45, parent)
		"ekonomika":
			for index in 4:
				_box("Ledger_%d" % index, center + Vector3(-2.4 + index * 1.6, 1.02, 7.5), Vector3(1.05, 0.1, 0.72), Color("708273"), false, 0.0, parent)
		"aplikovana_informatika":
			for index in 3:
				_box("ComputerMonitor_%d" % index, center + Vector3(-4.2 + index * 4.2, 1.28, -2.25), Vector3(1.05, 0.7, 0.12), Color("142f2a"), false, 0.35, parent)


func _place_homework_station(subject: SubjectData, station_position: Vector3, parent: Node3D) -> void:
	if homework_station_scene == null:
		push_error("Škola nemá priradenú scénu domácej úlohy.")
		return
	var station := homework_station_scene.instantiate() as HomeworkStation
	station.name = "Homework_%s" % subject.subject_id
	station.position = station_position
	station.configure(subject)
	station.add_to_group("homework_stations")
	parent.add_child(station)


func _place_door(room_id: String, door_position: Vector3, side: float, parent: Node3D, index: int, initially_open: bool, player_locked := false) -> void:
	if door_scene == null:
		push_error("Škola nemá priradenú scénu dverí.")
		return
	var door := door_scene.instantiate() as Node3D
	door.name = "ClassroomDoor_%02d_%s" % [index + 1, room_id]
	door.position = door_position - Vector3(0, 0, 0.9)
	door.rotation_degrees.y = 90.0
	door.set("open_angle_degrees", -100.0 if side < 0.0 else 100.0)
	door.set("locked_for_player", player_locked)
	parent.add_child(door)
	if initially_open:
		door.call("set_open", true)
	_add_door_navigation_link(room_id, door_position, side)
	_add_door_frame(room_id, door_position, parent)
	if player_locked:
		_add_player_only_barrier(door_position, parent)


func _place_exit_door() -> void:
	if door_scene == null:
		push_error("Škola nemá priradenú scénu dverí pre východ.")
		return
	var door := door_scene.instantiate() as Node3D
	door.name = "SchoolExitDoor"
	door.position = Vector3(0.9, 0, -SCHOOL_HALF_Z + 0.15)
	door.set("open_angle_degrees", -105.0)
	door.set("morning_exit", true)
	door.set("teacher_can_open", false)
	add_child(door)
	var frame := Color("171a1b")
	_box("ExitDoorFrameLeft", Vector3(-0.96, 1.45, -SCHOOL_HALF_Z + 0.17), Vector3(0.12, 2.9, 0.34), frame, false)
	_box("ExitDoorFrameRight", Vector3(0.96, 1.45, -SCHOOL_HALF_Z + 0.17), Vector3(0.12, 2.9, 0.34), frame, false)
	_box("ExitDoorFrameTop", Vector3(0, 2.96, -SCHOOL_HALF_Z + 0.17), Vector3(2.04, 0.12, 0.34), frame, false)
	var sign := Label3D.new()
	sign.name = "ExitSign"
	sign.text = "VÝCHOD"
	sign.font_size = 36
	sign.pixel_size = 0.005
	sign.outline_size = 7
	sign.modulate = Color("8fc7a7")
	sign.position = Vector3(0, 3.3, -SCHOOL_HALF_Z + 0.19)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sign)


func _add_door_navigation_link(room_id: String, door_position: Vector3, side: float) -> void:
	var link := NavigationLink3D.new()
	link.name = "DoorNavigationLink_%s" % room_id
	link.start_position = door_position + Vector3(side * 0.9, 0.3, 0)
	link.end_position = door_position + Vector3(-side * 0.9, 0.3, 0)
	link.bidirectional = true
	add_child(link)


func _add_player_only_barrier(barrier_position: Vector3, parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "KabinetPlayerBarrier"
	body.collision_layer = 4
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.12, 2.9, 1.8)
	collision.shape = shape
	body.add_child(collision)
	body.position = barrier_position + Vector3(0, 1.45, 0)
	parent.add_child(body)


func _add_door_frame(room_id: String, center: Vector3, parent: Node3D) -> void:
	var frame := Color("171a1b")
	_box("%sDoorFrameLeft" % room_id, center + Vector3(0, 1.45, -0.96), Vector3(0.34, 2.9, 0.12), frame, false, 0.0, parent)
	_box("%sDoorFrameRight" % room_id, center + Vector3(0, 1.45, 0.96), Vector3(0.34, 2.9, 0.12), frame, false, 0.0, parent)
	_box("%sDoorFrameTop" % room_id, center + Vector3(0, 2.96, 0), Vector3(0.34, 0.12, 2.04), frame, false, 0.0, parent)


func _place_room_sign(text: String, sign_position: Vector3, side: float, parent: Node3D) -> void:
	var sign := Label3D.new()
	sign.name = "CorridorSign"
	sign.text = text.to_upper()
	sign.font_size = 28
	sign.pixel_size = 0.0045
	sign.outline_size = 6
	sign.modulate = Color("b5beb7")
	sign.position = sign_position
	sign.rotation.y = deg_to_rad(-90.0 * side)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(sign)


func _add_board_label(title: String, room_code: String, center: Vector3, parent: Node3D) -> void:
	var label := Label3D.new()
	label.name = "BoardLabel"
	label.text = "%s\nUČEBŇA %s  /  3 SADY ÚLOH" % [title.to_upper(), room_code]
	label.font_size = 38
	label.pixel_size = 0.0055
	label.outline_size = 5
	label.modulate = Color("d2d0c2")
	label.position = center + Vector3(0, 2.55, -9.18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)


func _build_lighting() -> void:
	for index in 10:
		_add_ceiling_light("CorridorLight_%02d" % index, Vector3(0, 3.82, -36.0 + index * 8.0), 1.45, 7.0, index % 2 == 0)
	for row_index in ROOM_ROWS.size():
		var row_z: float = ROOM_ROWS[row_index]
		for side_value in [-1.0, 1.0]:
			var center_x := float(side_value) * 13.0
			_add_ceiling_light("ClassroomLight_%d_%s_A" % [row_index, str(side_value)], Vector3(center_x - 4.0, 3.82, row_z), 1.15, 7.5, false)
			_add_ceiling_light("ClassroomLight_%d_%s_B" % [row_index, str(side_value)], Vector3(center_x + 4.0, 3.82, row_z), 1.05, 7.5, false)


func _add_ceiling_light(label: String, light_position: Vector3, energy: float, light_range: float, shadows: bool) -> void:
	var fixture := _box("%sFixture" % label, light_position + Vector3(0, 0.08, 0), Vector3(2.6, 0.08, 0.34), Color("c6d1c6"), false, 1.7)
	fixture.add_to_group("school_light_fixtures")
	var light := OmniLight3D.new()
	light.name = label
	light.position = light_position - Vector3(0, 0.22, 0)
	light.light_color = Color("c5d3c5")
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = shadows
	light.add_to_group("school_lights")
	add_child(light)


func _build_navigation() -> void:
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.agent_height = 2.0
	navigation_mesh.agent_radius = 0.5
	navigation_mesh.agent_max_climb = 0.25
	navigation_mesh.cell_size = 0.5
	navigation_mesh.cell_height = 0.25
	navigation_mesh.region_min_size = 1.0
	navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navigation_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navigation_mesh.geometry_source_group_name = &"school_navigation_source"
	navigation_mesh.geometry_collision_mask = 1
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	region.navigation_mesh = navigation_mesh
	add_child(region)
	region.bake_navigation_mesh(true)


func _set_blackout(active: bool) -> void:
	for node in get_tree().get_nodes_in_group("school_lights"):
		if is_ancestor_of(node):
			(node as Light3D).visible = not active
	for node in get_tree().get_nodes_in_group("school_light_fixtures"):
		if is_ancestor_of(node):
			(node as Node3D).visible = not active


func _box(label: String, box_position: Vector3, size: Vector3, color: Color, collision := true, emission := 0.0, parent: Node3D = null) -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color, emission)
	mesh_instance.mesh = mesh
	var root: Node3D
	if collision:
		var body := StaticBody3D.new()
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(mesh_instance)
		body.add_child(shape_node)
		root = body
	else:
		root = mesh_instance
	root.name = label
	root.position = box_position
	var target: Node3D = parent if parent != null else self
	target.add_child(root)
	return root


func _material(color: Color, emission: float) -> StandardMaterial3D:
	var key := "%s:%0.2f" % [color.to_html(), emission]
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	_materials[key] = material
	return material
