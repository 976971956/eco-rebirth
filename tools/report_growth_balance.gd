extends SceneTree

const Catalog = preload("res://scripts/species_catalog.gd")
const MAX_LEVEL := Catalog.MAX_GROWTH_LEVEL


func _init() -> void:
	print("| 物种 | 成长流派 | 实时体型 Lv.1→10 | 视觉倍率 | Lv.1→10 生命 | Lv.1→10 攻击 | Lv.1→10 速度 | Lv.1→10 耐力 | Lv.1→10 护甲 | Lv.1 击杀经验 |")
	print("|---|---|---:|---:|---:|---:|---:|---:|---:|---:|")
	for species_id in Catalog.ORDER:
		var data := Catalog.get_data(species_id)
		var growth := Catalog.growth_profile(species_id)
		var level_one := Catalog.growth_stats(species_id, 1, MAX_LEVEL)
		var level_ten := Catalog.growth_stats(species_id, MAX_LEVEL, MAX_LEVEL)
		print("| %s | %s | %.1f→%.1f | %.2f× | %d→%d | %.1f→%.1f | %.2f→%.2f | %d→%d | %.1f→%.1f | %d |" % [
			str(data["name"]), str(growth["name"]), float(level_one["effective_size"]), float(level_ten["effective_size"]), float(level_ten["visual_scale"]),
			roundi(float(level_one["health"])), roundi(float(level_ten["health"])), float(level_one["attack"]), float(level_ten["attack"]),
			float(level_one["speed"]), float(level_ten["speed"]), roundi(float(level_one["stamina"])), roundi(float(level_ten["stamina"])),
			float(level_one["armor"]), float(level_ten["armor"]), int(data["xp_reward"]),
		])
	quit(0)
