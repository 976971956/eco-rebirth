class_name LowPolyFactory
extends RefCounted

static var _terrain_shader: Shader
static var _biome_blend_shader: Shader
static var _water_shader: Shader
static var _shared_faceted_material: StandardMaterial3D
static var _faceted_sphere_cache: Dictionary = {}
static var _foliage_card_material_cache: Dictionary = {}

const FACETED_SPHERE_CACHE_LIMIT := 384


static func material(color: Color, roughness: float = 0.84, emission: Color = Color.TRANSPARENT) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = clampf(roughness, 0.18, 1.0)
	mat.metallic = 0.0
	mat.metallic_specular = 0.18
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	if emission.a > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 0.85
	return mat


static func faceted_material(roughness: float = 0.79) -> StandardMaterial3D:
	if is_equal_approx(roughness, 0.79) and _shared_faceted_material != null:
		return _shared_faceted_material
	var mat := material(Color.WHITE, roughness)
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = false
	mat.rim_enabled = true
	mat.rim = 0.035
	mat.rim_tint = 0.28
	if is_equal_approx(roughness, 0.79):
		_shared_faceted_material = mat
	return mat


## Blends the four scanned-style biome textures on one continuous world-space
## surface.  Macro variation, restrained colour grading and a cheap procedural
## detail normal keep the ground natural without normal-map memory on Web/mobile.
static func biome_blend_material(forest_texture: Texture2D, grassland_texture: Texture2D, wetland_texture: Texture2D, highland_texture: Texture2D, world_extent: float, relief_amplitude: float = 0.0) -> ShaderMaterial:
	if _biome_blend_shader == null:
		_biome_blend_shader = Shader.new()
		_biome_blend_shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D forest_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grassland_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wetland_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D highland_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float world_extent = 43.0;
uniform float texture_world_scale = 7.6;
uniform float relief_amplitude = 0.0;
uniform float micro_normal_strength = 0.44;
varying vec3 world_position;

