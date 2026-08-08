extends SceneTree

const ActorScript = preload("res://scripts/eco_actor.gd")
const Catalog = preload("res://scripts/species_catalog.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")

class GalleryGame:
	extends Node
	var batch_mode: bool = true
	var player: EcoActor
	var world: Node


func _initialize() -> void:
	_build_gallery.call_deferred()


func _build_gallery() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var game_stub := GalleryGame.new()
	scene.add_child(game_stub)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#30484b")
	sky_material.sky_horizon_color = Color("#a8aa83")
	sky_material.ground_horizon_color = Color("#33493d")
	sky_material.ground_bottom_color = Color("#0e1c17")
	sky_material.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.94
	environment.adjustment_contrast = 1.14
	environment.adjustment_saturation = 1.08
	environment_node.environment = environment
	scene.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_color = Color("#ffe0ae")
	sun.light_energy = 0.88
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.60
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#a9d2d5")
	fill.light_energy = 0.28
	fill.rotation_degrees = Vector3(-58.0, 142.0, 0.0)
	scene.add_child(fill)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(34.0, 28.0)
	ground.mesh = plane
	ground.material_override = Factory.terrain_material(Color("#425d3d"), Color("#61764a"), 12.0)
	scene.add_child(ground)

	var species_ids: Array[String] = ["bear", "wolf", "tiger", "crocodile"]
	var x_positions := [-7.5, -2.5, 2.5, 7.5]
	for index in range(species_ids.size()):
		var species_id := species_ids[index]
		var actor: EcoActor = ActorScript.new()
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		scene.add_child(actor)
		actor.setup(game_stub, index + 1, species_id, false, Vector3(x_positions[index], 0.0, 2.5), 0)
		actor.position.y = 0.0
		actor.rotation.y = 0.48
		actor.health_bar_root.visible = false
		var label := Label3D.new()
		label.text = Catalog.display_name(species_id)
		label.font = load("res://assets/fonts/NotoSansSC-VF.ttf") as Font
		label.font_size = 42
		label.outline_size = 8
		label.modulate = Color("#f5f1d8")
		label.outline_modulate = Color(0.02, 0.05, 0.025, 0.96)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.pixel_size = 0.011
		label.position = actor.position + Vector3(0.0, 4.2 + int(Catalog.get_data(species_id)["size"]) * 0.18, 0.0)
		scene.add_child(label)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.5
	camera.position = Vector3(0.0, 10.5, -18.5)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.5, 2.5), Vector3.UP)
	camera.current = true

	for _frame in range(8):
		await process_frame
	var output_path := "res://docs/images/v16-species-v2.png"
	var image := root.get_texture().get_image()
	var result := image.save_png(output_path)
	if result == OK:
		print("SPECIES_GALLERY_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存物种画廊：%s" % result)
		quit(1)
