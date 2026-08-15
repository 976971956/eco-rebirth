class_name SpeciesSkeletonRig
extends RefCounted

const RIG_NAME := "SpeciesSkeleton3D"
const RIGGED_SPECIES := [
	"rabbit", "fox", "deer", "wolf", "bear", "boar", "raccoon", "porcupine", "capybara", "otter",
	"lynx", "goat", "wolverine", "bison", "zebra", "elephant", "tiger", "monkey", "moose", "turtle",
	"cheetah", "rhino", "gorilla", "hippo", "hyena", "lion",
]
const WEIGHTED_SKIN_SPECIES := RIGGED_SPECIES
const SKILL_SOCKET_NAMES := ["SkillSocket_Mouth", "SkillSocket_Chest"]
const ANIMATION_STATES := ["idle", "run", "attack", "hit"]
const RABBIT_ANIMATION_STATES := ["idle", "run", "forage", "attack", "skill", "hit", "dead"]
const V2_ANIMATION_STATES := ["idle", "run", "sprint", "forage", "attack", "skill", "hit", "dead"]
const DRIVEN_BONES := [
	"Spine", "Chest", "Neck", "Head",
	"Leg_LF", "Leg_RF", "Leg_LH", "Leg_RH",
	"Paw_LF", "Paw_RF", "Paw_LH", "Paw_RH",
	"Ear_L", "Ear_R", "Tail",
]
const ATTACK_DURATION := 0.26
const HIT_DURATION := 0.28
const RABBIT_SKILL_DURATION := 0.38
const DEFAULT_SKILL_DURATION := 0.44
const RIG_PROFILES := {
	"rabbit": {
		"gait": "bound", "gait_rate": 1.24, "front_stride": 0.68, "hind_stride": 1.38,
		"spine_run": 1.18, "ear_run": 1.42, "tail_run": 0.78,
		"attack_spine": -0.13, "attack_front": -0.22, "attack_hind": 0.48,
		"hit_spine": 0.16, "hit_side": 0.26,
	},
	"wolf": {
		"gait": "trot", "gait_rate": 1.0, "front_stride": 0.86, "hind_stride": 1.15,
		"spine_run": 1.0, "ear_run": 1.0, "tail_run": 1.0,
		"attack_spine": -0.11, "attack_front": -0.42, "attack_hind": 0.26,
		"hit_spine": 0.12, "hit_side": 0.24,
	},
	"deer": {
		"gait": "trot", "gait_rate": 1.12, "front_stride": 1.04, "hind_stride": 0.96,
		"spine_run": 0.72, "ear_run": 0.72, "tail_run": 0.54,
		"attack_spine": -0.27, "attack_front": -0.18, "attack_hind": 0.20,
		"hit_spine": 0.09, "hit_side": 0.18,
	},
	"bear": {
		"gait": "pace", "gait_rate": 0.72, "front_stride": 0.72, "hind_stride": 0.76,
		"spine_run": 0.46, "ear_run": 0.34, "tail_run": 0.24,
		"attack_spine": -0.24, "attack_front": -0.58, "attack_hind": 0.14,
		"hit_spine": 0.07, "hit_side": 0.13,
	},
}
const FAMILY_BY_SPECIES := {
	"fox": "canid", "raccoon": "canid", "otter": "canid", "wolverine": "canid", "hyena": "canid",
	"lynx": "felid", "tiger": "felid", "cheetah": "felid", "lion": "felid",
	"deer": "ungulate", "goat": "ungulate", "bison": "ungulate", "zebra": "ungulate", "moose": "ungulate",
	"bear": "heavy", "boar": "heavy", "porcupine": "heavy", "capybara": "heavy", "elephant": "heavy", "rhino": "heavy", "hippo": "heavy",
	"monkey": "primate", "gorilla": "primate", "turtle": "chelonian",
}
const FAMILY_PROFILES := {
	"canid": {
		"gait": "trot", "gait_rate": 1.08, "front_stride": 0.90, "hind_stride": 1.08,
		"spine_run": 1.02, "ear_run": 1.12, "tail_run": 1.14,
		"attack_spine": -0.13, "attack_front": -0.44, "attack_hind": 0.29,
		"hit_spine": 0.13, "hit_side": 0.25,
	},
	"felid": {
		"gait": "bound", "gait_rate": 1.20, "front_stride": 1.02, "hind_stride": 1.28,
		"spine_run": 1.32, "ear_run": 0.78, "tail_run": 1.20,
		"attack_spine": -0.19, "attack_front": -0.54, "attack_hind": 0.48,
		"hit_spine": 0.14, "hit_side": 0.27,
	},
	"ungulate": {
		"gait": "trot", "gait_rate": 1.05, "front_stride": 1.10, "hind_stride": 1.02,
		"spine_run": 0.66, "ear_run": 0.68, "tail_run": 0.55,
		"attack_spine": -0.28, "attack_front": -0.20, "attack_hind": 0.24,
		"hit_spine": 0.09, "hit_side": 0.18,
	},
	"heavy": {
		"gait": "pace", "gait_rate": 0.72, "front_stride": 0.74, "hind_stride": 0.78,
		"spine_run": 0.45, "ear_run": 0.34, "tail_run": 0.32,
		"attack_spine": -0.25, "attack_front": -0.60, "attack_hind": 0.16,
		"hit_spine": 0.07, "hit_side": 0.14,
	},
	"primate": {
		"gait": "pace", "gait_rate": 0.88, "front_stride": 1.24, "hind_stride": 0.74,
		"spine_run": 0.70, "ear_run": 0.28, "tail_run": 0.82,
		"attack_spine": -0.21, "attack_front": -0.76, "attack_hind": 0.16,
		"hit_spine": 0.11, "hit_side": 0.22,
	},
	"chelonian": {
		"gait": "pace", "gait_rate": 0.50, "front_stride": 0.42, "hind_stride": 0.42,
		"spine_run": 0.18, "ear_run": 0.0, "tail_run": 0.16,
		"attack_spine": -0.10, "attack_front": -0.20, "attack_hind": 0.08,
		"hit_spine": 0.04, "hit_side": 0.08,
	},
}


