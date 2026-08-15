class_name SpeciesFlightRig
extends RefCounted

const RIG_NAME := "SpeciesFlightSkeleton3D"
const RIGGED_SPECIES := ["owl", "eagle"]
const ANIMATION_STATES := ["glide", "flap", "dive", "hit"]
const SKILL_SOCKET_NAMES := ["SkillSocket_Beak", "SkillSocket_Wing_L", "SkillSocket_Wing_R"]
const DRIVEN_BONES := ["Body", "Head", "Wing_L", "Wing_R", "WingTip_L", "WingTip_R", "Tail", "Talon_L", "Talon_R"]
const DIVE_DURATION := 0.52
const HIT_DURATION := 0.32


static func supports(species_id: String) -> bool:
	return species_id in RIGGED_SPECIES


static func upgrade(model: Node3D, species_id: String) -> Skeleton3D:
	if model == null or not supports(species_id):
		return null
	var existing := _find_skeleton(model)
	if existing != null:
		existing.set_meta("species_id", species_id)
		existing.set_meta("rig_version", 2)
		existing.set_meta("flight_profile", "nocturnal_flapper" if species_id == "owl" else "diurnal_soarer")
		existing.set_meta("animation_states", ["idle", "locomotion", "sprint", "attack", "skill", "hit", "eat", "death", "glide", "flap", "dive", "land"])
		model.set_meta("uses_flight_skeleton_rig", true)
		return existing
	var original_children := model.get_children()
	var wing_pivots: Array[Node3D] = []
	var tail_pivot: Node3D
	var talons: Array[Node3D] = []
	var body_parts: Array[Node3D] = []
	var head_parts: Array[Node3D] = []
	for child in original_children:
		if not child is Node3D:
			continue
		var visual_node := child as Node3D
		var node_name := str(visual_node.name)
		if node_name.begins_with("WingPivot_"):
			wing_pivots.append(visual_node)
		elif node_name == "TailPivot":
			tail_pivot = visual_node
		elif node_name.begins_with("Talon"):
			talons.append(visual_node)
		elif _is_head_part(node_name):
			head_parts.append(visual_node)
		else:
			body_parts.append(visual_node)
	if wing_pivots.size() != 2 or tail_pivot == null:
		return null

	var skeleton := Skeleton3D.new()
	skeleton.name = RIG_NAME
	model.add_child(skeleton)
	skeleton.add_bone("Root")
	skeleton.set_bone_rest(0, Transform3D.IDENTITY)
	_add_bone(skeleton, "Body", "Root", Transform3D.IDENTITY)
	_add_bone(skeleton, "Head", "Body", Transform3D(Basis.IDENTITY, Vector3(0.0, 1.62, -1.42)))
	var attachments := {
		"Body": _add_attachment(skeleton, "BodyAttachment", "Body"),
		"Head": _add_attachment(skeleton, "HeadAttachment", "Head"),
	}

	for wing_pivot in wing_pivots:
		var side_suffix := "L" if wing_pivot.position.x < 0.0 else "R"
		var bone_name := "Wing_%s" % side_suffix
		_add_bone(skeleton, bone_name, "Body", _relative_transform(wing_pivot, model))
		var attachment := _add_attachment(skeleton, "WingPivot_%s" % side_suffix, bone_name)
		attachments[bone_name] = attachment
		_move_pivot_children(wing_pivot, model, skeleton, attachment, bone_name)

	_add_bone(skeleton, "Tail", "Body", _relative_transform(tail_pivot, model))
	attachments["Tail"] = _add_attachment(skeleton, "TailPivot", "Tail")
	_move_pivot_children(tail_pivot, model, skeleton, attachments["Tail"], "Tail")

	for talon in talons:
		var side_suffix := "L" if talon.position.x < 0.0 else "R"
		var bone_name := "Talon_%s" % side_suffix
		_add_bone(skeleton, bone_name, "Body", _relative_transform(talon, model))
		var attachment := _add_attachment(skeleton, "TalonAttachment_%s" % side_suffix, bone_name)
		attachments[bone_name] = attachment
		_move_node_to_attachment(talon, model, skeleton, attachment, bone_name)

	for body_part in body_parts:
		_move_node_to_attachment(body_part, model, skeleton, attachments["Body"], "Body")
	for head_part in head_parts:
		_move_node_to_attachment(head_part, model, skeleton, attachments["Head"], "Head")
	_add_skill_sockets(attachments)

	skeleton.reset_bone_poses()
	skeleton.set_meta("species_id", species_id)
	skeleton.set_meta("rig_version", 1)
	skeleton.set_meta("flight_profile", "diurnal_soarer")
	skeleton.set_meta("animation_states", ANIMATION_STATES.duplicate())
	model.set_meta("uses_flight_skeleton_rig", true)
	return skeleton


