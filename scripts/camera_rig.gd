class_name EcoCameraRig
extends Node3D

var target: Node3D
var camera: Camera3D
var desired_offset := Vector3(14.5, 18.0, 14.5)
var look_ahead := Vector3.ZERO


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.current = true
	camera.fov = 48.0
	camera.near = 0.2
	camera.far = 180.0
	add_child(camera)


func setup(follow_target: Node3D) -> void:
	target = follow_target
	if target is EcoActor:
		var size_level: int = int(target.data.get("size", 2))
		var horizontal := 10.8 + size_level * 0.72
		desired_offset = Vector3(horizontal, 13.8 + size_level * 1.0, horizontal)
	if target != null:
		global_position = target.global_position
	_orient_camera()


func _orient_camera() -> void:
	if camera == null:
		return
	camera.position = desired_offset
	# Keep one stable isometric heading. Both the rig and camera translate with the
	# player, so changing this rotation every frame makes the world appear to spin.
	camera.look_at(global_position + Vector3(0.0, 0.8, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var target_velocity := Vector3.ZERO
	if target is CharacterBody3D:
		target_velocity = target.velocity
	look_ahead = look_ahead.lerp(Vector3(target_velocity.x, 0.0, target_velocity.z) * 0.22, 1.0 - exp(-delta * 3.5))
	var focus := target.global_position + Vector3(0.0, 0.8, 0.0) + look_ahead
	global_position = global_position.lerp(focus, 1.0 - exp(-delta * 5.0))
	camera.position = desired_offset


func input_to_world(input_vector: Vector2) -> Vector3:
	if camera == null:
		return Vector3(input_vector.x, 0.0, input_vector.y).normalized()
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	return (right * input_vector.x + forward * -input_vector.y).normalized()
