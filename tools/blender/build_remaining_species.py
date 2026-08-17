from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


ACTIONS = ("idle", "locomotion", "sprint", "attack", "skill", "hit", "eat", "death")
LIMBS = ("LF", "RF", "LH", "RH")
BIRDS = ("owl", "eagle")
LONG_BODY = ("snake", "crocodile")
REMAINING_SPECIES = (
    "turtle",
    "cheetah", "rhino", "gorilla",
    "eagle", "hippo", "hyena", "lion",
)


FAMILY_BASE = {
    "canid": dict(width=0.55, height=0.58, length=1.42, leg=0.86, paw=0.18, head=0.43, muzzle=0.50, neck=0.42, tail=1.30, ear=0.34),
    "felid": dict(width=0.62, height=0.62, length=1.58, leg=0.90, paw=0.20, head=0.45, muzzle=0.36, neck=0.40, tail=1.55, ear=0.27),
    "ungulate": dict(width=0.63, height=0.68, length=1.58, leg=1.22, paw=0.14, head=0.42, muzzle=0.50, neck=0.68, tail=0.58, ear=0.32),
    "heavy": dict(width=0.82, height=0.80, length=1.62, leg=0.78, paw=0.25, head=0.55, muzzle=0.48, neck=0.46, tail=0.36, ear=0.22),
    "primate": dict(width=0.72, height=0.78, length=1.12, leg=0.82, paw=0.26, head=0.48, muzzle=0.30, neck=0.30, tail=0.95, ear=0.20),
    "chelonian": dict(width=0.84, height=0.52, length=1.24, leg=0.42, paw=0.24, head=0.32, muzzle=0.24, neck=0.44, tail=0.18, ear=0.0),
}


SPECIES = {
    "fox": dict(family="canid", coat="#bb5d28", accent="#efe3ce", dark="#282523", eye="#d39a38", width=0.48, height=0.50, length=1.30, leg=0.76, tail=1.62, ear=0.43, features=("chest", "black_legs", "tail_tip")),
    "deer": dict(family="ungulate", coat="#8a5533", accent="#e4d0aa", dark="#3e2b21", eye="#39200e", leg=1.34, neck=0.82, tail=0.42, features=("chest", "antlers", "hoof")),
    "bear": dict(family="heavy", coat="#4c3327", accent="#80634c", dark="#1d1816", eye="#25130b", width=0.96, height=0.92, length=1.66, leg=0.72, head=0.62, features=("shoulder_hump", "muzzle_patch", "claws")),
    "boar": dict(family="heavy", coat="#55483b", accent="#8e7459", dark="#24201c", eye="#352014", width=0.78, height=0.70, length=1.55, leg=0.62, head=0.48, muzzle=0.66, tail=0.30, features=("tusks", "ridge_mane", "snout")),
    "raccoon": dict(family="canid", coat="#72736e", accent="#c5c2b3", dark="#202428", eye="#d2a84b", width=0.49, height=0.48, length=1.10, leg=0.58, head=0.44, muzzle=0.34, tail=1.10, ear=0.25, features=("mask", "tail_rings", "hands")),
    "porcupine": dict(family="heavy", coat="#514337", accent="#d7c49b", dark="#28231f", eye="#3a2416", width=0.75, height=0.62, length=1.34, leg=0.48, head=0.40, muzzle=0.40, tail=0.40, features=("quills", "muzzle_patch")),
    "capybara": dict(family="heavy", coat="#936943", accent="#bc956c", dark="#3f3127", eye="#2a160d", width=0.74, height=0.66, length=1.42, leg=0.58, head=0.53, muzzle=0.48, tail=0.08, ear=0.16, features=("muzzle_patch",)),
    "otter": dict(family="canid", coat="#493a2d", accent="#a58b69", dark="#17191a", eye="#392211", width=0.43, height=0.42, length=1.36, leg=0.42, head=0.40, muzzle=0.34, tail=1.34, ear=0.14, features=("chest", "webbed_paws")),
    "lynx": dict(family="felid", coat="#a7794b", accent="#d5bd94", dark="#2d2924", eye="#c9ae42", width=0.53, height=0.57, length=1.20, leg=0.92, tail=0.32, ear=0.42, features=("spots", "ear_tufts", "cheek_ruff")),
    "goat": dict(family="ungulate", coat="#9a8d78", accent="#ded2bc", dark="#433c34", eye="#a88d45", width=0.50, height=0.56, length=1.20, leg=0.90, neck=0.55, tail=0.30, features=("horns", "beard", "hoof")),
    "wolverine": dict(family="canid", coat="#322b27", accent="#b18a58", dark="#121416", eye="#7f5523", width=0.64, height=0.58, length=1.24, leg=0.56, head=0.48, muzzle=0.40, tail=0.72, ear=0.18, features=("side_band", "claws")),
    "bison": dict(family="ungulate", coat="#4a3526", accent="#8b6b47", dark="#1d1a17", eye="#26150c", width=0.92, height=0.98, length=1.66, leg=0.94, head=0.57, muzzle=0.55, neck=0.58, tail=0.70, features=("shoulder_hump", "horns", "ridge_mane", "beard", "hoof")),
    "zebra": dict(family="ungulate", coat="#d7d3c6", accent="#eee9da", dark="#26282a", eye="#39261a", width=0.58, height=0.64, length=1.50, leg=1.20, neck=0.76, tail=0.78, features=("stripes", "ridge_mane", "hoof")),
    "elephant": dict(family="heavy", coat="#777a78", accent="#9a8e86", dark="#343739", eye="#4a2b18", width=1.12, height=1.10, length=1.72, leg=1.16, paw=0.34, head=0.76, muzzle=0.20, neck=0.28, tail=0.72, ear=0.74, features=("trunk", "tusks", "elephant_ears")),
    "tiger": dict(family="felid", coat="#bc6a2f", accent="#e8cfaa", dark="#1b1d1e", eye="#e0b54d", width=0.68, height=0.68, length=1.70, leg=0.90, head=0.49, tail=1.52, features=("stripes", "chest")),
    "monkey": dict(family="primate", coat="#75513b", accent="#c49a75", dark="#28211e", eye="#3a2014", width=0.50, height=0.62, length=0.94, leg=0.72, head=0.43, tail=1.42, features=("face_patch", "hands", "long_arms")),
    "moose": dict(family="ungulate", coat="#4c3a2e", accent="#8e735a", dark="#211d1a", eye="#352015", width=0.74, height=0.78, length=1.66, leg=1.48, head=0.52, muzzle=0.62, neck=0.82, tail=0.24, ear=0.37, features=("palm_antlers", "dewlap", "hoof")),
    "turtle": dict(family="chelonian", coat="#66734f", accent="#9a8652", dark="#323a2b", eye="#19170d", features=("shell", "beak")),
    "cheetah": dict(family="felid", coat="#c59b55", accent="#e8d5a9", dark="#252525", eye="#bf9a3c", width=0.50, height=0.54, length=1.58, leg=1.02, head=0.39, muzzle=0.32, tail=1.70, features=("spots", "tear_marks")),
    "rhino": dict(family="heavy", coat="#77766e", accent="#99978d", dark="#3f403c", eye="#322218", width=1.03, height=0.94, length=1.78, leg=0.82, paw=0.30, head=0.64, muzzle=0.70, neck=0.44, tail=0.42, ear=0.20, features=("rhino_horns", "armor_folds")),
    "gorilla": dict(family="primate", coat="#24282a", accent="#777a78", dark="#111314", eye="#4b2d19", width=0.96, height=0.98, length=1.10, leg=0.78, head=0.56, tail=0.0, features=("silverback", "hands", "long_arms", "brow")),
    "hippo": dict(family="heavy", coat="#756d70", accent="#a77d80", dark="#343135", eye="#3d261b", width=1.18, height=0.92, length=1.72, leg=0.56, paw=0.32, head=0.76, muzzle=0.78, neck=0.30, tail=0.24, ear=0.16, features=("wide_muzzle", "tusks")),
    "hyena": dict(family="canid", coat="#9b7445", accent="#c6a66c", dark="#2b2924", eye="#9e6b27", width=0.61, height=0.68, length=1.42, leg=0.82, head=0.50, muzzle=0.46, tail=0.70, ear=0.39, features=("spots", "ridge_mane", "high_shoulders")),
    "lion": dict(family="felid", coat="#b58a4b", accent="#d8bc83", dark="#5b3b24", eye="#d1a13d", width=0.74, height=0.74, length=1.66, leg=0.92, head=0.54, tail=1.50, features=("mane", "chest", "tail_tuft")),
}


V3_FAMILY_PROFILE = {
    "canid": dict(gait="walk", sprint_gait="gallop", stride=0.42, flex=0.48, stance=0.76, fore_scale=1.0, rear_scale=1.0, front_knee_z=-0.08, hind_knee_z=0.16, front_paw_z=-0.18, hind_paw_z=-0.05, upper_thickness=1.00, lower_thickness=0.66, chest_mass=1.00, rump_mass=0.94, body_bob=0.038, head_bob=0.024, attack="pounce"),
    "felid": dict(gait="stalk", sprint_gait="gallop", stride=0.50, flex=0.55, stance=0.74, fore_scale=1.0, rear_scale=1.02, front_knee_z=-0.10, hind_knee_z=0.22, front_paw_z=-0.20, hind_paw_z=-0.02, upper_thickness=1.06, lower_thickness=0.70, chest_mass=1.00, rump_mass=1.02, body_bob=0.032, head_bob=0.016, attack="pounce"),
    "ungulate": dict(gait="four_beat", sprint_gait="gallop", stride=0.38, flex=0.44, stance=0.74, fore_scale=1.0, rear_scale=1.0, front_knee_z=0.10, hind_knee_z=0.22, front_paw_z=-0.16, hind_paw_z=-0.08, upper_thickness=0.92, lower_thickness=0.52, chest_mass=1.02, rump_mass=0.98, body_bob=0.026, head_bob=0.020, attack="charge"),
    "heavy": dict(gait="lumber", sprint_gait="charge", stride=0.28, flex=0.30, stance=0.76, fore_scale=1.0, rear_scale=1.0, front_knee_z=-0.02, hind_knee_z=0.10, front_paw_z=-0.10, hind_paw_z=-0.02, upper_thickness=1.20, lower_thickness=0.92, chest_mass=1.10, rump_mass=1.05, body_bob=0.046, head_bob=0.030, attack="bash"),
    "primate": dict(gait="knuckle", sprint_gait="knuckle_run", stride=0.34, flex=0.42, stance=0.74, fore_scale=1.20, rear_scale=0.92, front_knee_z=-0.18, hind_knee_z=0.18, front_paw_z=-0.24, hind_paw_z=-0.04, upper_thickness=1.18, lower_thickness=0.92, chest_mass=1.12, rump_mass=0.96, body_bob=0.055, head_bob=0.025, attack="swipe"),
    "chelonian": dict(gait="crawl", sprint_gait="crawl", stride=0.18, flex=0.20, stance=0.96, fore_scale=0.82, rear_scale=0.82, front_knee_z=-0.16, hind_knee_z=0.16, front_paw_z=-0.30, hind_paw_z=0.20, upper_thickness=1.20, lower_thickness=1.05, chest_mass=1.04, rump_mass=1.04, body_bob=0.012, head_bob=0.012, attack="bash"),
}


# V4 uses a true three-segment limb silhouette.  Values are normalized by the
# configured leg length and describe fore/aft offsets in Godot space (-Z is
# forward).  This gives canids/felids a readable elbow and hock, ungulates a
# long metapodial, heavy animals a compact load-bearing chain, and primates a
# bent arm/leg profile instead of four straight rods.
V4_LIMB_PROFILE = {
    "canid": dict(front_joint=0.11, front_ankle=-0.04, hind_joint=-0.22, hind_ankle=0.18, toe_forward=0.26, joint_drop=0.50, ankle_height=0.17),
    "felid": dict(front_joint=0.13, front_ankle=-0.06, hind_joint=-0.25, hind_ankle=0.21, toe_forward=0.29, joint_drop=0.49, ankle_height=0.16),
    "ungulate": dict(front_joint=0.07, front_ankle=-0.02, hind_joint=-0.18, hind_ankle=0.22, toe_forward=0.18, joint_drop=0.48, ankle_height=0.20),
    "heavy": dict(front_joint=0.05, front_ankle=-0.01, hind_joint=-0.13, hind_ankle=0.12, toe_forward=0.18, joint_drop=0.51, ankle_height=0.18),
    "primate": dict(front_joint=0.15, front_ankle=-0.07, hind_joint=-0.22, hind_ankle=0.11, toe_forward=0.24, joint_drop=0.48, ankle_height=0.16),
    "chelonian": dict(front_joint=0.17, front_ankle=-0.12, hind_joint=-0.15, hind_ankle=0.17, toe_forward=0.20, joint_drop=0.47, ankle_height=0.13),
}


V3_SPECIES_PROFILE = {
    "fox": dict(gait="trot", stride=0.44, flex=0.52, stance=0.72, chest_mass=0.94, rump_mass=0.88, attack="pounce"),
    "bear": dict(gait="lumber", stride=0.27, flex=0.28, stance=0.80, upper_thickness=1.34, lower_thickness=1.08, chest_mass=1.22, rump_mass=1.10, attack="swipe"),
    "boar": dict(gait="scuttle", sprint_gait="charge", stride=0.31, flex=0.32, stance=0.82, fore_scale=0.92, rear_scale=0.88, chest_mass=1.20, rump_mass=0.92, attack="charge"),
    "raccoon": dict(gait="amble", sprint_gait="lope", stride=0.32, flex=0.46, stance=0.82, upper_thickness=1.08, lower_thickness=0.86, chest_mass=0.94, rump_mass=1.04, attack="swipe"),
    "porcupine": dict(gait="shuffle", sprint_gait="scuttle", stride=0.22, flex=0.25, stance=0.86, upper_thickness=1.12, lower_thickness=0.92, chest_mass=1.06, rump_mass=1.12, attack="bash"),
    "capybara": dict(gait="amble", sprint_gait="lope", stride=0.25, flex=0.28, stance=0.82, upper_thickness=1.18, lower_thickness=0.98, chest_mass=1.08, rump_mass=1.08, attack="bash"),
    "otter": dict(gait="lope", sprint_gait="bound", stride=0.36, flex=0.52, stance=0.70, fore_scale=0.88, rear_scale=0.92, chest_mass=0.86, rump_mass=0.96, body_bob=0.055, attack="pounce"),
    "lynx": dict(gait="stalk", sprint_gait="bound", stride=0.42, flex=0.58, stance=0.76, rear_scale=1.08, chest_mass=0.94, rump_mass=1.06, attack="pounce"),
    "goat": dict(gait="prance", sprint_gait="bound", stride=0.39, flex=0.56, stance=0.72, upper_thickness=0.90, lower_thickness=0.52, chest_mass=0.98, rump_mass=0.94, attack="charge"),
    "wolverine": dict(gait="lope", sprint_gait="bound", stride=0.34, flex=0.44, stance=0.86, upper_thickness=1.28, lower_thickness=1.00, chest_mass=1.10, rump_mass=1.02, attack="swipe"),
    "bison": dict(gait="lumber", sprint_gait="charge", stride=0.31, flex=0.32, stance=0.80, upper_thickness=1.26, lower_thickness=0.92, chest_mass=1.34, rump_mass=0.92, body_bob=0.052, attack="charge"),
    "zebra": dict(gait="four_beat", sprint_gait="gallop", stride=0.43, flex=0.48, stance=0.72, upper_thickness=0.90, lower_thickness=0.50, chest_mass=1.00, rump_mass=0.98, attack="kick"),
    "elephant": dict(gait="amble", sprint_gait="charge", stride=0.24, flex=0.20, stance=0.78, fore_scale=1.02, rear_scale=1.00, upper_thickness=1.26, lower_thickness=1.16, chest_mass=1.18, rump_mass=1.14, body_bob=0.035, attack="stomp"),
    "tiger": dict(gait="stalk", sprint_gait="gallop", stride=0.50, flex=0.58, stance=0.76, upper_thickness=1.12, lower_thickness=0.76, chest_mass=1.08, rump_mass=1.08, attack="pounce"),
    "monkey": dict(gait="primate_walk", sprint_gait="primate_run", stride=0.40, flex=0.54, stance=0.74, fore_scale=1.62, rear_scale=1.16, upper_thickness=0.92, lower_thickness=0.72, chest_mass=0.98, rump_mass=0.86, attack="swipe"),
    "moose": dict(gait="four_beat", sprint_gait="long_trot", stride=0.38, flex=0.44, stance=0.74, fore_scale=1.04, rear_scale=1.00, upper_thickness=1.14, lower_thickness=0.68, chest_mass=1.12, rump_mass=0.96, attack="charge"),
    "turtle": dict(gait="crawl", sprint_gait="crawl", stride=0.19, flex=0.25, stance=1.06, fore_scale=0.76, rear_scale=0.76, upper_thickness=1.32, lower_thickness=1.20, chest_mass=1.08, rump_mass=1.08, attack="bash"),
    "cheetah": dict(gait="stalk", sprint_gait="gallop", stride=0.62, flex=0.68, stance=0.70, rear_scale=1.12, upper_thickness=0.86, lower_thickness=0.58, chest_mass=0.92, rump_mass=0.98, body_bob=0.060, attack="pounce"),
    "rhino": dict(gait="lumber", sprint_gait="charge", stride=0.30, flex=0.26, stance=0.82, upper_thickness=1.38, lower_thickness=1.06, chest_mass=1.26, rump_mass=1.08, attack="charge"),
    "gorilla": dict(gait="knuckle", sprint_gait="knuckle_run", stride=0.38, flex=0.40, stance=0.90, fore_scale=2.00, rear_scale=1.10, front_knee_z=-0.20, upper_thickness=1.44, lower_thickness=1.18, chest_mass=1.46, rump_mass=0.88, body_bob=0.068, attack="swipe"),
    "hippo": dict(gait="lumber", sprint_gait="charge", stride=0.24, flex=0.22, stance=0.84, fore_scale=0.78, rear_scale=0.76, upper_thickness=1.50, lower_thickness=1.28, chest_mass=1.18, rump_mass=1.18, attack="bash"),
    "hyena": dict(gait="lope", sprint_gait="gallop", stride=0.41, flex=0.49, stance=0.76, fore_scale=1.10, rear_scale=0.94, upper_thickness=1.06, lower_thickness=0.72, chest_mass=1.14, rump_mass=0.90, attack="pounce"),
    "lion": dict(gait="stalk", sprint_gait="gallop", stride=0.48, flex=0.54, stance=0.78, upper_thickness=1.14, lower_thickness=0.78, chest_mass=1.14, rump_mass=1.04, attack="pounce"),
}


