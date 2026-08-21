extends SceneTree

const FoodPatchScript = preload("res://scripts/food_patch.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")
const UIFont = preload("res://assets/fonts/NotoSansSC-VF.ttf")

const FOOD_KINDS: Array[String] = ["grass", "berries", "mushroom", "fruit", "roots", "fish"]
const FOOD_LABELS: Array[String] = ["嫩草", "野莓", "林地蘑菇", "落果", "块根", "活鱼群"]
const PLOT_COLORS: Array[Color] = [
	Color("#344329"), Color("#2e3d2e"), Color("#3e382d"),
	Color("#4a422d"), Color("#493a2d"), Color("#244345"),
]


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var compact_preview := "--compact-preview" in OS.get_cmdline_user_args()
	var scene := Node3D.new()
	root.add_child(scene)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#17231d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c2d2bd")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	scene.add_child(environment_node)

	var ground := Factory.box("PreviewGround", Color("#28352a"), Vector3(15.4, 0.18, 7.1), Vector3(0.0, -0.12, 0.0))
	ground.material_override = Factory.material(Color("#28352a"), 0.97)
	scene.add_child(ground)
	for index in range(FOOD_KINDS.size()):
		var column := index % 3
		var row := index / 3
		var position_value := Vector3((float(column) - 1.0) * 4.65, 0.0, (float(row) - 0.5) * 3.15)
		var plot := Factory.box("FoodPlot_%02d" % index, PLOT_COLORS[index], Vector3(4.2, 0.045, 2.75), position_value + Vector3(0.0, 0.012, 0.0))
		plot.material_override = Factory.material(PLOT_COLORS[index], 0.98)
		scene.add_child(plot)
		if FOOD_KINDS[index] == "fish":
			var water := Factory.box("FishShallowWater", Color("#315b5d"), Vector3(4.05, 0.025, 2.60), position_value + Vector3(0.0, 0.075, 0.0))
			water.material_override = Factory.water_material(Color("#5b8c82"), Color("#244d58"), 0.55, 0.24)
			water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			scene.add_child(water)
		var rng := RandomNumberGenerator.new()
		rng.seed = 20260824 + index * 1009
		var patch := FoodPatchScript.new()
		patch.position = position_value
		patch.setup(FOOD_KINDS[index], rng, "common", index, compact_preview)
		scene.add_child(patch)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#fff0d2")
	sun.light_energy = 1.42
	sun.rotation_degrees = Vector3(-51.0, -31.0, 0.0)
	sun.shadow_enabled = true
	scene.add_child(sun)
	var fill := OmniLight3D.new()
	fill.light_color = Color("#a8d0b3")
	fill.light_energy = 1.05
	fill.omni_range = 18.0
	fill.position = Vector3(-2.0, 6.3, 4.8)
	scene.add_child(fill)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 43.0
	camera.near = 0.1
	camera.far = 60.0
	camera.position = Vector3(0.0, 6.15, 9.25)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 0.45, 0.0), Vector3.UP)
	camera.current = true

	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var title := Label.new()
	title.text = "自然野外食物套装 · %s" % ("普通地图紧凑档" if compact_preview else "六类生态资源重制")
	title.position = Vector2(0.0, 20.0)
	title.size = Vector2(1280.0, 58.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UIFont)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#eef4df"))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.86))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	canvas.add_child(title)
	for index in range(FOOD_LABELS.size()):
		var column := index % 3
		var row := index / 3
		var label := Label.new()
		label.text = FOOD_LABELS[index]
		label.position = Vector2(float(column) * 426.0, 321.0 + float(row) * 280.0)
		label.size = Vector2(426.0, 42.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", UIFont)
		label.add_theme_font_size_override("font_size", 23)
		label.add_theme_color_override("font_color", Color("#edf0dc"))
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.90))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		canvas.add_child(label)
	var subtitle := Label.new()
	subtitle.text = "程序化连续果体 · 枝叶与浆果簇 · 菌褶伞盖 · 根冠与土痕 · 完整鱼体和鱼鳍"
	subtitle.position = Vector2(0.0, 665.0)
	subtitle.size = Vector2(1280.0, 38.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", UIFont)
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color("#cbd8c5"))
	subtitle.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.86))
	subtitle.add_theme_constant_override("shadow_offset_x", 2)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(subtitle)

	for _frame in range(48):
		await process_frame
	var output_path := "/tmp/eco-food-compact-preview.png" if compact_preview else "res://docs/images/v93-natural-wild-foods.png"
	var result := root.get_texture().get_image().save_png(output_path)
	if result == OK:
		print("WILD_FOOD_PREVIEW_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存自然野外食物验收图：%s" % result)
		quit(1)
