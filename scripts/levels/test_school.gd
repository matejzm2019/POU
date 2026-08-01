@tool
extends Node3D

const ROOM_ROWS := [-28.5, -9.5, 9.5, 28.5]
const SCHOOL_HALF_Z := 38.5
const ROOM_HALF_Z := 9.5
const CORRIDOR_WINDOW_CENTER_OFFSET_Z := 5.2
const CORRIDOR_WINDOW_WIDTH := 8.0
const WINDOW_BOTTOM := 1.0
const WINDOW_TOP := 3.35
const EXTERIOR_WINDOW_WIDTH := 12.0
const FLOOR_HEIGHT := 4.4
const FLOOR_COUNT := 3
const STAIR_TOWER_MIN_X := -2.8
const STAIR_TOWER_MAX_X := 10.4
const STAIR_TOWER_MIN_Z := 38.35
const STAIR_TOWER_MAX_Z := 45.9
const STAIR_START_X := 4.29
const STAIR_END_X := 8.45
const STAIR_LANDING_EAST_X := STAIR_TOWER_MAX_X - 0.3
const STAIR_FLIGHT_A_Z := 41.175
const STAIR_FLIGHT_B_Z := 43.075
const STAIR_FLIGHT_WIDTH := 1.65
const STAIR_STEPS_PER_FLIGHT := 13
const DESK_HIDING_SPOT_SCRIPT := preload("res://systems/hiding/desk_hiding_spot.gd")
const CLASSROOM_DECORATOR := preload("res://scripts/levels/classroom_decorator.gd")
const SCHOOL_VISUAL_POLISH := preload("res://scripts/levels/school_visual_polish.gd")
const UPPER_ROOM_NAMES := {
	"classroom": "VŠEOBECNÁ UČEBŇA",
	"library": "KNIŽNICA",
	"science_lab": "PRÍRODOVEDNÉ LABORATÓRIUM",
	"study_room": "ŠTUDOVŇA",
	"technical_workshop": "POLYTECHNICKÁ DIELŇA",
	"computer_lab": "POČÍTAČOVÉ LABORATÓRIUM",
	"music_room": "HUDOBNÁ UČEBŇA",
	"archive": "ŠKOLSKÝ ARCHÍV",
}

@export var door_scene: PackedScene
@export var teacher_scene: PackedScene
@export var homework_station_scene: PackedScene
@export_category("Editor Preview")
@export var show_editor_preview := true:
	set(value):
		show_editor_preview = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("_build_editor_preview")

@onready var _school_environment: WorldEnvironment = $WorldEnvironment
@onready var _sun_light: DirectionalLight3D = $SunLight

var _materials: Dictionary = {}
var _upper_patrol_points := PackedVector3Array()


func _ready() -> void:
	if Engine.is_editor_hint():
		if show_editor_preview:
			call_deferred("_build_editor_preview")
		return
	_build_runtime_school()


func _build_runtime_school() -> void:
	add_to_group("school_navigation_source")
	_build_floor_markers()
	_build_school_exterior()
	_build_shell()
	_build_upper_floors()
	_build_stairs()
	_build_sports_complex()
	_build_corridor()
	_place_exit_door()
	_build_subject_classrooms()
	_build_kabinet()
	_build_lighting()
	SCHOOL_VISUAL_POLISH.apply(self)
	_build_navigation()
	SchoolGameManager.blackout_changed.connect(_set_blackout)
	NightManager.time_updated.connect(_update_daylight)
	_update_daylight(NightManager.current_in_game_time, NightManager.get_night_progress())


func _build_editor_preview() -> void:
	var preview_root := get_node_or_null("EditorPreview") as Node3D
	if preview_root == null or not is_inside_tree():
		return
	for child in preview_root.get_children():
		child.free()
	if not show_editor_preview:
		return
	_upper_patrol_points.clear()
	_materials.clear()
	var existing_children := get_children()
	_build_floor_markers()
	_build_school_exterior()
	_build_shell()
	_build_upper_floors()
	_build_stairs()
	_build_sports_complex()
	_build_corridor()
	_place_exit_door()
	_build_subject_classrooms()
	_build_kabinet()
	_build_lighting()
	SCHOOL_VISUAL_POLISH.apply(self)
	for child in get_children():
		if child != preview_root and not existing_children.has(child):
			child.reparent(preview_root)


func _build_school_exterior() -> void:
	var exterior := Node3D.new()
	exterior.name = "SchoolExterior"
	exterior.add_to_group("school_exterior")
	add_child(exterior)
	var grass := _box("SchoolGroundGrass", Vector3(25.0, -0.24, 0), Vector3(160.0, 0.18, 150.0), Color("294b32"), false, 0.0, exterior)
	grass.add_to_group("school_exterior_ground")
	_box("NorthEntranceWalk", Vector3(-3.8, -0.12, -60.0), Vector3(4.2, 0.06, 28.0), Color("676b68"), false, 0.0, exterior)
	_box("SouthCourtyardWalk", Vector3(0, -0.12, 50.0), Vector3(7.0, 0.06, 23.0), Color("676b68"), false, 0.0, exterior)
	var tree_positions: Array[Vector3] = [
		Vector3(-38, 0, -30), Vector3(-42, 0, -10), Vector3(-39, 0, 14), Vector3(-43, 0, 34),
		Vector3(-25, 0, 55), Vector3(-10, 0, 60), Vector3(12, 0, 58), Vector3(30, 0, 53),
		Vector3(50, 0, 52), Vector3(72, 0, 43), Vector3(92, 0, 24), Vector3(94, 0, 4),
		Vector3(94, 0, -20), Vector3(94, 0, -44), Vector3(35, 0, -61), Vector3(17, 0, -65),
		Vector3(-20, 0, -62), Vector3(-40, 0, -55),
	]
	for index in tree_positions.size():
		_add_exterior_tree(exterior, index, tree_positions[index], 0.9 + (index % 4) * 0.08)


func _add_exterior_tree(parent: Node3D, index: int, tree_position: Vector3, tree_scale: float) -> void:
	var tree := Node3D.new()
	tree.name = "ExteriorTree_%02d" % (index + 1)
	tree.position = tree_position
	tree.add_to_group("school_exterior_tree")
	parent.add_child(tree)
	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.22 * tree_scale
	trunk_mesh.bottom_radius = 0.36 * tree_scale
	trunk_mesh.height = 4.4 * tree_scale
	trunk_mesh.radial_segments = 10
	trunk_mesh.material = _material(Color("5c4430"), 0.0)
	trunk.mesh = trunk_mesh
	trunk.position.y = trunk_mesh.height * 0.5 - 0.1
	tree.add_child(trunk)
	for crown_index in 2:
		var crown := MeshInstance3D.new()
		crown.name = "Crown_%d" % (crown_index + 1)
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = (1.8 - crown_index * 0.25) * tree_scale
		crown_mesh.height = crown_mesh.radius * 2.0
		crown_mesh.radial_segments = 12
		crown_mesh.rings = 7
		crown_mesh.material = _material(Color("244f32").lightened(crown_index * 0.08), 0.0)
		crown.mesh = crown_mesh
		crown.position = Vector3((crown_index * 2 - 1) * 0.45 * tree_scale, (4.1 + crown_index * 1.05) * tree_scale, 0)
		tree.add_child(crown)


func _build_shell() -> void:
	var wall := Color("34373a")
	_box("SchoolFloor", Vector3(0, -0.1, 0), Vector3(46, 0.2, 77), Color("25282a"))
	_box("NorthExteriorWallLeft", Vector3(-13, 2.05, -SCHOOL_HALF_Z), Vector3(20, 4.3, 0.3), wall)
	_box("NorthExteriorWallRight", Vector3(13, 2.05, -SCHOOL_HALF_Z), Vector3(20, 4.3, 0.3), wall)
	_box("NorthStairPortalHeader", Vector3(0, 3.55, -SCHOOL_HALF_Z), Vector3(6, 1.3, 0.3), Color("445054"))
	_box("SouthExteriorWallLeft", Vector3(-13, 2.05, SCHOOL_HALF_Z), Vector3(20, 4.3, 0.3), wall)
	_box("SouthExteriorWallRight", Vector3(13, 2.05, SCHOOL_HALF_Z), Vector3(20, 4.3, 0.3), wall)
	_box("GroundStairPortalHeader", Vector3(0, 3.55, SCHOOL_HALF_Z), Vector3(6, 1.3, 0.3), Color("445054"))
	for row_index in ROOM_ROWS.size():
		var row_z: float = ROOM_ROWS[row_index]
		_build_exterior_wall_row(-1.0, row_index, row_z, wall, true)
		_build_exterior_wall_row(1.0, row_index, row_z, wall, row_index < ROOM_ROWS.size() - 1)

	for divider_z in [-19.0, 0.0, 19.0]:
		_box("WestRoomDivider_%s" % str(divider_z), Vector3(-13, 2.05, divider_z), Vector3(20, 4.3, 0.25), wall)
		_box("EastRoomDivider_%s" % str(divider_z), Vector3(13, 2.05, divider_z), Vector3(20, 4.3, 0.25), wall)

	for row_index in ROOM_ROWS.size():
		var row_z: float = ROOM_ROWS[row_index]
		for side_value in [-1.0, 1.0]:
			var side := float(side_value)
			_build_corridor_wall_row(side, row_index, row_z, wall, not (side > 0.0 and row_index == ROOM_ROWS.size() - 1))