static func _profile_for(species_id: String) -> Dictionary:
	if RIG_PROFILES.has(species_id):
		return RIG_PROFILES[species_id]
	return FAMILY_PROFILES.get(str(FAMILY_BY_SPECIES.get(species_id, "canid")), FAMILY_PROFILES["canid"])


static func skill_duration(species_id: String) -> float:
	return RABBIT_SKILL_DURATION if species_id == "rabbit" else DEFAULT_SKILL_DURATION


static func supports(species_id: String) -> bool:
	return species_id in RIGGED_SPECIES


static func upgrade(model: Node3D, species_id: String) -> Skeleton3D:
	if model == null or not supports(species_id):
		return null
	var existing := _find_skeleton(model)
	if existing != null:
		_register_existing_rig(model, existing, species_id)
		return existing
	var pivots: Array[Node3D] = []
	_collect_motion_pivots(model, pivots)
	if pivots.is_empty():
		return null
	pivots = _ordered_pivots(pivots)

	var skeleton := Skeleton3D.new()
	skeleton.name = RIG_NAME
	model.add_child(skeleton)
	skeleton.add_bone("Root")
	skeleton.set_bone_rest(0, Transform3D.IDENTITY)

	var attachments := {}
	for pivot in pivots:
		if not is_instance_valid(pivot) or pivot == model:
			continue
		var bone_name := _bone_name_for_pivot(str(pivot.name))
		if bone_name == "" or skeleton.find_bone(bone_name) >= 0:
			continue
		var parent_name := _bone_parent_name(species_id, bone_name)
		var global_rest := _relative_transform(pivot, model)
		_add_bone(skeleton, bone_name, parent_name, global_rest)
		var attachment := _add_attachment(skeleton, str(pivot.name), bone_name)
		attachments[bone_name] = attachment

		if species_id in WEIGHTED_SKIN_SPECIES and bone_name == "Spine":
			_add_weighted_body_chain(skeleton, attachments, species_id)
			_distribute_weighted_spine_children(pivot, model, skeleton, attachments, species_id)
		else:
			_move_pivot_to_attachment(pivot, model, skeleton, attachment, bone_name)

	if species_id in WEIGHTED_SKIN_SPECIES:
		if species_id in ["rabbit", "wolf"]:
			_add_weighted_skill_sockets(attachments, species_id)
		var organic_name := _organic_body_name(species_id)
		var organic_body := _find_node_named(model, organic_name) as MeshInstance3D
		if organic_body != null:
			_apply_weighted_skin(organic_body, skeleton, species_id)

	skeleton.reset_bone_poses()
	skeleton.set_meta("species_id", species_id)
	skeleton.set_meta("rig_version", 3 if species_id in WEIGHTED_SKIN_SPECIES else 2)
	skeleton.set_meta("skin_mode", "weighted_prototype" if species_id in WEIGHTED_SKIN_SPECIES else "rigid_parts")
	skeleton.set_meta("locomotion_profile", str(_profile_for(species_id)["gait"]))
	skeleton.set_meta("animation_states", RABBIT_ANIMATION_STATES.duplicate() if species_id == "rabbit" else ANIMATION_STATES.duplicate())
	model.set_meta("uses_skeleton_rig", true)
	return skeleton


