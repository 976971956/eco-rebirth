class_name SpeciesCrocodileRig
extends RefCounted

const RIG_NAME := "SpeciesCrocodileSkeleton3D"
const RIGGED_SPECIES := ["snake", "crocodile"]
const ANIMATION_STATES := ["idle", "crawl", "swim", "attack", "roll", "hit"]
const SKILL_SOCKET_NAMES := ["SkillSocket_Jaw", "SkillSocket_TailTip"]
const SKIN_BONES := ["Body", "Neck", "Head", "Tail_Base", "Tail_Mid", "Tail_Tip"]
const DRIVEN_BONES := [
	"Body", "Neck", "Head", "Jaw", "Tail_Base", "Tail_Mid", "Tail_Tip",
	"Leg_LF", "Leg_RF", "Leg_LH", "Leg_RH",
]
const ATTACK_DURATION := 0.30
const ROLL_DURATION := 0.58
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
		existing.set_meta("skin_mode", "blender_weighted_long_body")
		existing.set_meta("locomotion_profile", "serpentine" if species_id == "snake" else "amphibious_sprawl")
		existing.set_meta("animation_states", ["idle", "locomotion", "sprint", "attack", "skill", "hit", "eat", "death", "swim"])
		model.set_meta("uses_crocodile_skeleton_rig", true)
		return existing
	var original_children := model.get_children()
	var organic_body: MeshInstance3D
	var leg_pivots: Array[Node3D] = []
	var detail_parts: Array[Node3D] = []
	for child in original_children:
		if not child is Node3D:
			continue
		var visual_node := child as Node3D
		var node_name := str(visual_node.name)
		if node_name == "CrocodileOrganicBody" and visual_node is MeshInstance3D:
			organic_body = visual_node as MeshInstance3D
		elif node_name.begins_with("LegPivot_"):
			leg_pivots.append(visual_node)
		else:
			detail_parts.append(visual_node)
	if organic_body == null or leg_pivots.size() != 4:
		return null

	var skeleton := Skeleton3D.new()
	skeleton.name = RIG_NAME
	model.add_child(skeleton)
	skeleton.add_bone("Root")
	skeleton.set_bone_rest(0, Transform3D.IDENTITY)
	var attachments := {}
	_add_bone(skeleton, "Body", "Root", Transform3D.IDENTITY)
	attachments["Body"] = _add_attachment(skeleton, "BodyAttachment", "Body")
	var chain_rests := {
		"Neck": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.71, -0.92)),
		"Head": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.62, -1.78)),
		"Jaw": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.50, -1.68)),
		"Tail_Base": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.69, 0.48)),
		"Tail_Mid": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.61, 1.10)),
		"Tail_Tip": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.55, 1.64)),
	}
	var parents := {
		"Neck": "Body", "Head": "Neck", "Jaw": "Head",
		"Tail_Base": "Body", "Tail_Mid": "Tail_Base", "Tail_Tip": "Tail_Mid",
	}
	for bone_name in ["Neck", "Head", "Jaw", "Tail_Base", "Tail_Mid", "Tail_Tip"]:
		_add_bone(skeleton, bone_name, str(parents[bone_name]), chain_rests[bone_name])
		attachments[bone_name] = _add_attachment(skeleton, "%sAttachment" % bone_name, bone_name)

	for pivot in leg_pivots:
		var suffix := str(pivot.name).trim_prefix("LegPivot_")
		var bone_name := "Leg_%s" % suffix
		_add_bone(skeleton, bone_name, "Body", _relative_transform(pivot, model))
		var attachment := _add_attachment(skeleton, "LegPivot_%s" % suffix, bone_name)
		attachments[bone_name] = attachment
		_move_pivot_children(pivot, model, skeleton, attachment, bone_name)

	for detail_part in detail_parts:
		var target_bone := _detail_target_bone(detail_part)
		_move_node_to_attachment(detail_part, model, skeleton, attachments[target_bone], target_bone)
	_apply_weighted_body(organic_body, skeleton)
	_add_skill_sockets(attachments)

	skeleton.reset_bone_poses()
	skeleton.set_meta("species_id", species_id)
	skeleton.set_meta("rig_version", 1)
	skeleton.set_meta("skin_mode", "weighted_long_body")
	skeleton.set_meta("locomotion_profile", "amphibious_sprawl")
	skeleton.set_meta("animation_states", ANIMATION_STATES.duplicate())
	model.set_meta("uses_crocodile_skeleton_rig", true)
	return skeleton