func _build_floor_markers() -> void:
	for floor_index in FLOOR_COUNT:
		var floor_root := Node3D.new()
		floor_root.name = "SchoolFloor_%d" % (floor_index + 1)
		floor_root.position.y = floor_index * FLOOR_HEIGHT
		floor_root.add_to_group("school_floor")
		floor_root.set_meta("floor_index", floor_index)
		add_child(floor_root)


func _build_upper_floors() -> void:
	var room_kinds := ["classroom", "library", "science_lab", "study_room", "technical_workshop", "computer_lab", "music_room", "archive"]
	for floor_index in range(1, FLOOR_COUNT):
		var base_y := floor_index * FLOOR_HEIGHT
		_build_floor_slab(floor_index, base_y)
		for corridor_index in ROOM_ROWS.size():
			_box("UpperCorridorFloor_F%d_%02d" % [floor_index + 1, corridor_index + 1], Vector3(0, base_y + 0.015, ROOM_ROWS[corridor_index]), Vector3(5.7, 0.03, 19.1), Color("20292b"), false)
		_box("UpperNorthWallLeft_F%d" % (floor_index + 1), Vector3(-13, base_y + 2.05, -SCHOOL_HALF_Z), Vector3(20, 4.3, 0.3), Color("34373a"))
		_box("UpperNorthWallRight_F%d" % (floor_index + 1), Vector3(13, base_y + 2.05, -SCHOOL_HALF_Z), Vector3(20, 4.3, 0.3), Color("34373a"))
		_box("UpperNorthStairPortalHeader_F%d" % (floor_index + 1), Vector3(0, base_y + 3.55, -SCHOOL_HALF_Z), Vector3(6, 1.3, 0.3), Color("445054"))
		_box("UpperSouthWallLeft_F%d" % (floor_index + 1), Vector3(-13, base_y + 2.05, SCHOOL_HALF_Z), Vector3(20, 4.3, 0.3), Color("34373a"))
		_box("UpperSouthWallRight_F%d" % (floor_index + 1), Vector3(13, base_y + 2.05, SCHOOL_HALF_Z), Vector3(20, 4.3, 0.3), Color("34373a"))
		_box("UpperStairPortalHeader_F%d" % (floor_index + 1), Vector3(0, base_y + 3.55, SCHOOL_HALF_Z), Vector3(6, 1.3, 0.3), Color("445054"))
		for divider_z in [-19.0, 0.0, 19.0]:
			for side_value in [-1.0, 1.0]:
				var side := float(side_value)
				_box("UpperDivider_F%d_%s_%s" % [floor_index + 1, "W" if side < 0.0 else "E", str(divider_z)], Vector3(side * 13.0, base_y + 2.05, divider_z), Vector3(20, 4.3, 0.25), Color("34373a"))
		for row_index in ROOM_ROWS.size():
			var row_z: float = ROOM_ROWS[row_index]
			for side_index in 2:
				var side := -1.0 if side_index == 0 else 1.0
				var room_slot := row_index * 2 + side_index
				_build_upper_facade(floor_index, side, row_index, row_z, base_y)
				_build_upper_corridor_wall(floor_index, side, row_index, row_z, base_y)
				var room_kind := str(room_kinds[room_slot])
				_build_upper_room(floor_index, side, row_index, row_z, base_y, room_kind)
		_add_floor_sign(floor_index, base_y)
		for marker_index in 4:
			var side := -13.0 if (marker_index + floor_index) % 2 == 0 else 13.0
			_add_upper_patrol_marker(floor_index, marker_index, Vector3(side, base_y + 0.05, ROOM_ROWS[marker_index]))
		for light_index in 8:
			_add_ceiling_light("UpperCorridorLight_F%d_%02d" % [floor_index + 1, light_index], Vector3(0, base_y + 3.82, -34.0 + light_index * 9.5), 1.2, 7.0, false)
	_box("SchoolRoof", Vector3(0, FLOOR_COUNT * FLOOR_HEIGHT - 0.1, 0), Vector3(46, 0.2, 77), Color("17191b"))


func _build_floor_slab(floor_index: int, base_y: float) -> void:
	var slab_y := base_y - 0.1
	var color := Color("25282a")
	_box("FloorSlab_F%d" % (floor_index + 1), Vector3(0, slab_y, 0), Vector3(46, 0.2, 77), color)
	for stair_data in [["South", 0.0], ["North", PI]]:
		var root := Node3D.new()
		root.name = "%sStairFloorSections_F%d" % [str(stair_data[0]), floor_index + 1]
		root.rotation.y = float(stair_data[1])
		add_child(root)
		_build_stair_floor_sections(root, str(stair_data[0]), floor_index, slab_y, color)


func _build_stair_floor_sections(parent: Node3D, prefix: String, floor_index: int, slab_y: float, color: Color) -> void:
	var tower_center_z := (STAIR_TOWER_MIN_Z + STAIR_TOWER_MAX_Z) * 0.5
	var tower_depth := STAIR_TOWER_MAX_Z - STAIR_TOWER_MIN_Z
	var opening_north := STAIR_FLIGHT_A_Z - STAIR_FLIGHT_WIDTH * 0.5
	var opening_south := STAIR_FLIGHT_B_Z + STAIR_FLIGHT_WIDTH * 0.5
	_box("%sStairFloorWest_F%d" % [prefix, floor_index + 1], Vector3((STAIR_TOWER_MIN_X + STAIR_START_X) * 0.5, slab_y, tower_center_z), Vector3(STAIR_START_X - STAIR_TOWER_MIN_X, 0.2, tower_depth), color, true, 0.0, parent)
	_box("%sStairFloorEast_F%d" % [prefix, floor_index + 1], Vector3((STAIR_LANDING_EAST_X + STAIR_TOWER_MAX_X) * 0.5, slab_y, tower_center_z), Vector3(STAIR_TOWER_MAX_X - STAIR_LANDING_EAST_X, 0.2, tower_depth), color, true, 0.0, parent)
	_box("%sStairFloorNorth_F%d" % [prefix, floor_index + 1], Vector3((STAIR_START_X + STAIR_LANDING_EAST_X) * 0.5, slab_y, (STAIR_TOWER_MIN_Z + opening_north) * 0.5), Vector3(STAIR_LANDING_EAST_X - STAIR_START_X, 0.2, opening_north - STAIR_TOWER_MIN_Z), color, true, 0.0, parent)
	_box("%sStairFloorSouth_F%d" % [prefix, floor_index + 1], Vector3((STAIR_START_X + STAIR_LANDING_EAST_X) * 0.5, slab_y, (opening_south + STAIR_TOWER_MAX_Z) * 0.5), Vector3(STAIR_LANDING_EAST_X - STAIR_START_X, 0.2, STAIR_TOWER_MAX_Z - opening_south), color, true, 0.0, parent)


func _build_upper_facade(floor_index: int, side: float, row_index: int, row_z: float, base_y: float) -> void:
	var prefix := "UpperFacade_F%d_%s_%d" % [floor_index + 1, "W" if side < 0.0 else "E", row_index + 1]
	var wall_x := side * 23.0
	var width := 19.0
	var window_width := 8.0
	var edge_width := (width - window_width) * 0.5
	var wall := Color("34373a")
	_box("%sBefore" % prefix, Vector3(wall_x, base_y + 2.05, row_z - window_width * 0.5 - edge_width * 0.5), Vector3(0.3, 4.3, edge_width), wall)
	_box("%sAfter" % prefix, Vector3(wall_x, base_y + 2.05, row_z + window_width * 0.5 + edge_width * 0.5), Vector3(0.3, 4.3, edge_width), wall)
	_box("%sSill" % prefix, Vector3(wall_x, base_y + WINDOW_BOTTOM * 0.5, row_z), Vector3(0.3, WINDOW_BOTTOM, window_width), wall)
	_box("%sHeader" % prefix, Vector3(wall_x, base_y + WINDOW_TOP + (4.2 - WINDOW_TOP) * 0.5, row_z), Vector3(0.3, 4.2 - WINDOW_TOP, window_width), wall)
	_build_window_bank(prefix, "F%d_R%d" % [floor_index + 1, row_index + 1], wall_x, side * 22.88, row_z, window_width, base_y + WINDOW_BOTTOM, base_y + WINDOW_TOP, 4, self)


