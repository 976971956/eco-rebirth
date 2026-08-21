extends SceneTree

const Factory = preload("res://scripts/low_poly_factory.gd")
const WorldScript = preload("res://scripts/eco_world.gd")
const UIFont = preload("res://assets/fonts/NotoSansSC-VF.ttf")


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#18251f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c7d5bd")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	scene.add_child(environment_node)

	var ground := Factory.box("PreviewGround", Color("#34432f"), Vector3(15.2, 0.18, 6.2), Vector3(0.0, -0.10, 0.0))
	ground.material_override = Factory.material(Color("#34432f"), 0.96)
	scene.add_child(ground)
	var region_ids: Array[String] = ["forest", "grassland", "wetland", "highland"]
	var region_names: Array[String] = ["古木林地", "日照草原", "浅水湿地", "岩丘高地"]
	var plot_colors: Array[Color] = [Color("#2c3b2d"), Color("#4a4d2c"), Color("#29433c"), Color("#4b4937")]
	for region_index in range(region_ids.size()):
		var x := (float(region_index) - 1.5) * 3.55
		var plot := Factory.box("RegionPlot_%d" % region_index, plot_colors[region_index], Vector3(3.40, 0.035, 5.7), Vector3(x, 0.015, 0.0))
		plot.material_override = Factory.material(plot_colors[region_index], 0.98)
		scene.add_child(plot)
		var profile := WorldScript.tactical_cover_profile(region_ids[region_index])
		var tuft := Factory.grass_tuft(
			"%sNaturalCover" % region_ids[region_index].capitalize(),
			Color(str(profile["base"])),
			Color(str(profile["tip"])),
			float(profile["radius"]),
			float(profile["height"]),
			28,
			20260823 + region_index * 97,
			float(profile["broadness"]),
			float(profile["uprightness"])
		)
		tuft.position = Vector3(x, 0.0, -0.08)
		tuft.rotation.y = float(region_index) * 0.57
		scene.add_child(tuft)
		var back_tuft := Factory.grass_tuft(
			"%sBackgroundCover" % region_ids[region_index].capitalize(),
			Color(str(profile["base"])).darkened(0.06),
			Color(str(profile["tip"])).darkened(0.04),
			float(profile["radius"]),
			float(profile["height"]),
			18,
			20260911 + region_index * 131,
			float(profile["broadness"]),
			float(profile["uprightness"])
		)
		back_tuft.position = Vector3(x + 0.58, 0.0, -1.05)
		back_tuft.scale = Vector3.ONE * 0.72
		back_tuft.rotation.y = 1.20 + float(region_index) * 0.31
		scene.add_child(back_tuft)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#fff0cf")
	sun.light_energy = 1.38
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.shadow_enabled = true
	scene.add_child(sun)
	var fill := OmniLight3D.new()
	fill.light_color = Color("#b7d8c2")
	fill.light_energy = 1.0
	fill.omni_range = 18.0
	fill.position = Vector3(-1.0, 5.6, 4.0)
	scene.add_child(fill)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 43.0
	camera.near = 0.1
	camera.far = 60.0
	camera.position = Vector3(0.0, 4.8, 10.8)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 0.72, -0.15), Vector3.UP)
	camera.current = true

	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var title := Label.new()
	title.text = "自然战术草丛 · 四生态区差异"
	title.position = Vector2(0.0, 26.0)
	title.size = Vector2(1280.0, 58.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UIFont)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#eef4df"))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.86))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	canvas.add_child(title)
	for region_index in range(region_names.size()):
		var label := Label.new()
		label.text = region_names[region_index]
		label.position = Vector2(float(region_index) * 320.0, 583.0)
		label.size = Vector2(320.0, 44.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", UIFont)
		label.add_theme_font_size_override("font_size", 23)
		label.add_theme_color_override("font_color", Color("#e8efd9"))
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		canvas.add_child(label)
	var subtitle := Label.new()
	subtitle.text = "弯曲草叶 · 中心高边缘低 · 轻风摆动 · 无碰撞 · 每丛 72–112 三角面"
	subtitle.position = Vector2(0.0, 640.0)
	subtitle.size = Vector2(1280.0, 42.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", UIFont)
	subtitle.add_theme_font_size_override("font_size", 21)
	subtitle.add_theme_color_override("font_color", Color("#cbd9c2"))
	subtitle.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	subtitle.add_theme_constant_override("shadow_offset_x", 2)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(subtitle)

	for _frame in range(48):
		await process_frame
	var output_path := "res://docs/images/v92-natural-tactical-grass.png"
	var result := root.get_texture().get_image().save_png(output_path)
	if result == OK:
		print("TACTICAL_GRASS_PREVIEW_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存自然战术草丛验收图：%s" % result)
		quit(1)
