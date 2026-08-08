class_name EcoWorld
extends Node3D

const Factory = preload("res://scripts/low_poly_factory.gd")
const FoodPatchScript = preload("res://scripts/food_patch.gd")
const Catalog = preload("res://scripts/species_catalog.gd")

const COLLAPSE_MIN_RADIUS_RATIO := 0.22
const COLLAPSE_SHRINK_SECONDS := 90.0
const MIN_PASSAGE_GAP := 3.4

const REGION_NAMES := {
	"forest": "古木林地",
	"grassland": "日照草原",
	"wetland": "浅水湿地",
	"highland": "岩丘高地",
}

var world_size: float = 86.0
var density_scale: float = 1.0
var campaign_level: int = 1
var weather_id: String = "clear"
var time_phase: String = "day"
var visual_effects_enabled: bool = true
var quality_preset: String = "medium"
var collapse_active: bool = false
var collapse_radius: float = INF
var rng := RandomNumberGenerator.new()
var obstacles: Array[Vector3] = []
var obstacle_radii: Array[float] = []
var obstacle_visuals: Array[Node3D] = []
var obstacle_colliders: Array[StaticBody3D] = []
var obstacle_kinds: Array[String] = []
var food_patches: Array[Node] = []
var decoration_root: Node3D
var obstacle_root: Node3D
var environment_resource: Environment
var sun_light: DirectionalLight3D
var weather_fx_root: Node3D
var precipitation: GPUParticles3D
var base_sun_energy: float = 1.0
var lightning_timer: float = 0.0
var lightning_flash_timer: float = 0.0


func setup(seed_value: int, size_value: float = 86.0, level_value: int = 1, enable_visual_effects: bool = true, forced_weather: String = "", forced_time_phase: String = "", quality_value: String = "medium") -> void:
	rng.seed = seed_value
	world_size = size_value
	campaign_level = level_value
	visual_effects_enabled = enable_visual_effects
	quality_preset = quality_value if quality_value in ["low", "medium", "high"] else "medium"
	density_scale = clampf(world_size / 86.0, 1.0, 3.0)
	name = "GeneratedForest_%s" % seed_value
	_select_world_conditions()
	if forced_weather in ["clear", "rain", "fog", "storm"]:
		weather_id = forced_weather
	if forced_time_phase in ["day", "night"]:
		time_phase = forced_time_phase
	_build_environment()
	_build_weather_visuals()
	_build_ground()
	_build_biome_regions()
	_build_ground_details()
	_build_paths_and_pond()
	_build_trees()
	_build_rocks()
	_build_bushes()
	_build_food()
	_build_visible_border()
	_build_border_hills()


func _select_world_conditions() -> void:
	time_phase = "night" if campaign_level >= 6 and rng.randf() < 0.48 else "day"
	weather_id = "clear"
	if campaign_level >= 7:
		var weather_pool: Array[String] = ["clear", "rain", "fog", "storm"]
		weather_id = weather_pool[rng.randi_range(0, weather_pool.size() - 1)]


func _build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment_resource = environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#203342") if time_phase == "night" else Color("#a9c7b0")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#7890a9") if time_phase == "night" else Color("#c9dac3")
	environment.ambient_light_energy = 0.34 if time_phase == "night" else 0.56
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.98
	environment.adjustment_contrast = 1.10
	environment.adjustment_saturation = 1.00
	environment.fog_enabled = true
	environment.fog_light_color = Color("#65798b") if time_phase == "night" else Color("#b9cfb8")
	environment.fog_light_energy = 0.55
	environment.fog_density = 0.012 if weather_id == "fog" else (0.0075 if weather_id == "storm" else (0.0042 if weather_id == "rain" else 0.0018))
	environment.fog_sky_affect = 0.30
	if weather_id == "storm":
		environment.background_color = environment.background_color.darkened(0.28)
		environment.adjustment_saturation = 0.76
	elif weather_id == "rain":
		environment.background_color = environment.background_color.darkened(0.12)
		environment.adjustment_saturation = 0.88
	elif weather_id == "fog":
		environment.background_color = environment.background_color.lightened(0.08)
		environment.adjustment_contrast = 0.94
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun_light = sun
	sun.name = "Sun"
	sun.light_color = Color("#afc9e9") if time_phase == "night" else Color("#ffe0aa")
	sun.light_energy = (0.30 if time_phase == "night" else 1.00) * (0.58 if weather_id == "storm" else (0.76 if weather_id in ["rain", "fog"] else 1.0))
	base_sun_energy = sun.light_energy
	sun.shadow_enabled = quality_preset != "low"
	sun.directional_shadow_max_distance = minf(world_size * (0.82 if quality_preset == "high" else 0.55), 150.0 if quality_preset == "high" else 88.0)
	sun.directional_shadow_fade_start = 0.78
	sun.rotation_degrees = Vector3(-48.0, -38.0, 0.0)
	add_child(sun)

	var sky_fill := DirectionalLight3D.new()
	sky_fill.name = "SkyFill"
	sky_fill.light_color = Color("#9fc4cf")
	sky_fill.light_energy = 0.18
	sky_fill.shadow_enabled = false
	sky_fill.rotation_degrees = Vector3(-62.0, 138.0, 0.0)
	add_child(sky_fill)


