class_name LowPolyFactory
extends RefCounted


static func material(color: Color, roughness: float = 0.92, emission: Color = Color.TRANSPARENT) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = 0.0
	mat.metallic_specular = 0.18
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	if emission.a > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 0.85
	return mat


static func sphere(name_text: String, color: Color, scale_value: Vector3, position_value: Vector3 = Vector3.ZERO, radial: int = 8, rings: int = 5) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_text
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = radial
	mesh.rings = rings
	node.mesh = mesh
	node.material_override = material(color)
	node.scale = scale_value
	node.position = position_value
	return node


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
	for ring_index in range(ring_count - 1):
		var first: PackedVector3Array = rings[ring_index]
		var second: PackedVector3Array = rings[ring_index + 1]
		for side_index in range(side_count):
			var next_side := (side_index + 1) % side_count
			_add_triangle(surface, first[side_index], second[next_side], second[side_index])
			_add_triangle(surface, first[side_index], first[next_side], second[next_side])

	var start_center: Vector3 = centers[0]
	var end_center: Vector3 = centers[ring_count - 1]
	var start_ring: PackedVector3Array = rings[0]
	var end_ring: PackedVector3Array = rings[ring_count - 1]
	for side_index in range(side_count):
		var next_side := (side_index + 1) % side_count
		_add_triangle(surface, start_center, start_ring[next_side], start_ring[side_index])
		_add_triangle(surface, end_center, end_ring[side_index], end_ring[next_side])

	surface.generate_normals()
	node.mesh = surface.commit()
	node.material_override = material(color)
	return node


static func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
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