static func resolve_state(
	gait_blend: float,
	attack_remaining: float,
	roll_remaining: float,
	hit_remaining: float,
	swimming: bool
) -> String:
	if hit_remaining > 0.0:
		return "hit"
	if roll_remaining > 0.0:
		return "roll"
	if attack_remaining > 0.0:
		return "attack"
	if gait_blend <= 0.10:
		return "idle"
	return "swim" if swimming else "crawl"


static func apply_pose(
	skeleton: Skeleton3D,
	state: String,
	motion_time: float,
	speed_ratio: float,
	attack_progress: float,
	roll_progress: float,
	hit_progress: float,
	actor_phase: float,
	delta: float
) -> void:
	if skeleton == null:
		return
	var targets := pose_targets(
		state,
		motion_time,
		speed_ratio,
		attack_progress,
		roll_progress,
		hit_progress,
		actor_phase
	)
	var blend_speed := 28.0 if state in ["attack", "roll", "hit"] else 14.0
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
	attack_progress: float,
	roll_progress: float,
	hit_progress: float,
	actor_phase: float
) -> Dictionary:
	var idle_wave := sin(motion_time * 0.42 + actor_phase)
	var targets := {
		"Body": Vector3(0.0, idle_wave * 0.012, 0.0),
		"Neck": Vector3(0.0, -idle_wave * 0.018, 0.0),
		"Head": Vector3(0.0, idle_wave * 0.010, 0.0),
		"Jaw": Vector3(-0.025, 0.0, 0.0),
		"Tail_Base": Vector3(0.0, sin(motion_time * 0.48 + actor_phase + 0.45) * 0.035, 0.0),
		"Tail_Mid": Vector3(0.0, sin(motion_time * 0.48 + actor_phase + 0.92) * 0.055, 0.0),
		"Tail_Tip": Vector3(0.0, sin(motion_time * 0.48 + actor_phase + 1.36) * 0.075, 0.0),
		"Leg_LF": Vector3.ZERO,
		"Leg_RF": Vector3.ZERO,
		"Leg_LH": Vector3.ZERO,
		"Leg_RH": Vector3.ZERO,
	}
	match state:
		"crawl":
			var strength := clampf(speed_ratio, 0.0, 1.25)
			var stride := 0.34 * strength
			var crawl_phase := motion_time * 0.78
			targets["Body"] = Vector3(0.0, sin(crawl_phase) * 0.040 * strength, sin(crawl_phase * 2.0) * 0.018 * strength)
			targets["Neck"] = Vector3(0.0, -sin(crawl_phase + 0.35) * 0.055 * strength, 0.0)
			targets["Head"] = Vector3(0.0, sin(crawl_phase + 0.70) * 0.028 * strength, 0.0)
			targets["Tail_Base"] = Vector3(0.0, sin(crawl_phase + 0.80) * 0.13 * strength, 0.0)
			targets["Tail_Mid"] = Vector3(0.0, sin(crawl_phase + 1.34) * 0.22 * strength, 0.0)
			targets["Tail_Tip"] = Vector3(0.0, sin(crawl_phase + 1.92) * 0.32 * strength, 0.0)
			targets["Leg_LF"] = Vector3(sin(crawl_phase) * stride, 0.0, -0.08)
			targets["Leg_RH"] = Vector3(sin(crawl_phase + 0.20) * stride, 0.0, 0.08)
			targets["Leg_RF"] = Vector3(sin(crawl_phase + PI) * stride, 0.0, 0.08)
			targets["Leg_LH"] = Vector3(sin(crawl_phase + PI + 0.20) * stride, 0.0, -0.08)
		"swim":
			var strength := clampf(speed_ratio, 0.25, 1.35)
			var swim_phase := motion_time * 0.94
			targets["Body"] = Vector3(0.0, sin(swim_phase) * 0.075 * strength, 0.0)
			targets["Neck"] = Vector3(0.0, -sin(swim_phase + 0.42) * 0.095 * strength, 0.0)
			targets["Head"] = Vector3(-0.025, sin(swim_phase + 0.78) * 0.055 * strength, 0.0)
			targets["Tail_Base"] = Vector3(0.0, sin(swim_phase + 0.92) * 0.29 * strength, 0.0)
			targets["Tail_Mid"] = Vector3(0.0, sin(swim_phase + 1.54) * 0.48 * strength, 0.0)
			targets["Tail_Tip"] = Vector3(0.0, sin(swim_phase + 2.12) * 0.68 * strength, 0.0)
			for leg_name in ["Leg_LF", "Leg_RF", "Leg_LH", "Leg_RH"]:
				targets[leg_name] = Vector3(0.22, 0.0, -0.10 if leg_name in ["Leg_LF", "Leg_LH"] else 0.10)
		"attack":
			var attack_curve := sin(clampf(attack_progress, 0.0, 1.0) * PI)
			targets["Body"] = Vector3(-0.045 * attack_curve, 0.0, 0.0)
			targets["Neck"] = Vector3(-0.075 * attack_curve, 0.0, 0.0)
			targets["Head"] = Vector3(0.055 * attack_curve, sin(actor_phase) * 0.055 * attack_curve, 0.0)
			targets["Jaw"] = Vector3(-0.42 * attack_curve, 0.0, 0.0)
			targets["Tail_Base"] = Vector3(0.0, -sin(actor_phase + 0.4) * 0.12 * attack_curve, 0.0)
			targets["Tail_Mid"] = Vector3(0.0, sin(actor_phase + 0.8) * 0.20 * attack_curve, 0.0)
			targets["Tail_Tip"] = Vector3(0.0, sin(actor_phase + 1.2) * 0.28 * attack_curve, 0.0)
		"roll":
			var roll_curve := sin(clampf(roll_progress, 0.0, 1.0) * PI)
			var side := -1.0 if sin(actor_phase * 1.37) < 0.0 else 1.0
			targets["Body"] = Vector3(-0.06 * roll_curve, side * 0.10 * roll_curve, side * 0.92 * roll_curve)
			targets["Neck"] = Vector3(0.04 * roll_curve, -side * 0.13 * roll_curve, side * 0.18 * roll_curve)
			targets["Head"] = Vector3(-0.05 * roll_curve, side * 0.16 * roll_curve, side * 0.15 * roll_curve)
			targets["Jaw"] = Vector3(-0.16, 0.0, 0.0)
			targets["Tail_Base"] = Vector3(0.0, -side * 0.30 * roll_curve, -side * 0.18 * roll_curve)
			targets["Tail_Mid"] = Vector3(0.0, -side * 0.46 * roll_curve, -side * 0.12 * roll_curve)
			targets["Tail_Tip"] = Vector3(0.0, side * 0.62 * roll_curve, 0.0)
		"hit":
			var hit_curve := sin(clampf(hit_progress, 0.0, 1.0) * PI)
			var side := -1.0 if sin(actor_phase * 1.71) < 0.0 else 1.0
			targets["Body"] = Vector3(0.08 * hit_curve, -side * 0.10 * hit_curve, side * 0.19 * hit_curve)
			targets["Neck"] = Vector3(0.04 * hit_curve, side * 0.14 * hit_curve, -side * 0.08 * hit_curve)
			targets["Head"] = Vector3(0.10 * hit_curve, side * 0.11 * hit_curve, -side * 0.08 * hit_curve)
			targets["Jaw"] = Vector3(-0.10 * hit_curve, 0.0, 0.0)
			targets["Tail_Base"] = Vector3(0.0, -side * 0.17 * hit_curve, 0.0)
			targets["Tail_Mid"] = Vector3(0.0, -side * 0.24 * hit_curve, 0.0)
			targets["Tail_Tip"] = Vector3(0.0, side * 0.34 * hit_curve, 0.0)
	return targets


