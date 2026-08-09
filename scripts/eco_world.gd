class_name EcoWorld
extends Node3D

signal ecology_event_started(event: Dictionary)
signal ecology_event_ended(event: Dictionary)

const Factory = preload("res://scripts/low_poly_factory.gd")
const FoodPatchScript = preload("res://scripts/food_patch.gd")
const Catalog = preload("res://scripts/species_catalog.gd")
const FOREST_GROUND_TEXTURE = preload("res://assets/textures/terrain/forest_floor_ai.jpg")
const GRASSLAND_GROUND_TEXTURE = preload("res://assets/textures/terrain/grassland_ai.jpg")
const WETLAND_GROUND_TEXTURE = preload("res://assets/textures/terrain/wetland_ai.jpg")
const HIGHLAND_GROUND_TEXTURE = preload("res://assets/textures/terrain/highland_ai.jpg")

const COLLAPSE_MIN_RADIUS_RATIO := 0.22
const COLLAPSE_SHRINK_SECONDS := 90.0
const MIN_PASSAGE_GAP := 3.4
const TERRAIN_COUNTER_THRESHOLD := 0.72
const ECOLOGY_EVENT_FIRST_BASE := 34.0
const ECOLOGY_EVENT_REPEAT_BASE := 72.0
const ECOLOGY_TRACE_MIN_AGE := 0.75
const ECOLOGY_TRACE_MAX_ENTRIES := 180
const DANGER_MEMORY_MAX_ENTRIES := 24
const ECOLOGY_EVENT_ORDER: Array[String] = ["fruit_fall", "grass_flush", "fish_run", "root_bloom"]
const ECOLOGY_EVENT_PROFILES := {
	"fruit_fall": {"unlock": 1, "title": "落果潮", "region": "forest", "foods": ["fruit", "berries", "fruit"], "color": "#e6a84f", "description": "成熟果实集中坠落，草食与杂食动物正在向林地迁徙"},
	"grass_flush": {"unlock": 2, "title": "新草繁盛", "region": "grassland", "foods": ["grass", "grass", "fruit"], "color": "#a6d86f", "description": "雨露催生新草，开阔草原将形成短时争食热点"},
	"fish_run": {"unlock": 3, "title": "鱼群洄游", "region": "wetland", "foods": ["fish", "fish", "fish"], "color": "#62cfd1", "description": "浅滩鱼群聚集，肉食与杂食动物会循水声前来"},
	"root_bloom": {"unlock": 4, "title": "块根出土", "region": "highland", "foods": ["roots", "roots", "mushroom"], "color": "#d3b56d", "description": "岩丘土层松动，高能块根在山地集中出现"},
}

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
var event_rng := RandomNumberGenerator.new()
var obstacles: Array[Vector3] = []
var obstacle_radii: Array[float] = []
var obstacle_visuals: Array[Node3D] = []
var obstacle_colliders: Array[StaticBody3D] = []
var obstacle_kinds: Array[String] = []
var cover_positions: Array[Vector3] = []
var cover_radii: Array[float] = []
var food_patches: Array[Node] = []
var active_ecology_event: Dictionary = {}
var active_event_patches: Array[Node] = []
var active_event_visual: Node3D
var active_event_title_label: Label3D
var active_event_ring_material: StandardMaterial3D
var ecology_event_timer: float = 0.0
var ecology_event_sequence: int = 0
var last_ecology_event_id: String = ""
var ecology_clock: float = 0.0
var ecology_trace_cleanup_timer: float = 0.0
var ecology_trace_sequence: int = 0
var movement_traces: Array[Dictionary] = []
var danger_memories: Array[Dictionary] = []
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
	event_rng.seed = seed_value ^ 0x5EED771
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
	_build_biome_transitions()
	_build_ground_details()
	_build_paths_and_pond()
	_build_trees()
	_build_rocks()
	_build_bushes()
	_build_biome_props()
	_build_food()
	_build_visible_border()
	ecology_clock = 0.0
	ecology_trace_cleanup_timer = 0.0
	ecology_trace_sequence = 0
	movement_traces.clear()
	danger_memories.clear()
	ecology_event_timer = ecology_event_first_delay(campaign_level, event_rng.randf())


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
	var sky_material := ProceduralSkyMaterial.new()
	var sky_top := Color("#17283a") if time_phase == "night" else Color("#6f9ca4")
	var sky_horizon := Color("#627284") if time_phase == "night" else Color("#d5c99f")
	var ground_horizon := Color("#28343b") if time_phase == "night" else Color("#4d6048")
	var ground_bottom := Color("#0c151a") if time_phase == "night" else Color("#1a3025")
	if weather_id == "storm":
		sky_top = sky_top.darkened(0.38)
		sky_horizon = sky_horizon.darkened(0.30)
		ground_horizon = ground_horizon.darkened(0.28)
	elif weather_id == "rain":
		sky_top = sky_top.darkened(0.18)
		sky_horizon = sky_horizon.darkened(0.12)
	elif weather_id == "fog":
		sky_top = sky_top.lerp(Color("#aabbb5"), 0.48)
		sky_horizon = sky_horizon.lerp(Color("#d4ddd0"), 0.62)
	sky_material.sky_top_color = sky_top
	sky_material.sky_horizon_color = sky_horizon
	sky_material.ground_horizon_color = ground_horizon
	sky_material.ground_bottom_color = ground_bottom
	sky_material.sun_angle_max = 0.0
	sky_material.sun_curve = 0.055
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.66
	environment.ambient_light_energy = 0.32 if time_phase == "night" else 0.46
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.94
	environment.adjustment_contrast = 1.16
	environment.adjustment_saturation = 1.10
	environment.fog_enabled = true
	environment.fog_light_color = Color("#65798b") if time_phase == "night" else Color("#b9cfb8")
	environment.fog_light_energy = 0.55
	environment.fog_density = 0.012 if weather_id == "fog" else (0.0075 if weather_id == "storm" else (0.0042 if weather_id == "rain" else 0.0018))
	environment.fog_sky_affect = 0.30
	if weather_id == "storm":
		environment.adjustment_saturation = 0.76
	elif weather_id == "rain":
		environment.adjustment_saturation = 0.88
	elif weather_id == "fog":
		environment.adjustment_contrast = 0.94
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun_light = sun
	sun.name = "Sun"
	sun.light_color = Color("#afc9e9") if time_phase == "night" else Color("#ffe0aa")
	sun.light_energy = (0.27 if time_phase == "night" else 0.82) * (0.58 if weather_id == "storm" else (0.76 if weather_id in ["rain", "fog"] else 1.0))
	base_sun_energy = sun.light_energy
	sun.shadow_enabled = quality_preset != "low"
	sun.shadow_opacity = 0.62
	sun.directional_shadow_max_distance = minf(world_size * (0.82 if quality_preset == "high" else 0.55), 150.0 if quality_preset == "high" else 88.0)
	sun.directional_shadow_fade_start = 0.78
	sun.rotation_degrees = Vector3(-48.0, -38.0, 0.0)
	add_child(sun)

	var sky_fill := DirectionalLight3D.new()
	sky_fill.name = "SkyFill"
	sky_fill.light_color = Color("#9fc4cf")
	sky_fill.light_energy = 0.18 if time_phase == "day" else 0.10
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
	ground.material_override = Factory.terrain_material(Color("#193228"), Color("#274737"), 15.0, FOREST_GROUND_TEXTURE, 7.0, 0.12)
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
	_add_region_ground("AncientForest", Vector3(-half_extent, 0.003, -half_extent), region_size, Color("#244833"), Color("#3b603d"), FOREST_GROUND_TEXTURE, 0.24)
	_add_region_ground("SunGrassland", Vector3(half_extent, 0.003, -half_extent), region_size, Color("#596f3d"), Color("#7d8244"), GRASSLAND_GROUND_TEXTURE, 0.20)
	_add_region_ground("ShallowWetland", Vector3(-half_extent, 0.003, half_extent), region_size, Color("#305a53"), Color("#416b5b"), WETLAND_GROUND_TEXTURE, 0.24)
	_add_region_ground("RockHighland", Vector3(half_extent, 0.003, half_extent), region_size, Color("#5b563f"), Color("#766446"), HIGHLAND_GROUND_TEXTURE, 0.22)
	_build_region_marker("古木林地", Vector3(-world_size * 0.27, 0.0, -world_size * 0.27), Color("#9dd19b"))
	_build_region_marker("日照草原", Vector3(world_size * 0.27, 0.0, -world_size * 0.27), Color("#e1d68a"))
	_build_region_marker("浅水湿地", Vector3(-world_size * 0.27, 0.0, world_size * 0.27), Color("#8fd5cf"))
	_build_region_marker("岩丘高地", Vector3(world_size * 0.27, 0.0, world_size * 0.27), Color("#d4c493"))


