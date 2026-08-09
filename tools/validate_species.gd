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
		if Catalog.victory_guide(species_id).length() < 45:
			failures.append("%s 缺少完整获胜攻略" % species_id)
		var growth := Catalog.growth_profile(species_id)
		for growth_key in ["health", "attack", "speed", "stamina", "armor", "regen"]:
			if not growth.has(growth_key) or float(growth[growth_key]) <= 0.0:
				failures.append("%s 的成长配置 %s 无效" % [species_id, growth_key])
		var base_health := actor.max_health
		var base_attack := float(actor.data["attack"])
		var base_speed := float(actor.data["speed"])
		var base_stamina := actor.max_stamina
		for _growth_level in range(2, actor.MAX_LEVEL + 1):
			actor._level_up()
		if actor.max_health <= base_health or float(actor.data["attack"]) <= base_attack or float(actor.data["speed"]) <= base_speed or actor.max_stamina <= base_stamina:
			failures.append("%s 升到满级后没有全面提升生命、攻击、速度与耐力" % species_id)
		if actor.max_health > base_health * 2.25 or float(actor.data["attack"]) > base_attack * 1.72 or float(actor.data["speed"]) > base_speed * 1.20:
			failures.append("%s 的满级成长超过首发平衡上限" % species_id)
		var combat_tier := Catalog.combat_tier(species_id)
		if combat_tier < 1 or combat_tier > 5:
			failures.append("%s 的生态威胁级不在 1–5 范围" % species_id)

	if Catalog.opportunity_threat_gap("rabbit", "elephant") != 4:
		failures.append("雪兔对巨象的逆袭威胁差应为 4 级")
	if Catalog.opportunity_threat_gap("elephant", "rabbit") != 0:
		failures.append("强物种攻击弱物种不应获得逆袭补偿")
	if not is_equal_approx(Catalog.opportunity_health_ratio(4), 0.06):
		failures.append("4 级威胁差的逆袭百分比应为 6%")
	if Catalog.skill_exposure_duration("elephant") <= Catalog.skill_exposure_duration("rabbit"):
		failures.append("巨兽技能后的破绽窗口应长于微型物种")

	var rabbit_opportunity: EcoActor = ActorScript.new()
	rabbit_opportunity.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(rabbit_opportunity)
	rabbit_opportunity.setup(game_stub, 80, "rabbit", false, Vector3.ZERO, 0)
	var elephant_opportunity: EcoActor = ActorScript.new()
	elephant_opportunity.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(elephant_opportunity)
	elephant_opportunity.setup(game_stub, 81, "elephant", false, Vector3(0.0, 0.0, -1.8), 0)
	rabbit_opportunity.spawn_protection = 0.0
	elephant_opportunity.spawn_protection = 0.0
	game_stub.actors = [rabbit_opportunity, elephant_opportunity]
	elephant_opportunity.stamina = elephant_opportunity.max_stamina * 0.18
	elephant_opportunity._update_exhaustion_state()
	var opportunity_health_before := elephant_opportunity.health
	var opportunity_stamina_before := elephant_opportunity.stamina
	elephant_opportunity.take_damage(float(rabbit_opportunity.data["attack"]), rabbit_opportunity)
	var first_opportunity_damage := opportunity_health_before - elephant_opportunity.health
	if first_opportunity_damage < elephant_opportunity.max_health * 0.06:
		failures.append("弱物种命中强敌破绽时没有造成百分比逆袭伤害")
	if rabbit_opportunity.opportunity_strike_timer <= 0.0:
		failures.append("逆袭命中后没有进入防止连续触发的冷却")
	if elephant_opportunity.stamina >= opportunity_stamina_before:
		failures.append("逆袭命中没有削减强敌耐力")
	var second_health_before := elephant_opportunity.health
	elephant_opportunity.take_damage(float(rabbit_opportunity.data["attack"]), rabbit_opportunity)
	if second_health_before - elephant_opportunity.health >= first_opportunity_damage * 0.50:
		failures.append("逆袭冷却期间仍重复结算百分比伤害")
	elephant_opportunity.stamina = elephant_opportunity.max_stamina * 0.09
	elephant_opportunity._update_exhaustion_state()
	if not elephant_opportunity.exhausted:
		failures.append("耐力低于 10% 后没有进入力竭")
	elephant_opportunity.stamina = elephant_opportunity.max_stamina * 0.20
	elephant_opportunity._update_exhaustion_state()
	if not elephant_opportunity.exhausted:
		failures.append("力竭没有保持到 25% 恢复阈值")
	elephant_opportunity.stamina = elephant_opportunity.max_stamina * 0.26
	elephant_opportunity._update_exhaustion_state()
	if elephant_opportunity.exhausted:
		failures.append("耐力恢复到 25% 后仍未解除力竭")
	rabbit_opportunity.free()
	elephant_opportunity.free()
	game_stub.actors.clear()

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
		elif attacker.exposed_timer <= 0.0:
			failures.append("%s 的主动技能没有产生可反击的后摇破绽" % new_species[index])
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
		print("SPECIES_VALIDATION_OK: %d species, opportunity/exhaustion combat, growth/victory guides, progressive pools 1-10, %d new skills, flight/weather/canopy rules" % [Catalog.ORDER.size(), new_species.size()])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
