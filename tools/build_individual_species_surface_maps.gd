extends SceneTree

const TEXTURE_SIZE := 512
const MOBILE_TEXTURE_SIZE := 128
const SOURCE_ROOT := "assets/source/animals/material_reference_ai"
const OUTPUT_ROOT := "assets/textures/animals"
const GROUPS := [
	{
		"sheet": "small_mammals.png",
		"species": ["rabbit", "fox", "raccoon", "porcupine", "capybara"],
	},
	{
		"sheet": "predators.png",
		"species": ["wolf", "lion", "tiger", "cheetah", "lynx"],
	},
	{
		"sheet": "ungulates.png",
		"species": ["deer", "bison", "zebra", "moose", "goat"],
	},
	{
		"sheet": "coarse_mammals.png",
		"species": ["bear", "boar", "otter", "wolverine", "hyena"],
	},
	{
		"sheet": "primates_and_hide.png",
		"species": ["monkey", "gorilla", "elephant", "rhino", "hippo"],
	},
	{
		"sheet": "feather_scale_shell.png",
		"species": ["owl", "eagle", "snake", "crocodile", "turtle"],
	},
]
const SURFACE_PROFILES := {
	"rabbit": {"roughness": 0.90, "relief": 2.8},
	"fox": {"roughness": 0.82, "relief": 3.2},
	"raccoon": {"roughness": 0.86, "relief": 3.0},
	"porcupine": {"roughness": 0.72, "relief": 4.8},
	"capybara": {"roughness": 0.74, "relief": 3.4},
	"wolf": {"roughness": 0.83, "relief": 3.4},
	"lion": {"roughness": 0.82, "relief": 3.1},
	"tiger": {"roughness": 0.80, "relief": 3.0},
	"cheetah": {"roughness": 0.78, "relief": 2.5},
	"lynx": {"roughness": 0.88, "relief": 3.4},
	"deer": {"roughness": 0.84, "relief": 2.5},
	"bison": {"roughness": 0.91, "relief": 4.2},
	"zebra": {"roughness": 0.80, "relief": 2.4},
	"moose": {"roughness": 0.88, "relief": 3.2},
	"goat": {"roughness": 0.88, "relief": 3.3},
	"bear": {"roughness": 0.90, "relief": 4.0},
	"boar": {"roughness": 0.83, "relief": 4.4},
	"otter": {"roughness": 0.66, "relief": 2.3},
	"wolverine": {"roughness": 0.88, "relief": 3.8},
	"hyena": {"roughness": 0.82, "relief": 3.1},
	"monkey": {"roughness": 0.82, "relief": 2.7},
	"gorilla": {"roughness": 0.87, "relief": 3.5},
	"elephant": {"roughness": 0.92, "relief": 4.8},
	"rhino": {"roughness": 0.94, "relief": 5.0},
	"hippo": {"roughness": 0.62, "relief": 2.8},
	"owl": {"roughness": 0.90, "relief": 2.4},
	"eagle": {"roughness": 0.84, "relief": 2.8},
	"snake": {"roughness": 0.58, "relief": 4.2},
	"crocodile": {"roughness": 0.76, "relief": 5.2},
	"turtle": {"roughness": 0.88, "relief": 4.7},
}


func _initialize() -> void:
	call_deferred("_build")