func _build_weather_visuals() -> void:
	if not visual_effects_enabled or weather_id not in ["rain", "storm"]:
		return
	weather_fx_root = Node3D.new()
	weather_fx_root.name = "LocalWeatherFX"
	add_child(weather_fx_root)
	precipitation = GPUParticles3D.new()
	precipitation.name = "StormRain" if weather_id == "storm" else "Rain"
	precipitation.amount = _quality_particle_amount()
	precipitation.lifetime = 1.45
	precipitation.fixed_fps = 18 if quality_preset == "low" else (24 if quality_preset == "medium" else 30)
	precipitation.local_coords = true
	precipitation.visibility_aabb = AABB(Vector3(-27.0, -13.0, -27.0), Vector3(54.0, 30.0, 54.0))
	precipitation.position = Vector3(0.0, 11.0, 0.0)
	var rain_mesh := BoxMesh.new()
	rain_mesh.size = Vector3(0.025, 0.82 if weather_id == "storm" else 0.64, 0.025)
	var rain_material := StandardMaterial3D.new()
	rain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_material.albedo_color = Color(0.68, 0.84, 0.95, 0.68 if weather_id == "storm" else 0.52)
	rain_mesh.material = rain_material
	precipitation.draw_pass_1 = rain_mesh
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(23.0, 7.0, 23.0)
	process_material.direction = Vector3(0.20 if weather_id == "storm" else 0.05, -1.0, 0.08).normalized()
	process_material.spread = 4.0 if weather_id == "storm" else 2.0
	process_material.initial_velocity_min = 18.0 if weather_id == "storm" else 14.0
	process_material.initial_velocity_max = 24.0 if weather_id == "storm" else 18.0
	process_material.gravity = Vector3(3.8 if weather_id == "storm" else 0.7, -5.5, 1.4 if weather_id == "storm" else 0.2)
	precipitation.process_material = process_material
	weather_fx_root.add_child(precipitation)
	precipitation.emitting = true
	if weather_id == "storm":
		lightning_timer = rng.randf_range(3.5, 7.5)


func apply_quality_preset(value: String) -> void:
	quality_preset = value if value in ["low", "medium", "high"] else "medium"
	if sun_light != null:
		sun_light.shadow_enabled = quality_preset != "low"
		sun_light.directional_shadow_max_distance = minf(world_size * (0.82 if quality_preset == "high" else 0.55), 150.0 if quality_preset == "high" else 88.0)
	if precipitation != null:
		precipitation.amount = _quality_particle_amount()
		precipitation.fixed_fps = 18 if quality_preset == "low" else (24 if quality_preset == "medium" else 30)


func _quality_particle_amount() -> int:
	if weather_id == "storm":
		return {"low": 150, "medium": 280, "high": 440}.get(quality_preset, 280)
	return {"low": 100, "medium": 200, "high": 310}.get(quality_preset, 200)


func _build_ground() -> void:
	decoration_root = Node3D.new()
	decoration_root.name = "Decoration"
	add_child(decoration_root)
	obstacle_root = Node3D.new()
	obstacle_root.name = "Obstacles"
	add_child(obstacle_root)

	var ground := MeshInstance3D.new()
	ground.name = "ForestFloor"
	var plane := PlaneMesh.new()
	# Render extra terrain outside the playable collision square so the camera
	# never exposes a hard edge when the player reaches the perimeter.
	plane.size = Vector2(world_size * 1.72, world_size * 1.72)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	ground.mesh = plane
	ground.material_override = Factory.material(Color("#294936"))
	decoration_root.add_child(ground)

	var collision_body := StaticBody3D.new()
	collision_body.name = "GroundCollision"
	collision_body.collision_layer = 2
	collision_body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(world_size, 0.4, world_size)
	collision.shape = shape
	collision.position.y = -0.22
	collision_body.add_child(collision)
	add_child(collision_body)


