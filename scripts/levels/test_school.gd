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
const STAIR_START_Z := 12.5
const STAIR_END_Z := 18.5
const DESK_HIDING_SPOT_SCRIPT := preload("res://systems/hiding/desk_hiding_spot.gd")
const CLASSROOM_DECORATOR := preload("res://scripts/levels/classroom_decorator.gd")
const UPPER_ROOM_NAMES := {
	"classroom": "VŠEOBECNÁ UČEBŇA",
	"library": "KNIŽNICA",
	"science_lab": "PRÍRODOVEDNÉ LABORATÓRIUM",
	"study_room": "ŠTUDOVŇA",
	"art_room": "VÝTVARNÝ ATELIÉR",
	"computer_lab": "POČÍTAČOVÉ LABORATÓRIUM",
	"music_room": "HUDOBNÁ UČEBŇA",
	"archive": "ŠKOLSKÝ ARCHÍV",
}

@export var door_scene: PackedScene
@export var teacher_scene: PackedScene
@export var homework_station_scene: PackedScene

@onready var _school_environment: WorldEnvironment = $WorldEnvironment
@onready var _sun_light: DirectionalLight3D = $SunLight

var _materials: Dictionary = {}
var _upper_patrol_points := PackedVector3Array()


func _ready() -> void:
	add_to_group("school_navigation_source")
	_build_floor_markers()
	_build_shell()
	_build_upper_floors()
	_build_stairs()
	_build_corridor()
	_place_exit_door()
	_build_subject_classrooms()
	_build_kabinet()
	_build_lighting()
	_build_navigation()
	SchoolGameManager.blackout_changed.connect(_set_blackout)
	NightManager.time_updated.connect(_update_daylight)
	_update_daylight(NightManager.current_in_game_time, NightManager.get_night_progress())


func _build_shell() -> void:
	var wall := Color("34373a")
	_box("SchoolFloor", Vector3(0, -0.1, 0), Vector3(46, 0.2, 77), Color("25282a"))
	_box("NorthExteriorWallLeft", Vector3(-11.95, 2.05, -SCHOOL_HALF_Z), Vector3(22.1, 4.3, 0.3), wall)
	_box("NorthExteriorWallRight", Vector3(11.95, 2.05, -SCHOOL_HALF_Z), Vector3(22.1, 4.3, 0.3), wall)
	_box("NorthExitHeader", Vector3(0, 3.55, -SCHOOL_HALF_Z), Vector3(1.8, 1.3, 0.3), wall)
	_box("SouthExteriorWall", Vector3(0, 2.05, SCHOOL_HALF_Z), Vector3(46, 4.3, 0.3), wall)
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
	var room_kinds := ["classroom", "library", "science_lab", "study_room", "art_room", "computer_lab", "music_room", "archive"]
	for floor_index in range(1, FLOOR_COUNT):
		var base_y := floor_index * FLOOR_HEIGHT
		_build_floor_slab(floor_index, base_y)
		_box("UpperCorridorFloor_F%d" % (floor_index + 1), Vector3(0, base_y + 0.015, 0), Vector3(5.7, 0.03, 76.4), Color("20292b"), false)
		_box("UpperNorthWall_F%d" % (floor_index + 1), Vector3(0, base_y + 2.05, -SCHOOL_HALF_Z), Vector3(46, 4.3, 0.3), Color("34373a"))
		_box("UpperSouthWall_F%d" % (floor_index + 1), Vector3(0, base_y + 2.05, SCHOOL_HALF_Z), Vector3(46, 4.3, 0.3), Color("34373a"))
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
				_build_upper_room(floor_index, side, row_index, row_z, base_y, room_kinds[room_slot])
		_add_floor_sign(floor_index, base_y)
		for marker_index in 4:
			_add_upper_patrol_marker(floor_index, marker_index, Vector3(0, base_y + 0.05, -30.0 + marker_index * 20.0))
		for light_index in 8:
			_add_ceiling_light("UpperCorridorLight_F%d_%02d" % [floor_index + 1, light_index], Vector3(0, base_y + 3.82, -34.0 + light_index * 9.5), 1.2, 7.0, false)
	_box("SchoolRoof", Vector3(0, FLOOR_COUNT * FLOOR_HEIGHT - 0.1, 0), Vector3(46, 0.2, 77), Color("17191b"))


func _build_floor_slab(floor_index: int, base_y: float) -> void:
	var slab_y := base_y - 0.1
	var color := Color("25282a")
	_box("FloorSlab_F%d_North" % (floor_index + 1), Vector3(0, slab_y, -13.25), Vector3(46, 0.2, 50.5), color)
	_box("FloorSlab_F%d_South" % (floor_index + 1), Vector3(0, slab_y, 29.75), Vector3(46, 0.2, 17.5), color)
	_box("FloorSlab_F%d_WestBridge" % (floor_index + 1), Vector3(-13, slab_y, 16.5), Vector3(20, 0.2, 9), color)
	_box("FloorSlab_F%d_EastBridge" % (floor_index + 1), Vector3(13, slab_y, 16.5), Vector3(20, 0.2, 9), color)


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
	_add_ceiling_light("UpperRoomLight_%s" % room_id, center + Vector3(0, 3.82, 0), 1.25, 9.0, false)


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
	add_child(marker)
	_upper_patrol_points.append(marker_position)


func _build_stairs() -> void:
	for from_floor in range(FLOOR_COUNT - 1):
		_build_stair(from_floor)


