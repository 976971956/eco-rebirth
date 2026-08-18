extends SceneTree

const WorldScript = preload("res://scripts/eco_world.gd")


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var world: EcoWorld = WorldScript.new()
	scene.add_child(world)
	world.setup(20260818, 140.0, 1, true, "clear", "day", "high")

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 47.0
	camera.near = 0.2
	camera.far = 240.0
	camera.position = Vector3(0.0, 10.5, -48.0)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.25, -68.0), Vector3.UP)
	camera.current = true

	for _frame in range(36):
		await process_frame
	var output_path := "res://docs/images/v72-visible-world-boundary.png"
	var result := root.get_texture().get_image().save_png(output_path)
	if result == OK:
		print("BOUNDARY_PREVIEW_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存可见地图边界验收图：%s" % result)
		quit(1)
