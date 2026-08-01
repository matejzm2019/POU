@tool
class_name ClassroomDecorator
extends RefCounted

const FEATURES := [
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

const SUBJECT_IDENTITY := {
	"dejepis": {
		"board": "DEJEPIS  •  ČESKOSLOVENSKO\n1918 — 1993  /  demokracia a štátnosť",
		"poster": "MILAN RASTISLAV ŠTEFÁNIK\nVEDA • ODVAHA • SLOBODA",
		"notice": "HISTORICKÝ KRÚŽOK\nstreda 14:30  •  učebňa D-101",
	},
	"matematika": {
		"board": "MATEMATIKA  •  KVADRATICKÁ FUNKCIA\nf(x) = ax² + bx + c     D = b² − 4ac",
		"poster": "MATEMATIKA JE JAZYK VZOROV\npresnosť • dôkaz • riešenie",
		"notice": "MATEMATICKÁ OLYMPIÁDA\nprihlášky do piatka",
	},
	"slovensky_jazyk": {
		"board": "SLOVENSKÝ JAZYK A LITERATÚRA\nĽudovít Štúr  •  kodifikácia 1843",
		"poster": "SLOVENČINA NÁS SPÁJA\nČÍTAJ • TVOR • ROZPRÁVAJ",
		"notice": "ŠKOLSKÝ ČASOPIS\nredakčná rada v utorok",
	},
	"elektrotechnika": {
		"board": "ELEKTROTECHNIKA  •  OHMOV ZÁKON\nU = R · I     P = U · I     bezpečnosť nadovšetko",
		"poster": "POZOR — ELEKTRICKÉ ZARIADENIE\nodpoj • over • zaisti",
		"notice": "ODBORNÁ PRAX\nprineste si meracie protokoly",
	},
	"ekonomika": {
		"board": "EKONOMIKA  •  NÁKLADY A VÝNOSY\nvýsledok hospodárenia = výnosy − náklady",
		"poster": "ROZUMNÉ ROZHODNUTIA\nplánuj • počítaj • vyhodnocuj",
		"notice": "ŠTUDENTSKÁ FIRMA\nporada vo štvrtok 13:45",
	},
	"aplikovana_informatika": {
		"board": "APLIKOVANÁ INFORMATIKA\nALGORITMUS → PROGRAM → TEST → RIEŠENIE",
		"poster": "MYSLI, KÝM KLIKNEŠ\nheslo • záloha • overenie",
		"notice": "PROGRAMÁTORSKÝ KRÚŽOK\npondelok 15:00  •  učebňa AI-301",
	},
	"anglicky_jazyk": {
		"board": "ANGLICKÝ JAZYK  •  TODAY'S TOPIC\nPast simple vs. present perfect",
		"poster": "SPEAK • LISTEN • READ • WRITE\nKaždý deň o krok ďalej",
		"notice": "KONVERZAČNÝ KLUB\npiatok 14:00  •  everyone welcome",
	},
}

const FALLBACK_IDENTITY := {
	"board": "ODBORNÁ UČEBŇA\npoznanie • prax • spolupráca",
	"poster": "UČÍME SA PRE ŽIVOT",
	"notice": "OZNAMY TRIEDY",
}

const WHITEBOARD_SUBJECTS := [
	"elektrotechnika",
	"ekonomika",
	"aplikovana_informatika",
]

static var _material_cache := {}


static func decorate(room: Node3D, center: Vector3, subject_id: String, accent: Color, side: float) -> Node3D:
	if not is_instance_valid(room):
		push_error("ClassroomDecorator potrebuje platný uzol učebne.")
		return null
	if subject_id.is_empty() or is_zero_approx(side):
		push_error("ClassroomDecorator potrebuje subject_id a nenulovú stranu učebne.")
		return null

	var node_name := "ClassroomDecoration_%s" % subject_id
	var existing := room.get_node_or_null(node_name) as Node3D
	if existing != null:
		return existing

	var has_student_desks := room.find_child("*DeskTop_*", true, false) != null
	var has_teacher_desk := room.find_child("*TeacherDesk*", true, false) != null
	var old_board_label := room.find_child("BoardLabel", true, false) as Label3D
	if old_board_label != null:
		old_board_label.visible = false

	var root := Node3D.new()
	root.name = node_name
	root.position = center
	root.add_to_group("decorated_classroom")
	root.set_meta("subject_id", subject_id)
	root.set_meta("floor_index", 0)
	root.set_meta("decorator_version", 1)
	root.set_meta("features", PackedStringArray(FEATURES))
	room.add_child(root)

	var whiteboard := subject_id in WHITEBOARD_SUBJECTS
	var materials := _make_materials(accent, whiteboard)
	var wall_finish := _section(root, "WallFinish", "classroom_wall_trim")
	var teaching_wall := _section(root, "TeachingWall")
	var furniture := _section(root, "Furniture", "classroom_furniture")
	var storage := _section(root, "Storage", "classroom_storage")
	var displays := _section(root, "Displays", "classroom_notice")
	var utilities := _section(root, "Utilities")
	var ceiling := _section(root, "Ceiling", "classroom_ceiling_fixture")
	var floor_detail := _section(root, "FloorDetail")

	_build_wall_finish(wall_finish, side, materials)
	_build_teaching_wall(teaching_wall, subject_id, whiteboard, materials)
	_build_student_furniture(furniture, materials, has_student_desks)
	_build_teacher_furniture(furniture, materials, has_teacher_desk)
	_build_storage(storage, materials)
	_build_displays(displays, subject_id, whiteboard, materials)
	_build_utilities(utilities, side, materials)
	_build_ceiling(ceiling, materials)
	_build_floor_detail(floor_detail, materials)
	return root


static func _section(parent: Node3D, node_name: String, group := "") -> Node3D:
	var section := Node3D.new()
	section.name = node_name
	if not group.is_empty():
		section.add_to_group(group)
	parent.add_child(section)
	return section


static func _make_materials(accent: Color, whiteboard: bool) -> Dictionary:
	var muted_accent := Color("405b53").lerp(accent, 0.22)
	return {
		"accent": _material(muted_accent, 0.78),
		"band": _material(Color("355149"), 0.9),
		"board": _material(Color("ebe8de") if whiteboard else Color("213d35"), 0.84),
		"board_frame": _material(Color("a8aaa3"), 0.42, 0.5),
		"cork": _material(Color("8d6a49"), 0.96),
		"dark": _material(Color("303635"), 0.82, 0.18),
		"floor_line": _material(Color("777a72"), 1.0),
		"light": _material(Color("e8eddf"), 0.38, 0.0, 1.35),
		"metal": _material(Color("59625f"), 0.48, 0.5),
		"paper": _material(Color("e9e4d6"), 0.96),
		"wood": _material(Color("9b744d"), 0.8),
	}


static func _build_wall_finish(parent: Node3D, side: float, materials: Dictionary) -> void:
	var exterior_x := signf(side) * 9.82
	var corridor_x := -signf(side) * 9.82
	_box(parent, "FrontLowerBand", Vector3(0, 0.45, -9.12), Vector3(19.5, 0.86, 0.045), materials["band"])
	_box(parent, "BackLowerBand", Vector3(0, 0.45, 9.12), Vector3(19.5, 0.86, 0.045), materials["band"])
	_box(parent, "ExteriorLowerBand", Vector3(exterior_x, 0.45, 0), Vector3(0.045, 0.86, 18.55), materials["band"])
	_box(parent, "CorridorLowerBandA", Vector3(corridor_x, 0.45, -5.15), Vector3(0.045, 0.86, 8.25), materials["band"])
	_box(parent, "CorridorLowerBandB", Vector3(corridor_x, 0.45, 5.15), Vector3(0.045, 0.86, 8.25), materials["band"])
	_box(parent, "FrontTrim", Vector3(0, 0.92, -9.04), Vector3(19.5, 0.08, 0.12), materials["accent"])
	_box(parent, "BackTrim", Vector3(0, 0.92, 9.04), Vector3(19.5, 0.08, 0.12), materials["accent"])
	_box(parent, "ExteriorTrim", Vector3(exterior_x - signf(side) * 0.08, 0.92, 0), Vector3(0.12, 0.08, 18.55), materials["accent"])


static func _build_teaching_wall(parent: Node3D, subject_id: String, whiteboard: bool, materials: Dictionary) -> void:
	_box(parent, "BoardSurface", Vector3(0, 2.46, -9.04), Vector3(8.15, 1.78, 0.07), materials["board"])
	_box(parent, "BoardFrameTop", Vector3(0, 3.39, -8.98), Vector3(8.42, 0.09, 0.12), materials["board_frame"])
	_box(parent, "BoardFrameBottom", Vector3(0, 1.53, -8.98), Vector3(8.42, 0.09, 0.12), materials["board_frame"])
	_box(parent, "BoardFrameLeft", Vector3(-4.16, 2.46, -8.98), Vector3(0.09, 1.95, 0.12), materials["board_frame"])
	_box(parent, "BoardFrameRight", Vector3(4.16, 2.46, -8.98), Vector3(0.09, 1.95, 0.12), materials["board_frame"])
	_box(parent, "MarkerTray", Vector3(0, 1.46, -8.88), Vector3(8.55, 0.09, 0.32), materials["board_frame"])
	var identity: Dictionary = SUBJECT_IDENTITY.get(subject_id, FALLBACK_IDENTITY)
	_label(
		parent,
		"BoardWriting",
		str(identity["board"]),
		Vector3(0, 2.48, -8.94),
		Color("263237") if whiteboard else Color("d8dacd"),
		34,
		0.005
	)


static func _build_student_furniture(parent: Node3D, materials: Dictionary, existing_desks: bool) -> void:
	var desk_positions := [
		Vector3(-4.2, 0, -2.2),
		Vector3(0, 0, -2.2),
		Vector3(4.2, 0, -2.2),
		Vector3(-4.2, 0, 2.8),
		Vector3(0, 0, 2.8),
		Vector3(4.2, 0, 2.8),
	]
	var tops := []
	var modesty_panels := []
	var desk_legs := []
	var chair_seats := []
	var chair_backs := []
	var chair_legs := []
	var baskets := []
	var notebooks := []
	for index in desk_positions.size():
		var origin: Vector3 = desk_positions[index]
		tops.append(Transform3D(Basis.IDENTITY, origin + Vector3(0, 0.9, 0)))
		modesty_panels.append(Transform3D(Basis.IDENTITY, origin + Vector3(0, 0.61, 0.35)))
		chair_seats.append(Transform3D(Basis.IDENTITY, origin + Vector3(0, 0.47, 1.0)))
		chair_backs.append(Transform3D(Basis.IDENTITY, origin + Vector3(0, 0.9, 1.34)))
		baskets.append(Transform3D(Basis.IDENTITY, origin + Vector3(0, 0.66, 0)))
		notebooks.append(Transform3D(Basis.IDENTITY, origin + Vector3(-0.25, 0.99, -0.05)))
		for x in [-0.72, 0.72]:
			for z in [-0.34, 0.34]:
				desk_legs.append(Transform3D(Basis.IDENTITY, origin + Vector3(x, 0.43, z)))
		for x in [-0.36, 0.36]:
			for z in [0.75, 1.25]:
				chair_legs.append(Transform3D(Basis.IDENTITY, origin + Vector3(x, 0.22, z)))
		if not existing_desks:
			_collider(parent, "StudentDeskCollision_%02d" % (index + 1), origin + Vector3(0, 0.48, 0), Vector3(1.85, 0.96, 0.9))

	if not existing_desks:
		_multibox(parent, "StudentDeskTops", Vector3(1.8, 0.12, 0.82), materials["wood"], tops)
		_multibox(parent, "StudentDeskModestyPanels", Vector3(1.5, 0.42, 0.055), materials["wood"], modesty_panels)
		_multibox(parent, "StudentDeskLegs", Vector3(0.075, 0.86, 0.075), materials["metal"], desk_legs)
		_multibox(parent, "StudentChairSeats", Vector3(0.92, 0.1, 0.75), materials["wood"], chair_seats)
		_multibox(parent, "StudentChairBacks", Vector3(0.92, 0.76, 0.1), materials["wood"], chair_backs)
	_multibox(parent, "StudentChairLegs", Vector3(0.065, 0.44, 0.065), materials["metal"], chair_legs)
	_multibox(parent, "UnderDeskBaskets", Vector3(1.28, 0.045, 0.52), materials["metal"], baskets)
	_multibox(parent, "StudentNotebooks", Vector3(0.72, 0.035, 0.46), materials["paper"], notebooks)


static func _build_teacher_furniture(parent: Node3D, materials: Dictionary, existing_desk: bool) -> void:
	var origin := Vector3(-4.5, 0, -6.6)
	if not existing_desk:
		_box(parent, "TeacherDeskTop", origin + Vector3(0, 0.84, 0), Vector3(3.2, 0.18, 1.2), materials["wood"])
		_box(parent, "TeacherDeskPedestal", origin + Vector3(1.15, 0.42, 0), Vector3(0.65, 0.75, 1.05), materials["wood"])
		_box(parent, "TeacherDeskModestyPanel", origin + Vector3(0, 0.45, -0.5), Vector3(3.0, 0.72, 0.08), materials["wood"])
		_collider(parent, "TeacherDeskCollision", origin + Vector3(0, 0.48, 0), Vector3(3.25, 0.96, 1.25))
	for drawer_y in [0.24, 0.47, 0.7]:
		_box(parent, "TeacherDrawer_%s" % str(drawer_y), origin + Vector3(1.15, drawer_y, 0.54), Vector3(0.53, 0.16, 0.035), materials["dark"])
	_box(parent, "TeacherChairSeat", origin + Vector3(0, 0.49, -1.12), Vector3(0.92, 0.12, 0.78), materials["wood"])
	_box(parent, "TeacherChairBack", origin + Vector3(0, 0.96, -1.49), Vector3(0.92, 0.82, 0.1), materials["wood"])
	for x in [-0.36, 0.36]:
		for z in [-1.38, -0.88]:
			_box(parent, "TeacherChairLeg_%s_%s" % [str(x), str(z)], origin + Vector3(x, 0.23, z), Vector3(0.07, 0.46, 0.07), materials["metal"])


static func _build_storage(parent: Node3D, materials: Dictionary) -> void:
	_box(parent, "TallCabinet", Vector3(8.35, 1.16, 7.85), Vector3(1.45, 2.32, 2.35), materials["dark"], true)
	_box(parent, "CabinetDoorLeft", Vector3(8.0, 1.2, 6.66), Vector3(0.66, 2.18, 0.055), materials["metal"])
	_box(parent, "CabinetDoorRight", Vector3(8.7, 1.2, 6.66), Vector3(0.66, 2.18, 0.055), materials["metal"])
	_box(parent, "CabinetHandleLeft", Vector3(8.26, 1.2, 6.61), Vector3(0.055, 0.42, 0.055), materials["paper"])
	_box(parent, "CabinetHandleRight", Vector3(8.44, 1.2, 6.61), Vector3(0.055, 0.42, 0.055), materials["paper"])
	_collider(parent, "OpenShelfCollision", Vector3(-8.35, 1.16, 7.85), Vector3(1.45, 2.32, 2.35))
	_box(parent, "ShelfBack", Vector3(-8.35, 1.16, 9.0), Vector3(1.45, 2.32, 0.08), materials["dark"])
	_box(parent, "ShelfSideLeft", Vector3(-9.03, 1.16, 7.85), Vector3(0.09, 2.32, 2.3), materials["dark"])
	_box(parent, "ShelfSideRight", Vector3(-7.67, 1.16, 7.85), Vector3(0.09, 2.32, 2.3), materials["dark"])
	for shelf_y in [0.2, 0.72, 1.24, 1.76, 2.28]:
		_box(parent, "Shelf_%s" % str(shelf_y), Vector3(-8.35, shelf_y, 7.85), Vector3(1.38, 0.075, 2.28), materials["metal"])
	var books := []
	for shelf_index in 4:
		for book_index in 4:
			books.append(Transform3D(Basis.IDENTITY, Vector3(-8.83 + book_index * 0.31, 0.46 + shelf_index * 0.52, 6.58)))
	_multibox(parent, "ShelfBooks", Vector3(0.22, 0.4, 0.34), materials["accent"], books)


static func _build_displays(parent: Node3D, subject_id: String, whiteboard: bool, materials: Dictionary) -> void:
	var identity: Dictionary = SUBJECT_IDENTITY.get(subject_id, FALLBACK_IDENTITY)
	for x in [-6.65, 6.65]:
		_box(parent, "DisplayBoard_%s" % str(x), Vector3(x, 2.35, -9.04), Vector3(3.05, 1.65, 0.07), materials["cork"])
		_box(parent, "DisplayFrameTop_%s" % str(x), Vector3(x, 3.21, -8.98), Vector3(3.2, 0.08, 0.11), materials["board_frame"])
		_box(parent, "DisplayFrameBottom_%s" % str(x), Vector3(x, 1.49, -8.98), Vector3(3.2, 0.08, 0.11), materials["board_frame"])
	_label(parent, "SubjectPoster", str(identity["poster"]), Vector3(-6.65, 2.35, -8.94), Color("e8e2cf"), 24, 0.004)
	_label(parent, "ClassNotice", str(identity["notice"]), Vector3(6.65, 2.35, -8.94), Color("f0ead8"), 23, 0.004)
	var notes := []
	for x in [5.65, 6.32, 6.98, 7.65]:
		notes.append(Transform3D(Basis.IDENTITY, Vector3(x, 1.78, -8.92)))
	_multibox(parent, "PinnedNotes", Vector3(0.48, 0.34, 0.018), materials["paper"], notes)
	if whiteboard:
		_box(parent, "MarkerEraser", Vector3(3.25, 1.56, -8.68), Vector3(0.54, 0.08, 0.18), materials["dark"])


static func _build_utilities(parent: Node3D, side: float, materials: Dictionary) -> void:
	var bin := MeshInstance3D.new()
	bin.name = "Wastebasket"
	var bin_mesh := CylinderMesh.new()
	bin_mesh.top_radius = 0.28
	bin_mesh.bottom_radius = 0.22
	bin_mesh.height = 0.65
	bin_mesh.radial_segments = 12
	bin_mesh.material = materials["metal"]
	bin.mesh = bin_mesh
	bin.position = Vector3(-7.0, 0.34, -6.4)
	parent.add_child(bin)

	var radiator_x := signf(side) * 9.67
	var fins := []
	for index in 12:
		fins.append(Transform3D(Basis.IDENTITY, Vector3(radiator_x, 0.52, -2.5 + index * 0.44)))
	_multibox(parent, "RadiatorFins", Vector3(0.18, 0.82, 0.28), materials["paper"], fins)
	_box(parent, "RadiatorTop", Vector3(radiator_x - signf(side) * 0.04, 0.96, -0.08), Vector3(0.24, 0.08, 5.2), materials["metal"])
	_box(parent, "RadiatorPipe", Vector3(radiator_x, 0.16, 2.55), Vector3(0.12, 0.22, 0.85), materials["metal"])
	var corridor_x := -signf(side) * 9.7
	_box(parent, "LightSwitch", Vector3(corridor_x, 1.25, -1.35), Vector3(0.055, 0.34, 0.24), materials["paper"])
	_box(parent, "PowerOutlet", Vector3(corridor_x, 0.3, -2.0), Vector3(0.055, 0.22, 0.34), materials["paper"])


static func _build_ceiling(parent: Node3D, materials: Dictionary) -> void:
	var housings := []
	var diffusers := []
	for x in [-4.0, 4.0]:
		for z in [-4.5, 4.5]:
			housings.append(Transform3D(Basis.IDENTITY, Vector3(x, 4.02, z)))
			diffusers.append(Transform3D(Basis.IDENTITY, Vector3(x, 3.93, z)))
	_multibox(parent, "CeilingLightHousings", Vector3(2.92, 0.1, 0.54), materials["metal"], housings)
	var fixture := _multibox(parent, "CeilingLightDiffusers", Vector3(2.58, 0.055, 0.31), materials["light"], diffusers)
	fixture.add_to_group("school_light_fixtures")


static func _build_floor_detail(parent: Node3D, materials: Dictionary) -> void:
	var long_lines := []
	var cross_lines := []
	for x in [-9.35, 9.35]:
		long_lines.append(Transform3D(Basis.IDENTITY, Vector3(x, 0.033, 0)))
	for z in [-8.85, 8.85]:
		cross_lines.append(Transform3D(Basis.IDENTITY, Vector3(0, 0.034, z)))
	_multibox(parent, "FloorLongBorders", Vector3(0.04, 0.006, 18.25), materials["floor_line"], long_lines)
	_multibox(parent, "FloorCrossBorders", Vector3(19.15, 0.006, 0.04), materials["floor_line"], cross_lines)


static func _box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material, collision := false) -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh" if collision else node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	if not collision:
		mesh_instance.position = position
		parent.add_child(mesh_instance)
		return mesh_instance

	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(mesh_instance)
	body.add_child(shape_node)
	parent.add_child(body)
	return body


static func _collider(parent: Node3D, node_name: String, position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)


static func _multibox(parent: Node3D, node_name: String, size: Vector3, material: Material, transforms: Array) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = transforms.size()
	for index in transforms.size():
		multi_mesh.set_instance_transform(index, transforms[index])
	instance.multimesh = multi_mesh
	parent.add_child(instance)
	return instance


static func _label(parent: Node3D, node_name: String, text: String, position: Vector3, color: Color, font_size: int, pixel_size: float) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = position
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


static func _material(color: Color, roughness: float, metallic := 0.0, emission := 0.0) -> StandardMaterial3D:
	var key := "%s:%0.2f:%0.2f:%0.2f" % [color.to_html(), roughness, metallic, emission]
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	_material_cache[key] = material
	return material