static func find_socket(model: Node, socket_name: String) -> Node3D:
	if model == null or not socket_name in SKILL_SOCKET_NAMES:
		return null
	return _find_node_named(model, socket_name) as Node3D


static func _detail_target_bone(node: Node3D) -> String:
	var node_name := str(node.name)
	if node_name == "LowerJaw":
		return "Jaw"
	for head_prefix in ["EyeSocket", "Iris", "Pupil", "EyeCatchlight", "Nostril", "Tooth"]:
		if node_name.begins_with(head_prefix):
			return "Head"
	if node_name.begins_with("BackScute"):
		if node.position.z > 1.18:
			return "Tail_Mid"
		if node.position.z > 0.52:
			return "Tail_Base"
		if node.position.z < -1.55:
			return "Head"
		if node.position.z < -0.72:
			return "Neck"
	return "Body"


static func _apply_weighted_body(mesh_instance: MeshInstance3D, skeleton: Skeleton3D) -> void:
	if mesh_instance.mesh == null:
		return
	var source := mesh_instance.mesh
	var skinned := ArrayMesh.new()
	var total_vertices := 0
	var blended_vertices := 0
	for surface_index in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_VERTEX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bone_indices := PackedInt32Array()
		var weights := PackedFloat32Array()
		bone_indices.resize(vertices.size() * 4)
		weights.resize(vertices.size() * 4)
		for vertex_index in range(vertices.size()):
			var influences := _vertex_influences(vertices[vertex_index])
			for slot_index in range(mini(influences.size(), 4)):
				var influence: Vector2 = influences[slot_index]
				bone_indices[vertex_index * 4 + slot_index] = int(influence.x)
				weights[vertex_index * 4 + slot_index] = influence.y
			if influences.size() > 1:
				blended_vertices += 1
		arrays[Mesh.ARRAY_BONES] = bone_indices
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		skinned.add_surface_from_arrays(source.surface_get_primitive_type(surface_index), arrays)
		skinned.surface_set_material(skinned.get_surface_count() - 1, source.surface_get_material(surface_index))
		total_vertices += vertices.size()
	var skin := Skin.new()
	for bone_name in SKIN_BONES:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index >= 0:
			skin.add_named_bind(bone_name, skeleton.get_bone_global_rest(bone_index).affine_inverse())
	mesh_instance.mesh = skinned
	mesh_instance.skin = skin
	mesh_instance.skeleton = mesh_instance.get_path_to(skeleton)
	mesh_instance.set_meta("weighted_skin", true)
	mesh_instance.set_meta("weighted_vertex_count", total_vertices)
	mesh_instance.set_meta("blended_vertex_count", blended_vertices)
	skeleton.set_meta("weighted_mesh", str(mesh_instance.name))


