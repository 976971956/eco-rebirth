class_name FoodPatch
extends Node3D

const Factory = preload("res://scripts/low_poly_factory.gd")
const Catalog = preload("res://scripts/species_catalog.gd")

const FOOD_DATA := {
	"grass": {"name": "嫩草", "amount": 42.0, "regrow": 13.0, "nutrition": 0.90, "diets": ["herbivore", "omnivore"]},
	"berries": {"name": "野莓", "amount": 36.0, "regrow": 18.0, "nutrition": 1.00, "diets": ["herbivore", "omnivore"]},
	"mushroom": {"name": "林地蘑菇", "amount": 30.0, "regrow": 22.0, "nutrition": 1.08, "diets": ["herbivore", "omnivore"]},
	"fruit": {"name": "落果", "amount": 48.0, "regrow": 24.0, "nutrition": 1.18, "diets": ["herbivore", "omnivore"]},
	"roots": {"name": "块根", "amount": 44.0, "regrow": 26.0, "nutrition": 1.15, "diets": ["herbivore", "omnivore"]},
	"fish": {"name": "活鱼群", "amount": 48.0, "regrow": 25.0, "nutrition": 1.45, "diets": ["carnivore", "omnivore"]},
}

const FOOD_VISUAL_VERSION := 2
const FOOD_VISUAL_SIGNATURES := {
	"grass": "tender_grass_rosette",
	"berries": "wild_berry_bramble",
	"mushroom": "woodland_mushroom_cluster",
	"fruit": "fallen_orchard_fruit",
	"roots": "exposed_root_crown",
	"fish": "living_shallow_fish_school",
}

var amount: float = 45.0
var max_amount: float = 45.0
var regrow_delay: float = 16.0
var empty_time: float = 0.0
var active: bool = true
var regrow_enabled: bool = true
var visual_root: Node3D
var food_kind: String = "grass"
var nutrient_tier: String = "common"
var nutrient_experience: int = 3
var nutrient_cluster_id: int = -1
var ecology_hotspot: bool = false
var ecology_event_id: int = -1
var fish_animation_time: float = 0.0

static var _compact_tender_grass_mesh: Mesh
static var _compact_tender_grass_material: Material
static var _compact_loft_meshes: Dictionary = {}


func setup(kind: String, rng: RandomNumberGenerator, tier: String = "common", cluster_id: int = -1, compact_visual: bool = false) -> void:
	food_kind = kind if FOOD_DATA.has(kind) else "grass"
	nutrient_tier = tier if tier in ["common", "rich", "rare"] else "common"
	nutrient_cluster_id = cluster_id
	match nutrient_tier:
		"rare": nutrient_experience = rng.randi_range(15, 25)
		"rich": nutrient_experience = rng.randi_range(6, 9)
		_: nutrient_experience = rng.randi_range(3, 5)
	var config: Dictionary = FOOD_DATA[food_kind]
	max_amount = float(config["amount"])
	if nutrient_tier == "rich":
		max_amount *= 1.18
	elif nutrient_tier == "rare":
		max_amount *= 1.36
	amount = max_amount
	regrow_delay = float(config["regrow"])
	# FoodPatch already is a Node3D. Reusing it as the visual root removes one
	# transform node per resource, which matters on 100-actor mobile maps.
	visual_root = self
	name = "Food_%s" % food_kind
	# The world RNG advances exactly once for presentation.  All remaining shape
	# variation uses a private stream, so changing food art quality cannot move
	# actors, landmarks or later resource spawns in the same world seed.
	var visual_rng := RandomNumberGenerator.new()
	var visual_seed := int(rng.randi()) ^ int(food_kind.hash()) ^ int(nutrient_cluster_id * 7919)
	visual_rng.seed = visual_seed
	set_meta("food_visual_version", FOOD_VISUAL_VERSION)
	set_meta("food_visual_signature", str(FOOD_VISUAL_SIGNATURES[food_kind]))
	set_meta("food_visual_seed", visual_seed)
	set_meta("compact_visual", compact_visual)
	_build_visual(visual_rng, compact_visual)
	set_process(food_kind == "fish")