static func _register_existing_rig(model: Node3D, skeleton: Skeleton3D, species_id: String) -> void:
	var has_articulated_paws := skeleton.find_bone("Paw_LF") >= 0 and skeleton.find_bone("Paw_RH") >= 0
	skeleton.set_meta("species_id", species_id)
	skeleton.set_meta("rig_version", 4 if has_articulated_paws else 3)
	skeleton.set_meta("skin_mode", "blender_weighted_articulated" if has_articulated_paws else "imported_weighted")
	skeleton.set_meta("locomotion_profile", str(_profile_for(species_id)["gait"]))
	skeleton.set_meta("animation_states", V2_ANIMATION_STATES.duplicate())
	model.set_meta("uses_skeleton_rig", true)
	model.set_meta("articulated_lower_limbs", has_articulated_paws)


static func resolve_state(
	gait_blend: float,
	attack_remaining: float,
	hit_remaining: float,
	forage_remaining: float = 0.0,
	skill_remaining: float = 0.0,
	is_dead: bool = false,
	species_id: String = "wolf"
) -> String:
	if is_dead:
		return "dead"
	if hit_remaining > 0.0:
		return "hit"
	if skill_remaining > 0.0:
		return "skill"
	if attack_remaining > 0.0:
		return "attack"
	if forage_remaining > 0.0:
		return "forage"
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
	delta: float,
	species_id: String = "wolf"
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
		actor_phase,
		species_id
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
	actor_phase: float,
	species_id: String = "wolf"
) -> Dictionary:
	var profile: Dictionary = _profile_for(species_id)
	var targets := {}
	var ear_listen := sin(motion_time * 0.31 + actor_phase) * 0.055
	targets["Ear_L"] = Vector3(ear_listen, 0.0, -0.018)
	targets["Ear_R"] = Vector3(-ear_listen * 0.72, 0.0, 0.018)
	targets["Tail"] = Vector3(0.0, sin(motion_time * 0.72 + actor_phase) * 0.065 * float(profile["tail_run"]), 0.0)
	targets["Spine"] = Vector3(sin(motion_time * 1.32) * 0.012, 0.0, sin(motion_time * 0.66) * 0.010)
	targets["Chest"] = Vector3.ZERO
	targets["Neck"] = Vector3.ZERO
	targets["Head"] = Vector3.ZERO
	for bone_name in ["Leg_LF", "Leg_RF", "Leg_LH", "Leg_RH"]:
		targets[bone_name] = Vector3.ZERO
	for bone_name in ["Paw_LF", "Paw_RF", "Paw_LH", "Paw_RH"]:
		targets[bone_name] = Vector3.ZERO

	match state:
		"run":
			var run_strength := clampf(speed_ratio, 0.0, 1.35)
			var phases := _gait_phases(str(profile["gait"]))
			var stride_scales := {
				"Leg_LF": float(profile["front_stride"]), "Leg_RF": float(profile["front_stride"]),
				"Leg_LH": float(profile["hind_stride"]), "Leg_RH": float(profile["hind_stride"]),
			}
			for bone_name in phases:
				var swing := sin(motion_time * float(profile["gait_rate"]) + float(phases[bone_name])) * stride_amplitude * float(stride_scales[bone_name])
				targets[bone_name] = Vector3(swing, 0.0, 0.0)
				var paw_name := "Paw_%s" % bone_name.trim_prefix("Leg_")
				var flex_curve := maxf(0.0, sin(motion_time * float(profile["gait_rate"]) + float(phases[bone_name])))
				var flex_scale := 0.78 if species_id == "rabbit" else 0.56
				targets[paw_name] = Vector3(-flex_curve * stride_amplitude * flex_scale, 0.0, 0.0)
			targets["Spine"] = Vector3(
				sin(motion_time * 2.0 * float(profile["gait_rate"]) + 0.65) * 0.030 * run_strength * float(profile["spine_run"]),
				0.0,
				sin(motion_time * float(profile["gait_rate"])) * 0.026 * run_strength * float(profile["spine_run"])
			)
			var ear_sweep := 0.11 * minf(run_strength, 1.0) * float(profile["ear_run"])
			targets["Ear_L"] = Vector3(ear_sweep + ear_listen, 0.0, -0.025)
			targets["Ear_R"] = Vector3(ear_sweep - ear_listen * 0.72, 0.0, 0.025)
			targets["Tail"] = Vector3(0.03 * float(profile["tail_run"]), sin(motion_time * 1.15 + actor_phase) * 0.12 * float(profile["tail_run"]), 0.0)
			if species_id in WEIGHTED_SKIN_SPECIES:
				targets["Chest"] = Vector3(-targets["Spine"].x * 0.72, 0.0, -targets["Spine"].z * 0.46)
				var neck_bob := 0.038 if species_id == "rabbit" else 0.018
				targets["Neck"] = Vector3(neck_bob * run_strength, 0.0, sin(motion_time * float(profile["gait_rate"]) + 0.7) * neck_bob)
				targets["Head"] = Vector3(-neck_bob * 0.68 * run_strength, 0.0, -targets["Neck"].z * 0.62)
				if species_id == "rabbit":
					var bound_curve := maxf(sin(motion_time * float(profile["gait_rate"])), -0.35)
					targets["Spine"].x += bound_curve * 0.055 * run_strength
					targets["Chest"].x -= bound_curve * 0.040 * run_strength
					targets["Ear_L"].x += maxf(bound_curve, 0.0) * 0.12
					targets["Ear_R"].x += maxf(bound_curve, 0.0) * 0.12
		"forage":
			var chew := sin(motion_time * 3.4 + actor_phase) * 0.035
			targets["Spine"] = Vector3(-0.08, 0.0, 0.0)
			targets["Chest"] = Vector3(0.18, 0.0, 0.0)
			targets["Neck"] = Vector3((0.58 if species_id == "rabbit" else 0.42) + chew, 0.0, 0.0)
			targets["Head"] = Vector3((0.42 if species_id == "rabbit" else 0.26) - chew * 0.7, 0.0, 0.0)
			targets["Ear_L"] = Vector3(0.28, 0.0, -0.08)
			targets["Ear_R"] = Vector3(0.23, 0.0, 0.08)
			targets["Leg_LF"] = Vector3(-0.12, 0.0, 0.0)
			targets["Leg_RF"] = Vector3(-0.12, 0.0, 0.0)
		"attack":
			var attack_curve := sin(clampf(attack_progress, 0.0, 1.0) * PI)
			targets["Spine"] = Vector3(float(profile["attack_spine"]) * attack_curve, 0.0, 0.0)
			targets["Leg_LF"] = Vector3(float(profile["attack_front"]) * attack_curve, 0.0, -0.05 * attack_curve)
			targets["Leg_RF"] = Vector3(float(profile["attack_front"]) * attack_curve, 0.0, 0.05 * attack_curve)
			targets["Leg_LH"] = Vector3(float(profile["attack_hind"]) * attack_curve, 0.0, 0.0)
			targets["Leg_RH"] = Vector3(float(profile["attack_hind"]) * attack_curve, 0.0, 0.0)
			targets["Ear_L"] = Vector3(0.24 * attack_curve * float(profile["ear_run"]), 0.0, -0.05)
			targets["Ear_R"] = Vector3(0.24 * attack_curve * float(profile["ear_run"]), 0.0, 0.05)
			targets["Tail"] = Vector3(-0.06 * attack_curve, -0.18 * attack_curve * float(profile["tail_run"]), 0.0)
			if species_id in WEIGHTED_SKIN_SPECIES:
				targets["Chest"] = Vector3(-0.07 * attack_curve, 0.0, 0.0)
				targets["Neck"] = Vector3((-0.04 if species_id == "rabbit" else -0.09) * attack_curve, 0.0, 0.0)
				targets["Head"] = Vector3((0.12 if species_id == "rabbit" else 0.04) * attack_curve, 0.0, 0.0)
		"skill":
			var leap_curve := sin(clampf(attack_progress, 0.0, 1.0) * PI)
			if species_id == "rabbit":
				targets["Spine"] = Vector3(-0.20 * leap_curve, 0.0, 0.0)
				targets["Chest"] = Vector3(0.12 * leap_curve, 0.0, 0.0)
				targets["Neck"] = Vector3(-0.08 * leap_curve, 0.0, 0.0)
				targets["Head"] = Vector3(0.06 * leap_curve, 0.0, 0.0)
				for bone_name in ["Leg_LF", "Leg_RF"]:
					targets[bone_name] = Vector3(-0.52 * leap_curve, 0.0, 0.0)
					targets["Paw_%s" % bone_name.trim_prefix("Leg_")] = Vector3(0.34 * leap_curve, 0.0, 0.0)
				for bone_name in ["Leg_LH", "Leg_RH"]:
					targets[bone_name] = Vector3(0.82 * leap_curve, 0.0, 0.0)
					targets["Paw_%s" % bone_name.trim_prefix("Leg_")] = Vector3(-0.58 * leap_curve, 0.0, 0.0)
				targets["Ear_L"] = Vector3(0.42 * leap_curve, 0.0, -0.06)
				targets["Ear_R"] = Vector3(0.42 * leap_curve, 0.0, 0.06)
				targets["Tail"] = Vector3(-0.12 * leap_curve, 0.18 * leap_curve, 0.0)
			else:
				var family := str(FAMILY_BY_SPECIES.get(species_id, "canid"))
				var heavy_scale := 0.68 if family in ["heavy", "chelonian"] else 1.0
				targets["Spine"] = Vector3(-0.24 * leap_curve * heavy_scale, 0.0, 0.0)
				targets["Chest"] = Vector3(-0.10 * leap_curve, 0.0, 0.0)
				targets["Neck"] = Vector3(-0.13 * leap_curve, 0.0, 0.0)
				targets["Head"] = Vector3(0.16 * leap_curve, 0.0, 0.0)
				targets["Leg_LF"] = Vector3(float(profile["attack_front"]) * 1.18 * leap_curve, 0.0, -0.08 * leap_curve)
				targets["Leg_RF"] = Vector3(float(profile["attack_front"]) * 1.18 * leap_curve, 0.0, 0.08 * leap_curve)
				targets["Leg_LH"] = Vector3(float(profile["attack_hind"]) * 1.24 * leap_curve, 0.0, 0.0)
				targets["Leg_RH"] = Vector3(float(profile["attack_hind"]) * 1.24 * leap_curve, 0.0, 0.0)
				targets["Tail"] = Vector3(-0.08 * leap_curve, 0.24 * leap_curve * float(profile["tail_run"]), 0.0)
		"hit":
			var hit_curve := sin(clampf(hit_progress, 0.0, 1.0) * PI)
			var recoil_side := -1.0 if sin(actor_phase * 1.73) < 0.0 else 1.0
			targets["Spine"] = Vector3(float(profile["hit_spine"]) * hit_curve, 0.0, recoil_side * float(profile["hit_side"]) * hit_curve)
			targets["Leg_LF"] = Vector3(0.20 * hit_curve, 0.0, -0.08 * recoil_side)
			targets["Leg_RF"] = Vector3(-0.16 * hit_curve, 0.0, 0.08 * recoil_side)
			targets["Leg_LH"] = Vector3(-0.12 * hit_curve, 0.0, 0.0)
			targets["Leg_RH"] = Vector3(0.12 * hit_curve, 0.0, 0.0)
			targets["Ear_L"] = Vector3(0.34 * hit_curve, 0.0, -0.09)
			targets["Ear_R"] = Vector3(0.34 * hit_curve, 0.0, 0.09)
			targets["Tail"] = Vector3(0.08 * hit_curve, recoil_side * 0.16 * hit_curve, 0.0)
			if species_id in WEIGHTED_SKIN_SPECIES:
				targets["Chest"] = Vector3(0.03 * hit_curve, 0.0, recoil_side * 0.07 * hit_curve)
				targets["Neck"] = Vector3(0.02 * hit_curve, 0.0, -recoil_side * 0.05 * hit_curve)
				targets["Head"] = Vector3(0.04 * hit_curve, 0.0, -recoil_side * 0.07 * hit_curve)
		"dead":
			if species_id == "rabbit":
				targets["Spine"] = Vector3(0.08, 0.0, 1.18)
				targets["Chest"] = Vector3(0.10, 0.0, 0.22)
				targets["Neck"] = Vector3(0.18, 0.0, 0.12)
				targets["Head"] = Vector3(0.12, 0.0, 0.10)
				targets["Leg_LF"] = Vector3(0.44, 0.0, -0.18)
				targets["Leg_RF"] = Vector3(-0.24, 0.0, 0.14)
				targets["Leg_LH"] = Vector3(0.35, 0.0, -0.16)
				targets["Leg_RH"] = Vector3(-0.18, 0.0, 0.12)
				targets["Ear_L"] = Vector3(0.48, 0.0, -0.12)
				targets["Ear_R"] = Vector3(0.52, 0.0, 0.12)
				targets["Tail"] = Vector3(0.0, -0.18, 0.0)
			else:
				targets["Spine"] = Vector3(0.06, 0.0, 1.16)
				targets["Chest"] = Vector3(0.10, 0.0, 0.20)
				targets["Neck"] = Vector3(0.16, 0.0, 0.10)
				targets["Head"] = Vector3(0.12, 0.0, 0.08)
				targets["Leg_LF"] = Vector3(0.34, 0.0, -0.14)
				targets["Leg_RF"] = Vector3(-0.22, 0.0, 0.12)
				targets["Leg_LH"] = Vector3(0.28, 0.0, -0.12)
				targets["Leg_RH"] = Vector3(-0.16, 0.0, 0.10)
				targets["Ear_L"] = Vector3(0.38, 0.0, -0.10)
				targets["Ear_R"] = Vector3(0.42, 0.0, 0.10)
				targets["Tail"] = Vector3(0.0, -0.16, 0.0)
	return targets


