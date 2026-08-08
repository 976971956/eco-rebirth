class_name EcoSkillVFX
extends RefCounted

const Factory = preload("res://scripts/low_poly_factory.gd")


static func ring(parent: Node, world_position: Vector3, color: Color, start_radius: float, end_radius: float, duration: float, delay: float = 0.0, height: float = 0.10) -> void:
	if not is_instance_valid(parent):
		return
	var node := MeshInstance3D.new()
	node.name = "SkillRing"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.82
	mesh.outer_radius = 1.0
	mesh.rings = 18
	mesh.ring_segments = 5
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.material_override = _fx_material(color)
	parent.add_child(node)
	node.global_position = Vector3(world_position.x, world_position.y + height, world_position.z)
	var tween := parent.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(node, "scale", Vector3(end_radius, 0.65, end_radius), duration).from(Vector3(start_radius, 0.65, start_radius)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node.material_override, "albedo_color", Color(color.r, color.g, color.b, 0.0), duration).from(Color(color.r, color.g, color.b, 0.82))
	tween.finished.connect(node.queue_free)


static func radial_burst(parent: Node, world_position: Vector3, color: Color, radius: float, count: int = 8, shard_size: float = 0.16, duration: float = 0.42, phase: float = 0.0) -> void:
	if not is_instance_valid(parent):
		return
	var root := Node3D.new()
	root.name = "SkillBurst"
	parent.add_child(root)
	root.global_position = Vector3(world_position.x, world_position.y + 0.22, world_position.z)
	var tween := parent.create_tween()
	tween.set_parallel(true)
	for index in range(count):
		var angle := phase + TAU * float(index) / float(maxi(count, 1))
		var direction := Vector3(cos(angle), 0.16 + 0.08 * float(index % 3), sin(angle)).normalized()
		var shard := Factory.sphere("Spark", color, Vector3(shard_size, shard_size * 0.72, shard_size), direction * 0.15, 6, 3)
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shard.material_override = _fx_material(color)
		root.add_child(shard)
		tween.tween_property(shard, "position", direction * radius, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "scale", Vector3.ZERO, duration).from(shard.scale)
	tween.finished.connect(root.queue_free)


static func dash_trail(parent: Node, world_position: Vector3, direction: Vector3, color: Color, length: float = 2.8) -> void:
	if not is_instance_valid(parent):
		return
	var flat_direction := Vector3(direction.x, 0.0, direction.z).normalized()
	if flat_direction.length_squared() < 0.01:
		flat_direction = Vector3.FORWARD
	var root := Node3D.new()
	root.name = "SkillDashTrail"
	parent.add_child(root)
	root.global_position = Vector3(world_position.x, world_position.y + 0.48, world_position.z)
	root.rotation.y = atan2(-flat_direction.x, -flat_direction.z)
	var tween := parent.create_tween()
	tween.set_parallel(true)
	for index in range(5):
		var side := (float(index) - 2.0) * 0.20
		var streak_length := length * (1.0 - absf(side) * 0.42)
		var streak := Factory.box("WindStreak", color, Vector3(0.055 + 0.018 * (index % 2), 0.055, streak_length), Vector3(side, float(index % 2) * 0.20, streak_length * 0.55))
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		streak.material_override = _fx_material(color)
		root.add_child(streak)
		tween.tween_property(streak, "scale", Vector3(0.25, 0.25, 0.10), 0.30).from(Vector3.ONE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(streak.material_override, "albedo_color", Color(color.r, color.g, color.b, 0.0), 0.30).from(Color(color.r, color.g, color.b, 0.72))
	tween.finished.connect(root.queue_free)


static func fang_strike(parent: Node, world_position: Vector3, direction: Vector3, color: Color, scale_value: float = 1.0) -> void:
	if not is_instance_valid(parent):
		return
	var flat_direction := Vector3(direction.x, 0.0, direction.z).normalized()
	if flat_direction.length_squared() < 0.01:
		flat_direction = Vector3.FORWARD
	var root := Node3D.new()
	root.name = "FangStrike"
	parent.add_child(root)
	root.global_position = Vector3(world_position.x, world_position.y + 0.82, world_position.z)
	root.rotation.y = atan2(-flat_direction.x, -flat_direction.z)
	for side in [-1.0, 1.0]:
		var fang := Factory.cone("Fang", color, 0.14 * scale_value, 0.92 * scale_value, Vector3(side * 0.23 * scale_value, 0.0, -0.18 * scale_value), 7)
		fang.rotation.x = -PI * 0.42
		fang.rotation.z = side * 0.18
		fang.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fang.material_override = _fx_material(color)
		root.add_child(fang)
		var fang_mat := fang.material_override as StandardMaterial3D
		if fang_mat != null:
			var fade_tween := parent.create_tween()
			fade_tween.tween_property(fang_mat, "albedo_color", Color(color.r, color.g, color.b, 0.0), 0.20).set_delay(0.08)
	var tween := parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "scale", Vector3(1.32, 1.32, 1.32), 0.18).from(Vector3(0.30, 0.30, 0.30)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "position", root.position + flat_direction * 0.72, 0.22)
	tween.finished.connect(root.queue_free)


static func ground_spokes(parent: Node, world_position: Vector3, color: Color, radius: float, count: int = 9) -> void:
	if not is_instance_valid(parent):
		return
	var root := Node3D.new()
	root.name = "GroundSpokes"
	parent.add_child(root)
	root.global_position = Vector3(world_position.x, world_position.y + 0.075, world_position.z)
	var tween := parent.create_tween()
	tween.set_parallel(true)
	for index in range(count):
		var angle := TAU * float(index) / float(maxi(count, 1))
		var spoke := Factory.box("Crack", color, Vector3(0.075, 0.025, radius * 0.76), Vector3(0.0, 0.0, -radius * 0.40))
		spoke.rotation.y = angle
		spoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spoke.material_override = _fx_material(color)
		root.add_child(spoke)
		tween.tween_property(spoke, "scale", Vector3(1.0, 1.0, 1.0), 0.16).from(Vector3(0.08, 1.0, 0.08)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spoke.material_override, "albedo_color", Color(color.r, color.g, color.b, 0.0), 0.52).from(Color(color.r, color.g, color.b, 0.75)).set_delay(0.15)
	tween.finished.connect(root.queue_free)


static func status_aura(actor: Node3D, color: Color, duration: float, radius: float = 0.78) -> void:
	if not is_instance_valid(actor):
		return
	var root := Node3D.new()
	root.name = "SkillStatusAura"
	root.position.y = 0.10
	actor.add_child(root)
	var torus := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius
	mesh.outer_radius = radius + 0.075
	mesh.rings = 15
	mesh.ring_segments = 5
	torus.mesh = mesh
	torus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	torus.material_override = _fx_material(color)
	root.add_child(torus)
	for index in range(4):
		var angle := TAU * float(index) / 4.0
		var mote := Factory.sphere("StatusMote", color, Vector3.ONE * 0.10, Vector3(cos(angle) * radius, 0.36 + 0.16 * float(index % 2), sin(angle) * radius), 6, 3)
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mote.material_override = _fx_material(color)
		root.add_child(mote)
	var tween := actor.create_tween()
	tween.set_loops(maxi(int(ceil(duration / 0.85)), 1))
	tween.tween_property(root, "rotation:y", TAU, 0.85).from(0.0)
	tween.finished.connect(root.queue_free)


static func _fx_material(color: Color) -> StandardMaterial3D:
	var mat := Factory.material(Color(color.r, color.g, color.b, 0.76), 0.38, Color(color.r, color.g, color.b, 1.0))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_energy_multiplier = 1.45
	return mat