float biome_hash(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

float biome_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = biome_hash(cell);
	float b = biome_hash(cell + vec2(1.0, 0.0));
	float c = biome_hash(cell + vec2(0.0, 1.0));
	float d = biome_hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

vec3 grade_surface(vec3 painted, vec3 tint, float strength) {
	float luminance = dot(painted, vec3(0.299, 0.587, 0.114));
	vec3 graded = tint * mix(0.74, 1.18, luminance);
	return mix(painted, graded, strength);
}

void vertex() {
	vec3 base_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float relief_a = biome_noise(base_world.xz * 0.028 + vec2(8.2, 3.7));
	float relief_b = biome_noise(base_world.zx * 0.063 + vec2(1.4, 11.8));
	VERTEX.y += ((relief_a - 0.5) * 0.72 + (relief_b - 0.5) * 0.28) * relief_amplitude;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 sample_uv = world_position.xz / texture_world_scale;
	float broad_a = biome_noise(world_position.xz * 0.035);
	float broad_b = biome_noise(world_position.zx * 0.071 + vec2(17.2, 6.4));
	float warp_x = (broad_a - 0.5) * world_extent * 0.115 + (broad_b - 0.5) * world_extent * 0.045;
	float warp_z = (broad_b - 0.5) * world_extent * 0.105 - (broad_a - 0.5) * world_extent * 0.040;
	float blend_width = max(world_extent * 0.075, 4.2);
	float east_mix = smoothstep(-blend_width, blend_width, world_position.x + warp_x);
	float south_mix = smoothstep(-blend_width, blend_width, world_position.z + warp_z);

	vec2 detail_uv = vec2(-sample_uv.y, sample_uv.x) * 0.57 + vec2(0.37, 0.61);
	vec3 forest_raw = mix(texture(forest_texture, sample_uv).rgb, texture(forest_texture, detail_uv).rgb, 0.18);
	vec3 grass_raw = mix(texture(grassland_texture, sample_uv * 0.94 + vec2(0.17, 0.31)).rgb, texture(grassland_texture, detail_uv * 1.07 + vec2(0.42, 0.13)).rgb, 0.16);
	vec3 wetland_raw = mix(texture(wetland_texture, sample_uv * 1.04 + vec2(0.43, 0.12)).rgb, texture(wetland_texture, detail_uv * 0.91 + vec2(0.08, 0.48)).rgb, 0.18);
	vec3 highland_raw = mix(texture(highland_texture, sample_uv * 0.90 + vec2(0.24, 0.57)).rgb, texture(highland_texture, detail_uv * 1.12 + vec2(0.66, 0.21)).rgb, 0.16);
	vec3 forest = grade_surface(forest_raw, vec3(0.25, 0.31, 0.20), 0.13);
	vec3 grassland = grade_surface(grass_raw * vec3(0.60, 0.64, 0.52), vec3(0.27, 0.31, 0.16), 0.30);
	vec3 wetland = grade_surface(wetland_raw, vec3(0.22, 0.31, 0.27), 0.14);
	vec3 highland = grade_surface(highland_raw * vec3(0.82, 0.80, 0.74), vec3(0.39, 0.36, 0.29), 0.16);
	vec3 north = mix(forest, grassland, east_mix);
	vec3 south = mix(wetland, highland, east_mix);
	vec3 terrain = mix(north, south, south_mix);
	float macro = biome_noise(world_position.xz * 0.018 + vec2(3.1, 8.7));
	float grain = biome_noise(world_position.xz * 0.38);
	ALBEDO = terrain * mix(0.88, 1.08, macro) * mix(0.965, 1.035, grain);

	float bump = biome_noise(world_position.xz * 1.32);
	float bump_x = biome_noise(world_position.xz * 1.32 + vec2(0.055, 0.0));
	float bump_z = biome_noise(world_position.xz * 1.32 + vec2(0.0, 0.055));
	vec3 detail_normal = normalize(vec3((bump - bump_x) * 7.2 * micro_normal_strength, 1.0, (bump - bump_z) * 7.2 * micro_normal_strength));
	NORMAL_MAP = detail_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.48;
	float wetland_weight = south_mix * (1.0 - east_mix);
	ROUGHNESS = mix(mix(0.84, 0.94, grain), 0.69, wetland_weight * 0.72);
	SPECULAR = mix(0.16, 0.34, wetland_weight);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = _biome_blend_shader
	mat.set_shader_parameter("forest_texture", forest_texture)
	mat.set_shader_parameter("grassland_texture", grassland_texture)
	mat.set_shader_parameter("wetland_texture", wetland_texture)
	mat.set_shader_parameter("highland_texture", highland_texture)
	mat.set_shader_parameter("world_extent", maxf(world_extent, 1.0))
	mat.set_shader_parameter("texture_world_scale", 7.6)
	mat.set_shader_parameter("relief_amplitude", clampf(relief_amplitude, 0.0, 0.08))
	return mat


static func terrain_material(base_color: Color, detail_color: Color, pattern_scale: float = 10.0, painted_texture: Texture2D = null, texture_scale: float = 3.0, texture_strength: float = 0.0) -> ShaderMaterial:
	if _terrain_shader == null:
		_terrain_shader = Shader.new()
		_terrain_shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color;
uniform vec4 detail_color : source_color;
uniform float pattern_scale = 10.0;
uniform sampler2D painted_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float texture_scale = 3.0;
uniform float texture_strength = 0.0;

float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 345.45));
	point += dot(point, point + 34.345);
	return fract(point.x * point.y);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

