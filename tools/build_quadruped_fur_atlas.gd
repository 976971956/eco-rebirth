extends SceneTree

const SOURCE_ALBEDO := "res://assets/textures/animals/shared/fur_micro_albedo_ai.png"
const SOURCE_NORMAL := "res://assets/textures/animals/shared/fur_micro_normal_ai.png"
const SOURCE_ROUGHNESS := "res://assets/textures/animals/shared/fur_micro_roughness_ai.png"
const OUTPUT_ROOT := "res://assets/textures/animals/shared/quadruped_fur_atlas"
const ATLAS_SIZE := 256
const REGION_SIZE := 128

const REGIONS := [
	{"id": "rabbit", "sample_scale": 1.42, "albedo": 1.035, "roughness": 1.025},
	{"id": "wolf", "sample_scale": 1.08, "albedo": 0.965, "roughness": 0.985},
	{"id": "deer", "sample_scale": 0.86, "albedo": 1.005, "roughness": 0.955},
	{"id": "bear", "sample_scale": 0.68, "albedo": 0.925, "roughness": 1.035},
]


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var sources := [_load_image(SOURCE_ALBEDO), _load_image(SOURCE_NORMAL), _load_image(SOURCE_ROUGHNESS)]
	if sources.any(func(image: Image): return image == null):
		quit(1)
		return
	var outputs := [
		Image.create(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8),
		Image.create(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8),
		Image.create(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8),
	]
	for region_index in range(REGIONS.size()):
		var region: Dictionary = REGIONS[region_index]
		var origin := Vector2i((region_index % 2) * REGION_SIZE, (region_index / 2) * REGION_SIZE)
		for y in range(REGION_SIZE):
			for x in range(REGION_SIZE):
				var source_x := posmod(int(float(x) * float(region["sample_scale"])), sources[0].get_width())
				var source_y := posmod(int(float(y) * float(region["sample_scale"])), sources[0].get_height())
				var albedo: Color = sources[0].get_pixel(source_x, source_y)
				var normal: Color = sources[1].get_pixel(source_x, source_y)
				var roughness: Color = sources[2].get_pixel(source_x, source_y)
				var variation := 0.985 + sin(float(x * 7 + y * 3 + region_index * 19) * 0.071) * 0.015
				albedo = Color(
					clampf(albedo.r * float(region["albedo"]) * variation, 0.0, 1.0),
					clampf(albedo.g * float(region["albedo"]) * variation, 0.0, 1.0),
					clampf(albedo.b * float(region["albedo"]) * variation, 0.0, 1.0),
					1.0
				)
				var roughness_value := clampf(roughness.r * float(region["roughness"]), 0.72, 0.99)
				outputs[0].set_pixel(origin.x + x, origin.y + y, albedo)
				outputs[1].set_pixel(origin.x + x, origin.y + y, normal)
				outputs[2].set_pixel(origin.x + x, origin.y + y, Color(roughness_value, roughness_value, roughness_value, 1.0))
	var suffixes := ["_albedo.png", "_normal.png", "_roughness.png"]
	for index in range(outputs.size()):
		var output_path: String = OUTPUT_ROOT + suffixes[index]
		var save_error: Error = outputs[index].save_png(ProjectSettings.globalize_path(output_path))
		if save_error != OK:
			push_error("无法保存四足动物材质图集：%s" % error_string(save_error))
			quit(1)
			return
	print("QUADRUPED_FUR_ATLAS_OK: 256x256 / four 128x128 regions")
	quit(0)


func _load_image(path: String) -> Image:
	var image := Image.new()
	var load_error := image.load(ProjectSettings.globalize_path(path))
	if load_error != OK:
		push_error("无法读取毛发源贴图 %s：%s" % [path, error_string(load_error)])
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image
