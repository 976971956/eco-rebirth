extends SceneTree

const Catalog = preload("res://scripts/species_catalog.gd")
const ActorScript = preload("res://scripts/eco_actor.gd")

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

	var rng := RandomNumberGenerator.new()
	var minimum_types_by_level := [4, 5, 6, 7, 8, 9, 10, 11, 12, 14]
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

	var new_species: Array[String] = ["boar", "lynx", "bison", "crocodile", "tiger", "moose", "rhino", "hippo"]
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
		game_stub.actors = [attacker, target]
		if not attacker.use_skill(target):
			failures.append("%s 的主动技能未能命中近距离测试目标" % new_species[index])
		elif attacker.skill_timer <= 0.0:
			failures.append("%s 的主动技能没有进入冷却" % new_species[index])
		attacker.free()
		target.free()
	game_stub.actors.clear()

	if failures.is_empty():
		print("SPECIES_VALIDATION_OK: %d species, progressive pools 1-10, %d new skills" % [Catalog.ORDER.size(), new_species.size()])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
