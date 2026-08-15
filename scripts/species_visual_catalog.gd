class_name SpeciesVisualCatalog
extends RefCounted

const SkeletonRig = preload("res://scripts/species_skeleton_rig.gd")
const MODEL_ROOT := "res://assets/models/animals"
const EXTERNAL_SPECIES := ["rabbit", "wolf", "deer", "bear", "eagle", "crocodile"]
const SKELETAL_SPECIES := ["rabbit", "wolf"]


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
		SkeletonRig.upgrade(instance, species_id)
	return instance