func _build_upper_corridor_wall(floor_index: int, side: float, row_index: int, row_z: float, base_y: float) -> void:
	var prefix := "UpperCorridorWall_F%d_%s_%d" % [floor_index + 1, "W" if side < 0.0 else "E", row_index + 1]
	var wall_x := side * 3.0
	var wall := Color("34373a")
	_box("%sA" % prefix, Vector3(wall_x, base_y + 2.05, row_z - 5.2), Vector3(0.25, 4.3, 8.6), wall)
	_box("%sDoorHeader" % prefix, Vector3(wall_x, base_y + 3.55, row_z), Vector3(0.25, 1.3, 1.8), wall)
	var edge_width := 8.6 - CORRIDOR_WINDOW_WIDTH
	var window_center_z := row_z + CORRIDOR_WINDOW_CENTER_OFFSET_Z
	_box("%sWindowBefore" % prefix, Vector3(wall_x, base_y + 2.05, row_z + 0.9 + edge_width * 0.25), Vector3(0.25, 4.3, edge_width * 0.5), wall)
	_box("%sWindowAfter" % prefix, Vector3(wall_x, base_y + 2.05, row_z + 9.5 - edge_width * 0.25), Vector3(0.25, 4.3, edge_width * 0.5), wall)
	_box("%sWindowSill" % prefix, Vector3(wall_x, base_y + WINDOW_BOTTOM * 0.5, window_center_z), Vector3(0.25, WINDOW_BOTTOM, CORRIDOR_WINDOW_WIDTH), wall)
	_box("%sWindowHeader" % prefix, Vector3(wall_x, base_y + WINDOW_TOP + (4.2 - WINDOW_TOP) * 0.5, window_center_z), Vector3(0.25, 4.2 - WINDOW_TOP, CORRIDOR_WINDOW_WIDTH), wall)
	_build_window_bank("UpperCorridorWindow", "F%d_%s_%d" % [floor_index + 1, "W" if side < 0.0 else "E", row_index + 1], wall_x, side * 3.22, window_center_z, CORRIDOR_WINDOW_WIDTH, base_y + WINDOW_BOTTOM, base_y + WINDOW_TOP, 3, self)


func _build_upper_room(floor_index: int, side: float, row_index: int, row_z: float, base_y: float, room_kind: String) -> void:
	var side_name := "West" if side < 0.0 else "East"
	var room_id := "F%d_%s_%d" % [floor_index + 1, side_name, row_index + 1]
	var center := Vector3(side * 13.0, base_y, row_z)
	var room := Node3D.new()
	room.name = "UpperRoom_%s" % room_id
	room.add_to_group("school_upper_room")
	room.add_to_group("school_classrooms")
	room.set_meta("floor_index", floor_index)
	room.set_meta("room_id", room_id)
	room.set_meta("room_kind", room_kind)
	add_child(room)
	var accent := Color("43575a").lightened(0.05 * row_index)
	_box("%sFloor" % room_id, center + Vector3(0, 0.012, 0), Vector3(19.6, 0.025, 18.6), accent.darkened(0.48), false, 0.0, room)
	var decoration := CLASSROOM_DECORATOR.decorate(room, center, room_kind, accent, side)
	decoration.set_meta("floor_index", floor_index)
	_place_room_sign("F%d-%02d  %s" % [floor_index + 1, row_index * 2 + (2 if side > 0.0 else 1), str(UPPER_ROOM_NAMES.get(room_kind, "UČEBŇA"))], Vector3(side * 2.82, base_y + 3.03, row_z), side, room)
	var anchor := Marker3D.new()
	anchor.name = "DecorationAnchor"
	anchor.position = center + Vector3(0, 0.05, 0)
	anchor.add_to_group("school_room_decorator_anchor")
	anchor.set_meta("floor_index", floor_index)
	anchor.set_meta("room_id", room_id)
	anchor.set_meta("room_kind", room_kind)
	room.add_child(anchor)
	for light_x in [-4.0, 4.0]:
		for light_z in [-4.5, 4.5]:
			_add_ceiling_light("UpperRoomLight_%s_%s_%s" % [room_id, str(light_x), str(light_z)], center + Vector3(light_x, 3.82, light_z), 1.35, 8.8, false, false)
	var door_index := 8 + (floor_index - 1) * 8 + row_index * 2 + (1 if side > 0.0 else 0)
	_place_door(room_id, Vector3(side * 3.0, base_y, row_z), side, room, door_index, false)



func _build_sports_complex() -> void:
	var root := Node3D.new()
	root.name = "SportsComplex"
	root.add_to_group("school_sports_complex")
	add_child(root)
	_build_sports_connector(root)
	_build_gym_shell(root)
	_build_gym_interior(root)
	var patrol_points: Array[Vector3] = [
		Vector3(10.0, 0.05, -42.125),
		Vector3(32.0, 0.05, -42.125),
		Vector3(53.0, 0.05, -42.125),
		Vector3(70.0, 0.05, -28.5),
	]
	for index in patrol_points.size():
		var marker := Marker3D.new()
		marker.name = "GymPatrol_%02d" % (index + 1)
		marker.position = patrol_points[index]
		marker.add_to_group("gym_patrol_marker")
		root.add_child(marker)
		_upper_patrol_points.append(marker.position)


func _build_sports_connector(parent: Node3D) -> void:
	var center_x := 23.4
	var center_z := -42.125
	var connector_length := 41.2
	_box("GymConnectorFloor", Vector3(center_x, -0.08, center_z), Vector3(connector_length, 0.16, 3.6), Color("4d5552"), true, 0.0, parent)
	_box("GymConnectorRoof", Vector3(center_x, 3.85, center_z), Vector3(connector_length, 0.2, 3.9), Color("c9c8be"), true, 0.0, parent)
	for side in [-1.0, 1.0]:
		var wall_z: float = center_z + float(side) * 1.8
		_box("GymConnectorSill_%s" % str(side), Vector3(center_x, 0.45, wall_z), Vector3(connector_length, 0.9, 0.18), Color("d8d5c9"), true, 0.0, parent)
		_box("GymConnectorHeader_%s" % str(side), Vector3(center_x, 3.42, wall_z), Vector3(connector_length, 0.86, 0.18), Color("b9bbb4"), true, 0.0, parent)
		for pane_index in 10:
			var pane_x := 5.0 + pane_index * 4.1
			_add_window_pane("GymConnectorGlass_%s_%02d" % [str(side), pane_index + 1], Vector3(pane_x, 1.95, wall_z), Vector3(4.05, 2.0, 0.08), parent)
		for mullion_index in 11:
			_box("GymConnectorMullion_%s_%02d" % [str(side), mullion_index + 1], Vector3(2.9 + mullion_index * 4.1, 1.95, wall_z - float(side) * 0.04), Vector3(0.12, 2.1, 0.16), Color("6e7774"), false, 0.0, parent)
	for light_index in 6:
		_add_ceiling_light("GymConnectorLight_%02d" % (light_index + 1), Vector3(6.0 + light_index * 7.2, 3.45, center_z), 1.25, 7.5, false)


