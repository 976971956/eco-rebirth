extends SceneTree

const ActorScript = preload("res://scripts/eco_actor.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")
const GRASS_TEXTURE = preload("res://assets/textures/terrain/grassland_ai.jpg")


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
		{"id": "lion", "title": "猫科", "sub": "雄狮 · 鬃毛与长尾", "position": Vector3(6.6, 0.0, 0.0), "scale": 0.82},
		{"id": "elephant", "title": "巨兽", "sub": "巨象 · 耳、长鼻与象牙", "position": Vector3(2.2, 0.0, 0.0), "scale": 0.60},
		{"id": "moose", "title": "有蹄类", "sub": "驼鹿 · 掌状角与垂皮", "position": Vector3(-2.4, 0.0, 0.0), "scale": 0.64},
		{"id": "gorilla", "title": "灵长类", "sub": "银背 · 长臂与拳步", "position": Vector3(-6.5, 0.0, 0.0), "scale": 0.74},
	]
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var actor: EcoActor = ActorScript.new()
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		scene.add_child(actor)
		actor.setup(game_stub, index + 1, str(entry["id"]), true, Vector3.ZERO, 0)
		actor.position = entry["position"]
		actor.scale = Vector3.ONE * float(entry["scale"])
		actor.rotation.y = 0.48
		_hide_actor_ui(actor)
		_add_label(scene, str(entry["title"]), actor.position + Vector3(0.0, 3.55, 0.0), 34)
		_add_label(scene, str(entry["sub"]), actor.position + Vector3(0.0, 3.08, 0.0), 23, Color("#d8e8c1"))
	_add_label(scene, "第三批外部动物 GLB · 11 种 / 22 份资源 / Hero + Mobile", Vector3(0.0, 4.65, 2.1), 38)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.0
	camera.position = Vector3(0.0, 11.8, -21.8)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.48, 0.0), Vector3.UP)
	camera.current = true
	for _frame in range(18):
		await process_frame
	var output_path := "res://docs/images/v42-third-expansion-glb.png"
	var image := root.get_texture().get_image()
	var result := image.save_png(output_path)
	if result == OK:
		print("THIRD_EXPANSION_GLB_SHOWCASE_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存第三批 GLB 验收图：%s" % result)
		quit(1)


func _build_environment(scene: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#355c68")
	sky_material.sky_horizon_color = Color("#d4c18a")
	sky_material.ground_horizon_color = Color("#66734d")
	sky_material.ground_bottom_color = Color("#1a281c")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.68
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.02
	environment.adjustment_contrast = 1.09
	environment.adjustment_saturation = 1.05
	environment_node.environment = environment
	scene.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	sun.light_color = Color("#ffe0ae")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#b8d9e2")
	fill.light_energy = 0.44
	fill.rotation_degrees = Vector3(55.0, 145.0, 0.0)
	scene.add_child(fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(34.0, 20.0)
	ground.mesh = plane
	ground.material_override = Factory.terrain_material(Color("#59623a"), Color("#8b8a50"), 12.0, GRASS_TEXTURE, 7.0, 0.22)
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