func _add_region_ground(node_name: String, center: Vector3, size_value: Vector2, tint: Color, detail_tint: Color, painted_texture: Texture2D, painted_strength: float) -> void:
	var region := MeshInstance3D.new()
	region.name = node_name
	var plane := PlaneMesh.new()
	plane.size = size_value
	region.mesh = plane
	region.material_override = Factory.terrain_material(tint, detail_tint, 12.0, painted_texture, 5.0, painted_strength)
	region.position = center
	decoration_root.add_child(region)


func _build_biome_transitions() -> void:
	var transition_steps := 13
	for step_index in range(transition_steps):
		var ratio := float(step_index) / float(transition_steps - 1)
		var axis_offset := lerpf(-world_size * 0.43, world_size * 0.43, ratio)
		var vertical_tint := Color("#4a603c") if axis_offset < 0.0 else Color("#4c6350")
		var vertical_pos := Vector3(rng.randf_range(-1.45, 1.45), 0.011 + step_index * 0.00004, axis_offset + rng.randf_range(-1.2, 1.2))
		_add_transition_patch("VerticalBiomeBlend", vertical_pos, vertical_tint, rng.randf_range(2.0, 4.2), rng.randf_range(0.55, 1.10))
		var horizontal_tint := Color("#3d5d45") if axis_offset < 0.0 else Color("#6a6843")
		var horizontal_pos := Vector3(axis_offset + rng.randf_range(-1.2, 1.2), 0.012 + step_index * 0.00004, rng.randf_range(-1.45, 1.45))
		_add_transition_patch("HorizontalBiomeBlend", horizontal_pos, horizontal_tint, rng.randf_range(2.0, 4.2), rng.randf_range(0.55, 1.10))


func _add_transition_patch(node_name: String, pos: Vector3, tint: Color, radius: float, squash: float) -> void:
	var patch := Factory.disc(node_name, tint, radius, 0.018, pos, rng.randi_range(9, 13))
	patch.scale.z = squash
	patch.rotation.y = rng.randf_range(0.0, TAU)
	patch.material_override = Factory.terrain_material(tint.darkened(0.10), tint.lightened(0.04), rng.randf_range(5.0, 8.0))
	decoration_root.add_child(patch)


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
	var patch_count := int(round(30.0 * density_scale))
	for i in range(patch_count):
		var radius := rng.randf_range(0.9, 3.1)
		var pos := Vector3(rng.randf_range(-world_size * 0.44, world_size * 0.44), 0.008 + i * 0.00005, rng.randf_range(-world_size * 0.44, world_size * 0.44))
		var patch_colors: Array[Color]
		match region_id_at(pos):
			"forest": patch_colors = [Color("#274937"), Color("#426341"), Color("#526746")]
			"grassland": patch_colors = [Color("#80954d"), Color("#a29a50"), Color("#657b43")]
			"wetland": patch_colors = [Color("#38685d"), Color("#4d7764"), Color("#315c58")]
			_: patch_colors = [Color("#756b4b"), Color("#8a7650"), Color("#5f6248")]
		var patch_tint: Color = patch_colors[rng.randi_range(0, patch_colors.size() - 1)]
		var patch := Factory.disc("GroundMottle", patch_tint, radius, 0.018, pos, rng.randi_range(8, 12))
		patch.material_override = Factory.terrain_material(patch_tint.darkened(0.10), patch_tint, rng.randf_range(4.0, 7.0))
		patch.scale.z = rng.randf_range(0.48, 0.92)
		patch.rotation.y = rng.randf_range(0.0, TAU)
		decoration_root.add_child(patch)


func _build_paths_and_pond() -> void:
	var trail_color := Color("#4f603e")
	var path_half := world_size * 0.46
	var east_west_points: Array[Vector2] = [
		Vector2(-path_half, -2.4), Vector2(-path_half * 0.64, -0.8), Vector2(-path_half * 0.32, 1.3),
		Vector2(0.0, 0.0), Vector2(path_half * 0.33, -1.5), Vector2(path_half * 0.67, 1.0), Vector2(path_half, 0.5),
	]
	var north_south_points: Array[Vector2] = [
		Vector2(2.0, -path_half), Vector2(0.8, -path_half * 0.66), Vector2(-1.2, -path_half * 0.34),
		Vector2(0.0, 0.0), Vector2(1.7, path_half * 0.31), Vector2(-1.3, path_half * 0.68), Vector2(0.4, path_half),
	]
	_add_winding_trail("EastWestMainTrail", east_west_points, 4.1, trail_color.lightened(0.035), 0.022)
	_add_winding_trail("NorthSouthMainTrail", north_south_points, 4.1, trail_color, 0.023)
	for trail_index in range(3):
		var angle := -0.55 + trail_index * 1.92 + rng.randf_range(-0.18, 0.18)
		var previous := Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
		for segment_index in range(6):
			var distance := world_size * 0.068 + segment_index * world_size * 0.010
			angle += rng.randf_range(-0.20, 0.20)
			var next := previous + Vector2(cos(angle), sin(angle)) * distance
			_add_ground_strip("ForestTrail", previous, next, rng.randf_range(2.5, 3.7), trail_color.lightened(rng.randf_range(-0.035, 0.035)), 0.018 + trail_index * 0.002)
			previous = next

	var stream_points: Array[Vector2] = [
		Vector2(-16.0, -12.0), Vector2(-9.0, -9.4), Vector2(-2.0, -10.2),
		Vector2(5.0, -7.6), Vector2(12.0, -8.5), Vector2(18.0, -5.2)
	]
	for i in range(stream_points.size() - 1):
		_add_ground_strip("StreamBank", stream_points[i], stream_points[i + 1], 7.6, Color("#657b57"), 0.030)
		var stream := _add_ground_strip("ShallowStream", stream_points[i], stream_points[i + 1], 5.4, Color(0.20, 0.56, 0.60, 0.90), 0.044)
		stream.material_override = Factory.water_material(Color("#62b8ac"), Color("#236b70"), 0.82)
	for stone_index in range(9):
		var t := float(stone_index) / 8.0
		var stone_pos := Vector3(lerpf(-4.2, 2.6, t), 0.10, lerpf(-10.0, -8.35, t) + sin(t * TAU) * 0.28)
		var stone := Factory.sphere("SteppingStone", Color("#818a79").lightened(rng.randf_range(-0.05, 0.08)), Vector3(0.72, 0.20, 0.58), stone_pos, 8, 4)
		stone.rotation.y = rng.randf_range(-0.5, 0.5)
		decoration_root.add_child(stone)

	var basin_center := Vector3(-world_size * 0.25, 0.052, world_size * 0.25)
	var basin := Factory.disc("WetlandBasin", Color(0.17, 0.55, 0.58, 0.74), world_size * 0.145, 0.026, basin_center, 18)
	basin.scale.z = 0.72
	basin.material_override = Factory.water_material(Color("#62b9a8"), Color("#225f67"), 0.78)
	decoration_root.add_child(basin)
	var deep_center := Factory.disc("DeepWaterBand", Color(0.11, 0.42, 0.49, 0.82), world_size * 0.075, 0.028, basin_center + Vector3.UP * 0.004, 16)
	deep_center.scale.z = 0.68
	deep_center.material_override = Factory.water_material(Color("#438f8e"), Color("#174d5d"), 0.86)
	decoration_root.add_child(deep_center)


func _add_winding_trail(node_name: String, points: Array[Vector2], width: float, color: Color, height: float) -> void:
	for point_index in range(points.size() - 1):
		_add_ground_strip(node_name, points[point_index], points[point_index + 1], width, color.lightened(sin(float(point_index) * 1.7) * 0.018), height + point_index * 0.00008)
	for point_index in range(1, points.size() - 1):
		var point := points[point_index]
		var joint := Factory.disc("%sJoint" % node_name, color, width * 0.49, 0.018, Vector3(point.x, height - 0.006, point.y), 12)
		joint.material_override = Factory.terrain_material(color.darkened(0.055), color.lightened(0.045), 8.0)
		decoration_root.add_child(joint)


func _add_ground_strip(node_name: String, start: Vector2, finish: Vector2, width: float, color: Color, height: float) -> MeshInstance3D:
	var delta := finish - start
	var strip := MeshInstance3D.new()
	strip.name = node_name
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(delta.length() + 0.3, width)
	strip.mesh = mesh
	if color.a < 0.999:
		var strip_material := Factory.material(color, 0.72)
		strip_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		strip.material_override = strip_material
	else:
		strip.material_override = Factory.terrain_material(color.darkened(0.055), color.lightened(0.045), 8.0)
	strip.position = Vector3((start.x + finish.x) * 0.5, height, (start.y + finish.y) * 0.5)
	strip.rotation.y = -atan2(delta.y, delta.x)
	decoration_root.add_child(strip)
	return strip


