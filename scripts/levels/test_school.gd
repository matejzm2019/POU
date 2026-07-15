extends Node3D

var _materials: Dictionary = {}


func _ready() -> void:
	_build_shell()
	_build_classroom()
	_build_lighting()


func _build_shell() -> void:
	var wall := Color("34373a")
	_box("Floor", Vector3(0, -0.1, 0), Vector3(18, 0.2, 14), Color("26282a"))
	_box("Ceiling", Vector3(0, 4.1, 0), Vector3(18, 0.2, 14), Color("191b1d"))
	_box("NorthWall", Vector3(0, 2, -7), Vector3(18, 4, 0.25), wall)
	_box("WestWall", Vector3(-9, 2, 0), Vector3(0.25, 4, 14), wall)
	_box("EastWall", Vector3(9, 2, 0), Vector3(0.25, 4, 14), wall)
	_box("SouthWallLeft", Vector3(-1.6, 2, 7), Vector3(14.8, 4, 0.25), wall)
	_box("SouthWallRight", Vector3(8.1, 2, 7), Vector3(1.8, 4, 0.25), wall)
	_box("DoorHeader", Vector3(6.5, 3.45, 7), Vector3(1.4, 1.1, 0.25), wall)
	for z in [-5.0, 0.0, 5.0]:
		_box("WestBaseboard", Vector3(-8.84, 0.14, z), Vector3(0.08, 0.28, 4.7), Color("17191a"), false)
		_box("EastBaseboard", Vector3(8.84, 0.14, z), Vector3(0.08, 0.28, 4.7), Color("17191a"), false)


func _build_classroom() -> void:
	_box("Blackboard", Vector3(0, 2.45, -6.82), Vector3(7.6, 2.0, 0.12), Color("132c28"), false)
	_box("ChalkTray", Vector3(0, 1.42, -6.68), Vector3(7.8, 0.12, 0.28), Color("a7a095"), false)
	var board_text := Label3D.new()
	board_text.name = "BoardMessage"
	board_text.text = "DETENTION\nFinish your work.  Do not leave."
	board_text.font_size = 42
	board_text.modulate = Color("d8d2bd")
	board_text.position = Vector3(0, 2.55, -6.68)
	board_text.outline_size = 4
	add_child(board_text)

	var desk_index := 0
	for z in [-3.0, 0.0, 3.0]:
		for x in [-5.4, -1.8, 1.8, 5.4]:
			desk_index += 1
			_build_student_desk(desk_index, Vector3(x, 0, z))
	_build_teacher_desk()

	for index in 6:
		var y := 0.52 + index * 0.56
		_box("Locker_%02d" % index, Vector3(-8.75, y, 5.65), Vector3(0.28, 0.5, 1.0), Color("38454a"), false)


func _build_student_desk(index: int, origin: Vector3) -> void:
	var wood := Color("5a4635")
	var metal := Color("32383a")
	_box("DeskTop_%02d" % index, origin + Vector3(0, 0.83, 0), Vector3(1.65, 0.12, 0.8), wood)
	for x in [-0.68, 0.68]:
		for z in [-0.27, 0.27]:
			_box("DeskLeg_%02d" % index, origin + Vector3(x, 0.42, z), Vector3(0.08, 0.78, 0.08), metal, false)
	_box("ChairSeat_%02d" % index, origin + Vector3(0, 0.48, 0.88), Vector3(0.9, 0.1, 0.75), wood)
	_box("ChairBack_%02d" % index, origin + Vector3(0, 0.93, 1.21), Vector3(0.9, 0.85, 0.1), wood, false)


func _build_teacher_desk() -> void:
	_box("TeacherDesk", Vector3(-5.7, 0.85, -5.35), Vector3(3.4, 0.18, 1.25), Color("4a382b"))
	_box("TeacherDeskFront", Vector3(-5.7, 0.43, -5.7), Vector3(3.2, 0.72, 0.1), Color("3b2c22"), false)
	_box("DetentionPaper", Vector3(-5.5, 1.0, -5.35), Vector3(0.8, 0.02, 0.6), Color("c9c3ac"), false)


func _build_lighting() -> void:
	for x in [-5.0, 0.0, 5.0]:
		_box("FluorescentFixture", Vector3(x, 3.92, 0), Vector3(2.8, 0.08, 0.36), Color("d4decf"), false, 2.2)
		var light := OmniLight3D.new()
		light.name = "CeilingLight"
		light.position = Vector3(x, 3.55, 0)
		light.light_color = Color("c7d5c4")
		light.light_energy = 2.0
		light.omni_range = 7.0
		light.shadow_enabled = true
		add_child(light)


func _box(label: String, box_position: Vector3, size: Vector3, color: Color, collision := true, emission := 0.0) -> Node3D:
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
	add_child(root)
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