func _build() -> void:
	var built_species: Array[String] = []
	for group in GROUPS:
		var source_path := ProjectSettings.globalize_path("res://%s/%s" % [SOURCE_ROOT, group["sheet"]])
		var source := Image.new()
		var load_result := source.load(source_path)
		if load_result != OK:
			push_error("无法加载 AI 物种表面方向板：%s" % source_path)
			quit(1)
			return
		var swatches := _detect_swatches(source)
		if swatches.size() != 5:
			push_error("%s 只识别出 %d/5 个材质区" % [group["sheet"], swatches.size()])
			quit(1)
			return
		var species_group: Array = group["species"]
		for index in range(species_group.size()):
			var species_id: String = species_group[index]
			var albedo := source.get_region(swatches[index])
			albedo.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
			_normalize_albedo(albedo)
			var normal := _build_normal(albedo, float(SURFACE_PROFILES[species_id]["relief"]))
			var roughness := _build_roughness(albedo, float(SURFACE_PROFILES[species_id]["roughness"]))
			var mobile_albedo := albedo.duplicate()
			var mobile_normal := normal.duplicate()
			var mobile_roughness := roughness.duplicate()
			mobile_albedo.resize(MOBILE_TEXTURE_SIZE, MOBILE_TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
			mobile_normal.resize(MOBILE_TEXTURE_SIZE, MOBILE_TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
			mobile_roughness.resize(MOBILE_TEXTURE_SIZE, MOBILE_TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
			var output_dir := ProjectSettings.globalize_path("res://%s/%s" % [OUTPUT_ROOT, species_id])
			DirAccess.make_dir_recursive_absolute(output_dir)
			var results := [
				albedo.save_png(output_dir.path_join("%s_surface_albedo.png" % species_id)),
				normal.save_png(output_dir.path_join("%s_surface_normal.png" % species_id)),
				roughness.save_png(output_dir.path_join("%s_surface_roughness.png" % species_id)),
				mobile_albedo.save_png(output_dir.path_join("%s_surface_mobile_albedo.png" % species_id)),
				mobile_normal.save_png(output_dir.path_join("%s_surface_mobile_normal.png" % species_id)),
				mobile_roughness.save_png(output_dir.path_join("%s_surface_mobile_roughness.png" % species_id)),
			]
			if results.any(func(result: int): return result != OK):
				push_error("无法保存 %s 的独立 PBR 图集：%s" % [species_id, results])
				quit(1)
				return
			built_species.append(species_id)
	if built_species.size() != 30:
		push_error("独立表面图集只生成了 %d/30 种" % built_species.size())
		quit(1)
		return
	print("INDIVIDUAL_SPECIES_SURFACES_OK: 30 species / 180 maps / Hero %dx%d + Mobile %dx%d" % [TEXTURE_SIZE, TEXTURE_SIZE, MOBILE_TEXTURE_SIZE, MOBILE_TEXTURE_SIZE])
	quit(0)


func _detect_swatches(source: Image) -> Array[Rect2i]:
	var width := source.get_width()
	var height := source.get_height()
	var background := _background_color(source)
	var center_y := height / 2
	var active := PackedByteArray()
	active.resize(width)
	for x in range(width):
		var matches := 0
		for y_offset in [-8, -4, 0, 4, 8]:
			var color := source.get_pixel(x, clampi(center_y + y_offset, 0, height - 1))
			if _color_distance(color, background) > 0.075:
				matches += 1
		active[x] = 1 if matches >= 3 else 0
	_close_short_gaps(active, maxi(5, width / 260))
	var runs := _active_runs(active, maxi(48, width / 18))
	if runs.size() != 5:
		return _fallback_swatches(width, height)
	var rects: Array[Rect2i] = []
	for run in runs:
		var centre_x: int = (int(run.x) + int(run.y)) / 2
		var vertical := PackedByteArray()
		vertical.resize(height)
		for y in range(height):
			var matches := 0
			for x_offset in [-6, -3, 0, 3, 6]:
				var color := source.get_pixel(clampi(centre_x + x_offset, 0, width - 1), y)
				if _color_distance(color, background) > 0.075:
					matches += 1
			vertical[y] = 1 if matches >= 3 else 0
		_close_short_gaps(vertical, maxi(5, height / 180))
		var vertical_runs := _active_runs(vertical, maxi(48, height / 8))
		if vertical_runs.is_empty():
			return _fallback_swatches(width, height)
		var best: Vector2i = vertical_runs[0]
		for candidate in vertical_runs:
			if int(candidate.y) - int(candidate.x) > best.y - best.x:
				best = candidate
		var inset := 3
		var rect := Rect2i(
			int(run.x) + inset,
			best.x + inset,
			maxi(8, int(run.y) - int(run.x) - inset * 2 + 1),
			maxi(8, best.y - best.x - inset * 2 + 1)
		)
		var square_size := mini(rect.size.x, rect.size.y)
		rect.position += (rect.size - Vector2i.ONE * square_size) / 2
		rect.size = Vector2i.ONE * square_size
		rects.append(rect)
	return rects


func _background_color(source: Image) -> Color:
	var width := source.get_width()
	var height := source.get_height()
	var samples := [
		source.get_pixel(4, 4),
		source.get_pixel(width - 5, 4),
		source.get_pixel(4, height - 5),
		source.get_pixel(width - 5, height - 5),
		source.get_pixel(width / 2, 4),
	]
	var result := Color(0.0, 0.0, 0.0, 1.0)
	for sample in samples:
		result += sample
	return result / float(samples.size())


func _color_distance(left: Color, right: Color) -> float:
	return absf(left.r - right.r) + absf(left.g - right.g) + absf(left.b - right.b)


func _close_short_gaps(active: PackedByteArray, maximum_gap: int) -> void:
	var index := 0
	while index < active.size():
		if active[index] != 0:
			index += 1
			continue
		var start := index
		while index < active.size() and active[index] == 0:
			index += 1
		if start > 0 and index < active.size() and index - start <= maximum_gap:
			for fill_index in range(start, index):
				active[fill_index] = 1


func _active_runs(active: PackedByteArray, minimum_length: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var index := 0
	while index < active.size():
		while index < active.size() and active[index] == 0:
			index += 1
		var start := index
		while index < active.size() and active[index] != 0:
			index += 1
		if index - start >= minimum_length:
			result.append(Vector2i(start, index - 1))
	return result


func _fallback_swatches(width: int, height: int) -> Array[Rect2i]:
	var pitch := float(width) / 5.0
	var square_size := mini(int(pitch * 0.86), int(height * 0.52))
	var result: Array[Rect2i] = []
	for index in range(5):
		result.append(Rect2i(
			int((float(index) + 0.5) * pitch - float(square_size) * 0.5),
			(height - square_size) / 2,
			square_size,
			square_size
		))
	return result


func _normalize_albedo(image: Image) -> void:
	# Cross-polarized direction boards are already close to flat lighting. A
	# restrained value normalization keeps dark fur readable without destroying
	# species markings or turning hide into a painted colour patch.
	var average := 0.0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			average += image.get_pixel(x, y).get_luminance()
	average /= float((image.get_width() / 4) * (image.get_height() / 4))
	var exposure := clampf(0.46 / maxf(average, 0.08), 0.82, 1.28)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			color.r = clampf(pow(color.r * exposure, 0.96), 0.0, 1.0)
			color.g = clampf(pow(color.g * exposure, 0.96), 0.0, 1.0)
			color.b = clampf(pow(color.b * exposure, 0.96), 0.0, 1.0)
			color.a = 1.0
			image.set_pixel(x, y, color)


func _build_normal(albedo: Image, relief: float) -> Image:
	var width := albedo.get_width()
	var height := albedo.get_height()
	var normal := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			var left := albedo.get_pixel(posmod(x - 1, width), y).get_luminance()
			var right := albedo.get_pixel((x + 1) % width, y).get_luminance()
			var up := albedo.get_pixel(x, posmod(y - 1, height)).get_luminance()
			var down := albedo.get_pixel(x, (y + 1) % height).get_luminance()
			var vector := Vector3((left - right) * relief, (up - down) * relief, 1.0).normalized()
			normal.set_pixel(x, y, Color(vector.x * 0.5 + 0.5, vector.y * 0.5 + 0.5, vector.z * 0.5 + 0.5, 1.0))
	return normal


func _build_roughness(albedo: Image, base_roughness: float) -> Image:
	var width := albedo.get_width()
	var height := albedo.get_height()
	var roughness := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			var luminance := albedo.get_pixel(x, y).get_luminance()
			var local := clampf(base_roughness + (0.48 - luminance) * 0.16, 0.38, 0.98)
			roughness.set_pixel(x, y, Color(local, local, local, 1.0))
	return roughness