func _build_visual(rng: RandomNumberGenerator, compact_visual: bool = false) -> void:
	match food_kind:
		"berries": _build_berry_bramble(rng, compact_visual)
		"mushroom": _build_mushroom_cluster(rng, compact_visual)
		"fruit": _build_fallen_fruit(rng, compact_visual)
		"roots": _build_root_crown(rng, compact_visual)
		"fish": _build_fish_school(rng, compact_visual)
		_:
			_build_tender_grass(rng, compact_visual)
	if nutrient_tier in ["rich", "rare"]:
		var nutrient_color := Color("#f2cd67") if nutrient_tier == "rich" else Color("#d59bff")
		var nutrient_ring := Factory.disc("NutrientSignal", Color(nutrient_color, 0.55), 0.82 if nutrient_tier == "rich" else 1.02, 0.025, Vector3(0.0, 0.025, 0.0), 16)
		nutrient_ring.material_override = Factory.material(Color(nutrient_color, 0.44), 0.35, nutrient_color)
		nutrient_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual_root.add_child(nutrient_ring)


func _build_tender_grass(rng: RandomNumberGenerator, compact_visual: bool) -> void:
	var tuft: MeshInstance3D
	if compact_visual and _compact_tender_grass_mesh != null and _compact_tender_grass_material != null:
		tuft = MeshInstance3D.new()
		tuft.name = "TenderGrassRosette"
		tuft.mesh = _compact_tender_grass_mesh
		tuft.material_override = _compact_tender_grass_material
		tuft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		tuft.extra_cull_margin = 0.22
		tuft.set_meta("visual_only", true)
		tuft.set_meta("natural_grass_tuft", true)
		tuft.set_meta("blade_count", 12)
		tuft.set_meta("triangle_count", 48)
	else:
		tuft = Factory.grass_tuft(
			"TenderGrassRosette",
			Color("#365f2e"),
			Color("#9fc46b"),
			0.50 if compact_visual else 0.64,
			0.64 if compact_visual else 0.82,
			12 if compact_visual else 22,
			681208 if compact_visual else rng.randi(),
			1.12,
			0.44
		)
		if compact_visual:
			_compact_tender_grass_mesh = tuft.mesh
			_compact_tender_grass_material = tuft.material_override
	tuft.set_meta("food_visual_part", "edible_grass_rosette")
	visual_root.add_child(tuft)


func _build_berry_bramble(rng: RandomNumberGenerator, compact_visual: bool) -> void:
	var branch_count := 2 if compact_visual else 4
	for i in range(branch_count):
		var angle := TAU * float(i) / float(branch_count) + rng.randf_range(-0.28, 0.28)
		var branch_height := rng.randf_range(0.66, 0.88)
		var branch := Factory.tapered_cylinder("BrambleStem_%02d" % i, Color("#554830").lightened(rng.randf_range(-0.04, 0.05)), 0.042, 0.020, branch_height, Vector3(cos(angle) * 0.12, branch_height * 0.5, sin(angle) * 0.12), 6)
		branch.rotation = Vector3(sin(angle) * 0.17, 0.0, -cos(angle) * 0.17)
		visual_root.add_child(branch)
	var leaf_count := 3 if compact_visual else 9
	for i in range(leaf_count):
		var angle := TAU * float(i) / float(leaf_count) + rng.randf_range(-0.16, 0.16)
		var height := rng.randf_range(0.30, 0.72)
		var leaf_color := Color("#3c6943") if compact_visual else Color("#35633d").lightened(rng.randf_range(-0.05, 0.08))
		var leaf_length := 0.44 if compact_visual else rng.randf_range(0.36, 0.52)
		var leaf_width := 0.16 if compact_visual else rng.randf_range(0.13, 0.19)
		var leaf_bend := 0.075 if compact_visual else rng.randf_range(0.055, 0.095)
		var leaf := Factory.organic_leaf("BrambleLeaf_%02d" % i, leaf_color, leaf_length, leaf_width, Vector3(cos(angle) * 0.15, height, sin(angle) * 0.15), leaf_bend, "berry_leaf_v2" if compact_visual else "")
		leaf.rotation = Vector3(rng.randf_range(-0.54, -0.30), angle, rng.randf_range(-0.12, 0.12))
		visual_root.add_child(leaf)
	var berry_count := 4 if compact_visual else 13
	for i in range(berry_count):
		var cluster_angle := TAU * float(i % 5) / 5.0 + float(i / 5) * 1.38
		var cluster_radius := 0.20 + float(i % 3) * 0.055
		var berry_color := Color("#493251") if i % 3 != 0 else Color("#633b58")
		var berry := Factory.sphere("WildBerry_%02d" % i, berry_color.lightened(rng.randf_range(-0.035, 0.065)), Vector3(0.17, 0.15, 0.17) * rng.randf_range(0.88, 1.10), Vector3(cos(cluster_angle) * cluster_radius, 0.58 + float(i % 4) * 0.075, sin(cluster_angle) * cluster_radius), 7, 4)
		berry.set_meta("food_visual_part", "ripe_wild_berry")
		visual_root.add_child(berry)


