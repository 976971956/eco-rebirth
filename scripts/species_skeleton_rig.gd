class_name SpeciesSkeletonRig
extends RefCounted

const RIG_NAME := "SpeciesSkeleton3D"
const RIGGED_SPECIES := ["rabbit", "wolf"]
const ANIMATION_STATES := ["idle", "run", "attack", "hit"]
const DRIVEN_BONES := ["Spine", "Leg_LF", "Leg_RF", "Leg_LH", "Leg_RH", "Ear_L", "Ear_R", "Tail"]
const ATTACK_DURATION := 0.26
const HIT_DURATION := 0.28


static func supports(species_id: String) -> bool:
	return species_id in RIGGED_SPECIES


static func upgrade(model: Node3D, species_id: String) -> Skeleton3D:
	if model == null or not supports(species_id):
		return null
	var existing := _find_skeleton(model)
	if existing != null:
		return existing
	var pivots: Array[Node3D] = []
	_collect_motion_pivots(model, pivots)
	if pivots.is_empty():
		return null

	var skeleton := Skeleton3D.new()
	skeleton.name = RIG_NAME
	model.add_child(skeleton)
	skeleton.add_bone("Root")
	skeleton.set_bone_rest(0, Transform3D.IDENTITY)

	for pivot in pivots:
		if not is_instance_valid(pivot) or pivot == model:
			continue
		var bone_name := _bone_name_for_pivot(str(pivot.name))
		if bone_name == "" or skeleton.find_bone(bone_name) >= 0:
			continue
		var rest_transform := _relative_transform(pivot, model)
		var bone_index := skeleton.get_bone_count()
		skeleton.add_bone(bone_name)
		skeleton.set_bone_parent(bone_index, 0)
		skeleton.set_bone_rest(bone_index, rest_transform)

		var attachment := BoneAttachment3D.new()
		attachment.name = str(pivot.name)
		skeleton.add_child(attachment)
		attachment.bone_name = bone_name
		attachment.set_meta("species_bone", bone_name)

		if pivot is MeshInstance3D:
			pivot.owner = null
			pivot.name = "%s_Mesh" % bone_name
			pivot.reparent(attachment, false)
			pivot.transform = Transform3D.IDENTITY
		else:
			for child in pivot.get_children():
				if child is Node3D:
					child.owner = null
					child.reparent(attachment, false)
			pivot.free()

	skeleton.reset_bone_poses()
	skeleton.set_meta("species_id", species_id)
	skeleton.set_meta("rig_version", 1)
	skeleton.set_meta("animation_states", ANIMATION_STATES.duplicate())
	model.set_meta("uses_skeleton_rig", true)
	return skeleton


static func resolve_state(gait_blend: float, attack_remaining: float, hit_remaining: float) -> String:
	if hit_remaining > 0.0:
		return "hit"
	if attack_remaining > 0.0:
		return "attack"
	return "run" if gait_blend > 0.10 else "idle"


static func apply_pose(
	skeleton: Skeleton3D,
	state: String,
	motion_time: float,
	stride_amplitude: float,
	speed_ratio: float,
	attack_progress: float,
	hit_progress: float,
	actor_phase: float,
	delta: float
) -> void:
	if skeleton == null:
		return
	var targets := pose_targets(
		state,
		motion_time,
		stride_amplitude,
		speed_ratio,
		attack_progress,
		hit_progress,
		actor_phase
	)
	var blend_speed := 24.0 if state in ["attack", "hit"] else 15.0
	var blend_weight := 1.0 - exp(-maxf(delta, 0.001) * blend_speed)
	for bone_name in DRIVEN_BONES:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index < 0:
			continue
		var target_euler: Vector3 = targets.get(bone_name, Vector3.ZERO)
		var target_rotation := Quaternion.from_euler(target_euler)
		var current_rotation := skeleton.get_bone_pose_rotation(bone_index)
		skeleton.set_bone_pose_rotation(bone_index, current_rotation.slerp(target_rotation, blend_weight))