func _build_biome_regions() -> void:
	var half_extent := world_size * 0.245
	var region_size := Vector2(world_size * 0.495, world_size * 0.495)
	_add_region_ground("AncientForest", Vector3(-half_extent, 0.003, -half_extent), region_size, Color("#3d6742"))
	_add_region_ground("SunGrassland", Vector3(half_extent, 0.003, -half_extent), region_size, Color("#6f8b4b"))
	_add_region_ground("ShallowWetland", Vector3(-half_extent, 0.003, half_extent), region_size, Color("#47756b"))
	_add_region_ground("RockHighland", Vector3(half_extent, 0.003, half_extent), region_size, Color("#716e4c"))
	_build_region_marker("古木林地", Vector3(-world_size * 0.27, 0.0, -world_size * 0.27), Color("#9dd19b"))
	_build_region_marker("日照草原", Vector3(world_size * 0.27, 0.0, -world_size * 0.27), Color("#e1d68a"))
	_build_region_marker("浅水湿地", Vector3(-world_size * 0.27, 0.0, world_size * 0.27), Color("#8fd5cf"))
	_build_region_marker("岩丘高地", Vector3(world_size * 0.27, 0.0, world_size * 0.27), Color("#d4c493"))


func _add_region_ground(node_name: String, center: Vector3, size_value: Vector2, tint: Color) -> void:
	var region := MeshInstance3D.new()
	region.name = node_name
	var plane := PlaneMesh.new()
	plane.size = size_value
	region.mesh = plane
	region.material_override = Factory.material(tint)
	region.position = center
	decoration_root.add_child(region)


func _build_region_marker(title: String, marker_position: Vector3, tint: Color) -> void:
	var marker := Node3D.new()
	marker.name = "RegionMarker_%s" % title
	marker.position = marker_position
	decoration_root.add_child(marker)
	marker.add_child(Factory.tapered_cylinder("MarkerPost", Color("#57483b"), 0.11, 0.08, 1.45, Vector3(0.0, 0.72, 0.0), 7))
	var sign := Factory.box("MarkerSign", tint.darkened(0.38), Vector3(2.55, 0.58, 0.12), Vector3(0.0, 1.52, 0.0))
	marker.add_child(sign)
	var label := Label3D.new()
	label.text = title
	label.font = load("res://assets/fonts/NotoSansSC-VF.ttf") as Font
	label.font_size = 46
	label.outline_size = 9
	label.modulate = tint
	label.outline_modulate = Color(0.02, 0.07, 0.04, 0.96)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.012
	label.position = Vector3(0.0, 1.55, 0.10)
	marker.add_child(label)


func _build_ground_details() -> void:
	var patch_colors := [Color("#3e6140"), Color("#52764a"), Color("#5d7d50"), Color("#385b42")]
	var patch_count := int(round(18.0 * density_scale))
	for i in range(patch_count):
		var radius := rng.randf_range(2.2, 5.8)
		var pos := Vector3(rng.randf_range(-world_size * 0.44, world_size * 0.44), 0.008 + i * 0.00005, rng.randf_range(-world_size * 0.44, world_size * 0.44))
		var patch := Factory.disc("GroundMottle", patch_colors[rng.randi_range(0, patch_colors.size() - 1)], radius, 0.018, pos, rng.randi_range(8, 12))
		patch.scale.z = rng.randf_range(0.48, 0.92)
		patch.rotation.y = rng.randf_range(0.0, TAU)
		decoration_root.add_child(patch)


