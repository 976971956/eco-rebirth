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
		{"id": "fox", "label": "赤狐 · 林缘侧猎", "sub": "蓬尾 / 胸绒 / 胡须", "position": Vector3(4.2, 0.0, 0.0), "scale": 0.94},
		{"id": "snake", "label": "青环蛇 · 冷伏毒击", "sub": "连续体型 / 背斑 / 毒牙", "position": Vector3(0.0, 0.0, 0.0), "scale": 1.06},
		{"id": "boar", "label": "獠牙野猪 · 硬皮突阵", "sub": "肩峰 / 鬃毛 / 双獠牙", "position": Vector3(-4.2, 0.0, 0.0), "scale": 0.82},
	]
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var actor: EcoActor = ActorScript.new()
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		scene.add_child(actor)
		actor.setup(game_stub, index + 1, str(entry["id"]), true, Vector3.ZERO, 0)
		actor.position = entry["position"]
		actor.scale = Vector3.ONE * float(entry["scale"])
		actor.rotation.y = 0.58
		_hide_actor_ui(actor)
		_add_label(scene, str(entry["label"]), actor.position + Vector3(0.0, 2.85 if str(entry["id"]) != "snake" else 1.65, 0.0), 34)
		_add_label(scene, str(entry["sub"]), actor.position + Vector3(0.0, 2.36 if str(entry["id"]) != "snake" else 1.22, 0.0), 25, Color("#d8e8c1"))
	_add_label(scene, "第二批外部物种 GLB · Hero 玩家 / Mobile AI / 程序模型回退", Vector3(0.0, 4.15, 2.2), 38)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.2
	camera.position = Vector3(0.0, 10.8, -20.5)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.25, 0.0), Vector3.UP)
	camera.current = true
	for _frame in range(18):
		await process_frame
	var output_path := "res://docs/images/v39-first-expansion-glb.png"
	var image := root.get_texture().get_image()
	var result := image.save_png(output_path)
	if result == OK:
		print("EXPANSION_GLB_SHOWCASE_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存第二批 GLB 验收图：%s" % result)
		quit(1)


func _build_environment(scene: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#274f5d")
	sky_material.sky_horizon_color = Color("#b7c397")
	sky_material.ground_horizon_color = Color("#425b42")
	sky_material.ground_bottom_color = Color("#10231b")
	sky_material.sun_angle_max = 3.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.66
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.02
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.04
	environment_node.environment = environment
	scene.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	sun.light_color = Color("#ffe1ae")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#b4d8e2")
	fill.light_energy = 0.46
	fill.rotation_degrees = Vector3(55.0, 145.0, 0.0)
	scene.add_child(fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(28.0, 19.0)
	ground.mesh = plane
	ground.material_override = Factory.terrain_material(Color("#314c36"), Color("#60774a"), 12.0, FOREST_GROUND_TEXTURE, 6.0, 0.24)
	scene.add_child(ground)


func _hide_actor_ui(actor: EcoActor) -> void:
	actor.health_bar_root.visible = false
	if actor.selection_ring != null:
		actor.selection_ring.visible = false
	for node_name in ["PlayerArrow", "PlayerLabel"]:
		var node := actor.get_node_or_null(node_name) as Node3D
		if node != null:
			node.visible = false


func _add_label(scene: Node3D, label_text: String, label_position: Vector3, font_size: int, tint: Color = Color("#f7f1d8")) -> void:
	var label := Label3D.new()
	label.text = label_text
	label.font = load("res://assets/fonts/NotoSansSC-VF.ttf") as Font
	label.font_size = font_size
	label.outline_size = 8
	label.modulate = tint
	label.outline_modulate = Color(0.02, 0.05, 0.025, 0.96)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0105
	label.position = label_position
	scene.add_child(label)
