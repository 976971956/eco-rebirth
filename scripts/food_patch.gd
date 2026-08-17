class_name FoodPatch
extends Node3D

const Factory = preload("res://scripts/low_poly_factory.gd")
const Catalog = preload("res://scripts/species_catalog.gd")

const FOOD_DATA := {
	"grass": {"name": "嫩草", "amount": 42.0, "regrow": 13.0, "nutrition": 0.90, "diets": ["herbivore", "omnivore"]},
	"berries": {"name": "野莓", "amount": 36.0, "regrow": 18.0, "nutrition": 1.00, "diets": ["herbivore", "omnivore"]},
	"mushroom": {"name": "林地蘑菇", "amount": 30.0, "regrow": 22.0, "nutrition": 1.08, "diets": ["herbivore", "omnivore"]},
	"fruit": {"name": "落果", "amount": 48.0, "regrow": 24.0, "nutrition": 1.18, "diets": ["herbivore", "omnivore"]},
	"roots": {"name": "块根", "amount": 44.0, "regrow": 26.0, "nutrition": 1.15, "diets": ["herbivore", "omnivore"]},
	"fish": {"name": "活鱼群", "amount": 48.0, "regrow": 25.0, "nutrition": 1.45, "diets": ["carnivore", "omnivore"]},
}

var amount: float = 45.0
var max_amount: float = 45.0
var regrow_delay: float = 16.0
var empty_time: float = 0.0
var active: bool = true
var regrow_enabled: bool = true
var visual_root: Node3D
var food_kind: String = "grass"
var ecology_hotspot: bool = false
var ecology_event_id: int = -1
var fish_animation_time: float = 0.0


func setup(kind: String, rng: RandomNumberGenerator) -> void:
	food_kind = kind if FOOD_DATA.has(kind) else "grass"
	var config: Dictionary = FOOD_DATA[food_kind]
	max_amount = float(config["amount"])
	amount = max_amount
	regrow_delay = float(config["regrow"])
	visual_root = Node3D.new()
	visual_root.name = "Food_%s" % food_kind
	add_child(visual_root)
	_build_visual(rng)


func _build_visual(rng: RandomNumberGenerator) -> void:
	match food_kind:
		"berries":
			for i in range(5):
				var angle := TAU * float(i) / 5.0
				visual_root.add_child(Factory.sphere("BerryLeaf", Color("#43894b").lightened(rng.randf_range(-0.05, 0.08)), Vector3(0.62, 0.32, 0.45), Vector3(cos(angle) * 0.48, 0.42, sin(angle) * 0.48), 7, 4))
			for i in range(7):
				var berry_angle := TAU * float(i) / 7.0 + 0.3
				visual_root.add_child(Factory.sphere("WildBerry", Color("#c9474f").lightened(rng.randf_range(-0.04, 0.10)), Vector3.ONE * 0.13, Vector3(cos(berry_angle) * 0.46, 0.60 + (i % 2) * 0.16, sin(berry_angle) * 0.46), 7, 4))
		"mushroom":
			for i in range(5):
				var offset := Vector3(rng.randf_range(-0.62, 0.62), 0.0, rng.randf_range(-0.52, 0.52))
				var height := rng.randf_range(0.34, 0.62)
				visual_root.add_child(Factory.tapered_cylinder("Stem", Color("#e1d5b8"), 0.08, 0.065, height, offset + Vector3.UP * height * 0.5, 7))
				visual_root.add_child(Factory.sphere("Cap", Color("#c88449").lightened(i * 0.025), Vector3(0.30, 0.12, 0.30), offset + Vector3.UP * height, 8, 4))
		"fruit":
			for i in range(7):
				var angle := TAU * float(i) / 7.0
				var fruit_color := Color("#dc9a38") if i % 2 == 0 else Color("#b94c3f")
				visual_root.add_child(Factory.sphere("FallenFruit", fruit_color, Vector3.ONE * rng.randf_range(0.20, 0.27), Vector3(cos(angle) * rng.randf_range(0.28, 0.70), 0.22, sin(angle) * rng.randf_range(0.28, 0.70)), 8, 5))
		"roots":
			for i in range(5):
				var angle := TAU * float(i) / 5.0
				var root := Factory.sphere("Root", Color("#a76b3e").lightened(i * 0.025), Vector3(0.22, 0.16, 0.48), Vector3(cos(angle) * 0.48, 0.15, sin(angle) * 0.48), 7, 4)
				root.rotation.y = -angle
				visual_root.add_child(root)
		"fish":
			for i in range(6):
				var swimmer := Node3D.new()
				swimmer.name = "LiveFish_%02d" % i
				var school_center := Vector3(rng.randf_range(-0.78, 0.78), 0.07 + float(i % 2) * 0.025, rng.randf_range(-0.60, 0.60))
				swimmer.set_meta("school_center", school_center)
				swimmer.set_meta("phase", rng.randf_range(0.0, TAU))
				swimmer.set_meta("orbit", rng.randf_range(0.10, 0.24))
				swimmer.set_meta("swim_rate", rng.randf_range(0.72, 1.20))
				var fish_color := Color("#7faeb1").lightened(rng.randf_range(-0.06, 0.11))
				swimmer.add_child(Factory.sphere("FishBody", fish_color, Vector3(0.34, 0.085, 0.14), Vector3.ZERO, 8, 4))
				var tail := Factory.cone("FishTail", fish_color.darkened(0.12), 0.13, 0.23, Vector3(0.0, 0.0, 0.24), 6)
				tail.rotation.x = PI * 0.5
				swimmer.add_child(tail)
				visual_root.add_child(swimmer)
		_:
			for i in range(8):
				var angle := TAU * float(i) / 8.0
				var blade := Factory.cone("GrassBlade", Color("#76ad4d").lightened(rng.randf_range(-0.08, 0.10)), 0.13, rng.randf_range(0.48, 0.82), Vector3(cos(angle) * 0.42, 0.35, sin(angle) * 0.42), 6)
				blade.rotation.z = rng.randf_range(-0.18, 0.18)
				visual_root.add_child(blade)