static func find_socket(model: Node, socket_name: String) -> Node3D:
	if model == null or not socket_name in SKILL_SOCKET_NAMES:
		return null
	return _find_node_named(model, socket_name) as Node3D


static func _gait_phases(gait: String) -> Dictionary:
	match gait:
		"bound":
			return {"Leg_LF": 0.0, "Leg_RF": 0.22, "Leg_LH": PI, "Leg_RH": PI + 0.18}
		"pace":
			return {"Leg_LF": 0.0, "Leg_RF": PI, "Leg_LH": 0.18, "Leg_RH": PI + 0.18}
		_:
			return {"Leg_LF": 0.0, "Leg_RF": PI, "Leg_LH": PI, "Leg_RH": 0.0}


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


static func _collect_motion_pivots(root: Node, output: Array[Node3D]) -> void:
	for child in root.get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		if _bone_name_for_pivot(str(node.name)) != "":
			output.append(node)
		else:
			_collect_motion_pivots(node, output)


static func _ordered_pivots(pivots: Array[Node3D]) -> Array[Node3D]:
	var ordered: Array[Node3D] = []
	for pivot in pivots:
		if str(pivot.name) == "SpinePivot":
			ordered.push_front(pivot)
		else:
			ordered.append(pivot)
	return ordered


static func _bone_parent_name(species_id: String, bone_name: String) -> String:
	if not species_id in WEIGHTED_SKIN_SPECIES:
		return "Root"
	if bone_name in ["Leg_LF", "Leg_RF"]:
		return "Chest"
	if bone_name in ["Ear_L", "Ear_R"]:
		return "Head"
	if bone_name in ["Leg_LH", "Leg_RH", "Tail"]:
		return "Spine"
	return "Root"


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


