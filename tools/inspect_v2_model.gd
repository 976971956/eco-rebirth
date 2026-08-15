extends SceneTree

const VisualCatalog = preload("res://scripts/species_visual_catalog.gd")


func _initialize() -> void:
	for species_id in ["rabbit", "wolf"]:
		for profile in ["hero", "mobile"]:
			var instance := VisualCatalog.instantiate(species_id, profile)
			if instance == null:
				push_error("V2_MODEL_MISSING: %s/%s" % [species_id, profile])
				quit(1)
				return
			print("V2_MODEL_TREE: %s/%s path=%s" % [species_id, profile, VisualCatalog.model_path(species_id, profile)])
			_print_tree(instance, "")
			instance.free()
	quit(0)


func _print_tree(node: Node, indent: String) -> void:
	print("%s%s <%s>" % [indent, node.name, node.get_class()])
	for child in node.get_children():
		_print_tree(child, indent + "  ")
