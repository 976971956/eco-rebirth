extends SceneTree

const ActorScript = preload("res://scripts/eco_actor.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")
const FOREST_GROUND_TEXTURE = preload("res://assets/textures/terrain/forest_floor_ai.jpg")


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
	var entries := [
		{"id": "rabbit", "label": "雪兔 · 细短绒", "position": Vector3(4.5, 0.0, 0.0), "scale": 0.90},
		{"id": "wolf", "label": "灰狼 · 中粗毛", "position": Vector3(1.5, 0.0, 0.0), "scale": 0.78},
		{"id": "deer", "label": "林鹿 · 暖短毛", "position": Vector3(-1.5, 0.0, 0.0), "scale": 0.74},
		{"id": "bear", "label": "棕熊 · 厚长毛", "position": Vector3(-4.5, 0.0, 0.0), "scale": 0.71},
	]
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var actor: EcoActor = ActorScript.new()
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		scene.add_child(actor)
		actor.setup(game_stub, index + 1, str(entry["id"]), true, Vector3.ZERO, 0)
		actor.position = entry["position"]
		actor.scale = Vector3.ONE * float(entry["scale"])
		actor.rotation.y = 0.68
		_hide_actor_ui(actor)
		_add_label(scene, str(entry["label"]), actor.position + Vector3(0.0, 3.0 if str(entry["id"]) == "deer" else 2.45, 0.0), 31)
	_add_label(scene, "四足动物 2×2 共享 PBR 图集 · 远景眼部/耳内/细节自动 LOD", Vector3(0.0, 4.35, 2.2), 38)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.9
	camera.position = Vector3(0.0, 10.8, -20.0)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.25, 0.0), Vector3.UP)
	camera.current = true
	for _frame in range(18):
		await process_frame
	var output_path := "res://docs/images/v38-material-atlas-lod.png"
	var image := root.get_texture().get_image()
	var result := image.save_png(output_path)
	if result == OK:
		print("MATERIAL_ATLAS_LOD_SHOWCASE_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存材质图集/LOD 验收图：%s" % result)
		quit(1)


func _build_environment(scene: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#365764")
	sky_material.sky_horizon_color = Color("#b9c29d")
	sky_material.ground_horizon_color = Color("#4a6248")
	sky_material.ground_bottom_color = Color("#14251d")
	sky_material.sun_angle_max = 3.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.03
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.04
	environment_node.environment = environment
	scene.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	sun.light_color = Color("#ffe5b5")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#b7dbe3")
	fill.light_energy = 0.44
	fill.rotation_degrees = Vector3(55.0, 145.0, 0.0)
	scene.add_child(fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 20.0)
	ground.mesh = plane
	ground.material_override = Factory.terrain_material(Color("#34503a"), Color("#60774a"), 12.0, FOREST_GROUND_TEXTURE, 6.0, 0.24)
	scene.add_child(ground)


func _hide_actor_ui(actor: EcoActor) -> void:
	actor.health_bar_root.visible = false
	if actor.selection_ring != null:
		actor.selection_ring.visible = false
	for node_name in ["PlayerArrow", "PlayerLabel"]:
		var node := actor.get_node_or_null(node_name) as Node3D
		if node != null:
			node.visible = false


func _add_label(scene: Node3D, label_text: String, label_position: Vector3, font_size: int) -> void:
	var label := Label3D.new()
	label.text = label_text
	label.font = load("res://assets/fonts/NotoSansSC-VF.ttf") as Font
	label.font_size = font_size
	label.outline_size = 8
	label.modulate = Color("#f7f1d8")
	label.outline_modulate = Color(0.02, 0.05, 0.025, 0.96)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0105
	label.position = label_position
	scene.add_child(label)