func _build_paths_and_pond() -> void:
	var trail_color := Color("#71845a")
	var path_half := world_size * 0.46
	_add_ground_strip("EastWestMainTrail", Vector2(-path_half, 0.0), Vector2(path_half, 0.0), 6.8, trail_color.lightened(0.04), 0.022)
	_add_ground_strip("NorthSouthMainTrail", Vector2(0.0, -path_half), Vector2(0.0, path_half), 6.8, trail_color, 0.023)
	for trail_index in range(3):
		var angle := -0.55 + trail_index * 1.92 + rng.randf_range(-0.18, 0.18)
		var previous := Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
		for segment_index in range(6):
			var distance := world_size * 0.068 + segment_index * world_size * 0.010
			angle += rng.randf_range(-0.20, 0.20)
			var next := previous + Vector2(cos(angle), sin(angle)) * distance
			_add_ground_strip("ForestTrail", previous, next, rng.randf_range(3.1, 4.5), trail_color.lightened(rng.randf_range(-0.035, 0.035)), 0.018 + trail_index * 0.002)
			previous = next

	var stream_points: Array[Vector2] = [
		Vector2(-16.0, -12.0), Vector2(-9.0, -9.4), Vector2(-2.0, -10.2),
		Vector2(5.0, -7.6), Vector2(12.0, -8.5), Vector2(18.0, -5.2)
	]
	for i in range(stream_points.size() - 1):
		_add_ground_strip("StreamBank", stream_points[i], stream_points[i + 1], 7.6, Color("#657b57"), 0.030)
		_add_ground_strip("ShallowStream", stream_points[i], stream_points[i + 1], 5.4, Color(0.20, 0.56, 0.60, 0.90), 0.044)
	for stone_index in range(9):
		var t := float(stone_index) / 8.0
		var stone_pos := Vector3(lerpf(-4.2, 2.6, t), 0.10, lerpf(-10.0, -8.35, t) + sin(t * TAU) * 0.28)
		var stone := Factory.sphere("SteppingStone", Color("#818a79").lightened(rng.randf_range(-0.05, 0.08)), Vector3(0.72, 0.20, 0.58), stone_pos, 8, 4)
		stone.rotation.y = rng.randf_range(-0.5, 0.5)
		decoration_root.add_child(stone)

	var basin_center := Vector3(-world_size * 0.25, 0.052, world_size * 0.25)
	var basin := Factory.disc("WetlandBasin", Color(0.17, 0.55, 0.58, 0.74), world_size * 0.145, 0.026, basin_center, 18)
	basin.scale.z = 0.72
	decoration_root.add_child(basin)
	var deep_center := Factory.disc("DeepWaterBand", Color(0.11, 0.42, 0.49, 0.82), world_size * 0.075, 0.028, basin_center + Vector3.UP * 0.004, 16)
	deep_center.scale.z = 0.68
	decoration_root.add_child(deep_center)


func _add_ground_strip(node_name: String, start: Vector2, finish: Vector2, width: float, color: Color, height: float) -> void:
	var delta := finish - start
	var strip := MeshInstance3D.new()
	strip.name = node_name
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(delta.length() + 0.3, width)
	strip.mesh = mesh
	var strip_material := Factory.material(color, 0.72)
	if color.a < 0.999:
		strip_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	strip.material_override = strip_material
	strip.position = Vector3((start.x + finish.x) * 0.5, height, (start.y + finish.y) * 0.5)
	strip.rotation.y = -atan2(delta.y, delta.x)
	decoration_root.add_child(strip)


func _build_trees() -> void:
	var tree_count := int(round(30 * density_scale))
	for i in range(tree_count):
		var radius := rng.randf_range(0.55, 0.9)
		# The visible trunk is radius * 0.48. Keep its collider close to the
		# silhouette so apparently open paths do not contain invisible walls.
		var collision_radius := maxf(radius * 0.56, 0.32)
		var pos := _random_decor_position(7.0, collision_radius)
		var height := rng.randf_range(3.4, 5.5)
		obstacles.append(pos)
		obstacle_radii.append(collision_radius)
		var tree := Node3D.new()
		var broadleaf := rng.randf() < 0.32
		tree.name = "BroadleafTree" if broadleaf else "PineTree"
		tree.position = pos
		tree.rotation.y = rng.randf_range(0.0, TAU)
		decoration_root.add_child(tree)
		var trunk_color := Color("#57483b").lightened(rng.randf_range(-0.04, 0.06))
		var trunk := Factory.tapered_cylinder("Trunk", trunk_color, radius * 0.50, radius * 0.37, height, Vector3(0.0, height * 0.5, 0.0), 8)
		tree.add_child(trunk)
		var leaf_color := Color.from_hsv(rng.randf_range(0.285, 0.36), rng.randf_range(0.38, 0.56), rng.randf_range(0.34, 0.50))
		if broadleaf:
			for cluster_index in range(5):
				var cluster_angle := TAU * float(cluster_index) / 5.0 + rng.randf_range(-0.25, 0.25)
				var cluster_pos := Vector3(cos(cluster_angle) * 0.92, height + 0.75 + (cluster_index % 2) * 0.72, sin(cluster_angle) * 0.92)
				var cluster := Factory.sphere("LeafCluster", leaf_color.lightened(rng.randf_range(-0.06, 0.08)), Vector3(2.2, 1.55, 1.95), cluster_pos, 8, 5)
				tree.add_child(cluster)
			var crown_top := Factory.sphere("LeafCrown", leaf_color.lightened(0.045), Vector3(2.1, 1.75, 2.0), Vector3(0.0, height + 2.0, 0.0), 9, 5)
			tree.add_child(crown_top)
		else:
			for layer in range(3):
				var crown_radius := 2.05 - layer * 0.30
				var crown := Factory.cone("PineCrown", leaf_color.lightened(layer * 0.035), crown_radius, 3.0, Vector3(0.0, height + 0.45 + layer * 1.02, 0.0), 9)
				crown.rotation.y = layer * 0.42
				tree.add_child(crown)
		# One collider per tree. This used to be inside the crown loop, creating
		# three identical StaticBody3D nodes at the same position.
		var tree_collider := Factory.add_static_cylinder(obstacle_root, collision_radius, height, Vector3(pos.x, height * 0.5, pos.z))
		obstacle_visuals.append(tree)
		obstacle_colliders.append(tree_collider)
		obstacle_kinds.append("tree")