func _build_trees() -> void:
	var base_tree_count: int = {"low": 28, "medium": 38, "high": 46}.get(quality_preset, 38)
	var tree_count := int(round(base_tree_count * density_scale))
	for i in range(tree_count):
		var pos := _random_decor_position(7.0, 0.48)
		var region_id := region_id_at(pos)
		var keep_probability: float = {"forest": 1.0, "grassland": 0.52, "wetland": 0.78, "highland": 0.66}.get(region_id, 0.75)
		if rng.randf() > keep_probability:
			continue
		var radius := rng.randf_range(0.52, 0.88)
		var height := rng.randf_range(4.2, 6.2)
		match region_id:
			"forest":
				radius *= 1.08
				height *= 1.14
			"grassland":
				radius *= 0.78
				height *= 0.82
			"wetland":
				radius *= 0.74
				height *= 1.04
			"highland":
				radius *= 0.84
				height *= 1.12
		# The visible trunk is radius * 0.48. Keep its collider close to the
		# silhouette so apparently open paths do not contain invisible walls.
		var collision_radius := maxf(radius * 0.56, 0.32)
		obstacles.append(pos)
		obstacle_radii.append(collision_radius)
		var tree := Node3D.new()
		tree.name = "%sTree" % region_id.capitalize()
		tree.position = pos
		tree.rotation.y = rng.randf_range(0.0, TAU)
		decoration_root.add_child(tree)
		match region_id:
			"forest": _decorate_forest_tree(tree, radius, height)
			"grassland": _decorate_grassland_tree(tree, radius, height)
			"wetland": _decorate_wetland_tree(tree, radius, height)
			_: _decorate_highland_tree(tree, radius, height)
		# One collider per tree. This used to be inside the crown loop, creating
		# three identical StaticBody3D nodes at the same position.
		var tree_collider := Factory.add_static_cylinder(obstacle_root, collision_radius, height, Vector3(pos.x, height * 0.5, pos.z))
		obstacle_visuals.append(tree)
		obstacle_colliders.append(tree_collider)
		obstacle_kinds.append("tree")


func _decorate_forest_tree(tree: Node3D, radius: float, height: float) -> void:
	var trunk_color := Color("#4a372b").lightened(rng.randf_range(-0.035, 0.055))
	var trunk := Factory.tapered_cylinder("AncientTrunk", trunk_color, radius * 0.58, radius * 0.34, height, Vector3(0.0, height * 0.5, 0.0), 9)
	tree.add_child(trunk)
	for root_index in range(4):
		var root_angle := TAU * float(root_index) / 4.0 + rng.randf_range(-0.22, 0.22)
		var root_end := Vector3(cos(root_angle) * radius * 1.28, 0.10, sin(root_angle) * radius * 1.28)
		_add_branch_segment(tree, "RootFlare", trunk_color.darkened(0.05), Vector3(0.0, 0.32, 0.0), root_end, radius * 0.16)
	var leaf_color := Color.from_hsv(rng.randf_range(0.29, 0.35), rng.randf_range(0.46, 0.62), rng.randf_range(0.32, 0.46))
	for branch_index in range(3):
		var branch_angle := TAU * float(branch_index) / 3.0 + rng.randf_range(-0.30, 0.30)
		var branch_start := Vector3(0.0, height * (0.62 + branch_index * 0.07), 0.0)
		var branch_end := Vector3(cos(branch_angle) * radius * 1.85, height * (0.80 + branch_index * 0.06), sin(branch_angle) * radius * 1.85)
		_add_branch_segment(tree, "CrownBranch", trunk_color.lightened(0.025), branch_start, branch_end, radius * 0.18)
		for cluster_index in range(2):
			var cluster_pos := branch_end + Vector3(cos(branch_angle + cluster_index * 1.18) * 0.62, cluster_index * 0.55, sin(branch_angle + cluster_index * 1.18) * 0.62)
			tree.add_child(Factory.sphere("LeafMass", leaf_color.lightened(rng.randf_range(-0.06, 0.08)), Vector3(2.15, 1.34, 1.85), cluster_pos, 9, 6))
	tree.add_child(Factory.sphere("CrownHeart", leaf_color.lightened(0.05), Vector3(2.35, 1.62, 2.05), Vector3(0.0, height + 1.30, 0.0), 10, 6))


func _decorate_grassland_tree(tree: Node3D, radius: float, height: float) -> void:
	var trunk_color := Color("#66503a").lightened(rng.randf_range(-0.04, 0.06))
	tree.add_child(Factory.tapered_cylinder("SunTrunk", trunk_color, radius * 0.50, radius * 0.28, height, Vector3(0.0, height * 0.5, 0.0), 8))
	var canopy_color := Color.from_hsv(rng.randf_range(0.20, 0.27), rng.randf_range(0.50, 0.66), rng.randf_range(0.46, 0.60))
	for branch_index in range(2):
		var side := -1.0 if branch_index == 0 else 1.0
		var end := Vector3(side * radius * 1.70, height * 0.91, (branch_index * 2 - 1) * radius * 0.42)
		_add_branch_segment(tree, "OpenBranch", trunk_color, Vector3(0.0, height * 0.62, 0.0), end, radius * 0.15)
	for cluster_index in range(5):
		var angle := TAU * float(cluster_index) / 5.0
		var cluster_pos := Vector3(cos(angle) * 1.28, height + 0.42 + (cluster_index % 2) * 0.22, sin(angle) * 0.92)
		tree.add_child(Factory.sphere("UmbrellaCanopy", canopy_color.lightened(rng.randf_range(-0.05, 0.07)), Vector3(1.75, 0.78, 1.36), cluster_pos, 8, 5))


func _decorate_wetland_tree(tree: Node3D, radius: float, height: float) -> void:
	var trunk_color := Color("#51483b").lightened(rng.randf_range(-0.035, 0.045))
	tree.add_child(Factory.tapered_cylinder("WetlandTrunk", trunk_color, radius * 0.52, radius * 0.25, height, Vector3(0.0, height * 0.5, 0.0), 8))
	for knee_index in range(3):
		var knee_angle := TAU * float(knee_index) / 3.0
		var knee := Factory.cone("CypressKnee", trunk_color.darkened(0.08), radius * 0.18, radius * 0.95, Vector3(cos(knee_angle) * radius * 0.78, radius * 0.42, sin(knee_angle) * radius * 0.78), 7)
		tree.add_child(knee)
	var leaf_color := Color.from_hsv(rng.randf_range(0.37, 0.43), rng.randf_range(0.42, 0.58), rng.randf_range(0.34, 0.48))
	for cluster_index in range(5):
		var angle := TAU * float(cluster_index) / 5.0
		var cluster_pos := Vector3(cos(angle) * 1.12, height + 0.45 + (cluster_index % 2) * 0.58, sin(angle) * 1.12)
		tree.add_child(Factory.sphere("HangingFoliage", leaf_color.lightened(rng.randf_range(-0.05, 0.07)), Vector3(1.12, 1.72, 0.96), cluster_pos, 8, 6))


func _decorate_highland_tree(tree: Node3D, radius: float, height: float) -> void:
	var trunk_color := Color("#493e34").lightened(rng.randf_range(-0.035, 0.045))
	tree.add_child(Factory.tapered_cylinder("PineTrunk", trunk_color, radius * 0.44, radius * 0.22, height, Vector3(0.0, height * 0.5, 0.0), 8))
	var needle_color := Color.from_hsv(rng.randf_range(0.31, 0.37), rng.randf_range(0.46, 0.62), rng.randf_range(0.27, 0.39))
	for layer in range(4):
		var crown_radius := 1.90 - layer * 0.25
		var crown := Factory.cone("PineTier", needle_color.lightened(layer * 0.028), crown_radius, 2.75, Vector3(0.0, height * 0.50 + layer * 1.12, 0.0), 10)
		crown.rotation.y = layer * 0.51
		tree.add_child(crown)


func _add_branch_segment(parent: Node3D, node_name: String, color: Color, start: Vector3, finish: Vector3, radius: float) -> void:
	var direction := finish - start
	if direction.length_squared() < 0.001:
		return
	var branch := Factory.tapered_cylinder(node_name, color, radius, radius * 0.46, direction.length(), (start + finish) * 0.5, 7)
	branch.quaternion = Quaternion(Vector3.UP, direction.normalized())
	parent.add_child(branch)


