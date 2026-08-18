extends SceneTree

const WorldScript = preload("res://scripts/eco_world.gd")
const ActorScript = preload("res://scripts/eco_actor.gd")
const Catalog = preload("res://scripts/species_catalog.gd")


class PreviewGame:
	extends Node
	var batch_mode: bool = false
	var world_seed: int = 20260818
	var current_level: int = 3
	var quality_preset: String = "high"
	var world: EcoWorld
	var player: EcoActor
	var actors: Array[EcoActor] = []

	func get_quality_preset() -> String:
		return quality_preset

	func get_living_actors() -> Array[EcoActor]:
		return actors


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var game := PreviewGame.new()
	scene.add_child(game)
	var world: EcoWorld = WorldScript.new()
	game.world = world
	game.add_child(world)
	world.setup(game.world_seed, 140.0, game.current_level, true, "clear", "day", game.quality_preset)

	var basin_center := Vector3(-35.0, 0.0, 35.0)
	var water_scale := float(world.current_level_profile().get("water", 1.0))
	var basin_radius := 140.0 * 0.145 * water_scale
	# Stay near the shoreline while keeping both actors inside the same camera
	# frame; this offset is ~0.89 of the elliptical basin radius.
	var shallow_position := basin_center + Vector3(-basin_radius * 0.75, 0.0, -basin_radius * 0.35)
	var deep_position := basin_center + Vector3(basin_radius * 0.08, 0.0, -basin_radius * 0.05)
	var positions := [shallow_position, deep_position]
	for landmark in world.find_children("RegionLandmark_*", "Node3D", true, false):
		(landmark as Node3D).visible = false
	for obstacle_index in range(world.obstacle_visuals.size()):
		var obstacle_visual := world.obstacle_visuals[obstacle_index]
		if not is_instance_valid(obstacle_visual):
			continue
		# The preview isolates the bathymetry and actors. Runtime trees remain
		# unchanged; hiding only their preview visuals keeps both labels readable.
		if world.obstacle_kinds[obstacle_index] == "tree" or positions.any(func(actor_position: Vector3): return actor_position.distance_to(world.obstacles[obstacle_index]) < 4.8):
			obstacle_visual.visible = false
	for actor_index in range(positions.size()):
		var actor: EcoActor = ActorScript.new()
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		game.add_child(actor)
		actor.setup(game, actor_index + 1, "wolf", true, positions[actor_index], 0)
		_hide_actor_ui(actor)
		actor.current_water_depth = world.water_depth_at(positions[actor_index])
		actor.velocity = Vector3(1.8, 0.0, -1.2)
		game.actors.append(actor)
		for _pose_step in range(18):
			actor._update_visual_motion(0.08)
		print("WATER_DEPTH_ACTOR: index=%d depth=%.3f wade=%.3f swimming=%s immersion=%.3f" % [
			actor_index,
			actor.current_water_depth,
			Catalog.water_wade_depth(actor.species_id),
			actor.is_swimming(),
			actor.visual_immersion_offset,
		])
		_add_depth_label(scene, actor, "浅水 %.2fm · 露腿涉水" % actor.current_water_depth if actor_index == 0 else "深水 %.2fm · 浮身游泳" % actor.current_water_depth)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 43.0
	camera.near = 0.2
	camera.far = 220.0
	var focus_position := shallow_position.lerp(deep_position, 0.54)
	camera.position = focus_position + Vector3(24.0, 15.0, 24.0)
	scene.add_child(camera)
	camera.look_at(focus_position + Vector3.UP * 0.62, Vector3.UP)
	camera.current = true

	for _frame in range(42):
		await process_frame
	var output_path := "res://docs/images/v84-water-depth-immersion.png"
	var result := root.get_texture().get_image().save_png(output_path)
	if result == OK:
		print("WATER_DEPTH_PREVIEW_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存水深与动物浸没验收图：%s" % result)
		quit(1)


func _add_depth_label(parent: Node3D, actor: EcoActor, text_value: String) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.font = load("res://assets/fonts/NotoSansSC-VF.ttf") as Font
	label.font_size = 44
	label.outline_size = 9
	label.modulate = Color("#e7f7e8")
	label.outline_modulate = Color(0.01, 0.055, 0.06, 0.96)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.011
	label.position = actor.position + Vector3(0.0, 2.65, 0.0)
	parent.add_child(label)


func _hide_actor_ui(actor: EcoActor) -> void:
	if actor.health_bar_root != null:
		actor.health_bar_root.visible = false
	if actor.selection_ring != null:
		actor.selection_ring.visible = false
	for node in actor.find_children("*", "Label3D", true, false):
		(node as Label3D).visible = false
	for child in actor.get_children():
		if child is MeshInstance3D and str(child.name) == "PlayerArrow":
			(child as MeshInstance3D).visible = false