func _build_gym_shell(parent: Node3D) -> void:
	var center := Vector3(62.0, 0.0, -28.5)
	var half_x := 18.0
	var half_z := 23.0
	var east_x := center.x + half_x
	var west_x := center.x - half_x
	var north_z := center.z - half_z
	var south_z := center.z + half_z
	var facade := Color("d8d5c9")
	var lower := Color("526a62")
	_box("GymFoundation", center + Vector3(0, -0.15, 0), Vector3(36.0, 0.3, 46.0), Color("343937"), true, 0.0, parent)
	_box("GymRoof", center + Vector3(0, 9.6, 0), Vector3(36.6, 0.28, 46.6), Color("8d918d"), true, 0.0, parent)
	var portal_width := 3.6
	var portal_center_z := -42.125
	var north_segment := portal_center_z - portal_width * 0.5 - north_z
	var south_segment := south_z - portal_center_z - portal_width * 0.5
	_box("GymWestWallNorth", Vector3(west_x, 4.75, north_z + north_segment * 0.5), Vector3(0.35, 9.5, north_segment), facade, true, 0.0, parent)
	_box("GymWestWallSouth", Vector3(west_x, 4.75, portal_center_z + portal_width * 0.5 + south_segment * 0.5), Vector3(0.35, 9.5, south_segment), facade, true, 0.0, parent)
	_box("GymWestPortalHeader", Vector3(west_x, 6.65, portal_center_z), Vector3(0.35, 5.7, portal_width), facade, true, 0.0, parent)
	_box("GymEastLowerWall", Vector3(east_x, 2.0, center.z), Vector3(0.35, 4.0, 46.0), lower, true, 0.0, parent)
	_box("GymEastUpperWall", Vector3(east_x, 8.55, center.z), Vector3(0.35, 1.9, 46.0), facade, true, 0.0, parent)
	for pane_index in 10:
		var pane_z := north_z + 2.3 + pane_index * 4.6
		_add_window_pane("GymEastClerestory_%02d" % (pane_index + 1), Vector3(east_x, 5.85, pane_z), Vector3(0.1, 3.45, 4.35), parent)
		_box("GymEastMullion_%02d" % (pane_index + 1), Vector3(east_x - 0.04, 5.85, pane_z - 2.25), Vector3(0.18, 3.6, 0.16), facade, false, 0.0, parent)
	for wall_data in [[north_z, "North"], [south_z, "South"]]:
		var wall_z := float(wall_data[0])
		var wall_name := str(wall_data[1])
		_box("Gym%sLowerWall" % wall_name, Vector3(center.x, 2.0, wall_z), Vector3(36.0, 4.0, 0.35), lower, true, 0.0, parent)
		_box("Gym%sUpperWall" % wall_name, Vector3(center.x, 8.55, wall_z), Vector3(36.0, 1.9, 0.35), facade, true, 0.0, parent)
		for pane_index in 8:
			var pane_x := west_x + 2.25 + pane_index * 4.5
			_add_window_pane("Gym%sClerestory_%02d" % [wall_name, pane_index + 1], Vector3(pane_x, 5.85, wall_z), Vector3(4.25, 3.45, 0.1), parent)
			_box("Gym%sMullion_%02d" % [wall_name, pane_index + 1], Vector3(pane_x - 2.2, 5.85, wall_z), Vector3(0.16, 3.6, 0.18), facade, false, 0.0, parent)
	for truss_index in 9:
		var truss_z := north_z + 2.5 + truss_index * 5.1
		_box("GymRoofTruss_%02d" % (truss_index + 1), Vector3(center.x, 8.92, truss_z), Vector3(35.2, 0.18, 0.18), Color("4b5351"), false, 0.0, parent)
	var facade_sign := Label3D.new()
	facade_sign.name = "GymFacadeSign"
	facade_sign.text = "SOŠ POLYTECHNICKÁ\nTELOCVIČŇA • SNP 2 • ZLATÉ MORAVCE"
	facade_sign.position = Vector3(west_x - 0.2, 8.15, center.z - 5.0)
	facade_sign.rotation.y = PI * 0.5
	facade_sign.font_size = 42
	facade_sign.pixel_size = 0.006
	facade_sign.outline_size = 7
	facade_sign.modulate = Color("24453f")
	parent.add_child(facade_sign)


func _build_gym_interior(parent: Node3D) -> void:
	var center := Vector3(62.0, 0.0, -28.5)
	_box("GymSportsFloor", center + Vector3(0, 0.035, 0), Vector3(34.8, 0.035, 44.8), Color("9c7145"), false, 0.0, parent)
	var white := Color("e7e6d9")
	var blue := Color("2d7080")
	for x in [center.x - 12.0, center.x + 12.0]:
		_box("GymSideline_%s" % str(x), Vector3(x, 0.062, center.z), Vector3(0.08, 0.014, 40.0), white, false, 0.0, parent)
	for z in [center.z - 20.0, center.z + 20.0]:
		_box("GymBaseline_%s" % str(z), Vector3(center.x, 0.063, z), Vector3(24.0, 0.014, 0.08), white, false, 0.0, parent)
	_box("GymCenterLine", center + Vector3(0, 0.064, 0), Vector3(24.0, 0.014, 0.08), blue, false, 0.0, parent)
	var center_circle := MeshInstance3D.new()
	center_circle.name = "GymCenterCircle"
	var circle_mesh := CylinderMesh.new()
	circle_mesh.top_radius = 1.8
	circle_mesh.bottom_radius = 1.8
	circle_mesh.height = 0.014
	circle_mesh.radial_segments = 48
	circle_mesh.material = _material(blue, 0.0)
	center_circle.mesh = circle_mesh
	center_circle.position = center + Vector3(0, 0.066, 0)
	parent.add_child(center_circle)
	for z in [center.z - 21.2, center.z + 21.2]:
		var direction := signf(z - center.z)
		_box("GymHoopPole_%s" % str(z), Vector3(center.x, 1.6, z), Vector3(0.24, 3.2, 0.24), Color("4b5351"), true, 0.0, parent)
		_box("GymBasketballBackboard_%s" % str(z), Vector3(center.x, 3.35, z - direction * 0.12), Vector3(4.2, 2.15, 0.16), Color("dfe2dc"), false, 0.0, parent)
		var rim := MeshInstance3D.new()
		rim.name = "GymBasketballRim_%s" % str(z)
		var rim_mesh := CylinderMesh.new()
		rim_mesh.top_radius = 0.42
		rim_mesh.bottom_radius = 0.42
		rim_mesh.height = 0.06
		rim_mesh.radial_segments = 32
		rim_mesh.material = _material(Color("d36b24"), 0.0)
		rim.mesh = rim_mesh
		rim.position = Vector3(center.x, 2.75, z - direction * 0.62)
		parent.add_child(rim)
		for goal_x in [center.x - 3.0, center.x + 3.0]:
			_box("GymGoalPost_%s_%s" % [str(z), str(goal_x)], Vector3(goal_x, 1.15, z - direction * 0.45), Vector3(0.13, 2.3, 0.13), Color("e8e5d7"), true, 0.0, parent)
		_box("GymGoalCrossbar_%s" % str(z), Vector3(center.x, 2.28, z - direction * 0.45), Vector3(6.1, 0.13, 0.13), Color("e8e5d7"), true, 0.0, parent)
	for tier_index in 4:
		_box("GymBleacherTier_%02d" % (tier_index + 1), Vector3(78.5 - tier_index * 0.9, 0.22 + tier_index * 0.35, center.z), Vector3(0.9, 0.44 + tier_index * 0.7, 18.0), Color("68716d"), true, 0.0, parent)
	for bar_index in 7:
		_box("GymWallBarVertical_%02d" % (bar_index + 1), Vector3(45.0, 1.65, -15.0 + bar_index * 0.7), Vector3(0.12, 3.1, 0.12), Color("956d45"), true, 0.0, parent)
	for rail_index in 9:
		_box("GymWallBarRail_%02d" % (rail_index + 1), Vector3(45.1, 0.35 + rail_index * 0.34, -12.9), Vector3(0.12, 0.08, 4.4), Color("956d45"), false, 0.0, parent)
	var scoreboard := Label3D.new()
	scoreboard.name = "GymScoreboard"
	scoreboard.text = "DOMÁCI   00 : 00   HOSTIA\nSOŠ POLYTECHNICKÁ"
	scoreboard.position = Vector3(70.0, 6.9, -51.28)
	scoreboard.font_size = 44
	scoreboard.pixel_size = 0.006
	scoreboard.outline_size = 9
	scoreboard.modulate = Color("d7eee2")
	parent.add_child(scoreboard)
	for x_index in 3:
		for z_index in 4:
			_add_ceiling_light("GymHallLight_%d_%d" % [x_index, z_index], Vector3(52.0 + x_index * 10.0, 8.55, -44.0 + z_index * 10.5), 2.2, 14.0, false)


func _add_floor_sign(floor_index: int, base_y: float) -> void:
	var sign := Label3D.new()
	sign.name = "FloorSign_F%d" % (floor_index + 1)
	sign.text = "%d. POSCHODIE\nUČEBNE F%d-01 – F%d-08" % [floor_index, floor_index + 1, floor_index + 1]
	sign.font_size = 42
	sign.pixel_size = 0.005
	sign.outline_size = 7
	sign.modulate = Color("a9c5ba")
	sign.position = Vector3(-2.82, base_y + 2.35, 10.5)
	sign.rotation.y = PI * 0.5
	add_child(sign)