func _build_rocks() -> void:
	var rock_count := int(round(14 * density_scale))
	for i in range(rock_count):
		var scale_value := Vector3(rng.randf_range(1.0, 2.2), rng.randf_range(0.7, 1.45), rng.randf_range(0.9, 1.8))
		var collision_radius := maxf(scale_value.x, scale_value.z) * 0.50
		var pos := _random_decor_position(5.0, collision_radius)
		var region_id := region_id_at(pos)
		if region_id == "grassland" and rng.randf() < 0.38:
			continue
		if region_id == "highland":
			scale_value.y *= rng.randf_range(1.25, 1.75)
		obstacles.append(pos)
		obstacle_radii.append(collision_radius)
		var rock_base: Color = {
			"forest": Color("#626d62"), "grassland": Color("#807b65"),
			"wetland": Color("#596d68"), "highland": Color("#747168"),
		}.get(region_id, Color("#727a70"))
		var rock_color := rock_base.lightened(rng.randf_range(-0.07, 0.07))
		var rock := Factory.sphere("Rock", rock_color, scale_value, Vector3(pos.x, scale_value.y * 0.42, pos.z), 8, 5)
		rock.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.0, TAU), rng.randf_range(-0.1, 0.1))
		decoration_root.add_child(rock)
		if rng.randf() < 0.62:
			var moss := Factory.sphere("RockMoss", Color("#5f7d4e").lightened(rng.randf_range(-0.04, 0.08)), Vector3(scale_value.x * 0.62, 0.12, scale_value.z * 0.55), Vector3(pos.x, scale_value.y * 0.84, pos.z), 8, 4)
			moss.rotation.y = rock.rotation.y
			decoration_root.add_child(moss)
		if region_id == "highland":
			for satellite_index in range(2):
				var satellite_scale := scale_value * rng.randf_range(0.32, 0.52)
				var satellite_angle := rock.rotation.y + (satellite_index * 2 - 1) * rng.randf_range(0.65, 1.10)
				var satellite_pos := pos + Vector3(cos(satellite_angle), 0.0, sin(satellite_angle)) * scale_value.x * 0.72
				var satellite := Factory.sphere("RockCluster", rock_color.lightened(0.025 + satellite_index * 0.025), satellite_scale, Vector3(satellite_pos.x, satellite_scale.y * 0.36, satellite_pos.z), 8, 5)
				satellite.rotation = Vector3(rng.randf_range(-0.15, 0.15), satellite_angle, rng.randf_range(-0.12, 0.12))
				decoration_root.add_child(satellite)
		var rock_collider := Factory.add_static_box(obstacle_root, Vector3(scale_value.x * 0.9, scale_value.y * 0.8, scale_value.z * 0.9), Vector3(pos.x, scale_value.y * 0.4, pos.z), rock.rotation.y)
		obstacle_visuals.append(rock)
		obstacle_colliders.append(rock_collider)
		obstacle_kinds.append("rock")


func _build_bushes() -> void:
	var bush_count := int(round(26 * density_scale))
	for i in range(bush_count):
		var pos := _random_decor_position(3.0)
		var bush := Node3D.new()
		bush.name = "TacticalCover_%02d" % i
		bush.position = pos
		decoration_root.add_child(bush)
		bush.rotation.y = rng.randf_range(0.0, TAU)
		var tint: Color
		match region_id_at(pos):
			"forest": tint = Color.from_hsv(rng.randf_range(0.29, 0.37), rng.randf_range(0.48, 0.64), rng.randf_range(0.31, 0.46))
			"grassland": tint = Color.from_hsv(rng.randf_range(0.19, 0.29), rng.randf_range(0.50, 0.67), rng.randf_range(0.44, 0.60))
			"wetland": tint = Color.from_hsv(rng.randf_range(0.36, 0.44), rng.randf_range(0.38, 0.58), rng.randf_range(0.34, 0.50))
			_: tint = Color.from_hsv(rng.randf_range(0.13, 0.24), rng.randf_range(0.36, 0.55), rng.randf_range(0.39, 0.55))
		var bush_scale := rng.randf_range(0.78, 1.18)
		for j in range(4):
			var piece := Factory.sphere("Bush", tint.lightened(j * 0.022), Vector3(1.05, 0.72, 0.92) * bush_scale, Vector3((j - 1.5) * 0.48 * bush_scale, 0.48 + (j % 2) * 0.18, rng.randf_range(-0.28, 0.28)), 8, 5)
			bush.add_child(piece)
		if rng.randf() < 0.28:
			var flower_color: Color = [Color("#e7d58c"), Color("#d7a6a0"), Color("#b9cce5")][rng.randi_range(0, 2)]
			for flower_index in range(3):
				bush.add_child(Factory.sphere("Wildflower", flower_color, Vector3(0.13, 0.10, 0.13), Vector3((flower_index - 1) * 0.55, 1.02 + flower_index * 0.06, rng.randf_range(-0.20, 0.20)), 7, 4))
		cover_positions.append(pos)
		cover_radii.append(1.72 * bush_scale)


func _build_biome_props() -> void:
	var base_prop_count: int = {"low": 28, "medium": 48, "high": 68}.get(quality_preset, 48)
	var prop_count := int(round(base_prop_count * sqrt(density_scale)))
	for prop_index in range(prop_count):
		var pos := _random_decor_position(2.2)
		var prop := Node3D.new()
		prop.name = "BiomeProp_%d" % prop_index
		prop.position = pos
		prop.rotation.y = rng.randf_range(0.0, TAU)
		prop.scale = Vector3.ONE * rng.randf_range(0.82, 1.22)
		decoration_root.add_child(prop)
		match region_id_at(pos):
			"forest": _decorate_forest_prop(prop)
			"grassland": _decorate_grassland_prop(prop)
			"wetland": _decorate_wetland_prop(prop)
			_: _decorate_highland_prop(prop)


func _decorate_forest_prop(prop: Node3D) -> void:
	if rng.randf() < 0.24:
		var log_color := Color("#4a3628").lightened(rng.randf_range(-0.035, 0.05))
		var log := Factory.tapered_cylinder("FallenLog", log_color, 0.26, 0.20, 2.10, Vector3(0.0, 0.28, 0.0), 8)
		log.rotation.z = PI * 0.5
		prop.add_child(log)
		for fungus_index in range(3):
			prop.add_child(Factory.sphere("ShelfFungus", Color("#d7b978").darkened(fungus_index * 0.05), Vector3(0.22, 0.07, 0.16), Vector3(-0.58 + fungus_index * 0.56, 0.43, -0.13 + fungus_index % 2 * 0.22), 7, 3))
		return
	var fern_color := Color.from_hsv(rng.randf_range(0.30, 0.37), 0.58, rng.randf_range(0.38, 0.52))
	for leaf_index in range(6):
		var angle := TAU * float(leaf_index) / 6.0
		var leaf := Factory.sphere("FernFrond", fern_color.lightened((leaf_index % 2) * 0.035), Vector3(0.18, 0.055, 0.88), Vector3(cos(angle) * 0.42, 0.32, sin(angle) * 0.42), 7, 4)
		leaf.rotation.x = 0.48
		leaf.rotation.y = -angle
		prop.add_child(leaf)


func _decorate_grassland_prop(prop: Node3D) -> void:
	var grass_color := Color.from_hsv(rng.randf_range(0.18, 0.27), rng.randf_range(0.52, 0.72), rng.randf_range(0.48, 0.66))
	for blade_index in range(7):
		var angle := TAU * float(blade_index) / 7.0
		var blade := Factory.tapered_cylinder("MeadowBlade", grass_color.lightened(rng.randf_range(-0.04, 0.07)), 0.045, 0.012, rng.randf_range(0.72, 1.18), Vector3(cos(angle) * 0.16, 0.46, sin(angle) * 0.16), 5)
		blade.rotation.z = cos(angle) * 0.26
		blade.rotation.x = sin(angle) * 0.26
		prop.add_child(blade)
	if rng.randf() < 0.38:
		var flower_color: Color = [Color("#efe0a0"), Color("#d9a8b0"), Color("#bdcfea"), Color("#d8b065")][rng.randi_range(0, 3)]
		for flower_index in range(2):
			prop.add_child(Factory.sphere("MeadowFlower", flower_color, Vector3(0.12, 0.08, 0.12), Vector3((flower_index * 2 - 1) * 0.24, 0.82 + flower_index * 0.10, 0.04), 7, 4))


