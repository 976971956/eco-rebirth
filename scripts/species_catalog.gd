class_name SpeciesCatalog
extends RefCounted


const ORDER: Array[String] = ["rabbit", "fox", "deer", "wolf", "snake", "bear"]

const DATA: Dictionary = {
	"rabbit": {
		"name": "雪兔",
		"subtitle": "敏捷草食者",
		"color": "#e7ebe7",
		"accent": "#f3a7a8",
		"size": 1,
		"diet": "herbivore",
		"health": 55.0,
		"xp_reward": 18,
		"stamina": 125.0,
		"speed": 7.6,
		"sprint": 1.72,
		"regen": 20.0,
		"attack": 7.0,
		"attack_range": 1.35,
		"attack_interval": 0.68,
		"attack_cost": 5.0,
		"armor": 0.0,
		"passive": "警觉",
		"passive_hint": "被天敌盯上时更早察觉，逃跑触发距离更远",
		"skill": "月影折跃",
		"skill_hint": "高速转向并短暂隐匿，甩开正在追击你的天敌",
		"skill_feedback": "月影扰乱了追猎者的判断，趁现在改变路线",
		"skill_color": "#b9f4e8",
		"skill_cooldown": 7.0,
		"skill_cost": 18.0,
		"aggression": 0.04,
		"courage": 0.10,
		"hunger_rate": 0.18,
		"preferred_prey": [],
		"tip": "不要正面战斗。利用灌木、耐力和混战活到最后。"
	},
	"fox": {
		"name": "赤狐",
		"subtitle": "机会主义猎手",
		"color": "#d9632f",
		"accent": "#f2e0c2",
		"size": 2,
		"diet": "omnivore",
		"health": 90.0,
		"xp_reward": 32,
		"stamina": 110.0,
		"speed": 6.8,
		"sprint": 1.58,
		"regen": 17.0,
		"attack": 15.0,
		"attack_range": 1.55,
		"attack_interval": 0.78,
		"attack_cost": 8.0,
		"armor": 4.0,
		"passive": "机会嗅觉",
		"passive_hint": "更远发现尸体，对残血目标伤害+12%",
		"skill": "血味佯攻",
		"skill_hint": "突袭并留下血味，让附近捕食者更容易盯上目标",
		"skill_feedback": "血味正在扩散，附近捕食者会争夺这个目标",
		"skill_color": "#ff8a4d",
		"skill_cooldown": 6.0,
		"skill_cost": 16.0,
		"aggression": 0.48,
		"courage": 0.35,
		"hunger_rate": 0.16,
		"preferred_prey": ["rabbit", "snake"],
		"tip": "追踪残血目标和尸体，等待强者互斗后再补刀。"
	},
	"deer": {
		"name": "林鹿",
		"subtitle": "耐力型草食者",
		"color": "#aa6c3e",
		"accent": "#ead5ad",
		"size": 3,
		"diet": "herbivore",
		"health": 155.0,
		"xp_reward": 38,
		"stamina": 140.0,
		"speed": 6.45,
		"sprint": 1.63,
		"regen": 18.0,
		"attack": 17.0,
		"attack_range": 1.8,
		"attack_interval": 1.02,
		"attack_cost": 9.0,
		"armor": 5.0,
		"passive": "顺势奔跑",
		"passive_hint": "直线冲刺超过2秒后耗耐降低",
		"skill": "惊群蹬踏",
		"skill_hint": "震开近敌，并惊动周围较小动物制造混乱",
		"skill_feedback": "兽群受到惊吓，追击队形已经被打乱",
		"skill_color": "#f3d17a",
		"skill_cooldown": 7.5,
		"skill_cost": 20.0,
		"aggression": 0.12,
		"courage": 0.30,
		"hunger_rate": 0.14,
		"preferred_prey": [],
		"tip": "保持直线冲刺，把追猎者带进熊或狼群的领地。"
	},
	"wolf": {
		"name": "灰狼",
		"subtitle": "群体追猎者",
		"color": "#68727a",
		"accent": "#c7ced0",
		"size": 3,
		"diet": "carnivore",
		"health": 145.0,
		"xp_reward": 46,
		"stamina": 115.0,
		"speed": 6.3,
		"sprint": 1.53,
		"regen": 16.0,
		"attack": 23.0,
		"attack_range": 1.75,
		"attack_interval": 0.88,
		"attack_cost": 10.0,
		"armor": 8.0,
		"passive": "群猎",
		"passive_hint": "附近同类越多，攻击消耗的耐力越低",
		"skill": "群猎扑杀",
		"skill_hint": "扑咬目标，并号召附近同类共同围攻",
		"skill_feedback": "嚎叫传向狼群，同类正在向目标合围",
		"skill_color": "#a9d8ed",
		"skill_cooldown": 8.0,
		"skill_cost": 24.0,
		"aggression": 0.68,
		"courage": 0.62,
		"hunger_rate": 0.17,
		"preferred_prey": ["rabbit", "deer", "fox", "snake"],
		"tip": "不要耗尽追击耐力；让同类先施压，再从侧面扑咬。"
	},
	"snake": {
		"name": "青环蛇",
		"subtitle": "毒素伏击者",
		"color": "#5c9651",
		"accent": "#d6d254",
		"size": 2,
		"diet": "carnivore",
		"health": 75.0,
		"xp_reward": 27,
		"stamina": 95.0,
		"speed": 5.2,
		"sprint": 1.43,
		"regen": 16.0,
		"attack": 10.0,
		"attack_range": 1.35,
		"attack_interval": 0.90,
		"attack_cost": 7.0,
		"armor": 2.0,
		"passive": "冷伏",
		"passive_hint": "静止一段时间后更难被天敌发现",
		"skill": "翠毒伏击",
		"skill_hint": "毒牙造成持续伤害和减速，暴露目标的虚弱气味",
		"skill_feedback": "毒素正在削弱目标，它会成为更显眼的猎物",
		"skill_color": "#8ee86d",
		"skill_cooldown": 9.0,
		"skill_cost": 18.0,
		"aggression": 0.52,
		"courage": 0.38,
		"hunger_rate": 0.13,
		"preferred_prey": ["rabbit", "fox"],
		"tip": "静止伏击，命中毒牙后立刻脱离，让毒素和第三方完成击杀。"
	},
	"bear": {
		"name": "棕熊",
		"subtitle": "重装反击者",
		"color": "#65432f",
		"accent": "#b4845f",
		"size": 4,
		"diet": "omnivore",
		"health": 300.0,
		"xp_reward": 75,
		"stamina": 105.0,
		"speed": 4.6,
		"sprint": 1.38,
		"regen": 13.0,
		"attack": 42.0,
		"attack_range": 2.15,
		"attack_interval": 1.22,
		"attack_cost": 16.0,
		"armor": 28.0,
		"passive": "怒意",
		"passive_hint": "受伤后短暂提高伤害，有冷却",
		"skill": "领地震荡",
		"skill_hint": "拍地形成扩散冲击，击退并震慑周围生物",
		"skill_feedback": "领地震荡扩散，弱小动物会优先逃离这里",
		"skill_color": "#e8ad62",
		"skill_cooldown": 10.0,
		"skill_cost": 28.0,
		"aggression": 0.55,
		"courage": 0.82,
		"hunger_rate": 0.20,
		"preferred_prey": ["rabbit", "fox", "deer", "wolf", "snake"],
		"tip": "守住尸体热点，别浪费耐力长途追赶小型生物。"
	}
}


