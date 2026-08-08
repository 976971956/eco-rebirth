extends SceneTree

const WorldScript = preload("res://scripts/eco_world.gd")


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var world: EcoWorld = WorldScript.new()
	scene.add_child(world)
	world.setup(24681357, 86.0, 8, true, "clear", "day", "high")
	for child in world.decoration_root.get_children():
		if child.name.begins_with("RegionMarker_"):
			child.visible = false

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 49.0
	camera.near = 0.2
	camera.far = 220.0
	camera.position = Vector3(25.0, 20.0, 29.0)
	scene.add_child(camera)
	camera.look_at(Vector3(-1.0, 0.8, -2.0), Vector3.UP)
	camera.current = true

	for _frame in range(32):
		await process_frame
	var output_path := "res://docs/images/v16-biome-kit-v2.png"
	var result := root.get_texture().get_image().save_png(output_path)
	if result == OK:
		print("BIOME_KIT_PREVIEW_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存生态地图套装预览：%s" % result)
		quit(1)
