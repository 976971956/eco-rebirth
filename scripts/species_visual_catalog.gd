class_name SpeciesVisualCatalog
extends RefCounted

const SkeletonRig = preload("res://scripts/species_skeleton_rig.gd")
const FlightRig = preload("res://scripts/species_flight_rig.gd")
const CrocodileRig = preload("res://scripts/species_crocodile_rig.gd")
const FUR_ATLAS_SHADER = preload("res://assets/shaders/quadruped_fur_atlas.gdshader")
const FUR_ALBEDO = preload("res://assets/textures/animals/shared/quadruped_fur_atlas_albedo.png")
const FUR_NORMAL = preload("res://assets/textures/animals/shared/quadruped_fur_atlas_normal.png")
const FUR_ROUGHNESS = preload("res://assets/textures/animals/shared/quadruped_fur_atlas_roughness.png")
const MODEL_ROOT := "res://assets/models/animals"
const MODEL_V2_ROOT := "res://assets/models_v2/animals"
const EXTERNAL_SPECIES := [
	"rabbit", "fox", "deer", "wolf", "snake", "bear",
	"boar", "raccoon", "porcupine", "crocodile", "capybara", "otter", "lynx", "goat", "wolverine",
	"bison", "zebra", "elephant", "tiger", "monkey", "owl", "moose", "turtle", "cheetah",
	"rhino", "gorilla", "eagle", "hippo", "hyena", "lion",
]
const V2_SPECIES := EXTERNAL_SPECIES
const AUTHORED_SOURCE_SPECIES := ["rabbit", "wolf", "fox", "deer", "snake", "bear", "boar"]
const THIRD_BATCH_SPECIES := ["lion", "tiger", "lynx", "elephant", "rhino", "hippo", "bison", "moose", "goat", "monkey", "gorilla"]
const FOURTH_BATCH_SPECIES := ["raccoon", "porcupine", "capybara", "otter", "wolverine", "zebra", "owl", "turtle", "cheetah", "hyena"]
const SKELETAL_SPECIES := [
	"rabbit", "fox", "deer", "wolf", "bear", "boar", "raccoon", "porcupine", "capybara", "otter",
	"lynx", "goat", "wolverine", "bison", "zebra", "elephant", "tiger", "monkey", "moose", "turtle",
	"cheetah", "rhino", "gorilla", "hippo", "hyena", "lion",
]
const LEGACY_SKELETAL_SPECIES := ["rabbit", "wolf", "deer", "bear"]
const FLIGHT_RIG_SPECIES := ["owl", "eagle"]
const LONG_BODY_RIG_SPECIES := ["snake", "crocodile"]
const VISUAL_SCALE_CONTRACT := {
	"rabbit": 1.02,
	"wolf": 1.10,
	"deer": 1.08,
	"bear": 1.22,
	"eagle": 1.04,
	"crocodile": 1.18,
	"fox": 0.88,
	"snake": 0.98,
	"boar": 1.06,
	"raccoon": 0.88,
	"porcupine": 0.96,
	"capybara": 1.04,
	"otter": 0.92,
	"wolverine": 0.94,
	"zebra": 1.08,
	"owl": 0.96,
	"turtle": 0.96,
	"cheetah": 1.02,
	"hyena": 1.02,
	"lion": 1.08,
	"tiger": 1.12,
	"lynx": 0.92,
	"elephant": 1.32,
	"rhino": 1.26,
	"hippo": 1.28,
	"bison": 1.18,
	"moose": 1.16,
	"goat": 0.90,
	"monkey": 0.88,
	"gorilla": 1.14,
}
const FUR_ATLAS_REGIONS := {
	"rabbit": Vector2(0.0, 0.0),
	"wolf": Vector2(0.5, 0.0),
	"deer": Vector2(0.0, 0.5),
	"bear": Vector2(0.5, 0.5),
}
const DETAIL_LOD_TOKENS := ["detail", "iris", "pupil", "catchlight", "innerear", "whisker", "stripe", "spot", "quill", "mane", "plate", "antlerbranch", "tooth", "claw"]
const ESSENTIAL_SILHOUETTE_TOKENS := ["wingbody", "wingfeather", "tailfeather", "beakdetail", "trunkdetail", "shelldetail"]
const HERO_DETAIL_RANGE := 28.0
const MOBILE_DETAIL_RANGE := 20.0
const HERO_BODY_RANGE := 82.0
const MOBILE_BODY_RANGE := 68.0


