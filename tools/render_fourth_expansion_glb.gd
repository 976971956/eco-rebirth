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
	_render_showcases.call_deferred()


func _render_showcases() -> void:
	var first_group := [
		{"id": "raccoon", "title": "浣熊", "sub": "黑眼罩 · 环纹长尾", "scale": 0.88},
		{"id": "porcupine", "title": "豪猪", "sub": "背部棘刺 · 伏地轮廓", "scale": 0.83},
		{"id": "capybara", "title": "水豚", "sub": "宽吻 · 厚实躯干", "scale": 0.80},
		{"id": "otter", "title": "水獭", "sub": "流线躯干 · 舵形尾", "scale": 0.86},
		{"id": "wolverine", "title": "狼獾", "sub": "侧身浅带 · 强壮前肢", "scale": 0.82},
	]
	var second_group := [
		{"id": "zebra", "title": "斑马", "sub": "全身条纹 · 立鬃", "scale": 0.67},
		{"id": "owl", "title": "雪鸮", "sub": "面盘 · 分层羽翼", "scale": 0.80},
		{"id": "turtle", "title": "陆龟", "sub": "甲片 · 低伏步态", "scale": 0.88},
		{"id": "cheetah", "title": "猎豹", "sub": "泪痕 · 斑点长尾", "scale": 0.75},
		{"id": "hyena", "title": "斑鬣狗", "sub": "高肩斜背 · 脊鬃", "scale": 0.76},
	]
	var first_ok := await _render_group(first_group, "第四批外部动物 GLB · 森林与湿地", "res://docs/images/v44-fourth-expansion-glb-a.png")
	var second_ok := await _render_group(second_group, "第四批外部动物 GLB · 草原与夜行组", "res://docs/images/v44-fourth-expansion-glb-b.png")
	if first_ok and second_ok:
		print("FOURTH_EXPANSION_GLB_SHOWCASE_OK: 10 species / 2 screenshots")
		quit(0)
	else:
		push_error("无法保存第四批 GLB 验收图")
		quit(1)


func _render_group(entries: Array, heading: String, output_path: String) -> bool:
	var scene := Node3D.new()
	root.add_child(scene)
	var game_stub := ShowcaseGame.new()
	scene.add_child(game_stub)
	_build_environment(scene)
	var x_positions := [7.2, 3.6, 0.0, -3.6, -7.2]
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var actor: EcoActor = ActorScript.new()
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		scene.add_child(actor)
		actor.setup(game_stub, index + 1, str(entry["id"]), true, Vector3.ZERO, 0)
		actor.position = Vector3(float(x_positions[index]), 0.0, 0.0)
		actor.scale = Vector3.ONE * float(entry["scale"])
		actor.rotation.y = 0.42
		_hide_actor_ui(actor)
		_add_label(scene, str(entry["title"]), actor.position + Vector3(0.0, 3.30, 0.0), 30)
		_add_label(scene, str(entry["sub"]), actor.position + Vector3(0.0, 2.89, 0.0), 19, Color("#d8e8c1"))
	_add_label(scene, heading, Vector3(0.0, 4.62, 2.0), 38)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.2
	camera.position = Vector3(0.0, 11.8, -22.2)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.45, 0.0), Vector3.UP)
	camera.current = true
	for _frame in range(18):
		await process_frame
	var image := root.get_texture().get_image()
	var result := image.save_png(output_path)
	scene.queue_free()
	for _frame in range(3):
		await process_frame
	return result == OK


func _build_environment(scene: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#284e5b")
	sky_material.sky_horizon_color = Color("#d9bd7d")
	sky_material.ground_horizon_color = Color("#66734d")
	sky_material.ground_bottom_color = Color("#17251b")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.04
	environment.adjustment_contrast = 1.10
	environment.adjustment_saturation = 1.06
	environment_node.environment = environment
	scene.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	sun.light_color = Color("#ffe0ae")
	sun.light_energy = 1.08
	sun.shadow_enabled = true
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#b8d9e2")
	fill.light_energy = 0.48
	fill.rotation_degrees = Vector3(55.0, 145.0, 0.0)
	scene.add_child(fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(36.0, 20.0)
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
