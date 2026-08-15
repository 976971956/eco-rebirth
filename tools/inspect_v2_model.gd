extends SceneTree

const VisualCatalog = preload("res://scripts/species_visual_catalog.gd")


func _initialize() -> void:
	call_deferred("_inspect_models")


func _inspect_models() -> void:
	var requested_species := ["rabbit", "wolf"]
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		requested_species = user_args
	for species_id in requested_species:
		for profile in ["hero", "mobile"]:
			var instance := VisualCatalog.instantiate(species_id, profile)
			if instance == null:
				push_error("V2_MODEL_MISSING: %s/%s" % [species_id, profile])
				quit(1)
				return
			print("V2_MODEL_TREE: %s/%s path=%s" % [species_id, profile, VisualCatalog.model_path(species_id, profile)])
			root.add_child(instance)
			await process_frame
			_print_tree(instance, "")
			instance.free()
	quit(0)


func _print_tree(node: Node, indent: String) -> void:
	var position_text := ""
	if node is Node3D and str(node.name).begins_with("SkillSocket_"):
		position_text = " global=%s" % str((node as Node3D).global_position)
	print("%s%s <%s>%s" % [indent, node.name, node.get_class(), position_text])
	for child in node.get_children():
		_print_tree(child, indent + "  ")