func _build_mushroom_cluster(rng: RandomNumberGenerator, compact_visual: bool) -> void:
	var mushroom_count := 1 if compact_visual else 5
	var cap_palette: Array[Color] = [Color("#8d5a37"), Color("#a66e42"), Color("#735142"), Color("#b4875c")]
	for i in range(mushroom_count):
		var angle := TAU * float(i) / float(mushroom_count) + rng.randf_range(-0.25, 0.25)
		var radius := 0.18 + float(i % 3) * 0.16
		var offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var height := 0.52 if compact_visual else rng.randf_range(0.42, 0.72)
		var group := Node3D.new()
		group.name = "WoodlandMushroom_%02d" % i
		group.position = offset
		group.rotation = Vector3(rng.randf_range(-0.025, 0.025), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.035, 0.035))
		group.add_child(Factory.tapered_cylinder("TaperedStem", Color("#d8c9a9").lightened(rng.randf_range(-0.03, 0.05)), 0.088, 0.060, height, Vector3.UP * height * 0.5, 7))
		var cap_radius := 0.33 if compact_visual else rng.randf_range(0.28, 0.39)
		group.add_child(Factory.disc("PaleGills", Color("#bfae8c"), cap_radius * 0.83, 0.026, Vector3.UP * (height - 0.018), 12))
		var cap_centers: Array = [
			Vector3(0.0, height, 0.0),
			Vector3(0.0, height + cap_radius * 0.12, 0.0),
			Vector3(0.0, height + cap_radius * 0.43, 0.0),
			Vector3(0.0, height + cap_radius * 0.62, 0.0),
		]
		var cap_radii: Array = [
			Vector2(cap_radius * 0.90, cap_radius * 0.90),
			Vector2(cap_radius, cap_radius),
			Vector2(cap_radius * 0.64, cap_radius * 0.64),
			Vector2(cap_radius * 0.09, cap_radius * 0.09),
		]
		var cap_color := cap_palette[i % cap_palette.size()] if compact_visual else cap_palette[i % cap_palette.size()].lightened(rng.randf_range(-0.04, 0.05))
		group.add_child(_food_loft("DomedCap", "mushroom_cap_v2" if compact_visual else "", cap_color, cap_centers, cap_radii, 10))
		group.set_meta("food_visual_part", "gilled_mushroom")
		visual_root.add_child(group)
	if not compact_visual:
		var forest_leaf := Factory.organic_leaf("FallenForestLeaf", Color("#6a5434"), 0.56, 0.18, Vector3(-0.48, 0.035, 0.28), 0.035)
		forest_leaf.rotation = Vector3(0.0, -0.72, 0.0)
		visual_root.add_child(forest_leaf)


