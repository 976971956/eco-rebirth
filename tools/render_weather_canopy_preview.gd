extends SceneTree

const WorldScript = preload("res://scripts/eco_world.gd")
const ActorScript = preload("res://scripts/eco_actor.gd")
const Catalog = preload("res://scripts/species_catalog.gd")


class PreviewGame:
	extends Node
	var batch_mode: bool = true
	var player: EcoActor
	var world: EcoWorld


func _initialize() -> void:
	_build_preview.call_deferred()


func _build_preview() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var world: EcoWorld = WorldScript.new()
	scene.add_child(world)
	world.setup(11337, 86.0, 7, true, "storm", "night")
	for child in world.decoration_root.get_children():
		if child.name.begins_with("RegionMarker_"):
			child.visible = false

	var tree_position := Vector3(-18.0, 0.0, -18.0)
	for index in range(world.obstacles.size()):
		if index < world.obstacle_kinds.size() and world.obstacle_kinds[index] == "tree" and world.region_id_at(world.obstacles[index]) == "forest":
			tree_position = world.obstacles[index]
			break

	var game_stub := PreviewGame.new()
	game_stub.world = world
	scene.add_child(game_stub)
	var monkey: EcoActor = ActorScript.new()
	monkey.process_mode = Node.PROCESS_MODE_DISABLED
	scene.add_child(monkey)
	var monkey_position := tree_position + Vector3(1.35, 0.0, 0.35)
	monkey.setup(game_stub, 1, "monkey", true, monkey_position, 0)
	monkey.health_bar_root.visible = false
	for child in monkey.get_children():
		if child.name in ["PlayerLabel", "PlayerArrow", "PlayerRing"]:
			child.visible = false
	monkey._try_enter_canopy(8.0)
	monkey.position.y = 3.25
	game_stub.player = monkey
	world.update_weather_focus(monkey.global_position)

	var label := Label3D.new()
	label.text = "暴风夜 · 树冠逃生\n%s · %s" % [Catalog.display_name("monkey"), Catalog.get_data("monkey")["skill"]]
	label.font = load("res://assets/fonts/NotoSansSC-VF.ttf") as Font
	label.font_size = 46
	label.outline_size = 10
	label.modulate = Color("#eef4d8")
	label.outline_modulate = Color(0.01, 0.03, 0.04, 0.96)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.011
	label.position = monkey.global_position + Vector3(0.0, 4.2, 0.0)
	scene.add_child(label)

	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.near = 0.2
	camera.far = 180.0
	camera.position = monkey.global_position + Vector3(12.5, 10.5, 14.5)
	scene.add_child(camera)
	camera.look_at(monkey.global_position + Vector3(0.0, 1.3, 0.0), Vector3.UP)
	camera.current = true

	for _frame in range(45):
		await process_frame
	var output_path := "res://docs/images/v11-weather-canopy.png"
	var image := root.get_texture().get_image()
	var result := image.save_png(output_path)
	if result == OK:
		print("WEATHER_CANOPY_PREVIEW_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存天气树冠预览图：%s" % result)
		quit(1)