static func _add_weighted_body_chain(skeleton: Skeleton3D, attachments: Dictionary, species_id: String) -> void:
	var chain_global_rests := _body_chain_rests(species_id)
	var parent_name := "Spine"
	for bone_name in ["Chest", "Neck", "Head"]:
		_add_bone(skeleton, bone_name, parent_name, chain_global_rests[bone_name])
		attachments[bone_name] = _add_attachment(skeleton, "%sAttachment" % bone_name, bone_name)
		parent_name = bone_name


static func _distribute_weighted_spine_children(
	pivot: Node3D,
	model: Node3D,
	skeleton: Skeleton3D,
	attachments: Dictionary,
	species_id: String
) -> void:
	for child in pivot.get_children():
		if not child is Node3D:
			continue
		var visual_node := child as Node3D
		var node_name := str(visual_node.name)
		if node_name == _organic_body_name(species_id):
			_move_node_to_model(visual_node, model)
			continue
		var target_bone := "Spine"
		if node_name in ["ShoulderMass", "ShoulderHump", "ChestFur", "ChestLight"]:
			target_bone = "Chest"
		elif node_name in ["CheekRuff", "Muzzle", "Nose", "EyeSocket", "Iris", "Pupil", "EyeCatchlight", "Whisker"] or node_name.begins_with("Antler_"):
			target_bone = "Head"
		_move_node_to_attachment(visual_node, model, skeleton, attachments[target_bone], target_bone)
	pivot.free()