func _build_rocks() -> void:
	var rock_count := int(round(14 * density_scale))
	for i in range(rock_count):
		var scale_value := Vector3(rng.randf_range(1.0, 2.2), rng.randf_range(0.7, 1.45), rng.randf_range(0.9, 1.8))
		var collision_radius := maxf(scale_value.x, scale_value.z) * 0.50
		var pos := _random_decor_position(5.0, collision_radius)
		obstacles.append(pos)
		obstacle_radii.append(collision_radius)
		var rock_color := Color("#727a70").lightened(rng.randf_range(-0.07, 0.07))
		var rock := Factory.sphere("Rock", rock_color, scale_value, Vector3(pos.x, scale_value.y * 0.42, pos.z), 8, 5)
		rock.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.0, TAU), rng.randf_range(-0.1, 0.1))
		decoration_root.add_child(rock)
		if rng.randf() < 0.62:
			var moss := Factory.sphere("RockMoss", Color("#5f7d4e").lightened(rng.randf_range(-0.04, 0.08)), Vector3(scale_value.x * 0.62, 0.12, scale_value.z * 0.55), Vector3(pos.x, scale_value.y * 0.84, pos.z), 8, 4)
			moss.rotation.y = rock.rotation.y
			decoration_root.add_child(moss)
		var rock_collider := Factory.add_static_box(obstacle_root, Vector3(scale_value.x * 0.9, scale_value.y * 0.8, scale_value.z * 0.9), Vector3(pos.x, scale_value.y * 0.4, pos.z), rock.rotation.y)
		obstacle_visuals.append(rock)
		obstacle_colliders.append(rock_collider)
		obstacle_kinds.append("rock")


func _build_bushes() -> void:
	var bush_count := int(round(26 * density_scale))
	for i in range(bush_count):
		var pos := _random_decor_position(3.0)
		var bush := Node3D.new()
		bush.position = pos
		decoration_root.add_child(bush)
		bush.rotation.y = rng.randf_range(0.0, TAU)
		var tint := Color.from_hsv(rng.randf_range(0.27, 0.37), rng.randf_range(0.42, 0.60), rng.randf_range(0.36, 0.54))
		var bush_scale := rng.randf_range(0.78, 1.18)
		for j in range(4):
			var piece := Factory.sphere("Bush", tint.lightened(j * 0.022), Vector3(1.05, 0.72, 0.92) * bush_scale, Vector3((j - 1.5) * 0.48 * bush_scale, 0.48 + (j % 2) * 0.18, rng.randf_range(-0.28, 0.28)), 8, 5)
			bush.add_child(piece)
		if rng.randf() < 0.28:
			var flower_color: Color = [Color("#e7d58c"), Color("#d7a6a0"), Color("#b9cce5")][rng.randi_range(0, 2)]
			for flower_index in range(3):
				bush.add_child(Factory.sphere("Wildflower", flower_color, Vector3(0.13, 0.10, 0.13), Vector3((flower_index - 1) * 0.55, 1.02 + flower_index * 0.06, rng.randf_range(-0.20, 0.20)), 7, 4))


func _build_food() -> void:
	var food_count := int(round(18 * clampf(world_size / 86.0, 1.0, 4.0)))
	for i in range(food_count):
		var patch := FoodPatchScript.new()
		patch.position = _random_valid_position(3.0)
		var food_pool: Array[String]
		match region_id_at(patch.position):
			"forest": food_pool = ["berries", "mushroom", "fruit", "berries"]
			"grassland": food_pool = ["grass", "grass", "berries", "fruit"]
			"wetland": food_pool = ["fish", "fish", "mushroom", "grass"]
			_: food_pool = ["roots", "roots", "grass", "mushroom"]
		patch.setup(food_pool[rng.randi_range(0, food_pool.size() - 1)], rng)
		add_child(patch)
		food_patches.append(patch)


