extends SceneTree

const ActorScript = preload("res://scripts/eco_actor.gd")
const Catalog = preload("res://scripts/species_catalog.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")
const GRASS_TEXTURE = preload("res://assets/textures/terrain/grassland_ai.jpg")


class ShowcaseGame:
	extends Node
	var batch_mode: bool = false
	var player: EcoActor
	var world: Node
	var world_seed: int = 20260815

	func get_quality_preset() -> String:
		return "high"


const GALLERY_GROUPS := [
	["rabbit", "fox", "deer"],
	["wolf", "bear", "boar"],
	["raccoon", "porcupine", "capybara"],
	["otter", "lynx", "goat"],
	["wolverine", "bison", "zebra"],
	["elephant", "tiger", "monkey"],
	["owl", "moose", "turtle"],
	["cheetah", "rhino", "gorilla"],
	["eagle", "hippo", "hyena"],
	["lion", "snake", "crocodile"],
]
const GALLERY_SCALE := {
	"rabbit": 0.70, "fox": 0.64, "deer": 0.48, "wolf": 0.58, "bear": 0.46,
	"boar": 0.54, "raccoon": 0.68, "porcupine": 0.62, "capybara": 0.60, "otter": 0.68,
	"lynx": 0.64, "goat": 0.58, "wolverine": 0.62, "bison": 0.43, "zebra": 0.48,
	"elephant": 0.37, "tiger": 0.50, "monkey": 0.64, "owl": 0.58, "moose": 0.40,
	"turtle": 0.66, "cheetah": 0.55, "rhino": 0.40, "gorilla": 0.48, "eagle": 0.52,
	"hippo": 0.39, "hyena": 0.54, "lion": 0.48, "snake": 0.54, "crocodile": 0.40,
}


func _initialize() -> void:
	_render_gallery.call_deferred()


func _render_gallery() -> void:
	var all_ok := true
	for group_index in range(GALLERY_GROUPS.size()):
		var group_suffix := char(97 + group_index)
		var idle_output := "res://docs/images/v54-v5-realistic-gallery-%s-idle.png" % group_suffix
		var move_output := "res://docs/images/v54-v5-realistic-gallery-%s-move.png" % group_suffix
		all_ok = await _render_group(GALLERY_GROUPS[group_index], group_index, idle_output, "idle") and all_ok
		all_ok = await _render_group(GALLERY_GROUPS[group_index], group_index, move_output, "locomotion") and all_ok
	if all_ok:
		print("V5_SPECIES_GALLERY_OK: 30 species / 20 close-up screenshots / idle + locomotion")
		quit(0)
	else:
		push_error("无法保存 V5 三十物种近景验收图")
		quit(1)


func _render_group(species_group: Array, group_index: int, output_path: String, animation_name: String) -> bool:
	var scene := Node3D.new()
	root.add_child(scene)
	var game_stub := ShowcaseGame.new()
	scene.add_child(game_stub)
	_build_environment(scene, group_index)
	var x_positions := [4.6, 0.0, -4.6]
	for index in range(species_group.size()):
		var species_id := str(species_group[index])
		var actor: EcoActor = ActorScript.new()
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		scene.add_child(actor)
		actor.setup(game_stub, group_index * 10 + index + 1, species_id, true, Vector3.ZERO, 0)
		actor.position = Vector3(float(x_positions[index]), 0.0, 0.0)
		actor.scale = Vector3.ONE * float(GALLERY_SCALE.get(species_id, 0.55)) * 1.22
		actor.rotation.y = 0.38
		_hide_actor_ui(actor)
		if is_instance_valid(actor.external_animation_player) and actor.external_animation_player.has_animation(animation_name):
			actor.external_animation_player.play(animation_name)
			actor.external_animation_player.seek(0.38 if animation_name == "locomotion" else 0.16, true)
		_add_label(scene, Catalog.display_name(species_id), actor.position + Vector3(0.0, 3.38, 0.0), 28)
	var pose_title := "移动动作定格" if animation_name == "locomotion" else "静止轮廓"
	_add_label(scene, "Blender V5 · 逐物种解剖 / 贴体纹理 / 渐薄耳足 · %s · 第 %d/10 组" % [pose_title, group_index + 1], Vector3(0.0, 4.62, 2.0), 34)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.85
	camera.position = Vector3(0.0, 10.4, -20.6)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.36, 0.0), Vector3.UP)
	camera.current = true
	for _frame in range(18):
		await process_frame
	var image := root.get_texture().get_image()
	var result := image.save_png(output_path)
	scene.queue_free()
	for _frame in range(3):
		await process_frame
	return result == OK


func _build_environment(scene: Node3D, group_index: int) -> void:
	var palettes := [
		[Color("#264b3c"), Color("#d7bd82"), Color("#3d5338")],
		[Color("#315363"), Color("#d7c49b"), Color("#6e7048")],
		[Color("#243d55"), Color("#d4b48c"), Color("#4f6546")],
	]
	var palette: Array = palettes[group_index % palettes.size()]
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = palette[0]
	sky_material.sky_horizon_color = palette[1]
	sky_material.ground_horizon_color = palette[2]
	sky_material.ground_bottom_color = Color("#111a16")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.90
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.04
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.04
	environment_node.environment = environment
	scene.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	sun.light_color = Color("#ffe0ae")
	sun.light_energy = 1.20
	sun.shadow_enabled = false
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#b8d9e2")
	fill.light_energy = 0.55
	fill.rotation_degrees = Vector3(55.0, 145.0, 0.0)
	scene.add_child(fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(32.0, 24.0)
	ground.mesh = plane
	ground.material_override = Factory.terrain_material(Color("#58633d"), Color("#8c8751"), 12.0, GRASS_TEXTURE, 7.0, 0.22)
	scene.add_child(ground)


func _hide_actor_ui(actor: EcoActor) -> void:
	actor.health_bar_root.visible = false
	if actor.selection_ring != null:
		actor.selection_ring.visible = false
	for node_name in ["PlayerArrow", "PlayerLabel"]:
		var node := actor.get_node_or_null(node_name) as Node3D
		if node != null:
			node.visible = false


func _add_label(scene: Node3D, label_text: String, label_position: Vector3, font_size: int) -> void:
	var label := Label3D.new()
	label.text = label_text
	label.font = load("res://assets/fonts/NotoSansSC-VF.ttf") as Font
	label.font_size = font_size
	label.outline_size = 8
	label.modulate = Color("#f7f1d8")
	label.outline_modulate = Color(0.02, 0.05, 0.025, 0.96)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0105
	label.position = label_position
	scene.add_child(label)