func _decorate_wetland_prop(prop: Node3D) -> void:
	if rng.randf() < 0.26:
		for pad_index in range(3):
			var pad := Factory.disc("LilyPad", Color("#4f8153").lightened(pad_index * 0.035), 0.34 - pad_index * 0.035, 0.025, Vector3((pad_index - 1) * 0.52, 0.08, sin(float(pad_index)) * 0.28), 10)
			pad.scale.z = 0.72
			prop.add_child(pad)
		return
	var reed_color := Color.from_hsv(rng.randf_range(0.20, 0.30), 0.58, rng.randf_range(0.43, 0.58))
	for reed_index in range(6):
		var angle := TAU * float(reed_index) / 6.0
		var height := rng.randf_range(0.95, 1.55)
		prop.add_child(Factory.tapered_cylinder("Reed", reed_color.lightened(rng.randf_range(-0.035, 0.055)), 0.035, 0.018, height, Vector3(cos(angle) * 0.30, height * 0.5, sin(angle) * 0.30), 5))
		if reed_index % 3 == 0:
			prop.add_child(Factory.sphere("Cattail", Color("#5c3f2d"), Vector3(0.10, 0.26, 0.10), Vector3(cos(angle) * 0.30, height + 0.04, sin(angle) * 0.30), 6, 4))


func _decorate_highland_prop(prop: Node3D) -> void:
	if rng.randf() < 0.48:
		var rock_color := Color("#72736a").lightened(rng.randf_range(-0.07, 0.08))
		for stone_index in range(3):
			var stone_scale := rng.randf_range(0.28, 0.58)
			var stone := Factory.sphere("TrailStone", rock_color.lightened(stone_index * 0.025), Vector3(stone_scale, stone_scale * 0.68, stone_scale * 0.82), Vector3((stone_index - 1) * 0.43, stone_scale * 0.30, (stone_index % 2) * 0.28), 7, 4)
			stone.rotation = Vector3(rng.randf_range(-0.18, 0.18), rng.randf_range(0.0, TAU), rng.randf_range(-0.12, 0.12))
			prop.add_child(stone)
		return
	var dry_color := Color.from_hsv(rng.randf_range(0.11, 0.18), 0.55, rng.randf_range(0.48, 0.64))
	for blade_index in range(5):
		var angle := TAU * float(blade_index) / 5.0
		var blade := Factory.tapered_cylinder("HighlandGrass", dry_color.lightened(blade_index * 0.018), 0.045, 0.010, rng.randf_range(0.58, 0.96), Vector3(cos(angle) * 0.18, 0.35, sin(angle) * 0.18), 5)
		blade.rotation.z = cos(angle) * 0.31
		blade.rotation.x = sin(angle) * 0.31
		prop.add_child(blade)


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
	var north_centers: Array[Vector3] = []
	var south_centers: Array[Vector3] = []
	var west_centers: Array[Vector3] = []
	var east_centers: Array[Vector3] = []
	var north_radii: Array[Vector2] = []
	var south_radii: Array[Vector2] = []
	var west_radii: Array[Vector2] = []
	var east_radii: Array[Vector2] = []
	for point_index in range(11):
		var offset := lerpf(-edge - 1.0, edge + 1.0, float(point_index) / 10.0)
		var ridge_height := rng.randf_range(0.46, 0.82)
		var ridge_width := rng.randf_range(0.72, 1.12)
		north_centers.append(Vector3(offset, ridge_height * 0.55, -edge))
		south_centers.append(Vector3(offset, ridge_height * 0.55, edge))
		west_centers.append(Vector3(-edge, ridge_height * 0.55, offset))
		east_centers.append(Vector3(edge, ridge_height * 0.55, offset))
		north_radii.append(Vector2(ridge_width, ridge_height))
		south_radii.append(Vector2(ridge_width * rng.randf_range(0.88, 1.10), ridge_height * rng.randf_range(0.90, 1.16)))
		west_radii.append(Vector2(ridge_width * rng.randf_range(0.90, 1.12), ridge_height * rng.randf_range(0.88, 1.12)))
		east_radii.append(Vector2(ridge_width * rng.randf_range(0.86, 1.08), ridge_height * rng.randf_range(0.92, 1.18)))
	decoration_root.add_child(Factory.loft("NorthNaturalRidge", Color("#354c39"), north_centers, north_radii, 8))
	decoration_root.add_child(Factory.loft("SouthNaturalRidge", Color("#4e5a42"), south_centers, south_radii, 8))
	decoration_root.add_child(Factory.loft("WestNaturalRidge", Color("#304c42"), west_centers, west_radii, 8))
	decoration_root.add_child(Factory.loft("EastNaturalRidge", Color("#5f5942"), east_centers, east_radii, 8))


func trigger_collapse() -> void:
	collapse_active = true
	if not active_ecology_event.is_empty():
		_end_ecology_event("栖息地压力终止了外围资源信号")
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
	_process_ecology_events(delta)
	_process_ecology_traces(delta)
	if collapse_active:
		var min_radius := world_size * COLLAPSE_MIN_RADIUS_RATIO
		if collapse_radius > min_radius:
			var shrink_rate := (world_size * 0.47 - min_radius) / COLLAPSE_SHRINK_SECONDS
			collapse_radius = maxf(collapse_radius - shrink_rate * delta, min_radius)


static func ecology_event_ids_for_level(level: int) -> Array[String]:
	var result: Array[String] = []
	for event_id in ECOLOGY_EVENT_ORDER:
		if int(ECOLOGY_EVENT_PROFILES[event_id]["unlock"]) <= clampi(level, 1, 10):
			result.append(event_id)
	return result


static func ecology_event_first_delay(level: int, random_unit: float) -> float:
	return ECOLOGY_EVENT_FIRST_BASE + float(clampi(level, 1, 10)) * 1.5 + clampf(random_unit, 0.0, 1.0) * 12.0


static func ecology_event_repeat_delay(level: int, random_unit: float) -> float:
	return ECOLOGY_EVENT_REPEAT_BASE - float(clampi(level, 1, 10) - 1) * 1.5 + clampf(random_unit, 0.0, 1.0) * 18.0


static func compass_direction(origin: Vector3, target: Vector3) -> String:
	var delta := Vector2(target.x - origin.x, target.z - origin.z)
	if delta.length_squared() < 0.01:
		return "附近"
	var east_west := "东" if delta.x >= 0.0 else "西"
	var north_south := "南" if delta.y >= 0.0 else "北"
	if absf(delta.x) <= absf(delta.y) * 0.42:
		return north_south
	if absf(delta.y) <= absf(delta.x) * 0.42:
		return east_west
	return east_west + north_south


static func ecology_activity_risk(migrants: int, hunters: int) -> String:
	if hunters <= 0:
		return "平稳"
	if hunters >= 3 or hunters * 2 >= maxi(migrants, 1):
		return "高危"
	return "警戒"


static func ecology_activity_status(migrants: int, hunters: int) -> String:
	return "迁徙 %d · 猎手 %d · 风险：%s" % [migrants, hunters, ecology_activity_risk(migrants, hunters)]


static func ecology_ambush_offset(radius: float, actor_id: int, event_sequence: int) -> Vector3:
	var angle := fmod(float(actor_id) * 2.399963 + float(event_sequence) * 0.83, TAU)
	var distance := radius + 3.2 + float(posmod(actor_id, 3)) * 1.1
	return Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)


static func ecology_trace_lifetime(condition_id: String, injured: bool, sprinting: bool, scent_marked: bool = false) -> float:
	var lifetime := 13.0
	if injured:
		lifetime *= 1.42
	if sprinting:
		lifetime *= 1.18
	if scent_marked:
		lifetime *= 1.32
	match condition_id:
		"rain": lifetime *= 0.56
		"storm": lifetime *= 0.44
		"fog": lifetime *= 1.12
	return clampf(lifetime, 6.0, 30.0)


static func should_record_ecology_trace(moved_distance: float, concealed: bool, sprinting: bool, injured: bool, scent_marked: bool, airborne: bool) -> bool:
	if airborne or moved_distance < 0.62:
		return false
	if concealed and not sprinting and not injured and not scent_marked:
		return false
	return true


func _process_ecology_traces(delta: float) -> void:
	ecology_clock += delta
	ecology_trace_cleanup_timer -= delta
	if ecology_trace_cleanup_timer > 0.0:
		return
	ecology_trace_cleanup_timer = 0.8
	movement_traces = movement_traces.filter(func(trace: Dictionary) -> bool: return float(trace.get("expires_at", 0.0)) > ecology_clock)
	danger_memories = danger_memories.filter(func(memory: Dictionary) -> bool: return float(memory.get("expires_at", 0.0)) > ecology_clock)
	while movement_traces.size() > ECOLOGY_TRACE_MAX_ENTRIES:
		movement_traces.pop_front()
	while danger_memories.size() > DANGER_MEMORY_MAX_ENTRIES:
		danger_memories.pop_front()