static func _move_pivot_to_attachment(
	pivot: Node3D,
	model: Node3D,
	skeleton: Skeleton3D,
	attachment: BoneAttachment3D,
	bone_name: String
) -> void:
	if pivot is MeshInstance3D:
		pivot.name = "%s_Mesh" % bone_name
		_move_node_to_attachment(pivot, model, skeleton, attachment, bone_name)
		return
	for child in pivot.get_children():
		if child is Node3D:
			_move_node_to_attachment(child as Node3D, model, skeleton, attachment, bone_name)
	pivot.free()


static func _move_node_to_model(node: Node3D, model: Node3D) -> void:
	var model_transform := _relative_transform(node, model)
	node.owner = null
	node.reparent(model, false)
	node.transform = model_transform


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


static func _add_weighted_skill_sockets(attachments: Dictionary, species_id: String) -> void:
	var mouth := Node3D.new()
	mouth.name = "SkillSocket_Mouth"
	attachments["Head"].add_child(mouth)
	mouth.position = Vector3(0.0, -0.07, -0.50 if species_id == "rabbit" else -0.64)
	mouth.set_meta("socket_role", "bite_origin")
	var chest := Node3D.new()
	chest.name = "SkillSocket_Chest"
	attachments["Chest"].add_child(chest)
	chest.position = Vector3(0.0, 0.06 if species_id == "rabbit" else 0.08, -0.04 if species_id == "rabbit" else -0.06)
	chest.set_meta("socket_role", "moonstep_origin" if species_id == "rabbit" else "rally_origin")


