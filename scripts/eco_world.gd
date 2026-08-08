class_name EcoWorld
extends Node3D

const Factory = preload("res://scripts/low_poly_factory.gd")
const FoodPatchScript = preload("res://scripts/food_patch.gd")

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
var collapse_active: bool = false
var collapse_radius: float = INF
var rng := RandomNumberGenerator.new()
var obstacles: Array[Vector3] = []
var obstacle_radii: Array[float] = []
var food_patches: Array[Node] = []
var decoration_root: Node3D
var obstacle_root: Node3D


func setup(seed_value: int, size_value: float = 86.0) -> void:
	rng.seed = seed_value
	world_size = size_value
	density_scale = clampf(world_size / 86.0, 1.0, 3.0)
	name = "GeneratedForest_%s" % seed_value
	_build_environment()
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


func _build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#a9c7b0")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c9dac3")
	environment.ambient_light_energy = 0.56
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.98
	environment.adjustment_contrast = 1.10
	environment.adjustment_saturation = 1.00
	environment.fog_enabled = true
	environment.fog_light_color = Color("#b9cfb8")
	environment.fog_light_energy = 0.55
	environment.fog_density = 0.0018
	environment.fog_sky_affect = 0.30
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("#ffe0aa")
	sun.light_energy = 1.00
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = minf(world_size * 0.82, 150.0)
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
		Factory.add_static_cylinder(obstacle_root, collision_radius, height, Vector3(pos.x, height * 0.5, pos.z))


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
		Factory.add_static_box(obstacle_root, Vector3(scale_value.x * 0.9, scale_value.y * 0.8, scale_value.z * 0.9), Vector3(pos.x, scale_value.y * 0.4, pos.z), rock.rotation.y)


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
	if not collapse_active:
		return
	var min_radius := world_size * COLLAPSE_MIN_RADIUS_RATIO
	if collapse_radius > min_radius:
		var shrink_rate := (world_size * 0.47 - min_radius) / COLLAPSE_SHRINK_SECONDS
		collapse_radius = maxf(collapse_radius - shrink_rate * delta, min_radius)


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


func steer_around_obstacles(origin: Vector3, desired: Vector3, actor_radius: float, actor_id: int) -> Vector3:
	if desired.length() < 0.05:
		return Vector3.ZERO
	var flat_desired := Vector3(desired.x, 0.0, desired.z).normalized()
	var look_ahead := 2.1 + actor_radius * 1.8
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