static func supports(species_id: String) -> bool:
	return species_id in EXTERNAL_SPECIES


static func profile_for(player_controlled: bool, quality: String) -> String:
	return "hero" if player_controlled and quality != "low" else "mobile"


static func model_path(species_id: String, profile: String) -> String:
	if not supports(species_id):
		return ""
	var safe_profile := profile if profile in ["hero", "mobile"] else "mobile"
	if species_id in V2_SPECIES:
		var v2_path := "%s/%s/%s_%s.glb" % [MODEL_V2_ROOT, species_id, species_id, safe_profile]
		if ResourceLoader.exists(v2_path):
			return v2_path
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
		instance.scale = Vector3.ONE * float(VISUAL_SCALE_CONTRACT.get(species_id, 1.0))
		instance.set_meta("species_id", species_id)
		instance.set_meta("visual_profile", profile)
		instance.set_meta("visual_scale_contract", float(VISUAL_SCALE_CONTRACT.get(species_id, 1.0)))
		instance.set_meta("automatic_detail_lod", true)
		var uses_v2 := path.begins_with(MODEL_V2_ROOT)
		if uses_v2:
			# Blender's exported meshes currently arrive facing +Z. EcoActor, camera
			# steering and combat all use Godot's -Z forward convention.
			instance.rotation.y = PI
			if species_id in FLIGHT_RIG_SPECIES:
				FlightRig.upgrade(instance, species_id)
			elif species_id in LONG_BODY_RIG_SPECIES:
				CrocodileRig.upgrade(instance, species_id)
			else:
				SkeletonRig.upgrade(instance, species_id)
		elif species_id in LEGACY_SKELETAL_SPECIES:
			instance.set_meta("fur_atlas_region", FUR_ATLAS_REGIONS[species_id])
			_apply_shared_fur_materials(instance, species_id)
			SkeletonRig.upgrade(instance, species_id)
		elif species_id == "eagle":
			FlightRig.upgrade(instance, species_id)
		elif species_id == "crocodile":
			CrocodileRig.upgrade(instance, species_id)
		_apply_automatic_detail_lod(instance, profile)
	return instance


static func _apply_shared_fur_materials(node: Node, species_id: String) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var source := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
				if source == null or not "_coat_pbr" in source.resource_name:
					continue
				var material := ShaderMaterial.new()
				material.resource_name = "%s_coat_atlas_pbr" % species_id
				material.shader = FUR_ATLAS_SHADER
				material.set_shader_parameter("albedo_atlas", FUR_ALBEDO)
				material.set_shader_parameter("normal_atlas", FUR_NORMAL)
				material.set_shader_parameter("roughness_atlas", FUR_ROUGHNESS)
				material.set_shader_parameter("coat_tint", source.albedo_color)
				material.set_shader_parameter("atlas_offset", FUR_ATLAS_REGIONS[species_id])
				material.set_shader_parameter("pattern_scale", 2.55 if species_id == "rabbit" else 2.10 if species_id == "bear" else 2.35)
				mesh_instance.set_surface_override_material(surface_index, material)
	for child in node.get_children():
		_apply_shared_fur_materials(child, species_id)


static func _apply_automatic_detail_lod(node: Node, profile: String) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var lowered := str(mesh_instance.name).to_lower()
		# Some generated parts carry the generic `Detail` suffix even though they
		# define the animal's silhouette. Hiding wings, the elephant trunk or the
		# turtle shell at normal gameplay distance leaves only the small torso and
		# makes the model look like a bare rig.
		var is_essential_silhouette := ESSENTIAL_SILHOUETTE_TOKENS.any(func(token: String): return token in lowered)
		var is_detail := not is_essential_silhouette and DETAIL_LOD_TOKENS.any(func(token: String): return token in lowered)
		mesh_instance.visibility_range_end = (HERO_DETAIL_RANGE if profile == "hero" else MOBILE_DETAIL_RANGE) if is_detail else (HERO_BODY_RANGE if profile == "hero" else MOBILE_BODY_RANGE)
		mesh_instance.visibility_range_end_margin = 3.0 if is_detail else 7.0
		mesh_instance.set_meta("lod_class", "detail" if is_detail else "silhouette" if is_essential_silhouette else "body")
	for child in node.get_children():
		_apply_automatic_detail_lod(child, profile)