func record_movement_trace(source_id: int, source_species: String, trace_position: Vector3, trace_direction: Vector3, injured: bool, sprinting: bool, scent_marked: bool = false) -> Dictionary:
	if source_id < 0 or source_species == "":
		return {}
	ecology_trace_sequence += 1
	var lifetime := ecology_trace_lifetime(weather_id, injured, sprinting, scent_marked)
	var strength := 1.0 + (0.42 if injured else 0.0) + (0.20 if sprinting else 0.0) + (0.46 if scent_marked else 0.0)
	var direction := Vector3(trace_direction.x, 0.0, trace_direction.z).normalized()
	var trace := {
		"sequence": ecology_trace_sequence,
		"source_id": source_id,
		"species_id": source_species,
		"position": Vector3(trace_position.x, 0.08, trace_position.z),
		"direction": direction,
		"kind": "血迹" if injured or scent_marked else "足迹",
		"strength": strength,
		"created_at": ecology_clock,
		"expires_at": ecology_clock + lifetime,
		"lifetime": lifetime,
	}
	movement_traces.append(trace)
	if movement_traces.size() > ECOLOGY_TRACE_MAX_ENTRIES:
		movement_traces.pop_front()
	return trace.duplicate(true)


func record_danger_memory(trace_position: Vector3, victim_species: String, victim_size: int, killer_species: String = "") -> Dictionary:
	ecology_trace_sequence += 1
	var combat_death := killer_species != ""
	var lifetime := (34.0 if combat_death else 23.0) + float(clampi(victim_size, 1, 5)) * 2.6
	if weather_id == "rain":
		lifetime *= 0.78
	elif weather_id == "storm":
		lifetime *= 0.66
	var memory := {
		"sequence": ecology_trace_sequence,
		"position": Vector3(trace_position.x, 0.08, trace_position.z),
		"victim_species": victim_species,
		"killer_species": killer_species,
		"kind": "血战残迹" if combat_death else "饥饿残迹",
		"radius": 8.0 + float(clampi(victim_size, 1, 5)) * 1.25 + (2.0 if combat_death else 0.0),
		"created_at": ecology_clock,
		"expires_at": ecology_clock + lifetime,
		"lifetime": lifetime,
	}
	danger_memories.append(memory)
	if danger_memories.size() > DANGER_MEMORY_MAX_ENTRIES:
		danger_memories.pop_front()
	return memory.duplicate(true)


func best_prey_trace(observer_id: int, observer_species: String, origin: Vector3, max_distance: float, after_sequence: int = 0) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for trace in movement_traces:
		var sequence := int(trace.get("sequence", 0))
		if sequence <= after_sequence or int(trace.get("source_id", -1)) == observer_id:
			continue
		var source_species := str(trace.get("species_id", ""))
		if not Catalog.considers_prey(observer_species, source_species):
			continue
		var age := ecology_clock - float(trace.get("created_at", ecology_clock))
		var lifetime := maxf(float(trace.get("lifetime", 1.0)), 1.0)
		if age < ECOLOGY_TRACE_MIN_AGE or age >= lifetime:
			continue
		var trace_position: Vector3 = trace.get("position", origin)
		var distance := origin.distance_to(trace_position)
		if distance > max_distance:
			continue
		var freshness := clampf(1.0 - age / lifetime, 0.0, 1.0)
		var score := freshness * float(trace.get("strength", 1.0)) / maxf(distance, 3.0)
		if score > best_score:
			best_score = score
			best = trace.duplicate(true)
			best["age"] = age
			best["distance"] = distance
	return best


func nearest_danger_memory(origin: Vector3, max_distance: float, excluded_sequences: Dictionary = {}) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for memory in danger_memories:
		if excluded_sequences.has(str(int(memory.get("sequence", 0)))):
			continue
		var age := ecology_clock - float(memory.get("created_at", ecology_clock))
		var lifetime := maxf(float(memory.get("lifetime", 1.0)), 1.0)
		if age >= lifetime:
			continue
		var memory_position: Vector3 = memory.get("position", origin)
		var distance := origin.distance_to(memory_position)
		if distance > max_distance:
			continue
		var freshness := clampf(1.0 - age / lifetime, 0.0, 1.0)
		var score := freshness * float(memory.get("radius", 8.0)) / maxf(distance, 2.0)
		if score > best_score:
			best_score = score
			best = memory.duplicate(true)
			best["age"] = age
			best["distance"] = distance
	return best


func ecology_trace_status(observer_id: int, observer_species: String, origin: Vector3) -> String:
	var danger := nearest_danger_memory(origin, 28.0)
	if not danger.is_empty() and float(danger.get("distance", INF)) <= float(danger.get("radius", 8.0)) + 2.0:
		return "危险记忆 · %s %s %dm · %.0fs前" % [str(danger.get("kind", "危险残迹")), compass_direction(origin, danger.get("position", origin)), roundi(float(danger.get("distance", 0.0))), maxf(float(danger.get("age", 0.0)), 1.0)]
	var trace := best_prey_trace(observer_id, observer_species, origin, 36.0)
	if not trace.is_empty():
		return "追踪线索 · %s%s %s %dm · %.0fs前" % [Catalog.display_name(str(trace.get("species_id", ""))), str(trace.get("kind", "足迹")), compass_direction(origin, trace.get("position", origin)), roundi(float(trace.get("distance", 0.0))), maxf(float(trace.get("age", 0.0)), 1.0)]
	if not danger.is_empty():
		return "危险记忆 · %s %s %dm" % [str(danger.get("kind", "危险残迹")), compass_direction(origin, danger.get("position", origin)), roundi(float(danger.get("distance", 0.0)))]
	return "生态踪迹 · 暂无线索"


func _process_ecology_events(delta: float) -> void:
	if collapse_active:
		return
	if not active_ecology_event.is_empty():
		var remaining := maxf(float(active_ecology_event.get("remaining", 0.0)) - delta, 0.0)
		active_ecology_event["remaining"] = remaining
		if is_instance_valid(active_event_visual):
			var pulse := 1.0 + sin(float(Time.get_ticks_msec()) * 0.0032) * 0.045
			active_event_visual.scale = Vector3(pulse, 1.0, pulse)
		if remaining <= 0.0:
			_end_ecology_event("资源潮已经平息")
		return
	ecology_event_timer = maxf(ecology_event_timer - delta, 0.0)
	if ecology_event_timer <= 0.0:
		start_ecology_event()


func start_ecology_event(forced_event_id: String = "") -> Dictionary:
	if collapse_active or not active_ecology_event.is_empty():
		return {}
	var available := ecology_event_ids_for_level(campaign_level)
	if available.is_empty():
		return {}
	var event_id := forced_event_id if available.has(forced_event_id) else available[event_rng.randi_range(0, available.size() - 1)]
	if available.size() > 1 and event_id == last_ecology_event_id:
		event_id = available[(available.find(event_id) + 1 + event_rng.randi_range(0, available.size() - 2)) % available.size()]
	var profile: Dictionary = ECOLOGY_EVENT_PROFILES[event_id]
	var region_id := str(profile["region"])
	var center := ecology_event_position(region_id)
	if center.x == INF:
		ecology_event_timer = 8.0
		return {}
	ecology_event_sequence += 1
	last_ecology_event_id = event_id
	var duration := 42.0 + float(clampi(campaign_level, 1, 10)) * 0.8
	var radius := 6.5 + float(clampi(campaign_level, 1, 10)) * 0.18
	active_ecology_event = {
		"sequence": ecology_event_sequence,
		"id": event_id,
		"title": str(profile["title"]),
		"region": region_id,
		"region_name": str(REGION_NAMES[region_id]),
		"description": str(profile["description"]),
		"foods": foods_for_event(profile),
		"color": str(profile["color"]),
		"position": center,
		"radius": radius,
		"duration": duration,
		"remaining": duration,
	}
	_build_ecology_event_food(profile, center)
	_build_ecology_event_visual(center, str(profile["title"]), Color.from_string(str(profile["color"]), Color("#e6c66f")), radius)
	ecology_event_started.emit(active_ecology_event.duplicate(true))
	return active_ecology_event.duplicate(true)


