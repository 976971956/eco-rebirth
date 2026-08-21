extends SceneTree

const ExperiencePackScript = preload("res://scripts/experience_pack.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")
const UIFont = preload("res://assets/fonts/NotoSansSC-VF.ttf")


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#13242b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b8d9d0")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	scene.add_child(environment_node)

	var ground := Factory.box("PreviewGround", Color("#263b35"), Vector3(12.0, 0.18, 6.4), Vector3(0.0, -0.10, 0.2))
	ground.material_override = Factory.material(Color("#263b35"), 0.88)
	scene.add_child(ground)
	for line_index in range(3):
		var line := Factory.box("PreviewLane_%d" % line_index, Color("#35534a"), Vector3(0.035, 0.015, 5.8), Vector3(-1.5 + float(line_index) * 1.5, 0.01, 0.2))
		line.material_override = Factory.material(Color("#35534a"), 0.92)
		scene.add_child(line)

	var pack_specs := [
		{"tier": ExperiencePackScript.TIER_COMMON, "amount": 15, "position": Vector3(-3.1, 0.0, 0.0)},
		{"tier": ExperiencePackScript.TIER_RICH, "amount": 42, "position": Vector3(0.0, 0.0, 0.0)},
		{"tier": ExperiencePackScript.TIER_LEVEL, "amount": 0, "position": Vector3(3.1, 0.0, 0.0)},
	]
	for index in range(pack_specs.size()):
		var spec: Dictionary = pack_specs[index]
		var pack := ExperiencePackScript.new()
		pack.position = spec["position"]
		pack.setup(str(spec["tier"]), int(spec["amount"]), 1, index, true, float(index) * 1.7)
		scene.add_child(pack)

	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color("#fff0cd")
	key_light.light_energy = 1.55
	key_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key_light.shadow_enabled = true
	scene.add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.light_color = Color("#78cfe1")
	fill_light.light_energy = 1.25
	fill_light.omni_range = 12.0
	fill_light.position = Vector3(0.0, 5.0, 2.2)
	scene.add_child(fill_light)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 42.0
	camera.near = 0.1
	camera.far = 60.0
	camera.position = Vector3(0.0, 4.5, 9.2)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.current = true

	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var title := Label.new()
	title.text = "全图进化能量雨 · 原创 3D 经验核心"
	title.position = Vector2(0.0, 30.0)
	title.size = Vector2(1280.0, 60.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UIFont)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#edf8ed"))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	canvas.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "普通经验包　　丰厚经验包　　跃迁经验包　　　每60秒按关卡投放 10 / 20 / … / 100 个"
	subtitle.position = Vector2(0.0, 635.0)
	subtitle.size = Vector2(1280.0, 48.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", UIFont)
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color("#d6e8df"))
	subtitle.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	subtitle.add_theme_constant_override("shadow_offset_x", 2)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(subtitle)

	for _frame in range(48):
		await process_frame
	var output_path := "res://docs/images/v91-experience-pack-3d-rain.png"
	var result := root.get_texture().get_image().save_png(output_path)
	if result == OK:
		print("EXPERIENCE_PACK_PREVIEW_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存经验包3D验收图：%s" % result)
		quit(1)