func _build_fallen_fruit(rng: RandomNumberGenerator, compact_visual: bool) -> void:
	var fruit_count := 2 if compact_visual else 7
	var fruit_palette: Array[Color] = [Color("#b64f3f"), Color("#d49437"), Color("#738345"), Color("#a75c33")]
	for i in range(fruit_count):
		var angle := TAU * float(i) / float(fruit_count) + rng.randf_range(-0.24, 0.24)
		var radius := rng.randf_range(0.18, 0.68)
		var fruit_group := Node3D.new()
		fruit_group.name = "FallenFruit_%02d" % i
		fruit_group.position = Vector3(cos(angle) * radius, 0.035, sin(angle) * radius)
		fruit_group.rotation = Vector3(rng.randf_range(-0.16, 0.16), rng.randf_range(-PI, PI), rng.randf_range(-0.18, 0.18))
		var fruit_height := 0.38 + float(i % 2) * 0.055 if compact_visual else rng.randf_range(0.34, 0.46)
		var fruit_width := 0.175 + float(i % 2) * 0.012 if compact_visual else rng.randf_range(0.15, 0.21)
		var centers: Array = [
			Vector3(0.0, 0.02, 0.0),
			Vector3(0.0, fruit_height * 0.28, 0.0),
			Vector3(0.0, fruit_height * 0.66, 0.0),
			Vector3(0.0, fruit_height, 0.0),
		]
		var radii: Array = [
			Vector2(fruit_width * 0.58, fruit_width * 0.58),
			Vector2(fruit_width, fruit_width * 0.92),
			Vector2(fruit_width * (0.90 if i % 2 == 0 else 0.72), fruit_width * 0.84),
			Vector2(fruit_width * 0.30, fruit_width * 0.28),
		]
		var fruit_color := fruit_palette[i % fruit_palette.size()] if compact_visual else fruit_palette[i % fruit_palette.size()].lightened(rng.randf_range(-0.04, 0.05))
		fruit_group.add_child(_food_loft("OrganicFruitBody", "fruit_body_v2_%d" % (i % 2) if compact_visual else "", fruit_color, centers, radii, 9))
		fruit_group.add_child(Factory.tapered_cylinder("FruitStem", Color("#4b3825"), 0.024, 0.014, 0.14, Vector3(0.0, fruit_height + 0.065, 0.0), 6))
		if not compact_visual or i == 0:
			var leaf := Factory.organic_leaf("FruitLeaf", Color("#4d6d38"), 0.24, 0.075, Vector3(0.0, fruit_height + 0.05, 0.0), 0.045, "fruit_leaf_v2" if compact_visual else "")
			leaf.rotation = Vector3(-0.34, rng.randf_range(-PI, PI), 0.14)
			fruit_group.add_child(leaf)
		fruit_group.set_meta("food_visual_part", "pear_apple_body")
		visual_root.add_child(fruit_group)


func _build_root_crown(rng: RandomNumberGenerator, compact_visual: bool) -> void:
	var soil := Factory.disc("DisturbedSoil", Color("#46382b"), 0.64 if compact_visual else 0.82, 0.045, Vector3(0.0, 0.018, 0.0), 12)
	soil.scale.z = 0.76
	soil.set_meta("food_visual_part", "disturbed_soil")
	visual_root.add_child(soil)
	var root_count := 2 if compact_visual else 6
	for i in range(root_count):
		var angle := float(i) * 2.399963 + rng.randf_range(-0.28, 0.28)
		var length := 0.50 + float(i % 2) * 0.11 if compact_visual else rng.randf_range(0.42, 0.68)
		var root_group := Node3D.new()
		root_group.name = "TuberRoot_%02d" % i
		root_group.rotation.y = angle
		var bend_a := (0.026 if i % 2 == 0 else -0.026) if compact_visual else rng.randf_range(-0.035, 0.035)
		var bend_b := (-0.038 if i % 2 == 0 else 0.038) if compact_visual else rng.randf_range(-0.05, 0.05)
		var bend_c := (0.052 if i % 2 == 0 else -0.052) if compact_visual else rng.randf_range(-0.07, 0.07)
		var centers: Array = [
			Vector3(0.0, 0.16, 0.04),
			Vector3(bend_a, 0.14, length * 0.30),
			Vector3(bend_b, 0.10, length * 0.70),
			Vector3(bend_c, 0.055, length),
		]
		var girth := 0.10 + float(i % 2) * 0.016 if compact_visual else rng.randf_range(0.085, 0.135)
		var radii: Array = [Vector2(girth * 0.55, girth * 0.54), Vector2(girth, girth * 0.78), Vector2(girth * 0.70, girth * 0.58), Vector2(0.026, 0.022)]
		var root_color := Color("#795038").lightened(float(i % 2) * 0.045) if compact_visual else Color("#795038").lightened(rng.randf_range(-0.06, 0.07))
		root_group.add_child(_food_loft("TaperedTuber", "tuber_v2_%d" % (i % 2) if compact_visual else "", root_color, centers, radii, 7))
		root_group.set_meta("food_visual_part", "edible_tuber")
		visual_root.add_child(root_group)
	var shoot_count := 3 if compact_visual else 8
	for i in range(shoot_count):
		var shoot_angle := TAU * float(i) / float(shoot_count) + rng.randf_range(-0.18, 0.18)
		var shoot_color := Color("#5a7f48") if compact_visual else Color("#527842").lightened(rng.randf_range(-0.04, 0.08))
		var shoot_length := 0.52 if compact_visual else rng.randf_range(0.42, 0.62)
		var shoot_width := 0.115 if compact_visual else rng.randf_range(0.09, 0.14)
		var shoot_bend := 0.135 if compact_visual else rng.randf_range(0.10, 0.17)
		var shoot := Factory.organic_leaf("RootShoot_%02d" % i, shoot_color, shoot_length, shoot_width, Vector3(cos(shoot_angle) * 0.08, 0.16, sin(shoot_angle) * 0.08), shoot_bend, "root_shoot_v2" if compact_visual else "")
		shoot.rotation = Vector3(rng.randf_range(-0.90, -0.60), shoot_angle, rng.randf_range(-0.09, 0.09))
		visual_root.add_child(shoot)


