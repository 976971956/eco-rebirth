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
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#b6caae")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d7e0cd")
	environment.ambient_light_energy = 0.72
	environment_node.environment = environment
	scene.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_color = Color("#ffe0ae")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	scene.add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(32.0, 20.0)
	ground.mesh = plane
	ground.material_override = Factory.material(Color("#55754f"))
	scene.add_child(ground)

	var species_ids: Array[String] = ["owl", "cheetah", "eagle"]
	var x_positions := [-6.5, 0.0, 6.5]
	for index in range(species_ids.size()):
		var species_id := species_ids[index]
		var actor: EcoActor = ActorScript.new()
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		scene.add_child(actor)
		actor.setup(game_stub, index + 1, species_id, false, Vector3(x_positions[index % 3], 0.0, 2.5), 0)
		actor.position.y = 0.0
		actor.health_bar_root.visible = false
		var label := Label3D.new()
		label.text = "%s\n%s" % [Catalog.display_name(species_id), str(Catalog.get_data(species_id)["skill"])]
		label.font = load("res://assets/fonts/NotoSansSC-VF.ttf") as Font
		label.font_size = 42
		label.outline_size = 8
		label.modulate = Color("#f5f1d8")
		label.outline_modulate = Color(0.02, 0.05, 0.025, 0.96)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.pixel_size = 0.011
		label.position = actor.position + Vector3(0.0, 3.6, 0.0)
		scene.add_child(label)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16.5
	camera.position = Vector3(0.0, 15.5, -22.0)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.6, 2.5), Vector3.UP)
	camera.current = true

	for _frame in range(8):
		await process_frame
	var output_path := "res://docs/images/v10-species-models.png"
	var image := root.get_texture().get_image()
	var result := image.save_png(output_path)
	if result == OK:
		print("SPECIES_GALLERY_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存物种画廊：%s" % result)
		quit(1)