static func _apply_weighted_skin(mesh_instance: MeshInstance3D, skeleton: Skeleton3D, species_id: String) -> void:
	if mesh_instance.mesh == null:
		return
	var source := mesh_instance.mesh
	var skinned := ArrayMesh.new()
	var bone_names := ["Spine", "Chest", "Neck", "Head"]
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
			var vertex_weights := _weighted_vertex_weights(vertices[vertex_index], species_id)
			var positive_weights := 0
			for influence_index in range(4):
				var array_index := vertex_index * 4 + influence_index
				bone_indices[array_index] = influence_index
				weights[array_index] = float(vertex_weights[influence_index])
				if weights[array_index] > 0.001:
					positive_weights += 1
			if positive_weights > 1:
				blended_vertices += 1
		arrays[Mesh.ARRAY_BONES] = bone_indices
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		skinned.add_surface_from_arrays(source.surface_get_primitive_type(surface_index), arrays)
		skinned.surface_set_material(skinned.get_surface_count() - 1, source.surface_get_material(surface_index))
		total_vertices += vertices.size()
	var skin := Skin.new()
	for bone_name in bone_names:
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


static func _weighted_vertex_weights(vertex: Vector3, species_id: String) -> PackedFloat32Array:
	if species_id == "rabbit":
		if vertex.z > 0.28:
			return PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
		if vertex.z > -0.56:
			var rabbit_chest_blend := smoothstep(0.28, -0.56, vertex.z)
			return PackedFloat32Array([1.0 - rabbit_chest_blend, rabbit_chest_blend, 0.0, 0.0])
		if vertex.z > -1.10:
			var rabbit_neck_blend := smoothstep(-0.56, -1.10, vertex.z)
			return PackedFloat32Array([0.0, 1.0 - rabbit_neck_blend, rabbit_neck_blend, 0.0])
		if vertex.z > -1.48:
			var rabbit_head_blend := smoothstep(-1.10, -1.48, vertex.z)
			return PackedFloat32Array([0.0, 0.0, 1.0 - rabbit_head_blend, rabbit_head_blend])
		return PackedFloat32Array([0.0, 0.0, 0.0, 1.0])
	if species_id == "deer":
		return _four_chain_weights(vertex.z, 0.34, -0.70, -1.44, -2.16)
	if species_id == "bear":
		return _four_chain_weights(vertex.z, 0.34, -0.66, -1.36, -2.14)
	var result := PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
	if vertex.z > 0.30:
		return result
	if vertex.z > -0.62:
		var chest_blend := smoothstep(0.30, -0.62, vertex.z)
		return PackedFloat32Array([1.0 - chest_blend, chest_blend, 0.0, 0.0])
	if vertex.z > -1.32:
		var neck_blend := smoothstep(-0.62, -1.32, vertex.z)
		return PackedFloat32Array([0.0, 1.0 - neck_blend, neck_blend, 0.0])
	if vertex.z > -2.05:
		var head_blend := smoothstep(-1.32, -2.05, vertex.z)
		return PackedFloat32Array([0.0, 0.0, 1.0 - head_blend, head_blend])
	return PackedFloat32Array([0.0, 0.0, 0.0, 1.0])