# V5 is the real-time near-realistic surface/anatomy pass.  The values are not
# interchangeable family presets: every animal gets its own rib cage, waist,
# pelvis, skull and muzzle proportions.  This keeps the existing mobile-safe
# rig contract while removing the "same toy with different horns" silhouette.
V5_FAMILY_ANATOMY = {
    "canid": dict(rib=0.96, waist=0.78, pelvis=0.88, belly=0.88, skull_width=0.90, skull_height=0.88, skull_length=1.00, muzzle_width=0.72, muzzle_height=0.68, muzzle_length=1.05, eye_scale=0.060, ear_width=0.42, muscle=0.82, foot_width=0.84),
    "felid": dict(rib=1.00, waist=0.74, pelvis=0.96, belly=0.84, skull_width=1.00, skull_height=0.92, skull_length=0.92, muzzle_width=0.82, muzzle_height=0.70, muzzle_length=0.86, eye_scale=0.064, ear_width=0.46, muscle=0.88, foot_width=0.94),
    "ungulate": dict(rib=0.94, waist=0.72, pelvis=0.84, belly=0.82, skull_width=0.82, skull_height=0.82, skull_length=1.04, muzzle_width=0.72, muzzle_height=0.64, muzzle_length=1.12, eye_scale=0.052, ear_width=0.40, muscle=0.72, foot_width=0.62),
    "heavy": dict(rib=1.02, waist=0.92, pelvis=1.00, belly=0.98, skull_width=1.00, skull_height=0.92, skull_length=1.00, muzzle_width=0.94, muzzle_height=0.78, muzzle_length=1.00, eye_scale=0.048, ear_width=0.42, muscle=0.90, foot_width=0.96),
    "primate": dict(rib=1.06, waist=0.76, pelvis=0.88, belly=0.86, skull_width=1.02, skull_height=1.08, skull_length=0.82, muzzle_width=0.84, muzzle_height=0.68, muzzle_length=0.72, eye_scale=0.054, ear_width=0.50, muscle=0.94, foot_width=1.06),
    "chelonian": dict(rib=1.04, waist=1.00, pelvis=1.02, belly=0.74, skull_width=0.92, skull_height=0.72, skull_length=1.00, muzzle_width=0.82, muzzle_height=0.62, muzzle_length=0.88, eye_scale=0.050, ear_width=0.0, muscle=0.72, foot_width=1.08),
}


V5_SPECIES_ANATOMY = {
    "fox": dict(rib=0.88, waist=0.62, pelvis=0.76, belly=0.76, skull_width=0.82, skull_height=0.84, muzzle_width=0.62, muzzle_height=0.56, muzzle_length=1.16, eye_scale=0.056, ear_width=0.46, muscle=0.70, foot_width=0.76),
    "bear": dict(rib=1.10, waist=1.00, pelvis=1.06, belly=1.08, skull_width=1.10, skull_height=0.98, muzzle_width=0.88, muzzle_height=0.72, muzzle_length=0.88, eye_scale=0.040, ear_width=0.46, muscle=1.08, foot_width=1.12),
    "boar": dict(rib=1.08, waist=0.90, pelvis=0.88, belly=0.92, skull_width=0.86, skull_height=0.72, skull_length=1.08, muzzle_width=0.78, muzzle_height=0.66, muzzle_length=1.28, eye_scale=0.042, ear_width=0.42, muscle=0.98, foot_width=0.68),
    "raccoon": dict(rib=0.92, waist=0.80, pelvis=0.96, belly=0.90, skull_width=1.02, skull_height=0.94, muzzle_width=0.72, muzzle_height=0.62, muzzle_length=0.82, eye_scale=0.058, ear_width=0.52, muscle=0.76, foot_width=1.04),
    "porcupine": dict(rib=1.00, waist=0.94, pelvis=1.08, belly=0.90, skull_width=0.76, skull_height=0.70, muzzle_width=0.62, muzzle_height=0.56, muzzle_length=1.08, eye_scale=0.044, ear_width=0.38, muscle=0.78, foot_width=0.86),
    "capybara": dict(rib=1.02, waist=0.96, pelvis=1.02, belly=1.00, skull_width=1.04, skull_height=1.00, muzzle_width=1.02, muzzle_height=0.82, muzzle_length=0.92, eye_scale=0.040, ear_width=0.42, muscle=0.84, foot_width=0.90),
    "otter": dict(rib=0.82, waist=0.70, pelvis=0.88, belly=0.76, skull_width=1.02, skull_height=0.90, muzzle_width=0.82, muzzle_height=0.58, muzzle_length=0.82, eye_scale=0.050, ear_width=0.40, muscle=0.68, foot_width=1.12),
    "lynx": dict(rib=0.92, waist=0.72, pelvis=1.00, belly=0.86, skull_width=1.08, skull_height=1.00, muzzle_width=0.78, muzzle_height=0.66, muzzle_length=0.72, eye_scale=0.058, ear_width=0.44, muscle=0.84, foot_width=1.06),
    "goat": dict(rib=0.90, waist=0.70, pelvis=0.82, belly=0.80, skull_width=0.78, skull_height=0.82, muzzle_width=0.68, muzzle_height=0.60, muzzle_length=1.08, eye_scale=0.050, ear_width=0.42, muscle=0.72, foot_width=0.62),
    "wolverine": dict(rib=1.08, waist=0.90, pelvis=1.02, belly=0.94, skull_width=1.06, skull_height=0.92, muzzle_width=0.84, muzzle_height=0.68, muzzle_length=0.86, eye_scale=0.044, ear_width=0.48, muscle=1.00, foot_width=1.16),
    "bison": dict(rib=1.18, waist=0.84, pelvis=0.90, belly=0.96, skull_width=1.08, skull_height=0.92, muzzle_width=0.92, muzzle_height=0.72, muzzle_length=1.04, eye_scale=0.040, ear_width=0.40, muscle=1.04, foot_width=0.70),
    "zebra": dict(rib=0.94, waist=0.68, pelvis=0.86, belly=0.78, skull_width=0.76, skull_height=0.78, muzzle_width=0.66, muzzle_height=0.56, muzzle_length=1.18, eye_scale=0.048, ear_width=0.40, muscle=0.72, foot_width=0.58),
    "elephant": dict(rib=1.10, waist=0.98, pelvis=1.04, belly=1.10, skull_width=1.08, skull_height=1.00, skull_length=0.86, muzzle_width=0.74, muzzle_height=0.68, muzzle_length=0.72, eye_scale=0.032, ear_width=0.0, muscle=1.02, foot_width=1.18),
    "tiger": dict(rib=1.04, waist=0.68, pelvis=1.02, belly=0.82, skull_width=1.06, skull_height=0.92, muzzle_width=0.84, muzzle_height=0.68, muzzle_length=0.82, eye_scale=0.056, ear_width=0.46, muscle=0.98, foot_width=1.00),
    "monkey": dict(rib=0.92, waist=0.70, pelvis=0.90, belly=0.82, skull_width=1.02, skull_height=1.10, skull_length=0.76, muzzle_width=0.82, muzzle_height=0.62, muzzle_length=0.64, eye_scale=0.052, ear_width=0.52, muscle=0.74, foot_width=1.14),
    "moose": dict(rib=1.00, waist=0.72, pelvis=0.84, belly=0.86, skull_width=0.82, skull_height=0.82, muzzle_width=0.78, muzzle_height=0.66, muzzle_length=1.24, eye_scale=0.044, ear_width=0.42, muscle=0.78, foot_width=0.62),
    "turtle": dict(rib=1.08, waist=1.04, pelvis=1.08, belly=0.66, skull_width=0.86, skull_height=0.70, muzzle_width=0.76, muzzle_height=0.58, muzzle_length=0.82, eye_scale=0.046, muscle=0.68, foot_width=1.16),
    "cheetah": dict(rib=0.82, waist=0.56, pelvis=0.88, belly=0.70, skull_width=0.86, skull_height=0.82, muzzle_width=0.72, muzzle_height=0.56, muzzle_length=0.82, eye_scale=0.058, ear_width=0.44, muscle=0.70, foot_width=0.82),
    "rhino": dict(rib=1.10, waist=0.96, pelvis=1.04, belly=1.02, skull_width=0.94, skull_height=0.78, muzzle_width=1.00, muzzle_height=0.78, muzzle_length=1.24, eye_scale=0.032, ear_width=0.42, muscle=1.02, foot_width=1.10),
    "gorilla": dict(rib=1.20, waist=0.78, pelvis=0.90, belly=0.92, skull_width=1.12, skull_height=1.04, skull_length=0.78, muzzle_width=1.02, muzzle_height=0.78, muzzle_length=0.68, eye_scale=0.042, ear_width=0.46, muscle=1.16, foot_width=1.22),
    "hippo": dict(rib=1.12, waist=1.02, pelvis=1.10, belly=1.10, skull_width=1.18, skull_height=0.82, skull_length=1.08, muzzle_width=1.24, muzzle_height=0.82, muzzle_length=1.10, eye_scale=0.034, ear_width=0.42, muscle=1.02, foot_width=1.18),
    "hyena": dict(rib=1.08, waist=0.70, pelvis=0.80, belly=0.78, skull_width=1.00, skull_height=0.88, muzzle_width=0.82, muzzle_height=0.66, muzzle_length=1.06, eye_scale=0.050, ear_width=0.48, muscle=0.84, foot_width=0.88),
    "lion": dict(rib=1.08, waist=0.72, pelvis=0.98, belly=0.86, skull_width=1.12, skull_height=1.00, muzzle_width=0.88, muzzle_height=0.72, muzzle_length=0.82, eye_scale=0.052, ear_width=0.44, muscle=1.00, foot_width=1.02),
}


V5_SURFACE = {
    "canid": dict(coat_roughness=0.86, accent_roughness=0.82, detail_roughness=0.70),
    "felid": dict(coat_roughness=0.84, accent_roughness=0.80, detail_roughness=0.68),
    "ungulate": dict(coat_roughness=0.82, accent_roughness=0.78, detail_roughness=0.62),
    "heavy": dict(coat_roughness=0.80, accent_roughness=0.74, detail_roughness=0.58),
    "primate": dict(coat_roughness=0.84, accent_roughness=0.72, detail_roughness=0.58),
    "chelonian": dict(coat_roughness=0.72, accent_roughness=0.64, detail_roughness=0.50),
}


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Build the remaining Eco Rebirth V5 near-realistic species")
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--species", nargs="*", choices=REMAINING_SPECIES)
    return parser.parse_args(argv)


def g2b(value: tuple[float, float, float]) -> tuple[float, float, float]:
    return value[0], value[2], value[1]


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.metaballs, bpy.data.armatures, bpy.data.materials, bpy.data.actions):
        for datablock in list(datablocks):
            datablocks.remove(datablock)


def rgba(value: str) -> tuple[float, float, float, float]:
    value = value.removeprefix("#")
    return tuple(int(value[index:index + 2], 16) / 255.0 for index in (0, 2, 4)) + (1.0,)


def pbr_material(name: str, color: str, roughness: float, metallic: float = 0.0) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = rgba(color)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled is not None:
        principled.inputs["Base Color"].default_value = rgba(color)
        principled.inputs["Roughness"].default_value = roughness
        principled.inputs["Metallic"].default_value = metallic
        if "Specular IOR Level" in principled.inputs:
            principled.inputs["Specular IOR Level"].default_value = 0.32 if "eye" not in name else 0.50
    material["eco_pbr_surface"] = "v5_near_realistic"
    material["eco_roughness"] = roughness
    return material