func _build_visible_border() -> void:
	var edge := world_size * 0.5
	var ridge_color := Color("#344b3c")
	decoration_root.add_child(Factory.box("NorthBoundary", ridge_color, Vector3(world_size + 2.0, 0.72, 1.7), Vector3(0.0, 0.30, -edge)))
	decoration_root.add_child(Factory.box("SouthBoundary", ridge_color, Vector3(world_size + 2.0, 0.72, 1.7), Vector3(0.0, 0.30, edge)))
	decoration_root.add_child(Factory.box("WestBoundary", ridge_color.darkened(0.04), Vector3(1.7, 0.72, world_size + 2.0), Vector3(-edge, 0.30, 0.0)))
	decoration_root.add_child(Factory.box("EastBoundary", ridge_color.darkened(0.04), Vector3(1.7, 0.72, world_size + 2.0), Vector3(edge, 0.30, 0.0)))


func _build_border_hills() -> void:
	var hill_count := int(round(22 * density_scale))
	for ring in range(2):
		for i in range(hill_count):
			var angle := TAU * float(i) / float(hill_count) + rng.randf_range(-0.055, 0.055)
			var distance := world_size * (0.70 + ring * 0.10) + rng.randf_range(0.0, 5.0)
			var pos := Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
			var far_color := Color("#345844") if ring == 0 else Color("#557463")
			var height := rng.randf_range(6.5, 10.5) * (1.0 + ring * 0.12)
			var hill := Factory.cone("DistantForest", far_color.lightened(rng.randf_range(-0.04, 0.04)), rng.randf_range(2.5, 4.2), height, pos + Vector3.UP * height * 0.5, 8)
			decoration_root.add_child(hill)


func trigger_collapse() -> void:
	collapse_active = true
	collapse_radius = world_size * 0.47
	var center_radius := world_size * 0.18
	for patch in food_patches:
		if not is_instance_valid(patch):
			continue
		if patch.global_position.length() < center_radius:
			patch.boost(1.8)
		else:
			patch.stop_regrow()


func _process(delta: float) -> void:
	_process_weather(delta)
	if collapse_active:
		var min_radius := world_size * COLLAPSE_MIN_RADIUS_RATIO
		if collapse_radius > min_radius:
			var shrink_rate := (world_size * 0.47 - min_radius) / COLLAPSE_SHRINK_SECONDS
			collapse_radius = maxf(collapse_radius - shrink_rate * delta, min_radius)


func _process_weather(delta: float) -> void:
	if weather_id != "storm" or not visual_effects_enabled or sun_light == null:
		return
	lightning_timer -= delta
	lightning_flash_timer = maxf(lightning_flash_timer - delta, 0.0)
	if lightning_timer <= 0.0:
		lightning_flash_timer = 0.14
		lightning_timer = rng.randf_range(4.0, 8.5)
	var flash_factor := 3.4 if lightning_flash_timer > 0.07 else (1.9 if lightning_flash_timer > 0.0 else 1.0)
	sun_light.light_energy = base_sun_energy * flash_factor


func update_weather_focus(pos: Vector3) -> void:
	if weather_fx_root != null:
		weather_fx_root.global_position = Vector3(pos.x, 0.0, pos.z)


func random_spawn(avoid_positions: Array[Vector3] = [], minimum_actor_distance: float = 6.0) -> Vector3:
	for attempt in range(160):
		var pos := _random_valid_position(7.0)
		var valid := true
		for other in avoid_positions:
			if pos.distance_to(other) < minimum_actor_distance:
				valid = false
				break
		if valid:
			return pos
	return Vector3(rng.randf_range(-12.0, 12.0), 0.45, rng.randf_range(-12.0, 12.0))


func random_spawn_in_regions(region_ids: Array[String], avoid_positions: Array[Vector3] = [], minimum_actor_distance: float = 6.0) -> Vector3:
	if region_ids.is_empty():
		return random_spawn(avoid_positions, minimum_actor_distance)
	for attempt in range(220):
		var pos := _random_valid_position(7.0)
		if not region_ids.has(region_id_at(pos)):
			continue
		var valid := true
		for other in avoid_positions:
			if pos.distance_to(other) < minimum_actor_distance:
				valid = false
				break
		if valid:
			return pos
	return random_spawn(avoid_positions, minimum_actor_distance)


func clamp_position(pos: Vector3) -> Vector3:
	# The ecological collapse changes resource regeneration, but must not create
	# an invisible movement wall over otherwise visible terrain.
	# Leave only enough margin to keep the largest capsule on the ground plane.
	var edge := maxf(world_size * 0.5 - 1.2, 1.0)
	return Vector3(clampf(pos.x, -edge, edge), pos.y, clampf(pos.z, -edge, edge))


func region_id_at(pos: Vector3) -> String:
	if pos.x < 0.0:
		return "forest" if pos.z < 0.0 else "wetland"
	return "grassland" if pos.z < 0.0 else "highland"


