extends SceneTree

const Factory = preload("res://scripts/low_poly_factory.gd")
const Catalog = preload("res://scripts/species_catalog.gd")

const OUTPUT_ROOT := "res://assets/models/animals"
const REPRESENTATIVE_SPECIES := ["rabbit", "wolf", "deer", "bear", "eagle", "crocodile"]

var failures: Array[String] = []


func _initialize() -> void:
	_generate.call_deferred()


func _generate() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	for species_id in REPRESENTATIVE_SPECIES:
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
		print("SPECIES_GLB_GENERATION_OK: 6 species × hero/mobile")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _bake_export_materials(root: Node, species_id: String) -> void:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		if mesh_instance.mesh != null and mesh_instance.material_override != null:
			var baked_mesh := mesh_instance.mesh.duplicate()
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
	if species_id in ["rabbit", "wolf"]:
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
	_add_eye_pair(root, 1.76, -1.67, 0.22, 0.063, Color("#e1b13f"), hero)
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
		_add_sphere(root, "Talon", Color("#c9a346"), Vector3(0.15, 0.10, 0.23), Vector3(side * 0.23, 0.55, -0.18), hero)


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
	_add_eye_pair(root, 0.88, -2.34, 0.29, 0.072, Color("#c8c04c"), hero)
	for side in [-1.0, 1.0]:
		_add_sphere(root, "Nostril", Color("#26352a"), Vector3(0.07, 0.045, 0.06), Vector3(side * 0.17, 0.60, -3.22), hero)
	var plate_count := 12 if hero else 7
	for plate_index in range(plate_count):
		var ratio := float(plate_index) / float(maxi(plate_count - 1, 1))
		var plate_z := lerpf(1.42, -1.92, ratio)
		var plate_height := lerpf(0.16, 0.24, sin(ratio * PI))
		var plate := Factory.cone("BackScute", dark.lightened(0.04), 0.14, plate_height, Vector3(0.0, 1.06 - absf(ratio - 0.48) * 0.22, plate_z), 6)
		root.add_child(plate)
	if hero:
		for side in [-1.0, 1.0]:
			for tooth_index in range(6):
				var tooth := Factory.cone("Tooth", Color("#ded6b5"), 0.035, 0.17, Vector3(side * 0.34, 0.47, -1.92 - tooth_index * 0.20), 5)
				tooth.rotation.x = PI
				root.add_child(tooth)