void fragment() {
	vec2 tiled_uv = UV * pattern_scale;
	float broad = value_noise(tiled_uv * 0.42);
	float fine = value_noise(tiled_uv * 1.85);
	float grain = value_noise(tiled_uv * 4.2);
	float blend_value = clamp(broad * 0.60 + fine * 0.28 + grain * 0.12, 0.0, 1.0);
	vec3 terrain_color = mix(base_color.rgb, detail_color.rgb, smoothstep(0.28, 0.78, blend_value));
	vec3 painted = texture(painted_texture, UV * texture_scale).rgb;
	float painted_luma = dot(painted, vec3(0.299, 0.587, 0.114));
	vec3 painted_tinted = mix(terrain_color, painted, 0.46) * mix(0.78, 1.14, painted_luma);
	ALBEDO = mix(terrain_color, painted_tinted, texture_strength) * 0.72;
	ROUGHNESS = 0.82 + grain * 0.12;
	SPECULAR = 0.18;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = _terrain_shader
	mat.set_shader_parameter("base_color", base_color)
	mat.set_shader_parameter("detail_color", detail_color)
	mat.set_shader_parameter("pattern_scale", pattern_scale)
	mat.set_shader_parameter("texture_scale", texture_scale)
	mat.set_shader_parameter("texture_strength", clampf(texture_strength, 0.0, 0.55) if painted_texture != null else 0.0)
	if painted_texture != null:
		mat.set_shader_parameter("painted_texture", painted_texture)
	return mat


static func water_material(shallow_color: Color, deep_color: Color, opacity: float = 0.82, visual_depth: float = 0.35) -> ShaderMaterial:
	if _water_shader == null:
		_water_shader = Shader.new()
		_water_shader.code = """
shader_type spatial;
// Transparent water must not become an opaque depth mask.  Writing the water
// plane into the depth buffer hid submerged skinned meshes while a few
// no-depth-test details remained visible, which looked like a moving skeleton.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color;
uniform vec4 deep_color : source_color;
uniform float opacity = 0.82;
uniform float visual_depth = 0.35;

void fragment() {
	vec2 wave_uv = UV * vec2(10.0, 13.0);
	float wave_a = sin(wave_uv.x + wave_uv.y * 0.52 + TIME * 1.08);
	float wave_b = sin(wave_uv.y * 1.47 - wave_uv.x * 0.38 - TIME * 0.79);
	float wave_c = sin((wave_uv.x - wave_uv.y) * 0.43 + TIME * 0.46);
	float ripple = wave_a * 0.38 + wave_b * 0.37 + wave_c * 0.25;
	float edge_glint = smoothstep(0.68, 0.98, abs(ripple));
	float depth_mix = clamp(visual_depth + ripple * 0.035, 0.0, 1.0);
	vec3 ripple_normal = normalize(vec3(cos(wave_uv.x + TIME * 1.08) * 0.15, 1.0, cos(wave_uv.y * 1.47 - TIME * 0.79) * 0.12));
	NORMAL_MAP = ripple_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.62;
	ALBEDO = mix(shallow_color.rgb, deep_color.rgb, depth_mix) * mix(0.76, 0.58, visual_depth);
	EMISSION = shallow_color.rgb * edge_glint * mix(0.035, 0.012, visual_depth);
	ROUGHNESS = 0.12 + (1.0 - edge_glint) * 0.11 + visual_depth * 0.035;
	SPECULAR = 0.86;
	ALPHA = opacity;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = _water_shader
	mat.set_shader_parameter("shallow_color", shallow_color)
	mat.set_shader_parameter("deep_color", deep_color)
	mat.set_shader_parameter("opacity", opacity)
	mat.set_shader_parameter("visual_depth", clampf(visual_depth, 0.0, 1.0))
	return mat


## A camera-facing alpha-scissored vegetation card.  The visual has no physics;
## EcoWorld keeps its existing trunk collider and clearance radius authoritative.
## One shared material per texture keeps the realistic canopy layer inexpensive.
static func foliage_card(name_text: String, texture: Texture2D, size_value: Vector2, position_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_text
	var mesh := QuadMesh.new()
	mesh.size = size_value
	mesh.orientation = PlaneMesh.FACE_Z
	var texture_key := texture.resource_path if not texture.resource_path.is_empty() else str(texture.get_rid())
	var card_material: StandardMaterial3D
	if _foliage_card_material_cache.has(texture_key):
		card_material = _foliage_card_material_cache[texture_key] as StandardMaterial3D
	else:
		card_material = StandardMaterial3D.new()
		card_material.albedo_texture = texture
		card_material.roughness = 0.92
		card_material.metallic_specular = 0.08
		card_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		card_material.alpha_scissor_threshold = 0.34
		card_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		card_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		card_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_foliage_card_material_cache[texture_key] = card_material
	mesh.material = card_material
	node.mesh = mesh
	node.position = position_value
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.set_meta("visual_only", true)
	return node


static func sphere(name_text: String, color: Color, scale_value: Vector3, position_value: Vector3 = Vector3.ZERO, radial: int = 8, rings: int = 5) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_text
	node.mesh = _faceted_sphere_mesh(color, maxi(radial, 6), maxi(rings, 4))
	node.material_override = faceted_material()
	node.scale = scale_value
	node.position = position_value
	return node


static func _faceted_sphere_mesh(color: Color, radial: int, rings: int) -> ArrayMesh:
	var cache_key := "%d:%d:%d" % [color.to_rgba32(), radial, rings]
	if _faceted_sphere_cache.has(cache_key):
		return _faceted_sphere_cache[cache_key] as ArrayMesh
	# Environment colors include small random variations. Bound the shared cache
	# so repeated world regeneration cannot retain every historical tint forever.
	if _faceted_sphere_cache.size() >= FACETED_SPHERE_CACHE_LIMIT:
		_faceted_sphere_cache.clear()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_vertices: Array[PackedVector3Array] = []
	for ring_index in range(1, rings):
		var latitude := PI * float(ring_index) / float(rings)
		var ring := PackedVector3Array()
		var radius_at_height := sin(latitude) * 0.5
		var height := cos(latitude) * 0.5
		for side_index in range(radial):
			var longitude := TAU * float(side_index) / float(radial)
			ring.append(Vector3(cos(longitude) * radius_at_height, height, sin(longitude) * radius_at_height))
		ring_vertices.append(ring)

	var face_index := 0
	var top := Vector3(0.0, 0.5, 0.0)
	var bottom := Vector3(0.0, -0.5, 0.0)
	var first_ring: PackedVector3Array = ring_vertices[0]
	for side_index in range(radial):
		var next_side := (side_index + 1) % radial
		_add_smooth_sphere_facet(surface, top, first_ring[side_index], first_ring[next_side], color, face_index)
		face_index += 1
	for ring_index in range(ring_vertices.size() - 1):
		var upper: PackedVector3Array = ring_vertices[ring_index]
		var lower: PackedVector3Array = ring_vertices[ring_index + 1]
		for side_index in range(radial):
			var next_side := (side_index + 1) % radial
			var alternate := (side_index + ring_index) % 2 == 0
			if alternate:
				_add_smooth_sphere_facet(surface, upper[side_index], lower[side_index], lower[next_side], color, face_index)
				face_index += 1
				_add_smooth_sphere_facet(surface, upper[side_index], lower[next_side], upper[next_side], color, face_index)
			else:
				_add_smooth_sphere_facet(surface, upper[side_index], lower[side_index], upper[next_side], color, face_index)
				face_index += 1
				_add_smooth_sphere_facet(surface, upper[next_side], lower[side_index], lower[next_side], color, face_index)
			face_index += 1
	var last_ring: PackedVector3Array = ring_vertices[ring_vertices.size() - 1]
	for side_index in range(radial):
		var next_side := (side_index + 1) % radial
		_add_smooth_sphere_facet(surface, bottom, last_ring[next_side], last_ring[side_index], color, face_index)
		face_index += 1
	var mesh := surface.commit()
	_faceted_sphere_cache[cache_key] = mesh
	return mesh


static func cylinder(name_text: String, color: Color, radius: float, height: float, position_value: Vector3 = Vector3.ZERO, radial: int = 8) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_text
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial
	mesh.rings = 1
	node.mesh = mesh
	node.material_override = material(color)
	node.position = position_value
	return node


static func tapered_cylinder(name_text: String, color: Color, bottom_radius: float, top_radius: float, height: float, position_value: Vector3 = Vector3.ZERO, radial: int = 8) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_text
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = radial
	mesh.rings = 1
	node.mesh = mesh
	node.material_override = material(color)
	node.position = position_value
	return node


static func disc(name_text: String, color: Color, radius: float, height: float = 0.04, position_value: Vector3 = Vector3.ZERO, radial: int = 12) -> MeshInstance3D:
	return cylinder(name_text, color, radius, height, position_value, radial)


## Builds one continuous faceted mesh along a curved center line. Each Vector2 in
## `radii` is the horizontal and vertical radius of the matching cross section.
## Keeping the torso, neck, head and tail in one surface removes the toy-like seams
## caused by overlapping primitive meshes, while staying lightweight on mobile.
static func loft(name_text: String, color: Color, centers: Array, radii: Array, sides: int = 8) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_text
	if centers.size() < 2 or centers.size() != radii.size():
		return node

	var ring_count := centers.size()
	var side_count := maxi(sides, 5)
	var rings: Array = []
	var normal_rings: Array = []
	var tangents: Array[Vector3] = []
	for ring_index in range(ring_count):
		var center: Vector3 = centers[ring_index]
		var tangent: Vector3
		if ring_index == 0:
			tangent = Vector3(centers[1]) - center
		elif ring_index == ring_count - 1:
			tangent = center - Vector3(centers[ring_index - 1])
		else:
			tangent = Vector3(centers[ring_index + 1]) - Vector3(centers[ring_index - 1])
		tangent = tangent.normalized()
		tangents.append(tangent)
		var side_axis := Vector3.UP.cross(tangent)
		if side_axis.length_squared() < 0.001:
			side_axis = Vector3.RIGHT.cross(tangent)
		side_axis = side_axis.normalized()
		var up_axis := tangent.cross(side_axis).normalized()
		var radius: Vector2 = radii[ring_index]
		var ring := PackedVector3Array()
		var normal_ring := PackedVector3Array()
		for side_index in range(side_count):
			var angle := TAU * float(side_index) / float(side_count)
			ring.append(center + side_axis * cos(angle) * radius.x + up_axis * sin(angle) * radius.y)
			var radial_normal := side_axis * cos(angle) / maxf(radius.x, 0.001) + up_axis * sin(angle) / maxf(radius.y, 0.001)
			normal_ring.append(radial_normal.normalized())
		rings.append(ring)
		normal_rings.append(normal_ring)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var face_index := 0
	for ring_index in range(ring_count - 1):
		var first: PackedVector3Array = rings[ring_index]
		var second: PackedVector3Array = rings[ring_index + 1]
		var first_normals: PackedVector3Array = normal_rings[ring_index]
		var second_normals: PackedVector3Array = normal_rings[ring_index + 1]
		for side_index in range(side_count):
			var next_side := (side_index + 1) % side_count
			_add_oriented_smooth_colored_triangle(surface, first[side_index], second[next_side], second[side_index], first_normals[side_index], second_normals[next_side], second_normals[side_index], color, face_index)
			face_index += 1
			_add_oriented_smooth_colored_triangle(surface, first[side_index], first[next_side], second[next_side], first_normals[side_index], first_normals[next_side], second_normals[next_side], color, face_index)
			face_index += 1

	var start_center: Vector3 = centers[0]
	var end_center: Vector3 = centers[ring_count - 1]
	var start_ring: PackedVector3Array = rings[0]
	var end_ring: PackedVector3Array = rings[ring_count - 1]
	var start_cap_normal: Vector3 = -tangents[0]
	var end_cap_normal: Vector3 = tangents[tangents.size() - 1]
	for side_index in range(side_count):
		var next_side := (side_index + 1) % side_count
		_add_oriented_smooth_colored_triangle(surface, start_center, start_ring[next_side], start_ring[side_index], start_cap_normal, start_cap_normal, start_cap_normal, color, face_index)
		face_index += 1
		_add_oriented_smooth_colored_triangle(surface, end_center, end_ring[side_index], end_ring[next_side], end_cap_normal, end_cap_normal, end_cap_normal, color, face_index)
		face_index += 1

	node.mesh = surface.commit()
	node.material_override = faceted_material()
	return node


static func _add_smooth_sphere_facet(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, face_index: int) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var center := (a + b + c) / 3.0
	if normal.dot(center) < 0.0:
		var swap := b
		b = c
		c = swap
	_add_smooth_colored_triangle(surface, a, b, c, a.normalized(), b.normalized(), c.normalized(), color, face_index)


static func _add_oriented_smooth_colored_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal_a: Vector3, normal_b: Vector3, normal_c: Vector3, color: Color, face_index: int) -> void:
	# Curved center-lines can rotate the loft basis between neighbouring rings.
	# Keep geometric winding aligned with the supplied outward normals so glTF
	# importers do not classify visible coat surfaces as back faces.
	var face_normal := (b - a).cross(c - a).normalized()
	var average_normal := (normal_a + normal_b + normal_c).normalized()
	if face_normal.dot(average_normal) < 0.0:
		var swap_vertex := b
		b = c
		c = swap_vertex
		var swap_normal := normal_b
		normal_b = normal_c
		normal_c = swap_normal
	_add_smooth_colored_triangle(surface, a, b, c, normal_a, normal_b, normal_c, color, face_index)


static func _add_smooth_colored_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal_a: Vector3, normal_b: Vector3, normal_c: Vector3, color: Color, _face_index: int) -> void:
	# Vertex-based coat variation stays continuous across adjacent triangles.
	# The former per-face color jump made otherwise curved bodies look assembled
	# from plastic plates even after their normals were smoothed.
	surface.set_color(_organic_vertex_color(color, a, normal_a))
	surface.set_normal(normal_a)
	surface.add_vertex(a)
	surface.set_color(_organic_vertex_color(color, b, normal_b))
	surface.set_normal(normal_b)
	surface.add_vertex(b)
	surface.set_color(_organic_vertex_color(color, c, normal_c))
	surface.set_normal(normal_c)
	surface.add_vertex(c)


static func _organic_vertex_color(base_color: Color, vertex: Vector3, normal: Vector3) -> Color:
	var key_light := Vector3(-0.36, 0.82, -0.44).normalized()
	var light_bias := normal.dot(key_light) * 0.014
	var position_variation := sin(vertex.x * 9.17 + vertex.y * 5.31 + vertex.z * 7.73) * 0.006
	var shift := light_bias + position_variation
	return base_color.lightened(shift) if shift >= 0.0 else base_color.darkened(-shift)


static func cone(name_text: String, color: Color, radius: float, height: float, position_value: Vector3 = Vector3.ZERO, radial: int = 8) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_text
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial
	mesh.rings = 1
	node.mesh = mesh
	node.material_override = material(color)
	node.position = position_value
	return node


static func box(name_text: String, color: Color, size: Vector3, position_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_text
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color)
	node.position = position_value
	return node


static func add_static_cylinder(parent: Node3D, radius: float, height: float, position_value: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Obstacle"
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = position_value
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body


static func add_static_box(parent: Node3D, size: Vector3, position_value: Vector3, rotation_y: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Obstacle"
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = position_value
	body.rotation.y = rotation_y
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body
