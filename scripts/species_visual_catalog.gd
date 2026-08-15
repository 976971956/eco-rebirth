class_name SpeciesVisualCatalog
extends RefCounted

const SkeletonRig = preload("res://scripts/species_skeleton_rig.gd")
const FUR_ALBEDO = preload("res://assets/textures/animals/shared/fur_micro_albedo_ai.png")
const FUR_NORMAL = preload("res://assets/textures/animals/shared/fur_micro_normal_ai.png")
const FUR_ROUGHNESS = preload("res://assets/textures/animals/shared/fur_micro_roughness_ai.png")
const MODEL_ROOT := "res://assets/models/animals"
const EXTERNAL_SPECIES := ["rabbit", "wolf", "deer", "bear", "eagle", "crocodile"]
const SKELETAL_SPECIES := ["rabbit", "wolf", "deer", "bear"]


static func supports(species_id: String) -> bool:
	return species_id in EXTERNAL_SPECIES


static func profile_for(player_controlled: bool, quality: String) -> String:
	return "hero" if player_controlled and quality != "low" else "mobile"


static func model_path(species_id: String, profile: String) -> String:
	if not supports(species_id):
		return ""
	var safe_profile := profile if profile in ["hero", "mobile"] else "mobile"
	return "%s/%s/%s_%s.glb" % [MODEL_ROOT, species_id, species_id, safe_profile]


static func instantiate(species_id: String, profile: String) -> Node3D:
	var path := model_path(species_id, profile)
	if path == "" or not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate() as Node3D
	if instance != null:
		instance.name = "ExternalSpeciesModel"
		instance.set_meta("species_id", species_id)
		instance.set_meta("visual_profile", profile)
		if species_id in SKELETAL_SPECIES:
			_apply_shared_fur_materials(instance)
		SkeletonRig.upgrade(instance, species_id)
	return instance


static func _apply_shared_fur_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var source := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
				if source == null or not "_coat_pbr" in source.resource_name:
					continue
				var material := source.duplicate() as StandardMaterial3D
				material.albedo_texture = FUR_ALBEDO
				material.normal_enabled = true
				material.normal_texture = FUR_NORMAL
				material.normal_scale = 0.72
				material.roughness_texture = FUR_ROUGHNESS
				material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				material.texture_repeat = true
				material.uv1_scale = Vector3(2.35, 2.35, 2.35)
				mesh_instance.set_surface_override_material(surface_index, material)
	for child in node.get_children():
		_apply_shared_fur_materials(child)
