extends SceneTree

const ActorScript = preload("res://scripts/eco_actor.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")
const SkeletonRig = preload("res://scripts/species_skeleton_rig.gd")
const SkillVFX = preload("res://scripts/skill_vfx.gd")
const FOREST_GROUND_TEXTURE = preload("res://assets/textures/terrain/forest_floor_ai.jpg")
const TREE_A = preload("res://assets/models_v2/biomes/forest/ancient_tree_1.glb")
const TREE_B = preload("res://assets/models_v2/biomes/forest/ancient_tree_2.glb")


class ShowcaseGame:
	extends Node
	var batch_mode: bool = false
	var player: EcoActor
	var world: Node
	var world_seed: int = 20260815

	func get_quality_preset() -> String:
		return "high"


func _initialize() -> void:
	_build_showcase.call_deferred()


func _build_showcase() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var game_stub := ShowcaseGame.new()
	scene.add_child(game_stub)
	_build_environment(scene)

	for tree_data in [
		{"scene": TREE_A, "position": Vector3(-6.3, 0.0, 3.0), "scale": 1.05, "rotation": 0.34},
		{"scene": TREE_B, "position": Vector3(6.4, 0.0, 4.1), "scale": 0.92, "rotation": -0.46},
		{"scene": TREE_A, "position": Vector3(0.4, 0.0, 7.6), "scale": 1.18, "rotation": 1.12},
	]:
		var tree := (tree_data["scene"] as PackedScene).instantiate() as Node3D
		tree.position = tree_data["position"]
		tree.scale = Vector3.ONE * float(tree_data["scale"])
		tree.rotation.y = float(tree_data["rotation"])
		scene.add_child(tree)

	var rabbit: EcoActor = ActorScript.new()
	rabbit.process_mode = Node.PROCESS_MODE_DISABLED
	scene.add_child(rabbit)
	rabbit.setup(game_stub, 451, "rabbit", true, Vector3(-2.55, 0.0, -0.15), 0)
	rabbit.rotation.y = -0.52
	_hide_actor_ui(rabbit)
	SkeletonRig.apply_pose(rabbit.external_skeleton, "skill", 1.25, 0.82, 1.0, 0.72, 0.0, 0.4, 1.0, "rabbit")
	rabbit.external_skeleton.force_update_all_bone_transforms()
	SkillVFX.moonstep(scene, rabbit.global_position + Vector3.UP * 0.24, Vector3(-0.38, 0.0, -1.0), Color("#b9f4e8"))

	var wolf: EcoActor = ActorScript.new()
	wolf.process_mode = Node.PROCESS_MODE_DISABLED
	scene.add_child(wolf)
	wolf.setup(game_stub, 452, "wolf", true, Vector3(2.35, 0.0, 0.30), 0)
	wolf.rotation.y = -0.36
	_hide_actor_ui(wolf)
	SkeletonRig.apply_pose(wolf.external_skeleton, "attack", 1.38, 0.74, 1.0, 0.62, 0.0, 1.1, 1.0, "wolf")
	wolf.external_skeleton.force_update_all_bone_transforms()
	SkillVFX.pack_pounce(scene, wolf.global_position + Vector3(0.0, 0.0, 1.25), wolf.global_position + Vector3(0.0, 0.0, -0.55), Vector3(0.25, 0.0, -1.0), Color("#a9d8ed"))

	_add_label(scene, "V2 竖向切片  ·  雪兔月影折跃  ·  灰狼群猎扑杀", Vector3(0.0, 4.95, -0.20), 43)
	_add_label(scene, "Blender 连续体块  ·  两段腿骨  ·  Hero PBR  ·  古木林地套件", Vector3(0.0, 4.36, -0.20), 27)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 39.0
	camera.position = Vector3(5.4, 5.8, -13.4)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.55, 0.55), Vector3.UP)
	camera.current = true

	for _frame in range(7):
		await process_frame
	var output_path := "res://docs/images/v46-realistic-vertical-slice.png"
	var image := root.get_texture().get_image()
	var result := image.save_png(output_path)
	if result == OK:
		print("REALISTIC_VERTICAL_SLICE_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存 V2 竖向切片验收图：%s" % result)
		quit(1)


func _build_environment(scene: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#1e3945")
	sky_material.sky_horizon_color = Color("#c0b98f")
	sky_material.ground_horizon_color = Color("#314b39")
	sky_material.ground_bottom_color = Color("#0c1713")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.92
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.02
	environment.adjustment_contrast = 1.10
	environment.adjustment_saturation = 1.04
	environment_node.environment = environment
	scene.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47.0, -30.0, 0.0)
	sun.light_color = Color("#ffdfa3")
	sun.light_energy = 1.20
	# Keep this acceptance render readable on the macOS Compatibility path;
	# gameplay still follows the selected quality preset's shadow settings.
	sun.shadow_enabled = false
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#8dcbd7")
	fill.light_energy = 0.72
	fill.rotation_degrees = Vector3(55.0, 151.0, 0.0)
	scene.add_child(fill)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(28.0, 22.0)
	ground.mesh = plane
	ground.material_override = Factory.terrain_material(Color("#29452f"), Color("#50663f"), 12.0, FOREST_GROUND_TEXTURE, 5.2, 0.26)
	scene.add_child(ground)
	for rock_index in range(6):
		var angle := TAU * float(rock_index) / 6.0 + 0.22
		var rock := Factory.sphere("MossRock", Color("#59675b"), Vector3(0.68, 0.38, 0.54), Vector3(cos(angle) * 4.7, 0.25, sin(angle) * 2.8 + 1.5), 9, 5)
		rock.rotation.y = angle
		scene.add_child(rock)


func _hide_actor_ui(actor: EcoActor) -> void:
	actor.health_bar_root.visible = false
	if actor.selection_ring != null:
		actor.selection_ring.visible = false
	var player_arrow := actor.get_node_or_null("PlayerArrow") as Node3D
	if player_arrow != null:
		player_arrow.visible = false
	var player_label := actor.get_node_or_null("PlayerLabel") as Label3D
	if player_label != null:
		player_label.visible = false


func _add_label(scene: Node3D, label_text: String, label_position: Vector3, font_size: int) -> void:
	var label := Label3D.new()
	label.text = label_text
	label.font = load("res://assets/fonts/NotoSansSC-VF.ttf") as Font
	label.font_size = font_size
	label.outline_size = 9
	label.modulate = Color("#f4efd7")
	label.outline_modulate = Color(0.01, 0.035, 0.025, 0.96)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0105
	label.position = label_position
	scene.add_child(label)