func region_name_at(pos: Vector3) -> String:
	return str(REGION_NAMES[region_id_at(pos)])


func water_depth_at(pos: Vector3) -> float:
	if region_id_at(pos) != "wetland":
		return 0.0
	var basin_center := Vector2(-world_size * 0.25, world_size * 0.25)
	var basin_radius := world_size * 0.145
	var normalized := Vector2(
		(pos.x - basin_center.x) / maxf(basin_radius, 0.1),
		(pos.z - basin_center.y) / maxf(basin_radius * 0.72, 0.1)
	).length()
	if normalized <= 1.0:
		return lerpf(0.68, 0.28, normalized)
	return 0.16


func condition_summary() -> String:
	var phase_name := "夜晚" if time_phase == "night" else "白昼"
	var weather_name: String = {"clear": "晴朗", "rain": "暴雨", "fog": "大雾", "storm": "风暴"}.get(weather_id, "晴朗")
	return "%s · %s" % [phase_name, weather_name]


func movement_multiplier(species_id: String, pos: Vector3) -> float:
	var multiplier := 1.0
	if Catalog.has_trait(species_id, "flying"):
		if weather_id == "storm":
			multiplier *= 0.76
		elif weather_id == "rain":
			multiplier *= 0.88
		elif weather_id == "fog":
			multiplier *= 0.94
	if Catalog.has_trait(species_id, "night_hunter"):
		multiplier *= 1.12 if time_phase == "night" else 0.90
	elif Catalog.has_trait(species_id, "day_hunter"):
		multiplier *= 1.10 if time_phase == "day" else 0.82
	if Catalog.has_trait(species_id, "weather_runner"):
		if weather_id == "clear" and region_id_at(pos) == "grassland":
			multiplier *= 1.08
		elif weather_id == "rain":
			multiplier *= 0.78
		elif weather_id == "storm":
			multiplier *= 0.68
		elif weather_id == "fog":
			multiplier *= 0.88
	return multiplier


func perception_multiplier(species_id: String) -> float:
	var multiplier := 1.0
	if weather_id == "fog":
		multiplier *= 0.68
	elif weather_id == "storm":
		multiplier *= 0.78
	elif weather_id == "rain":
		multiplier *= 0.88
	if Catalog.has_trait(species_id, "night_hunter"):
		multiplier *= 1.38 if time_phase == "night" else 0.78
	elif Catalog.has_trait(species_id, "day_hunter"):
		multiplier *= 1.28 if time_phase == "day" else 0.68
	return multiplier


func flight_stamina_multiplier() -> float:
	if weather_id == "storm":
		return 1.45
	if weather_id == "rain":
		return 1.20
	return 1.0


func is_landing_clear(pos: Vector3, actor_radius: float = 0.55) -> bool:
	var edge := world_size * 0.5 - actor_radius - 1.2
	if absf(pos.x) > edge or absf(pos.z) > edge:
		return false
	for index in range(obstacles.size()):
		if Vector2(pos.x - obstacles[index].x, pos.z - obstacles[index].z).length() < obstacle_radii[index] + actor_radius + 0.35:
			return false
	return true


func nearest_legal_landing(pos: Vector3, actor_radius: float = 0.55) -> Vector3:
	var base := clamp_position(Vector3(pos.x, 0.45, pos.z))
	if is_landing_clear(base, actor_radius):
		return base
	for ring_index in range(1, 5):
		var radius := float(ring_index) * 1.65
		for direction_index in range(12):
			var angle := TAU * float(direction_index) / 12.0
			var candidate := clamp_position(base + Vector3(cos(angle), 0.0, sin(angle)) * radius)
			candidate.y = 0.45
			if is_landing_clear(candidate, actor_radius):
				return candidate
	return Vector3(0.0, 0.45, 0.0)


func nearest_climbable_tree(pos: Vector3, max_distance: float = 5.0) -> Vector3:
	var nearest := Vector3(INF, 0.0, INF)
	var nearest_distance := max_distance
	for index in range(obstacles.size()):
		if index >= obstacle_kinds.size() or obstacle_kinds[index] != "tree":
			continue
		var distance := Vector2(pos.x - obstacles[index].x, pos.z - obstacles[index].z).length()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = obstacles[index]
	return nearest


func _is_protected_route(pos: Vector3) -> bool:
	var corridor_half_width := 4.4
	if absf(pos.x) < corridor_half_width or absf(pos.z) < corridor_half_width:
		return true
	var marker_distance := world_size * 0.27
	for marker_x in [-marker_distance, marker_distance]:
		for marker_z in [-marker_distance, marker_distance]:
			if Vector2(pos.x - marker_x, pos.z - marker_z).length() < 3.2:
				return true
	return false


