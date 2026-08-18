extends SceneTree

const Catalog = preload("res://scripts/species_catalog.gd")
const ActorScript = preload("res://scripts/eco_actor.gd")
const ProjectileScript = preload("res://scripts/skill_projectile.gd")
const WorldScript = preload("res://scripts/eco_world.gd")
const FoodPatchScript = preload("res://scripts/food_patch.gd")
const CorpseScript = preload("res://scripts/corpse.gd")

class ValidationGame:
	extends Node
	var actors: Array[EcoActor] = []
	var batch_mode: bool = true
	var player: EcoActor
	var world: Node
	var corpses: Array[Node3D] = []
	var world_seed: int = 424242
	var interventions: Array[Dictionary] = []
	var counterplay_events: Array[Dictionary] = []
	var actor_level_events: Array[Dictionary] = []
	var player_level_events: Array[Dictionary] = []
	var player_xp_events: Array[Dictionary] = []

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

	func on_actor_level_up(actor: EcoActor, new_level: int) -> void:
		actor_level_events.append({"actor": actor, "level": new_level})

	func on_player_level_up(new_level: int, gains: Dictionary = {}) -> void:
		player_level_events.append({"level": new_level, "gains": gains.duplicate(true)})

	func on_player_experience_gained(amount: int, source_name: String, reason: String = "击杀") -> void:
		player_xp_events.append({"amount": amount, "source": source_name, "reason": reason})

	func nearest_corpse(origin: Vector3, max_distance: float, excluded_instance_id: int = 0) -> Node3D:
		var nearest: Node3D
		var nearest_distance := max_distance
		for corpse in corpses:
			if not is_instance_valid(corpse) or float(corpse.food_amount) <= 0.0:
				continue
			if excluded_instance_id != 0 and corpse.get_instance_id() == excluded_instance_id:
				continue
			var distance := origin.distance_to(corpse.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = corpse
		return nearest

	func get_available_corpses() -> Array[Node3D]:
		return corpses.filter(func(corpse: Node3D) -> bool: return is_instance_valid(corpse) and float(corpse.food_amount) > 0.0)

	func nearest_food(_origin: Vector3, _max_distance: float, _eater_species: String = "", _include_hotspots: bool = true, _excluded_instance_id: int = 0, _breath_ratio: float = 1.0, _hunger_value: float = 0.0) -> Node3D:
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
	if not is_zero_approx(ActorScript.starvation_health_after(1.2, 100.0, 6.0)):
		failures.append("饱腹耗尽后生命仍被锁在 1 点，无法触发饥饿死亡")
	if not is_equal_approx(ActorScript.drowning_health_after(100.0, 100.0, 1.0), 94.0) or not is_zero_approx(ActorScript.drowning_health_after(3.0, 100.0, 1.0)):
		failures.append("屏息耗尽后的溺水伤害没有按最大生命 6%/秒结算")
	var dry_immersion := ActorScript.water_visual_immersion(0.0, 0.24, 3, 2, false)
	var shallow_immersion := ActorScript.water_visual_immersion(0.16, 0.24, 3, 2, false)
	var deep_immersion := ActorScript.water_visual_immersion(0.92, 0.24, 3, 2, false)
	if not is_zero_approx(dry_immersion) or shallow_immersion <= 0.0 or deep_immersion <= shallow_immersion:
		failures.append("动物视觉浸没没有随陆地、浅水、深水递增")
	if not is_zero_approx(ActorScript.water_visual_immersion(0.92, 0.24, 3, 2, true)):
		failures.append("飞行动物掠过水面时被错误浸没")
	if ActorScript.water_visual_immersion(3.0, 0.14, 1, 0, false) > 0.20 or ActorScript.water_visual_immersion(3.0, 0.72, 5, 4, false) > 0.29:
		failures.append("深水浸没超出物种体型上限，可能把整只动物埋入地面")
	if Catalog.WATER_PROFILES.size() != Catalog.ORDER.size():
		failures.append("30 种动物没有全部配置独立水性")
	var breath_values := {}
	for species_id in Catalog.ORDER:
		var water_profile := Catalog.water_profile(species_id)
		for required_key in ["name", "grade", "wade_depth", "comfort_depth", "breath", "swim_speed", "fish_catch"]:
			if not water_profile.has(required_key):
				failures.append("%s 水性缺少字段 %s" % [species_id, required_key])
		breath_values[Catalog.water_breath_seconds(species_id)] = true
		if Catalog.water_comfort_depth(species_id) < Catalog.water_wade_depth(species_id):
			failures.append("%s 的 AI 舒适水深低于安全涉水深度" % species_id)
		if Catalog.water_speed_multiplier(species_id) < 0.35 or Catalog.water_speed_multiplier(species_id) > 1.55:
			failures.append("%s 的游泳速度倍率越界" % species_id)
	if breath_values.size() < 12:
		failures.append("30 种动物的屏息时间区分不足")
	if Catalog.water_breath_seconds("rabbit") >= Catalog.water_breath_seconds("otter") or Catalog.water_speed_multiplier("rabbit") >= Catalog.water_speed_multiplier("otter"):
		failures.append("雪兔与水獭没有形成明确的水性差距")
	if Catalog.ai_water_entry_depth("rabbit", 90.0, 1.0, false) > 0.20 or Catalog.ai_water_entry_depth("otter", 40.0, 1.0, false) < 1.20:
		failures.append("弱/强水性 AI 没有选择不同深度路线")
	if not is_equal_approx(Catalog.ai_water_entry_depth("fox", 80.0, 0.20, true), Catalog.water_wade_depth("fox")):
		failures.append("低屏息 AI 仍会为鱼群进入深水")
	if Catalog.fish_catch_multiplier("otter") <= Catalog.fish_catch_multiplier("fox") or Catalog.fish_catch_multiplier("rabbit") > 0.0:
		failures.append("捕鱼效率没有体现物种食性和水性")
	var satiated_bear_motivation := ActorScript.hunting_motivation(18.0, 0.55, "omnivore", 4, 0)
	var hungry_bear_motivation := ActorScript.hunting_motivation(68.0, 0.55, "omnivore", 4, 0)
	var coordinated_wolf_motivation := ActorScript.hunting_motivation(18.0, 0.68, "carnivore", 3, 1)
	if satiated_bear_motivation >= ActorScript.AI_HUNT_MOTIVATION_THRESHOLD or hungry_bear_motivation <= ActorScript.AI_HUNT_MOTIVATION_THRESHOLD:
		failures.append("大型杂食者的饥饿猎杀动机没有区分饱腹与饥饿状态")
	if coordinated_wolf_motivation <= ActorScript.AI_HUNT_MOTIVATION_THRESHOLD:
		failures.append("同伴支援没有让狼群在建立期后形成可读围猎")
	var nearby_hunt_context := {
		"diet": "carnivore", "health": 0.92, "stamina": 0.84,
		"utility": ActorScript.AI_MIN_PREY_UTILITY + 0.08,
		"motivation": ActorScript.hunting_motivation(18.0, 0.68, "carnivore", 3, 0),
		"aggression": 0.68, "pack_support": 0, "attack_range": 1.8,
		"distance": 5.8, "target_exposed": false,
	}
	if not ActorScript.should_start_proximity_hunt(nearby_hunt_context):
		failures.append("健康肉食 AI 不会主动攻击进入附近反应半径的合法猎物")
	nearby_hunt_context["diet"] = "herbivore"
	if ActorScript.should_start_proximity_hunt(nearby_hunt_context):
		failures.append("草食 AI 被近距离规则错误改成了主动猎杀者")
	nearby_hunt_context["diet"] = "carnivore"
	nearby_hunt_context["distance"] = ActorScript.AI_PROXIMITY_HUNT_MAX_RADIUS + 0.1
	if ActorScript.should_start_proximity_hunt(nearby_hunt_context):
		failures.append("近距离主动捕猎超过硬上限，可能恢复跨图仇恨")
	if ActorScript.should_replan_blocked_route(2, false) or not ActorScript.should_replan_blocked_route(3, false) or ActorScript.should_replan_blocked_route(4, true):
		failures.append("AI 连续脱困后的改道阈值或终局例外无效")
	if ActorScript.should_escalate_territory_intrusion(true, false, 14.0, 2.0, 16.0) or not ActorScript.should_escalate_territory_intrusion(true, false, 5.0, 2.0, 16.0) or not ActorScript.should_escalate_territory_intrusion(false, true, 18.0, 2.0, 16.0):
		failures.append("领地 AI 仍会跨区清场，或无法立即回应真实攻击者")
	if not ActorScript.should_show_habit_guidance(0.60, 0.80, 24.0, 0.90, false):
		failures.append("受伤雪兔不会显示生态本能资源引导")
	if ActorScript.should_show_habit_guidance(0.95, 0.90, 18.0, 0.90, false) or ActorScript.should_show_habit_guidance(0.40, 0.20, 80.0, 0.90, true):
		failures.append("健康状态或习性已激活时仍错误显示资源引导")
	if Catalog.combat_experience_reward("bear", "rabbit", 1) >= Catalog.experience_reward("rabbit", 1):
		failures.append("强物种捕杀弱小猎物仍获得完整成长经验")
	if Catalog.combat_experience_reward("rabbit", "bear", 1) != Catalog.experience_reward("bear", 1):
		failures.append("弱物种击倒强敌被错误削减成长经验")
	var rabbit_grass_effect := Catalog.habit_food_effect("rabbit", "grass", "grassland", true, "day", "clear", 0.50, 0)
	if rabbit_grass_effect.is_empty() or float(rabbit_grass_effect.get("health_ratio", 0.0)) < 0.115 or float(rabbit_grass_effect.get("stamina_ratio", 0.0)) < 0.17:
		failures.append("雪兔在草原草丛取食嫩草没有获得足够的生命与耐力恢复")
	if int(rabbit_grass_effect.get("xp_bonus", 0)) < 4:
		failures.append("雪兔完成主场草丛习性没有获得生态适应经验")
	if not Catalog.habit_food_effect("rabbit", "fruit", "grassland", true).is_empty():
		failures.append("雪兔可以用非嫩草食物错误触发草窟反刍")
	var favorable_hunt_score := ActorScript.evaluate_prey_utility({
		"hunter_health": 0.92, "hunter_stamina": 0.78, "target_health": 0.22, "target_stamina": 0.16,
		"hunger": 0.72, "aggression": 0.66, "distance": 8.0, "speed_ratio": 1.08,
		"tier_delta": 1, "size_delta": 0, "support": 2, "target_pressure": 1,
		"habitat_delta": 0.25, "threat_gap": 0, "target_exposed": true, "finisher": true,
		"pack_hunter": true, "scavenger": false, "ambush_ready": false, "aerial_small_prey": false,
		"attack_range": 2.0,
	})
	var reckless_hunt_score := ActorScript.evaluate_prey_utility({
		"hunter_health": 0.35, "hunter_stamina": 0.12, "target_health": 0.95, "target_stamina": 0.90,
		"hunger": 0.35, "aggression": 0.40, "distance": 24.0, "speed_ratio": 0.70,
		"tier_delta": -2, "size_delta": -2, "support": 0, "target_pressure": 0,
		"habitat_delta": -0.30, "threat_gap": 2, "target_exposed": false, "finisher": false,
		"pack_hunter": false, "scavenger": false, "ambush_ready": false, "aerial_small_prey": false,
		"attack_range": 2.0,
	})
	if favorable_hunt_score <= reckless_hunt_score or favorable_hunt_score < ActorScript.AI_MIN_PREY_UTILITY:
		failures.append("AI 目标效用没有优先选择残血、力竭且有队友支援的猎物")
	if reckless_hunt_score >= ActorScript.AI_MIN_PREY_UTILITY:
		failures.append("AI 仍会选择远距离、更强且无法追上的猎物")
	if not ActorScript.should_abandon_pursuit(reckless_hunt_score, 0.35, 0.12, 0.95, 24.0, 2.0, false):
		failures.append("AI 在低收益或力竭时不会放弃追击")
	if ActorScript.should_abandon_pursuit(0.0, 0.10, 0.05, 1.0, 30.0, 2.0, true):
		failures.append("终局收束战被普通脱战逻辑中断")
	if ActorScript.should_approach_contested_food(1, 0.30, 0.30, 60.0, false, 0):
		failures.append("受伤独行 AI 仍会冲进有强敌的尸体争夺点")
	if not ActorScript.should_approach_contested_food(1, 0.45, 0.80, 60.0, true, 0):
		failures.append("健康食腐者无法承担一名尸体竞争者")
	if not ActorScript.should_approach_contested_food(3, 0.20, 0.30, 90.0, false, 0):
		failures.append("即将饿死的 AI 没有在最后关头冒险进食")

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

	var growth_actor: EcoActor = ActorScript.new()
	growth_actor.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(growth_actor)
	growth_actor.setup(game_stub, 69, "wolf", true, Vector3.ZERO, 0)
	for threshold_index in range(Catalog.EXPERIENCE_THRESHOLDS.size()):
		growth_actor.level = threshold_index + 1
		growth_actor._recalculate_growth_stats()
		var expected_threshold := Catalog.experience_threshold(growth_actor.level, growth_actor.effective_size)
		if growth_actor.experience_to_next_level() != expected_threshold:
			failures.append("Lv.%d 实时体型升级门槛不是 %d" % [threshold_index + 1, expected_threshold])
	growth_actor.level = 1
	growth_actor._recalculate_growth_stats()
	var growth_base_health := growth_actor.max_health
	var growth_base_stamina := growth_actor.max_stamina
	var growth_base_attack := float(growth_actor.data["attack"])
	growth_actor.health = growth_actor.max_health * 0.20
	growth_actor.stamina = growth_actor.max_stamina * 0.05
	growth_actor.exhausted = true
	game_stub.actor_level_events.clear()
	game_stub.player_level_events.clear()
	game_stub.player_xp_events.clear()
	var two_level_reward := Catalog.experience_threshold(1, Catalog.effective_body_size("wolf", 1)) + Catalog.experience_threshold(2, Catalog.effective_body_size("wolf", 2)) + 17
	growth_actor.gain_experience(two_level_reward, "bear")
	if growth_actor.level != 3 or growth_actor.experience != 17:
		failures.append("一次获得大量经验时没有正确连升两级并保留剩余经验")
	var expected_level_three := Catalog.growth_stats("wolf", 3)
	if not is_equal_approx(growth_actor.max_health, float(expected_level_three["health"])) or not is_equal_approx(growth_actor.max_stamina, float(expected_level_three["stamina"])):
		failures.append("连续升级后生命或耐力没有按实时体型确定性重算")
	if not is_equal_approx(float(growth_actor.data["attack"]), float(expected_level_three["attack"])) or not is_equal_approx(float(growth_actor.data["speed"]), float(expected_level_three["speed"])):
		failures.append("连续升级后攻击或速度没有按实时体型确定性重算")
	if not is_equal_approx(float(growth_actor.data["armor"]), float(expected_level_three["armor"])) or not is_equal_approx(float(growth_actor.data["regen"]), float(expected_level_three["regen"])):
		failures.append("连续升级后护甲或耐力恢复没有按实时体型确定性重算")
	if growth_actor.health <= growth_base_health * 0.20 or growth_actor.stamina <= growth_base_stamina * 0.05 or growth_actor.exhausted:
		failures.append("升级后没有正确恢复生命、耐力或解除力竭")
	if game_stub.actor_level_events.size() != 2 or game_stub.player_level_events.size() != 2 or game_stub.player_xp_events.size() != 1:
		failures.append("连续升级没有发送完整的角色、玩家或经验反馈事件")
	elif not game_stub.player_level_events.all(func(event: Dictionary) -> bool: return float(event["gains"].get("regen", 0.0)) > 0.0):
		failures.append("玩家升级反馈没有包含耐力恢复成长")
	growth_actor.gain_experience(100000, "elephant")
	if growth_actor.level != growth_actor.MAX_LEVEL or growth_actor.experience != 0 or growth_actor.experience_to_next_level() != 0:
		failures.append("超额经验没有正确限制在 Lv.10 并清理溢出")
	var capped_attack := float(growth_actor.data["attack"])
	growth_actor.gain_experience(999, "rabbit")
	if not is_equal_approx(float(growth_actor.data["attack"]), capped_attack):
		failures.append("满级后仍能通过经验继续增长属性")
	var fresh_growth_actor: EcoActor = ActorScript.new()
	fresh_growth_actor.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(fresh_growth_actor)
	fresh_growth_actor.setup(game_stub, 70, "wolf", false, Vector3(3.0, 0.0, 0.0), 0)
	if not is_equal_approx(float(fresh_growth_actor.data["attack"]), growth_base_attack) or not is_equal_approx(fresh_growth_actor.max_health, growth_base_health):
		failures.append("一名狼升级污染了后续生成的同物种基础数据")
	growth_actor.free()
	fresh_growth_actor.free()

	var proximity_wolf: EcoActor = ActorScript.new()
	proximity_wolf.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(proximity_wolf)
	proximity_wolf.setup(game_stub, 72, "wolf", false, Vector3.ZERO, 0)
	var proximity_player: EcoActor = ActorScript.new()
	proximity_player.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(proximity_player)
	proximity_player.setup(game_stub, 73, "rabbit", true, Vector3(5.8, 0.0, 0.0), 0)
	proximity_wolf.spawn_protection = 0.0
	proximity_player.spawn_protection = 0.0
	proximity_wolf.calm_timer = 30.0
	proximity_wolf.state_commit_timer = 0.0
	game_stub.player = proximity_player
	game_stub.actors = [proximity_wolf, proximity_player]
	proximity_wolf._think()
	if proximity_wolf.ai_state != "hunt" or proximity_wolf.ai_target != proximity_player or proximity_wolf.calm_timer > 0.0:
		failures.append("生态建立期内的附近合法玩家猎物没有公平进入 AI 主动捕猎链")
	proximity_wolf.ai_state = "wander"
	proximity_wolf.ai_target = null
	proximity_wolf.calm_timer = 30.0
	proximity_wolf.state_commit_timer = 0.0
	proximity_player.is_player = false
	proximity_wolf._think()
	if proximity_wolf.ai_state != "hunt" or proximity_wolf.ai_target != proximity_player:
		failures.append("同一近距离主动捕猎链没有同样覆盖普通 AI 动物")
	proximity_wolf.free()
	proximity_player.free()
	game_stub.player = null
	game_stub.actors.clear()

	var pack_leader: EcoActor = ActorScript.new()
	pack_leader.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(pack_leader)
	pack_leader.setup(game_stub, 63, "wolf", false, Vector3(5.0, 0.0, 0.0), 0)
	var pack_follower: EcoActor = ActorScript.new()
	pack_follower.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(pack_follower)
	pack_follower.setup(game_stub, 64, "wolf", false, Vector3.ZERO, 0)
	var distant_rabbit: EcoActor = ActorScript.new()
	distant_rabbit.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(distant_rabbit)
	distant_rabbit.setup(game_stub, 65, "rabbit", false, Vector3(31.0, 0.0, 0.0), 0)
	pack_leader.spawn_protection = 0.0
	pack_follower.spawn_protection = 0.0
	distant_rabbit.spawn_protection = 0.0
	pack_leader._switch_state("hunt", distant_rabbit)
	pack_follower.hunger = 70.0
	pack_follower.calm_timer = 0.0
	pack_follower.state_commit_timer = 0.0
	game_stub.actors = [pack_leader, pack_follower, distant_rabbit]
	pack_follower._think()
	if pack_follower.ai_state != "hunt" or pack_follower.ai_target != distant_rabbit:
		failures.append("狼群成员没有接收近处同伴共享的追猎目标")
	pack_leader.free()
	pack_follower.free()
	distant_rabbit.free()
	game_stub.actors.clear()

	var herd_scout: EcoActor = ActorScript.new()
	herd_scout.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(herd_scout)
	herd_scout.setup(game_stub, 66, "deer", false, Vector3(5.0, 0.0, 0.0), 0)
	var herd_follower: EcoActor = ActorScript.new()
	herd_follower.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(herd_follower)
	herd_follower.setup(game_stub, 67, "deer", false, Vector3.ZERO, 0)
	var distant_wolf: EcoActor = ActorScript.new()
	distant_wolf.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(distant_wolf)
	distant_wolf.setup(game_stub, 68, "wolf", false, Vector3(31.0, 0.0, 0.0), 0)
	herd_scout.spawn_protection = 0.0
	herd_follower.spawn_protection = 0.0
	distant_wolf.spawn_protection = 0.0
	herd_scout._switch_state("flee", distant_wolf)
	herd_scout.desired_direction = Vector3.LEFT
	herd_follower.calm_timer = 0.0
	herd_follower.state_commit_timer = 0.0
	game_stub.actors = [herd_scout, herd_follower, distant_wolf]
	herd_follower._think()
	if herd_follower.ai_state != "flee" or herd_follower.ai_target != distant_wolf or herd_follower.group_escape_direction.length() < 0.9:
		failures.append("鹿群成员没有接收同伴的危险警报与逃生方向")
	herd_scout.free()
	herd_follower.free()
	distant_wolf.free()
	game_stub.actors.clear()

	var foraging_actor: EcoActor = ActorScript.new()
	foraging_actor.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(foraging_actor)
	foraging_actor.setup(game_stub, 62, "rabbit", false, Vector3.ZERO, 0)
	foraging_actor.health = foraging_actor.max_health * 0.40
	foraging_actor.stamina = foraging_actor.max_stamina * 0.30
	var food_patch: FoodPatch = FoodPatchScript.new()
	food_patch.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(food_patch)
	var food_rng := RandomNumberGenerator.new()
	food_rng.seed = 62
	food_patch.setup("grass", food_rng)
	food_patch.position = Vector3(1.4, 0.0, 0.0)
	var fruit_patch: FoodPatch = FoodPatchScript.new()
	fruit_patch.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(fruit_patch)
	food_rng.seed = 63
	fruit_patch.setup("fruit", food_rng)
	fruit_patch.position = Vector3(0.5, 0.0, 0.0)
	var guidance_world: EcoWorld = WorldScript.new()
	guidance_world.process_mode = Node.PROCESS_MODE_DISABLED
	guidance_world.world_size = 100.0
	container.add_child(guidance_world)
	guidance_world.food_patches = [food_patch, fruit_patch]
	game_stub.world = guidance_world
	game_stub.actors = [foraging_actor]
	foraging_actor.hunger = 70.0
	var fruit_before := fruit_patch.amount
	if not foraging_actor.habit_resource_guidance_text().contains("嫩草"):
		failures.append("低血雪兔 HUD 没有指向可用嫩草")
	if not foraging_actor.try_consume_nearby() or foraging_actor.experience <= 0:
		failures.append("第一次觅食没有获得成长经验")
	if not is_equal_approx(fruit_patch.amount, fruit_before) or food_patch.amount >= food_patch.max_amount:
		failures.append("手动进食没有优先选择可触发本物种习性的资源")
	if foraging_actor.eat_timer <= 0.0 or foraging_actor.use_skill():
		failures.append("进食后没有进入禁止技能的咀嚼承诺")
	if foraging_actor.habit_activation_count != 1 or not foraging_actor.has_habit_buff("escape") or foraging_actor.health <= foraging_actor.max_health * 0.48:
		failures.append("雪兔进食嫩草没有实际触发回血和轻捷习性")
	var first_forage_experience := foraging_actor.experience
	foraging_actor.eat_timer = 0.0
	foraging_actor.try_consume_resource(food_patch)
	if foraging_actor.experience != first_forage_experience:
		failures.append("同一食物点可以被反复刷取经验")
	if foraging_actor.habit_activation_count != 1:
		failures.append("同一食物点可以反复刷取生态习性")
	var snake_actor: EcoActor = ActorScript.new()
	snake_actor.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(snake_actor)
	snake_actor.setup(game_stub, 71, "snake", false, Vector3(8.0, 0.0, 0.0), 0)
	var fish_patch: FoodPatch = FoodPatchScript.new()
	fish_patch.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(fish_patch)
	food_rng.seed = 64
	fish_patch.setup("fish", food_rng)
	fish_patch.position = Vector3(8.8, 0.0, 0.0)
	guidance_world.food_patches.append(fish_patch)
	var distant_corpse: EcoCorpse = CorpseScript.new()
	distant_corpse.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(distant_corpse)
	distant_corpse.setup("rabbit", 999)
	distant_corpse.position = Vector3(14.0, 0.0, 0.0)
	var grown_corpse: EcoCorpse = CorpseScript.new()
	grown_corpse.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(grown_corpse)
	grown_corpse.setup("rabbit", 1000, Catalog.maximum_effective_body_size("rabbit"))
	if grown_corpse.food_amount <= distant_corpse.food_amount or grown_corpse.lifetime <= distant_corpse.lifetime or not is_equal_approx(grown_corpse.effective_size, Catalog.maximum_effective_body_size("rabbit")):
		failures.append("尸体食物量、保留时间或习性体型没有继承死亡个体的实时体型")
	game_stub.corpses = [distant_corpse]
	game_stub.actors = [snake_actor]
	snake_actor.habit_rewarded_sources[str(fish_patch.get_instance_id())] = true
	snake_actor.health = snake_actor.max_health * 0.50
	snake_actor.hunger = 78.0
	var snake_health_before_fish := snake_actor.health
	var snake_hunger_before_fish := snake_actor.hunger
	var fish_before := fish_patch.amount
	if not snake_actor.try_consume_nearby() or fish_patch.amount >= fish_before:
		failures.append("远处尸体抢占了手动进食目标，脚边鱼群无法被吃到")
	if snake_actor.health <= snake_health_before_fish or snake_actor.hunger >= snake_hunger_before_fish or snake_actor.fish_catches != 1:
		failures.append("捕获活鱼没有同时恢复生命、饱腹并计入捕鱼次数")
	snake_actor.free()
	fish_patch.free()
	distant_corpse.free()
	grown_corpse.free()
	game_stub.corpses.clear()
	guidance_world.level_profile_data = {"water": 1.0, "water_depth": 1.0}
	guidance_world.weather_id = "clear"
	var rabbit_water_actor: EcoActor = ActorScript.new()
	rabbit_water_actor.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(rabbit_water_actor)
	rabbit_water_actor.setup(game_stub, 72, "rabbit", false, Vector3(-25.0, 0.0, 25.0), 0)
	rabbit_water_actor._update_water_survival(5.5)
	if rabbit_water_actor.breath_remaining > 0.0 or rabbit_water_actor.health >= rabbit_water_actor.max_health or rabbit_water_actor.drowning_seconds <= 0.0:
		failures.append("怕水雪兔在深水耗尽屏息后没有开始溺水")
	if not rabbit_water_actor.water_status_is_dangerous() or not rabbit_water_actor.water_status_text().contains("溺水"):
		failures.append("深水屏息耗尽后 HUD 状态没有进入溺水警告")
	rabbit_water_actor.position = Vector3(40.0, 0.0, 40.0)
	rabbit_water_actor._update_water_survival(1.0)
	if rabbit_water_actor.breath_remaining <= 0.0:
		failures.append("动物离开水域后没有恢复屏息")
	var otter_water_actor: EcoActor = ActorScript.new()
	otter_water_actor.process_mode = Node.PROCESS_MODE_DISABLED
	container.add_child(otter_water_actor)
	otter_water_actor.setup(game_stub, 73, "otter", false, Vector3(-25.0, 0.0, 25.0), 0)
	otter_water_actor._update_water_survival(5.5)
	if otter_water_actor.breath_remaining <= otter_water_actor.max_breath * 0.85 or otter_water_actor.health < otter_water_actor.max_health:
		failures.append("水獭在短时深水活动中被错误按弱水性动物结算")
	rabbit_water_actor.free()
	otter_water_actor.free()
	foraging_actor.free()
	food_patch.free()
	fruit_patch.free()
	game_stub.world = null
	guidance_world.free()
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
		if not Catalog.ECO_HABITS.has(species_id):
			failures.append("%s 缺少独立生态习性" % species_id)
		else:
			var habit := Catalog.habit_profile(species_id)
			var favored_foods := Catalog.habit_favored_foods(species_id)
			if str(habit.get("name", "")).length() < 2 or str(habit.get("summary", "")).length() < 24 or favored_foods.is_empty():
				failures.append("%s 生态习性名称、触发食物或说明不完整" % species_id)
			if str(habit.get("buff", "")) not in Catalog.HABIT_BUFF_NAMES:
				failures.append("%s 生态习性配置了未知状态" % species_id)
			for food_kind in favored_foods:
				if food_kind not in ["grass", "berries", "mushroom", "fruit", "roots", "fish", "corpse"]:
					failures.append("%s 生态习性配置了未知食物 %s" % [species_id, food_kind])
			var sample_effect := Catalog.habit_food_effect(species_id, favored_foods[0], regions[0], true, "night" if species_id == "owl" else "day", "clear", 0.50, 3)
			if sample_effect.is_empty() or float(sample_effect.get("health_ratio", 0.0)) <= 0.0 or float(sample_effect.get("stamina_ratio", 0.0)) <= 0.0:
				failures.append("%s 生态习性没有实际恢复效果" % species_id)
		var growth := Catalog.growth_profile(species_id)
		for growth_key in ["health", "attack", "speed", "stamina", "armor", "regen"]:
			if not growth.has(growth_key) or float(growth[growth_key]) <= 0.0:
				failures.append("%s 的成长配置 %s 无效" % [species_id, growth_key])
		var base_health := actor.max_health
		var base_attack := float(actor.data["attack"])
		var base_speed := float(actor.data["speed"])
		var base_stamina := actor.max_stamina
		var base_effective_size := actor.effective_size
		for _growth_level in range(2, actor.MAX_LEVEL + 1):
			actor._level_up()
		if actor.max_health <= base_health or float(actor.data["attack"]) <= base_attack or float(actor.data["speed"]) <= base_speed or actor.max_stamina <= base_stamina:
			failures.append("%s 升到满级后没有全面提升生命、攻击、速度与耐力" % species_id)
		var expected_max_stats := Catalog.growth_stats(species_id, actor.MAX_LEVEL)
		if not is_equal_approx(actor.effective_size, Catalog.maximum_effective_body_size(species_id)) or not is_equal_approx(actor.max_health, float(expected_max_stats["health"])) or not is_equal_approx(float(actor.data["attack"]), float(expected_max_stats["attack"])):
			failures.append("%s 的 Lv.10 体型或核心属性偏离确定性体型曲线" % species_id)
		if actor.effective_size <= base_effective_size or Catalog.visual_growth_scale(species_id, actor.MAX_LEVEL) <= 1.0 or float(actor.data["speed"]) > base_speed * 1.20:
			failures.append("%s 的体型展示没有成长或速度成长越过 20%% 上限" % species_id)
		if not Catalog.SPECIES_ADAPTATION_NAMES.has(species_id) or Catalog.adaptation_choices(species_id).size() != 3:
			failures.append("%s 缺少三条完整局内适应路线" % species_id)
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
	var live_opponent_reward := Catalog.combat_experience_reward("rabbit", "elephant", 1, rabbit_opportunity.effective_size, elephant_opportunity.effective_size, rabbit_opportunity.combat_power_rating(), elephant_opportunity.combat_power_rating())
	var expected_tactical_xp := maxi(roundi(float(live_opponent_reward) * Catalog.COUNTERPLAY_ROUTE_XP_RATIO), 1)
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
	if target_tactical_xp != maxi(roundi(float(live_opponent_reward) * Catalog.COUNTERPLAY_TARGET_XP_CAP_RATIO), 1):
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
	var teaching_bear_rosters := 0
	for sample_index in range(128):
		rng.seed = 8100 + sample_index
		var teaching_roster := Catalog.build_roster(rng, 10, Vector2i(4, 5), 1)
		if teaching_roster.has("bear"):
			teaching_bear_rosters += 1
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
	if teaching_bear_rosters < 38 or teaching_bear_rosters > 72:
		failures.append("第一关棕熊出现率失控：128 个世界中出现 %d 局" % teaching_bear_rosters)
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
	world_test.obstacles.append(Vector3.ZERO)
	world_test.obstacle_radii.append(0.75)
	world_test.obstacle_kinds.append("tree")
	var forward_route := Vector3(0.0, 0.0, -1.0)
	var left_steer := world_test.steer_around_obstacles(Vector3(0.0, 0.0, 2.2), forward_route, 0.55, 2, 1.0, 1.0)
	var right_steer := world_test.steer_around_obstacles(Vector3(0.0, 0.0, 2.2), forward_route, 0.55, 2, 1.0, -1.0)
	if left_steer.x <= 0.1 or right_steer.x >= -0.1:
		failures.append("AI 避障没有遵守已锁定的左右绕行方向")
	var cleared_route := world_test.steer_around_obstacles(Vector3(0.0, 0.0, -2.2), forward_route, 0.55, 2)
	if cleared_route.dot(forward_route) < 0.999:
		failures.append("AI 已越过障碍后仍被身后的障碍牵引，可能原地转圈")
	if not ActorScript.resolved_ai_ground_facing(Vector3.ZERO).is_zero_approx():
		failures.append("AI 没有实际位移时仍会跟随抖动的意图方向原地旋转")
	var actual_facing := ActorScript.resolved_ai_ground_facing(Vector3(0.08, 0.0, -0.03))
	if actual_facing.dot(Vector3(0.08, 0.0, -0.03).normalized()) < 0.999:
		failures.append("AI 移动朝向没有跟随实际位移")
	world_test.obstacles.clear()
	world_test.obstacle_radii.clear()
	world_test.obstacle_kinds.clear()
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
		print("SPECIES_VALIDATION_OK: %d species, distinct water profiles/breath/drowning/fishing, ecological habits and starvation deaths, full XP/level chain, hunger-aware hunting, route-failure memory, territorial restraint, pack/herd shared intelligence, contested food safety, counterplay mastery, ecological leverage, terrain/cover routing, growth/victory guides, progressive pools 1-10, %d new skills, flight/weather/canopy rules" % [Catalog.ORDER.size(), new_species.size()])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
