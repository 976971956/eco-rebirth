extends SceneTree

const Catalog = preload("res://scripts/species_catalog.gd")
const ActorScript = preload("res://scripts/eco_actor.gd")
const ProjectileScript = preload("res://scripts/skill_projectile.gd")
const WorldScript = preload("res://scripts/eco_world.gd")

class ValidationGame:
	extends Node
	var actors: Array[EcoActor] = []
	var batch_mode: bool = true
	var player: EcoActor
	var world: Node

	func get_living_actors() -> Array[EcoActor]:
		return actors.filter(func(actor: EcoActor) -> bool: return is_instance_valid(actor) and not actor.dead)

	func get_ai_damage_multiplier() -> float:
		return 1.0

	func play_sfx_near(_effect_name: String, _position: Vector3, _is_player: bool) -> void:
		pass

	func show_hint(_message: String) -> void:
		pass

	func nearest_corpse(_origin: Vector3, _max_distance: float) -> Node3D:
		return null

	func nearest_food(_origin: Vector3, _max_distance: float, _eater_species: String = "") -> Node3D:
		return null


func _initialize() -> void:
	_run_validation.call_deferred()


func _run_validation() -> void:
	var failures: Array[String] = []
	var container := Node3D.new()
	container.name = "SpeciesValidation"
	root.add_child(container)
	var game_stub := ValidationGame.new()
	container.add_child(game_stub)

	for index in range(Catalog.ORDER.size()):
		var species_id: String = Catalog.ORDER[index]
		if not Catalog.DATA.has(species_id):
			failures.append("%s 没有物种数据" % species_id)
			continue
		var data: Dictionary = Catalog.get_data(species_id)
		for required_key in ["name", "health", "stamina", "speed", "attack", "skill", "xp_reward"]:
			if not data.has(required_key):
				failures.append("%s 缺少字段 %s" % [species_id, required_key])
		var actor: EcoActor = ActorScript.new()
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		container.add_child(actor)
		actor.setup(game_stub, index + 1, species_id, false, Vector3(index * 4.0, 0.0, 0.0), 0)
		if actor.body_root == null or actor.body_root.get_child_count() == 0:
			failures.append("%s 没有生成可见模型" % species_id)
		var regions: Array[String] = Catalog.preferred_regions(species_id)
		if regions.is_empty():
			failures.append("%s 没有配置偏好生态区" % species_id)
		for region_id in regions:
			if region_id not in ["forest", "grassland", "wetland", "highland"]:
				failures.append("%s 配置了未知生态区 %s" % [species_id, region_id])
		for prey_id in data.get("preferred_prey", []):
			if not Catalog.DATA.has(prey_id):
				failures.append("%s 配置了未知猎物 %s" % [species_id, prey_id])

	var rng := RandomNumberGenerator.new()
	var minimum_types_by_level := [4, 6, 8, 10, 12, 14, 16, 18, 20, 22]
	for campaign_level in range(1, 11):
		rng.seed = 7100 + campaign_level
		var available: Array[String] = Catalog.available_species(campaign_level)
		var type_count: int = minimum_types_by_level[campaign_level - 1]
		var roster: Array[String] = Catalog.build_roster(rng, maxi(available.size() * 2, 10), Vector2i(type_count, type_count), campaign_level)
		for species_id in roster:
			if Catalog.unlock_level(species_id) > campaign_level:
				failures.append("第%d关错误生成未解锁物种 %s" % [campaign_level, species_id])
		if campaign_level in range(2, 10):
			for species_id in available:
				if Catalog.unlock_level(species_id) == campaign_level and not roster.has(species_id):
					failures.append("第%d关没有生成本关新物种 %s" % [campaign_level, species_id])

	var new_species: Array[String] = [
		"boar", "raccoon", "porcupine", "lynx", "capybara", "otter", "goat", "wolverine", "bison",
		"zebra", "elephant", "crocodile", "tiger", "monkey", "owl", "moose", "turtle", "cheetah",
		"rhino", "gorilla", "eagle", "hippo", "hyena", "lion"
	]
	for index in range(new_species.size()):
		var attacker: EcoActor = ActorScript.new()
		attacker.process_mode = Node.PROCESS_MODE_DISABLED
		container.add_child(attacker)
		attacker.setup(game_stub, 100 + index * 2, new_species[index], false, Vector3.ZERO, 0)
		var target: EcoActor = ActorScript.new()
		target.process_mode = Node.PROCESS_MODE_DISABLED
		container.add_child(target)
		target.setup(game_stub, 101 + index * 2, "rabbit", false, Vector3(0.0, 0.0, -2.4), 0)
		target.max_health = 10000.0
		target.health = target.max_health
		target.spawn_protection = 0.0
		attacker.spawn_protection = 0.0
		game_stub.actors = [attacker, target]
		var target_health_before := target.health
		var skill_used := attacker.use_skill(target)
		if not skill_used:
			failures.append("%s 的主动技能未能命中近距离测试目标" % new_species[index])
		elif attacker.skill_timer <= 0.0:
			failures.append("%s 的主动技能没有进入冷却" % new_species[index])
		if new_species[index] == "monkey":
			var projectile_created := false
			for child in container.get_children():
				if child.get_script() == ProjectileScript:
					projectile_created = true
					child.free()
			if not projectile_created:
				failures.append("monkey 的果实投掷没有生成真实投射物")
		if new_species[index] == "otter" and float(attacker.data.get("wetland_speed", 1.0)) <= 1.0:
			failures.append("otter 没有配置湿地区域速度优势")
		if new_species[index] == "turtle" and attacker.shell_guard_timer <= 0.0:
			failures.append("turtle 的缩壳技能没有进入防御姿态")
		elif new_species[index] == "turtle":
			var turtle_health_before := attacker.health
			attacker.take_damage(100.0, target)
			if turtle_health_before - attacker.health > 20.0:
				failures.append("turtle 缩壳后的承伤降低没有生效")
		if new_species[index] == "elephant" and not Catalog.has_trait("elephant", "obstacle_breaker"):
			failures.append("elephant 没有配置巨体开路特征")
		if new_species[index] in ["owl", "eagle"]:
			if not Catalog.has_trait(new_species[index], "flying") or attacker.flight_dive_timer <= 0.0:
				failures.append("%s 没有进入有效飞行俯冲状态" % new_species[index])
			await create_timer(0.24).timeout
			if target.health >= target_health_before:
				failures.append("%s 的俯冲预警结束后没有命中目标" % new_species[index])
		if new_species[index] == "cheetah" and attacker.burst_exhaustion_timer <= 0.0:
			failures.append("cheetah 极速猎杀后没有进入疲劳窗口")
		attacker.free()
		target.free()
	game_stub.actors.clear()

	var world_test: EcoWorld = WorldScript.new()
	container.add_child(world_test)
	var light_tree_visual := Node3D.new()
	var light_tree_collider := StaticBody3D.new()
	world_test.add_child(light_tree_visual)
	world_test.add_child(light_tree_collider)
	world_test.obstacles.append(Vector3.ZERO)
	world_test.obstacle_radii.append(0.38)
	world_test.obstacle_visuals.append(light_tree_visual)
	world_test.obstacle_colliders.append(light_tree_collider)
	world_test.obstacle_kinds.append("tree")
	if world_test.flatten_light_obstacles_near(Vector3.ZERO, 1.0, 1) != 1:
		failures.append("巨象开路没有移除轻型树木")
	elif not world_test.obstacles.is_empty() or not world_test.obstacle_radii.is_empty() or not world_test.obstacle_kinds.is_empty():
		failures.append("巨象开路后障碍导航数组没有保持同步")
	var basin_center := Vector3(-world_test.world_size * 0.25, 0.0, world_test.world_size * 0.25)
	if world_test.water_depth_at(basin_center) <= 0.45:
		failures.append("湿地中心没有生成深水速度带")
	if world_test.water_depth_at(Vector3(world_test.world_size * 0.25, 0.0, -world_test.world_size * 0.25)) > 0.0:
		failures.append("草原区域被错误标记为水域")
	world_test.obstacles.append(Vector3(-1.5, 0.0, -1.5))
	world_test.obstacle_radii.append(1.0)
	world_test.obstacle_kinds.append("tree")
	var landing := world_test.nearest_legal_landing(Vector3(-1.5, 0.0, -1.5), 0.55)
	if not world_test.is_landing_clear(landing, 0.55):
		failures.append("飞行动物没有找到避开障碍的合法落点")
	game_stub.world = world_test
	var monkey_test: EcoActor = ActorScript.new()
	monkey_test.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(monkey_test)
	monkey_test.setup(game_stub, 900, "monkey", false, Vector3(-2.0, 0.0, -2.0), 0)
	if not monkey_test._try_enter_canopy(4.0) or monkey_test.canopy_timer <= 0.0:
		failures.append("猕猴靠近树木时没有进入树冠移动域")
	monkey_test.free()
	game_stub.world = null
	world_test.weather_id = "storm"
	world_test.time_phase = "day"
	if world_test.movement_multiplier("eagle", Vector3.ZERO) >= 1.0:
		failures.append("风暴没有削弱飞行动物速度")
	if world_test.flight_stamina_multiplier() <= 1.0:
		failures.append("风暴没有增加飞行耐力消耗")
	world_test.weather_id = "rain"
	world_test.visual_effects_enabled = true
	world_test._build_weather_visuals()
	if world_test.precipitation == null:
		failures.append("暴雨没有生成局部降水视觉")
	world_test.free()

	if failures.is_empty():
		print("SPECIES_VALIDATION_OK: %d species, progressive pools 1-10, %d new skills, flight/weather/canopy rules" % [Catalog.ORDER.size(), new_species.size()])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
