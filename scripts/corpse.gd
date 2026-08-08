class_name EcoCorpse
extends Node3D

const Factory = preload("res://scripts/low_poly_factory.gd")
const Catalog = preload("res://scripts/species_catalog.gd")

var species_id: String
var food_amount: float
var max_food: float
var lifetime: float
var age: float = 0.0
var source_actor_id: int = -1
var visual_root: Node3D


func setup(dead_species: String, actor_id: int) -> void:
	species_id = dead_species
	source_actor_id = actor_id
	var data := Catalog.get_data(species_id)
	var size_level := int(data["size"])
	food_amount = 24.0 + size_level * 22.0
	max_food = food_amount
	lifetime = 55.0 + size_level * 15.0
	visual_root = Node3D.new()
	visual_root.name = "CorpseVisual"
	add_child(visual_root)
	var base_color := Catalog.get_color(species_id).darkened(0.36)
	var body := Factory.sphere("Body", base_color, Vector3(1.15 + size_level * 0.13, 0.26, 0.72 + size_level * 0.08), Vector3(0.0, 0.26, 0.0))
	body.rotation.z = 0.14
	visual_root.add_child(body)
	var marker := Factory.sphere("Scent", Color(0.66, 0.82, 0.48, 0.45), Vector3(0.17, 0.17, 0.17), Vector3(0.0, 1.0, 0.0), 6, 3)
	visual_root.add_child(marker)


func consume(requested: float) -> float:
	if food_amount <= 0.0:
		return 0.0
	var taken := minf(requested, food_amount)
	food_amount -= taken
	var ratio := clampf(food_amount / max_food, 0.0, 1.0)
	visual_root.scale = Vector3.ONE * lerpf(0.35, 1.0, ratio)
	if food_amount <= 0.01:
		queue_free()
	return taken


func _process(delta: float) -> void:
	age += delta
	if age > lifetime:
		queue_free()
		return
	if visual_root != null:
		var scent := visual_root.get_node_or_null("Scent") as Node3D
		if scent != null:
			scent.position.y = 0.95 + sin(age * 2.2) * 0.12
			scent.rotation.y += delta

