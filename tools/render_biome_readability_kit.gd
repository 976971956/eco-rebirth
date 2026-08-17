extends SceneTree

const WorldScript = preload("res://scripts/eco_world.gd")


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var world: EcoWorld = WorldScript.new()
	scene.add_child(world)
	world.setup(132032, 140.0, 10, false, "clear", "day", "high")

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 118.0
	camera.near = 0.2
	camera.far = 340.0
	camera.position = Vector3(0.0, 112.0, 82.0)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	camera.current = true

	for _frame in range(32):
		await process_frame
	var output_path := "res://docs/images/v70-realistic-biome-overview.png"
	var result := root.get_texture().get_image().save_png(output_path)
	if result == OK:
		print("BIOME_READABILITY_PREVIEW_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存生态区可读性预览：%s" % result)
		quit(1)
