@tool
class_name SchoolVisualPolish
extends RefCounted

const FLOOR_COUNT := 3
const FLOOR_HEIGHT := 4.4
const ROOM_ROWS := [-28.5, -9.5, 9.5, 28.5]
const FLOOR_NAMES := ["PRÍZEMIE", "1. POSCHODIE", "2. POSCHODIE"]

static var _materials := {}


static func apply(school: Node3D) -> Node3D:
	if not is_instance_valid(school):
		push_error("SchoolVisualPolish potrebuje platný uzol školy.")
		return null
	var existing := school.get_node_or_null("SchoolVisualPolish") as Node3D
	if existing != null:
		return existing

	var root := Node3D.new()
	root.name = "SchoolVisualPolish"
	root.add_to_group("school_visual_polish")
	root.set_meta("visual_budget", "shared materials; 4 multimeshes; 3 signs")
	school.add_child(root)
	_retint_architecture(school)
	_build_corridor_finish(root)
	_build_floor_signs(root)
	return root


static func _retint_architecture(school: Node3D) -> void:
	var wall := _material(Color("85877f"), 0.92)
	var floor := _material(Color("343b39"), 0.96)
	var concrete := _material(Color("747771"), 0.98)
	var painted_metal := _material(Color("202729"), 0.88)
	var locker := _material(Color("3d5657"), 0.82, 0.15)
	for candidate in school.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		var parent := mesh.get_parent()
		var label := str(parent.name if parent is StaticBody3D else mesh.name)
		if "Locker" in label:
			mesh.material_override = locker
		elif "Rail" in label or "Guard" in label or "Frame" in label:
			mesh.material_override = painted_metal
		elif "Step" in label or "Landing" in label or "StairTread" in label:
			mesh.material_override = concrete
		elif "Floor" in label or "Slab" in label:
			mesh.material_override = floor
		elif "Wall" in label or "Divider" in label or "Header" in label or "Sill" in label:
			mesh.material_override = wall


static func _build_corridor_finish(parent: Node3D) -> void:
	var band_transforms := []
	var trim_transforms := []
	var floor_edges := []
	for floor_index in FLOOR_COUNT:
		var base_y := floor_index * FLOOR_HEIGHT
		for side in [-1.0, 1.0]:
			for row_z in ROOM_ROWS:
				for offset_z in [-5.2, 5.2]:
					var position := Vector3(side * 2.865, base_y + 0.45, row_z + offset_z)
					band_transforms.append(Transform3D(Basis.IDENTITY, position))
					trim_transforms.append(Transform3D(Basis.IDENTITY, position + Vector3(0, 0.46, 0)))
			floor_edges.append(Transform3D(Basis.IDENTITY, Vector3(side * 2.48, base_y + 0.045, 0)))
	_multibox(parent, "CorridorLowerPanels", Vector3(0.035, 0.86, 8.35), _material(Color("355149"), 0.9), band_transforms)
	_multibox(parent, "CorridorPanelTrim", Vector3(0.055, 0.07, 8.35), _material(Color("9e9c8f"), 0.84), trim_transforms)
	_multibox(parent, "CorridorFloorEdges", Vector3(0.07, 0.012, 75.5), _material(Color("798078"), 0.96), floor_edges)


static func _build_floor_signs(parent: Node3D) -> void:
	var panels := []
	for floor_index in FLOOR_COUNT:
		var base_y := floor_index * FLOOR_HEIGHT
		panels.append(Transform3D(Basis.IDENTITY, Vector3(0, base_y + 2.35, 38.29)))
		var label := Label3D.new()
		label.name = "FloorIdentity_%d" % floor_index
		label.text = FLOOR_NAMES[floor_index]
		label.position = Vector3(0, base_y + 2.35, 38.25)
		label.rotation.y = PI
		label.font_size = 38
		label.pixel_size = 0.005
		label.outline_size = 5
		label.modulate = Color("ece8d9")
		parent.add_child(label)
	_multibox(parent, "FloorIdentityPanels", Vector3(4.4, 1.0, 0.05), _material(Color("304943"), 0.86), panels)


static func _multibox(parent: Node3D, node_name: String, size: Vector3, material: Material, transforms: Array) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = transforms.size()
	for index in transforms.size():
		multi_mesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi_mesh
	parent.add_child(instance)
	return instance


static func _material(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var key := "%s:%0.2f:%0.2f" % [color.to_html(), roughness, metallic]
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_materials[key] = material
	return material
