extends SceneTree

const Factory = preload("res://scripts/low_poly_factory.gd")
const Catalog = preload("res://scripts/species_catalog.gd")

const OUTPUT_ROOT := "res://assets/models/animals"
const REPRESENTATIVE_SPECIES := [
	"rabbit", "fox", "deer", "wolf", "snake", "bear",
	"boar", "raccoon", "porcupine", "crocodile", "capybara", "otter", "lynx", "goat", "wolverine",
	"bison", "zebra", "elephant", "tiger", "monkey", "owl", "moose", "turtle", "cheetah",
	"rhino", "gorilla", "eagle", "hippo", "hyena", "lion",
]

var failures: Array[String] = []


func _initialize() -> void:
	_generate.call_deferred()


func _generate() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	var requested_species := _requested_species()
	for species_id in requested_species:
		for profile in ["hero", "mobile"]:
			var model := _build_species(species_id, profile == "hero")
			_bake_export_materials(model, species_id)
			var species_dir := "%s/%s" % [OUTPUT_ROOT, species_id]
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(species_dir))
			var output_path := "%s/%s_%s.glb" % [species_dir, species_id, profile]
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			var append_error := document.append_from_scene(model, state)
			if append_error != OK:
				failures.append("%s 无法转换场景：%s" % [output_path, error_string(append_error)])
			else:
				var write_error := document.write_to_filesystem(state, output_path)
				if write_error != OK:
					failures.append("%s 无法写入：%s" % [output_path, error_string(write_error)])
				else:
					print("[species-glb] %s" % output_path)
			model.free()
	if failures.is_empty():
		print("SPECIES_GLB_GENERATION_OK: %d species × hero/mobile" % requested_species.size())
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _requested_species() -> Array[String]:
	var requested: Array[String] = []
	for argument in OS.get_cmdline_user_args():
		if argument in REPRESENTATIVE_SPECIES and not argument in requested:
			requested.append(argument)
	if requested.is_empty():
		requested.assign(REPRESENTATIVE_SPECIES)
	return requested


func _bake_export_materials(root: Node, species_id: String) -> void:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		if mesh_instance.mesh != null and mesh_instance.material_override != null:
			var baked_mesh := _mesh_with_generated_uvs(mesh_instance.mesh)
			var baked_material := _portable_export_material(mesh_instance.mesh, mesh_instance.material_override, str(mesh_instance.name), species_id)
			if baked_mesh is PrimitiveMesh:
				(baked_mesh as PrimitiveMesh).material = baked_material
			elif baked_mesh is ArrayMesh:
				for surface_index in range((baked_mesh as ArrayMesh).get_surface_count()):
					(baked_mesh as ArrayMesh).surface_set_material(surface_index, baked_material)
			mesh_instance.mesh = baked_mesh
			mesh_instance.material_override = null
	for child in root.get_children():
		_bake_export_materials(child, species_id)


func _portable_export_material(mesh: Mesh, source_material: Material, mesh_name: String, species_id: String) -> StandardMaterial3D:
	var color := Color.WHITE
	if source_material is StandardMaterial3D:
		color = (source_material as StandardMaterial3D).albedo_color
	if mesh is ArrayMesh and (mesh as ArrayMesh).get_surface_count() > 0:
		var arrays := (mesh as ArrayMesh).surface_get_arrays(0)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		if not colors.is_empty():
			var red := 0.0
			var green := 0.0
			var blue := 0.0
			var alpha := 0.0
			for vertex_color in colors:
				red += vertex_color.r
				green += vertex_color.g
				blue += vertex_color.b
				alpha += vertex_color.a
			var divisor := float(colors.size())
			color = Color(red / divisor, green / divisor, blue / divisor, alpha / divisor)
	var material := StandardMaterial3D.new()
	var material_slot := _pbr_material_slot(mesh_name)
	material.resource_name = "%s_%s_pbr" % [species_id, material_slot]
	material.albedo_color = color
	material.metallic = 0.0
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.emission_enabled = true
	material.emission = color.darkened(0.58)
	match material_slot:
		"coat":
			material.roughness = 0.94
			material.metallic_specular = 0.11
			material.emission_energy_multiplier = 0.07
		"eye":
			material.roughness = 0.24
			material.metallic_specular = 0.52
			material.emission_energy_multiplier = 0.10
		"nose":
			material.roughness = 0.42
			material.metallic_specular = 0.34
			material.emission_energy_multiplier = 0.08
		"paw":
			material.roughness = 0.82
			material.metallic_specular = 0.14
			material.emission_energy_multiplier = 0.06
		_:
			material.roughness = 0.76
			material.metallic_specular = 0.18
			material.emission_energy_multiplier = 0.07
	return material


func _mesh_with_generated_uvs(source_mesh: Mesh) -> Mesh:
	if not source_mesh is ArrayMesh:
		return source_mesh.duplicate()
	var source := source_mesh as ArrayMesh
	var baked := ArrayMesh.new()
	for surface_index in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		if uvs.size() != vertices.size():
			uvs = PackedVector2Array()
			for vertex in vertices:
				uvs.append(Vector2(vertex.x * 0.38 + vertex.z * 0.07, vertex.z * 0.34 + vertex.y * 0.16))
			arrays[Mesh.ARRAY_TEX_UV] = uvs
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
		if tangents.size() != vertices.size() * 4 and normals.size() == vertices.size():
			tangents = PackedFloat32Array()
			for normal in normals:
				var tangent := Vector3.RIGHT - normal * normal.dot(Vector3.RIGHT)
				if tangent.length_squared() < 0.0001:
					tangent = Vector3.FORWARD - normal * normal.dot(Vector3.FORWARD)
				tangent = tangent.normalized()
				tangents.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, 1.0]))
			arrays[Mesh.ARRAY_TANGENT] = tangents
		baked.add_surface_from_arrays(source.surface_get_primitive_type(surface_index), arrays)
	return baked


func _pbr_material_slot(mesh_name: String) -> String:
	var lowered := mesh_name.to_lower()
	if "eye" in lowered or "iris" in lowered or "pupil" in lowered or "catchlight" in lowered:
		return "eye"
	if "nose" in lowered or "beak" in lowered:
		return "nose"
	if "paw" in lowered or "hoof" in lowered or "talon" in lowered or "claw" in lowered:
		return "paw"
	if "body" in lowered or "fur" in lowered or "quarter" in lowered or "ruff" in lowered or "wing" in lowered or "tail" in lowered:
		return "coat"
	return "detail"


