class_name ExperiencePack
extends Node3D

const Factory = preload("res://scripts/low_poly_factory.gd")

const TIER_COMMON := "common"
const TIER_RICH := "rich"
const TIER_LEVEL := "level"

static var shared_meshes: Dictionary = {}
static var shared_materials: Dictionary = {}

var tier: String = TIER_COMMON
var experience_amount: int = 12
var event_sequence: int = -1
var region_index: int = -1
var active: bool = true
var visual_root: Node3D
var crystal_root: Node3D
var orbit_root: Node3D
var ground_signal: MeshInstance3D
var base_height: float = 0.0
var animation_phase: float = 0.0


static func tier_roll(random_unit: float, level: int) -> String:
	var safe_roll := clampf(random_unit, 0.0, 0.999999)
	var level_pack_chance := 0.035 + float(clampi(level, 1, 10) - 1) * 0.0045
	var rich_chance := 0.28 + float(clampi(level, 1, 10) - 1) * 0.006
	if safe_roll < level_pack_chance:
		return TIER_LEVEL
	if safe_roll < level_pack_chance + rich_chance:
		return TIER_RICH
	return TIER_COMMON


static func rolled_experience(tier_id: String, level: int, random_unit: float) -> int:
	var safe_level := clampi(level, 1, 10)
	var roll := clampf(random_unit, 0.0, 1.0)
	if tier_id == TIER_RICH:
		return roundi(24.0 + float(safe_level) * 1.4 + roll * (13.0 + float(safe_level) * 0.8))
	if tier_id == TIER_LEVEL:
		return 0
	return roundi(8.0 + float(safe_level) * 0.55 + roll * (8.0 + float(safe_level) * 0.35))


static func absorption_seconds(experience_value: int, grants_level: bool = false) -> float:
	if grants_level:
		return 4.8
	return clampf(0.72 + float(maxi(experience_value, 1)) * 0.052, 1.0, 3.65)


static func tier_title(tier_id: String) -> String:
	match tier_id:
		TIER_RICH:
			return "丰厚经验包"
		TIER_LEVEL:
			return "跃迁经验包"
		_:
			return "经验包"


static func tier_color(tier_id: String) -> Color:
	match tier_id:
		TIER_RICH:
			return Color("#bd83ff")
		TIER_LEVEL:
			return Color("#ffd65a")
		_:
			return Color("#66e6c0")


func setup(tier_id: String, amount: int, sequence: int, cluster_index: int, enable_visuals: bool = true, phase: float = 0.0) -> void:
	tier = tier_id if tier_id in [TIER_COMMON, TIER_RICH, TIER_LEVEL] else TIER_COMMON
	experience_amount = maxi(amount, 0)
	event_sequence = sequence
	region_index = cluster_index
	animation_phase = phase
	base_height = position.y
	name = "ExperiencePack_%d_%d_%s" % [event_sequence, region_index, tier]
	if enable_visuals:
		ensure_visual()
	set_process(true)


func ensure_visual() -> void:
	if not active or is_instance_valid(visual_root):
		return
	_build_visual()


func is_level_pack() -> bool:
	return tier == TIER_LEVEL


func display_name() -> String:
	return tier_title(tier)


func reward_preview(remaining_to_level: int) -> int:
	return maxi(remaining_to_level, 1) if is_level_pack() else experience_amount


func absorb_duration(remaining_to_level: int) -> float:
	return absorption_seconds(reward_preview(remaining_to_level), is_level_pack())


func claim() -> bool:
	if not active:
		return false
	active = false
	visible = false
	set_process(false)
	queue_free.call_deferred()
	return true


func retire() -> void:
	if not active:
		return
	active = false
	visible = false
	set_process(false)
	queue_free.call_deferred()


