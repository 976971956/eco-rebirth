class_name LowPolyFactory
extends RefCounted

static var _terrain_shader: Shader
static var _water_shader: Shader
static var _shared_faceted_material: StandardMaterial3D
static var _faceted_sphere_cache: Dictionary = {}

const FACETED_SPHERE_CACHE_LIMIT := 384


static func material(color: Color, roughness: float = 0.84, emission: Color = Color.TRANSPARENT) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = clampf(roughness, 0.18, 1.0)
	mat.metallic = 0.0
	mat.metallic_specular = 0.28
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
	mat.rim = 0.11
	mat.rim_tint = 0.42
	if is_equal_approx(roughness, 0.79):
		_shared_faceted_material = mat
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


static func water_material(shallow_color: Color, deep_color: Color, opacity: float = 0.82) -> ShaderMaterial:
	if _water_shader == null:
		_water_shader = Shader.new()
		_water_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color;
uniform vec4 deep_color : source_color;
uniform float opacity = 0.82;

void fragment() {
	vec2 wave_uv = UV * vec2(8.0, 11.0);
	float wave_a = sin(wave_uv.x + wave_uv.y * 0.46 + TIME * 1.25);
	float wave_b = sin(wave_uv.y * 1.55 - wave_uv.x * 0.32 - TIME * 0.92);
	float ripple = wave_a * 0.5 + wave_b * 0.5;
	float edge_glint = smoothstep(0.62, 0.96, abs(ripple));
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, 0.48 + ripple * 0.12) * 0.72;
	EMISSION = shallow_color.rgb * edge_glint * 0.055;
	ROUGHNESS = 0.17 + (1.0 - edge_glint) * 0.10;
	SPECULAR = 0.78;
	ALPHA = opacity;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = _water_shader
	mat.set_shader_parameter("shallow_color", shallow_color)
	mat.set_shader_parameter("deep_color", deep_color)
	mat.set_shader_parameter("opacity", opacity)
	return mat


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
		_add_outward_facet(surface, top, first_ring[side_index], first_ring[next_side], color, face_index)
		face_index += 1
	for ring_index in range(ring_vertices.size() - 1):
		var upper: PackedVector3Array = ring_vertices[ring_index]
		var lower: PackedVector3Array = ring_vertices[ring_index + 1]
		for side_index in range(radial):
			var next_side := (side_index + 1) % radial
			var alternate := (side_index + ring_index) % 2 == 0
			if alternate:
				_add_outward_facet(surface, upper[side_index], lower[side_index], lower[next_side], color, face_index)
				face_index += 1
				_add_outward_facet(surface, upper[side_index], lower[next_side], upper[next_side], color, face_index)
			else:
				_add_outward_facet(surface, upper[side_index], lower[side_index], upper[next_side], color, face_index)
				face_index += 1
				_add_outward_facet(surface, upper[next_side], lower[side_index], lower[next_side], color, face_index)
			face_index += 1
	var last_ring: PackedVector3Array = ring_vertices[ring_vertices.size() - 1]
	for side_index in range(radial):
		var next_side := (side_index + 1) % radial
		_add_outward_facet(surface, bottom, last_ring[next_side], last_ring[side_index], color, face_index)
		face_index += 1
	surface.generate_normals()
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
		var side_axis := Vector3.UP.cross(tangent)
		if side_axis.length_squared() < 0.001:
			side_axis = Vector3.RIGHT.cross(tangent)
		side_axis = side_axis.normalized()
		var up_axis := tangent.cross(side_axis).normalized()
		var radius: Vector2 = radii[ring_index]
		var ring := PackedVector3Array()
		for side_index in range(side_count):
			var angle := TAU * float(side_index) / float(side_count)
			ring.append(center + side_axis * cos(angle) * radius.x + up_axis * sin(angle) * radius.y)
		rings.append(ring)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var face_index := 0
	for ring_index in range(ring_count - 1):
		var first: PackedVector3Array = rings[ring_index]
		var second: PackedVector3Array = rings[ring_index + 1]
		for side_index in range(side_count):
			var next_side := (side_index + 1) % side_count
			_add_colored_triangle(surface, first[side_index], second[next_side], second[side_index], color, face_index)
			face_index += 1
			_add_colored_triangle(surface, first[side_index], first[next_side], second[next_side], color, face_index)
			face_index += 1

	var start_center: Vector3 = centers[0]
	var end_center: Vector3 = centers[ring_count - 1]
	var start_ring: PackedVector3Array = rings[0]
	var end_ring: PackedVector3Array = rings[ring_count - 1]
	for side_index in range(side_count):
		var next_side := (side_index + 1) % side_count
		_add_colored_triangle(surface, start_center, start_ring[next_side], start_ring[side_index], color, face_index)
		face_index += 1
		_add_colored_triangle(surface, end_center, end_ring[side_index], end_ring[next_side], color, face_index)
		face_index += 1

	surface.generate_normals()
	node.mesh = surface.commit()
	node.material_override = faceted_material()
	return node


static func _add_outward_facet(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, face_index: int) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var center := (a + b + c) / 3.0
	if normal.dot(center) < 0.0:
		var swap := b
		b = c
		c = swap
	_add_colored_triangle(surface, a, b, c, color, face_index)


static func _add_colored_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, face_index: int) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var key_light := Vector3(-0.36, 0.82, -0.44).normalized()
	var light_bias := normal.dot(key_light) * 0.055
	var deterministic_variation := sin(float(face_index) * 12.9898 + a.x * 18.13 + a.z * 7.71) * 0.026
	var color_shift := light_bias + deterministic_variation
	var face_color := color.lightened(color_shift) if color_shift >= 0.0 else color.darkened(-color_shift)
	surface.set_color(face_color)
	surface.add_vertex(a)
	surface.set_color(face_color)
	surface.add_vertex(b)
	surface.set_color(face_color)
	surface.add_vertex(c)


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
