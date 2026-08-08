class_name EcoSkillProjectile
extends Node3D

const Factory = preload("res://scripts/low_poly_factory.gd")
const SkillVFX = preload("res://scripts/skill_vfx.gd")

var source: Node
var target: Node3D
var damage: float = 0.0
var projectile_color := Color("#d7f07a")
var travel_speed: float = 14.0
var slow_multiplier: float = 0.82
var slow_duration: float = 2.4
var scent_duration: float = 5.0
var lifetime: float = 2.2
var spin_time: float = 0.0


func setup(
	new_source: Node,
	new_target: Node3D,
	start_position: Vector3,
	damage_value: float,
	color_value: Color
) -> void:
	source = new_source
	target = new_target
	damage = damage_value
	projectile_color = color_value
	global_position = start_position + Vector3.UP * 1.35
	_build_visual()


func _build_visual() -> void:
	var fruit := Factory.sphere("ThrownFruit", projectile_color, Vector3(0.34, 0.34, 0.34), Vector3.ZERO, 8, 5)
	fruit.material_override = Factory.material(projectile_color, 0.72, projectile_color.darkened(0.35))
	add_child(fruit)
	var leaf := Factory.cone("FruitLeaf", Color("#4f8d48"), 0.10, 0.30, Vector3(0.0, 0.28, 0.0), 6)
	leaf.rotation.z = 0.65
	add_child(leaf)


func _process(delta: float) -> void:
	lifetime -= delta
	spin_time += delta
	rotation = Vector3(spin_time * 5.4, spin_time * 7.2, spin_time * 3.7)
	if lifetime <= 0.0 or not is_instance_valid(source) or not is_instance_valid(target):
		queue_free()
		return
	var target_height := 0.75
	var target_data = target.get("data")
	if target_data is Dictionary:
		target_height += float(int(target_data.get("size", 2))) * 0.20
	var impact_position := target.global_position + Vector3.UP * target_height
	var offset := impact_position - global_position
	var travel := travel_speed * delta
	if offset.length() <= travel + 0.34:
		_impact(impact_position)
		return
	global_position += offset.normalized() * travel


func _impact(impact_position: Vector3) -> void:
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.call("take_damage", damage, source)
		if target.has_method("apply_slow"):
			target.call("apply_slow", slow_multiplier, slow_duration)
		if target.has_method("apply_scent_mark"):
			target.call("apply_scent_mark", scent_duration, source, projectile_color)
	SkillVFX.radial_burst(get_parent(), impact_position, projectile_color, 1.9, 10, 0.13, 0.38, 0.16)
	SkillVFX.ring(get_parent(), impact_position, projectile_color.lightened(0.18), 0.35, 1.8, 0.30)
	queue_free()
