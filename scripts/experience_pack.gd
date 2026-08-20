class_name ExperiencePack
extends Node3D

const Factory = preload("res://scripts/low_poly_factory.gd")

const TIER_COMMON := "common"
const TIER_RICH := "rich"
const TIER_LEVEL := "level"

var tier: String = TIER_COMMON
var experience_amount: int = 12
var event_sequence: int = -1
var region_index: int = -1
var active: bool = true
var visual_root: Node3D
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
		_build_visual()
	set_process(true)


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
	visual_root.rotation.y = animation_phase
	visual_root.position.y = sin(animation_phase * 1.55) * 0.16
	var pulse := 1.0 + sin(animation_phase * 2.1) * (0.08 if is_level_pack() else 0.045)
	visual_root.scale = Vector3.ONE * pulse


func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "ExperiencePackVisual"
	add_child(visual_root)
	var color := tier_color(tier)
	var scale_value := 0.62 if tier == TIER_COMMON else (0.82 if tier == TIER_RICH else 1.05)
	var core := Factory.sphere("ExperienceCore", color, Vector3.ONE * scale_value, Vector3(0.0, 0.95, 0.0), 10, 7)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core_material := Factory.material(Color(color, 0.90), 0.24, color * 0.72)
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.emission_enabled = true
	core_material.emission = color
	core_material.emission_energy_multiplier = 1.65 if is_level_pack() else 1.05
	core.material_override = core_material
	visual_root.add_child(core)
	var ring_count := 3 if is_level_pack() else 2
	for ring_index in range(ring_count):
		var ring := MeshInstance3D.new()
		ring.name = "ExperienceOrbit"
		var torus := TorusMesh.new()
		var orbit_radius := scale_value * (1.22 + float(ring_index) * 0.22)
		torus.inner_radius = orbit_radius
		torus.outer_radius = orbit_radius + 0.075
		torus.rings = 18
		torus.ring_segments = 5
		ring.mesh = torus
		ring.position = Vector3(0.0, 0.95, 0.0)
		ring.rotation = Vector3(0.36 + float(ring_index) * 0.48, float(ring_index) * 0.76, 0.18)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.material_override = core_material
		visual_root.add_child(ring)
	var ground_ring := Factory.disc("ExperienceSignal", Color(color, 0.38), scale_value * 1.75, 0.035, Vector3(0.0, 0.08, 0.0), 18)
	ground_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ground_material := Factory.material(Color(color, 0.38), 0.62, color.darkened(0.20))
	ground_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ground_material.emission_enabled = true
	ground_material.emission = color.darkened(0.10)
	ground_ring.material_override = ground_material
	visual_root.add_child(ground_ring)
	var label := Label3D.new()
	label.name = "ExperienceLabel"
	label.text = "升 1 级" if is_level_pack() else "+%d 经验" % experience_amount
	label.position = Vector3(0.0, 2.05 + scale_value * 0.25, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 34 if is_level_pack() else 29
	label.outline_size = 8
	label.modulate = color.lightened(0.16)
	label.outline_modulate = Color(0.015, 0.035, 0.03, 0.94)
	visual_root.add_child(label)