static func pose_targets(
	state: String,
	motion_time: float,
	stride_amplitude: float,
	speed_ratio: float,
	attack_progress: float,
	hit_progress: float,
	actor_phase: float
) -> Dictionary:
	var targets := {}
	var ear_listen := sin(motion_time * 0.31 + actor_phase) * 0.055
	targets["Ear_L"] = Vector3(ear_listen, 0.0, -0.018)
	targets["Ear_R"] = Vector3(-ear_listen * 0.72, 0.0, 0.018)
	targets["Tail"] = Vector3(0.0, sin(motion_time * 0.72 + actor_phase) * 0.065, 0.0)
	targets["Spine"] = Vector3(sin(motion_time * 1.32) * 0.012, 0.0, sin(motion_time * 0.66) * 0.010)
	for bone_name in ["Leg_LF", "Leg_RF", "Leg_LH", "Leg_RH"]:
		targets[bone_name] = Vector3.ZERO

	match state:
		"run":
			var run_strength := clampf(speed_ratio, 0.0, 1.35)
			var phases := {"Leg_LF": 0.0, "Leg_RF": PI, "Leg_LH": PI, "Leg_RH": 0.0}
			var stride_scales := {"Leg_LF": 0.86, "Leg_RF": 0.86, "Leg_LH": 1.15, "Leg_RH": 1.15}
			for bone_name in phases:
				var swing := sin(motion_time + float(phases[bone_name])) * stride_amplitude * float(stride_scales[bone_name])
				targets[bone_name] = Vector3(swing, 0.0, 0.0)
			targets["Spine"] = Vector3(
				sin(motion_time * 2.0 + 0.65) * 0.030 * run_strength,
				0.0,
				sin(motion_time) * 0.026 * run_strength
			)
			targets["Ear_L"] = Vector3(0.11 * minf(run_strength, 1.0) + ear_listen, 0.0, -0.025)
			targets["Ear_R"] = Vector3(0.11 * minf(run_strength, 1.0) - ear_listen * 0.72, 0.0, 0.025)
			targets["Tail"] = Vector3(0.03, sin(motion_time * 1.15 + actor_phase) * 0.12, 0.0)
		"attack":
			var attack_curve := sin(clampf(attack_progress, 0.0, 1.0) * PI)
			targets["Spine"] = Vector3(-0.18 * attack_curve, 0.0, 0.0)
			targets["Leg_LF"] = Vector3(-0.38 * attack_curve, 0.0, -0.05 * attack_curve)
			targets["Leg_RF"] = Vector3(-0.38 * attack_curve, 0.0, 0.05 * attack_curve)
			targets["Leg_LH"] = Vector3(0.22 * attack_curve, 0.0, 0.0)
			targets["Leg_RH"] = Vector3(0.22 * attack_curve, 0.0, 0.0)
			targets["Ear_L"] = Vector3(0.24 * attack_curve, 0.0, -0.05)
			targets["Ear_R"] = Vector3(0.24 * attack_curve, 0.0, 0.05)
			targets["Tail"] = Vector3(-0.06 * attack_curve, -0.18 * attack_curve, 0.0)
		"hit":
			var hit_curve := sin(clampf(hit_progress, 0.0, 1.0) * PI)
			var recoil_side := -1.0 if sin(actor_phase * 1.73) < 0.0 else 1.0
			targets["Spine"] = Vector3(0.11 * hit_curve, 0.0, recoil_side * 0.22 * hit_curve)
			targets["Leg_LF"] = Vector3(0.20 * hit_curve, 0.0, -0.08 * recoil_side)
			targets["Leg_RF"] = Vector3(-0.16 * hit_curve, 0.0, 0.08 * recoil_side)
			targets["Leg_LH"] = Vector3(-0.12 * hit_curve, 0.0, 0.0)
			targets["Leg_RH"] = Vector3(0.12 * hit_curve, 0.0, 0.0)
			targets["Ear_L"] = Vector3(0.34 * hit_curve, 0.0, -0.09)
			targets["Ear_R"] = Vector3(0.34 * hit_curve, 0.0, 0.09)
			targets["Tail"] = Vector3(0.08 * hit_curve, recoil_side * 0.16 * hit_curve, 0.0)
	return targets


static func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D and str(root.name) == RIG_NAME:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


static func _collect_motion_pivots(root: Node, output: Array[Node3D]) -> void:
	for child in root.get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		if _bone_name_for_pivot(str(node.name)) != "":
			output.append(node)
		else:
			_collect_motion_pivots(node, output)


static func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


static func _bone_name_for_pivot(node_name: String) -> String:
	if node_name == "SpinePivot":
		return "Spine"
	if node_name == "TailPivot":
		return "Tail"
	if node_name.begins_with("LegPivot_"):
		return "Leg_%s" % node_name.trim_prefix("LegPivot_")
	if node_name.begins_with("EarPivot_"):
		return "Ear_%s" % node_name.trim_prefix("EarPivot_")
	return ""