func _build_stair(from_floor: int) -> void:
	var base_y := from_floor * FLOOR_HEIGHT
	var stair := Node3D.new()
	stair.name = "SchoolStair_%d_to_%d" % [from_floor + 1, from_floor + 2]
	stair.add_to_group("school_stair")
	stair.set_meta("from_floor_index", from_floor)
	stair.set_meta("to_floor_index", from_floor + 1)
	add_child(stair)
	var run := STAIR_END_Z - STAIR_START_Z
	var rise := FLOOR_HEIGHT * 0.5
	var angle := atan(rise / run)
	var length := sqrt(run * run + rise * rise)
	var flight_a := _box("FlightA", Vector3(-1.35, base_y + rise * 0.5, (STAIR_START_Z + STAIR_END_Z) * 0.5), Vector3(2.2, 0.22, length), Color("4a5052"), true, 0.0, stair)
	flight_a.rotation.x = -angle
	var flight_b := _box("FlightB", Vector3(1.35, base_y + rise * 1.5, (STAIR_START_Z + STAIR_END_Z) * 0.5), Vector3(2.2, 0.22, length), Color("4a5052"), true, 0.0, stair)
	flight_b.rotation.x = angle
	_box("MidLanding", Vector3(0, base_y + rise - 0.1, STAIR_END_Z + 0.8), Vector3(5.5, 0.2, 2.0), Color("4a5052"), true, 0.0, stair)
	_box("TopLanding", Vector3(0, base_y + FLOOR_HEIGHT - 0.1, STAIR_START_Z - 0.75), Vector3(5.5, 0.2, 2.5), Color("4a5052"), true, 0.0, stair)
	var rail_a := _box("FlightARail", Vector3(-2.5, base_y + rise * 0.5 + 0.62, (STAIR_START_Z + STAIR_END_Z) * 0.5), Vector3(0.12, 1.05, length), Color("252c2e"), true, 0.0, stair)
	rail_a.rotation.x = -angle
	var rail_b := _box("FlightBRail", Vector3(2.5, base_y + rise * 1.5 + 0.62, (STAIR_START_Z + STAIR_END_Z) * 0.5), Vector3(0.12, 1.05, length), Color("252c2e"), true, 0.0, stair)
	rail_b.rotation.x = angle
	var inner_rail_a := _box("FlightAInnerRail", Vector3(-0.2, base_y + rise * 0.5 + 0.62, (STAIR_START_Z + STAIR_END_Z) * 0.5), Vector3(0.12, 1.05, length), Color("252c2e"), true, 0.0, stair)
	inner_rail_a.rotation.x = -angle
	var inner_rail_b := _box("FlightBInnerRail", Vector3(0.2, base_y + rise * 1.5 + 0.62, (STAIR_START_Z + STAIR_END_Z) * 0.5), Vector3(0.12, 1.05, length), Color("252c2e"), true, 0.0, stair)
	inner_rail_b.rotation.x = angle
	_box("LandingGuard", Vector3(0, base_y + rise + 0.55, STAIR_END_Z + 1.75), Vector3(5.6, 1.2, 0.12), Color("252c2e"), true, 0.0, stair)
	_add_stair_navigation_link(stair, "FlightALink", Vector3(-1.35, base_y + 0.2, STAIR_START_Z), Vector3(-1.35, base_y + rise + 0.2, STAIR_END_Z))
	_add_stair_navigation_link(stair, "LandingLink", Vector3(-1.35, base_y + rise + 0.2, STAIR_END_Z + 0.35), Vector3(1.35, base_y + rise + 0.2, STAIR_END_Z + 0.35))
	_add_stair_navigation_link(stair, "FlightBLink", Vector3(1.35, base_y + rise + 0.2, STAIR_END_Z), Vector3(1.35, base_y + FLOOR_HEIGHT + 0.2, STAIR_START_Z))
	_add_stair_access_marker(stair, "BottomAccess", from_floor, Vector3(-1.35, base_y + 0.05, STAIR_START_Z - 0.5))
	_add_stair_access_marker(stair, "TopAccess", from_floor + 1, Vector3(1.35, base_y + FLOOR_HEIGHT + 0.05, STAIR_START_Z - 0.5))


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
	_box("CorridorFloor", Vector3(0, 0.015, 0), Vector3(5.7, 0.03, 76.4), Color("1d2426"), false)
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
	directory.text = "NOČNÁ ŠKOLA\nPRÍZEMIE: PREDMETOVÉ UČEBNE A KABINET\n1. POSCHODIE: KNIŽNICA A LABORATÓRIÁ\n2. POSCHODIE: ATELIÉR, INFORMATIKA A ARCHÍV"
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
	base.append_array(_upper_patrol_points)
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
			for x_index in 2:
				for z_index in 2:
					var light_position := Vector3(center_x - 4.0 + x_index * 8.0, 3.82, row_z - 4.5 + z_index * 9.0)
					_add_ceiling_light("ClassroomLight_%d_%s_%d_%d" % [row_index, str(side_value), x_index, z_index], light_position, 1.35, 8.8, false)


func _add_ceiling_light(label: String, light_position: Vector3, energy: float, light_range: float, shadows: bool) -> void:
	var fixture := _box("%sFixture" % label, light_position + Vector3(0, 0.08, 0), Vector3(2.6, 0.08, 0.34), Color("c6d1c6"), false, 2.1)
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