static func resolve_state(
	gait_blend: float,
	dive_remaining: float,
	attack_remaining: float,
	hit_remaining: float,
	airborne: bool
) -> String:
	if hit_remaining > 0.0:
		return "hit"
	if dive_remaining > 0.0 or attack_remaining > 0.0:
		return "dive"
	if gait_blend > 0.24 or not airborne:
		return "flap"
	return "glide"


static func apply_pose(
	skeleton: Skeleton3D,
	state: String,
	motion_time: float,
	speed_ratio: float,
	dive_progress: float,
	hit_progress: float,
	actor_phase: float,
	delta: float
) -> void:
	if skeleton == null:
		return
	var targets := pose_targets(state, motion_time, speed_ratio, dive_progress, hit_progress, actor_phase)
	var blend_speed := 26.0 if state in ["dive", "hit"] else 14.0
	var blend_weight := 1.0 - exp(-maxf(delta, 0.001) * blend_speed)
	for bone_name in DRIVEN_BONES:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index < 0:
			continue
		var target_rotation := Quaternion.from_euler(targets.get(bone_name, Vector3.ZERO))
		var current_rotation := skeleton.get_bone_pose_rotation(bone_index)
		skeleton.set_bone_pose_rotation(bone_index, current_rotation.slerp(target_rotation, blend_weight))


static func pose_targets(
	state: String,
	motion_time: float,
	speed_ratio: float,
	dive_progress: float,
	hit_progress: float,
	actor_phase: float
) -> Dictionary:
	var targets := {
		"Body": Vector3.ZERO,
		"Head": Vector3.ZERO,
		"Wing_L": Vector3(-0.04, 0.0, 0.08),
		"Wing_R": Vector3(-0.04, 0.0, -0.08),
		"WingTip_L": Vector3(-0.02, 0.0, 0.04),
		"WingTip_R": Vector3(-0.02, 0.0, -0.04),
		"Tail": Vector3(0.02, sin(motion_time * 0.42 + actor_phase) * 0.045, 0.0),
		"Talon_L": Vector3(0.18, 0.0, -0.05),
		"Talon_R": Vector3(0.18, 0.0, 0.05),
	}
	match state:
		"flap":
			var flap_strength := 0.42 + minf(speed_ratio, 1.2) * 0.18
			var flap := sin(motion_time * 1.65) * flap_strength
			targets["Wing_L"] = Vector3(-0.09, 0.0, flap)
			targets["Wing_R"] = Vector3(-0.09, 0.0, -flap)
			targets["WingTip_L"] = Vector3(-0.06, 0.0, flap * 0.48)
			targets["WingTip_R"] = Vector3(-0.06, 0.0, -flap * 0.48)
			targets["Body"] = Vector3(sin(motion_time * 3.3 + 0.6) * 0.035, 0.0, 0.0)
			targets["Head"] = Vector3(-targets["Body"].x * 0.72, 0.0, 0.0)
		"dive":
			var dive_curve := sin(clampf(dive_progress, 0.0, 1.0) * PI)
			targets["Body"] = Vector3(-0.16 * dive_curve, 0.0, 0.0)
			targets["Head"] = Vector3(0.08 * dive_curve, 0.0, 0.0)
			targets["Wing_L"] = Vector3(-0.18 * dive_curve, 0.38 * dive_curve, 0.22 * dive_curve)
			targets["Wing_R"] = Vector3(-0.18 * dive_curve, -0.38 * dive_curve, -0.22 * dive_curve)
			targets["WingTip_L"] = Vector3(-0.10 * dive_curve, 0.26 * dive_curve, 0.20 * dive_curve)
			targets["WingTip_R"] = Vector3(-0.10 * dive_curve, -0.26 * dive_curve, -0.20 * dive_curve)
			targets["Tail"] = Vector3(0.16 * dive_curve, 0.0, 0.0)
			targets["Talon_L"] = Vector3(-0.42 * dive_curve, 0.0, -0.12)
			targets["Talon_R"] = Vector3(-0.42 * dive_curve, 0.0, 0.12)
		"hit":
			var hit_curve := sin(clampf(hit_progress, 0.0, 1.0) * PI)
			var side := -1.0 if sin(actor_phase * 1.71) < 0.0 else 1.0
			targets["Body"] = Vector3(0.08 * hit_curve, 0.0, side * 0.18 * hit_curve)
			targets["Head"] = Vector3(0.12 * hit_curve, 0.0, -side * 0.09 * hit_curve)
			targets["Wing_L"] = Vector3(0.12 * hit_curve, 0.0, 0.28 * hit_curve * side)
			targets["Wing_R"] = Vector3(-0.08 * hit_curve, 0.0, 0.16 * hit_curve * side)
			targets["WingTip_L"] = Vector3(0.08 * hit_curve, 0.0, 0.22 * hit_curve * side)
			targets["WingTip_R"] = Vector3(-0.05 * hit_curve, 0.0, 0.12 * hit_curve * side)
			targets["Tail"] = Vector3(-0.10 * hit_curve, side * 0.16 * hit_curve, 0.0)
	return targets