static func get_data(species_id: String) -> Dictionary:
	return DATA.get(species_id, DATA["rabbit"]).duplicate(true)


static func display_name(species_id: String) -> String:
	return str(DATA.get(species_id, DATA["rabbit"])["name"])


static func get_color(species_id: String) -> Color:
	return Color.from_string(str(DATA.get(species_id, DATA["rabbit"])["color"]), Color.WHITE)


static func experience_reward(species_id: String, victim_level: int = 1) -> int:
	var base_reward := int(DATA.get(species_id, DATA["rabbit"]).get("xp_reward", 20))
	return maxi(int(round(base_reward * (1.0 + maxi(victim_level - 1, 0) * 0.14))), 1)


static func build_roster(rng: RandomNumberGenerator, count: int = 10, species_type_range: Vector2i = Vector2i(6, 6)) -> Array[String]:
	var pool := ORDER.duplicate()
	for index in range(pool.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value: String = pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = value

	var min_types := clampi(species_type_range.x, 1, pool.size())
	var max_types := clampi(species_type_range.y, min_types, pool.size())
	var type_count := rng.randi_range(min_types, max_types)
	var selected: Array[String] = pool.slice(0, type_count)
	if not selected.has("rabbit"):
		selected[selected.size() - 1] = "rabbit"

	var roster: Array[String] = selected.duplicate()
	while roster.size() < count:
		var weighted: Array[String] = []
		for species_id in selected:
			var weight := 2
			if species_id == "rabbit":
				weight = 3
			elif species_id == "bear":
				weight = 1
			for i in range(weight):
				weighted.append(species_id)
		roster.append(weighted[rng.randi_range(0, weighted.size() - 1)])

	for index in range(roster.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value: String = roster[index]
		roster[index] = roster[swap_index]
		roster[swap_index] = value
	return roster


static func can_eat_food(species_id: String) -> bool:
	var diet := str(DATA[species_id]["diet"])
	return diet == "herbivore" or diet == "omnivore"


static func can_eat_corpse(species_id: String) -> bool:
	var diet := str(DATA[species_id]["diet"])
	return diet == "carnivore" or diet == "omnivore"


static func considers_prey(hunter_id: String, target_id: String) -> bool:
	if hunter_id == target_id:
		return false
	var data: Dictionary = DATA[hunter_id]
	if str(data["diet"]) == "herbivore":
		return false
	if target_id in data["preferred_prey"]:
		return true
	var hunter_size := int(data["size"])
	var target_size := int(DATA[target_id]["size"])
	return str(data["diet"]) == "carnivore" and target_size <= hunter_size - 2