func _build_fish_school(rng: RandomNumberGenerator, compact_visual: bool) -> void:
	var fish_count := 2 if compact_visual else 6
	var fish_palette: Array[Color] = [Color("#77989a"), Color("#829a76"), Color("#6f8fa1"), Color("#9a8d67")]
	for i in range(fish_count):
		var swimmer := Node3D.new()
		swimmer.name = "LiveFish_%02d" % i
		var school_center := Vector3(rng.randf_range(-0.78, 0.78), 0.07 + float(i % 2) * 0.025, rng.randf_range(-0.60, 0.60))
		swimmer.set_meta("school_center", school_center)
		swimmer.set_meta("phase", rng.randf_range(0.0, TAU))
		swimmer.set_meta("orbit", rng.randf_range(0.10, 0.24))
		swimmer.set_meta("swim_rate", rng.randf_range(0.72, 1.20))
		swimmer.set_meta("food_visual_part", "articulated_fish")
		var fish_color := fish_palette[i % fish_palette.size()].darkened(0.06 if compact_visual else rng.randf_range(0.02, 0.11))
		var fish_length := 0.68 + float(i % 2) * 0.09 if compact_visual else rng.randf_range(0.64, 0.82)
		var body_centers: Array = [
			Vector3(0.0, 0.0, -fish_length * 0.48),
			Vector3(0.0, 0.0, -fish_length * 0.24),
			Vector3(0.0, 0.0, fish_length * 0.10),
			Vector3(0.0, 0.0, fish_length * 0.42),
		]
		var body_radii: Array = [Vector2(0.045, 0.036), Vector2(0.135, 0.092), Vector2(0.155, 0.102), Vector2(0.040, 0.034)]
		swimmer.add_child(_food_loft("StreamlinedFishBody", "fish_body_v2_%d" % (i % 2) if compact_visual else "", fish_color, body_centers, body_radii, 8))
		for tail_index in range(2):
			var tail := Factory.organic_leaf("TailFin_%02d" % tail_index, fish_color.darkened(0.13), fish_length * 0.34, 0.125, Vector3(0.0, 0.0, fish_length * 0.39), 0.022, "fish_tail_v2_%d" % (i % 2) if compact_visual else "")
			tail.rotation.x = -0.48 if tail_index == 0 else 0.48
			swimmer.add_child(tail)
		var dorsal := Factory.organic_leaf("DorsalFin", fish_color.darkened(0.18), fish_length * 0.23, 0.080, Vector3(0.0, 0.088, -fish_length * 0.02), 0.018, "fish_dorsal_v2_%d" % (i % 2) if compact_visual else "")
		dorsal.rotation = Vector3(0.0, 0.0, PI * 0.5)
		swimmer.add_child(dorsal)
		var side_fin := Factory.organic_leaf("PectoralFin", fish_color.darkened(0.11), fish_length * 0.18, 0.064, Vector3(0.112, -0.015, -fish_length * 0.05), 0.014, "fish_side_v2_%d" % (i % 2) if compact_visual else "")
		side_fin.rotation.y = PI * 0.5
		swimmer.add_child(side_fin)
		var eye_sides: Array[float] = [1.0]
		if not compact_visual:
			eye_sides.push_front(-1.0)
		for eye_side in eye_sides:
			swimmer.add_child(Factory.sphere("FishEye", Color("#111717"), Vector3.ONE * 0.044, Vector3(eye_side * 0.098, 0.044, -fish_length * 0.35), 6, 4))
		visual_root.add_child(swimmer)