static func find_socket(model: Node, socket_name: String) -> Node3D:
	if model == null or not socket_name in SKILL_SOCKET_NAMES:
		return null
	return _find_node_named(model, socket_name) as Node3D


static func _is_head_part(node_name: String) -> bool:
	for prefix in ["GoldenNape", "Head", "HookedBeak", "EyeSocket", "Iris", "Pupil", "EyeCatchlight"]:
		if node_name.begins_with(prefix):
			return true
	return false


static func _add_bone(skeleton: Skeleton3D, bone_name: String, parent_name: String, global_rest: Transform3D) -> int:
	var parent_index := skeleton.find_bone(parent_name)
	if parent_index < 0:
		parent_index = 0
	var local_rest := skeleton.get_bone_global_rest(parent_index).affine_inverse() * global_rest
	var bone_index := skeleton.get_bone_count()
	skeleton.add_bone(bone_name)
	skeleton.set_bone_parent(bone_index, parent_index)
	skeleton.set_bone_rest(bone_index, local_rest)
	return bone_index


static func _add_attachment(skeleton: Skeleton3D, attachment_name: String, bone_name: String) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = attachment_name
	skeleton.add_child(attachment)
	attachment.bone_name = bone_name
	attachment.set_meta("species_bone", bone_name)
	return attachment


static func _move_pivot_children(
	pivot: Node3D,
	model: Node3D,
	skeleton: Skeleton3D,
	attachment: BoneAttachment3D,
	bone_name: String
) -> void:
	for child in pivot.get_children():
		if child is Node3D:
			_move_node_to_attachment(child as Node3D, model, skeleton, attachment, bone_name)
	pivot.free()


static func _move_node_to_attachment(
	node: Node3D,
	model: Node3D,
	skeleton: Skeleton3D,
	attachment: BoneAttachment3D,
	bone_name: String
) -> void:
	var model_transform := _relative_transform(node, model)
	var bone_index := skeleton.find_bone(bone_name)
	var bone_rest := skeleton.get_bone_global_rest(bone_index) if bone_index >= 0 else Transform3D.IDENTITY
	node.owner = null
	node.reparent(attachment, false)
	node.transform = bone_rest.affine_inverse() * model_transform


static func _add_skill_sockets(attachments: Dictionary) -> void:
	var beak := Node3D.new()
	beak.name = "SkillSocket_Beak"
	attachments["Head"].add_child(beak)
	beak.position = Vector3(0.0, -0.07, -0.82)
	beak.set_meta("socket_role", "dive_strike_origin")
	for side_suffix in ["L", "R"]:
		var side := -1.0 if side_suffix == "L" else 1.0
		var wing_socket := Node3D.new()
		wing_socket.name = "SkillSocket_Wing_%s" % side_suffix
		attachments["Wing_%s" % side_suffix].add_child(wing_socket)
		wing_socket.position = Vector3(side * 1.42, -0.05, 0.66)
		wing_socket.set_meta("socket_role", "wing_wake_origin")


static func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


static func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		var skeleton := root as Skeleton3D
		var imported_wrapper := skeleton.get_parent()
		if str(skeleton.name) == RIG_NAME or (imported_wrapper != null and str(imported_wrapper.name) == RIG_NAME):
			return skeleton
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


static func _find_node_named(root: Node, node_name: String) -> Node:
	if str(root.name) == node_name:
		return root
	for child in root.get_children():
		var found := _find_node_named(child, node_name)
		if found != null:
			return found
	return null