func foods_for_event(profile: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for food_kind in profile.get("foods", []):
		result.append(str(food_kind))
	return result


func _build_ecology_event_food(profile: Dictionary, center: Vector3) -> void:
	var foods: Array = profile["foods"]
	var patch_count := 3 + int(floor(float(clampi(campaign_level, 1, 10) - 1) / 3.0))
	var region_id := str(profile["region"])
	for index in range(patch_count):
		var angle := TAU * float(index) / float(patch_count) + event_rng.randf_range(-0.22, 0.22)
		var distance := event_rng.randf_range(1.8, 4.8)
		var candidate := center + Vector3(cos(angle), 0.0, sin(angle)) * distance
		candidate = _nearest_clear_point_in_region(candidate, region_id, 0.62)
		if candidate.x == INF:
			continue
		var patch := FoodPatchScript.new()
		patch.position = candidate
		patch.setup(str(foods[index % foods.size()]), event_rng)
		patch.mark_ecology_hotspot(ecology_event_sequence)
		patch.boost(1.22 + float(campaign_level) * 0.018)
		add_child(patch)
		food_patches.append(patch)
		active_event_patches.append(patch)


func _build_ecology_event_visual(center: Vector3, title: String, color: Color, radius: float) -> void:
	active_event_visual = Node3D.new()
	active_event_visual.name = "EcologyHotspot_%d" % ecology_event_sequence
	active_event_visual.position = Vector3(center.x, 0.0, center.z)
	add_child(active_event_visual)
	var ground_ring := MeshInstance3D.new()
	ground_ring.name = "HotspotRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.90
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 20
	ring_mesh.ring_segments = 6
	ground_ring.mesh = ring_mesh
	ground_ring.position = Vector3(0.0, 0.08, 0.0)
	ground_ring.scale = Vector3(radius, 0.22, radius)
	ground_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	active_event_ring_material = Factory.material(Color(color, 0.68), 0.72, color.darkened(0.18))
	active_event_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ground_ring.material_override = active_event_ring_material
	active_event_visual.add_child(ground_ring)
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var marker := Factory.cone("ScentMarker", Color(color, 0.72), 0.16, 0.62, Vector3(cos(angle) * radius * 0.86, 0.36, sin(angle) * radius * 0.86), 6)
		marker.rotation.z = sin(angle) * 0.32
		marker.rotation.x = cos(angle) * 0.32
		active_event_visual.add_child(marker)
	active_event_title_label = Label3D.new()
	active_event_title_label.text = title
	active_event_title_label.position = Vector3(0.0, 2.4, 0.0)
	active_event_title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	active_event_title_label.font_size = 34
	active_event_title_label.outline_size = 8
	active_event_title_label.modulate = color.lightened(0.18)
	active_event_title_label.outline_modulate = Color(0.02, 0.08, 0.06, 0.92)
	active_event_visual.add_child(active_event_title_label)


func _end_ecology_event(reason: String) -> void:
	if active_ecology_event.is_empty():
		return
	var ended_event := active_ecology_event.duplicate(true)
	ended_event["end_reason"] = reason
	for patch in active_event_patches:
		if not is_instance_valid(patch):
			continue
		patch.retire_hotspot()
		patch.queue_free()
	active_event_patches.clear()
	food_patches = food_patches.filter(func(patch: Node) -> bool: return is_instance_valid(patch) and not patch.is_queued_for_deletion())
	if is_instance_valid(active_event_visual):
		active_event_visual.queue_free()
	active_event_visual = null
	active_event_title_label = null
	active_event_ring_material = null
	active_ecology_event.clear()
	ecology_event_timer = ecology_event_repeat_delay(campaign_level, event_rng.randf())
	ecology_event_ended.emit(ended_event)


func ecology_event_position(region_id: String) -> Vector3:
	var x_sign := -1.0 if region_id in ["forest", "wetland"] else 1.0
	var z_sign := -1.0 if region_id in ["forest", "grassland"] else 1.0
	var base := Vector3(x_sign * world_size * 0.24, 0.45, z_sign * world_size * 0.24)
	base += Vector3(event_rng.randf_range(-world_size * 0.07, world_size * 0.07), 0.0, event_rng.randf_range(-world_size * 0.07, world_size * 0.07))
	return _nearest_clear_point_in_region(base, region_id, 0.72)


func get_active_ecology_event() -> Dictionary:
	return active_ecology_event.duplicate(true)


func species_can_feed_at_active_event(species_id: String) -> bool:
	for patch in active_event_patches:
		if is_instance_valid(patch) and patch.can_be_eaten_by(species_id):
			return true
	return false


func ecology_ambush_position(actor_id: int) -> Vector3:
	if active_ecology_event.is_empty():
		return Vector3(INF, 0.0, INF)
	var center: Vector3 = active_ecology_event["position"]
	var radius := float(active_ecology_event.get("radius", 7.0))
	var sequence := int(active_ecology_event.get("sequence", 0))
	var candidate := center + ecology_ambush_offset(radius, actor_id, sequence)
	return _nearest_clear_point_in_region(candidate, str(active_ecology_event.get("region", "forest")), 0.72)


func update_ecology_event_activity(migrants: int, hunters: int) -> void:
	if active_ecology_event.is_empty():
		return
	var risk := ecology_activity_risk(migrants, hunters)
	var base_color := Color.from_string(str(active_ecology_event.get("color", "#e6c66f")), Color("#e6c66f"))
	var signal_color := Color("#ef7d68") if risk == "高危" else (Color("#f0cf78") if risk == "警戒" else base_color.lightened(0.18))
	if is_instance_valid(active_event_title_label):
		active_event_title_label.text = "%s\n%s" % [str(active_ecology_event.get("title", "生态热点")), ecology_activity_status(migrants, hunters)]
		active_event_title_label.modulate = signal_color
	if active_event_ring_material != null:
		active_event_ring_material.albedo_color = Color(signal_color, 0.72)
		active_event_ring_material.emission = signal_color.darkened(0.12)


func ecology_event_attraction_radius() -> float:
	return world_size * 0.72


func ecology_event_status(origin: Vector3) -> String:
	if collapse_active:
		return "生态热点 · 收束期已停止"
	if active_ecology_event.is_empty():
		return "生态热点 · 下一次信号 %ds" % ceili(ecology_event_timer)
	var target: Vector3 = active_ecology_event["position"]
	var distance := roundi(Vector2(target.x - origin.x, target.z - origin.z).length())
	return "生态热点 · %s · %s %dm · %ds" % [
		str(active_ecology_event["title"]), compass_direction(origin, target), distance, ceili(float(active_ecology_event["remaining"])),
	]


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
	var best_position := Vector3.ZERO + Vector3.UP * 0.45
	var best_clearance := -INF
	for attempt in range(160):
		var pos := _random_valid_position(7.0)
		var clearance := minimum_spawn_distance(pos, avoid_positions)
		if clearance > best_clearance:
			best_clearance = clearance
			best_position = pos
		if clearance >= minimum_actor_distance:
			return pos
	# Dense maps may not satisfy the requested gap. Use the widest sampled point;
	# the old central 24 m fallback piled late actors on top of one another and
	# caused level-10 deaths on the first simulation frame.
	return best_position


func random_spawn_in_regions(region_ids: Array[String], avoid_positions: Array[Vector3] = [], minimum_actor_distance: float = 6.0) -> Vector3:
	if region_ids.is_empty():
		return random_spawn(avoid_positions, minimum_actor_distance)
	var best_position := Vector3(INF, 0.45, INF)
	var best_clearance := -INF
	for attempt in range(220):
		var pos := _random_valid_position(7.0)
		if not region_ids.has(region_id_at(pos)):
			continue
		var clearance := minimum_spawn_distance(pos, avoid_positions)
		if clearance > best_clearance:
			best_clearance = clearance
			best_position = pos
		if clearance >= minimum_actor_distance:
			return pos
	if best_position.x != INF:
		return best_position
	return random_spawn(avoid_positions, minimum_actor_distance)


static func minimum_spawn_distance(pos: Vector3, avoid_positions: Array[Vector3]) -> float:
	var clearance := INF
	for other in avoid_positions:
		clearance = minf(clearance, pos.distance_to(other))
	return clearance


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
	var region_id := region_id_at(pos)
	var affinity := Catalog.habitat_affinity(species_id, region_id)
	if affinity >= 0.99:
		multiplier *= 1.08
	elif affinity >= TERRAIN_COUNTER_THRESHOLD:
		multiplier *= 1.045
	var size_level := Catalog.body_size(species_id)
	if affinity < TERRAIN_COUNTER_THRESHOLD:
		if region_id == "forest" and size_level >= 4:
			multiplier *= 0.93
		elif region_id == "highland" and not Catalog.has_trait(species_id, "climber"):
			multiplier *= 0.92 if size_level >= 4 else 0.96
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


func stamina_regen_multiplier(species_id: String, pos: Vector3) -> float:
	var region_id := region_id_at(pos)
	var affinity := Catalog.habitat_affinity(species_id, region_id)
	var multiplier := 1.0
	if affinity >= 0.99:
		multiplier *= 1.14
	elif affinity >= TERRAIN_COUNTER_THRESHOLD:
		multiplier *= 1.08
	if region_id == "wetland" and Catalog.has_trait(species_id, "wetland_swimmer") and weather_id in ["rain", "storm"]:
		multiplier *= 1.08
	elif region_id == "forest" and weather_id == "fog" and Catalog.has_trait(species_id, "ambusher"):
		multiplier *= 1.06
	return multiplier


func stamina_cost_multiplier(species_id: String, pos: Vector3) -> float:
	var region_id := region_id_at(pos)
	var affinity := Catalog.habitat_affinity(species_id, region_id)
	var multiplier := 1.0
	if affinity >= 0.99:
		multiplier *= 0.88
	elif affinity >= TERRAIN_COUNTER_THRESHOLD:
		multiplier *= 0.94
	if region_id == "highland" and Catalog.has_trait(species_id, "climber"):
		multiplier *= 0.94
	elif region_id == "grassland" and Catalog.has_trait(species_id, "straight_runner"):
		multiplier *= 0.94
	return multiplier


func terrain_counter_strength(attacker_id: String, attacker_pos: Vector3, target_id: String, target_pos: Vector3) -> float:
	var region_id := region_id_at(attacker_pos)
	if region_id_at(target_pos) != region_id:
		return 0.0
	var attacker_affinity := Catalog.habitat_affinity(attacker_id, region_id)
	var target_affinity := Catalog.habitat_affinity(target_id, region_id)
	if attacker_affinity < TERRAIN_COUNTER_THRESHOLD or target_affinity >= TERRAIN_COUNTER_THRESHOLD:
		return 0.0
	var strength := attacker_affinity
	if region_id == "wetland" and Catalog.has_trait(attacker_id, "wetland_swimmer") and not Catalog.has_trait(target_id, "wetland_swimmer"):
		strength += 0.16
	elif region_id == "highland" and Catalog.has_trait(attacker_id, "climber") and not Catalog.has_trait(target_id, "climber"):
		strength += 0.12
	elif region_id == "forest" and Catalog.has_trait(attacker_id, "ambusher"):
		strength += 0.10
	elif region_id == "grassland" and Catalog.has_trait(attacker_id, "straight_runner") and not Catalog.has_trait(target_id, "straight_runner"):
		strength += 0.10
	if weather_id == "fog" and Catalog.has_trait(attacker_id, "ambusher"):
		strength += 0.08
	elif weather_id in ["rain", "storm"] and Catalog.has_trait(attacker_id, "wetland_swimmer"):
		strength += 0.08
	return clampf(strength, 0.0, 1.0)


func terrain_counter_name(region_id: String) -> String:
	return str({
		"forest": "密林周旋",
		"grassland": "旷野游斗",
		"wetland": "浅滩牵制",
		"highland": "岩径反制",
	}.get(region_id, "地形反制"))


func best_counter_habitat(origin: Vector3, threat_position: Vector3, species_id: String, target_species_id: String, max_distance: float = 18.0) -> Vector3:
	var current_region := region_id_at(origin)
	if Catalog.habitat_affinity(species_id, current_region) >= TERRAIN_COUNTER_THRESHOLD and Catalog.habitat_affinity(target_species_id, current_region) < TERRAIN_COUNTER_THRESHOLD:
		return Vector3(INF, 0.0, INF)
	var best := Vector3(INF, 0.0, INF)
	var best_score := -INF
	var current_threat_distance := Vector2(origin.x - threat_position.x, origin.z - threat_position.z).length()
	for region_id in Catalog.preferred_regions(species_id):
		if Catalog.habitat_affinity(target_species_id, region_id) >= TERRAIN_COUNTER_THRESHOLD:
			continue
		var candidate := _nearest_point_in_region(origin, region_id, 2.6)
		var route_distance := Vector2(candidate.x - origin.x, candidate.z - origin.z).length()
		if route_distance > max_distance:
			continue
		candidate = _nearest_clear_point_in_region(candidate, region_id, 0.55)
		if candidate.x == INF:
			continue
		if collapse_active and Vector2(candidate.x, candidate.z).length() > collapse_radius - 1.8:
			continue
		var threat_distance := Vector2(candidate.x - threat_position.x, candidate.z - threat_position.z).length()
		var safety_gain := threat_distance - current_threat_distance
		var affinity := Catalog.habitat_affinity(species_id, region_id)
		var score := affinity * 7.0 + safety_gain * 0.20 - route_distance * 0.24
		if score > best_score:
			best_score = score
			best = candidate
	return best


func _nearest_point_in_region(origin: Vector3, region_id: String, margin: float) -> Vector3:
	var edge := maxf(world_size * 0.5 - 2.2, margin + 0.5)
	var wants_west := region_id in ["forest", "wetland"]
	var wants_north := region_id in ["forest", "grassland"]
	var target_x := minf(origin.x, -margin) if wants_west else maxf(origin.x, margin)
	var target_z := minf(origin.z, -margin) if wants_north else maxf(origin.z, margin)
	return Vector3(clampf(target_x, -edge, edge), 0.45, clampf(target_z, -edge, edge))


func _nearest_clear_point_in_region(origin: Vector3, region_id: String, actor_radius: float) -> Vector3:
	if region_id_at(origin) == region_id and is_landing_clear(origin, actor_radius):
		return origin
	for ring_index in range(1, 5):
		var radius := float(ring_index) * 1.35
		for direction_index in range(12):
			var angle := TAU * float(direction_index) / 12.0
			var candidate := clamp_position(origin + Vector3(cos(angle), 0.0, sin(angle)) * radius)
			candidate.y = 0.45
			if region_id_at(candidate) == region_id and is_landing_clear(candidate, actor_radius):
				return candidate
	return Vector3(INF, 0.0, INF)


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


func cover_strength_at(pos: Vector3, species_id: String) -> float:
	if pos.y > 1.30 or cover_positions.is_empty():
		return 0.0
	var size_level := int(Catalog.get_data(species_id).get("size", 3))
	var size_factor: float = {1: 1.0, 2: 0.90, 3: 0.68, 4: 0.24, 5: 0.0}.get(size_level, 0.0)
	if size_factor <= 0.0:
		return 0.0
	var strongest := 0.0
	for index in range(cover_positions.size()):
		var radius := cover_radii[index] if index < cover_radii.size() else 1.6
		var distance := Vector2(pos.x - cover_positions[index].x, pos.z - cover_positions[index].z).length()
		if distance >= radius:
			continue
		var depth := 1.0 - distance / maxf(radius, 0.1)
		strongest = maxf(strongest, size_factor * lerpf(0.62, 1.0, depth))
	return clampf(strongest, 0.0, 1.0)


func best_escape_cover(origin: Vector3, threat_position: Vector3, species_id: String, max_distance: float = 15.0) -> Vector3:
	var best := Vector3(INF, 0.0, INF)
	var best_score := -INF
	var current_threat_distance := Vector2(origin.x - threat_position.x, origin.z - threat_position.z).length()
	for index in range(cover_positions.size()):
		var candidate := cover_positions[index]
		var route_distance := Vector2(candidate.x - origin.x, candidate.z - origin.z).length()
		if route_distance > max_distance or cover_strength_at(candidate, species_id) < 0.58:
			continue
		if collapse_active and Vector2(candidate.x, candidate.z).length() > collapse_radius - 1.8:
			continue
		var candidate_threat_distance := Vector2(candidate.x - threat_position.x, candidate.z - threat_position.z).length()
		var safety_gain := candidate_threat_distance - current_threat_distance
		if safety_gain < -1.0:
			continue
		var score := cover_strength_at(candidate, species_id) * 6.0 + safety_gain * 0.42 - route_distance * 0.26
		if score > best_score:
			best_score = score
			best = Vector3(candidate.x, 0.45, candidate.z)
	return best


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
	var best_position := Vector3.ZERO + Vector3.UP * 0.45
	var best_clearance := -INF
	for attempt in range(100):
		var half := world_size * 0.5 - edge_margin
		var pos := Vector3(rng.randf_range(-half, half), 0.45, rng.randf_range(-half, half))
		var clearance := INF
		for index in range(obstacles.size()):
			clearance = minf(clearance, pos.distance_to(obstacles[index]) - obstacle_radii[index] - 1.8)
		if clearance > best_clearance:
			best_clearance = clearance
			best_position = pos
		if clearance >= 0.0:
			return pos
	return best_position