func _build_species(species_id: String, hero: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "%s_%s" % [species_id.capitalize(), "Hero" if hero else "Mobile"]
	match species_id:
		"rabbit": _build_rabbit(root, hero)
		"wolf": _build_wolf(root, hero)
		"deer": _build_deer(root, hero)
		"bear": _build_bear(root, hero)
		"eagle": _build_eagle(root, hero)
		"crocodile": _build_crocodile(root, hero)
		"fox": _build_fox(root, hero)
		"snake": _build_snake(root, hero)
		"boar": _build_boar(root, hero)
		"raccoon": _build_raccoon(root, hero)
		"porcupine": _build_porcupine(root, hero)
		"capybara": _build_capybara(root, hero)
		"otter": _build_otter(root, hero)
		"wolverine": _build_wolverine(root, hero)
		"zebra": _build_zebra(root, hero)
		"owl": _build_owl(root, hero)
		"turtle": _build_turtle(root, hero)
		"cheetah": _build_cheetah(root, hero)
		"hyena": _build_hyena(root, hero)
		"lion", "tiger", "lynx": _build_feline(root, hero, species_id)
		"elephant", "rhino", "hippo": _build_heavy_herbivore(root, hero, species_id)
		"bison", "moose", "goat": _build_ungulate(root, hero, species_id)
		"monkey", "gorilla": _build_primate(root, hero, species_id)
	if species_id in ["rabbit", "wolf", "deer", "bear"]:
		_group_skeletal_body(root)
	return root


func _group_skeletal_body(root: Node3D) -> void:
	var existing_children := root.get_children()
	var spine := Node3D.new()
	spine.name = "SpinePivot"
	root.add_child(spine)
	for child in existing_children:
		if not child is Node3D:
			continue
		var node_name := str(child.name)
		if node_name.begins_with("LegPivot_") or node_name.begins_with("EarPivot_") or node_name == "TailPivot":
			continue
		child.reparent(spine, false)


func _detail(hero: bool) -> Dictionary:
	return {
		"sides": 12 if hero else 8,
		"radial": 12 if hero else 8,
		"rings": 8 if hero else 5,
	}


func _add_sphere(parent: Node3D, name_text: String, color: Color, scale_value: Vector3, position_value: Vector3, hero: bool) -> MeshInstance3D:
	var detail := _detail(hero)
	var mesh := Factory.sphere(name_text, color, scale_value, position_value, int(detail["radial"]), int(detail["rings"]))
	parent.add_child(mesh)
	return mesh


func _add_loft(parent: Node3D, name_text: String, color: Color, centers: Array, radii: Array, hero: bool) -> MeshInstance3D:
	var mesh := Factory.loft(name_text, color, centers, radii, int(_detail(hero)["sides"]))
	parent.add_child(mesh)
	return mesh


func _add_eye_pair(parent: Node3D, height: float, forward_z: float, side_x: float, eye_size: float, iris: Color, hero: bool) -> void:
	for side in [-1.0, 1.0]:
		_add_sphere(parent, "EyeSocket", Color("#111514"), Vector3(eye_size * 1.06, eye_size, eye_size * 0.62), Vector3(side * side_x, height, forward_z), hero)
		_add_sphere(parent, "Iris", iris, Vector3(eye_size * 0.47, eye_size * 0.52, eye_size * 0.18), Vector3(side * (side_x + 0.012), height, forward_z - eye_size * 0.47), hero)
		_add_sphere(parent, "Pupil", Color("#050606"), Vector3(eye_size * 0.18, eye_size * 0.32, eye_size * 0.08), Vector3(side * (side_x + 0.015), height, forward_z - eye_size * 0.57), hero)
		if hero:
			_add_sphere(parent, "EyeCatchlight", Color("#f7f1dc"), Vector3.ONE * eye_size * 0.10, Vector3(side * (side_x + 0.025), height + eye_size * 0.19, forward_z - eye_size * 0.62), true)


func _add_ear(parent: Node3D, side: float, base_position: Vector3, length: float, width: float, color: Color, inner: Color, hero: bool, upright: bool = true) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "EarPivot_L" if side < 0.0 else "EarPivot_R"
	pivot.position = base_position
	parent.add_child(pivot)
	var tip := Vector3(side * width * 0.35, length, 0.05 if upright else 0.28)
	_add_loft(pivot, "Ear", color, [Vector3.ZERO, Vector3(side * width * 0.10, length * 0.56, 0.02), tip], [Vector2(width, width * 0.48), Vector2(width * 0.82, width * 0.34), Vector2(0.025, 0.025)], hero)
	if hero:
		_add_loft(pivot, "InnerEar", inner, [Vector3(0.0, 0.05, -0.025), Vector3(side * width * 0.08, length * 0.54, -0.02), tip * 0.88 + Vector3(0.0, 0.02, -0.02)], [Vector2(width * 0.40, width * 0.12), Vector2(width * 0.35, width * 0.10), Vector2(0.014, 0.014)], true)
	return pivot


func _add_round_ear(parent: Node3D, side: float, base_position: Vector3, scale_value: Vector3, color: Color, inner: Color, hero: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "EarPivot_L" if side < 0.0 else "EarPivot_R"
	pivot.position = base_position
	parent.add_child(pivot)
	_add_sphere(pivot, "RoundEar", color, scale_value, Vector3.ZERO, hero)
	if hero:
		_add_sphere(pivot, "InnerEar", inner, scale_value * Vector3(0.56, 0.58, 0.46), Vector3(0.0, 0.0, -scale_value.z * 0.72), true)
	return pivot


func _add_quadruped_legs(parent: Node3D, color: Color, foot_color: Color, upper_y: float, length: float, spread_x: float, spread_z: float, radius: float, hero: bool, hoofed: bool = false, rabbit_gait: bool = false) -> void:
	for side in [-1.0, 1.0]:
		for front_sign in [-1.0, 1.0]:
			var suffix := ("L" if side < 0.0 else "R") + ("F" if front_sign < 0.0 else "H")
			var pivot := Node3D.new()
			pivot.name = "LegPivot_%s" % suffix
			pivot.position = Vector3(side * spread_x, upper_y, front_sign * spread_z)
			parent.add_child(pivot)
			var knee_bias := 0.16 if front_sign < 0.0 else -0.20
			if rabbit_gait and front_sign > 0.0:
				knee_bias = 0.30
			var knee := Vector3(side * 0.035, -length * 0.48, knee_bias)
			var ankle := Vector3(0.0, -length * 0.90, -0.04 if front_sign < 0.0 else 0.12)
			var toe := ankle + Vector3(0.0, -length * 0.08, -radius * (0.72 if hoofed else 1.05))
			_add_loft(pivot, "Leg_%s" % suffix, color, [Vector3.ZERO, knee, ankle, toe], [Vector2(radius * 0.56, radius * 0.52), Vector2(radius * 0.43, radius * 0.39), Vector2(radius * 0.30, radius * 0.27), Vector2(radius * 0.22, radius * 0.20)], hero)
			var foot_scale := Vector3(radius * (0.44 if hoofed else 0.62), radius * 0.20, radius * (0.62 if hoofed else (1.12 if rabbit_gait and front_sign > 0.0 else 0.82)))
			_add_sphere(pivot, "Hoof_%s" % suffix if hoofed else "Paw_%s" % suffix, foot_color, foot_scale, toe + Vector3(0.0, -radius * 0.05, -radius * 0.20), hero)


func _add_tail(parent: Node3D, base_position: Vector3, centers: Array, radii: Array, color: Color, hero: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "TailPivot"
	pivot.position = base_position
	parent.add_child(pivot)
	_add_loft(pivot, "Tail", color, centers, radii, hero)
	return pivot


func _build_rabbit(root: Node3D, hero: bool) -> void:
	var fur := Color("#d9ded8")
	var light := Color("#f0eee4")
	var warm := Color("#b9aaa0")
	root.scale = Vector3.ONE * 1.02
	_add_loft(root, "RabbitOrganicBody", fur, [
		Vector3(0.0, 0.92, 1.08), Vector3(0.0, 1.02, 0.55), Vector3(0.0, 1.08, -0.15),
		Vector3(0.0, 1.18, -0.74), Vector3(0.0, 1.34, -1.12), Vector3(0.0, 1.35, -1.56),
	], [
		Vector2(0.58, 0.64), Vector2(0.78, 0.76), Vector2(0.72, 0.70),
		Vector2(0.54, 0.60), Vector2(0.49, 0.47), Vector2(0.25, 0.23),
	], hero)
	_add_sphere(root, "HindQuarter_L", fur.darkened(0.035), Vector3(0.47, 0.55, 0.62), Vector3(-0.39, 0.84, 0.58), hero)
	_add_sphere(root, "HindQuarter_R", fur.darkened(0.035), Vector3(0.47, 0.55, 0.62), Vector3(0.39, 0.84, 0.58), hero)
	_add_sphere(root, "ChestFur", light, Vector3(0.43, 0.48, 0.16), Vector3(0.0, 1.08, -0.92), hero)
	_add_sphere(root, "Muzzle", light, Vector3(0.34, 0.23, 0.30), Vector3(0.0, 1.27, -1.70), hero)
	_add_sphere(root, "Nose", Color("#68565b"), Vector3(0.11, 0.08, 0.08), Vector3(0.0, 1.31, -2.00), hero)
	_add_eye_pair(root, 1.56, -1.45, 0.30, 0.075, Color("#68472f"), hero)
	_add_ear(root, -1.0, Vector3(-0.22, 1.63, -1.18), 1.24, 0.19, fur, Color("#d9a9ac"), hero)
	_add_ear(root, 1.0, Vector3(0.22, 1.63, -1.18), 1.18, 0.19, fur, Color("#d9a9ac"), hero)
	_add_sphere(root, "TailPivot", light, Vector3.ONE * 0.39, Vector3(0.0, 1.04, 1.42), hero)
	_add_quadruped_legs(root, fur.darkened(0.08), warm, 0.82, 0.62, 0.43, 0.58, 0.30, hero, false, true)
	if hero:
		for side in [-1.0, 1.0]:
			for line_index in range(3):
				var whisker := Factory.tapered_cylinder("Whisker", Color("#d8d4cb"), 0.008, 0.003, 0.52, Vector3(side * (0.32 + line_index * 0.018), 1.28 + line_index * 0.055, -1.78), 5)
				whisker.rotation.z = side * (PI * 0.5 - 0.12 - line_index * 0.05)
				root.add_child(whisker)


func _build_wolf(root: Node3D, hero: bool) -> void:
	var fur := Color("#667078")
	var dark := Color("#31383b")
	var light := Color("#aeb2ad")
	root.scale = Vector3.ONE * 1.10
	_add_loft(root, "WolfOrganicBody", fur, [
		Vector3(0.0, 1.13, 1.38), Vector3(0.0, 1.23, 0.72), Vector3(0.0, 1.35, 0.02),
		Vector3(0.0, 1.53, -0.62), Vector3(0.0, 1.74, -1.12), Vector3(0.0, 1.70, -1.63), Vector3(0.0, 1.56, -2.16),
	], [
		Vector2(0.46, 0.48), Vector2(0.69, 0.66), Vector2(0.73, 0.69), Vector2(0.66, 0.72),
		Vector2(0.49, 0.51), Vector2(0.42, 0.38), Vector2(0.18, 0.16),
	], hero)
	_add_sphere(root, "ShoulderMass", dark.lightened(0.08), Vector3(0.71, 0.74, 0.62), Vector3(0.0, 1.42, -0.45), hero)
	_add_sphere(root, "CheekRuff", light.darkened(0.08), Vector3(0.53, 0.43, 0.30), Vector3(0.0, 1.67, -1.52), hero)
	_add_sphere(root, "Muzzle", light, Vector3(0.34, 0.24, 0.44), Vector3(0.0, 1.55, -2.08), hero)
	_add_sphere(root, "Nose", Color("#181d1e"), Vector3(0.17, 0.12, 0.14), Vector3(0.0, 1.57, -2.53), hero)
	_add_eye_pair(root, 1.86, -1.65, 0.30, 0.072, Color("#d6a04a"), hero)
	_add_ear(root, -1.0, Vector3(-0.29, 2.00, -1.30), 0.72, 0.24, dark, Color("#8f6f70"), hero)
	_add_ear(root, 1.0, Vector3(0.29, 2.00, -1.30), 0.72, 0.24, dark, Color("#8f6f70"), hero)
	_add_quadruped_legs(root, dark, Color("#242a2c"), 1.02, 0.93, 0.50, 0.78, 0.38, hero)
	_add_tail(root, Vector3(0.0, 1.32, 1.27), [Vector3.ZERO, Vector3(0.12, -0.05, 0.64), Vector3(0.20, -0.18, 1.22), Vector3(0.16, -0.38, 1.72)], [Vector2(0.31, 0.30), Vector2(0.34, 0.32), Vector2(0.23, 0.22), Vector2(0.06, 0.06)], dark, hero)


func _build_fox(root: Node3D, hero: bool) -> void:
	var coat := Color("#d9632f")
	var dark := Color("#64331f")
	var cream := Color("#f2e0c2")
	root.scale = Vector3.ONE * 0.88
	_add_loft(root, "FoxOrganicBody", coat, [
		Vector3(0.0, 0.96, 1.14), Vector3(0.0, 1.03, 0.57), Vector3(0.0, 1.10, -0.10),
		Vector3(0.0, 1.29, -0.70), Vector3(0.0, 1.56, -1.16), Vector3(0.0, 1.57, -1.66), Vector3(0.0, 1.40, -2.20),
	], [
		Vector2(0.34, 0.35), Vector2(0.57, 0.47), Vector2(0.58, 0.48), Vector2(0.50, 0.54),
		Vector2(0.38, 0.40), Vector2(0.32, 0.27), Vector2(0.13, 0.11),
	], hero)
	_add_sphere(root, "ChestRuff", cream, Vector3(0.48, 0.58, 0.19), Vector3(0.0, 1.18, -1.02), hero)
	_add_sphere(root, "CheekRuff", cream.darkened(0.04), Vector3(0.45, 0.33, 0.27), Vector3(0.0, 1.52, -1.70), hero)
	_add_sphere(root, "Muzzle", cream, Vector3(0.27, 0.18, 0.36), Vector3(0.0, 1.42, -2.16), hero)
	_add_sphere(root, "Nose", Color("#202522"), Vector3(0.14, 0.10, 0.12), Vector3(0.0, 1.44, -2.53), hero)
	_add_eye_pair(root, 1.75, -1.72, 0.24, 0.068, Color("#d6a04a"), hero)
	_add_ear(root, -1.0, Vector3(-0.27, 1.91, -1.36), 0.79, 0.23, dark, Color("#a66b65"), hero)
	_add_ear(root, 1.0, Vector3(0.27, 1.91, -1.36), 0.79, 0.23, dark, Color("#a66b65"), hero)
	_add_quadruped_legs(root, dark, Color("#302c29"), 0.92, 0.79, 0.43, 0.68, 0.31, hero)
	var tail_pivot := _add_tail(root, Vector3(0.0, 1.10, 1.02), [Vector3.ZERO, Vector3(0.10, 0.18, 0.62), Vector3(0.18, 0.54, 1.18), Vector3(0.13, 0.76, 1.77), Vector3(0.05, 0.65, 2.16)], [Vector2(0.26, 0.25), Vector2(0.39, 0.36), Vector2(0.40, 0.37), Vector2(0.27, 0.25), Vector2(0.06, 0.06)], dark, hero)
	_add_loft(tail_pivot, "TailTip", cream, [Vector3(0.13, 0.76, 1.77), Vector3(0.05, 0.65, 2.16), Vector3(0.02, 0.53, 2.38)], [Vector2(0.27, 0.25), Vector2(0.12, 0.11), Vector2(0.02, 0.02)], hero)
	if hero:
		for side in [-1.0, 1.0]:
			for whisker_index in range(3):
				var whisker := Factory.tapered_cylinder("Whisker_%s_%d" % ["L" if side < 0.0 else "R", whisker_index], Color("#d9d0bd"), 0.007, 0.002, 0.46, Vector3(side * 0.27, 1.43 + whisker_index * 0.05, -2.18), 5)
				whisker.rotation.z = side * (PI * 0.5 - 0.16 - whisker_index * 0.05)
				root.add_child(whisker)


func _build_snake(root: Node3D, hero: bool) -> void:
	var hide := Color("#5c9651")
	var dark := Color("#315b36")
	var accent := Color("#d6d254")
	root.scale = Vector3.ONE * 0.98
	var centers: Array = []
	var radii: Array = []
	var segments := 18 if hero else 13
	for index in range(segments):
		var ratio := float(index) / float(segments - 1)
		centers.append(Vector3(sin(float(index) * 0.72) * (0.34 + ratio * 0.10), 0.27 + ratio * 0.16, 3.15 - ratio * 4.12))
		var radius := lerpf(0.055, 0.31, ratio)
		radii.append(Vector2(radius, radius * 0.72))
	centers.append_array([Vector3(0.0, 0.64, -1.34), Vector3(0.0, 0.66, -1.76), Vector3(0.0, 0.63, -2.08)])
	radii.append_array([Vector2(0.42, 0.29), Vector2(0.29, 0.19), Vector2(0.14, 0.10)])
	_add_loft(root, "SnakeOrganicBody", dark, centers, radii, hero)
	var mark_count := 6 if hero else 3
	for mark_index in range(mark_count):
		var sample_index := clampi(3 + mark_index * 2, 0, segments - 2)
		var center: Vector3 = centers[sample_index]
		_add_sphere(root, "BackMark_%02d" % mark_index, accent.darkened(0.05), Vector3(0.22, 0.07, 0.25), center + Vector3(0.0, float(radii[sample_index].y) * 0.78, 0.0), hero)
	_add_eye_pair(root, 0.75, -1.80, 0.18, 0.072, Color("#c7c24d"), hero)
	_add_loft(root, "ForkedTongue", Color("#d94f69"), [Vector3(0.0, 0.63, -2.04), Vector3(0.0, 0.63, -2.37)], [Vector2(0.025, 0.025), Vector2(0.014, 0.014)], hero)
	for side in [-1.0, 1.0]:
		_add_loft(root, "TongueFork_%s" % ("L" if side < 0.0 else "R"), Color("#d94f69"), [Vector3(0.0, 0.63, -2.34), Vector3(side * 0.10, 0.63, -2.55)], [Vector2(0.014, 0.014), Vector2(0.004, 0.004)], hero)
		if hero:
			var fang := Factory.cone("VenomFang_%s" % ("L" if side < 0.0 else "R"), Color("#e8e0c5"), 0.028, 0.16, Vector3(side * 0.12, 0.55, -2.03), 5)
			fang.rotation.x = PI
			root.add_child(fang)


func _build_boar(root: Node3D, hero: bool) -> void:
	var coat := Color("#594338")
	var dark := Color("#302821")
	var muzzle := Color("#a18a71")
	root.scale = Vector3.ONE * 1.06
	_add_loft(root, "BoarOrganicBody", coat, [
		Vector3(0.0, 1.02, 1.28), Vector3(0.0, 1.09, 0.62), Vector3(0.0, 1.18, -0.10),
		Vector3(0.0, 1.42, -0.74), Vector3(0.0, 1.55, -1.30), Vector3(0.0, 1.38, -1.83), Vector3(0.0, 1.23, -2.30),
	], [
		Vector2(0.38, 0.38), Vector2(0.72, 0.61), Vector2(0.76, 0.64), Vector2(0.72, 0.73),
		Vector2(0.52, 0.48), Vector2(0.41, 0.32), Vector2(0.20, 0.15),
	], hero)
	_add_sphere(root, "ShoulderMass", coat.darkened(0.08), Vector3(0.76, 0.72, 0.58), Vector3(0.0, 1.36, -0.66), hero)
	_add_sphere(root, "Snout", muzzle, Vector3(0.44, 0.29, 0.43), Vector3(0.0, 1.22, -2.22), hero)
	_add_sphere(root, "Nose", Color("#2d2725"), Vector3(0.30, 0.16, 0.12), Vector3(0.0, 1.22, -2.63), hero)
	_add_eye_pair(root, 1.60, -1.70, 0.29, 0.068, Color("#86663d"), hero)
	_add_ear(root, -1.0, Vector3(-0.38, 1.81, -1.34), 0.48, 0.20, coat.darkened(0.10), muzzle.darkened(0.22), hero, false)
	_add_ear(root, 1.0, Vector3(0.38, 1.81, -1.34), 0.48, 0.20, coat.darkened(0.10), muzzle.darkened(0.22), hero, false)
	_add_quadruped_legs(root, coat.darkened(0.18), dark, 0.94, 0.74, 0.56, 0.74, 0.38, hero)
	for side in [-1.0, 1.0]:
		var tusk := Factory.cone("Tusk_%s" % ("L" if side < 0.0 else "R"), Color("#ded4b5"), 0.085, 0.43, Vector3(side * 0.32, 1.12, -2.45), int(_detail(hero)["radial"]))
		tusk.rotation.x = -PI * 0.56
		tusk.rotation.z = side * 0.22
		root.add_child(tusk)
	var bristle_count := 8 if hero else 4
	for bristle_index in range(bristle_count):
		var ratio := float(bristle_index) / float(maxi(bristle_count - 1, 1))
		var bristle := Factory.cone("BackBristle_%02d" % bristle_index, dark, 0.13, lerpf(0.30, 0.46, sin(ratio * PI)), Vector3(0.0, 1.78, lerpf(0.66, -1.35, ratio)), 6)
		bristle.rotation.x = -0.10
		root.add_child(bristle)
	_add_tail(root, Vector3(0.0, 1.18, 1.18), [Vector3.ZERO, Vector3(0.09, 0.12, 0.24), Vector3(0.18, 0.04, 0.43), Vector3(0.10, -0.09, 0.54)], [Vector2(0.10, 0.10), Vector2(0.09, 0.09), Vector2(0.07, 0.07), Vector2(0.025, 0.025)], dark, hero)


func _build_deer(root: Node3D, hero: bool) -> void:
	var coat := Color("#9a704d")
	var dark := Color("#46372b")
	var cream := Color("#d2b58b")
	root.scale = Vector3.ONE * 1.08
	_add_loft(root, "DeerOrganicBody", coat, [
		Vector3(0.0, 1.50, 1.20), Vector3(0.0, 1.58, 0.55), Vector3(0.0, 1.63, -0.10),
		Vector3(0.0, 1.72, -0.72), Vector3(0.0, 2.10, -1.08), Vector3(0.0, 2.55, -1.32),
		Vector3(0.0, 2.78, -1.72), Vector3(0.0, 2.64, -2.22),
	], [
		Vector2(0.45, 0.48), Vector2(0.65, 0.63), Vector2(0.67, 0.64), Vector2(0.56, 0.61),
		Vector2(0.34, 0.38), Vector2(0.28, 0.30), Vector2(0.35, 0.31), Vector2(0.18, 0.15),
	], hero)
	_add_sphere(root, "ChestLight", cream, Vector3(0.32, 0.60, 0.14), Vector3(0.0, 1.76, -0.76), hero)
	_add_sphere(root, "Muzzle", cream.darkened(0.12), Vector3(0.27, 0.19, 0.38), Vector3(0.0, 2.63, -2.14), hero)
	_add_sphere(root, "Nose", Color("#24221f"), Vector3(0.14, 0.09, 0.10), Vector3(0.0, 2.64, -2.53), hero)
	_add_eye_pair(root, 2.90, -1.78, 0.24, 0.068, Color("#725033"), hero)
	_add_ear(root, -1.0, Vector3(-0.24, 3.00, -1.48), 0.52, 0.20, coat, cream, hero, false)
	_add_ear(root, 1.0, Vector3(0.24, 3.00, -1.48), 0.52, 0.20, coat, cream, hero, false)
	_add_quadruped_legs(root, coat.darkened(0.16), dark, 1.48, 1.35, 0.48, 0.76, 0.25, hero, true)
	_add_tail(root, Vector3(0.0, 1.66, 1.20), [Vector3.ZERO, Vector3(0.0, -0.10, 0.34), Vector3(0.0, -0.20, 0.57)], [Vector2(0.17, 0.16), Vector2(0.22, 0.18), Vector2(0.05, 0.05)], cream, hero)
	for side in [-1.0, 1.0]:
		var antler_root := Node3D.new()
		antler_root.name = "Antler_L" if side < 0.0 else "Antler_R"
		antler_root.position = Vector3(side * 0.20, 3.08, -1.52)
		root.add_child(antler_root)
		_add_loft(antler_root, "AntlerBeam", dark, [Vector3.ZERO, Vector3(side * 0.10, 0.45, 0.05), Vector3(side * 0.25, 0.88, 0.16), Vector3(side * 0.42, 1.12, 0.27)], [Vector2(0.075, 0.075), Vector2(0.065, 0.065), Vector2(0.045, 0.045), Vector2(0.018, 0.018)], hero)
		if hero:
			for branch_index in range(2):
				_add_loft(antler_root, "AntlerTine", dark, [Vector3(side * (0.10 + branch_index * 0.12), 0.44 + branch_index * 0.30, 0.10), Vector3(side * (0.25 + branch_index * 0.18), 0.66 + branch_index * 0.34, -0.02)], [Vector2(0.040, 0.040), Vector2(0.012, 0.012)], true)


func _build_bear(root: Node3D, hero: bool) -> void:
	var fur := Color("#654a38")
	var dark := Color("#392c24")
	var muzzle := Color("#9b7b61")
	root.scale = Vector3.ONE * 1.22
	_add_loft(root, "BearOrganicBody", fur, [
		Vector3(0.0, 1.28, 1.34), Vector3(0.0, 1.42, 0.72), Vector3(0.0, 1.55, 0.04),
		Vector3(0.0, 1.78, -0.62), Vector3(0.0, 2.02, -1.12), Vector3(0.0, 2.10, -1.67), Vector3(0.0, 1.90, -2.18),
	], [
		Vector2(0.78, 0.76), Vector2(1.02, 0.91), Vector2(1.04, 0.94), Vector2(1.12, 1.02),
		Vector2(0.78, 0.76), Vector2(0.63, 0.57), Vector2(0.30, 0.26),
	], hero)
	_add_sphere(root, "ShoulderHump", dark.lightened(0.06), Vector3(1.06, 0.82, 0.92), Vector3(0.0, 1.85, -0.55), hero)
	_add_sphere(root, "Muzzle", muzzle, Vector3(0.52, 0.36, 0.42), Vector3(0.0, 1.86, -2.15), hero)
	_add_sphere(root, "Nose", Color("#241c18"), Vector3(0.22, 0.15, 0.15), Vector3(0.0, 1.92, -2.58), hero)
	_add_eye_pair(root, 2.24, -1.81, 0.34, 0.070, Color("#7b562f"), hero)
	for side in [-1.0, 1.0]:
		var ear_pivot := Node3D.new()
		ear_pivot.name = "EarPivot_L" if side < 0.0 else "EarPivot_R"
		ear_pivot.position = Vector3(side * 0.44, 2.58, -1.38)
		root.add_child(ear_pivot)
		_add_sphere(ear_pivot, "RoundEar", fur.lightened(0.08), Vector3(0.29, 0.31, 0.18), Vector3.ZERO, hero)
		if hero:
			_add_sphere(ear_pivot, "InnerEar", dark, Vector3(0.16, 0.18, 0.08), Vector3(0.0, 0.0, -0.14), true)
	_add_quadruped_legs(root, dark.lightened(0.04), Color("#2d241f"), 1.16, 0.92, 0.70, 0.78, 0.64, hero)
	_add_sphere(root, "TailPivot", fur.darkened(0.08), Vector3(0.27, 0.24, 0.26), Vector3(0.0, 1.43, 1.60), hero)


func _build_eagle(root: Node3D, hero: bool) -> void:
	var feather := Color("#5a4934")
	var gold := Color("#b89550")
	var dark := Color("#2d2a26")
	root.scale = Vector3.ONE * 1.04
	_add_loft(root, "EagleOrganicBody", feather, [Vector3(0.0, 0.86, 0.70), Vector3(0.0, 1.20, 0.18), Vector3(0.0, 1.52, -0.38), Vector3(0.0, 1.69, -0.98), Vector3(0.0, 1.61, -1.44)], [Vector2(0.42, 0.46), Vector2(0.66, 0.74), Vector2(0.55, 0.62), Vector2(0.34, 0.35), Vector2(0.20, 0.18)], hero)
	_add_sphere(root, "GoldenNape", gold, Vector3(0.42, 0.43, 0.38), Vector3(0.0, 1.58, -1.10), hero)
	_add_sphere(root, "Head", feather.darkened(0.08), Vector3(0.36, 0.37, 0.35), Vector3(0.0, 1.62, -1.45), hero)
	var beak := Factory.cone("HookedBeak", Color("#d5ad52"), 0.17, 0.66, Vector3(0.0, 1.54, -1.90), int(_detail(hero)["radial"]))
	beak.rotation.x = -PI * 0.5
	root.add_child(beak)
	for side in [-1.0, 1.0]:
		var side_suffix := "L" if side < 0.0 else "R"
		var eye_size := 0.063
		_add_sphere(root, "EyeSocket_%s" % side_suffix, Color("#111514"), Vector3(eye_size * 1.06, eye_size, eye_size * 0.62), Vector3(side * 0.22, 1.76, -1.67), hero)
		_add_sphere(root, "Iris_%s" % side_suffix, Color("#e1b13f"), Vector3(eye_size * 0.47, eye_size * 0.52, eye_size * 0.18), Vector3(side * 0.232, 1.76, -1.67 - eye_size * 0.47), hero)
		_add_sphere(root, "Pupil_%s" % side_suffix, Color("#050606"), Vector3(eye_size * 0.18, eye_size * 0.32, eye_size * 0.08), Vector3(side * 0.235, 1.76, -1.67 - eye_size * 0.57), hero)
		if hero:
			_add_sphere(root, "EyeCatchlight_%s" % side_suffix, Color("#f7f1dc"), Vector3.ONE * eye_size * 0.10, Vector3(side * 0.245, 1.76 + eye_size * 0.19, -1.67 - eye_size * 0.62), true)
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.name = "WingPivot_L" if side < 0.0 else "WingPivot_R"
		wing.position = Vector3(side * 0.46, 1.36, -0.02)
		root.add_child(wing)
		_add_loft(wing, "Wing", feather.darkened(0.04), [Vector3.ZERO, Vector3(side * 0.74, 0.02, 0.28), Vector3(side * 1.42, -0.05, 0.64), Vector3(side * 2.10, -0.16, 1.00)], [Vector2(0.36, 0.18), Vector2(0.45, 0.16), Vector2(0.34, 0.12), Vector2(0.07, 0.04)], hero)
		if hero:
			for feather_index in range(4):
				_add_loft(wing, "PrimaryFeather", dark, [Vector3(side * (1.02 + feather_index * 0.23), -0.04, 0.56 + feather_index * 0.12), Vector3(side * (1.72 + feather_index * 0.22), -0.12, 1.12 + feather_index * 0.16)], [Vector2(0.11, 0.055), Vector2(0.018, 0.012)], true)
	var tail := Node3D.new()
	tail.name = "TailPivot"
	tail.position = Vector3(0.0, 0.92, 0.62)
	root.add_child(tail)
	for side_index in range(-2, 3):
		_add_loft(tail, "TailFeather", dark, [Vector3(side_index * 0.10, 0.0, 0.0), Vector3(side_index * 0.18, -0.08, 0.92)], [Vector2(0.12, 0.06), Vector2(0.018, 0.012)], hero)
	for side in [-1.0, 1.0]:
		_add_sphere(root, "Talon_L" if side < 0.0 else "Talon_R", Color("#c9a346"), Vector3(0.15, 0.10, 0.23), Vector3(side * 0.23, 0.55, -0.18), hero)


func _build_crocodile(root: Node3D, hero: bool) -> void:
	var hide := Color("#526b42")
	var dark := Color("#33462f")
	var belly := Color("#9a9b6e")
	root.scale = Vector3.ONE * 1.18
	_add_loft(root, "CrocodileOrganicBody", hide, [
		Vector3(0.0, 0.56, 2.00), Vector3(0.0, 0.68, 1.25), Vector3(0.0, 0.76, 0.42),
		Vector3(0.0, 0.78, -0.38), Vector3(0.0, 0.70, -1.10), Vector3(0.0, 0.63, -1.82),
		Vector3(0.0, 0.56, -2.55), Vector3(0.0, 0.53, -3.20),
	], [
		Vector2(0.18, 0.14), Vector2(0.56, 0.40), Vector2(0.82, 0.52), Vector2(0.86, 0.55),
		Vector2(0.70, 0.46), Vector2(0.52, 0.31), Vector2(0.40, 0.21), Vector2(0.24, 0.12),
	], hero)
	_add_loft(root, "LowerJaw", belly, [Vector3(0.0, 0.49, -1.72), Vector3(0.0, 0.45, -2.42), Vector3(0.0, 0.43, -3.22)], [Vector2(0.48, 0.14), Vector2(0.43, 0.12), Vector2(0.23, 0.08)], hero)
	_add_quadruped_legs(root, dark, dark.darkened(0.12), 0.58, 0.48, 0.68, 0.84, 0.36, hero)
	for side in [-1.0, 1.0]:
		var side_suffix := "L" if side < 0.0 else "R"
		var eye_size := 0.072
		_add_sphere(root, "EyeSocket_%s" % side_suffix, Color("#111514"), Vector3(eye_size * 1.06, eye_size, eye_size * 0.62), Vector3(side * 0.29, 0.88, -2.34), hero)
		_add_sphere(root, "Iris_%s" % side_suffix, Color("#c8c04c"), Vector3(eye_size * 0.47, eye_size * 0.52, eye_size * 0.18), Vector3(side * 0.302, 0.88, -2.34 - eye_size * 0.47), hero)
		_add_sphere(root, "Pupil_%s" % side_suffix, Color("#050606"), Vector3(eye_size * 0.18, eye_size * 0.32, eye_size * 0.08), Vector3(side * 0.305, 0.88, -2.34 - eye_size * 0.57), hero)
		if hero:
			_add_sphere(root, "EyeCatchlight_%s" % side_suffix, Color("#f7f1dc"), Vector3.ONE * eye_size * 0.10, Vector3(side * 0.315, 0.88 + eye_size * 0.19, -2.34 - eye_size * 0.62), true)
		_add_sphere(root, "Nostril_%s" % side_suffix, Color("#26352a"), Vector3(0.07, 0.045, 0.06), Vector3(side * 0.17, 0.60, -3.22), hero)
	var plate_count := 12 if hero else 7
	for plate_index in range(plate_count):
		var ratio := float(plate_index) / float(maxi(plate_count - 1, 1))
		var plate_z := lerpf(1.42, -1.92, ratio)
		var plate_height := lerpf(0.16, 0.24, sin(ratio * PI))
		var plate := Factory.cone("BackScute_%02d" % plate_index, dark.lightened(0.04), 0.14, plate_height, Vector3(0.0, 1.06 - absf(ratio - 0.48) * 0.22, plate_z), 6)
		root.add_child(plate)
	if hero:
		for side in [-1.0, 1.0]:
			for tooth_index in range(6):
				var tooth := Factory.cone("Tooth_%s_%02d" % ["L" if side < 0.0 else "R", tooth_index], Color("#ded6b5"), 0.035, 0.17, Vector3(side * 0.34, 0.47, -1.92 - tooth_index * 0.20), 5)
				tooth.rotation.x = PI
				root.add_child(tooth)


func _build_feline(root: Node3D, hero: bool, feline_id: String) -> void:
	var coat := Color("#c99a4c")
	var dark := Color("#4a321f")
	var light := Color("#ead1a0")
	var body_width := 0.72
	var body_height := 1.38
	var body_length := 1.48
	match feline_id:
		"tiger":
			coat = Color("#d27c32")
			dark = Color("#28231f")
			light = Color("#ead8b9")
			body_width = 0.80
			body_height = 1.42
			body_length = 1.58
		"lynx":
			coat = Color("#9b8066")
			dark = Color("#443a32")
			light = Color("#d8c4aa")
			body_width = 0.55
			body_height = 1.18
			body_length = 1.12
	_add_loft(root, "%sOrganicBody" % feline_id.capitalize(), coat, [
		Vector3(0.0, body_height * 0.78, body_length), Vector3(0.0, body_height * 0.84, body_length * 0.52),
		Vector3(0.0, body_height * 0.90, 0.0), Vector3(0.0, body_height, -body_length * 0.52),
		Vector3(0.0, body_height * 1.17, -body_length * 0.92), Vector3(0.0, body_height * 1.15, -body_length * 1.28),
		Vector3(0.0, body_height * 1.03, -body_length * 1.62),
	], [
		Vector2(body_width * 0.48, body_width * 0.46), Vector2(body_width * 0.88, body_width * 0.67),
		Vector2(body_width, body_width * 0.72), Vector2(body_width * 0.92, body_width * 0.82),
		Vector2(body_width * 0.64, body_width * 0.61), Vector2(body_width * 0.50, body_width * 0.45),
		Vector2(body_width * 0.22, body_width * 0.18),
	], hero)
	_add_sphere(root, "HindQuarter", coat.darkened(0.025), Vector3(body_width * 0.84, body_width * 0.69, body_width * 0.72), Vector3(0.0, body_height * 0.83, body_length * 0.78), hero)
	if feline_id == "lion":
		_add_sphere(root, "ManeRuff", dark, Vector3(0.84, 0.84, 0.62), Vector3(0.0, 1.72, -1.60), hero)
	elif feline_id == "tiger":
		var stripe_count := 9 if hero else 5
		for stripe_index in range(stripe_count):
			var stripe_ratio := float(stripe_index) / float(maxi(stripe_count - 1, 1))
			var stripe := Factory.box("CoatStripe_%02d" % stripe_index, dark, Vector3(body_width * 1.58, 0.055, 0.085), Vector3(0.0, body_height * (1.32 - absf(stripe_ratio - 0.48) * 0.38), lerpf(0.92, -1.15, stripe_ratio)))
			stripe.rotation.z = (stripe_ratio - 0.5) * 0.20
			root.add_child(stripe)
	else:
		_add_sphere(root, "CheekRuff", light, Vector3(0.52, 0.40, 0.26), Vector3(0.0, 1.48, -1.46), hero)
	_add_sphere(root, "Muzzle", light, Vector3(body_width * 0.48, body_width * 0.30, body_width * 0.46), Vector3(0.0, body_height * 1.08, -body_length * 1.57), hero)
	_add_sphere(root, "Nose", Color("#262120"), Vector3(body_width * 0.20, body_width * 0.13, body_width * 0.13), Vector3(0.0, body_height * 1.10, -body_length * 1.92), hero)
	_add_eye_pair(root, body_height * 1.30, -body_length * 1.40, body_width * 0.39, 0.070, Color("#d6a245"), hero)
	for side in [-1.0, 1.0]:
		var ear_pivot := Node3D.new()
		ear_pivot.name = "EarPivot_L" if side < 0.0 else "EarPivot_R"
		ear_pivot.position = Vector3(side * body_width * 0.53, body_height * 1.50, -body_length * 1.16)
		root.add_child(ear_pivot)
		_add_sphere(ear_pivot, "RoundEar", coat.darkened(0.06), Vector3(0.22, 0.25, 0.14), Vector3.ZERO, hero)
		if feline_id == "lynx":
			var tuft := Factory.cone("EarTuft_%s" % ("L" if side < 0.0 else "R"), dark, 0.055, 0.38, Vector3(0.0, 0.31, 0.0), 6 if hero else 5)
			ear_pivot.add_child(tuft)
	_add_quadruped_legs(root, coat.darkened(0.14), dark, body_height * 0.72, body_height * 0.74, body_width * 0.67, body_length * 0.52, body_width * 0.60, hero)
	if feline_id == "lynx":
		_add_tail(root, Vector3(0.0, body_height * 0.90, body_length * 0.93), [Vector3.ZERO, Vector3(0.04, 0.05, 0.46), Vector3(0.03, -0.05, 0.73)], [Vector2(0.18, 0.17), Vector2(0.16, 0.15), Vector2(0.05, 0.05)], dark, hero)
	else:
		var tail := _add_tail(root, Vector3(0.0, body_height * 0.90, body_length * 0.94), [Vector3.ZERO, Vector3(0.10, 0.03, 0.76), Vector3(0.18, -0.20, 1.48), Vector3(0.08, -0.56, 2.10)], [Vector2(0.17, 0.16), Vector2(0.15, 0.14), Vector2(0.10, 0.09), Vector2(0.035, 0.035)], coat.darkened(0.12), hero)
		if feline_id == "lion":
			_add_sphere(tail, "TailTuft", dark, Vector3(0.20, 0.22, 0.30), Vector3(0.08, -0.57, 2.08), hero)


func _build_heavy_herbivore(root: Node3D, hero: bool, heavy_id: String) -> void:
	var hide := Color("#777a73")
	var dark := Color("#474a45")
	var light := Color("#c8c2ae")
	var width := 1.02
	var height := 1.72
	var length := 1.58
	if heavy_id == "rhino":
		hide = Color("#7d817b")
		width = 0.94
		height = 1.52
		length = 1.50
	elif heavy_id == "hippo":
		hide = Color("#746b70")
		dark = Color("#423a3e")
		light = Color("#b9878b")
		width = 1.08
		height = 1.34
		length = 1.46
	_add_loft(root, "%sOrganicBody" % heavy_id.capitalize(), hide, [
		Vector3(0.0, height * 0.72, length), Vector3(0.0, height * 0.82, length * 0.50),
		Vector3(0.0, height * 0.88, 0.0), Vector3(0.0, height, -length * 0.55),
		Vector3(0.0, height * 1.05, -length), Vector3(0.0, height * 0.92, -length * 1.44),
	], [
		Vector2(width * 0.58, width * 0.54), Vector2(width, width * 0.78), Vector2(width * 1.04, width * 0.82),
		Vector2(width, width * 0.88), Vector2(width * 0.76, width * 0.65), Vector2(width * 0.46, width * 0.33),
	], hero)
	_add_sphere(root, "HindQuarter", hide.darkened(0.025), Vector3(width * 0.94, width * 0.78, width * 0.76), Vector3(0.0, height * 0.79, length * 0.76), hero)
	match heavy_id:
		"elephant":
			_add_sphere(root, "Head", hide, Vector3(0.77, 0.72, 0.70), Vector3(0.0, 1.86, -1.82), hero)
			for side in [-1.0, 1.0]:
				_add_sphere(root, "EarDetail_%s" % ("L" if side < 0.0 else "R"), hide.lightened(0.08), Vector3(0.18, 0.76, 0.68), Vector3(side * 0.73, 1.90, -1.55), hero)
				var tusk := Factory.cone("Tusk_%s" % ("L" if side < 0.0 else "R"), light, 0.09, 0.88, Vector3(side * 0.28, 1.34, -2.25), int(_detail(hero)["radial"]))
				tusk.rotation.x = -PI * 0.52
				root.add_child(tusk)
			_add_loft(root, "Trunk", dark.lightened(0.12), [Vector3(0.0, 1.70, -2.30), Vector3(0.0, 1.12, -2.55), Vector3(0.06, 0.52, -2.62), Vector3(0.12, 0.30, -2.42)], [Vector2(0.24, 0.23), Vector2(0.20, 0.19), Vector2(0.14, 0.13), Vector2(0.10, 0.09)], hero)
			_add_eye_pair(root, 2.08, -2.05, 0.48, 0.075, Color("#765638"), hero)
		"rhino":
			_add_sphere(root, "Muzzle", hide.lightened(0.04), Vector3(0.56, 0.38, 0.62), Vector3(0.0, 1.28, -2.10), hero)
			for horn_index in range(2):
				var horn := Factory.cone("HornDetail_%d" % horn_index, light, 0.19 - horn_index * 0.05, 1.12 - horn_index * 0.48, Vector3(0.0, 1.58 + horn_index * 0.18, -2.48 + horn_index * 0.52), int(_detail(hero)["radial"]))
				horn.rotation.x = -PI * 0.45
				root.add_child(horn)
			_add_eye_pair(root, 1.76, -1.75, 0.36, 0.067, Color("#6f5136"), hero)
		"hippo":
			_add_sphere(root, "WideMuzzle", light, Vector3(0.78, 0.40, 0.64), Vector3(0.0, 1.22, -2.05), hero)
			_add_sphere(root, "Nose", dark, Vector3(0.38, 0.14, 0.12), Vector3(0.0, 1.40, -2.60), hero)
			_add_eye_pair(root, 1.70, -1.75, 0.37, 0.070, Color("#76513b"), hero)
	for side in [-1.0, 1.0]:
		var ear_pivot := Node3D.new()
		ear_pivot.name = "EarPivot_L" if side < 0.0 else "EarPivot_R"
		ear_pivot.position = Vector3(side * width * 0.54, height * 1.26, -length * 0.90)
		root.add_child(ear_pivot)
		_add_sphere(ear_pivot, "EarDetail", hide.lightened(0.07), Vector3(0.20, 0.22, 0.13), Vector3.ZERO, hero)
	_add_quadruped_legs(root, hide.darkened(0.10), dark, height * 0.64, height * 0.62, width * 0.72, length * 0.55, width * 0.72, hero)
	_add_tail(root, Vector3(0.0, height * 0.82, length * 0.92), [Vector3.ZERO, Vector3(0.06, -0.15, 0.42), Vector3(0.03, -0.38, 0.67)], [Vector2(0.12, 0.11), Vector2(0.09, 0.08), Vector2(0.025, 0.025)], dark, hero)


func _build_ungulate(root: Node3D, hero: bool, ungulate_id: String) -> void:
	var coat := Color("#684b37")
	var dark := Color("#322a24")
	var light := Color("#b99b73")
	var width := 0.78
	var height := 1.50
	var length := 1.34
	if ungulate_id == "moose":
		coat = Color("#60493a")
		width = 0.70
		height = 1.88
		length = 1.42
	elif ungulate_id == "goat":
		coat = Color("#a59175")
		dark = Color("#51483c")
		light = Color("#d2c3a8")
		width = 0.48
		height = 1.28
		length = 1.05
	_add_loft(root, "%sOrganicBody" % ungulate_id.capitalize(), coat, [
		Vector3(0.0, height * 0.76, length), Vector3(0.0, height * 0.84, length * 0.48), Vector3(0.0, height * 0.90, 0.0),
		Vector3(0.0, height, -length * 0.55), Vector3(0.0, height * 1.20, -length * 0.92), Vector3(0.0, height * 1.40, -length * 1.22), Vector3(0.0, height * 1.31, -length * 1.60),
	], [
		Vector2(width * 0.46, width * 0.45), Vector2(width * 0.94, width * 0.72), Vector2(width, width * 0.76),
		Vector2(width * 0.92, width * 0.84), Vector2(width * 0.55, width * 0.56), Vector2(width * 0.48, width * 0.43), Vector2(width * 0.22, width * 0.18),
	], hero)
	_add_sphere(root, "HindQuarter", coat.darkened(0.025), Vector3(width * 0.84, width * 0.69, width * 0.72), Vector3(0.0, height * 0.84, length * 0.78), hero)
	if ungulate_id == "bison":
		_add_sphere(root, "ShoulderHump", dark, Vector3(0.91, 0.80, 0.68), Vector3(0.0, 1.72, -0.62), hero)
		_add_sphere(root, "BeardRuff", dark, Vector3(0.36, 0.54, 0.26), Vector3(0.0, 1.36, -1.82), hero)
	elif ungulate_id == "moose":
		_add_sphere(root, "Dewlap", dark, Vector3(0.20, 0.54, 0.18), Vector3(0.0, 2.05, -1.62), hero)
	else:
		_add_sphere(root, "BeardRuff", dark, Vector3(0.18, 0.34, 0.14), Vector3(0.0, 1.38, -1.42), hero)
	_add_sphere(root, "Muzzle", light.darkened(0.08), Vector3(width * 0.43, width * 0.28, width * 0.54), Vector3(0.0, height * 1.27, -length * 1.60), hero)
	_add_sphere(root, "Nose", dark, Vector3(width * 0.24, width * 0.13, width * 0.14), Vector3(0.0, height * 1.28, -length * 1.98), hero)
	_add_eye_pair(root, height * 1.48, -length * 1.36, width * 0.36, 0.068, Color("#725032"), hero)
	for side in [-1.0, 1.0]:
		var ear := _add_ear(root, side, Vector3(side * width * 0.42, height * 1.61, -length * 1.15), 0.42 if ungulate_id != "goat" else 0.34, 0.17, coat, light, hero, false)
		ear.rotation.z = side * 0.18
		if ungulate_id == "moose":
			var palm := Factory.box("AntlerPalmDetail_%s" % ("L" if side < 0.0 else "R"), light, Vector3(0.48, 0.10, 0.34), Vector3(side * 0.58, height * 1.88, -length * 1.02))
			palm.rotation.z = side * 0.22
			root.add_child(palm)
			var tine_count := 4 if hero else 2
			for tine_index in range(tine_count):
				var tine := Factory.cone("AntlerTineDetail", light, 0.055, 0.48, Vector3(side * (0.46 + tine_index * 0.15), height * (1.98 + tine_index * 0.035), -length * (1.03 - tine_index * 0.05)), 6)
				tine.rotation.z = -side * 0.24
				root.add_child(tine)
		else:
			var horn := Factory.cone("HornDetail_%s" % ("L" if side < 0.0 else "R"), dark.lightened(0.10), 0.105 if ungulate_id == "bison" else 0.09, 0.62 if ungulate_id == "bison" else 0.78, Vector3(side * width * 0.42, height * 1.70, -length * 1.17), int(_detail(hero)["radial"]))
			horn.rotation.z = side * (0.92 if ungulate_id == "bison" else 0.36)
			root.add_child(horn)
	_add_quadruped_legs(root, coat.darkened(0.14), dark, height * 0.70, height * 0.77, width * 0.62, length * 0.56, width * 0.50, hero, true)
	_add_tail(root, Vector3(0.0, height * 0.88, length * 0.94), [Vector3.ZERO, Vector3(0.03, -0.12, 0.42), Vector3(0.02, -0.30, 0.64)], [Vector2(0.12, 0.11), Vector2(0.10, 0.09), Vector2(0.025, 0.025)], dark, hero)


func _build_primate(root: Node3D, hero: bool, primate_id: String) -> void:
	var heavy := primate_id == "gorilla"
	var coat := Color("#343631") if heavy else Color("#7b5d43")
	var skin := Color("#514840") if heavy else Color("#b68462")
	var chest := Color("#6f7168") if heavy else Color("#b89370")
	var body_y := 1.46 if heavy else 1.18
	_add_loft(root, "%sOrganicBody" % primate_id.capitalize(), coat, [
		Vector3(0.0, 0.74 if heavy else 0.62, 0.62), Vector3(0.0, body_y, 0.34), Vector3(0.0, body_y * 1.30, 0.0),
		Vector3(0.0, body_y * 1.50, -0.36), Vector3(0.0, body_y * 1.56, -0.72),
	], [
		Vector2(0.48 if heavy else 0.30, 0.42), Vector2(0.82 if heavy else 0.48, 0.66 if heavy else 0.44),
		Vector2(0.94 if heavy else 0.52, 0.74 if heavy else 0.48), Vector2(0.66 if heavy else 0.40, 0.54 if heavy else 0.38),
		Vector2(0.30 if heavy else 0.22, 0.25 if heavy else 0.19),
	], hero)
	_add_sphere(root, "ChestRuff", chest, Vector3(0.70 if heavy else 0.38, 0.62 if heavy else 0.42, 0.17), Vector3(0.0, body_y * 1.21, -0.20), hero)
	_add_sphere(root, "Head", coat, Vector3(0.48 if heavy else 0.34, 0.45 if heavy else 0.34, 0.38 if heavy else 0.30), Vector3(0.0, body_y * 1.70, -0.70), hero)
	_add_sphere(root, "Muzzle", skin, Vector3(0.42 if heavy else 0.27, 0.28 if heavy else 0.20, 0.34 if heavy else 0.25), Vector3(0.0, body_y * 1.60, -1.02), hero)
	_add_sphere(root, "Nose", Color("#241f1d"), Vector3(0.20 if heavy else 0.13, 0.11 if heavy else 0.08, 0.10 if heavy else 0.07), Vector3(0.0, body_y * 1.67, -1.29), hero)
	_add_eye_pair(root, body_y * 1.82, -0.91, 0.24 if heavy else 0.18, 0.064, Color("#7b5c38"), hero)
	for side in [-1.0, 1.0]:
		var ear_pivot := Node3D.new()
		ear_pivot.name = "EarPivot_L" if side < 0.0 else "EarPivot_R"
		ear_pivot.position = Vector3(side * (0.48 if heavy else 0.34), body_y * 1.72, -0.68)
		root.add_child(ear_pivot)
		_add_sphere(ear_pivot, "EarDetail", skin, Vector3(0.14, 0.17, 0.09), Vector3.ZERO, hero)
	_add_external_primate_limbs(root, coat, skin, heavy, hero)
	if primate_id == "monkey":
		_add_tail(root, Vector3(0.0, 0.92, 0.46), [Vector3.ZERO, Vector3(0.18, 0.16, 0.70), Vector3(0.36, 0.02, 1.34), Vector3(0.30, 0.40, 1.90), Vector3(0.06, 0.64, 2.25)], [Vector2(0.13, 0.12), Vector2(0.12, 0.11), Vector2(0.09, 0.08), Vector2(0.06, 0.055), Vector2(0.02, 0.02)], coat, hero)
	else:
		_add_sphere(root, "TailPivot", coat, Vector3(0.10, 0.10, 0.12), Vector3(0.0, 0.90, 0.62), hero)


func _add_external_primate_limbs(root: Node3D, coat: Color, skin: Color, heavy: bool, hero: bool) -> void:
	for side in [-1.0, 1.0]:
		var side_name := "L" if side < 0.0 else "R"
		var arm := Node3D.new()
		arm.name = "LegPivot_%sF" % side_name
		arm.position = Vector3(side * (0.68 if heavy else 0.43), 1.82 if heavy else 1.42, -0.14)
		root.add_child(arm)
		var elbow := Vector3(side * 0.12, -0.72 if heavy else -0.58, -0.10)
		var hand := Vector3(side * 0.07, -1.44 if heavy else -1.14, -0.30)
		_add_loft(arm, "Arm_%s" % side_name, coat, [Vector3.ZERO, elbow, hand], [Vector2(0.30 if heavy else 0.20, 0.28 if heavy else 0.18), Vector2(0.24 if heavy else 0.16, 0.22 if heavy else 0.14), Vector2(0.13, 0.12)], hero)
		_add_sphere(arm, "PawHand_%s" % side_name, skin, Vector3(0.28 if heavy else 0.20, 0.15, 0.32), hand + Vector3(0.0, -0.04, -0.08), hero)
		var leg := Node3D.new()
		leg.name = "LegPivot_%sH" % side_name
		leg.position = Vector3(side * (0.42 if heavy else 0.30), 0.82 if heavy else 0.70, 0.28)
		root.add_child(leg)
		var knee := Vector3(side * 0.08, -0.36, 0.12)
		var foot := Vector3(side * 0.03, -0.70 if heavy else -0.60, -0.14)
		_add_loft(leg, "Leg_%s" % side_name, coat, [Vector3.ZERO, knee, foot], [Vector2(0.28 if heavy else 0.18, 0.26 if heavy else 0.17), Vector2(0.22 if heavy else 0.15, 0.20 if heavy else 0.14), Vector2(0.12, 0.11)], hero)
		_add_sphere(leg, "PawFoot_%s" % side_name, skin, Vector3(0.25 if heavy else 0.18, 0.13, 0.34), foot + Vector3(0.0, -0.03, -0.10), hero)


func _build_raccoon(root: Node3D, hero: bool) -> void:
	var coat := Color("#747a77")
	var dark := Color("#252b2d")
	var cream := Color("#d5d0bc")
	root.scale = Vector3.ONE * 0.88
	_add_loft(root, "RaccoonOrganicBody", coat, [
		Vector3(0.0, 0.88, 1.12), Vector3(0.0, 0.96, 0.54), Vector3(0.0, 1.02, -0.12),
		Vector3(0.0, 1.20, -0.68), Vector3(0.0, 1.44, -1.08), Vector3(0.0, 1.48, -1.48), Vector3(0.0, 1.32, -1.92),
	], [
		Vector2(0.34, 0.33), Vector2(0.57, 0.46), Vector2(0.59, 0.48), Vector2(0.52, 0.53),
		Vector2(0.39, 0.38), Vector2(0.35, 0.29), Vector2(0.16, 0.12),
	], hero)
	_add_sphere(root, "CheekRuff", cream.darkened(0.10), Vector3(0.47, 0.35, 0.28), Vector3(0.0, 1.42, -1.55), hero)
	for side in [-1.0, 1.0]:
		_add_sphere(root, "FaceMaskDetail_%s" % ("L" if side < 0.0 else "R"), dark, Vector3(0.31, 0.18, 0.10), Vector3(side * 0.22, 1.54, -1.82), hero)
		_add_round_ear(root, side, Vector3(side * 0.34, 1.88, -1.33), Vector3(0.22, 0.24, 0.14), coat.darkened(0.12), cream.darkened(0.18), hero)
	_add_sphere(root, "Muzzle", cream, Vector3(0.39, 0.25, 0.31), Vector3(0.0, 1.30, -1.98), hero)
	_add_sphere(root, "Nose", Color("#1d2221"), Vector3(0.17, 0.11, 0.12), Vector3(0.0, 1.31, -2.29), hero)
	_add_eye_pair(root, 1.56, -1.88, 0.22, 0.070, Color("#9b7748"), hero)
	_add_quadruped_legs(root, coat.darkened(0.22), dark, 0.83, 0.70, 0.46, 0.68, 0.31, hero)
	var tail := Node3D.new()
	tail.name = "TailPivot"
	tail.position = Vector3(0.0, 1.02, 0.98)
	root.add_child(tail)
	var ring_count := 7 if hero else 5
	for ring_index in range(ring_count):
		var ratio := float(ring_index) / float(maxi(ring_count - 1, 1))
		var center := Vector3(0.12 + ratio * 0.24, ratio * 0.72, ratio * 1.82)
		var radius := lerpf(0.31, 0.09, ratio)
		_add_sphere(tail, "TailRingDetail_%02d" % ring_index, cream.darkened(0.10) if ring_index % 2 == 0 else dark, Vector3(radius, radius * 0.94, 0.34), center, hero)
	if hero:
		for side in [-1.0, 1.0]:
			for whisker_index in range(2):
				var whisker := Factory.tapered_cylinder("Whisker_%s_%d" % ["L" if side < 0.0 else "R", whisker_index], cream.lightened(0.12), 0.007, 0.002, 0.46, Vector3(side * 0.31, 1.31 + whisker_index * 0.06, -2.05), 5)
				whisker.rotation.z = side * (PI * 0.5 - 0.14 - whisker_index * 0.06)
				root.add_child(whisker)


func _build_porcupine(root: Node3D, hero: bool) -> void:
	var coat := Color("#5a4a3e")
	var dark := Color("#292621")
	var quill_light := Color("#dfcfaa")
	root.scale = Vector3.ONE * 0.96
	_add_loft(root, "PorcupineOrganicBody", coat, [
		Vector3(0.0, 0.83, 1.18), Vector3(0.0, 1.00, 0.62), Vector3(0.0, 1.16, -0.04),
		Vector3(0.0, 1.28, -0.68), Vector3(0.0, 1.20, -1.22), Vector3(0.0, 1.03, -1.72), Vector3(0.0, 0.94, -2.08),
	], [
		Vector2(0.38, 0.34), Vector2(0.66, 0.58), Vector2(0.72, 0.64), Vector2(0.66, 0.63),
		Vector2(0.50, 0.45), Vector2(0.30, 0.23), Vector2(0.14, 0.10),
	], hero)
	var column_count := 8 if hero else 5
	for row_index in range(3):
		var side := float(row_index - 1)
		for quill_index in range(column_count):
			var ratio := float(quill_index) / float(maxi(column_count - 1, 1))
			var quill := Factory.cone("BackQuillDetail_%d_%02d" % [row_index, quill_index], quill_light if (quill_index + row_index) % 2 == 0 else dark, 0.075, 0.62 + sin(ratio * PI) * 0.34, Vector3(side * 0.34, 1.52 + (1.0 - absf(side)) * 0.18, lerpf(0.88, -1.30, ratio)), 6)
			quill.rotation.z = -side * 0.20
			quill.rotation.x = lerpf(-0.18, 0.16, ratio)
			root.add_child(quill)
	_add_sphere(root, "SmallFace", coat.darkened(0.14), Vector3(0.43, 0.35, 0.47), Vector3(0.0, 1.02, -1.74), hero)
	for side in [-1.0, 1.0]:
		_add_round_ear(root, side, Vector3(side * 0.25, 1.40, -1.48), Vector3(0.18, 0.20, 0.12), coat.lightened(0.05), dark, hero)
	_add_eye_pair(root, 1.14, -1.98, 0.19, 0.068, Color("#85633b"), hero)
	_add_sphere(root, "Nose", Color("#201d1b"), Vector3(0.14, 0.10, 0.10), Vector3(0.0, 0.95, -2.22), hero)
	_add_quadruped_legs(root, coat.darkened(0.20), dark, 0.76, 0.58, 0.49, 0.66, 0.32, hero)
	var tail := _add_tail(root, Vector3(0.0, 0.92, 1.08), [Vector3.ZERO, Vector3(0.02, -0.02, 0.34), Vector3(0.04, -0.10, 0.58)], [Vector2(0.17, 0.16), Vector2(0.13, 0.12), Vector2(0.03, 0.03)], coat.darkened(0.10), hero)
	if hero:
		for side in [-1.0, 1.0]:
			var tail_quill := Factory.cone("TailQuillDetail", quill_light, 0.045, 0.38, Vector3(side * 0.07, 0.08, 0.42), 5)
			tail_quill.rotation.z = side * 0.38
			tail.add_child(tail_quill)


func _build_capybara(root: Node3D, hero: bool) -> void:
	var coat := Color("#9a6f49")
	var dark := Color("#4b3528")
	var muzzle := Color("#c39b6d")
	root.scale = Vector3.ONE * 1.04
	_add_loft(root, "CapybaraOrganicBody", coat, [
		Vector3(0.0, 0.94, 1.24), Vector3(0.0, 1.04, 0.58), Vector3(0.0, 1.10, -0.14),
		Vector3(0.0, 1.22, -0.78), Vector3(0.0, 1.36, -1.26), Vector3(0.0, 1.30, -1.78), Vector3(0.0, 1.18, -2.22),
	], [
		Vector2(0.42, 0.40), Vector2(0.75, 0.62), Vector2(0.78, 0.64), Vector2(0.71, 0.66),
		Vector2(0.58, 0.50), Vector2(0.49, 0.36), Vector2(0.27, 0.19),
	], hero)
	_add_sphere(root, "SquareMuzzle", muzzle, Vector3(0.51, 0.31, 0.45), Vector3(0.0, 1.20, -2.02), hero)
	for side in [-1.0, 1.0]:
		_add_round_ear(root, side, Vector3(side * 0.31, 1.70, -1.44), Vector3(0.18, 0.18, 0.12), coat.darkened(0.14), dark, hero)
		_add_sphere(root, "NostrilDetail_%s" % ("L" if side < 0.0 else "R"), dark, Vector3(0.065, 0.045, 0.052), Vector3(side * 0.15, 1.31, -2.39), hero)
	_add_eye_pair(root, 1.50, -1.91, 0.27, 0.070, Color("#6d4b30"), hero)
	_add_quadruped_legs(root, coat.darkened(0.15), dark, 0.87, 0.73, 0.61, 0.78, 0.40, hero)
	_add_sphere(root, "TailPivot", coat.darkened(0.18), Vector3(0.08, 0.07, 0.09), Vector3(0.0, 1.02, 1.36), hero)
	if hero:
		for side in [-1.0, 1.0]:
			for whisker_index in range(2):
				var whisker := Factory.tapered_cylinder("Whisker_%s_%d" % ["L" if side < 0.0 else "R", whisker_index], muzzle.lightened(0.24), 0.007, 0.002, 0.42, Vector3(side * 0.34, 1.22 + whisker_index * 0.06, -2.10), 5)
				whisker.rotation.z = side * (PI * 0.5 - 0.16)
				root.add_child(whisker)


func _build_otter(root: Node3D, hero: bool) -> void:
	var coat := Color("#624733")
	var dark := Color("#28231f")
	var cream := Color("#e2c79b")
	root.scale = Vector3.ONE * 0.92
	_add_loft(root, "OtterOrganicBody", coat, [
		Vector3(0.0, 0.58, 1.34), Vector3(0.0, 0.66, 0.76), Vector3(0.0, 0.72, 0.08),
		Vector3(0.0, 0.81, -0.60), Vector3(0.0, 1.02, -1.06), Vector3(0.0, 1.27, -1.42), Vector3(0.0, 1.18, -1.86), Vector3(0.0, 1.09, -2.14),
	], [
		Vector2(0.25, 0.22), Vector2(0.50, 0.35), Vector2(0.55, 0.39), Vector2(0.47, 0.45),
		Vector2(0.34, 0.36), Vector2(0.40, 0.34), Vector2(0.28, 0.21), Vector2(0.13, 0.10),
	], hero)
	_add_sphere(root, "CreamThroat", cream, Vector3(0.48, 0.52, 0.18), Vector3(0.0, 0.86, -1.16), hero)
	_add_sphere(root, "Muzzle", cream.lightened(0.05), Vector3(0.43, 0.25, 0.29), Vector3(0.0, 1.11, -1.96), hero)
	for side in [-1.0, 1.0]:
		_add_round_ear(root, side, Vector3(side * 0.30, 1.57, -1.37), Vector3(0.18, 0.18, 0.12), coat.darkened(0.08), dark, hero)
	_add_eye_pair(root, 1.37, -1.75, 0.22, 0.070, Color("#8a673d"), hero)
	_add_sphere(root, "Nose", dark, Vector3(0.18, 0.12, 0.12), Vector3(0.0, 1.11, -2.28), hero)
	_add_quadruped_legs(root, coat.darkened(0.12), cream.darkened(0.18), 0.52, 0.48, 0.45, 0.66, 0.30, hero)
	var tail := _add_tail(root, Vector3(0.0, 0.66, 1.22), [Vector3.ZERO, Vector3(0.08, -0.04, 0.68), Vector3(0.16, -0.10, 1.42), Vector3(0.12, -0.18, 2.12)], [Vector2(0.25, 0.18), Vector2(0.23, 0.16), Vector2(0.15, 0.10), Vector2(0.035, 0.025)], coat.darkened(0.10), hero)
	if hero:
		for side in [-1.0, 1.0]:
			for whisker_index in range(3):
				var whisker := Factory.tapered_cylinder("Whisker_%s_%d" % ["L" if side < 0.0 else "R", whisker_index], cream.lightened(0.20), 0.007, 0.002, 0.54, Vector3(side * 0.35, 1.12 + whisker_index * 0.055, -2.04), 5)
				whisker.rotation.z = side * (PI * 0.5 - 0.12 + whisker_index * 0.06)
				root.add_child(whisker)
		for side in [-1.0, 1.0]:
			_add_sphere(tail, "TailWebDetail_%s" % ("L" if side < 0.0 else "R"), coat.darkened(0.14), Vector3(0.05, 0.08, 0.48), Vector3(side * 0.10, -0.12, 1.40), true)


func _build_wolverine(root: Node3D, hero: bool) -> void:
	var coat := Color("#40352d")
	var dark := Color("#1f1c1a")
	var band := Color("#b28b58")
	root.scale = Vector3.ONE * 0.94
	_add_loft(root, "WolverineOrganicBody", coat, [
		Vector3(0.0, 0.82, 1.40), Vector3(0.0, 0.92, 0.74), Vector3(0.0, 1.00, -0.06),
		Vector3(0.0, 1.12, -0.76), Vector3(0.0, 1.30, -1.22), Vector3(0.0, 1.40, -1.62), Vector3(0.0, 1.28, -2.04),
	], [
		Vector2(0.35, 0.34), Vector2(0.65, 0.52), Vector2(0.68, 0.55), Vector2(0.61, 0.59),
		Vector2(0.45, 0.43), Vector2(0.43, 0.35), Vector2(0.19, 0.14),
	], hero)
	for side in [-1.0, 1.0]:
		_add_sphere(root, "SideBandDetail_%s" % ("L" if side < 0.0 else "R"), band, Vector3(0.14, 0.40, 1.16), Vector3(side * 0.61, 1.11, 0.05), hero)
		_add_round_ear(root, side, Vector3(side * 0.31, 1.76, -1.46), Vector3(0.20, 0.20, 0.14), coat.lightened(0.10), band.darkened(0.34), hero)
	_add_sphere(root, "Muzzle", band.darkened(0.16), Vector3(0.43, 0.28, 0.33), Vector3(0.0, 1.33, -2.00), hero)
	_add_eye_pair(root, 1.52, -1.86, 0.22, 0.070, Color("#8b6b3f"), hero)
	_add_sphere(root, "Nose", dark, Vector3(0.18, 0.12, 0.13), Vector3(0.0, 1.29, -2.32), hero)
	_add_quadruped_legs(root, coat.darkened(0.15), dark, 0.75, 0.63, 0.55, 0.82, 0.38, hero)
	_add_tail(root, Vector3(0.0, 0.92, 1.20), [Vector3.ZERO, Vector3(0.12, 0.18, 0.52), Vector3(0.18, 0.42, 0.98)], [Vector2(0.24, 0.23), Vector2(0.32, 0.30), Vector2(0.09, 0.08)], coat.darkened(0.18), hero)
	if hero:
		for side in [-1.0, 1.0]:
			for claw_index in range(3):
				var claw := Factory.cone("ClawDetail_%s_%d" % ["L" if side < 0.0 else "R", claw_index], Color("#d6c5a1"), 0.025, 0.20, Vector3(side * (0.45 + claw_index * 0.055), 0.10, -0.85), 5)
				claw.rotation.x = -PI * 0.5
				root.add_child(claw)


func _build_zebra(root: Node3D, hero: bool) -> void:
	var coat := Color("#e1ded2")
	var dark := Color("#25282a")
	root.scale = Vector3.ONE * 1.08
	var height := 1.52
	var length := 1.35
	var width := 0.61
	_add_loft(root, "ZebraOrganicBody", coat, [
		Vector3(0.0, 1.40, 1.18), Vector3(0.0, 1.46, 0.60), Vector3(0.0, 1.49, -0.12),
		Vector3(0.0, 1.60, -0.76), Vector3(0.0, 1.94, -1.06), Vector3(0.0, 2.38, -1.28), Vector3(0.0, 2.68, -1.64), Vector3(0.0, 2.56, -2.12),
	], [
		Vector2(0.34, 0.35), Vector2(width, 0.49), Vector2(width * 1.03, 0.51), Vector2(width * 0.91, 0.56),
		Vector2(0.38, 0.40), Vector2(0.30, 0.34), Vector2(0.36, 0.31), Vector2(0.15, 0.11),
	], hero)
	var stripe_count := 10 if hero else 6
	for stripe_index in range(stripe_count):
		var ratio := float(stripe_index) / float(maxi(stripe_count - 1, 1))
		var stripe_z := lerpf(0.94, -1.18, ratio)
		_add_sphere(root, "CoatStripeDetail_%02d" % stripe_index, dark, Vector3(width * (0.98 - absf(ratio - 0.46) * 0.25), 0.055, 0.10), Vector3(0.0, 1.72 + sin(ratio * PI) * 0.10, stripe_z), hero)
	var mane_count := 8 if hero else 5
	for mane_index in range(mane_count):
		var mane := Factory.cone("ManeDetail_%02d" % mane_index, dark, 0.085, 0.34, Vector3(0.0, 2.18 + float(mane_index) * 0.105, -0.82 - float(mane_index) * 0.18), 6)
		mane.rotation.x = -0.12
		root.add_child(mane)
	for side in [-1.0, 1.0]:
		_add_ear(root, side, Vector3(side * 0.28, 3.10, -1.56), 0.54, 0.17, coat, Color("#a58a7d"), hero)
	_add_eye_pair(root, 2.76, -1.96, 0.19, 0.070, Color("#6e5035"), hero)
	_add_sphere(root, "Muzzle", dark, Vector3(0.33, 0.20, 0.41), Vector3(0.0, 2.50, -2.25), hero)
	_add_sphere(root, "Nose", Color("#161818"), Vector3(0.19, 0.10, 0.11), Vector3(0.0, 2.52, -2.63), hero)
	_add_quadruped_legs(root, coat.darkened(0.05), dark, height * 0.76, 1.39, 0.51, 0.90, 0.23, hero, true)
	var tail := _add_tail(root, Vector3(0.0, 1.54, 1.28), [Vector3.ZERO, Vector3(0.04, -0.30, 0.42), Vector3(0.10, -0.62, 0.74)], [Vector2(0.11, 0.11), Vector2(0.12, 0.11), Vector2(0.05, 0.05)], dark, hero)
	_add_sphere(tail, "TailTuftDetail", dark, Vector3(0.22, 0.24, 0.30), Vector3(0.10, -0.64, 0.76), hero)


func _build_owl(root: Node3D, hero: bool) -> void:
	var feather := Color("#6d5842")
	var dark := Color("#302a24")
	var chest := Color("#d5c292")
	root.scale = Vector3.ONE * 0.96
	_add_loft(root, "OwlOrganicBody", feather, [
		Vector3(0.0, 0.72, 0.70), Vector3(0.0, 1.05, 0.34), Vector3(0.0, 1.42, -0.02), Vector3(0.0, 1.78, -0.38), Vector3(0.0, 1.98, -0.66),
	], [Vector2(0.30, 0.34), Vector2(0.58, 0.66), Vector2(0.72, 0.76), Vector2(0.62, 0.60), Vector2(0.34, 0.29)], hero)
	_add_sphere(root, "ChestRuff", chest.darkened(0.08), Vector3(0.55, 0.74, 0.18), Vector3(0.0, 1.26, -0.58), hero)
	_add_sphere(root, "FacialDisc", chest, Vector3(0.66, 0.62, 0.23), Vector3(0.0, 2.02, -0.52), hero)
	for side in [-1.0, 1.0]:
		var tuft := Factory.cone("EarTuftDetail_%s" % ("L" if side < 0.0 else "R"), dark, 0.15, 0.55, Vector3(side * 0.38, 2.56, -0.40), 7 if hero else 5)
		tuft.rotation.z = side * 0.16
		root.add_child(tuft)
		_add_sphere(root, "EyeSocket_%s" % ("L" if side < 0.0 else "R"), dark, Vector3(0.18, 0.19, 0.09), Vector3(side * 0.23, 2.08, -0.70), hero)
		_add_sphere(root, "Iris_%s" % ("L" if side < 0.0 else "R"), Color("#efb33f"), Vector3(0.105, 0.12, 0.045), Vector3(side * 0.23, 2.08, -0.785), hero)
		_add_sphere(root, "Pupil_%s" % ("L" if side < 0.0 else "R"), Color("#11110f"), Vector3(0.045, 0.075, 0.025), Vector3(side * 0.23, 2.08, -0.825), hero)
		if hero:
			_add_sphere(root, "EyeCatchlight_%s" % ("L" if side < 0.0 else "R"), Color("#fff3d5"), Vector3.ONE * 0.018, Vector3(side * 0.25, 2.12, -0.85), true)
	var beak := Factory.cone("HookedBeak", Color("#d8a747"), 0.16, 0.53, Vector3(0.0, 1.89, -0.98), int(_detail(hero)["radial"]))
	beak.rotation.x = -PI * 0.5
	root.add_child(beak)
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.name = "WingPivot_L" if side < 0.0 else "WingPivot_R"
		wing.position = Vector3(side * 0.46, 1.48, -0.02)
		root.add_child(wing)
		_add_loft(wing, "Wing", feather.darkened(0.06), [Vector3.ZERO, Vector3(side * 0.72, 0.02, 0.22), Vector3(side * 1.34, -0.06, 0.56), Vector3(side * 1.86, -0.14, 0.88)], [Vector2(0.34, 0.18), Vector2(0.42, 0.16), Vector2(0.30, 0.11), Vector2(0.06, 0.035)], hero)
		var feather_count := 5 if hero else 3
		for feather_index in range(feather_count):
			_add_loft(wing, "PrimaryFeatherDetail_%02d" % feather_index, dark.lightened(float(feather_index) * 0.025), [Vector3(side * (0.76 + feather_index * 0.20), -0.02, 0.40 + feather_index * 0.10), Vector3(side * (1.40 + feather_index * 0.18), -0.10, 0.92 + feather_index * 0.12)], [Vector2(0.10, 0.05), Vector2(0.016, 0.010)], hero)
	var tail := Node3D.new()
	tail.name = "TailPivot"
	tail.position = Vector3(0.0, 0.88, 0.60)
	root.add_child(tail)
	for feather_index in range(-2 if hero else -1, 3 if hero else 2):
		_add_loft(tail, "TailFeatherDetail_%d" % feather_index, chest.darkened(0.18), [Vector3(feather_index * 0.10, 0.0, 0.0), Vector3(feather_index * 0.17, -0.08, 0.88)], [Vector2(0.12, 0.06), Vector2(0.018, 0.012)], hero)
	for side in [-1.0, 1.0]:
		_add_sphere(root, "Talon_%s" % ("L" if side < 0.0 else "R"), Color("#caa34d"), Vector3(0.15, 0.10, 0.23), Vector3(side * 0.23, 0.50, -0.18), hero)


func _build_turtle(root: Node3D, hero: bool) -> void:
	var skin := Color("#667052")
	var shell := Color("#96895a")
	var dark := Color("#454732")
	root.scale = Vector3.ONE * 0.96
	_add_sphere(root, "TurtleBody", skin.darkened(0.08), Vector3(1.06, 0.44, 1.38), Vector3(0.0, 0.68, 0.04), hero)
	_add_sphere(root, "StoneShell", shell.darkened(0.16), Vector3(1.40, 0.65, 1.72), Vector3(0.0, 0.82, 0.06), hero)
	_add_sphere(root, "ShellCrown", shell, Vector3(1.17, 0.53, 1.45), Vector3(0.0, 1.05, 0.00), hero)
	var plate_count := 9 if hero else 5
	for plate_index in range(plate_count):
		var angle := TAU * float(plate_index) / float(plate_count)
		_add_sphere(root, "ShellPlateDetail_%02d" % plate_index, shell.darkened(0.08 if plate_index % 2 == 0 else 0.20), Vector3(0.27, 0.075, 0.34), Vector3(cos(angle) * 0.68, 1.29 - absf(sin(angle)) * 0.10, sin(angle) * 0.91), hero)
	_add_loft(root, "TurtleNeck", skin, [Vector3(0.0, 0.72, -0.82), Vector3(0.0, 0.74, -1.24), Vector3(0.0, 0.84, -1.58), Vector3(0.0, 0.84, -1.90)], [Vector2(0.28, 0.24), Vector2(0.25, 0.22), Vector2(0.33, 0.28), Vector2(0.18, 0.13)], hero)
	_add_eye_pair(root, 0.98, -1.76, 0.19, 0.067, Color("#9a763f"), hero)
	_add_sphere(root, "Beak", shell.lightened(0.12), Vector3(0.19, 0.11, 0.15), Vector3(0.0, 0.83, -2.05), hero)
	_add_quadruped_legs(root, skin.darkened(0.08), dark, 0.52, 0.43, 0.88, 0.88, 0.38, hero)
	var tail := Node3D.new()
	tail.name = "TailPivot"
	tail.position = Vector3(0.0, 0.64, 1.60)
	root.add_child(tail)
	var tail_mesh := Factory.cone("ShortTail", skin.darkened(0.12), 0.17, 0.50, Vector3(0.0, 0.0, 0.20), int(_detail(hero)["radial"]))
	tail_mesh.rotation.x = PI * 0.5
	tail.add_child(tail_mesh)


func _build_cheetah(root: Node3D, hero: bool) -> void:
	var coat := Color("#d7ad5e")
	var dark := Color("#352820")
	var cream := Color("#ead39c")
	root.scale = Vector3.ONE * 1.02
	_add_loft(root, "CheetahOrganicBody", coat, [
		Vector3(0.0, 1.08, 1.42), Vector3(0.0, 1.13, 0.72), Vector3(0.0, 1.16, -0.05),
		Vector3(0.0, 1.26, -0.76), Vector3(0.0, 1.53, -1.22), Vector3(0.0, 1.63, -1.64), Vector3(0.0, 1.50, -2.08),
	], [
		Vector2(0.28, 0.27), Vector2(0.48, 0.35), Vector2(0.49, 0.36), Vector2(0.41, 0.39),
		Vector2(0.30, 0.29), Vector2(0.35, 0.29), Vector2(0.14, 0.10),
	], hero)
	_add_sphere(root, "HindQuarter", coat.darkened(0.025), Vector3(0.49, 0.40, 0.56), Vector3(0.0, 1.10, 0.78), hero)
	_add_sphere(root, "Muzzle", cream, Vector3(0.38, 0.23, 0.27), Vector3(0.0, 1.50, -2.15), hero)
	for side in [-1.0, 1.0]:
		_add_round_ear(root, side, Vector3(side * 0.29, 2.00, -1.52), Vector3(0.18, 0.21, 0.12), dark, Color("#8f6758"), hero)
		var tear_mark := _add_sphere(root, "TearMarkDetail_%s" % ("L" if side < 0.0 else "R"), dark, Vector3(0.045, 0.22, 0.035), Vector3(side * 0.17, 1.59, -2.29), hero)
		tear_mark.rotation.z = side * 0.18
	_add_eye_pair(root, 1.74, -2.04, 0.18, 0.068, Color("#b47d36"), hero)
	_add_sphere(root, "Nose", Color("#201b18"), Vector3(0.15, 0.10, 0.10), Vector3(0.0, 1.48, -2.42), hero)
	var spot_count := 22 if hero else 12
	for spot_index in range(spot_count):
		var row := spot_index / (6 if hero else 4)
		var column := spot_index % (6 if hero else 4)
		var side := -1.0 if column < (3 if hero else 2) else 1.0
		var column_local := column % (3 if hero else 2)
		_add_sphere(root, "CoatSpotDetail_%02d" % spot_index, dark, Vector3(0.055 + column_local * 0.008, 0.035, 0.072), Vector3(side * (0.38 + column_local * 0.045), 1.20 + float(row) * 0.10, 0.82 - float(row) * 0.48), hero)
	_add_quadruped_legs(root, coat.darkened(0.07), dark, 0.98, 1.02, 0.43, 0.80, 0.29, hero)
	var tail := _add_tail(root, Vector3(0.0, 1.10, 1.31), [Vector3.ZERO, Vector3(0.16, 0.08, 0.66), Vector3(0.42, 0.28, 1.32), Vector3(0.48, 0.48, 1.96)], [Vector2(0.13, 0.13), Vector2(0.14, 0.13), Vector2(0.11, 0.10), Vector2(0.055, 0.055)], coat.darkened(0.08), hero)
	_add_sphere(tail, "TailTipDetail", dark, Vector3(0.15, 0.14, 0.30), Vector3(0.48, 0.49, 2.04), hero)


func _build_hyena(root: Node3D, hero: bool) -> void:
	var coat := Color("#a98b56")
	var dark := Color("#3f3328")
	var light := Color("#cbb889")
	root.scale = Vector3.ONE * 1.02
	_add_loft(root, "HyenaOrganicBody", coat, [
		Vector3(0.0, 0.92, 1.24), Vector3(0.0, 1.05, 0.62), Vector3(0.0, 1.22, -0.10),
		Vector3(0.0, 1.48, -0.72), Vector3(0.0, 1.68, -1.16), Vector3(0.0, 1.73, -1.58), Vector3(0.0, 1.54, -2.04), Vector3(0.0, 1.40, -2.34),
	], [
		Vector2(0.34, 0.33), Vector2(0.57, 0.44), Vector2(0.60, 0.48), Vector2(0.56, 0.58),
		Vector2(0.41, 0.42), Vector2(0.44, 0.36), Vector2(0.28, 0.20), Vector2(0.15, 0.11),
	], hero)
	_add_sphere(root, "ShoulderMass", coat.darkened(0.06), Vector3(0.60, 0.62, 0.53), Vector3(0.0, 1.53, -0.66), hero)
	var mane_count := 9 if hero else 5
	for mane_index in range(mane_count):
		var ratio := float(mane_index) / float(maxi(mane_count - 1, 1))
		var mane := Factory.cone("BackManeDetail_%02d" % mane_index, dark, 0.095, 0.36 + sin(ratio * PI) * 0.16, Vector3(0.0, 1.93, lerpf(0.52, -1.34, ratio)), 6)
		root.add_child(mane)
	for side in [-1.0, 1.0]:
		_add_round_ear(root, side, Vector3(side * 0.35, 2.16, -1.47), Vector3(0.28, 0.35, 0.17), dark, Color("#9a7568"), hero)
	_add_sphere(root, "Muzzle", light.darkened(0.18), Vector3(0.39, 0.25, 0.42), Vector3(0.0, 1.45, -2.20), hero)
	_add_eye_pair(root, 1.76, -2.00, 0.23, 0.070, Color("#b8863e"), hero)
	_add_sphere(root, "Nose", Color("#1d1b18"), Vector3(0.18, 0.12, 0.13), Vector3(0.0, 1.41, -2.56), hero)
	var spot_count := 14 if hero else 8
	for spot_index in range(spot_count):
		var side := -1.0 if spot_index % 2 == 0 else 1.0
		var row := spot_index / 2
		_add_sphere(root, "CoatSpotDetail_%02d" % spot_index, dark, Vector3(0.075, 0.045, 0.10), Vector3(side * (0.47 + float(row % 2) * 0.04), 1.38 + float(row % 3) * 0.09, 0.86 - float(row) * 0.30), hero)
	_add_quadruped_legs(root, coat.darkened(0.15), dark, 0.90, 0.92, 0.52, 0.76, 0.34, hero)
	_add_tail(root, Vector3(0.0, 0.99, 1.15), [Vector3.ZERO, Vector3(0.10, 0.10, 0.48), Vector3(0.15, 0.20, 0.88)], [Vector2(0.19, 0.18), Vector2(0.25, 0.23), Vector2(0.08, 0.07)], dark, hero)
