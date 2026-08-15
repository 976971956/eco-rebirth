extends SceneTree

const ALBEDO_PATH := "res://assets/textures/animals/shared/fur_micro_albedo_ai.png"
const NORMAL_PATH := "res://assets/textures/animals/shared/fur_micro_normal_ai.png"
const ROUGHNESS_PATH := "res://assets/textures/animals/shared/fur_micro_roughness_ai.png"
const TEXTURE_SIZE := 256
const SEAM_BLEND_WIDTH := 28


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var source := Image.new()
	var load_error := source.load(ProjectSettings.globalize_path(ALBEDO_PATH))
	if load_error != OK:
		push_error("无法加载 AI 毛发源纹理：%s" % error_string(load_error))
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)
	source.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
	var height_map := _build_seamless_height(source)
	var albedo := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var normal := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var roughness := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var height := height_map[y * TEXTURE_SIZE + x]
			var detail := clampf(0.955 + (height - 0.5) * 0.10, 0.90, 1.0)
			albedo.set_pixel(x, y, Color(detail * 1.008, detail, detail * 0.985, 1.0))
			var left := height_map[y * TEXTURE_SIZE + posmod(x - 1, TEXTURE_SIZE)]
			var right := height_map[y * TEXTURE_SIZE + posmod(x + 1, TEXTURE_SIZE)]
			var up := height_map[posmod(y - 1, TEXTURE_SIZE) * TEXTURE_SIZE + x]
			var down := height_map[posmod(y + 1, TEXTURE_SIZE) * TEXTURE_SIZE + x]
			var normal_vector := Vector3((left - right) * 1.65, (up - down) * 1.65, 1.0).normalized()
			normal.set_pixel(x, y, Color(normal_vector.x * 0.5 + 0.5, normal_vector.y * 0.5 + 0.5, normal_vector.z * 0.5 + 0.5, 1.0))
			var roughness_value := clampf(0.88 + (0.5 - height) * 0.16, 0.78, 0.98)
			roughness.set_pixel(x, y, Color(roughness_value, roughness_value, roughness_value, 1.0))
	var errors := [
		albedo.save_png(ProjectSettings.globalize_path(ALBEDO_PATH)),
		normal.save_png(ProjectSettings.globalize_path(NORMAL_PATH)),
		roughness.save_png(ProjectSettings.globalize_path(ROUGHNESS_PATH)),
	]
	for error in errors:
		if error != OK:
			push_error("无法保存毛发 PBR 纹理：%s" % error_string(error))
			quit(1)
			return
	print("FUR_TEXTURE_MAPS_OK: 256x256 seamless albedo/normal/roughness")
	quit(0)


func _build_seamless_height(source: Image) -> PackedFloat32Array:
	var raw := PackedFloat32Array()
	raw.resize(TEXTURE_SIZE * TEXTURE_SIZE)
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			raw[y * TEXTURE_SIZE + x] = source.get_pixel(x, y).get_luminance()
	var horizontal := raw.duplicate()
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var edge_distance := mini(x, TEXTURE_SIZE - 1 - x)
			if edge_distance >= SEAM_BLEND_WIDTH:
				continue
			var opposite_x := TEXTURE_SIZE - 1 - x
			var edge_average := (raw[y * TEXTURE_SIZE + x] + raw[y * TEXTURE_SIZE + opposite_x]) * 0.5
			var blend := smoothstep(0.0, float(SEAM_BLEND_WIDTH), float(edge_distance))
			horizontal[y * TEXTURE_SIZE + x] = lerpf(edge_average, raw[y * TEXTURE_SIZE + x], blend)
	var seamless := horizontal.duplicate()
	for y in range(TEXTURE_SIZE):
		var edge_distance := mini(y, TEXTURE_SIZE - 1 - y)
		if edge_distance >= SEAM_BLEND_WIDTH:
			continue
		var opposite_y := TEXTURE_SIZE - 1 - y
		var blend := smoothstep(0.0, float(SEAM_BLEND_WIDTH), float(edge_distance))
		for x in range(TEXTURE_SIZE):
			var edge_average := (horizontal[y * TEXTURE_SIZE + x] + horizontal[opposite_y * TEXTURE_SIZE + x]) * 0.5
			seamless[y * TEXTURE_SIZE + x] = lerpf(edge_average, horizontal[y * TEXTURE_SIZE + x], blend)
	var minimum := seamless[0]
	var maximum := seamless[0]
	for value in seamless:
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
	var span := maxf(maximum - minimum, 0.001)
	for index in range(seamless.size()):
		seamless[index] = (seamless[index] - minimum) / span
	return seamless