def authored_mesh(
    name: str,
    vertices_godot: list[tuple[float, float, float]],
    faces: list[tuple[int, ...]],
    materials: list[bpy.types.Material],
    material_indices: list[int] | None = None,
) -> bpy.types.Object:
    """Build a compact authored silhouette instead of another inflated sphere."""
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata([g2b(vertex) for vertex in vertices_godot], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for material in materials:
        obj.data.materials.append(material)
    for index, polygon in enumerate(obj.data.polygons):
        polygon.use_smooth = True
        if material_indices is not None and index < len(material_indices):
            polygon.material_index = material_indices[index]
    return obj


def ear_leaf(
    name: str,
    base: tuple[float, float, float],
    tip: tuple[float, float, float],
    width: float,
    thickness: float,
    outer: bpy.types.Material,
    inner: bpy.types.Material,
    hero: bool,
) -> list[bpy.types.Object]:
    """Create a tapered mammal pinna with a recessed inner panel."""
    base_v = Vector(base)
    tip_v = Vector(tip)
    middle = base_v.lerp(tip_v, 0.56)
    centres = (base_v, middle, tip_v)
    widths = (width * 0.78, width, width * 0.10)
    vertices: list[tuple[float, float, float]] = []
    for depth in (-thickness, thickness):
        for centre, half_width in zip(centres, widths):
            vertices.append((centre.x - half_width, centre.y, centre.z + depth))
            vertices.append((centre.x + half_width, centre.y, centre.z + depth))
    faces = [
        (0, 2, 3, 1), (2, 4, 5, 3),
        (7, 9, 8, 6), (9, 11, 10, 8),
        (0, 6, 8, 2), (2, 8, 10, 4),
        (1, 3, 9, 7), (3, 5, 11, 9),
        (0, 1, 7, 6), (4, 10, 11, 5),
    ]
    ear = authored_mesh(name, vertices, faces, [outer], [0] * len(faces))
    bevel = ear.modifiers.new("PinnaEdge", "BEVEL")
    bevel.width = max(thickness * 0.65, 0.008)
    bevel.segments = 2 if hero else 1
    bpy.context.view_layer.objects.active = ear
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    result = [ear]
    if hero:
        inset_base = base_v.lerp(tip_v, 0.13)
        inset_tip = base_v.lerp(tip_v, 0.86)
        inset_mid = inset_base.lerp(inset_tip, 0.56)
        panel_vertices = [
            (inset_base.x - width * 0.42, inset_base.y, inset_base.z - thickness * 1.10),
            (inset_base.x + width * 0.42, inset_base.y, inset_base.z - thickness * 1.10),
            (inset_mid.x + width * 0.50, inset_mid.y, inset_mid.z - thickness * 1.10),
            (inset_tip.x, inset_tip.y, inset_tip.z - thickness * 1.10),
            (inset_mid.x - width * 0.50, inset_mid.y, inset_mid.z - thickness * 1.10),
        ]
        panel = authored_mesh(f"{name}InnerDetail", panel_vertices, [(0, 1, 2, 3, 4)], [inner], [0])
        result.append(panel)
    return result


def elephant_ear_fan(
    name: str,
    side: float,
    centre: tuple[float, float, float],
    height: float,
    outer: bpy.types.Material,
    inner: bpy.types.Material,
    hero: bool,
) -> list[bpy.types.Object]:
    """African-elephant ear with a broad, thin fan rather than an ellipsoid."""
    x, y, z = centre
    outward = side * height * 0.72
    vertices = [
        (x, y + height * 0.35, z),
        (x + outward * 0.72, y + height * 0.42, z + height * 0.08),
        (x + outward, y, z + height * 0.13),
        (x + outward * 0.78, y - height * 0.48, z + height * 0.06),
        (x + outward * 0.28, y - height * 0.58, z - height * 0.04),
    ]
    back = [(vx, vy, vz + 0.035) for vx, vy, vz in vertices]
    faces = [(0, 1, 2, 3, 4), (9, 8, 7, 6, 5)]
    for index in range(5):
        next_index = (index + 1) % 5
        faces.append((index, next_index, 5 + next_index, 5 + index))
    fan = authored_mesh(name, vertices + back, faces, [outer], [0] * len(faces))
    result = [fan]
    if hero:
        inset = [tuple(Vector(centre).lerp(Vector(vertex), 0.78)) for vertex in vertices]
        inset = [(vx, vy, vz - 0.008) for vx, vy, vz in inset]
        result.append(authored_mesh(f"{name}InnerDetail", inset, [(0, 1, 2, 3, 4)], [inner], [0]))
    return result


def append_material(obj: bpy.types.Object, material: bpy.types.Material) -> int:
    for index, current in enumerate(obj.data.materials):
        if current == material:
            return index
    obj.data.materials.append(material)
    return len(obj.data.materials) - 1


def paint_ground_surface(
    obj: bpy.types.Object,
    species: str,
    cfg: dict,
    layout: dict,
    accent: bpy.types.Material,
    dark: bpy.types.Material,
) -> None:
    """Assign flush coat markings to torso polygons; never inflate spots/stripes."""
    accent_index = append_material(obj, accent)
    dark_index = append_material(obj, dark)
    features = cfg["features"]
    body_y = float(layout["body_y"])
    for polygon in obj.data.polygons:
        if not polygon.vertices:
            continue
        centre_b = sum((obj.data.vertices[index].co for index in polygon.vertices), Vector()) / len(polygon.vertices)
        x, y, z = centre_b.x, centre_b.z, centre_b.y
        normalized_z = z / max(float(cfg["length"]), 0.2)
        normalized_x = abs(x) / max(float(cfg["width"]), 0.2)
        material_index = 0
        underside = y < body_y - float(cfg["height"]) * 0.42 and z > layout["neck_z"] + cfg["head"] * 0.2
        if underside and cfg["family"] not in ("primate", "chelonian"):
            material_index = accent_index
        if "stripes" in features:
            if species == "zebra":
                wave = math.sin(normalized_z * math.pi * 7.0 + y * 2.2 + normalized_x * 1.4)
                if wave > 0.58 and y > body_y - cfg["height"] * 0.38:
                    material_index = dark_index
            elif species == "tiger":
                wave = math.sin(normalized_z * math.pi * 7.0 + y * 2.3 + normalized_x * 1.2)
                if wave > 0.64 and y > body_y - cfg["height"] * 0.32 and normalized_x > 0.30:
                    material_index = dark_index
            else:
                wave = math.sin(normalized_z * math.pi * 8.6 + y * 2.8 + normalized_x * 1.9)
                if abs(wave) > 0.67 and y > body_y - cfg["height"] * 0.34:
                    material_index = dark_index
        elif "spots" in features:
            spot_field = math.sin(x * 18.7 + z * 8.9) * math.cos(y * 15.1 - z * 5.7)
            if spot_field > (0.48 if species == "cheetah" else 0.56) and normalized_x > 0.34:
                material_index = dark_index
        if "side_band" in features and normalized_x > 0.52 and y > body_y - cfg["height"] * 0.15:
            material_index = accent_index
        if "silverback" in features and y > body_y + cfg["height"] * 0.16 and z > layout["front_z"] * 0.25:
            material_index = accent_index
        polygon.material_index = material_index
    obj["eco_surface_pattern"] = "v5_flush_material_regions"


def metaball_mesh(name: str, elements: list[tuple[tuple[float, float, float], tuple[float, float, float], float]], material: bpy.types.Material, hero: bool) -> bpy.types.Object:
    data = bpy.data.metaballs.new(f"{name}Surface")
    data.resolution = 0.050 if hero else 0.075
    data.render_resolution = 0.038 if hero else 0.058
    # Keep the animal as one continuous fleshed silhouette.  At 0.62 the torso,
    # lower legs, paws, ears and tail exported as separate mesh islands, which
    # made the skinned result look like an exposed skeleton in Godot.
    data.threshold = 0.46
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    for position, scale, stiffness in elements:
        element = data.elements.new(type="ELLIPSOID")
        element.co = g2b(position)
        element.radius = 1.0
        element.size_x, element.size_y, element.size_z = scale[0], scale[2], scale[1]
        element.stiffness = stiffness
    obj.data.materials.append(material)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    obj.name = name
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def uv_sphere(name: str, position: tuple[float, float, float], scale: tuple[float, float, float], material: bpy.types.Material, hero: bool) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16 if hero else 10, ring_count=10 if hero else 6, location=g2b(position))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (scale[0], scale[2], scale[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def cone_between(name: str, start: tuple[float, float, float], end: tuple[float, float, float], radius: float, material: bpy.types.Material, hero: bool) -> bpy.types.Object:
    start_b = Vector(g2b(start))
    end_b = Vector(g2b(end))
    delta = end_b - start_b
    bpy.ops.mesh.primitive_cone_add(vertices=10 if hero else 7, radius1=radius, radius2=radius * 0.08, depth=delta.length, location=(start_b + end_b) * 0.5)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def ellipsoid_between(
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    radius: float,
    material: bpy.types.Material,
    hero: bool,
    flatten: float = 1.0,
) -> bpy.types.Object:
    """Create a smooth tapered-looking limb segment aligned between two Godot-space points."""
    start_b = Vector(g2b(start))
    end_b = Vector(g2b(end))
    delta = end_b - start_b
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=16 if hero else 10,
        ring_count=10 if hero else 6,
        location=(start_b + end_b) * 0.5,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    obj.scale = (radius, radius * flatten, max(delta.length * 0.54, radius))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def tapered_segment_between(
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    start_radius: float,
    end_radius: float,
    material: bpy.types.Material,
    hero: bool,
) -> bpy.types.Object:
    """Create a softly bevelled tapered segment for species-specific limbs."""
    start_b = Vector(g2b(start))
    end_b = Vector(g2b(end))
    delta = end_b - start_b
    bpy.ops.mesh.primitive_cone_add(
        vertices=16 if hero else 10,
        radius1=end_radius,
        radius2=start_radius,
        depth=delta.length * 1.04,
        location=(start_b + end_b) * 0.5,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    bevel = obj.modifiers.new("OrganicEdge", "BEVEL")
    bevel.width = min(start_radius, end_radius) * 0.42
    bevel.segments = 2 if hero else 1
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def tapered_flat_blade(
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    start_width: float,
    end_width: float,
    thickness: float,
    material: bpy.types.Material,
    hero: bool,
) -> bpy.types.Object:
    """Create a tapered, flattened feather blade in the horizontal flight plane."""
    start_b = Vector(g2b(start))
    end_b = Vector(g2b(end))
    direction = (end_b - start_b).normalized()
    vertical = Vector((0.0, 0.0, 1.0))
    transverse = direction.cross(vertical).normalized()
    vertices = []
    for centre, width in ((start_b, start_width), (end_b, end_width)):
        for side in (-1.0, 1.0):
            for height in (-1.0, 1.0):
                vertices.append(tuple(centre + transverse * width * side + vertical * thickness * height))
    faces = [
        (0, 1, 3, 2), (4, 6, 7, 5),
        (0, 4, 5, 1), (2, 3, 7, 6),
        (0, 2, 6, 4), (1, 5, 7, 3),
    ]
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bevel = obj.modifiers.new("FeatherEdge", "BEVEL")
    bevel.width = min(start_width, max(end_width, 0.025)) * 0.28
    bevel.segments = 2 if hero else 1
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def add_bone(edit_bones, name: str, head: tuple[float, float, float], tail: tuple[float, float, float], parent=None):
    result = edit_bones.new(name)
    result.head = g2b(head)
    result.tail = g2b(tail)
    result.parent = parent
    return result


def add_armature_weights(obj: bpy.types.Object, rig: bpy.types.Object, weights: dict[str, list[float]]) -> None:
    # The glTF exporter can infer an armature for an unparented skinned object,
    # but that path emits warnings and may produce fragile inverse bind matrices.
    # Keep the authored world transform while making the relationship explicit.
    world_transform = obj.matrix_world.copy()
    obj.parent = rig
    obj.matrix_world = world_transform
    modifier = obj.modifiers.new("SpeciesArmature", "ARMATURE")
    modifier.object = rig
    for bone_name, values in weights.items():
        group = obj.vertex_groups.new(name=bone_name)
        for vertex_index, value in enumerate(values):
            if value > 0.001:
                group.add([vertex_index], value, "REPLACE")


def rigid_skin(obj: bpy.types.Object, rig: bpy.types.Object, bone_name: str) -> None:
    add_armature_weights(obj, rig, {bone_name: [1.0] * len(obj.data.vertices)})


def attach_socket(name: str, position: tuple[float, float, float], rig: bpy.types.Object, bone_name: str) -> bpy.types.Object:
    socket = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(socket)
    socket.empty_display_type = "SPHERE"
    socket.empty_display_size = 0.08
    socket.parent = rig
    socket.parent_type = "BONE"
    socket.parent_bone = bone_name
    # Bone parenting changes the empty's local basis. Assign the desired world
    # transform afterwards so Godot receives a true bone-relative socket instead
    # of interpreting a model-space position a second time.
    socket.matrix_world = Matrix.Translation(g2b(position))
    return socket


def config_for(species: str) -> dict:
    specific = SPECIES[species]
    result = dict(FAMILY_BASE[specific["family"]])
    result.update(specific)
    result["species"] = species
    result["features"] = set(result.get("features", ()))
    profile = dict(V3_FAMILY_PROFILE[result["family"]])
    profile.update(V3_SPECIES_PROFILE.get(species, {}))
    result["v3"] = profile
    anatomy = dict(V5_FAMILY_ANATOMY[result["family"]])
    anatomy.update(V5_SPECIES_ANATOMY.get(species, {}))
    result["v5"] = anatomy
    result["surface"] = dict(V5_SURFACE[result["family"]])
    return result


def ground_layout(cfg: dict) -> dict:
    if cfg["family"] == "primate":
        # Primates carry a short, steep torso over the hips.  A conventional
        # quadruped layout made the macaque and gorilla read like canids even
        # though their arm lengths differed, so give them a raised shoulder
        # girdle and compressed fore-aft body here.
        body_y = cfg["leg"] + cfg["height"] * 0.66
        shoulder_y = body_y + cfg["height"] * (0.62 if cfg["species"] == "gorilla" else 0.54)
        front_z = -cfg["length"] * 0.18
        rear_z = cfg["length"] * 0.20
        neck_z = -cfg["length"] * 0.34
        head_z = neck_z - cfg["neck"] * 0.42
        head_y = shoulder_y + cfg["neck"] * 0.70
        muzzle_z = head_z - cfg["muzzle"]
        return dict(body_y=body_y, shoulder_y=shoulder_y, front_z=front_z, rear_z=rear_z, neck_z=neck_z, head_z=head_z, head_y=head_y, muzzle_z=muzzle_z)
    body_y = cfg["leg"] + cfg["height"] * 0.72
    mass_pitch = (float(cfg["v3"]["chest_mass"]) - float(cfg["v3"]["rump_mass"])) * cfg["height"] * 0.28
    shoulder_y = body_y + mass_pitch + (0.14 if "high_shoulders" in cfg["features"] or "shoulder_hump" in cfg["features"] else 0.03)
    front_z = -cfg["length"] * 0.36
    rear_z = cfg["length"] * 0.36
    neck_z = -cfg["length"] * 0.78
    head_z = neck_z - cfg["neck"] * 0.62
    head_y = shoulder_y + cfg["neck"] * (0.68 if cfg["family"] != "chelonian" else 0.18)
    muzzle_z = head_z - cfg["muzzle"]
    return dict(body_y=body_y, shoulder_y=shoulder_y, front_z=front_z, rear_z=rear_z, neck_z=neck_z, head_z=head_z, head_y=head_y, muzzle_z=muzzle_z)


def ground_limb_points(
    cfg: dict,
    layout: dict,
    suffix: str,
) -> tuple[
    tuple[float, float, float],
    tuple[float, float, float],
    tuple[float, float, float],
    tuple[float, float, float],
]:
    profile = cfg["v3"]
    limb_profile = V4_LIMB_PROFILE[cfg["family"]]
    side = -1.0 if suffix.startswith("L") else 1.0
    front = suffix.endswith("F")
    z = layout["front_z"] if front else layout["rear_z"]
    leg_scale = float(profile["fore_scale"] if front else profile["rear_scale"])
    leg_length = cfg["leg"] * leg_scale
    hip_y = layout["shoulder_y"] if front else layout["body_y"]
    hip = (side * cfg["width"] * float(profile["stance"]), hip_y, z)
    joint_z = z + leg_length * float(limb_profile["front_joint"] if front else limb_profile["hind_joint"])
    ankle_z = z + leg_length * float(limb_profile["front_ankle"] if front else limb_profile["hind_ankle"])
    joint = (
        side * cfg["width"] * (float(profile["stance"]) + 0.04),
        max(0.34, hip_y - leg_length * float(limb_profile["joint_drop"])),
        joint_z,
    )
    ankle = (
        side * cfg["width"] * (float(profile["stance"]) + 0.06),
        max(0.17, leg_length * float(limb_profile["ankle_height"])),
        ankle_z,
    )
    toe = (
        side * cfg["width"] * (float(profile["stance"]) + 0.07),
        0.10,
        ankle_z - leg_length * float(limb_profile["toe_forward"]),
    )
    return hip, joint, ankle, toe


def deer_limb_points(
    suffix: str,
) -> tuple[
    tuple[float, float, float],
    tuple[float, float, float],
    tuple[float, float, float],
    tuple[float, float, float],
]:
    """Anatomical three-link deer leg guides in Godot space (Y up, -Z forward)."""
    side = -1.0 if suffix.startswith("L") else 1.0
    if suffix.endswith("F"):
        return (
            (side * 0.40, 1.72, -0.58),
            (side * 0.42, 1.00, -0.47),
            (side * 0.43, 0.28, -0.62),
            (side * 0.43, 0.10, -0.83),
        )
    return (
        (side * 0.42, 1.68, 0.58),
        (side * 0.44, 1.02, 0.34),
        (side * 0.44, 0.30, 0.80),
        (side * 0.44, 0.10, 0.48),
    )


def build_deer_rig() -> tuple[bpy.types.Object, dict[str, tuple[float, float, float]]]:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    rig = bpy.context.active_object
    rig.name = "SpeciesSkeleton3D"
    rig.data.name = "DeerV3Rig"
    edit = rig.data.edit_bones
    root = edit[0]
    root.name = "Root"
    root.head = g2b((0.0, 0.05, 0.24))
    root.tail = g2b((0.0, 0.55, 0.24))
    spine = add_bone(edit, "Spine", (0.0, 1.66, 0.72), (0.0, 1.69, 0.10), root)
    chest = add_bone(edit, "Chest", (0.0, 1.69, 0.10), (0.0, 1.76, -0.62), spine)
    neck = add_bone(edit, "Neck", (0.0, 1.76, -0.62), (0.0, 2.18, -1.24), chest)
    head = add_bone(edit, "Head", (0.0, 2.18, -1.24), (0.0, 2.13, -2.12), neck)
    add_bone(edit, "Jaw", (0.0, 2.08, -1.62), (0.0, 2.02, -2.18), head)
    anchors: dict[str, tuple[float, float, float]] = {
        "Spine": (0.0, 1.67, 0.52),
        "Chest": (0.0, 1.73, -0.43),
        "Neck": (0.0, 1.99, -0.94),
        "Head": (0.0, 2.17, -1.65),
    }
    for suffix in LIMBS:
        hip, joint, ankle, toe = deer_limb_points(suffix)
        upper = add_bone(edit, f"Leg_{suffix}", hip, joint, chest if suffix.endswith("F") else spine)
        lower = add_bone(edit, f"Lower_{suffix}", joint, ankle, upper)
        add_bone(edit, f"Paw_{suffix}", ankle, toe, lower)
        anchors[f"Leg_{suffix}"] = tuple((Vector(hip) + Vector(joint)) * 0.5)
        anchors[f"Lower_{suffix}"] = tuple((Vector(joint) + Vector(ankle)) * 0.5)
        anchors[f"Paw_{suffix}"] = tuple((Vector(ankle) + Vector(toe)) * 0.5)
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        ear_base = (side * 0.20, 2.37, -1.43)
        ear_tip = (side * 0.40, 2.60, -1.31)
        add_bone(edit, f"Ear_{suffix}", ear_base, ear_tip, head)
        anchors[f"Ear_{suffix}"] = tuple((Vector(ear_base) + Vector(ear_tip)) * 0.5)
    tail_base = (0.0, 1.70, 0.84)
    tail_mid = (0.0, 1.60, 1.02)
    tail_tip = (0.0, 1.48, 1.18)
    tail = add_bone(edit, "Tail", tail_base, tail_mid, spine)
    add_bone(edit, "TailTip", tail_mid, tail_tip, tail)
    anchors["Tail"] = tuple((Vector(tail_base) + Vector(tail_mid)) * 0.5)
    anchors["TailTip"] = tuple((Vector(tail_mid) + Vector(tail_tip)) * 0.5)
    bpy.ops.object.mode_set(mode="OBJECT")
    rig["eco_species"] = "deer"
    rig["eco_rig_family"] = "ungulate_v3"
    rig["anatomy_profile"] = "v5_near_realistic_species_anatomy_three_segment_limbs"
    rig["surface_profile"] = "v5_flush_markings_facial_landmarks"
    rig["limb_segments"] = 3
    return rig, anchors


def skin_deer_body(body: bpy.types.Object, rig: bpy.types.Object, anchors: dict[str, tuple[float, float, float]]) -> None:
    body_bones = ("Spine", "Chest", "Neck", "Head")
    scales = {
        "Spine": Vector((0.78, 0.68, 0.86)),
        "Chest": Vector((0.72, 0.72, 0.82)),
        "Neck": Vector((0.45, 0.72, 0.62)),
        "Head": Vector((0.48, 0.48, 0.78)),
    }
    weights = {name: [] for name in body_bones}
    for vertex in body.data.vertices:
        point = Vector((vertex.co.x, vertex.co.z, vertex.co.y))
        raw = {}
        for name in body_bones:
            delta = point - Vector(anchors[name])
            distance = math.sqrt(sum((delta[index] / scales[name][index]) ** 2 for index in range(3)))
            raw[name] = max(0.0, 1.0 - distance) ** 2
        total = sum(raw.values())
        if total < 0.0001:
            nearest = min(body_bones, key=lambda name: (point - Vector(anchors[name])).length)
            raw[nearest] = 1.0
            total = 1.0
        for name in body_bones:
            weights[name].append(raw[name] / total)
    add_armature_weights(body, rig, weights)


def build_deer_parts(hero: bool, rig: bpy.types.Object, anchors: dict) -> list[bpy.types.Object]:
    """AI-art-directed deer benchmark: species-specific silhouette, anatomy and details."""
    coat = pbr_material("deer_coat_pbr", "#96592f", 0.86)
    accent = pbr_material("deer_accent_pbr", "#d7b47c", 0.82)
    dark = pbr_material("deer_detail_pbr", "#3b291f", 0.62)
    eye = pbr_material("deer_eye_pbr", "#17100c", 0.08)
    horn = pbr_material("deer_keratin_pbr", "#8d7352", 0.70)

    body_elements = [
        ((0.0, 1.67, 0.58), (0.57, 0.57, 0.72), 2.30),
        ((0.0, 1.66, 0.08), (0.55, 0.59, 0.76), 2.35),
        ((0.0, 1.73, -0.48), (0.54, 0.64, 0.63), 2.35),
        ((0.0, 1.78, -0.70), (0.40, 0.49, 0.40), 2.20),
        ((0.0, 1.90, -0.86), (0.34, 0.47, 0.40), 2.20),
        ((0.0, 2.04, -1.06), (0.30, 0.43, 0.37), 2.18),
        ((0.0, 2.18, -1.30), (0.29, 0.33, 0.34), 2.18),
        ((0.0, 2.22, -1.52), (0.32, 0.34, 0.39), 2.25),
        ((0.0, 2.16, -1.79), (0.25, 0.25, 0.38), 2.18),
        ((0.0, 2.10, -2.04), (0.19, 0.17, 0.27), 2.12),
    ]
    body = metaball_mesh("DeerOrganicBodyV2SourceConnected", body_elements, coat, hero)
    body["eco_anatomy_contract"] = "v5_cervid_rib_waist_pelvis_skull_muzzle"
    skin_deer_body(body, rig, anchors)
    parts = [body]

    def sphere(name: str, pos, scale, material=accent, bone_name="Head"):
        obj = uv_sphere(name, pos, scale, material, hero)
        rigid_skin(obj, rig, bone_name)
        parts.append(obj)
        return obj

    def limb(name: str, start, end, start_radius, end_radius, material, bone_name):
        obj = tapered_segment_between(name, start, end, start_radius, end_radius, material, hero)
        rigid_skin(obj, rig, bone_name)
        parts.append(obj)
        return obj

    def cone(name: str, start, end, radius, material=horn, bone_name="Head"):
        obj = cone_between(name, start, end, radius, material, hero)
        rigid_skin(obj, rig, bone_name)
        parts.append(obj)
        return obj

    for suffix in LIMBS:
        hip, joint, ankle, toe = deer_limb_points(suffix)
        front = suffix.endswith("F")
        shoulder_bone = "Chest" if front else "Spine"
        sphere(
            f"DeerMuscle_{suffix}",
            tuple(Vector(hip).lerp(Vector(joint), 0.18)),
            (0.20 if front else 0.26, 0.34 if front else 0.40, 0.24 if front else 0.31),
            coat,
            shoulder_bone,
        )
        limb(
            f"DeerUpperLeg_{suffix}",
            hip,
            tuple(Vector(joint).lerp(Vector(hip), -0.06)),
            0.18 if front else 0.22,
            0.105 if front else 0.12,
            coat,
            f"Leg_{suffix}",
        )
        limb(
            f"DeerLowerLeg_{suffix}",
            tuple(Vector(joint).lerp(Vector(ankle), -0.06)),
            ankle,
            0.105 if front else 0.12,
            0.060 if front else 0.067,
            coat,
            f"Lower_{suffix}",
        )
        if hero:
            sphere(f"DeerJoint_{suffix}", joint, (0.082, 0.089, 0.085), coat, f"Lower_{suffix}")
        limb(
            f"DeerMetapodial_{suffix}",
            ankle,
            toe,
            0.062 if front else 0.068,
            0.050 if front else 0.056,
            coat,
            f"Paw_{suffix}",
        )
        if hero:
            sphere(f"DeerHock_{suffix}", ankle, (0.072, 0.082, 0.074), coat, f"Paw_{suffix}")
        hoof_z = toe[2] - 0.055
        sphere(
            f"DeerHoofDetail_{suffix}",
            (toe[0], 0.085, hoof_z),
            (0.085, 0.065, 0.15),
            dark,
            f"Paw_{suffix}",
        )
        if hero:
            for digit_side in (-1.0, 1.0):
                sphere(
                    f"DeerSplitHoofDetail_{suffix}_{digit_side:+.0f}",
                    (toe[0] + digit_side * 0.047, 0.072, hoof_z - 0.055),
                    (0.042, 0.054, 0.105),
                    dark,
                    f"Paw_{suffix}",
                )

    for suffix, side in (("L", -1.0), ("R", 1.0)):
        ear_base = (side * 0.20, 2.37, -1.43)
        ear_tip = (side * 0.40, 2.60, -1.31)
        for ear_part in ear_leaf(f"V5DeerEarSilhouette_{suffix}", ear_base, ear_tip, 0.105, 0.018, coat, accent, hero):
            rigid_skin(ear_part, rig, f"Ear_{suffix}")
            parts.append(ear_part)
        eye_pos = (side * 0.292, 2.27, -1.68)
        sphere(f"V5DeerEyeDetail_{suffix}", eye_pos, (0.034, 0.040, 0.027), eye, "Head")
        if hero:
            sphere(f"V5DeerUpperEyelidDetail_{suffix}", (eye_pos[0], eye_pos[1] + 0.027, eye_pos[2] + 0.005), (0.048, 0.017, 0.035), coat, "Head")

    sphere("DeerMuzzlePatchDetail", (0.0, 2.10, -2.02), (0.19, 0.15, 0.24), accent, "Head")
    sphere("V5DeerNoseDetail", (0.0, 2.08, -2.27), (0.13, 0.090, 0.105), dark, "Head")
    if hero:
        for side in (-1.0, 1.0):
            sphere(f"V5DeerNostrilDetail_{side:+.0f}", (side * 0.065, 2.095, -2.355), (0.022, 0.017, 0.014), dark, "Head")
    sphere("DeerThroatPatchDetail", (0.0, 1.93, -1.12), (0.20, 0.34, 0.13), accent, "Neck")
    tail = ellipsoid_between("DeerTail", (0.0, 1.70, 0.84), (0.0, 1.48, 1.18), 0.15, accent, hero, 0.72)
    rigid_skin(tail, rig, "TailTip")
    parts.append(tail)

    jaw = ellipsoid_between("DeerLowerJawDetail", (0.0, 2.06, -1.72), (0.0, 2.00, -2.17), 0.115, accent, hero, 0.58)
    rigid_skin(jaw, rig, "Jaw")
    parts.append(jaw)

    for side in (-1.0, 1.0):
        antler_base = (side * 0.18, 2.40, -1.50)
        beam_mid = (side * 0.30, 2.76, -1.40)
        beam_tip = (side * 0.39, 3.05, -1.23)
        cone(f"DeerAntlerBase_{side:+.0f}", antler_base, beam_mid, 0.055)
        cone(f"DeerAntlerBeam_{side:+.0f}", beam_mid, beam_tip, 0.043)
        cone(
            f"DeerAntlerBrow_{side:+.0f}",
            tuple(Vector(antler_base).lerp(Vector(beam_mid), 0.46)),
            (side * 0.47, 2.74, -1.74),
            0.036,
        )
        cone(
            f"DeerAntlerRoyal_{side:+.0f}",
            tuple(Vector(beam_mid).lerp(Vector(beam_tip), 0.42)),
            (side * 0.62, 3.05, -1.47),
            0.032,
        )

    attach_socket("SkillSocket_Mouth", (0.0, 2.10, -2.30), rig, "Head")
    attach_socket("SkillSocket_Chest", (0.0, 1.72, -0.58), rig, "Chest")
    return parts


def build_ground_rig(species: str, cfg: dict, layout: dict) -> tuple[bpy.types.Object, dict[str, tuple[float, float, float]]]:
    if species == "deer":
        return build_deer_rig()
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    rig = bpy.context.active_object
    rig.name = "SpeciesSkeleton3D"
    rig.data.name = f"{species.title()}V2Rig"
    edit = rig.data.edit_bones
    root = edit[0]
    root.name = "Root"
    root.head = g2b((0.0, 0.05, 0.25))
    root.tail = g2b((0.0, 0.55, 0.25))
    anchors: dict[str, tuple[float, float, float]] = {}
    spine = add_bone(edit, "Spine", (0.0, layout["body_y"], cfg["length"] * 0.42), (0.0, layout["body_y"], 0.06), root)
    chest = add_bone(edit, "Chest", (0.0, layout["body_y"], 0.06), (0.0, layout["shoulder_y"], layout["front_z"]), spine)
    neck = add_bone(edit, "Neck", (0.0, layout["shoulder_y"], layout["front_z"]), (0.0, layout["head_y"], layout["neck_z"]), chest)
    head = add_bone(edit, "Head", (0.0, layout["head_y"], layout["neck_z"]), (0.0, layout["head_y"], layout["muzzle_z"] - 0.12), neck)
    anchors.update(Spine=(0.0, layout["body_y"], layout["rear_z"]), Chest=(0.0, layout["shoulder_y"], layout["front_z"]), Neck=(0.0, layout["head_y"], layout["neck_z"]), Head=(0.0, layout["head_y"], layout["head_z"] - cfg["muzzle"] * 0.30))
    add_bone(
        edit,
        "Jaw",
        (0.0, layout["head_y"] - cfg["head"] * 0.20, layout["head_z"] - cfg["head"] * 0.30),
        (0.0, layout["head_y"] - cfg["head"] * 0.24, layout["muzzle_z"] - cfg["muzzle"] * 0.72),
        head,
    )
    for suffix in LIMBS:
        front = suffix.endswith("F")
        hip, joint, ankle, toe = ground_limb_points(cfg, layout, suffix)
        upper = add_bone(edit, f"Leg_{suffix}", hip, joint, chest if front else spine)
        lower = add_bone(edit, f"Lower_{suffix}", joint, ankle, upper)
        add_bone(edit, f"Paw_{suffix}", ankle, toe, lower)
        anchors[f"Leg_{suffix}"] = tuple((Vector(hip) + Vector(joint)) * 0.5)
        anchors[f"Lower_{suffix}"] = tuple((Vector(joint) + Vector(ankle)) * 0.5)
        anchors[f"Paw_{suffix}"] = tuple((Vector(ankle) + Vector(toe)) * 0.5)
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        ear_base = (side * cfg["head"] * 0.52, layout["head_y"] + cfg["head"] * 0.42, layout["head_z"] + cfg["head"] * 0.12)
        ear_tip = (side * cfg["head"] * 0.64, ear_base[1] + max(cfg["ear"], 0.08), ear_base[2] + 0.04)
        add_bone(edit, f"Ear_{suffix}", ear_base, ear_tip, head)
        anchors[f"Ear_{suffix}"] = tuple((Vector(ear_base) + Vector(ear_tip)) * 0.5)
    tail_base = (0.0, layout["body_y"], cfg["length"] * 0.67)
    tail_tip = (0.0, max(0.24, layout["body_y"] - cfg["tail"] * 0.32), tail_base[2] + max(cfg["tail"], 0.15))
    tail_mid = tuple(Vector(tail_base).lerp(Vector(tail_tip), 0.52))
    tail = add_bone(edit, "Tail", tail_base, tail_mid, spine)
    add_bone(edit, "TailTip", tail_mid, tail_tip, tail)
    anchors["Tail"] = tuple((Vector(tail_base) + Vector(tail_mid)) * 0.5)
    anchors["TailTip"] = tuple((Vector(tail_mid) + Vector(tail_tip)) * 0.5)
    bpy.ops.object.mode_set(mode="OBJECT")
    rig["eco_species"] = species
    rig["eco_rig_family"] = cfg["family"]
    rig["anatomy_profile"] = "v5_near_realistic_species_anatomy_three_segment_limbs"
    rig["surface_profile"] = "v5_flush_markings_facial_landmarks"
    rig["limb_segments"] = 3
    return rig, anchors


def skin_ground_body(body: bpy.types.Object, rig: bpy.types.Object, anchors: dict[str, tuple[float, float, float]], cfg: dict) -> None:
    weights = {name: [] for name in anchors}
    for vertex in body.data.vertices:
        point = Vector((vertex.co.x, vertex.co.z, vertex.co.y))
        raw = {}
        for name, anchor in anchors.items():
            delta = point - Vector(anchor)
            if name.startswith("Leg_") or name.startswith("Paw_"):
                scale = Vector((cfg["width"] * 0.38, cfg["leg"] * 0.52, cfg["paw"] * 2.2))
                boost = 5.4
            elif name.startswith("Ear_"):
                scale = Vector((cfg["head"] * 0.42, max(cfg["ear"], 0.12) * 0.70, cfg["head"] * 0.38))
                boost = 5.0
            elif name == "Tail":
                scale = Vector((max(cfg["paw"], 0.18) * 1.8, max(cfg["tail"], 0.2) * 0.55, max(cfg["tail"], 0.2) * 0.72))
                boost = 4.8
            else:
                scale = Vector((cfg["width"] * 1.15, cfg["height"] * 1.05, cfg["length"] * 0.54))
                boost = 1.0
            distance = math.sqrt(sum((delta[index] / max(scale[index], 0.08)) ** 2 for index in range(3)))
            raw[name] = max(0.0, 1.0 - distance) ** 2 * boost
        total = sum(raw.values())
        if total < 0.0001:
            nearest = min(("Spine", "Chest", "Neck", "Head"), key=lambda name: (point - Vector(anchors[name])).length)
            raw[nearest] = 1.0
            total = 1.0
        for name in anchors:
            weights[name].append(raw[name] / total)
    add_armature_weights(body, rig, weights)


def skin_v3_torso(body: bpy.types.Object, rig: bpy.types.Object, anchors: dict[str, tuple[float, float, float]], cfg: dict) -> None:
    """Keep the torso smooth while articulated silhouette parts use rigid bone attachments."""
    bone_names = ("Spine", "Chest", "Neck", "Head")
    scales = {
        "Spine": Vector((cfg["width"] * 1.22, cfg["height"] * 1.20, cfg["length"] * 0.58)),
        "Chest": Vector((cfg["width"] * 1.18, cfg["height"] * 1.22, cfg["length"] * 0.54)),
        "Neck": Vector((cfg["head"] * 1.10, max(cfg["neck"], 0.26) * 1.05, max(cfg["neck"], 0.26) * 0.84)),
        "Head": Vector((cfg["head"] * 1.12, cfg["head"] * 1.12, max(cfg["muzzle"], cfg["head"]) * 1.10)),
    }
    weights = {name: [] for name in bone_names}
    for vertex in body.data.vertices:
        point = Vector((vertex.co.x, vertex.co.z, vertex.co.y))
        raw = {}
        for name in bone_names:
            delta = point - Vector(anchors[name])
            distance = math.sqrt(sum((delta[index] / max(scales[name][index], 0.08)) ** 2 for index in range(3)))
            raw[name] = max(0.0, 1.0 - distance) ** 2
        total = sum(raw.values())
        if total < 0.0001:
            nearest = min(bone_names, key=lambda name: (point - Vector(anchors[name])).length)
            raw[nearest] = 1.0
            total = 1.0
        for name in bone_names:
            weights[name].append(raw[name] / total)
    add_armature_weights(body, rig, weights)


def build_ground_parts(species: str, hero: bool, rig: bpy.types.Object, anchors: dict, cfg: dict, layout: dict) -> list[bpy.types.Object]:
    if species == "deer":
        return build_deer_parts(hero, rig, anchors)
    surface = cfg["surface"]
    anatomy = cfg["v5"]
    coat = pbr_material(f"{species}_coat_pbr", cfg["coat"], float(surface["coat_roughness"]))
    accent = pbr_material(f"{species}_accent_pbr", cfg["accent"], float(surface["accent_roughness"]))
    dark = pbr_material(f"{species}_detail_pbr", cfg["dark"], float(surface["detail_roughness"]))
    eye = pbr_material(f"{species}_eye_pbr", cfg["eye"], 0.09)
    horn = pbr_material(f"{species}_keratin_pbr", "#b9aa87", 0.66)
    profile = cfg["v3"]
    if cfg["family"] == "primate":
        elements = [
            ((0.0, layout["body_y"], layout["rear_z"] * 0.62), (cfg["width"] * float(profile["rump_mass"]) * float(anatomy["pelvis"]) * 0.88, cfg["height"] * 0.68 * float(anatomy["belly"]), cfg["length"] * 0.32), 2.30),
            ((0.0, (layout["body_y"] * 0.56 + layout["shoulder_y"] * 0.44), 0.02), (cfg["width"] * float(anatomy["waist"]), cfg["height"] * 0.78 * float(anatomy["belly"]), cfg["length"] * 0.34), 2.34),
            ((0.0, layout["shoulder_y"] * 0.96, layout["front_z"] * 0.74), (cfg["width"] * float(profile["chest_mass"]) * float(anatomy["rib"]), cfg["height"] * 0.72, cfg["length"] * 0.34), 2.34),
        ]
    else:
        elements = [
            ((0.0, layout["body_y"], layout["rear_z"] * 0.82), (cfg["width"] * float(profile["rump_mass"]) * float(anatomy["pelvis"]), cfg["height"] * 0.90 * float(anatomy["belly"]), cfg["length"] * 0.49), 2.28),
            ((0.0, (layout["body_y"] + layout["shoulder_y"]) * 0.5, 0.08), (cfg["width"] * float(anatomy["waist"]), cfg["height"] * 0.94 * float(anatomy["belly"]), cfg["length"] * 0.56), 2.32),
            ((0.0, layout["shoulder_y"], layout["front_z"] * 0.88), (cfg["width"] * float(profile["chest_mass"]) * float(anatomy["rib"]), cfg["height"] * 1.00, cfg["length"] * 0.46), 2.30),
        ]
    elements.extend([
        ((0.0, (layout["shoulder_y"] * 0.72 + layout["head_y"] * 0.28), (layout["front_z"] * 0.68 + layout["neck_z"] * 0.32)), (cfg["head"] * 0.78, max(cfg["neck"] * 0.48, cfg["head"] * 0.55), max(cfg["neck"] * 0.46, 0.24)), 2.16),
        ((0.0, (layout["shoulder_y"] + layout["head_y"]) * 0.5, layout["neck_z"]), (cfg["head"] * 0.68, max(cfg["neck"] * 0.62, cfg["head"] * 0.62), max(cfg["neck"] * 0.54, 0.24)), 2.14),
        ((0.0, layout["head_y"], layout["head_z"]), (cfg["head"] * float(anatomy["skull_width"]), cfg["head"] * 0.90 * float(anatomy["skull_height"]), cfg["head"] * float(anatomy["skull_length"])), 2.20),
        ((0.0, layout["head_y"] - cfg["head"] * 0.08, layout["muzzle_z"]), (cfg["head"] * 0.68 * float(anatomy["muzzle_width"]), cfg["head"] * 0.54 * float(anatomy["muzzle_height"]), cfg["muzzle"] * 0.74 * float(anatomy["muzzle_length"])), 2.12),
    ])
    # A short, heavy animal can place its head far enough in front of its chest
    # that two broad metaballs still resolve as separate islands.  Build a
    # continuous cervical chain for every ground species instead of relying on
    # a fortunate overlap.  This is also the Web-safe guarantee that the body
    # remains a single visible skinned surface rather than looking like an
    # exposed moving rig when one mesh island is culled or deformed.
    neck_start = Vector((0.0, layout["shoulder_y"], layout["front_z"] * 1.04))
    neck_end = Vector((0.0, layout["head_y"], layout["head_z"]))
    neck_delta = neck_end - neck_start
    for index, amount in enumerate((0.18, 0.36, 0.54, 0.72, 0.88)):
        position = neck_start.lerp(neck_end, amount)
        taper = 1.0 - amount * 0.18
        elements.append((
            tuple(position),
            (
                max(cfg["head"] * 0.58, cfg["width"] * 0.34) * taper,
                max(cfg["head"] * 0.62, abs(neck_delta.y) * 0.54),
                max(cfg["head"] * 0.68, abs(neck_delta.z) * 0.31),
            ),
            2.42,
        ))
    if "shoulder_hump" in cfg["features"]:
        elements.append(((0.0, layout["shoulder_y"] + cfg["height"] * 0.46, layout["front_z"] + 0.18), (cfg["width"] * 0.84, cfg["height"] * 0.56, cfg["length"] * 0.34), 2.2))
    body = metaball_mesh(f"{species.title()}OrganicBodyV2SourceConnected", elements, coat, hero)
    paint_ground_surface(body, species, cfg, layout, accent, dark)
    body["eco_anatomy_contract"] = "v5_species_specific_rib_waist_pelvis_skull_muzzle"
    skin_v3_torso(body, rig, anchors, cfg)
    parts = [body]

    def sphere(name: str, pos, scale, material=accent, bone_name="Head"):
        obj = uv_sphere(name, pos, scale, material, hero)
        rigid_skin(obj, rig, bone_name)
        parts.append(obj)
        return obj

    def cone(name: str, start, end, radius, material=horn, bone_name="Head"):
        obj = cone_between(name, start, end, radius, material, hero)
        rigid_skin(obj, rig, bone_name)
        parts.append(obj)
        return obj

    def limb(name: str, start, end, start_radius, end_radius, material, bone_name):
        obj = tapered_segment_between(name, start, end, start_radius, end_radius, material, hero)
        rigid_skin(obj, rig, bone_name)
        parts.append(obj)
        return obj

    taper_ratio = 0.84 if cfg["family"] in ("heavy", "primate", "chelonian") else 0.52 if cfg["family"] == "ungulate" else 0.68
    for suffix in LIMBS:
        hip, joint, ankle, toe = ground_limb_points(cfg, layout, suffix)
        front = suffix.endswith("F")
        parent_bone = "Chest" if front else "Spine"
        upper_radius = cfg["paw"] * 0.78 * float(profile["upper_thickness"]) * float(anatomy["muscle"])
        lower_radius = cfg["paw"] * 0.68 * float(profile["lower_thickness"]) * float(anatomy["muscle"])
        muscle_scale = (
            upper_radius * (0.94 if front else 1.04),
            max((hip[1] - joint[1]) * 0.22, upper_radius * 1.12),
            upper_radius * (0.88 if front else 0.98),
        )
        if cfg["family"] not in ("ungulate", "chelonian"):
            sphere(
                f"V5Muscle_{suffix}",
                tuple(Vector(hip).lerp(Vector(joint), 0.16)),
                tuple(value * 0.78 for value in muscle_scale),
                coat,
                parent_bone,
            )
        limb(
            f"V3UpperLimb_{suffix}", hip, tuple(Vector(joint).lerp(Vector(hip), -0.06)),
            upper_radius, max(upper_radius * taper_ratio, lower_radius * 1.05), coat, f"Leg_{suffix}",
        )
        limb(
            f"V4LowerLimb_{suffix}", tuple(Vector(joint).lerp(Vector(ankle), -0.06)), ankle,
            max(lower_radius * 1.14, cfg["paw"] * 0.10), max(lower_radius * 0.66, cfg["paw"] * 0.08), coat, f"Lower_{suffix}",
        )
        if hero:
            sphere(f"V5Joint_{suffix}", joint, (lower_radius * 0.70, lower_radius * 0.74, lower_radius * 0.72), coat, f"Lower_{suffix}")
        limb(
            f"V4Metapodial_{suffix}", ankle, toe,
            max(lower_radius * 0.70, cfg["paw"] * 0.08), max(lower_radius * 0.50, cfg["paw"] * 0.07), coat, f"Paw_{suffix}",
        )
        # Overlapping middle/metapodial forms already close this silhouette on
        # Mobile. Keep the tiny ankle cap only in Hero to protect the shared
        # 30-species mobile vertex budget without removing articulation.
        if hero:
            sphere(f"V4Hock_{suffix}", ankle, (lower_radius * 0.68, lower_radius * 0.72, lower_radius * 0.70), coat, f"Paw_{suffix}")
        foot_material = dark if cfg["features"] & {"hoof", "hands", "webbed_paws", "claws"} or cfg["family"] in ("canid", "felid") else coat
        foot_length = cfg["paw"] * (1.54 if cfg["family"] not in ("heavy", "primate") else 1.30)
        foot_width = max(lower_radius * 0.78 * float(anatomy["foot_width"]), 0.055)
        sphere(
            f"V5FootDetail_{suffix}",
            (toe[0], 0.075, toe[2] - foot_length * 0.12),
            (foot_width, max(lower_radius * 0.48, 0.052), max(foot_length, 0.11)),
            foot_material,
            f"Paw_{suffix}",
        )
        if hero:
            if "hoof" in cfg["features"]:
                for digit_side in (-1.0, 1.0):
                    sphere(
                        f"SplitHoofDetail_{suffix}_{digit_side:+.0f}",
                        (toe[0] + digit_side * foot_width * 0.45, 0.067, toe[2] - foot_length * 0.54),
                        (foot_width * 0.42, max(lower_radius * 0.38, 0.045), foot_length * 0.42),
                        dark,
                        f"Paw_{suffix}",
                    )
            elif cfg["family"] != "chelonian":
                digit_count = 4 if cfg["family"] == "primate" or "hands" in cfg["features"] else 3
                for digit_index in range(digit_count):
                    digit_offset = (digit_index - (digit_count - 1) * 0.5) * foot_width * 0.46
                    claw_start = (toe[0] + digit_offset, 0.070, toe[2] - foot_length * 0.62)
                    claw_end = (toe[0] + digit_offset, 0.052, toe[2] - foot_length * 0.88)
                    cone(f"ClawDetail_{suffix}_{digit_index}", claw_start, claw_end, max(foot_width * 0.12, 0.014), dark, f"Paw_{suffix}")

    if cfg["ear"] > 0.02 and "elephant_ears" not in cfg["features"]:
        for suffix, side in (("L", -1.0), ("R", 1.0)):
            ear_base = (side * cfg["head"] * 0.52, layout["head_y"] + cfg["head"] * 0.42, layout["head_z"] + cfg["head"] * 0.12)
            ear_tip = (side * cfg["head"] * 0.64, ear_base[1] + max(cfg["ear"], 0.08), ear_base[2] + 0.04)
            for ear_part in ear_leaf(
                f"V5EarSilhouette_{suffix}",
                ear_base,
                ear_tip,
                cfg["head"] * float(anatomy["ear_width"]),
                max(cfg["head"] * 0.035, 0.012),
                coat,
                accent,
                hero,
            ):
                rigid_skin(ear_part, rig, f"Ear_{suffix}")
                parts.append(ear_part)

    if cfg["tail"] > 0.12:
        tail_base = (0.0, layout["body_y"], cfg["length"] * 0.67)
        tail_tip = (0.0, max(0.24, layout["body_y"] - cfg["tail"] * 0.32), tail_base[2] + max(cfg["tail"], 0.15))
        tail_mid = tuple(Vector(tail_base).lerp(Vector(tail_tip), 0.52))
        tail_radius = max(cfg["paw"] * (1.22 if cfg["family"] in ("canid", "felid") else 0.82), 0.10)
        if species == "raccoon":
            # Build the diagnostic ringed tail out of overlapping tapered coat
            # segments.  The old implementation advertised `tail_rings` in the
            # catalog but never rendered them, while adding rings as loose beads
            # would bring back the toy-like silhouette removed by V5.
            ring_count = 7 if hero else 5
            tail_vector_start = Vector(tail_base)
            tail_vector_end = Vector(tail_tip)
            for ring_index in range(ring_count):
                start_amount = ring_index / ring_count
                end_amount = (ring_index + 1.10) / ring_count
                ring_start = tuple(tail_vector_start.lerp(tail_vector_end, start_amount))
                ring_end = tuple(tail_vector_start.lerp(tail_vector_end, min(end_amount, 1.0)))
                taper = 1.0 - ring_index / max(ring_count - 1, 1) * 0.38
                ring_material = dark if ring_index % 2 == 1 or ring_index == ring_count - 1 else coat
                ring = ellipsoid_between(
                    f"V5RaccoonTailRingDetail_{ring_index}",
                    ring_start,
                    ring_end,
                    tail_radius * taper,
                    ring_material,
                    hero,
                    0.80,
                )
                rigid_skin(ring, rig, "Tail" if start_amount < 0.50 else "TailTip")
                parts.append(ring)
        else:
            tail_base_mesh = ellipsoid_between("V5TailBaseSilhouette", tail_base, tail_mid, tail_radius, coat, hero, 0.78)
            rigid_skin(tail_base_mesh, rig, "Tail")
            parts.append(tail_base_mesh)
            tail_tip_mesh = ellipsoid_between("V5TailTipSilhouette", tail_mid, tail_tip, tail_radius * 0.76, coat, hero, 0.72)
            rigid_skin(tail_tip_mesh, rig, "TailTip")
            parts.append(tail_tip_mesh)

    jaw_start = (0.0, layout["head_y"] - cfg["head"] * 0.20, layout["head_z"] - cfg["head"] * 0.34)
    jaw_end = (0.0, layout["head_y"] - cfg["head"] * 0.25, layout["muzzle_z"] - cfg["muzzle"] * 0.70)
    jaw_radius = max(cfg["head"] * (0.23 if cfg["family"] in ("canid", "felid") else 0.29), 0.09)
    jaw_mesh = ellipsoid_between("V4LowerJawDetail", jaw_start, jaw_end, jaw_radius, accent, hero, 0.56)
    rigid_skin(jaw_mesh, rig, "Jaw")
    parts.append(jaw_mesh)

    eye_scale = cfg["head"] * float(anatomy["eye_scale"])
    eye_x = cfg["head"] * float(anatomy["skull_width"]) * 0.82
    for side in (-1.0, 1.0):
        eye_pos = (side * eye_x, layout["head_y"] + cfg["head"] * 0.13, layout["head_z"] - cfg["head"] * 0.42)
        sphere(f"V5EyeDetail_{'L' if side < 0 else 'R'}", eye_pos, (eye_scale, eye_scale * 1.02, eye_scale * 0.62), eye)
        if hero:
            sphere(
                f"V5UpperEyelidDetail_{'L' if side < 0 else 'R'}",
                (eye_pos[0], eye_pos[1] + eye_scale * 0.70, eye_pos[2] + eye_scale * 0.10),
                (eye_scale * 1.34, eye_scale * 0.42, eye_scale * 0.82),
                coat,
            )
    nose_pos = (0.0, layout["head_y"] - cfg["head"] * 0.10, layout["muzzle_z"] - cfg["muzzle"] * 0.68)
    nose_width = cfg["head"] * 0.20 * float(anatomy["muzzle_width"])
    sphere("V5NoseDetail", nose_pos, (nose_width, cfg["head"] * 0.115, cfg["head"] * 0.13), dark)
    if hero:
        for side in (-1.0, 1.0):
            sphere(
                f"V5NostrilDetail_{side:+.0f}",
                (side * nose_width * 0.54, nose_pos[1] + cfg["head"] * 0.015, nose_pos[2] - cfg["head"] * 0.095),
                (nose_width * 0.20, cfg["head"] * 0.027, cfg["head"] * 0.022),
                dark,
            )
        mouth_line = ellipsoid_between(
            "V5MouthLineDetail",
            (0.0, layout["head_y"] - cfg["head"] * 0.22, layout["head_z"] - cfg["head"] * 0.38),
            (0.0, layout["head_y"] - cfg["head"] * 0.24, layout["muzzle_z"] - cfg["muzzle"] * 0.72),
            max(cfg["head"] * 0.025, 0.012),
            dark,
            hero,
            0.30,
        )
        rigid_skin(mouth_line, rig, "Jaw")
        parts.append(mouth_line)
    features = cfg["features"]
    if features & {"chest", "muzzle_patch", "face_patch", "wide_muzzle"}:
        if "chest" in features:
            sphere("ChestRuffDetail", (0.0, layout["shoulder_y"], layout["front_z"] - cfg["length"] * 0.18), (cfg["width"] * 0.72, cfg["height"] * 0.72, 0.18), accent, "Chest")
        if features & {"muzzle_patch", "face_patch", "wide_muzzle"}:
            sphere("MuzzlePatchDetail", (0.0, layout["head_y"] - cfg["head"] * 0.10, layout["muzzle_z"] - cfg["muzzle"] * 0.30), (cfg["head"] * (0.90 if "wide_muzzle" in features else 0.70), cfg["head"] * 0.48, cfg["muzzle"] * 0.58), accent)
    if "black_legs" in features:
        for suffix in LIMBS:
            side = -1.0 if suffix.startswith("L") else 1.0
            z = layout["front_z"] if suffix.endswith("F") else layout["rear_z"]
            sphere(f"BlackLegDetail_{suffix}", (side * cfg["width"] * 0.80, 0.25, z - cfg["paw"] * 0.55), (cfg["paw"] * 1.10, 0.26, cfg["paw"] * 1.12), dark, f"Paw_{suffix}")
    if "mask" in features or "tear_marks" in features:
        for side in (-1.0, 1.0):
            sphere(f"FaceMaskDetail_{side:+.0f}", (side * cfg["head"] * 0.61, layout["head_y"] + 0.02, layout["head_z"] - cfg["head"] * 0.42), (cfg["head"] * (0.34 if "mask" in features else 0.12), cfg["head"] * 0.24, cfg["head"] * 0.10), dark)
    if features & {"mane", "ridge_mane", "cheek_ruff"}:
        if "mane" in features:
            sphere(
                "ManeSilhouette",
                (0.0, (layout["head_y"] + layout["shoulder_y"]) * 0.50, layout["head_z"] + cfg["head"] * 0.22),
                (cfg["head"] * 1.08, cfg["head"] * 1.02, cfg["head"] * 0.62),
                dark,
                "Neck",
            )
        count = (0 if "mane" in features else 7) if hero else (0 if "mane" in features else 4)
        for index in range(count):
            angle = -1.1 + 2.2 * index / max(count - 1, 1)
            if "cheek_ruff" in features:
                side = -1.0 if index % 2 == 0 else 1.0
                sphere(f"CheekRuffDetail_{index}", (side * cfg["head"] * 0.72, layout["head_y"] - 0.02 + index * 0.015, layout["head_z"] + 0.02), (0.18, 0.25, 0.17), accent)
            else:
                z = layout["rear_z"] - cfg["length"] * 0.72 * index / max(count - 1, 1)
                cone(f"ManeQuillDetail_{index}", (0.0, layout["body_y"] + cfg["height"] * 0.62, z), (0.0, layout["body_y"] + cfg["height"] * 1.02, z + 0.03), cfg["paw"] * 0.32, dark, "Spine" if z > 0.0 else "Chest")
    if "quills" in features:
        rows = 16 if hero else 9
        for index in range(rows):
            z = layout["rear_z"] - cfg["length"] * 0.95 * index / max(rows - 1, 1)
            for side in (-1.0, 1.0):
                cone(f"QuillDetail_{index}_{side:+.0f}", (side * cfg["width"] * 0.40, layout["body_y"] + cfg["height"] * 0.42, z), (side * cfg["width"] * 0.85, layout["body_y"] + cfg["height"] * 1.02, z + 0.18), 0.045, horn, "Spine" if z > 0.0 else "Chest")
    if "armor_folds" in features:
        for index in range(3):
            fold = ellipsoid_between(
                f"ArmorFoldDetail_{index}",
                (-cfg["width"] * 0.84, layout["body_y"] + 0.14, -0.40 + index * 0.42),
                (cfg["width"] * 0.84, layout["body_y"] + 0.14, -0.40 + index * 0.42),
                0.045,
                accent,
                hero,
                0.42,
            )
            rigid_skin(fold, rig, "Chest" if index < 2 else "Spine")
            parts.append(fold)
    if features & {"horns", "antlers", "palm_antlers", "rhino_horns", "tusks"}:
        for side in (-1.0, 1.0):
            if "rhino_horns" in features:
                continue
            if "tusks" in features:
                start = (side * cfg["head"] * 0.38, layout["head_y"] - cfg["head"] * 0.30, layout["muzzle_z"] - cfg["muzzle"] * 0.30)
                end = (side * cfg["head"] * 0.52, layout["head_y"] + cfg["head"] * 0.06, layout["muzzle_z"] - cfg["muzzle"] * 0.76)
                cone(f"TuskDetail_{side:+.0f}", start, end, cfg["head"] * 0.10)
            if "horns" in features:
                start = (side * cfg["head"] * 0.43, layout["head_y"] + cfg["head"] * 0.43, layout["head_z"] + 0.04)
                end = (side * cfg["head"] * 0.92, layout["head_y"] + cfg["head"] * 0.85, layout["head_z"] - 0.04)
                cone(f"HornDetail_{side:+.0f}", start, end, cfg["head"] * 0.13)
            if "antlers" in features or "palm_antlers" in features:
                start = (side * cfg["head"] * 0.42, layout["head_y"] + cfg["head"] * 0.45, layout["head_z"] + 0.02)
                crown = (side * cfg["head"] * (1.00 if "palm_antlers" in features else 0.70), layout["head_y"] + cfg["head"] * 1.38, layout["head_z"] + 0.08)
                cone(f"AntlerDetail_{side:+.0f}", start, crown, cfg["head"] * 0.10)
                branch_count = 3 if hero else 2
                for branch_index in range(branch_count):
                    p = (branch_index + 1) / (branch_count + 1)
                    branch_start = tuple(Vector(start).lerp(Vector(crown), p))
                    branch_end = (branch_start[0] + side * cfg["head"] * (0.45 + p * 0.20), branch_start[1] + cfg["head"] * 0.34, branch_start[2] - cfg["head"] * (0.15 + p * 0.10))
                    cone(f"AntlerBranchDetail_{side:+.0f}_{branch_index}", branch_start, branch_end, cfg["head"] * 0.075)
    if "rhino_horns" in features:
        cone("NasalHornDetail", (0.0, layout["head_y"] + cfg["head"] * 0.12, layout["muzzle_z"] - cfg["muzzle"] * 0.16), (0.0, layout["head_y"] + cfg["head"] * 1.18, layout["muzzle_z"] - cfg["muzzle"] * 0.40), cfg["head"] * 0.18)
        cone("SecondHornDetail", (0.0, layout["head_y"] + cfg["head"] * 0.38, layout["head_z"] - 0.12), (0.0, layout["head_y"] + cfg["head"] * 0.92, layout["head_z"] - 0.22), cfg["head"] * 0.13)
    if "elephant_ears" in features:
        for side in (-1.0, 1.0):
            suffix = "L" if side < 0 else "R"
            for ear_part in elephant_ear_fan(
                f"V5EarFanSilhouette_{suffix}",
                side,
                (side * cfg["head"] * 0.52, layout["head_y"] - 0.02, layout["head_z"] + 0.18),
                cfg["ear"],
                coat,
                accent,
                hero,
            ):
                rigid_skin(ear_part, rig, f"Ear_{suffix}")
                parts.append(ear_part)
    if "trunk" in features:
        trunk_elements = []
        for index in range(4):
            progress = index / 3.0
            trunk_elements.append(((0.0, layout["head_y"] - cfg["head"] * (0.20 + progress * 1.15), layout["muzzle_z"] - cfg["muzzle"] * (0.42 + progress * 0.15)), (cfg["head"] * (0.25 - progress * 0.07), cfg["head"] * 0.36, cfg["head"] * 0.20), 2.0))
        trunk = metaball_mesh("TrunkDetail", trunk_elements, accent, hero)
        rigid_skin(trunk, rig, "Head")
        parts.append(trunk)
    if "shell" in features:
        sphere("ShellDetail", (0.0, layout["body_y"] + cfg["height"] * 0.52, 0.10), (cfg["width"] * 1.10, cfg["height"] * 0.92, cfg["length"] * 0.72), accent, "Spine")
        if hero:
            for index in range(7):
                angle = index / 7.0 * math.tau
                sphere(f"ShellPlateDetail_{index}", (math.sin(angle) * cfg["width"] * 0.62, layout["body_y"] + cfg["height"] * 1.04, 0.10 + math.cos(angle) * cfg["length"] * 0.38), (0.22, 0.045, 0.27), dark, "Spine")
    if "tail_tip" in features or "tail_tuft" in features:
        sphere("TailTipDetail", (0.0, max(0.24, layout["body_y"] - cfg["tail"] * 0.32), cfg["length"] * 0.68 + cfg["tail"]), (cfg["paw"] * 1.55, cfg["paw"] * 1.45, cfg["paw"] * 1.72), accent if "tail_tip" in features else dark, "TailTip")
    if "beard" in features or "dewlap" in features:
        sphere("BeardDetail", (0.0, layout["head_y"] - cfg["head"] * 0.66, layout["head_z"] - cfg["head"] * 0.18), (cfg["head"] * 0.30, cfg["head"] * (0.62 if "dewlap" in features else 0.40), cfg["head"] * 0.26), dark)
    if "ear_tufts" in features:
        for side in (-1.0, 1.0):
            cone(f"EarTuftDetail_{side:+.0f}", (side * cfg["head"] * 0.55, layout["head_y"] + cfg["head"] * 0.88, layout["head_z"] + 0.02), (side * cfg["head"] * 0.62, layout["head_y"] + cfg["head"] * 1.30, layout["head_z"] + 0.02), 0.045, dark, f"Ear_{'L' if side < 0 else 'R'}")
    attach_socket("SkillSocket_Mouth", (0.0, layout["head_y"], layout["muzzle_z"] - cfg["muzzle"] * 0.86), rig, "Head")
    attach_socket("SkillSocket_Chest", (0.0, layout["shoulder_y"], layout["front_z"]), rig, "Chest")
    return parts


def limb_chain_flex_sign(rig: bpy.types.Object, suffix: str) -> float:
    """Return the local bend direction that increases the rest-chain angle.

    A hard-coded sign can rotate a bone while making the actual leg straighter,
    which was the failure found in the cinematic wolf.  Generated V4 legs use
    their own rest geometry to choose the direction that folds the upper and
    middle segments farther apart around the shared cross-body hinge.
    """

    upper = rig.data.bones[f"Leg_{suffix}"]
    lower = rig.data.bones[f"Lower_{suffix}"]
    upper_vector = (upper.tail_local - upper.head_local).normalized()
    lower_vector = (lower.tail_local - lower.head_local).normalized()
    cross_body = Vector((1.0, 0.0, 0.0))
    signed_angle = math.atan2(cross_body.dot(upper_vector.cross(lower_vector)), upper_vector.dot(lower_vector))
    return 1.0 if signed_angle >= 0.0 else -1.0


def create_deer_actions(rig: bpy.types.Object) -> None:
    """Eight deer-specific actions with a four-beat walk and gathered gallop."""
    rig.animation_data_create()

    def insert_rotation(bone_name: str, frame: int, xyz: tuple[float, float, float]) -> None:
        bone = rig.pose.bones[bone_name]
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = xyz
        bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)

    flex_signs = {suffix: limb_chain_flex_sign(rig, suffix) for suffix in LIMBS}

    for action_name in ACTIONS:
        action = bpy.data.actions.new(action_name)
        rig.animation_data.action = action
        for pose_bone in rig.pose.bones:
            insert_rotation(pose_bone.name, 1, (0.0, 0.0, 0.0))

        if action_name in ("locomotion", "sprint"):
            frames = (1, 5, 9, 13, 17, 21, 25, 29, 33)
            if action_name == "locomotion":
                phases = {"LF": 0.0, "RH": math.pi * 0.5, "RF": math.pi, "LH": math.pi * 1.5}
                amount, flex = 0.33, 0.43
            else:
                phases = {"LF": math.pi * 1.10, "RF": math.pi * 0.90, "LH": math.pi * 0.10, "RH": 0.0}
                amount, flex = 0.67, 0.72
            for frame in frames:
                cycle = math.tau * (frame - 1) / 32.0
                for suffix in LIMBS:
                    phase = phases[suffix]
                    swing = math.sin(cycle + phase)
                    lift = max(0.0, math.sin(cycle + phase - 0.34))
                    support = max(0.0, -math.sin(cycle + phase - 0.34))
                    upper = amount * swing
                    lower = flex_signs[suffix] * flex * (0.94 * lift + 0.08 * support)
                    paw = -flex_signs[suffix] * flex * (0.42 * lift + 0.05 * support)
                    if suffix.endswith("H"):
                        upper *= 1.08
                        lower *= 1.10
                        paw *= 1.08
                    insert_rotation(f"Leg_{suffix}", frame, (upper, 0.0, 0.0))
                    insert_rotation(f"Lower_{suffix}", frame, (lower, 0.0, 0.0))
                    insert_rotation(f"Paw_{suffix}", frame, (paw, 0.0, 0.0))
                body_wave = math.sin(cycle * (2.0 if action_name == "sprint" else 1.0))
                side_wave = math.sin(cycle)
                insert_rotation("Spine", frame, (0.025 * body_wave, 0.0, 0.025 * side_wave))
                insert_rotation("Chest", frame, (-0.035 * body_wave, 0.0, -0.022 * side_wave))
                insert_rotation("Neck", frame, (0.026 * body_wave, 0.0, 0.0))
                insert_rotation("Head", frame, (-0.018 * body_wave, 0.0, 0.0))
                insert_rotation("Tail", frame, (0.02 + 0.035 * body_wave, 0.0, -0.05 * side_wave))
                insert_rotation("TailTip", frame, (0.018 * body_wave, 0.0, -0.08 * side_wave))

        elif action_name == "idle":
            for frame, breath, flick in ((1, -1.0, 0.0), (11, 0.2, 1.0), (21, 1.0, -0.35), (31, -1.0, 0.0)):
                insert_rotation("Chest", frame, (0.018 * breath, 0.0, 0.0))
                insert_rotation("Neck", frame, (-0.012 * breath, 0.0, 0.0))
                insert_rotation("Head", frame, (0.008 * breath, 0.0, 0.0))
                insert_rotation("Ear_L", frame, (0.0, 0.10 * flick, 0.05 * flick))
                insert_rotation("Ear_R", frame, (0.0, -0.035 * flick, -0.02 * flick))
                insert_rotation("Tail", frame, (0.0, 0.0, 0.04 * flick))

        elif action_name in ("attack", "skill"):
            strength = 1.0 if action_name == "attack" else 1.28
            for frame, brace, strike in ((1, 0.0, 0.0), (7, 1.0, -0.20), (12, 0.55, 1.0), (22, 0.0, 0.0)):
                insert_rotation("Spine", frame, (-0.09 * brace * strength, 0.0, 0.0))
                insert_rotation("Chest", frame, (-0.12 * brace * strength, 0.0, 0.0))
                insert_rotation("Neck", frame, (0.25 * strike * strength, 0.0, 0.0))
                insert_rotation("Head", frame, (0.32 * strike * strength, 0.0, 0.0))
                insert_rotation("Jaw", frame, (-0.22 * max(strike, 0.0) * strength, 0.0, 0.0))
                insert_rotation("Leg_LF", frame, (-0.17 * brace, 0.0, 0.0))
                insert_rotation("Leg_RF", frame, (-0.17 * brace, 0.0, 0.0))

        elif action_name == "hit":
            for frame, curve in ((1, 0.0), (5, 1.0), (14, 0.0)):
                insert_rotation("Spine", frame, (-0.12 * curve, 0.0, 0.21 * curve))
                insert_rotation("Neck", frame, (0.15 * curve, 0.0, -0.13 * curve))
                insert_rotation("Head", frame, (0.10 * curve, 0.0, -0.16 * curve))

        elif action_name == "eat":
            for frame, lower, nibble in ((1, 0.0, 0.0), (10, 0.72, 0.0), (18, 1.0, 1.0), (25, 1.0, -1.0), (34, 0.0, 0.0)):
                insert_rotation("Neck", frame, (0.64 * lower, 0.0, 0.0))
                insert_rotation("Head", frame, (0.48 * lower + 0.05 * nibble, 0.0, 0.0))
                insert_rotation("Jaw", frame, (-0.055 * abs(nibble) * lower, 0.0, 0.0))

        elif action_name == "death":
            for frame, fall in ((1, 0.0), (12, 0.30), (23, 0.82), (34, 1.0)):
                insert_rotation("Spine", frame, (0.06 * fall, 0.0, 1.28 * fall))
                insert_rotation("Chest", frame, (-0.11 * fall, 0.0, 0.24 * fall))
                insert_rotation("Neck", frame, (0.22 * fall, 0.0, -0.16 * fall))
                insert_rotation("Head", frame, (0.19 * fall, 0.0, -0.12 * fall))
        action.use_fake_user = True
    rig.animation_data.action = bpy.data.actions["idle"]


def create_ground_actions(rig: bpy.types.Object, cfg: dict) -> None:
    if cfg.get("species") == "deer":
        create_deer_actions(rig)
        return
    rig.animation_data_create()
    profile = cfg["v3"]
    flex_signs = {suffix: limb_chain_flex_sign(rig, suffix) for suffix in LIMBS}

    def insert_rotation(bone_name: str, frame: int, xyz: tuple[float, float, float]) -> None:
        bone = rig.pose.bones[bone_name]
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = xyz
        bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)

    def gait_phases(gait: str) -> dict[str, float]:
        if gait in ("trot", "long_trot"):
            return {"LF": 0.0, "RH": 0.0, "RF": math.pi, "LH": math.pi}
        if gait in ("bound", "gallop"):
            return {"LF": math.pi * 0.92, "RF": math.pi * 1.08, "LH": 0.0, "RH": math.pi * 0.16}
        if gait in ("amble", "lumber", "shuffle"):
            return {"LF": 0.0, "LH": math.pi * 0.35, "RF": math.pi, "RH": math.pi * 1.35}
        if gait in ("knuckle", "knuckle_run", "primate_walk", "primate_run"):
            return {"LF": 0.0, "RH": math.pi * 0.65, "RF": math.pi, "LH": math.pi * 1.65}
        if gait == "crawl":
            return {"LF": 0.0, "RH": math.pi * 0.50, "RF": math.pi, "LH": math.pi * 1.50}
        return {"LF": 0.0, "RH": math.pi * 0.50, "RF": math.pi, "LH": math.pi * 1.50}

    for action_name in ACTIONS:
        action = bpy.data.actions.new(action_name)
        rig.animation_data.action = action
        for pose_bone in rig.pose.bones:
            insert_rotation(pose_bone.name, 1, (0.0, 0.0, 0.0))
        if action_name in ("locomotion", "sprint"):
            gait = str(profile["gait"] if action_name == "locomotion" else profile["sprint_gait"])
            phases = gait_phases(gait)
            stride = float(profile["stride"]) * (1.0 if action_name == "locomotion" else 1.48)
            flex = float(profile["flex"]) * (1.0 if action_name == "locomotion" else 1.30)
            frames = (1, 5, 9, 13, 17, 21, 25, 29, 33)
            for frame in frames:
                cycle = math.tau * (frame - 1) / 32.0
                for suffix in LIMBS:
                    phase = phases[suffix]
                    swing = math.sin(cycle + phase)
                    lift = max(0.0, math.sin(cycle + phase - 0.34))
                    support = max(0.0, -math.sin(cycle + phase - 0.34))
                    rear_power = 1.10 if suffix.endswith("H") and gait in ("bound", "gallop", "long_trot") else 1.0
                    upper = stride * swing * rear_power
                    lower = flex_signs[suffix] * flex * (0.94 * lift + 0.08 * support) * rear_power
                    paw = -flex_signs[suffix] * flex * (0.44 * lift + 0.06 * support) * rear_power
                    if gait == "crawl":
                        upper *= 0.56
                        lower *= 0.52
                        paw *= 0.48
                    insert_rotation(f"Leg_{suffix}", frame, (upper, 0.0, 0.0))
                    insert_rotation(f"Lower_{suffix}", frame, (lower, 0.0, 0.0))
                    insert_rotation(f"Paw_{suffix}", frame, (paw, 0.0, 0.0))
                double_wave = 2.0 if action_name == "sprint" and gait in ("gallop", "bound", "knuckle_run", "primate_run") else 1.0
                body_wave = math.sin(cycle * double_wave)
                side_wave = math.sin(cycle)
                bob = float(profile["body_bob"]) * (1.35 if action_name == "sprint" else 1.0)
                head_bob = float(profile["head_bob"])
                insert_rotation("Spine", frame, (bob * body_wave, 0.0, bob * 0.55 * side_wave))
                insert_rotation("Chest", frame, (-bob * 0.72 * body_wave, 0.0, -bob * 0.45 * side_wave))
                insert_rotation("Neck", frame, (head_bob * body_wave, 0.0, 0.0))
                insert_rotation("Head", frame, (-head_bob * 0.70 * body_wave, 0.0, 0.0))
                insert_rotation("Tail", frame, (0.02 * body_wave, 0.0, -0.06 * side_wave))
                insert_rotation("TailTip", frame, (0.018 * body_wave, 0.0, -0.095 * side_wave))
        elif action_name in ("attack", "skill"):
            strength = 1.0 if action_name == "attack" else 1.28
            attack_style = str(profile["attack"])
            for frame, windup, strike in ((1, 0.0, 0.0), (7, 1.0, -0.22), (12, 0.40, 1.0), (23, 0.0, 0.0)):
                spine_x = -0.18 * windup * strength
                neck_x = 0.18 * strike * strength
                head_x = 0.20 * strike * strength
                insert_rotation("Spine", frame, (spine_x, 0.0, 0.0))
                insert_rotation("Chest", frame, (-0.12 * windup * strength, 0.0, 0.0))
                insert_rotation("Neck", frame, (neck_x, 0.0, 0.0))
                insert_rotation("Head", frame, (head_x, 0.0, 0.0))
                insert_rotation("Jaw", frame, (-0.30 * max(strike, 0.0) * strength, 0.0, 0.0))
                if attack_style == "kick":
                    insert_rotation("Leg_LH", frame, (-0.68 * strike * strength, 0.0, 0.0))
                    insert_rotation("Leg_RH", frame, (-0.68 * strike * strength, 0.0, 0.0))
                    for suffix in ("LH", "RH"):
                        insert_rotation(f"Lower_{suffix}", frame, (flex_signs[suffix] * 0.48 * max(strike, 0.0), 0.0, 0.0))
                        insert_rotation(f"Paw_{suffix}", frame, (-flex_signs[suffix] * 0.22 * max(strike, 0.0), 0.0, 0.0))
                elif attack_style == "swipe":
                    insert_rotation("Leg_LF", frame, (-0.72 * strike * strength, 0.0, -0.16 * strike))
                    insert_rotation("Leg_RF", frame, (-0.18 * windup, 0.0, 0.0))
                    insert_rotation("Lower_LF", frame, (flex_signs["LF"] * 0.42 * max(strike, 0.0), 0.0, 0.0))
                    insert_rotation("Paw_LF", frame, (-flex_signs["LF"] * 0.18 * max(strike, 0.0), 0.0, 0.0))
                elif attack_style == "stomp":
                    insert_rotation("Leg_LF", frame, (-0.48 * windup + 0.26 * strike, 0.0, 0.0))
                    insert_rotation("Leg_RF", frame, (-0.48 * windup + 0.26 * strike, 0.0, 0.0))
                elif attack_style == "charge":
                    insert_rotation("Neck", frame, (0.38 * strike * strength, 0.0, 0.0))
                    insert_rotation("Head", frame, (0.32 * strike * strength, 0.0, 0.0))
                else:
                    insert_rotation("Leg_LF", frame, (-0.44 * strike * strength, 0.0, 0.0))
                    insert_rotation("Leg_RF", frame, (-0.44 * strike * strength, 0.0, 0.0))
        elif action_name == "hit":
            for frame, curve in ((1, 0.0), (6, 1.0), (15, 0.0)):
                insert_rotation("Spine", frame, (-0.10 * curve, 0.0, 0.28 * curve))
                insert_rotation("Neck", frame, (0.12 * curve, 0.0, -0.12 * curve))
                insert_rotation("Head", frame, (0.08 * curve, 0.0, -0.18 * curve))
        elif action_name == "eat":
            for frame, lower, nibble in ((1, 0.0, 0.0), (10, 0.72, 0.0), (18, 1.0, 1.0), (25, 1.0, -1.0), (34, 0.0, 0.0)):
                insert_rotation("Neck", frame, (0.54 * lower, 0.0, 0.0))
                insert_rotation("Head", frame, (0.34 * lower + 0.045 * nibble, 0.0, 0.0))
                insert_rotation("Jaw", frame, (-0.055 * abs(nibble) * lower, 0.0, 0.0))
        elif action_name == "death":
            for frame, curve in ((1, 0.0), (12, 0.28), (23, 0.82), (34, 1.0)):
                insert_rotation("Spine", frame, (0.05 * curve, 0.0, 1.22 * curve))
                insert_rotation("Chest", frame, (-0.10 * curve, 0.0, 0.22 * curve))
                insert_rotation("Neck", frame, (0.18 * curve, 0.0, -0.14 * curve))
        elif action_name == "idle":
            for frame, breath, flick in ((1, -1.0, 0.0), (11, 0.1, 1.0), (21, 1.0, -0.35), (31, -1.0, 0.0)):
                insert_rotation("Chest", frame, (0.020 * breath, 0.0, 0.0))
                insert_rotation("Neck", frame, (-0.012 * breath, 0.0, 0.0))
                insert_rotation("Ear_L", frame, (0.0, 0.08 * flick, 0.04 * flick))
                insert_rotation("Ear_R", frame, (0.0, -0.03 * flick, -0.02 * flick))
                insert_rotation("Tail", frame, (0.015 * breath, 0.0, 0.045 * flick))
                insert_rotation("TailTip", frame, (0.012 * breath, 0.0, 0.075 * flick))
        action.use_fake_user = True
    rig.animation_data.action = bpy.data.actions["idle"]


def build_bird(species: str, hero: bool) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    owl = species == "owl"
    coat = pbr_material(f"{species}_feather_pbr", "#665a4d" if owl else "#493729", 0.84 if owl else 0.80)
    accent = pbr_material(f"{species}_accent_pbr", "#d8ceb8" if owl else "#b88a42", 0.76)
    dark = pbr_material(f"{species}_detail_pbr", "#34383d" if owl else "#211c18", 0.66)
    eye = pbr_material(f"{species}_eye_pbr", "#e0bc42", 0.08)
    keratin = pbr_material(f"{species}_keratin_pbr", "#b9a66f" if owl else "#c39a48", 0.52)
    bpy.ops.object.armature_add(enter_editmode=True)
    rig = bpy.context.active_object
    rig.name = "SpeciesFlightSkeleton3D"
    rig.data.name = f"{species.title()}V5FlightRig"
    edit = rig.data.edit_bones
    root = edit[0]
    root.name = "Root"
    root.head, root.tail = g2b((0.0, 0.40, 0.10)), g2b((0.0, 0.90, 0.10))
    body = add_bone(edit, "Body", (0.0, 1.05, 0.40), (0.0, 1.27, -0.30), root)
    neck = add_bone(edit, "Neck", (0.0, 1.27, -0.30), (0.0, 1.37, -0.64), body)
    head = add_bone(edit, "Head", (0.0, 1.37, -0.64), (0.0, 1.42, -1.05), neck)
    wing_elbow = 1.30 if owl else 1.48
    wing_wrist = 1.92 if owl else 2.32
    wing_tip = 2.52 if owl else 3.12
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        wing = add_bone(edit, f"Wing_{suffix}", (side * 0.34, 1.18, -0.10), (side * wing_elbow, 1.16, 0.16), body)
        wing_tip_bone = add_bone(edit, f"WingTip_{suffix}", (side * wing_elbow, 1.16, 0.16), (side * wing_wrist, 1.10, 0.42), wing)
        add_bone(edit, f"WingPrimary_{suffix}", (side * wing_wrist, 1.10, 0.42), (side * wing_tip, 1.02, 0.72), wing_tip_bone)
        add_bone(edit, f"Talon_{suffix}", (side * 0.25, 0.92, -0.15), (side * 0.28, 0.46, -0.35), body)
    tail = add_bone(edit, "Tail", (0.0, 1.04, 0.58), (0.0, 1.00, 1.02), body)
    add_bone(edit, "TailTip", (0.0, 1.00, 1.02), (0.0, 0.98, 1.58 if owl else 1.76), tail)
    bpy.ops.object.mode_set(mode="OBJECT")
    body_elements = [
        ((0.0, 1.10, 0.24), (0.70 if owl else 0.54, 0.82 if owl else 0.72, 0.76 if owl else 0.92), 2.28),
        ((0.0, 1.31, -0.34), (0.62 if owl else 0.45, 0.62 if owl else 0.50, 0.56), 2.22),
        ((0.0, 1.43, -0.78), (0.57 if owl else 0.37, 0.58 if owl else 0.42, 0.45), 2.20),
        ((0.0, 1.40, -1.03), (0.40 if owl else 0.27, 0.34 if owl else 0.29, 0.32), 2.12),
    ]
    organic = metaball_mesh(f"{species.title()}OrganicBodyV2SourceConnected", body_elements, coat, hero)
    organic["eco_anatomy_contract"] = "v5_species_specific_raptor_body_wing_feather_profile"
    accent_index = append_material(organic, accent)
    dark_index = append_material(organic, dark)
    for polygon in organic.data.polygons:
        centre = sum((organic.data.vertices[index].co for index in polygon.vertices), Vector()) / len(polygon.vertices)
        if owl:
            feather_field = math.sin(centre.x * 15.0 + centre.y * 8.0) * math.cos(centre.z * 14.0 - centre.y * 4.0)
            if feather_field > 0.52:
                polygon.material_index = dark_index
            elif centre.z < 1.18 and feather_field < -0.46:
                polygon.material_index = accent_index
        elif centre.y < -0.55 and centre.z > 1.24:
            polygon.material_index = accent_index
    organic["eco_surface_pattern"] = "v5_flush_feather_regions"
    weights = {"Body": [], "Neck": [], "Head": []}
    for vertex in organic.data.vertices:
        godot_z = vertex.co.y
        raw = {
            "Body": max(0.0, 1.0 - abs(godot_z - 0.10) / 0.88) ** 2,
            "Neck": max(0.0, 1.0 - abs(godot_z + 0.48) / 0.58) ** 2,
            "Head": max(0.0, 1.0 - abs(godot_z + 0.88) / 0.55) ** 2,
        }
        total = sum(raw.values()) or 1.0
        for bone_name in weights:
            weights[bone_name].append(raw[bone_name] / total)
    add_armature_weights(organic, rig, weights)
    parts = [organic]
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        wing_base = tapered_flat_blade(
            f"WingBodyDetail_{suffix}",
            (side * 0.30, 1.16, -0.08),
            (side * wing_elbow, 1.15, 0.18),
            0.46 if owl else 0.38,
            0.32 if owl else 0.24,
            0.075 if owl else 0.060,
            coat,
            hero,
        )
        rigid_skin(wing_base, rig, f"Wing_{suffix}")
        parts.append(wing_base)
        wing_feather = tapered_flat_blade(
            f"WingFeatherDetail_{suffix}",
            (side * (wing_elbow - 0.06), 1.14, 0.18),
            (side * wing_wrist, 1.08, 0.46),
            0.38 if owl else 0.30,
            0.11 if owl else 0.075,
            0.052 if owl else 0.042,
            dark if owl else coat,
            hero,
        )
        rigid_skin(wing_feather, rig, f"WingTip_{suffix}")
        parts.append(wing_feather)
        primary_blade = tapered_flat_blade(
            f"WingPrimaryBladeDetail_{suffix}",
            (side * (wing_wrist - 0.04), 1.08, 0.42),
            (side * wing_tip, 1.02, 0.74),
            0.30 if owl else 0.24,
            0.09 if owl else 0.065,
            0.045 if owl else 0.036,
            dark if owl else coat,
            hero,
        )
        rigid_skin(primary_blade, rig, f"WingPrimary_{suffix}")
        parts.append(primary_blade)
        feather_count = 7 if hero else 4
        for feather_index in range(feather_count):
            amount = feather_index / max(feather_count - 1, 1)
            base_x = wing_wrist + (wing_tip - wing_wrist) * (0.10 + amount * 0.48)
            feather = tapered_flat_blade(
                f"PrimaryFeatherDetail_{suffix}_{feather_index}",
                (side * base_x, 1.02 - amount * 0.04, 0.46 + amount * 0.08),
                (side * (wing_tip + (0.14 if not owl else 0.05) - amount * 0.10), 0.98, 0.82 + amount * (0.34 if owl else 0.52)),
                0.080 if owl else 0.064,
                0.020,
                0.026 if owl else 0.021,
                dark if owl else coat,
                hero,
            )
            rigid_skin(feather, rig, f"WingPrimary_{suffix}")
            parts.append(feather)
        talon = tapered_segment_between(
            f"TalonDetail_{suffix}",
            (side * 0.27, 0.62, -0.28),
            (side * 0.31, 0.35, -0.56),
            0.075,
            0.050,
            keratin,
            hero,
        )
        rigid_skin(talon, rig, f"Talon_{suffix}")
        parts.append(talon)
        toe_count = 3 if hero else 2
        for toe_index in range(toe_count):
            toe_spread = (toe_index - (toe_count - 1) * 0.5) * 0.085
            toe_start = (side * 0.31 + toe_spread, 0.35, -0.53)
            toe_end = (side * 0.31 + toe_spread * 1.24, 0.27, -0.73 - abs(toe_spread) * 0.35)
            toe = tapered_segment_between(
                f"TalonToeDetail_{suffix}_{toe_index}", toe_start, toe_end,
                0.036, 0.014, keratin, hero,
            )
            rigid_skin(toe, rig, f"Talon_{suffix}")
            parts.append(toe)
        attach_socket(f"SkillSocket_Wing_{suffix}", (side * (wing_tip - 0.15), 1.06, 0.66), rig, f"WingPrimary_{suffix}")
    for tail_index, side in enumerate((-1.0, 0.0, 1.0)):
        tail = tapered_flat_blade(
            f"TailFeatherDetail_{tail_index}",
            (side * 0.10, 1.02, 0.58),
            (side * (0.42 if owl else 0.30), 0.98, 1.58 if owl else 1.76),
            0.22 if owl else 0.17,
            0.07 if owl else 0.045,
            0.035,
            coat,
            hero,
        )
        rigid_skin(tail, rig, "TailTip")
        parts.append(tail)
    if owl:
        for side in (-1.0, 1.0):
            disk = uv_sphere(
                f"FacialDiskDetail_{side:+.0f}",
                (side * 0.25, 1.46, -0.96),
                (0.34, 0.34, 0.10),
                accent,
                hero,
            )
            rigid_skin(disk, rig, "Head")
            parts.append(disk)
    else:
        nape = uv_sphere("GoldenNapeDetail", (0.0, 1.48, -0.72), (0.38, 0.34, 0.30), accent, hero)
        rigid_skin(nape, rig, "Head")
        parts.append(nape)
    beak = cone_between("BeakDetail", (0.0, 1.40, -1.08), (0.0, 1.25, -1.52 if owl else -1.60), 0.15 if owl else 0.14, keratin, hero)
    rigid_skin(beak, rig, "Head")
    parts.append(beak)
    lower_beak = ellipsoid_between(
        "V5LowerBeakDetail",
        (0.0, 1.33, -1.10),
        (0.0, 1.23, -1.42 if owl else -1.49),
        0.082 if owl else 0.074,
        dark,
        hero,
        0.42,
    )
    rigid_skin(lower_beak, rig, "Head")
    parts.append(lower_beak)
    for side in (-1.0, 1.0):
        eye_position = (side * (0.30 if owl else 0.24), 1.52, -1.03)
        eyeball = uv_sphere(f"V5EyeDetail_{side:+.0f}", eye_position, (0.096 if owl else 0.066, 0.098 if owl else 0.070, 0.058 if owl else 0.043), eye, hero)
        rigid_skin(eyeball, rig, "Head")
        parts.append(eyeball)
        brow = uv_sphere(
            f"V5EyeBrowDetail_{side:+.0f}",
            (eye_position[0], eye_position[1] + (0.075 if owl else 0.055), eye_position[2] + 0.018),
            (0.13 if owl else 0.095, 0.035, 0.072 if owl else 0.052),
            coat,
            hero,
        )
        rigid_skin(brow, rig, "Head")
        parts.append(brow)
        if hero:
            nostril = uv_sphere(
                f"V5BeakNostrilDetail_{side:+.0f}",
                (side * (0.055 if owl else 0.050), 1.385, -1.185),
                (0.015, 0.010, 0.018),
                dark,
                hero,
            )
            rigid_skin(nostril, rig, "Head")
            parts.append(nostril)
    attach_socket("SkillSocket_Beak", (0.0, 1.32, -1.48), rig, "Head")
    rig["eco_species"] = species
    rig["eco_rig_family"] = "avian"
    rig["anatomy_profile"] = "v5_near_realistic_raptor_three_stage_wing_neck_tail"
    rig["surface_profile"] = "v5_flush_feather_regions_beak_talons"
    rig["wing_segments"] = 3
    create_bird_actions(rig, species)
    return rig, parts


def create_bird_actions(rig: bpy.types.Object, species: str) -> None:
    names = ACTIONS + ("glide", "flap", "dive", "land")
    rig.animation_data_create()
    for action_name in names:
        action = bpy.data.actions.new(action_name)
        rig.animation_data.action = action
        for pose_bone in rig.pose.bones:
            pose_bone.rotation_mode = "XYZ"
            pose_bone.rotation_euler = (0.0, 0.0, 0.0)
            pose_bone.keyframe_insert(data_path="rotation_euler", frame=1, group=pose_bone.name)
        if action_name in ("locomotion", "sprint", "flap"):
            owl = species == "owl"
            amount = (0.78 if action_name == "locomotion" else 1.02) if owl else (0.62 if action_name == "locomotion" else 0.88)
            frames = (1, 5, 9, 13, 17, 21, 25, 29, 33)
            for frame_index, frame in enumerate(frames):
                phase = math.tau * frame_index / (len(frames) - 1)
                curve = math.cos(phase)
                elbow_curve = math.sin(phase - 0.48)
                for suffix, side in (("L", -1.0), ("R", 1.0)):
                    # A Blender bone's local Y is its own long axis.  Drive the
                    # mirrored wings around local X for true vertical travel,
                    # use Z for elbow folding, and reserve Y for feather wash.
                    rig.pose.bones[f"Wing_{suffix}"].rotation_euler[0] = amount * curve
                    rig.pose.bones[f"WingTip_{suffix}"].rotation_euler[0] = amount * 0.46 * curve + 0.22 * elbow_curve
                    rig.pose.bones[f"WingTip_{suffix}"].rotation_euler[2] = 0.18 * elbow_curve
                    rig.pose.bones[f"WingPrimary_{suffix}"].rotation_euler[0] = amount * 0.28 * curve + 0.30 * elbow_curve
                    rig.pose.bones[f"WingPrimary_{suffix}"].rotation_euler[1] = side * 0.10 * math.sin(phase - 0.72)
                    rig.pose.bones[f"WingPrimary_{suffix}"].rotation_euler[2] = 0.24 * elbow_curve
                    rig.pose.bones[f"Wing_{suffix}"].keyframe_insert(data_path="rotation_euler", frame=frame, group=f"Wing_{suffix}")
                    rig.pose.bones[f"WingTip_{suffix}"].keyframe_insert(data_path="rotation_euler", frame=frame, group=f"WingTip_{suffix}")
                    rig.pose.bones[f"WingPrimary_{suffix}"].keyframe_insert(data_path="rotation_euler", frame=frame, group=f"WingPrimary_{suffix}")
                rig.pose.bones["Body"].rotation_euler[0] = (0.045 if owl else 0.032) * math.sin(phase)
                rig.pose.bones["Neck"].rotation_euler[0] = -(0.026 if owl else 0.018) * math.sin(phase)
                rig.pose.bones["Head"].rotation_euler[0] = -(0.040 if owl else 0.022) * math.sin(phase)
                rig.pose.bones["Tail"].rotation_euler[2] = 0.040 * math.sin(phase)
                rig.pose.bones["TailTip"].rotation_euler[2] = 0.075 * math.sin(phase - 0.30)
                rig.pose.bones["Body"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Body")
                rig.pose.bones["Neck"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Neck")
                rig.pose.bones["Head"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Head")
                rig.pose.bones["Tail"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Tail")
                rig.pose.bones["TailTip"].keyframe_insert(data_path="rotation_euler", frame=frame, group="TailTip")
        elif action_name == "glide":
            for frame, settle in ((1, 0.0), (12, 1.0), (24, 0.35), (36, 0.0)):
                for suffix, side in (("L", -1.0), ("R", 1.0)):
                    rig.pose.bones[f"Wing_{suffix}"].rotation_euler[0] = -0.08 + 0.04 * settle
                    rig.pose.bones[f"WingTip_{suffix}"].rotation_euler[0] = -0.04 + 0.025 * settle
                    rig.pose.bones[f"WingTip_{suffix}"].rotation_euler[2] = 0.08 - 0.03 * settle
                    rig.pose.bones[f"WingPrimary_{suffix}"].rotation_euler[1] = side * (-0.10 + 0.035 * settle)
                    rig.pose.bones[f"WingPrimary_{suffix}"].rotation_euler[2] = 0.12 - 0.04 * settle
                    rig.pose.bones[f"Wing_{suffix}"].keyframe_insert(data_path="rotation_euler", frame=frame, group=f"Wing_{suffix}")
                    rig.pose.bones[f"WingTip_{suffix}"].keyframe_insert(data_path="rotation_euler", frame=frame, group=f"WingTip_{suffix}")
                    rig.pose.bones[f"WingPrimary_{suffix}"].keyframe_insert(data_path="rotation_euler", frame=frame, group=f"WingPrimary_{suffix}")
                rig.pose.bones["Head"].rotation_euler[2] = 0.035 * settle * (-1.0 if species == "owl" else 1.0)
                rig.pose.bones["Head"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Head")
        elif action_name in ("attack", "skill", "dive"):
            for frame, curve in zip((1, 9, 20), (0.0, 1.0, 0.0)):
                rig.pose.bones["Body"].rotation_euler[0] = -0.34 * curve
                rig.pose.bones["Head"].rotation_euler[0] = 0.22 * curve
                for suffix, side in (("L", -1.0), ("R", 1.0)):
                    rig.pose.bones[f"Wing_{suffix}"].rotation_euler[0] = 0.30 * curve
                    rig.pose.bones[f"Wing_{suffix}"].rotation_euler[2] = 0.18 * curve
                    rig.pose.bones[f"WingTip_{suffix}"].rotation_euler[0] = 0.18 * curve
                    rig.pose.bones[f"WingTip_{suffix}"].rotation_euler[2] = 0.34 * curve
                    rig.pose.bones[f"WingPrimary_{suffix}"].rotation_euler[1] = side * 0.12 * curve
                    rig.pose.bones[f"WingPrimary_{suffix}"].rotation_euler[2] = 0.42 * curve
                    rig.pose.bones[f"Talon_{suffix}"].rotation_euler[0] = -0.52 * curve
                rig.pose.bones["Neck"].rotation_euler[0] = 0.14 * curve
                for name in ("Body", "Neck", "Head", "Wing_L", "Wing_R", "WingTip_L", "WingTip_R", "WingPrimary_L", "WingPrimary_R", "Talon_L", "Talon_R"):
                    rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        elif action_name == "hit":
            for frame, curve in zip((1, 6, 15), (0.0, 1.0, 0.0)):
                rig.pose.bones["Body"].rotation_euler[2] = 0.32 * curve
                rig.pose.bones["Body"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Body")
        elif action_name == "eat":
            for frame, curve in zip((1, 16, 31), (0.0, 1.0, 0.0)):
                rig.pose.bones["Head"].rotation_euler[0] = 0.48 * curve
                rig.pose.bones["Neck"].rotation_euler[0] = 0.28 * curve
                rig.pose.bones["Head"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Head")
                rig.pose.bones["Neck"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Neck")
        elif action_name in ("death", "land"):
            for frame, curve in zip((1, 18, 32), (0.0, 0.76, 1.0)):
                rig.pose.bones["Body"].rotation_euler[2] = 1.16 * curve if action_name == "death" else 0.0
                rig.pose.bones["Wing_L"].rotation_euler[0] = 0.72 * curve
                rig.pose.bones["Wing_R"].rotation_euler[0] = 0.72 * curve
                rig.pose.bones["WingTip_L"].rotation_euler[0] = 0.42 * curve
                rig.pose.bones["WingTip_R"].rotation_euler[0] = 0.42 * curve
                rig.pose.bones["WingPrimary_L"].rotation_euler[2] = 0.30 * curve
                rig.pose.bones["WingPrimary_R"].rotation_euler[2] = 0.30 * curve
                for name in ("Body", "Wing_L", "Wing_R", "WingTip_L", "WingTip_R", "WingPrimary_L", "WingPrimary_R"):
                    rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        action.use_fake_user = True
    rig.animation_data.action = bpy.data.actions["idle"]


def build_long_body(species: str, hero: bool) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    crocodile = species == "crocodile"
    coat = pbr_material(f"{species}_scale_pbr", "#526245" if crocodile else "#315a55", 0.72 if crocodile else 0.62)
    accent = pbr_material(f"{species}_accent_pbr", "#a0a16c" if crocodile else "#62b9ac", 0.66 if crocodile else 0.54)
    dark = pbr_material(f"{species}_detail_pbr", "#202b24" if crocodile else "#152522", 0.54 if crocodile else 0.42)
    eye = pbr_material(f"{species}_eye_pbr", "#d0a13a", 0.08)
    bpy.ops.object.armature_add(enter_editmode=True)
    rig = bpy.context.active_object
    rig.name = "SpeciesCrocodileSkeleton3D"
    rig.data.name = f"{species.title()}V5LongRig"
    edit = rig.data.edit_bones
    root = edit[0]
    root.name = "Root"
    root.head, root.tail = g2b((0.0, 0.18, 0.10)), g2b((0.0, 0.58, 0.10))
    spine_rear = add_bone(edit, "Spine_Rear", (0.0, 0.54, 1.12), (0.0, 0.58, 0.42), root)
    body = add_bone(edit, "Body", (0.0, 0.58, 0.42), (0.0, 0.62, -0.22), spine_rear)
    chest = add_bone(edit, "Chest", (0.0, 0.62, -0.22), (0.0, 0.65, -0.68), body)
    neck = add_bone(edit, "Neck", (0.0, 0.65, -0.68), (0.0, 0.68, -1.05), chest)
    head = add_bone(edit, "Head", (0.0, 0.68, -1.05), (0.0, 0.62, -1.78), neck)
    add_bone(edit, "Jaw", (0.0, 0.53, -1.05), (0.0, 0.50, -1.82), head)
    tail_base = add_bone(edit, "Tail_Base", (0.0, 0.58, 0.42), (0.0, 0.54, 1.18), spine_rear)
    tail_mid = add_bone(edit, "Tail_Mid", (0.0, 0.54, 1.18), (0.0, 0.48, 1.92), tail_base)
    add_bone(edit, "Tail_Tip", (0.0, 0.48, 1.92), (0.0, 0.42, 2.72), tail_mid)
    crocodile_limbs = {}
    if crocodile:
        for suffix in LIMBS:
            side = -1.0 if suffix.startswith("L") else 1.0
            front = suffix.endswith("F")
            z = -0.40 if front else 0.60
            shoulder = (side * 0.46, 0.54, z)
            joint = (side * 0.76, 0.31, z + (0.12 if front else -0.10))
            ankle = (side * 0.96, 0.13, z + (-0.09 if front else 0.13))
            toe = (side * 1.12, 0.08, z + (-0.36 if front else 0.34))
            upper = add_bone(edit, f"Leg_{suffix}", shoulder, joint, chest if front else spine_rear)
            lower = add_bone(edit, f"Lower_{suffix}", joint, ankle, upper)
            add_bone(edit, f"Paw_{suffix}", ankle, toe, lower)
            crocodile_limbs[suffix] = (shoulder, joint, ankle, toe)
    bpy.ops.object.mode_set(mode="OBJECT")
    elements = []
    if crocodile:
        chain = [
            (0.42, 0.78, 0.36, 0.72),
            (-0.28, 0.80, 0.38, 0.70),
            (-0.92, 0.65, 0.34, 0.58),
            (-1.43, 0.58, 0.30, 0.54),
            (-1.93, 0.48, 0.23, 0.64),
            (1.10, 0.52, 0.30, 0.64),
            (1.76, 0.35, 0.25, 0.58),
            (2.40, 0.18, 0.18, 0.50),
        ]
        for z, width, height, length in chain:
            centre_y = 0.54 if z < -0.8 else 0.58
            elements.append(((0.0, centre_y, z), (width, height, length), 2.16))
    else:
        for index in range(13):
            z = -1.62 + index * 0.34
            width = 0.26 * (1.0 - max(0.0, index - 6) * 0.075)
            y = 0.30 + 0.07 * math.sin(index * 0.78)
            elements.append(((0.10 * math.sin(index * 0.82), y, z), (max(width, 0.085), max(width * 0.82, 0.08), 0.42), 2.06))
        elements.append(((0.0, 0.43, -1.76), (0.36, 0.23, 0.48), 2.16))
        elements.append(((0.0, 0.42, -2.02), (0.27, 0.18, 0.30), 2.08))
    organic = metaball_mesh(f"{species.title()}OrganicBodyV2SourceConnected", elements, coat, hero)
    organic["eco_anatomy_contract"] = "v5_crocodilian_low_skull_taper" if crocodile else "v5_serpentine_tapered_axial_body"
    accent_index = append_material(organic, accent)
    dark_index = append_material(organic, dark)
    for polygon in organic.data.polygons:
        centre = sum((organic.data.vertices[index].co for index in polygon.vertices), Vector()) / len(polygon.vertices)
        godot_y = centre.z
        godot_z = centre.y
        if crocodile:
            if godot_y < 0.42:
                polygon.material_index = accent_index
            elif math.sin(godot_z * 9.2 + centre.x * 7.0) > 0.72 and godot_y > 0.62:
                polygon.material_index = dark_index
        else:
            band = math.sin((godot_z + 1.60) * math.pi * 4.2 + centre.x * 2.0)
            if band > 0.42:
                polygon.material_index = accent_index
            elif band < -0.78:
                polygon.material_index = dark_index
    organic["eco_surface_pattern"] = "v5_flush_scale_regions"
    chain_anchors = {
        "Spine_Rear": 0.78,
        "Body": 0.15,
        "Chest": -0.46,
        "Neck": -0.88,
        "Head": -1.48,
        "Tail_Base": 1.02,
        "Tail_Mid": 1.66,
        "Tail_Tip": 2.38,
    }
    weights = {name: [] for name in chain_anchors}
    for vertex in organic.data.vertices:
        z = vertex.co.y
        raw = {name: max(0.0, 1.0 - abs(z - anchor) / 0.92) ** 2 for name, anchor in chain_anchors.items()}
        total = sum(raw.values()) or 1.0
        for name in chain_anchors:
            weights[name].append(raw[name] / total)
    add_armature_weights(organic, rig, weights)
    parts = [organic]
    if crocodile:
        # A crocodile is carried by short, laterally splayed limbs.  Keep the
        # segments as overlapping fleshed forms but bind each one to its own
        # upper/lower/paw bone so elbow, wrist and toes can flex independently.
        for suffix, (shoulder, joint, ankle, toe) in crocodile_limbs.items():
            upper = tapered_segment_between(
                f"CrocodileUpperLimb_{suffix}", shoulder, joint,
                0.28 if hero else 0.27, 0.22 if hero else 0.21, coat, hero,
            )
            lower = tapered_segment_between(
                f"CrocodileLowerLimb_{suffix}", joint, ankle,
                0.23 if hero else 0.22, 0.16 if hero else 0.15, coat, hero,
            )
            foot = ellipsoid_between(
                f"CrocodileWebbedFoot_{suffix}", ankle, toe,
                0.19 if hero else 0.18, accent, hero, 0.58,
            )
            rigid_skin(upper, rig, f"Leg_{suffix}")
            rigid_skin(lower, rig, f"Lower_{suffix}")
            rigid_skin(foot, rig, f"Paw_{suffix}")
            parts.extend((upper, lower, foot))
            if hero:
                joint_cap = uv_sphere(
                    f"CrocodileElbowDetail_{suffix}", joint,
                    (0.235, 0.19, 0.22), coat, hero,
                )
                rigid_skin(joint_cap, rig, f"Lower_{suffix}")
                parts.append(joint_cap)
    for side in (-1.0, 1.0):
        eye_position = (side * (0.34 if crocodile else 0.22), 0.72 if crocodile else 0.54, -1.70)
        eyeball = uv_sphere(f"V5EyeDetail_{side:+.0f}", eye_position, (0.060 if crocodile else 0.050, 0.055 if crocodile else 0.048, 0.040 if crocodile else 0.034), eye, hero)
        rigid_skin(eyeball, rig, "Head")
        parts.append(eyeball)
        if hero:
            brow = uv_sphere(
                f"V5EyeBrowDetail_{side:+.0f}",
                (eye_position[0], eye_position[1] + 0.045, eye_position[2] + 0.015),
                (0.090 if crocodile else 0.070, 0.030, 0.058 if crocodile else 0.045),
                coat,
                hero,
            )
            rigid_skin(brow, rig, "Head")
            parts.append(brow)
    if crocodile:
        jaw_shell = ellipsoid_between(
            "LowerJawSilhouette",
            (0.0, 0.48, -1.08),
            (0.0, 0.43, -1.84),
            0.28,
            accent,
            hero,
            0.48,
        )
        rigid_skin(jaw_shell, rig, "Jaw")
        parts.append(jaw_shell)
        for side in (-1.0, 1.0):
            nostril = uv_sphere(
                f"V5CrocodileNostrilDetail_{side:+.0f}",
                (side * 0.20, 0.69, -2.19),
                (0.045, 0.022, 0.030),
                dark,
                hero,
            )
            rigid_skin(nostril, rig, "Head")
            parts.append(nostril)
        scute_count = 13 if hero else 7
        for index in range(scute_count):
            z = -0.90 + index * (2.55 / max(scute_count - 1, 1))
            scute = cone_between(f"BackScuteDetail_{index}", (0.0, 0.90, z), (0.0, 1.16, z + 0.03), 0.10, dark, hero)
            target = "Head" if z < -0.8 else "Neck" if z < -0.2 else "Body" if z < 0.55 else "Tail_Base" if z < 1.25 else "Tail_Mid"
            rigid_skin(scute, rig, target)
            parts.append(scute)
        for side in (-1.0, 1.0):
            tooth = cone_between(f"ToothDetail_{side:+.0f}", (side * 0.30, 0.49, -1.76), (side * 0.31, 0.28, -1.82), 0.07, accent, hero)
            rigid_skin(tooth, rig, "Jaw")
            parts.append(tooth)
    else:
        jaw_shell = ellipsoid_between(
            "SnakeJawSilhouette",
            (0.0, 0.43, -1.55),
            (0.0, 0.39, -1.92),
            0.18,
            accent,
            hero,
            0.62,
        )
        rigid_skin(jaw_shell, rig, "Jaw")
        parts.append(jaw_shell)
        for side in (-1.0, 1.0):
            tongue = cone_between(
                f"ForkedTongueDetail_{side:+.0f}",
                (0.0, 0.42, -1.90),
                (side * 0.08, 0.40, -2.18),
                0.018,
                dark,
                hero,
            )
            rigid_skin(tongue, rig, "Jaw")
            parts.append(tongue)
    attach_socket("SkillSocket_Jaw", (0.0, 0.48, -1.92), rig, "Jaw")
    attach_socket("SkillSocket_TailTip", (0.0, 0.42, 2.75), rig, "Tail_Tip")
    rig["eco_species"] = species
    rig["eco_rig_family"] = "long_body"
    rig["anatomy_profile"] = "v5_near_realistic_crocodilian_three_segment_limbs" if crocodile else "v5_near_realistic_serpentine_eight_segment_spine"
    rig["surface_profile"] = "v5_flush_scale_regions_facial_landmarks"
    rig["axial_segments"] = 8
    if crocodile:
        rig["limb_segments"] = 3
    create_long_actions(rig, crocodile)
    return rig, parts


def create_long_actions(rig: bpy.types.Object, crocodile: bool) -> None:
    names = ACTIONS + ("swim",)
    rig.animation_data_create()
    for action_name in names:
        action = bpy.data.actions.new(action_name)
        rig.animation_data.action = action
        for pose_bone in rig.pose.bones:
            pose_bone.rotation_mode = "XYZ"
            pose_bone.rotation_euler = (0.0, 0.0, 0.0)
            pose_bone.keyframe_insert(data_path="rotation_euler", frame=1, group=pose_bone.name)
        if action_name in ("locomotion", "sprint", "swim"):
            amount = (0.17 if action_name == "locomotion" else 0.30) if crocodile else (0.32 if action_name == "locomotion" else 0.52)
            frames = (1, 5, 9, 13, 17, 21, 25, 29, 33)
            chain = ("Spine_Rear", "Body", "Chest", "Neck", "Head", "Tail_Base", "Tail_Mid", "Tail_Tip")
            flex_signs = {suffix: limb_chain_flex_sign(rig, suffix) for suffix in LIMBS} if crocodile else {}
            for frame_index, frame in enumerate(frames):
                phase = math.tau * frame_index / (len(frames) - 1)
                for index, name in enumerate(chain):
                    direction = -1.0 if name in ("Neck", "Head") else 1.0
                    # Long-body bones also use local Y as their longitudinal
                    # axis.  Lateral locomotion must rotate around local Z so
                    # the wave travels through the actual spine and tail.
                    rig.pose.bones[name].rotation_euler[2] = direction * amount * math.sin(phase - index * (0.44 if crocodile else 0.72))
                    rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
                if crocodile:
                    for limb_index, suffix in enumerate(LIMBS):
                        limb_phase = phase + (0.0 if limb_index in (0, 3) else math.pi)
                        swing = math.sin(limb_phase)
                        lift = max(0.0, math.sin(limb_phase - 0.35))
                        rig.pose.bones[f"Leg_{suffix}"].rotation_euler[0] = 0.28 * swing
                        rig.pose.bones[f"Leg_{suffix}"].rotation_euler[2] = 0.12 * math.cos(limb_phase)
                        rig.pose.bones[f"Lower_{suffix}"].rotation_euler[0] = flex_signs[suffix] * (0.18 + 0.38 * lift)
                        rig.pose.bones[f"Paw_{suffix}"].rotation_euler[0] = -flex_signs[suffix] * (0.10 + 0.26 * lift)
                        for name in (f"Leg_{suffix}", f"Lower_{suffix}", f"Paw_{suffix}"):
                            rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        elif action_name in ("attack", "skill"):
            for frame, curve in zip((1, 9, 21), (0.0, 1.0, 0.0)):
                rig.pose.bones["Jaw"].rotation_euler[0] = -0.46 * curve
                rig.pose.bones["Head"].rotation_euler[2] = 0.18 * curve
                rig.pose.bones["Tail_Mid"].rotation_euler[2] = -0.42 * curve
                rig.pose.bones["Chest"].rotation_euler[2] = 0.14 * curve
                for name in ("Jaw", "Head", "Chest", "Tail_Mid"):
                    rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        elif action_name == "hit":
            for frame, curve in zip((1, 6, 15), (0.0, 1.0, 0.0)):
                rig.pose.bones["Body"].rotation_euler[2] = 0.24 * curve
                rig.pose.bones["Body"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Body")
        elif action_name == "eat":
            for frame, curve in zip((1, 16, 31), (0.0, 1.0, 0.0)):
                rig.pose.bones["Head"].rotation_euler[0] = 0.26 * curve
                rig.pose.bones["Jaw"].rotation_euler[0] = -0.22 * curve
                rig.pose.bones["Head"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Head")
                rig.pose.bones["Jaw"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Jaw")
        elif action_name == "death":
            for frame, curve in zip((1, 18, 32), (0.0, 0.76, 1.0)):
                rig.pose.bones["Body"].rotation_euler[2] = 0.82 * curve
                rig.pose.bones["Body"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Body")
        elif action_name == "idle":
            for frame, curve in ((1, 0.0), (12, 1.0), (24, 0.0), (36, -1.0), (48, 0.0)):
                rig.pose.bones["Head"].rotation_euler[2] = 0.055 * curve
                rig.pose.bones["Tail_Tip"].rotation_euler[2] = -0.10 * curve
                rig.pose.bones["Head"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Head")
                rig.pose.bones["Tail_Tip"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Tail_Tip")
        action.use_fake_user = True
    rig.animation_data.action = bpy.data.actions["idle"]


def triangle_count(objects: list[bpy.types.Object]) -> int:
    total = 0
    for obj in objects:
        obj.data.calc_loop_triangles()
        total += len(obj.data.loop_triangles)
    return total


def mesh_island_summaries(obj: bpy.types.Object) -> list[tuple[int, tuple[float, float, float]]]:
    vertex_count = len(obj.data.vertices)
    if vertex_count == 0:
        return []
    adjacency = [[] for _ in range(vertex_count)]
    for edge in obj.data.edges:
        first, second = edge.vertices
        adjacency[first].append(second)
        adjacency[second].append(first)
    remaining = set(range(vertex_count))
    islands = []
    while remaining:
        component = [remaining.pop()]
        stack = component.copy()
        while stack:
            vertex_index = stack.pop()
            for neighbour in adjacency[vertex_index]:
                if neighbour in remaining:
                    remaining.remove(neighbour)
                    stack.append(neighbour)
                    component.append(neighbour)
        centroid = sum((obj.data.vertices[index].co for index in component), Vector()) / len(component)
        islands.append((len(component), tuple(round(value, 3) for value in centroid)))
    return sorted(islands, reverse=True)


def validate_continuous_flesh(species: str, parts: list[bpy.types.Object]) -> None:
    organic_body = next((obj for obj in parts if "OrganicBodyV2" in obj.name), None)
    if organic_body is None:
        raise RuntimeError(f"{species}: missing OrganicBodyV2")
    island_summaries = mesh_island_summaries(organic_body)
    if len(island_summaries) != 1:
        raise RuntimeError(f"{species}: OrganicBodyV2 has disconnected mesh islands {island_summaries}")


def export_species(species: str, hero: bool, output_root: Path) -> tuple[int, int, int]:
    reset_scene()
    if species in BIRDS:
        rig, parts = build_bird(species, hero)
    elif species in LONG_BODY:
        rig, parts = build_long_body(species, hero)
    else:
        cfg = config_for(species)
        layout = ground_layout(cfg)
        rig, anchors = build_ground_rig(species, cfg, layout)
        parts = build_ground_parts(species, hero, rig, anchors, cfg, layout)
        create_ground_actions(rig, cfg)
    validate_continuous_flesh(species, parts)
    profile = "hero" if hero else "mobile"
    output = output_root / species / f"{species}_{profile}.glb"
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=str(output), export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="ACTIONS",
        export_skins=True, export_yup=True, export_apply=True,
    )
    triangles = triangle_count(parts)
    vertices = sum(len(obj.data.vertices) for obj in parts)
    if not output.is_file() or output.stat().st_size < 4096:
        raise RuntimeError(f"failed to export {output}")
    return triangles, vertices, len(rig.data.bones)


def main() -> None:
    args = parse_args()
    output_root = Path(args.output_root).resolve()
    requested = tuple(args.species) if args.species else REMAINING_SPECIES
    for species in requested:
        for hero in (True, False):
            triangles, vertices, bones = export_species(species, hero, output_root)
            print(f"V5_SPECIES_MODEL_OK: {species} / {'hero' if hero else 'mobile'} / {triangles} triangles / {vertices} vertices / {bones} bones")


if __name__ == "__main__":
    main()