func can_be_eaten_by(species_id: String) -> bool:
	var diet := str(Catalog.get_data(species_id)["diet"])
	return diet in FOOD_DATA[food_kind]["diets"]


func get_food_name() -> String:
	return str(FOOD_DATA[food_kind]["name"])


func get_nutrition_multiplier() -> float:
	return float(FOOD_DATA[food_kind]["nutrition"])


func consume(requested: float) -> float:
	if not active or amount <= 0.0:
		return 0.0
	var taken := minf(requested, amount)
	amount -= taken
	_update_visual()
	if amount <= 0.01:
		active = false
		empty_time = 0.0
	return taken


func _process(delta: float) -> void:
	if food_kind == "fish" and active:
		_animate_fish_school(delta)
	if active or not regrow_enabled:
		return
	empty_time += delta
	if empty_time >= regrow_delay:
		amount = max_amount
		active = true
		_update_visual()


func _animate_fish_school(delta: float) -> void:
	if visual_root == null:
		return
	fish_animation_time += delta
	for child in visual_root.get_children():
		if not child is Node3D or not child.has_meta("school_center"):
			continue
		var swimmer := child as Node3D
		var center: Vector3 = swimmer.get_meta("school_center", Vector3.ZERO)
		var phase := float(swimmer.get_meta("phase", 0.0))
		var orbit := float(swimmer.get_meta("orbit", 0.16))
		var rate := float(swimmer.get_meta("swim_rate", 1.0))
		var angle := fish_animation_time * rate + phase
		swimmer.position = center + Vector3(cos(angle) * orbit, sin(angle * 1.7) * 0.018, sin(angle) * orbit)
		swimmer.rotation.y = -angle + PI * 0.5


func boost(multiplier: float) -> void:
	max_amount *= multiplier
	amount = max_amount
	active = true
	_update_visual()


func mark_ecology_hotspot(event_id: int) -> void:
	ecology_hotspot = true
	ecology_event_id = event_id


func retire_hotspot() -> void:
	regrow_enabled = false
	active = false
	amount = 0.0
	_update_visual()


func stop_regrow() -> void:
	regrow_enabled = false


func _update_visual() -> void:
	if visual_root == null:
		return
	var ratio := clampf(amount / max_amount, 0.0, 1.0)
	visual_root.visible = ratio > 0.01
	visual_root.scale = Vector3.ONE * lerpf(0.25, 1.0, ratio)