func _food_loft(name_text: String, compact_cache_key: String, color: Color, centers: Array, radii: Array, sides: int) -> MeshInstance3D:
	if compact_cache_key.is_empty():
		return Factory.loft(name_text, color, centers, radii, sides)
	if _compact_loft_meshes.has(compact_cache_key):
		var cached := MeshInstance3D.new()
		cached.name = name_text
		cached.mesh = _compact_loft_meshes[compact_cache_key] as Mesh
		cached.material_override = Factory.faceted_material()
		cached.set_meta("shared_food_mesh", true)
		return cached
	var generated := Factory.loft(name_text, color, centers, radii, sides)
	_compact_loft_meshes[compact_cache_key] = generated.mesh
	generated.set_meta("shared_food_mesh", true)
	return generated


func can_be_eaten_by(species_id: String) -> bool:
	var diet := str(Catalog.get_data(species_id)["diet"])
	return diet in FOOD_DATA[food_kind]["diets"]


func get_food_name() -> String:
	return str(FOOD_DATA[food_kind]["name"])


func get_nutrition_multiplier() -> float:
	return float(FOOD_DATA[food_kind]["nutrition"])


func get_experience_reward(species_id: String, region_id: String = "") -> int:
	var reward := nutrient_experience
	if food_kind in Catalog.habit_favored_foods(species_id):
		reward += 2
	if region_id != "" and Catalog.habitat_affinity(species_id, region_id) >= 0.99:
		reward += 1
	return maxi(reward, 1)


func consume(requested: float) -> float:
	if not active or amount <= 0.0:
		return 0.0
	var taken := minf(requested, amount)
	amount -= taken
	_update_visual()
	if amount <= 0.01:
		active = false
		empty_time = 0.0
		set_process(true)
	return taken


func _process(delta: float) -> void:
	if food_kind == "fish" and active:
		_animate_fish_school(delta)
	if active or not regrow_enabled:
		return
	empty_time += delta
	if empty_time >= regrow_delay:
		amount = max_amount
		active = true
		_update_visual()
		set_process(food_kind == "fish")


func _animate_fish_school(delta: float) -> void:
	if visual_root == null:
		return
	fish_animation_time += delta
	for child in visual_root.get_children():
		if not child is Node3D or not child.has_meta("school_center"):
			continue
		var swimmer := child as Node3D
		var center: Vector3 = swimmer.get_meta("school_center", Vector3.ZERO)
		var phase := float(swimmer.get_meta("phase", 0.0))
		var orbit := float(swimmer.get_meta("orbit", 0.16))
		var rate := float(swimmer.get_meta("swim_rate", 1.0))
		var angle := fish_animation_time * rate + phase
		swimmer.position = center + Vector3(cos(angle) * orbit, sin(angle * 1.7) * 0.018, sin(angle) * orbit)
		var swim_direction := Vector3(-sin(angle), 0.0, cos(angle)).normalized()
		swimmer.rotation.y = atan2(-swim_direction.x, -swim_direction.z)


func boost(multiplier: float) -> void:
	max_amount *= multiplier
	amount = max_amount
	active = true
	_update_visual()


func mark_ecology_hotspot(event_id: int) -> void:
	ecology_hotspot = true
	ecology_event_id = event_id


func retire_hotspot() -> void:
	regrow_enabled = false
	active = false
	amount = 0.0
	_update_visual()
	set_process(false)


func stop_regrow() -> void:
	regrow_enabled = false
	if not active:
		set_process(false)


func _update_visual() -> void:
	if visual_root == null:
		return
	var ratio := clampf(amount / max_amount, 0.0, 1.0)
	visual_root.visible = ratio > 0.01
	visual_root.scale = Vector3.ONE * lerpf(0.25, 1.0, ratio)