func _add_upper_patrol_marker(floor_index: int, marker_index: int, marker_position: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = "TeacherPatrol_F%d_%02d" % [floor_index + 1, marker_index + 1]
	marker.position = marker_position
	marker.add_to_group("teacher_patrol_marker")
	marker.set_meta("floor_index", floor_index)
	marker.set_meta("zone_id", "floor_%d_classrooms" % floor_index)
	marker.set_meta("room_id", "F%d_%s_%d" % [floor_index + 1, "West" if marker_position.x < 0.0 else "East", marker_index + 1])
	add_child(marker)
	_upper_patrol_points.append(marker_position)


func _build_stairs() -> void:
	for stair_data in [["South", 0.0, false], ["North", PI, true]]:
		var root := Node3D.new()
		var prefix := str(stair_data[0])
		root.name = "%sStairTower" % prefix
		root.rotation.y = float(stair_data[1])
		add_child(root)
		_build_stair_tower(root, prefix, bool(stair_data[2]))
		for from_floor in range(FLOOR_COUNT - 1):
			_build_stair(root, prefix, from_floor)


func _build_stair_tower(parent: Node3D, prefix: String, has_ground_connector: bool) -> void:
	var wall := Color("343b3e")
	var tower_center := Vector3((STAIR_TOWER_MIN_X + STAIR_TOWER_MAX_X) * 0.5, -0.1, (STAIR_TOWER_MIN_Z + STAIR_TOWER_MAX_Z) * 0.5)
	_box("%sStairTowerGroundFloor" % prefix, tower_center, Vector3(STAIR_TOWER_MAX_X - STAIR_TOWER_MIN_X, 0.2, STAIR_TOWER_MAX_Z - STAIR_TOWER_MIN_Z), Color("25282a"), true, 0.0, parent)
	for floor_index in FLOOR_COUNT:
		var base_y := floor_index * FLOOR_HEIGHT
		var window_width := 5.4
		var edge_depth := (STAIR_TOWER_MAX_Z - STAIR_TOWER_MIN_Z - window_width) * 0.5
		var window_center_z := (STAIR_TOWER_MIN_Z + STAIR_TOWER_MAX_Z) * 0.5
		if has_ground_connector and floor_index == 0:
			var connector_width := 3.6
			var connector_edge := (STAIR_TOWER_MAX_Z - STAIR_TOWER_MIN_Z - connector_width) * 0.5
			var connector_offset := connector_width * 0.5 + connector_edge * 0.5
			_box("NorthGymConnectorWallA", Vector3(STAIR_TOWER_MIN_X, 2.05, window_center_z - connector_offset), Vector3(0.3, 4.3, connector_edge), wall, true, 0.0, parent)
			_box("NorthGymConnectorWallB", Vector3(STAIR_TOWER_MIN_X, 2.05, window_center_z + connector_offset), Vector3(0.3, 4.3, connector_edge), wall, true, 0.0, parent)
			_box("NorthGymConnectorHeader", Vector3(STAIR_TOWER_MIN_X, 3.8, window_center_z), Vector3(0.3, 1.0, connector_width), wall, true, 0.0, parent)
		else:
			_box("%sStairTowerWestWall_F%d" % [prefix, floor_index + 1], Vector3(STAIR_TOWER_MIN_X, base_y + 2.05, window_center_z), Vector3(0.3, 4.3, STAIR_TOWER_MAX_Z - STAIR_TOWER_MIN_Z), wall, true, 0.0, parent)
		_build_stair_exterior_wall(parent, prefix, floor_index, base_y, wall, has_ground_connector)
		_box("%sStairTowerEastBefore_F%d" % [prefix, floor_index + 1], Vector3(STAIR_TOWER_MAX_X, base_y + 2.05, STAIR_TOWER_MIN_Z + edge_depth * 0.5), Vector3(0.3, 4.3, edge_depth), wall, true, 0.0, parent)
		_box("%sStairTowerEastAfter_F%d" % [prefix, floor_index + 1], Vector3(STAIR_TOWER_MAX_X, base_y + 2.05, STAIR_TOWER_MAX_Z - edge_depth * 0.5), Vector3(0.3, 4.3, edge_depth), wall, true, 0.0, parent)
		_box("%sStairTowerEastHeader_F%d" % [prefix, floor_index + 1], Vector3(STAIR_TOWER_MAX_X, base_y + 3.75, window_center_z), Vector3(0.3, 0.9, window_width), wall, true, 0.0, parent)
		_box("%sStairTowerEastSill_F%d" % [prefix, floor_index + 1], Vector3(STAIR_TOWER_MAX_X, base_y + 0.45, window_center_z), Vector3(0.3, 0.9, window_width), wall, true, 0.0, parent)
		_build_window_bank("%sStairTowerWindow" % prefix, "F%d" % (floor_index + 1), STAIR_TOWER_MAX_X, STAIR_TOWER_MAX_X - 0.12, window_center_z, window_width, base_y + 0.9, base_y + 3.3, 3, parent)
		_add_ceiling_light("%sStairTowerLight_F%d" % [prefix, floor_index + 1], Vector3((STAIR_TOWER_MIN_X + STAIR_TOWER_MAX_X) * 0.5, base_y + 3.82, window_center_z), 1.35, 8.0, false, true, parent)
	for floor_index in range(1, FLOOR_COUNT):
		var floor_y := floor_index * FLOOR_HEIGHT
		var opening_north := STAIR_FLIGHT_A_Z - STAIR_FLIGHT_WIDTH * 0.5
		var opening_south := STAIR_FLIGHT_B_Z + STAIR_FLIGHT_WIDTH * 0.5
		_add_stair_guard(parent, "%sStairwellNorthGuard_F%d" % [prefix, floor_index + 1], Vector3(STAIR_START_X, floor_y, opening_north), Vector3(STAIR_LANDING_EAST_X, floor_y, opening_north))
		_add_stair_guard(parent, "%sStairwellSouthGuard_F%d" % [prefix, floor_index + 1], Vector3(STAIR_START_X, floor_y, opening_south), Vector3(STAIR_LANDING_EAST_X, floor_y, opening_south))
		_add_stair_guard(parent, "%sStairwellEastGuard_F%d" % [prefix, floor_index + 1], Vector3(STAIR_LANDING_EAST_X, floor_y, opening_north), Vector3(STAIR_LANDING_EAST_X, floor_y, opening_south))
	_box("%sStairTowerRoof" % prefix, Vector3((STAIR_TOWER_MIN_X + STAIR_TOWER_MAX_X) * 0.5, FLOOR_COUNT * FLOOR_HEIGHT - 0.1, (STAIR_TOWER_MIN_Z + STAIR_TOWER_MAX_Z) * 0.5), Vector3(STAIR_TOWER_MAX_X - STAIR_TOWER_MIN_X, 0.2, STAIR_TOWER_MAX_Z - STAIR_TOWER_MIN_Z), Color("17191b"), true, 0.0, parent)


func _build_stair_exterior_wall(parent: Node3D, prefix: String, floor_index: int, base_y: float, wall: Color, has_exit: bool) -> void:
	if not has_exit or floor_index > 0:
		_box("%sStairTowerExteriorWall_F%d" % [prefix, floor_index + 1], Vector3((STAIR_TOWER_MIN_X + STAIR_TOWER_MAX_X) * 0.5, base_y + 2.05, STAIR_TOWER_MAX_Z), Vector3(STAIR_TOWER_MAX_X - STAIR_TOWER_MIN_X, 4.3, 0.3), wall, true, 0.0, parent)
		return
	var exit_center_x := (STAIR_TOWER_MIN_X + STAIR_TOWER_MAX_X) * 0.5
	var segment_width := (STAIR_TOWER_MAX_X - STAIR_TOWER_MIN_X - 2.0) * 0.5
	var offset := 1.0 + segment_width * 0.5
	_box("NorthExitWallLeft", Vector3(exit_center_x - offset, 2.05, STAIR_TOWER_MAX_Z), Vector3(segment_width, 4.3, 0.3), wall, true, 0.0, parent)
	_box("NorthExitWallRight", Vector3(exit_center_x + offset, 2.05, STAIR_TOWER_MAX_Z), Vector3(segment_width, 4.3, 0.3), wall, true, 0.0, parent)
	_box("NorthExitWallHeader", Vector3(exit_center_x, 3.55, STAIR_TOWER_MAX_Z), Vector3(2.0, 1.3, 0.3), wall, true, 0.0, parent)


func _build_stair(parent: Node3D, prefix: String, from_floor: int) -> void:
	var base_y := from_floor * FLOOR_HEIGHT
	var stair := Node3D.new()
	stair.name = "%sSchoolStair_%d_to_%d" % [prefix, from_floor + 1, from_floor + 2]
	stair.add_to_group("school_stair")
	stair.set_meta("from_floor_index", from_floor)
	stair.set_meta("to_floor_index", from_floor + 1)
	parent.add_child(stair)
	var run := STAIR_END_X - STAIR_START_X
	var rise := FLOOR_HEIGHT * 0.5
	var angle := atan(rise / run)
	var collision_overlap := 0.9
	var collision_run := run + collision_overlap
	var collision_rise := rise + collision_overlap * rise / run
	var collision_length := sqrt(collision_run * collision_run + collision_rise * collision_rise)
	var collision_center_x := (STAIR_START_X + STAIR_END_X + collision_overlap) * 0.5
	_add_stair_collision(stair, "FlightA", Vector3(collision_center_x, base_y + collision_rise * 0.5 - 0.06, STAIR_FLIGHT_A_Z), Vector3(collision_length, 0.12, STAIR_FLIGHT_WIDTH), Vector3(0, 0, angle))
	_add_stair_collision(stair, "FlightB", Vector3(collision_center_x, base_y + rise * 1.5 - (collision_rise - rise) * 0.5 - 0.06, STAIR_FLIGHT_B_Z), Vector3(collision_length, 0.12, STAIR_FLIGHT_WIDTH), Vector3(0, 0, -angle))
	var step_tread := run / STAIR_STEPS_PER_FLIGHT
	var step_rise := rise / STAIR_STEPS_PER_FLIGHT
	for step_index in STAIR_STEPS_PER_FLIGHT:
		var step_height := step_rise * (step_index + 1)
		_box("FlightA_Step_%02d" % (step_index + 1), Vector3(STAIR_START_X + step_tread * (step_index + 0.5), base_y + step_height * 0.5, STAIR_FLIGHT_A_Z), Vector3(step_tread + 0.01, step_height, STAIR_FLIGHT_WIDTH), Color("727779"), false, 0.0, stair)
		_box("FlightB_Step_%02d" % (step_index + 1), Vector3(STAIR_END_X - step_tread * (step_index + 0.5), base_y + rise + step_height * 0.5, STAIR_FLIGHT_B_Z), Vector3(step_tread + 0.01, step_height, STAIR_FLIGHT_WIDTH), Color("727779"), false, 0.0, stair)
	var landing_north := STAIR_FLIGHT_A_Z - STAIR_FLIGHT_WIDTH * 0.5
	var landing_south := STAIR_FLIGHT_B_Z + STAIR_FLIGHT_WIDTH * 0.5
	var landing_west := STAIR_END_X
	var landing_east := STAIR_LANDING_EAST_X
	var landing_center_x := (landing_west + landing_east) * 0.5
	var landing_center_z := (STAIR_FLIGHT_A_Z + STAIR_FLIGHT_B_Z) * 0.5
	var landing_collision_size := Vector3(landing_east - landing_west, 0.04, landing_south - landing_north)
	var landing_flat_start := STAIR_END_X + 0.75
	_add_stair_collision(stair, "MidLanding", Vector3((landing_flat_start + landing_east) * 0.5, base_y + rise - 0.09, landing_center_z), Vector3(landing_east - landing_flat_start, 0.18, landing_collision_size.z), Vector3.ZERO)
	_box("MidLandingSurface", Vector3(landing_center_x, base_y + rise - 0.09, landing_center_z), Vector3(landing_collision_size.x, 0.18, landing_collision_size.z), Color("727779"), false, 0.0, stair)
	_box("TopLanding", Vector3((STAIR_TOWER_MIN_X + STAIR_START_X) * 0.5, base_y + FLOOR_HEIGHT + 0.005, (STAIR_FLIGHT_A_Z + STAIR_FLIGHT_B_Z) * 0.5), Vector3(STAIR_START_X - STAIR_TOWER_MIN_X, 0.01, STAIR_FLIGHT_B_Z - STAIR_FLIGHT_A_Z + STAIR_FLIGHT_WIDTH), Color("727779"), false, 0.0, stair)
	_add_stair_flight_rail(stair, "FlightARail", STAIR_FLIGHT_A_Z - STAIR_FLIGHT_WIDTH * 0.5, base_y, rise, false)
	_add_stair_flight_rail(stair, "FlightAInnerRail", STAIR_FLIGHT_A_Z + STAIR_FLIGHT_WIDTH * 0.5, base_y, rise, false, true)
	_add_stair_flight_rail(stair, "FlightBRail", STAIR_FLIGHT_B_Z + STAIR_FLIGHT_WIDTH * 0.5, base_y + rise, rise, true)
	_add_stair_flight_rail(stair, "FlightBInnerRail", STAIR_FLIGHT_B_Z - STAIR_FLIGHT_WIDTH * 0.5, base_y + rise, rise, true, true)
	_add_stair_guard(stair, "LandingNorthGuard", Vector3(STAIR_END_X, base_y + rise, landing_north), Vector3(landing_east, base_y + rise, landing_north))
	_add_stair_guard(stair, "LandingSouthGuard", Vector3(STAIR_END_X, base_y + rise, landing_south), Vector3(landing_east, base_y + rise, landing_south))
	_add_stair_guard(stair, "LandingGuard", Vector3(landing_east, base_y + rise, landing_north), Vector3(landing_east, base_y + rise, landing_south))
	var nav_ramp_x := STAIR_END_X - 0.7
	var nav_landing_x := STAIR_END_X + 0.25
	_add_stair_landing_navigation(stair, base_y + rise + 0.3, landing_north + 0.45, landing_south - 0.45, nav_landing_x, landing_east - 0.45)
	_add_stair_navigation_link(stair, "FlightALink", Vector3(STAIR_START_X - 0.35, base_y + 0.05, STAIR_FLIGHT_A_Z), Vector3(nav_ramp_x, base_y + rise + 0.05, STAIR_FLIGHT_A_Z))
	_add_stair_navigation_link(stair, "LandingInLink", Vector3(nav_ramp_x, base_y + rise + 0.05, STAIR_FLIGHT_A_Z), Vector3(nav_landing_x, base_y + rise + 0.3, STAIR_FLIGHT_A_Z))
	_add_stair_navigation_link(stair, "LandingOutLink", Vector3(nav_landing_x, base_y + rise + 0.3, STAIR_FLIGHT_B_Z), Vector3(nav_ramp_x, base_y + rise + 0.85, STAIR_FLIGHT_B_Z))
	_add_stair_navigation_link(stair, "FlightBLink", Vector3(nav_ramp_x, base_y + rise + 0.85, STAIR_FLIGHT_B_Z), Vector3(STAIR_START_X - 0.35, base_y + FLOOR_HEIGHT + 0.05, STAIR_FLIGHT_B_Z))
	_add_stair_access_marker(stair, "BottomAccess", from_floor, Vector3(1.25, base_y + 0.05, STAIR_FLIGHT_A_Z))
	_add_stair_access_marker(stair, "TopAccess", from_floor + 1, Vector3(1.25, base_y + FLOOR_HEIGHT + 0.05, STAIR_FLIGHT_B_Z))


func _add_stair_flight_rail(parent: Node3D, rail_name: String, rail_z: float, bottom_y: float, rise: float, reverse: bool, open_at_landing := false) -> void:
	var run := STAIR_END_X - STAIR_START_X
	var rail_end_x := STAIR_END_X - (1.25 if open_at_landing else 0.0)
	var end_progress := (rail_end_x - STAIR_START_X) / run
	var start_y := bottom_y + (rise if reverse else 0.0)
	var end_y := bottom_y + (rise * (1.0 - end_progress) if reverse else rise * end_progress)
	var rail_delta := Vector2(rail_end_x - STAIR_START_X, end_y - start_y)
	var rail_position := Vector3((STAIR_START_X + rail_end_x) * 0.5, (start_y + end_y) * 0.5 + 0.95, rail_z)
	var rail := _box(rail_name, rail_position, Vector3(rail_delta.length(), 0.06, 0.06), Color("273235"), not open_at_landing, 0.0, parent)
	rail.rotation.z = rail_delta.angle()
	if open_at_landing:
		var collision_end_progress := 0.4
		var collision_end := Vector3(lerpf(STAIR_START_X, rail_end_x, collision_end_progress), lerpf(start_y, end_y, collision_end_progress) + 0.95, rail_z)
		var collision_start := Vector3(STAIR_START_X, start_y + 0.95, rail_z)
		var collision_delta := collision_end - collision_start
		_add_stair_collision(parent, "%sCollision" % rail_name, (collision_start + collision_end) * 0.5, Vector3(collision_delta.length(), 0.06, 0.06), Vector3(0, 0, atan2(collision_delta.y, collision_delta.x)))
	for post_index in 6:
		var progress := post_index / 5.0
		var post_x := lerpf(STAIR_START_X, rail_end_x, progress)
		var post_y := lerpf(start_y, end_y, progress)
		_box("%sPost_%02d" % [rail_name, post_index + 1], Vector3(post_x, post_y + 0.475, rail_z), Vector3(0.05, 0.95, 0.05), Color("273235"), not open_at_landing or progress <= 0.4, 0.0, parent)


func _add_stair_guard(parent: Node3D, guard_name: String, start: Vector3, end: Vector3) -> void:
	var delta := end - start
	var length := Vector2(delta.x, delta.z).length()
	var rail_size := Vector3(length, 0.06, 0.06) if absf(delta.x) > absf(delta.z) else Vector3(0.06, 0.06, length)
	_box(guard_name, (start + end) * 0.5 + Vector3.UP * 0.95, rail_size, Color("273235"), true, 0.0, parent)
	_box("%sMidRail" % guard_name, (start + end) * 0.5 + Vector3.UP * 0.5, rail_size, Color("273235"), true, 0.0, parent)
	var span_count := ceili(length / 0.9)
	for post_index in span_count + 1:
		_box("%sPost_%02d" % [guard_name, post_index + 1], start.lerp(end, post_index / float(span_count)) + Vector3.UP * 0.475, Vector3(0.05, 0.95, 0.05), Color("273235"), true, 0.0, parent)


func _add_stair_collision(parent: Node3D, body_name: String, body_position: Vector3, size: Vector3, body_rotation: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = body_position
	body.rotation = body_rotation
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _add_stair_landing_navigation(parent: Node3D, navigation_y: float, north_z: float, south_z: float, west_x: float, east_x: float) -> void:
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.vertices = PackedVector3Array([
		Vector3(west_x, navigation_y, north_z),
		Vector3(west_x, navigation_y, south_z),
		Vector3(east_x, navigation_y, south_z),
		Vector3(east_x, navigation_y, north_z),
	])
	navigation_mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var region := NavigationRegion3D.new()
	region.name = "LandingNavigationRegion"
	region.navigation_mesh = navigation_mesh
	parent.add_child(region)


func _add_stair_navigation_link(parent: Node3D, link_name: String, start: Vector3, end: Vector3) -> void:
	var link := NavigationLink3D.new()
	link.name = link_name
	link.start_position = start
	link.end_position = end
	link.bidirectional = true
	parent.add_child(link)


func _add_stair_access_marker(parent: Node3D, marker_name: String, floor_index: int, marker_position: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = marker_position
	marker.add_to_group("school_stair_access")
	marker.set_meta("floor_index", floor_index)
	parent.add_child(marker)


func _build_exterior_wall_row(side: float, row_index: int, row_z: float, color: Color, has_window: bool) -> void:
	var side_name := "West" if side < 0.0 else "East"
	var wall_x := side * 23.0
	var wall_center_z := row_z + (0.25 if row_index == ROOM_ROWS.size() - 1 else -0.25 if row_index == 0 else 0.0)
	var wall_width := ROOM_HALF_Z * 2.0 + (0.5 if row_index == 0 or row_index == ROOM_ROWS.size() - 1 else 0.0)
	if not has_window:
		_box("%sExteriorWall_%d" % [side_name, row_index], Vector3(wall_x, 2.05, wall_center_z), Vector3(0.3, 4.3, wall_width), color)
		return
	var side_width := (wall_width - EXTERIOR_WINDOW_WIDTH) * 0.5
	_box("%sExteriorWindowBefore_%d" % [side_name, row_index], Vector3(wall_x, 2.05, wall_center_z - EXTERIOR_WINDOW_WIDTH * 0.5 - side_width * 0.5), Vector3(0.3, 4.3, side_width), color)
	_box("%sExteriorWindowAfter_%d" % [side_name, row_index], Vector3(wall_x, 2.05, wall_center_z + EXTERIOR_WINDOW_WIDTH * 0.5 + side_width * 0.5), Vector3(0.3, 4.3, side_width), color)
	_box("%sExteriorWindowSill_%d" % [side_name, row_index], Vector3(wall_x, WINDOW_BOTTOM * 0.5, wall_center_z), Vector3(0.3, WINDOW_BOTTOM, EXTERIOR_WINDOW_WIDTH), color)
	var header_height := 4.2 - WINDOW_TOP
	_box("%sExteriorWindowHeader_%d" % [side_name, row_index], Vector3(wall_x, WINDOW_TOP + header_height * 0.5, wall_center_z), Vector3(0.3, header_height, EXTERIOR_WINDOW_WIDTH), color)


func _build_corridor_wall_row(side: float, row_index: int, row_z: float, color: Color, has_window: bool) -> void:
	var side_name := "West" if side < 0.0 else "East"
	var wall_x := side * 3.0
	_box("%sCorridorWallA_%d" % [side_name, row_index], Vector3(wall_x, 2.05, row_z - 5.2), Vector3(0.25, 4.3, 8.6), color)
	_box("%sDoorHeader_%d" % [side_name, row_index], Vector3(wall_x, 3.55, row_z), Vector3(0.25, 1.3, 1.8), color)
	if not has_window:
		_box("%sCorridorWallB_%d" % [side_name, row_index], Vector3(wall_x, 2.05, row_z + 5.2), Vector3(0.25, 4.3, 8.6), color)
		return
	var edge_width := 8.6 - CORRIDOR_WINDOW_WIDTH
	var window_center_z := row_z + CORRIDOR_WINDOW_CENTER_OFFSET_Z
	_box("%sCorridorWindowBefore_%d" % [side_name, row_index], Vector3(wall_x, 2.05, row_z + 0.9 + edge_width * 0.25), Vector3(0.25, 4.3, edge_width * 0.5), color)
	_box("%sCorridorWindowAfter_%d" % [side_name, row_index], Vector3(wall_x, 2.05, row_z + 9.5 - edge_width * 0.25), Vector3(0.25, 4.3, edge_width * 0.5), color)
	_box("%sCorridorWindowSill_%d" % [side_name, row_index], Vector3(wall_x, WINDOW_BOTTOM * 0.5, window_center_z), Vector3(0.25, WINDOW_BOTTOM, CORRIDOR_WINDOW_WIDTH), color)
	var header_height := 4.2 - WINDOW_TOP
	_box("%sCorridorWindowHeader_%d" % [side_name, row_index], Vector3(wall_x, WINDOW_TOP + header_height * 0.5, window_center_z), Vector3(0.25, header_height, CORRIDOR_WINDOW_WIDTH), color)


func _build_corridor() -> void:
	for corridor_index in ROOM_ROWS.size():
		_box("CorridorFloor_%02d" % (corridor_index + 1), Vector3(0, 0.015, ROOM_ROWS[corridor_index]), Vector3(5.7, 0.03, 19.1), Color("1d2426"), false)
	for z in range(-36, 38, 4):
		_box("CorridorTile_%d" % z, Vector3(0, 0.035, z), Vector3(5.6, 0.012, 0.055), Color("394044"), false)
	for side_value in [-1.0, 1.0]:
		var side := float(side_value)
		var side_name := "West" if side < 0.0 else "East"
		var locker_positions := [-36.0, -22.0, 0.0, 24.0, 36.0]
		for locker_index in locker_positions.size():
			_box("%sLockerBank_%d" % [side_name, locker_index], Vector3(side * 2.72, 1.15, locker_positions[locker_index]), Vector3(0.38, 2.3, 2.5), Color("35464d"))
	var directory := Label3D.new()
	directory.name = "SchoolDirectory"
	directory.text = "NOČNÁ ŠKOLA\nPRÍZEMIE: PREDMETOVÉ UČEBNE, KABINET A TELOCVIČŇA\n1. POSCHODIE: KNIŽNICA A LABORATÓRIÁ\n2. POSCHODIE: POLYTECHNICKÁ DIELŇA, INFORMATIKA A ARCHÍV"
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
		var subject_id := str(placement["subject"])
		var subject := load("res://data/homework/%s.tres" % subject_id) as SubjectData if Engine.is_editor_hint() else SchoolGameManager.get_subject(subject_id)
		if subject == null:
			push_error("Chýbajú údaje predmetu %s." % subject_id)
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
	_build_classroom_windows(subject.subject_id, center, side, room)
	_add_board_label(subject.display_name, subject.room_code, center, room)

	var desk_index := 0
	for local_z in [-2.2, 2.8]:
		for local_x in [-4.2, 0.0, 4.2]:
			desk_index += 1
			_build_student_desk(subject.subject_id, desk_index, center + Vector3(local_x, 0, local_z), subject.accent_color, room)
	var teacher_desk_position := center + Vector3(-4.5, 0, -6.6)
	_build_teacher_desk(subject.subject_id, teacher_desk_position, subject.accent_color, room)
	_build_subject_props(subject.subject_id, center, subject.accent_color, room)
	CLASSROOM_DECORATOR.decorate(room, center, subject.subject_id, subject.accent_color, side)
	if not Engine.is_editor_hint():
		_place_homework_station(subject, teacher_desk_position + Vector3(0, 1.0, 0), room)
	_place_door(subject.subject_id, Vector3(side * 3.0, 0, center.z), side, room, index, false)
	_place_room_sign("%s  %s" % [subject.room_code, subject.display_name], Vector3(side * 2.82, 3.03, center.z), side, room)


func _build_classroom_windows(subject_id: String, center: Vector3, side: float, parent: Node3D) -> void:
	_build_window_bank("CorridorWindow", subject_id, side * 3.0, side * 3.22, center.z + CORRIDOR_WINDOW_CENTER_OFFSET_Z, CORRIDOR_WINDOW_WIDTH, WINDOW_BOTTOM, WINDOW_TOP, 3, parent)
	var exterior_center_z := center.z + (0.25 if center.z == ROOM_ROWS[-1] else -0.25 if center.z == ROOM_ROWS[0] else 0.0)
	_build_window_bank("ExteriorWindow", subject_id, side * 23.0, side * 22.88, exterior_center_z, EXTERIOR_WINDOW_WIDTH, WINDOW_BOTTOM, WINDOW_TOP, 6, parent)


func _build_window_bank(prefix: String, subject_id: String, glass_x: float, frame_x: float, center_z: float, width: float, bottom: float, top: float, pane_count: int, parent: Node3D) -> void:
	var pane_height := top - bottom
	var pane_width := width / pane_count
	for pane_index in pane_count:
		var pane_z := center_z - width * 0.5 + pane_width * (pane_index + 0.5)
		_add_window_pane("%sGlass_%s_%d" % [prefix, subject_id, pane_index + 1], Vector3(glass_x, bottom + pane_height * 0.5, pane_z), Vector3(0.06, pane_height - 0.12, pane_width - 0.12), parent)
	var frame_color := Color("7d8584")
	for rail_index in 3:
		var rail_y := bottom + pane_height * rail_index * 0.5
		_box("%sRail_%s_%d" % [prefix, subject_id, rail_index], Vector3(frame_x, rail_y, center_z), Vector3(0.14, 0.1, width + 0.12), frame_color, false, 0.0, parent)
	for mullion_index in pane_count + 1:
		var mullion_z := center_z - width * 0.5 + pane_width * mullion_index
		_box("%sMullion_%s_%d" % [prefix, subject_id, mullion_index], Vector3(frame_x, bottom + pane_height * 0.5, mullion_z), Vector3(0.14, pane_height, 0.1), frame_color, false, 0.0, parent)


func _add_window_pane(label: String, pane_position: Vector3, size: Vector3, parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.add_to_group("classroom_window_glass")
	body.position = pane_position
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Glass"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _window_glass_material()
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(mesh_instance)
	body.add_child(collision)
	parent.add_child(body)


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
	if Engine.is_editor_hint():
		for index in 8:
			var data := load("res://data/teachers/teacher_%d.tres" % (index + 1)) as TeacherData
			if data == null:
				continue
			var subject := load("res://data/homework/%s.tres" % data.subject_id) as SubjectData
			var color := subject.accent_color.darkened(0.1) if subject != null else Color("315b68")
			var column := index % 4
			var row := index / 4
			var home := Vector3(8.2 + column * 3.0, 0.05, 24.0 + row * 7.0)
			_spawn_teacher(data, home, PackedVector3Array(), color, "Teacher_%02d_%s" % [index + 1, data.subject_id], parent)
		var headmistress := load("res://data/teachers/headmistress.tres") as TeacherData
		if headmistress != null:
			_spawn_teacher(headmistress, Vector3(8.2, 0.05, 35.0), PackedVector3Array(), Color("552f45"), "Headmistress_Zuzana_Cizmarikova", parent)
		return
	var subjects := SchoolGameManager.get_subjects()
	var teachers: Array[TeacherData] = []
	for subject in subjects:
		var data := SchoolGameManager.get_teacher_data(subject.subject_id)
		if data != null:
			teachers.append(data)
	var gym_teacher := SchoolGameManager.get_teacher_data("telocvik")
	if gym_teacher != null:
		teachers.append(gym_teacher)
	for index in teachers.size():
		var data := teachers[index]
		var subject := SchoolGameManager.get_subject(data.subject_id)
		var column := index % 4
		var row := index / 4
		var home := Vector3(8.2 + column * 3.0, 0.05, 24.0 + row * 7.0)
		var color := subject.accent_color.darkened(0.1) if subject != null else Color("315b68")
		_spawn_teacher(data, home, _school_patrol(index), color, "Teacher_%02d_%s" % [index + 1, data.subject_id], parent)
	var headmistress := SchoolGameManager.get_headmistress_data()
	if headmistress != null:
		_spawn_teacher(headmistress, Vector3(8.2, 0.05, 35.0), _school_patrol(teachers.size()), Color("552f45"), "Headmistress_Zuzana_Cizmarikova", parent)


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
	if Engine.is_editor_hint():
		teacher.editor_description = "Náhľad skutočnej štartovacej pozície: %s (%s). AI je v editore vypnutá; údaje a model uprav v %s." % [data.display_name, data.subject_id, data.resource_path]
		teacher.set_meta("teacher_data_path", data.resource_path)
		teacher.set_meta("home_position", home)
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
	base.append_array(_upper_patrol_points)
	var patrol := PackedVector3Array()
	var stride := 1 + posmod(offset * 2, base.size() - 1)
	while _greatest_common_divisor(stride, base.size()) != 1:
		stride = 1 if stride + 1 >= base.size() else stride + 1
	for index in base.size():
		patrol.append(base[(offset + index * stride) % base.size()])
	return patrol


func _greatest_common_divisor(first: int, second: int) -> int:
	var a := absi(first)
	var b := absi(second)
	while b != 0:
		var remainder := a % b
		a = b
		b = remainder
	return a


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
	var exit_center := Vector3(-(STAIR_TOWER_MIN_X + STAIR_TOWER_MAX_X) * 0.5, 0, -STAIR_TOWER_MAX_Z)
	door.position = exit_center + Vector3(0.9, 0, 0.15)
	door.set("open_angle_degrees", -105.0)
	door.set("morning_exit", true)
	door.set("teacher_can_open", false)
	add_child(door)
	var frame := Color("171a1b")
	_box("ExitDoorFrameLeft", exit_center + Vector3(-0.96, 1.45, 0.17), Vector3(0.12, 2.9, 0.34), frame, false)
	_box("ExitDoorFrameRight", exit_center + Vector3(0.96, 1.45, 0.17), Vector3(0.12, 2.9, 0.34), frame, false)
	_box("ExitDoorFrameTop", exit_center + Vector3(0, 2.96, 0.17), Vector3(2.04, 0.12, 0.34), frame, false)
	var sign := Label3D.new()
	sign.name = "ExitSign"
	sign.text = "VÝCHOD"
	sign.font_size = 36
	sign.pixel_size = 0.005
	sign.outline_size = 7
	sign.modulate = Color("8fc7a7")
	sign.position = exit_center + Vector3(0, 3.3, 0.19)
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
			for x_index in 2:
				for z_index in 2:
					var light_position := Vector3(center_x - 4.0 + x_index * 8.0, 3.82, row_z - 4.5 + z_index * 9.0)
					_add_ceiling_light("ClassroomLight_%d_%s_%d_%d" % [row_index, str(side_value), x_index, z_index], light_position, 1.35, 8.8, false)


func _add_ceiling_light(label: String, light_position: Vector3, energy: float, light_range: float, shadows: bool, create_fixture := true, parent: Node3D = null) -> void:
	if create_fixture:
		var fixture := _box("%sFixture" % label, light_position + Vector3(0, 0.08, 0), Vector3(2.6, 0.08, 0.34), Color("c6d1c6"), false, 2.1, parent)
		fixture.add_to_group("school_light_fixtures")
	var light := OmniLight3D.new()
	light.name = label
	light.position = light_position - Vector3(0, 0.22, 0)
	light.light_color = Color("c5d3c5")
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = shadows
	light.add_to_group("school_lights")
	var target: Node3D = parent if parent != null else self
	target.add_child(light)


func _build_navigation() -> void:
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.agent_height = 2.0
	navigation_mesh.agent_radius = 0.5
	navigation_mesh.agent_max_climb = 0.25
	navigation_mesh.cell_size = 0.25
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


func _update_daylight(_game_time_seconds: float, progress: float) -> void:
	var dawn := smoothstep(0.72, 1.0, clampf(progress, 0.0, 1.0))
	_sun_light.light_energy = lerpf(0.04, 0.9, dawn)
	_sun_light.rotation_degrees.x = lerpf(-8.0, -38.0, dawn)
	var environment := _school_environment.environment
	environment.ambient_light_energy = lerpf(0.34, 0.68, dawn)
	environment.fog_light_color = Color(0.08, 0.1, 0.11, 1).lerp(Color("b9cddd"), dawn)
	environment.fog_light_energy = lerpf(0.35, 0.8, dawn)
	var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
	sky_material.sky_top_color = Color("010205").lerp(Color("4d84b3"), dawn)
	sky_material.sky_horizon_color = Color("06101a").lerp(Color("f2b272"), dawn)
	sky_material.ground_horizon_color = Color("05090c").lerp(Color("8d765f"), dawn)


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


func _window_glass_material() -> StandardMaterial3D:
	const KEY := "classroom_window_glass"
	if _materials.has(KEY):
		return _materials[KEY] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.22, 0.36, 0.44, 0.2)
	material.metallic = 0.15
	material.roughness = 0.12
	_materials[KEY] = material
	return material