func steer_around_obstacles(origin: Vector3, desired: Vector3, actor_radius: float, actor_id: int, look_ahead_scale: float = 1.0) -> Vector3:
	if desired.length() < 0.05:
		return Vector3.ZERO
	var flat_desired := Vector3(desired.x, 0.0, desired.z).normalized()
	var look_ahead := (2.1 + actor_radius * 1.8) * maxf(look_ahead_scale, 1.0)
	var blocking_index := -1
	var nearest_clearance := INF
	for index in range(obstacles.size()):
		var to_obstacle := obstacles[index] - origin
		var distance_along_path := clampf(to_obstacle.dot(flat_desired), 0.0, look_ahead)
		var closest_path_point := origin + flat_desired * distance_along_path
		var clearance := Vector2(closest_path_point.x - obstacles[index].x, closest_path_point.z - obstacles[index].z).length() - obstacle_radii[index] - actor_radius
		if clearance < nearest_clearance and clearance < 0.9:
			nearest_clearance = clearance
			blocking_index = index
	if blocking_index < 0:
		return flat_desired
	var lateral := Vector3(-flat_desired.z, 0.0, flat_desired.x)
	var left_probe := origin + (flat_desired + lateral * 0.9).normalized() * look_ahead
	var right_probe := origin + (flat_desired - lateral * 0.9).normalized() * look_ahead
	var obstacle := obstacles[blocking_index]
	var left_clearance := Vector2(left_probe.x - obstacle.x, left_probe.z - obstacle.z).length()
	var right_clearance := Vector2(right_probe.x - obstacle.x, right_probe.z - obstacle.z).length()
	var side_sign := 1.0 if left_clearance > right_clearance else -1.0
	if is_equal_approx(left_clearance, right_clearance):
		side_sign = 1.0 if actor_id % 2 == 0 else -1.0
	return (flat_desired + lateral * side_sign * 1.25).normalized()


func flatten_light_obstacles_near(origin: Vector3, radius: float, max_count: int = 1) -> int:
	var flattened := 0
	for index in range(obstacles.size() - 1, -1, -1):
		if flattened >= max_count:
			break
		if index >= obstacle_kinds.size() or obstacle_kinds[index] != "tree":
			continue
		# Large old-growth trees and every rock remain permanent navigation
		# anchors. Only slim trunks can be displaced by an elephant.
		if obstacle_radii[index] > 0.43 or obstacles[index].distance_to(origin) > radius + obstacle_radii[index]:
			continue
		if index < obstacle_visuals.size() and is_instance_valid(obstacle_visuals[index]):
			obstacle_visuals[index].queue_free()
		if index < obstacle_colliders.size() and is_instance_valid(obstacle_colliders[index]):
			obstacle_colliders[index].queue_free()
		obstacles.remove_at(index)
		obstacle_radii.remove_at(index)
		obstacle_visuals.remove_at(index)
		obstacle_colliders.remove_at(index)
		obstacle_kinds.remove_at(index)
		flattened += 1
	return flattened


func _random_decor_position(center_clearance: float, new_radius: float = 0.0) -> Vector3:
	var best_position := Vector3.ZERO
	var best_clearance := -INF
	for attempt in range(180):
		var pos := Vector3(rng.randf_range(-world_size * 0.46, world_size * 0.46), 0.0, rng.randf_range(-world_size * 0.46, world_size * 0.46))
		if Vector2(pos.x, pos.z).length() < center_clearance:
			continue
		if _is_protected_route(pos):
			continue
		var clearance := INF
		for index in range(obstacles.size()):
			clearance = minf(clearance, pos.distance_to(obstacles[index]) - obstacle_radii[index] - new_radius)
		if obstacles.is_empty():
			clearance = INF
		if clearance > best_clearance:
			best_clearance = clearance
			best_position = pos
		if clearance >= MIN_PASSAGE_GAP:
			return pos
	# At very high densities prefer the widest sampled location instead of an
	# unchecked fallback that may overlap another collider.
	return best_position


func _random_valid_position(edge_margin: float) -> Vector3:
	for attempt in range(100):
		var half := world_size * 0.5 - edge_margin
		var pos := Vector3(rng.randf_range(-half, half), 0.45, rng.randf_range(-half, half))
		var valid := true
		for index in range(obstacles.size()):
			if pos.distance_to(obstacles[index]) < obstacle_radii[index] + 1.8:
				valid = false
				break
		if valid:
			return pos
	return Vector3.ZERO + Vector3.UP * 0.45