func _process(delta: float) -> void:
	if not active or not is_instance_valid(visual_root):
		return
	animation_phase = fmod(animation_phase + delta * (1.25 if is_level_pack() else 1.75), TAU)
	visual_root.position.y = sin(animation_phase * 1.55) * 0.16
	var pulse := 1.0 + sin(animation_phase * 2.1) * (0.08 if is_level_pack() else 0.045)
	visual_root.scale = Vector3.ONE * pulse
	if is_instance_valid(crystal_root):
		crystal_root.rotation.y = animation_phase * 0.82
		crystal_root.rotation.z = sin(animation_phase * 0.72) * 0.08
	if is_instance_valid(orbit_root):
		orbit_root.rotation.y = -animation_phase * 1.16
		orbit_root.rotation.z = sin(animation_phase * 0.94) * 0.10
	if is_instance_valid(ground_signal):
		var ground_pulse := 1.0 + sin(animation_phase * 2.1) * 0.10
		ground_signal.scale = Vector3(ground_pulse, 1.0, ground_pulse)


func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "ExperiencePackVisual"
	add_child(visual_root)
	var color := tier_color(tier)
	var scale_value := 0.56 if tier == TIER_COMMON else (0.72 if tier == TIER_RICH else 0.90)
	var visibility_distance := 76.0 if tier == TIER_COMMON else (92.0 if tier == TIER_RICH else 118.0)
	var crystal_material := _shared_material(tier, "crystal")
	var aura_material := _shared_material(tier, "aura")

	var aura := _visual_mesh("ExperienceEnergyAura", "sphere", Vector3(scale_value * 1.22, scale_value * 1.42, scale_value * 1.22), Vector3(0.0, 1.04, 0.0), aura_material)
	_configure_visual_instance(aura, visibility_distance)
	visual_root.add_child(aura)

	crystal_root = Node3D.new()
	crystal_root.name = "ExperienceCrystalShell"
	visual_root.add_child(crystal_root)
	var upper_crystal := _visual_mesh("ExperienceCrystalUpper", "cone", Vector3(scale_value * 0.58, scale_value * 1.12, scale_value * 0.58), Vector3(0.0, 1.20, 0.0), crystal_material)
	_configure_visual_instance(upper_crystal, visibility_distance)
	crystal_root.add_child(upper_crystal)
	var lower_crystal := _visual_mesh("ExperienceCrystalLower", "cone", Vector3(scale_value * 0.58, scale_value * 0.82, scale_value * 0.58), Vector3(0.0, 0.68, 0.0), crystal_material)
	lower_crystal.rotation.z = PI
	_configure_visual_instance(lower_crystal, visibility_distance)
	crystal_root.add_child(lower_crystal)
	var inner_core := _visual_mesh("ExperienceCrystalCore", "sphere", Vector3.ONE * scale_value * 0.25, Vector3(0.0, 1.02, 0.0), _shared_material(tier, "core"))
	_configure_visual_instance(inner_core, visibility_distance)
	crystal_root.add_child(inner_core)

	orbit_root = Node3D.new()
	orbit_root.name = "ExperienceOrbitRig"
	visual_root.add_child(orbit_root)
	var ring_count := 3 if is_level_pack() else 2
	for ring_index in range(ring_count):
		var orbit_radius := scale_value * (1.20 + float(ring_index) * 0.22)
		var ring := _visual_mesh("ExperienceOrbit_%d" % ring_index, "torus", Vector3.ONE * orbit_radius, Vector3(0.0, 1.02, 0.0), aura_material)
		ring.rotation = Vector3(0.36 + float(ring_index) * 0.48, float(ring_index) * 0.76, 0.18)
		_configure_visual_instance(ring, visibility_distance)
		orbit_root.add_child(ring)
	var shard_count := 4 if is_level_pack() else (3 if tier == TIER_RICH else 2)
	for shard_index in range(shard_count):
		var angle := TAU * float(shard_index) / float(shard_count)
		var shard := _visual_mesh("ExperienceOrbitShard_%d" % shard_index, "box", Vector3(scale_value * 0.12, scale_value * 0.34, scale_value * 0.12), Vector3(cos(angle) * scale_value * 1.55, 1.02 + sin(angle * 2.0) * scale_value * 0.24, sin(angle) * scale_value * 1.55), crystal_material)
		shard.rotation = Vector3(0.42, -angle, 0.68)
		_configure_visual_instance(shard, visibility_distance)
		orbit_root.add_child(shard)

	ground_signal = _visual_mesh("ExperienceSignalGlyph", "disc", Vector3(scale_value * 1.78, 0.035, scale_value * 1.78), Vector3(0.0, 0.08, 0.0), _shared_material(tier, "ground"))
	_configure_visual_instance(ground_signal, visibility_distance)
	visual_root.add_child(ground_signal)
	var pedestal := _visual_mesh("ExperienceSignalPedestal", "pedestal", Vector3(scale_value * 0.92, 0.10, scale_value * 0.92), Vector3(0.0, 0.10, 0.0), _shared_material(tier, "pedestal"))
	_configure_visual_instance(pedestal, visibility_distance)
	visual_root.add_child(pedestal)

	var label := Label3D.new()
	label.name = "ExperienceLabel"
	label.text = "升 1 级" if is_level_pack() else "+%d 经验" % experience_amount
	label.position = Vector3(0.0, 2.00 + scale_value * 0.32, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 34 if is_level_pack() else 29
	label.outline_size = 8
	label.modulate = color.lightened(0.16)
	label.outline_modulate = Color(0.015, 0.035, 0.03, 0.94)
	label.visibility_range_end = 54.0 if is_level_pack() else 42.0
	visual_root.add_child(label)


func _configure_visual_instance(instance: GeometryInstance3D, visibility_distance: float) -> void:
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = visibility_distance


static func _visual_mesh(node_name: String, mesh_key: String, scale_value: Vector3, position_value: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = _shared_mesh(mesh_key)
	instance.scale = scale_value
	instance.position = position_value
	instance.material_override = material
	return instance


static func _shared_mesh(mesh_key: String) -> Mesh:
	if shared_meshes.has(mesh_key):
		return shared_meshes[mesh_key]
	var mesh: Mesh
	match mesh_key:
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 8
			sphere.rings = 5
			mesh = sphere
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 1.0
			cone.height = 1.0
			cone.radial_segments = 6
			cone.rings = 1
			mesh = cone
		"torus":
			var torus := TorusMesh.new()
			torus.inner_radius = 0.92
			torus.outer_radius = 1.0
			torus.rings = 14
			torus.ring_segments = 4
			mesh = torus
		"box":
			var box := BoxMesh.new()
			box.size = Vector3.ONE
			mesh = box
		"pedestal":
			var pedestal := CylinderMesh.new()
			pedestal.top_radius = 1.0
			pedestal.bottom_radius = 1.0
			pedestal.height = 1.0
			pedestal.radial_segments = 10
			pedestal.rings = 1
			mesh = pedestal
		_:
			var disc := CylinderMesh.new()
			disc.top_radius = 1.0
			disc.bottom_radius = 1.0
			disc.height = 1.0
			disc.radial_segments = 18
			disc.rings = 1
			mesh = disc
	shared_meshes[mesh_key] = mesh
	return mesh


static func _shared_material(tier_id: String, role: String) -> StandardMaterial3D:
	var cache_key := "%s:%s" % [tier_id, role]
	if shared_materials.has(cache_key):
		return shared_materials[cache_key]
	var color := tier_color(tier_id)
	var material: StandardMaterial3D
	match role:
		"aura":
			material = Factory.material(Color(color, 0.18), 0.30, color.darkened(0.12))
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.emission_enabled = true
			material.emission = color.darkened(0.10)
			material.emission_energy_multiplier = 0.82
		"core":
			material = Factory.material(color.lightened(0.42), 0.18, color.lightened(0.18))
		"ground":
			material = Factory.material(Color(color, 0.38), 0.62, color.darkened(0.20))
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.emission_enabled = true
			material.emission = color.darkened(0.10)
		"pedestal":
			material = Factory.material(color.darkened(0.34), 0.42, color.darkened(0.22))
		_:
			material = Factory.material(color.lightened(0.08), 0.20, color)
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = 0.92 if tier_id == TIER_LEVEL else (0.76 if tier_id == TIER_RICH else 0.62)
	shared_materials[cache_key] = material
	return material