static func _four_chain_weights(z_value: float, chest_start: float, neck_start: float, head_start: float, head_end: float) -> PackedFloat32Array:
	if z_value > chest_start:
		return PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
	if z_value > neck_start:
		var chest_blend := smoothstep(chest_start, neck_start, z_value)
		return PackedFloat32Array([1.0 - chest_blend, chest_blend, 0.0, 0.0])
	if z_value > head_start:
		var neck_blend := smoothstep(neck_start, head_start, z_value)
		return PackedFloat32Array([0.0, 1.0 - neck_blend, neck_blend, 0.0])
	if z_value > head_end:
		var head_blend := smoothstep(head_start, head_end, z_value)
		return PackedFloat32Array([0.0, 0.0, 1.0 - head_blend, head_blend])
	return PackedFloat32Array([0.0, 0.0, 0.0, 1.0])


static func _body_chain_rests(species_id: String) -> Dictionary:
	match species_id:
		"rabbit":
			return {
				"Chest": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.10, -0.48)),
				"Neck": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.28, -1.02)),
				"Head": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.36, -1.50)),
			}
		"deer":
			return {
				"Chest": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.68, -0.52)),
				"Neck": Transform3D(Basis.IDENTITY, Vector3(0.0, 2.12, -1.08)),
				"Head": Transform3D(Basis.IDENTITY, Vector3(0.0, 2.70, -1.74)),
			}
		"bear":
			return {
				"Chest": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.76, -0.54)),
				"Neck": Transform3D(Basis.IDENTITY, Vector3(0.0, 2.03, -1.18)),
				"Head": Transform3D(Basis.IDENTITY, Vector3(0.0, 2.04, -1.82)),
			}
		_:
			return {
				"Chest": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.42, -0.45)),
				"Neck": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.67, -1.12)),
				"Head": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.69, -1.78)),
			}


static func _organic_body_name(species_id: String) -> String:
	return {
		"rabbit": "RabbitOrganicBody",
		"wolf": "WolfOrganicBody",
		"deer": "DeerOrganicBody",
		"bear": "BearOrganicBody",
	}.get(species_id, "")


static func _find_node_named(root: Node, node_name: String) -> Node:
	if str(root.name) == node_name:
		return root
	for child in root.get_children():
		var found := _find_node_named(child, node_name)
		if found != null:
			return found
	return null


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