static func _vertex_influences(vertex: Vector3) -> Array[Vector2]:
	if vertex.z <= -2.12:
		return [Vector2(2.0, 1.0)]
	if vertex.z <= -1.20:
		var head_blend := smoothstep(-1.20, -2.12, vertex.z)
		return [Vector2(1.0, 1.0 - head_blend), Vector2(2.0, head_blend)]
	if vertex.z <= -0.44:
		var neck_blend := smoothstep(-0.44, -1.20, vertex.z)
		return [Vector2(0.0, 1.0 - neck_blend), Vector2(1.0, neck_blend)]
	if vertex.z <= 0.36:
		return [Vector2(0.0, 1.0)]
	if vertex.z <= 0.94:
		var tail_base_blend := smoothstep(0.36, 0.94, vertex.z)
		return [Vector2(0.0, 1.0 - tail_base_blend), Vector2(3.0, tail_base_blend)]
	if vertex.z <= 1.46:
		var tail_mid_blend := smoothstep(0.94, 1.46, vertex.z)
		return [Vector2(3.0, 1.0 - tail_mid_blend), Vector2(4.0, tail_mid_blend)]
	var tail_tip_blend := smoothstep(1.46, 2.02, vertex.z)
	return [Vector2(4.0, 1.0 - tail_tip_blend), Vector2(5.0, tail_tip_blend)]


static func _add_skill_sockets(attachments: Dictionary) -> void:
	var jaw_socket := Node3D.new()
	jaw_socket.name = "SkillSocket_Jaw"
	(attachments["Jaw"] as Node3D).add_child(jaw_socket)
	jaw_socket.position = Vector3(0.0, -0.02, -1.48)
	jaw_socket.set_meta("socket_role", "death_roll_bite_origin")
	var tail_socket := Node3D.new()
	tail_socket.name = "SkillSocket_TailTip"
	(attachments["Tail_Tip"] as Node3D).add_child(tail_socket)
	tail_socket.position = Vector3(0.0, 0.0, 0.38)
	tail_socket.set_meta("socket_role", "tail_wake_origin")


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
