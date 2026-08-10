extends SceneTree

const Catalog = preload("res://scripts/species_catalog.gd")
const ActorScript = preload("res://scripts/eco_actor.gd")
const ProjectileScript = preload("res://scripts/skill_projectile.gd")
const WorldScript = preload("res://scripts/eco_world.gd")
const FoodPatchScript = preload("res://scripts/food_patch.gd")

class ValidationGame:
	extends Node
	var actors: Array[EcoActor] = []
	var batch_mode: bool = true
	var player: EcoActor
	var world: Node
	var world_seed: int = 424242
	var interventions: Array[Dictionary] = []
	var counterplay_events: Array[Dictionary] = []

	func get_living_actors() -> Array[EcoActor]:
		return actors.filter(func(actor: EcoActor) -> bool: return is_instance_valid(actor) and not actor.dead)

	func get_ai_damage_multiplier() -> float:
		return 1.0

	func play_sfx_near(_effect_name: String, _position: Vector3, _is_player: bool) -> void:
		pass

	func show_hint(_message: String) -> void:
		pass

	func on_ecology_intervention(bait: EcoActor, aggressor: EcoActor, responder: EcoActor) -> void:
		interventions.append({"bait": bait, "aggressor": aggressor, "responder": responder})

	func on_counterplay_progress(actor: EcoActor, target: EcoActor, route_id: String, xp_award: int, chain_count: int, mastery: bool, health_restored: float, stamina_restored: float) -> void:
		counterplay_events.append({"actor": actor, "target": target, "route": route_id, "xp": xp_award, "chain": chain_count, "mastery": mastery, "health": health_restored, "stamina": stamina_restored})

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

	if ActorScript.behavior_seed(77, 3, "wolf") != ActorScript.behavior_seed(77, 3, "wolf"):
		failures.append("相同世界种子无法派生相同 AI 行为种子")
	if ActorScript.behavior_seed(77, 3, "wolf") == ActorScript.behavior_seed(78, 3, "wolf"):
		failures.append("不同世界种子错误派生了相同 AI 行为种子")
	if ActorScript.should_rest_for_stamina(0.12, 8.0, INF):
		failures.append("低耐力 AI 面对近距离天敌仍会原地休息")
	if not ActorScript.should_rest_for_stamina(0.12, 18.0, INF):
		failures.append("低耐力 AI 在安全距离外不会休息恢复")
	if ActorScript.can_regenerate_stamina(false, 0.4) or not ActorScript.can_regenerate_stamina(false, 0.0):
		failures.append("攻击后的 0.8 秒耐力恢复延迟失效")
	if not is_equal_approx(ActorScript.starvation_health_after(100.0, 100.0, 3.0), 99.0):
		failures.append("饥饿伤害不是每 3 秒最大生命 1%")
	if not is_equal_approx(ActorScript.starvation_health_after(1.2, 100.0, 3.0), 1.0):
		failures.append("饥饿伤害仍能直接杀死生物")

	var base_threat_actor: EcoActor = ActorScript.new()
	base_threat_actor.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(base_threat_actor)
	base_threat_actor.setup(game_stub, 60, "rabbit", false, Vector3.ZERO, 0)
	var high_threat_actor: EcoActor = ActorScript.new()
	high_threat_actor.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(high_threat_actor)
	high_threat_actor.setup(game_stub, 61, "rabbit", false, Vector3(3.0, 0.0, 0.0), 8)
	if high_threat_actor.max_health <= base_threat_actor.max_health or float(high_threat_actor.data["speed"]) <= float(base_threat_actor.data["speed"]) or high_threat_actor.threat_perception_multiplier <= base_threat_actor.threat_perception_multiplier:
		failures.append("世界威胁没有同步提高 AI 生命、速度和感知")
	base_threat_actor.free()
	high_threat_actor.free()

	var foraging_actor: EcoActor = ActorScript.new()
	foraging_actor.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(foraging_actor)
	foraging_actor.setup(game_stub, 62, "rabbit", false, Vector3.ZERO, 0)
	var food_patch: FoodPatch = FoodPatchScript.new()
	food_patch.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(food_patch)
	var food_rng := RandomNumberGenerator.new()
	food_rng.seed = 62
	food_patch.setup("grass", food_rng)
	game_stub.actors = [foraging_actor]
	foraging_actor.hunger = 70.0
	if not foraging_actor.try_consume_resource(food_patch) or foraging_actor.experience <= 0:
		failures.append("第一次觅食没有获得成长经验")
	var first_forage_experience := foraging_actor.experience
	foraging_actor.eat_timer = 0.0
	foraging_actor.try_consume_resource(food_patch)
	if foraging_actor.experience != first_forage_experience:
		failures.append("同一食物点可以被反复刷取经验")
	foraging_actor.free()
	food_patch.free()
	game_stub.actors.clear()

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
		if not Catalog.habitat_description(species_id).contains("主场"):
			failures.append("%s 缺少可读的环境主场说明" % species_id)
		if Catalog.counterplay_plan(species_id).length() < 24:
			failures.append("%s 缺少完整反制组合攻略" % species_id)
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
	var expected_tactical_xp := Catalog.counterplay_experience_reward("elephant", 1)
	if rabbit_opportunity.experience != expected_tactical_xp or rabbit_opportunity.tactical_actions != 1:
		failures.append("首次弱打强战术没有获得限定战术经验")
	var second_health_before := elephant_opportunity.health
	elephant_opportunity.take_damage(float(rabbit_opportunity.data["attack"]), rabbit_opportunity)
	if second_health_before - elephant_opportunity.health >= first_opportunity_damage * 0.50:
		failures.append("逆袭冷却期间仍重复结算百分比伤害")
	rabbit_opportunity.opportunity_strike_timer = 0.0
	elephant_opportunity.exposed_timer = 1.0
	var repeat_xp_before := rabbit_opportunity.experience
	elephant_opportunity.take_damage(float(rabbit_opportunity.data["attack"]), rabbit_opportunity)
	if rabbit_opportunity.experience != repeat_xp_before or rabbit_opportunity.tactical_actions != 1:
		failures.append("同一目标的同一路线可以重复刷战术经验")
	rabbit_opportunity.health = rabbit_opportunity.max_health * 0.50
	rabbit_opportunity.stamina = rabbit_opportunity.max_stamina * 0.20
	var mastery_result: Dictionary = rabbit_opportunity.register_counterplay(elephant_opportunity, "ambush")
	if not bool(mastery_result["mastery"]) or int(mastery_result["chain"]) < 2:
		failures.append("两种不同反制路线没有触发生态掌控")
	if not is_equal_approx(float(mastery_result["health"]), rabbit_opportunity.max_health * ActorScript.COUNTERPLAY_MASTERY_HEALTH_RATIO):
		failures.append("生态掌控生命恢复不等于最大生命 6%")
	if not is_equal_approx(float(mastery_result["stamina"]), rabbit_opportunity.max_stamina * ActorScript.COUNTERPLAY_MASTERY_STAMINA_RATIO):
		failures.append("生态掌控耐力恢复不等于最大耐力 18%")
	var repeated_mastery: Dictionary = rabbit_opportunity.register_counterplay(elephant_opportunity, "terrain")
	if bool(repeated_mastery["mastery"]) or float(repeated_mastery["health"]) > 0.0 or float(repeated_mastery["stamina"]) > 0.0:
		failures.append("同一强敌可以重复触发生态掌控恢复")
	rabbit_opportunity.register_counterplay(elephant_opportunity, "ecology")
	var target_tactical_xp := int(rabbit_opportunity.counterplay_xp_by_target.get(str(elephant_opportunity.actor_id), 0))
	if target_tactical_xp != Catalog.counterplay_experience_cap("elephant", 1):
		failures.append("四种路线累计战术经验没有限制到目标价值的 32%")
	var strong_result: Dictionary = elephant_opportunity.register_counterplay(rabbit_opportunity, "opportunity")
	if int(strong_result["xp"]) != 0 or elephant_opportunity.tactical_actions != 0:
		failures.append("强物种攻击弱物种错误获得战术补偿")
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
	for sample_index in range(64):
		rng.seed = 8100 + sample_index
		var teaching_roster := Catalog.build_roster(rng, 10, Vector2i(4, 5), 1)
		var teaching_foragers := 0
		for species_id in teaching_roster:
			if str(Catalog.DATA[species_id]["diet"]) == "herbivore":
				teaching_foragers += 1
		if teaching_roster.count("bear") > Catalog.roster_species_cap("bear", 1):
			failures.append("第一关生成了超过 1 只熊")
		if teaching_roster.count("wolf") > Catalog.roster_species_cap("wolf", 1):
			failures.append("第一关生成了超过 3 只狼")
		if teaching_foragers < 5:
			failures.append("第一关草食个体少于 5 只，不符合早期 50–60% 人口结构")
		if not failures.is_empty():
			break
	for campaign_level in range(1, 11):
		var individual_count := campaign_level * 10
		var type_range := Vector2i(minimum_types_by_level[campaign_level - 1], mini(minimum_types_by_level[campaign_level - 1] + 3, Catalog.available_species(campaign_level).size()))
		var bounds := Catalog.roster_forager_bounds(individual_count, campaign_level)
		for sample_index in range(32):
			rng.seed = 9200 + campaign_level * 100 + sample_index
			var sampled_roster := Catalog.build_roster(rng, individual_count, type_range, campaign_level)
			var forager_count := 0
			for species_id in sampled_roster:
				if str(Catalog.DATA[species_id]["diet"]) == "herbivore":
					forager_count += 1
			if forager_count < bounds.x or forager_count > bounds.y:
				failures.append("第%d关草食个体 %d 不在配额 %d–%d" % [campaign_level, forager_count, bounds.x, bounds.y])
				break
	rng.seed = 9901
	var final_roster := Catalog.build_roster(rng, 100, Vector2i(22, 26), 10)
	for giant_id in ["elephant", "rhino", "hippo"]:
		if final_roster.count(giant_id) > Catalog.roster_species_cap(giant_id, 10):
			failures.append("第十关%s超过生态巨兽上限" % Catalog.display_name(giant_id))

	var feeding_hunter := ActorScript.new()
	feeding_hunter.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(feeding_hunter)
	feeding_hunter.setup(game_stub, 900, "wolf", false, Vector3.ZERO, 0)
	var fresh_corpse := Node3D.new()
	container.add_child(fresh_corpse)
	if not feeding_hunter.claim_fresh_corpse(fresh_corpse):
		failures.append("肉食 AI 击杀后没有接管新鲜尸体")
	if feeding_hunter.ai_state != "food" or feeding_hunter.resource_target != fresh_corpse or feeding_hunter.state_commit_timer < 5.9:
		failures.append("捕食者没有保持进食状态，仍可能立即连杀")
	var feeding_target := ActorScript.new()
	feeding_target.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(feeding_target)
	feeding_target.setup(game_stub, 901, "rabbit", false, Vector3(0.0, 0.0, -1.0), 0)
	feeding_hunter.skill_timer = 0.0
	feeding_hunter.stamina = feeding_hunter.max_stamina
	feeding_hunter.calm_timer = 5.0
	feeding_hunter.last_attacker = null
	if feeding_hunter.use_skill(feeding_target):
		failures.append("建立期 AI 可以绕过普攻限制用技能发起战斗")
	fresh_corpse.free()
	feeding_hunter.free()
	feeding_target.free()

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
	world_test.cover_positions.append(Vector3(4.0, 0.0, 4.0))
	world_test.cover_radii.append(2.0)
	if world_test.cover_strength_at(Vector3(4.0, 0.45, 4.0), "rabbit") < 0.90:
		failures.append("雪兔进入草丛中心后没有获得有效掩护")
	if world_test.cover_strength_at(Vector3(4.0, 0.45, 4.0), "elephant") > 0.0:
		failures.append("巨象被错误允许隐蔽在草丛")
	var escape_cover := world_test.best_escape_cover(Vector3.ZERO, Vector3(-4.0, 0.0, 0.0), "rabbit", 10.0)
	if escape_cover.x == INF:
		failures.append("弱势 AI 没有找到远离威胁的草丛掩体")
	var highland_position := Vector3(6.0, 0.45, 6.0)
	if Catalog.habitat_affinity("goat", "highland") < 0.99:
		failures.append("山羊没有把岩丘高地识别为第一主场")
	if world_test.movement_multiplier("goat", highland_position) <= 1.0:
		failures.append("山羊在高地主场没有获得移动优势")
	if world_test.movement_multiplier("lion", highland_position) >= 1.0:
		failures.append("不适应高地的大型狮子没有承担客场移动成本")
	if world_test.stamina_regen_multiplier("goat", highland_position) <= 1.0 or world_test.stamina_cost_multiplier("goat", highland_position) >= 1.0:
		failures.append("主场没有同时改善山羊的耐力恢复与移动成本")
	if world_test.terrain_counter_strength("goat", highland_position, "lion", Vector3(9.0, 0.45, 6.0)) < WorldScript.TERRAIN_COUNTER_THRESHOLD:
		failures.append("山羊无法在高地主场反制客场强敌")
	if world_test.terrain_counter_strength("goat", highland_position, "eagle", Vector3(9.0, 0.45, 6.0)) > 0.0:
		failures.append("双方都适应高地时错误产生了主场反制")
	var escape_habitat := world_test.best_counter_habitat(Vector3(2.0, 0.45, -2.0), Vector3(4.0, 0.45, -2.0), "goat", "lion", 12.0)
	if escape_habitat.x == INF or world_test.region_id_at(escape_habitat) != "highland":
		failures.append("弱势 AI 没有找到可反制狮子的高地主场路线")
	game_stub.world = world_test
	var cover_rabbit: EcoActor = ActorScript.new()
	cover_rabbit.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(cover_rabbit)
	cover_rabbit.setup(game_stub, 880, "rabbit", false, Vector3(4.0, 0.45, 4.0), 0)
	var cover_elephant: EcoActor = ActorScript.new()
	cover_elephant.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(cover_elephant)
	cover_elephant.setup(game_stub, 881, "elephant", false, Vector3(4.0, 0.45, 2.4), 0)
	cover_rabbit.spawn_protection = 0.0
	cover_elephant.spawn_protection = 0.0
	game_stub.actors = [cover_rabbit, cover_elephant]
	cover_rabbit._update_cover_state(0.80)
	if not cover_rabbit.has_cover_ambush() or not cover_rabbit.is_cover_concealed():
		failures.append("小型物种在草丛停留后没有蓄成伏击")
	var ambush_health_before := cover_elephant.health
	cover_rabbit.ambush_attack_armed = true
	cover_elephant.take_damage(float(cover_rabbit.data["attack"]), cover_rabbit)
	cover_rabbit.ambush_attack_armed = false
	if ambush_health_before - cover_elephant.health < cover_elephant.max_health * 0.06:
		failures.append("草丛伏击没有直接触发对强敌的逆袭伤害")
	if cover_elephant.exposed_timer < ActorScript.AMBUSH_CREATED_EXPOSURE - 0.01:
		failures.append("草丛伏击命中后没有为第三方制造破绽")
	var cover_hunter: EcoActor = ActorScript.new()
	cover_hunter.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(cover_hunter)
	cover_hunter.setup(game_stub, 882, "wolf", false, Vector3(16.0, 0.45, 4.0), 0)
	game_stub.actors = [cover_rabbit, cover_hunter]
	cover_hunter._switch_state("hunt", cover_rabbit)
	cover_hunter._think()
	if cover_hunter.ai_state != "search" or is_instance_valid(cover_hunter.ai_target) or cover_hunter.search_timer <= 0.0:
		failures.append("追猎者丢失草丛目标后没有搜索最后目击位置")
	cover_hunter.global_position = Vector3(10.4, 0.45, 4.0)
	cover_rabbit._switch_state("hide", null)
	cover_rabbit._think()
	if cover_rabbit.ai_state != "hunt" or cover_rabbit.ai_target != cover_hunter or not cover_rabbit.has_cover_ambush():
		failures.append("弱势 AI 隐蔽后没有对进入伏击距离的天敌反打")
	cover_rabbit.free()
	cover_elephant.free()
	cover_hunter.free()
	game_stub.actors.clear()
	var terrain_goat: EcoActor = ActorScript.new()
	terrain_goat.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(terrain_goat)
	terrain_goat.setup(game_stub, 890, "goat", false, Vector3(6.0, 0.45, 6.0), 0)
	var terrain_lion: EcoActor = ActorScript.new()
	terrain_lion.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(terrain_lion)
	terrain_lion.setup(game_stub, 891, "lion", false, Vector3(10.0, 0.45, 6.0), 0)
	terrain_goat.spawn_protection = 0.0
	terrain_lion.spawn_protection = 0.0
	game_stub.actors = [terrain_goat, terrain_lion]
	terrain_goat.velocity = Vector3(3.0, 0.0, 0.0)
	terrain_goat._update_environment_state(1.20)
	if not terrain_goat.has_terrain_momentum() or not terrain_goat.can_terrain_counter(terrain_lion):
		failures.append("弱势物种在主场持续移动后没有蓄成地形反制")
	var terrain_health_before := terrain_lion.health
	terrain_goat.terrain_attack_armed = true
	terrain_lion.take_damage(float(terrain_goat.data["attack"]), terrain_goat)
	terrain_goat.terrain_attack_armed = false
	if terrain_health_before - terrain_lion.health < terrain_lion.max_health * 0.04:
		failures.append("高地主场反制没有触发对强敌的百分比逆袭伤害")
	if terrain_lion.exposed_timer < ActorScript.TERRAIN_CREATED_EXPOSURE - 0.01:
		failures.append("地形反制命中后没有留下可接续的追击破绽")
	terrain_goat.opportunity_strike_timer = 0.0
	terrain_goat.terrain_counter_cooldown = 0.0
	terrain_goat.terrain_momentum = ActorScript.TERRAIN_MOMENTUM_REQUIRED
	terrain_goat._switch_state("flee", terrain_lion)
	terrain_goat._think()
	if terrain_goat.ai_state != "hunt" or terrain_goat.ai_target != terrain_lion:
		failures.append("弱势 AI 在主场蓄势完成后没有回头反制追兵")
	terrain_goat.free()
	terrain_lion.free()
	game_stub.actors.clear()
	var leverage_rabbit: EcoActor = ActorScript.new()
	leverage_rabbit.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(leverage_rabbit)
	leverage_rabbit.setup(game_stub, 894, "rabbit", false, Vector3.ZERO, 0)
	var leverage_elephant: EcoActor = ActorScript.new()
	leverage_elephant.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(leverage_elephant)
	leverage_elephant.setup(game_stub, 895, "elephant", false, Vector3(-1.5, 0.0, 0.0), 0)
	var leverage_rhino: EcoActor = ActorScript.new()
	leverage_rhino.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(leverage_rhino)
	leverage_rhino.setup(game_stub, 896, "rhino", false, Vector3(6.0, 0.0, 0.0), 0)
	var leverage_fox: EcoActor = ActorScript.new()
	leverage_fox.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(leverage_fox)
	leverage_fox.setup(game_stub, 897, "fox", false, Vector3(2.8, 0.0, 0.0), 0)
	leverage_rabbit.spawn_protection = 0.0
	leverage_elephant.spawn_protection = 0.0
	leverage_rhino.spawn_protection = 0.0
	leverage_fox.spawn_protection = 0.0
	game_stub.actors = [leverage_rabbit, leverage_elephant, leverage_fox, leverage_rhino]
	if leverage_rabbit.ecology_leverage_candidate(leverage_elephant) != leverage_rhino:
		failures.append("弱势物种没有识别足以介入强敌的第三方")
	leverage_rabbit.take_damage(4.0, leverage_elephant)
	if leverage_rhino.ai_state != "hunt" or leverage_rhino.ai_target != leverage_elephant:
		failures.append("追击者出手后没有惊动第三方转火")
	if leverage_elephant.ecology_influence_source != leverage_rabbit or leverage_elephant.ecology_influence_reason != "生态借力":
		failures.append("生态借力没有登记后续助攻归属")
	if leverage_rabbit.ecology_leverage_cooldown < ActorScript.ECOLOGY_LEVERAGE_COOLDOWN - 0.01 or game_stub.interventions.size() != 1:
		failures.append("生态借力没有进入冷却或发送唯一战况事件")
	if leverage_rabbit.tactical_actions != 1 or int(leverage_rabbit.counterplay_xp_by_target.get(str(leverage_elephant.actor_id), 0)) <= 0:
		failures.append("生态借力没有登记战术行动与经验")
	leverage_rabbit.ecology_leverage_cooldown = 0.0
	leverage_rabbit.ai_state = "wander"
	leverage_rabbit.ai_target = null
	leverage_rhino.ai_state = "wander"
	leverage_rhino.ai_target = null
	leverage_rhino.state_commit_timer = 0.0
	leverage_rabbit._switch_state("flee", leverage_elephant)
	leverage_rabbit._update_ai(0.1)
	if leverage_rabbit.escape_intervention_actor != leverage_rhino or leverage_rabbit.desired_direction.x <= 0.0:
		failures.append("弱势 AI 逃跑时没有主动把追兵引向第三方")
	leverage_rabbit.free()
	leverage_elephant.free()
	leverage_rhino.free()
	leverage_fox.free()
	game_stub.actors.clear()
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

	var paused_timer_state := [false]
	var paused_combat_timer := create_timer(0.05, false)
	paused_combat_timer.timeout.connect(func() -> void: paused_timer_state[0] = true)
	paused = true
	await create_timer(0.12, true).timeout
	if bool(paused_timer_state[0]):
		failures.append("暂停期间战斗延迟计时器仍在运行")
	paused = false
	await create_timer(0.08, true).timeout
	if not bool(paused_timer_state[0]):
		failures.append("恢复游戏后战斗延迟计时器没有继续")

	if failures.is_empty():
		print("SPECIES_VALIDATION_OK: %d species, tactical counterplay mastery/anti-farming, ecological leverage/AI third-party routing, terrain counter/AI routing, cover ambush/search, opportunity/exhaustion combat, growth/victory guides, progressive pools 1-10, %d new skills, flight/weather/canopy rules" % [Catalog.ORDER.size(), new_species.size()])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
