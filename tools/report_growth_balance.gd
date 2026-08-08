extends SceneTree

const Catalog = preload("res://scripts/species_catalog.gd")
const MAX_LEVEL := 8


func _init() -> void:
	print("| 物种 | 成长流派 | Lv.1 生命 | Lv.8 生命 | Lv.1 攻击 | Lv.8 攻击 | Lv.1 速度 | Lv.8 速度 | Lv.1 耐力 | Lv.8 耐力 | Lv.1/Lv.8 护甲 | 击杀经验 |")
	print("|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
	for species_id in Catalog.ORDER:
		var data := Catalog.get_data(species_id)
		var growth := Catalog.growth_profile(species_id)
		var steps := MAX_LEVEL - 1
		var health_l8 := float(data["health"]) * pow(1.0 + float(growth["health"]), steps)
		var attack_l8 := float(data["attack"]) * pow(1.0 + float(growth["attack"]), steps)
		var speed_l8 := float(data["speed"]) * pow(1.0 + float(growth["speed"]), steps)
		var stamina_l8 := float(data["stamina"]) * pow(1.0 + float(growth["stamina"]), steps)
		var armor_l8 := float(data["armor"]) + float(growth["armor"]) * steps
		print("| %s | %s | %d | %d | %.1f | %.1f | %.2f | %.2f | %d | %d | %.1f / %.1f | %d |" % [
			str(data["name"]), str(growth["name"]), int(data["health"]), roundi(health_l8),
			float(data["attack"]), attack_l8, float(data["speed"]), speed_l8,
			int(data["stamina"]), roundi(stamina_l8), float(data["armor"]), armor_l8, int(data["xp_reward"]),
		])
	quit(0)
