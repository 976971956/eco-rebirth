class_name SpeciesCatalog
extends RefCounted


const ORDER: Array[String] = [
	"rabbit", "fox", "deer", "wolf", "snake", "bear",
	"boar", "lynx", "bison", "crocodile", "tiger", "moose", "rhino", "hippo"
]

const UNLOCK_LEVEL := {
	"rabbit": 1, "fox": 1, "deer": 1, "wolf": 1, "snake": 1, "bear": 1,
	"boar": 2, "lynx": 3, "bison": 4, "crocodile": 5,
	"tiger": 6, "moose": 7, "rhino": 8, "hippo": 9,
}

const BIOME_PREFERENCES := {
	"rabbit": ["forest", "grassland"],
	"fox": ["forest", "highland"],
	"deer": ["forest", "grassland"],
	"wolf": ["forest", "highland"],
	"snake": ["wetland", "forest"],
	"bear": ["forest", "highland"],
	"boar": ["forest", "wetland"],
	"lynx": ["highland", "forest"],
	"bison": ["grassland"],
	"crocodile": ["wetland"],
	"tiger": ["forest"],
	"moose": ["highland", "wetland"],
	"rhino": ["grassland", "highland"],
	"hippo": ["wetland"],
}

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
	},
	"boar": {
		"name": "獠牙野猪",
		"subtitle": "不屈冲阵者",
		"color": "#594338",
		"accent": "#c9b18e",
		"size": 3,
		"diet": "omnivore",
		"health": 175.0,
		"xp_reward": 48,
		"stamina": 112.0,
		"speed": 5.9,
		"sprint": 1.55,
		"regen": 16.0,
		"attack": 25.0,
		"attack_range": 1.85,
		"attack_interval": 0.94,
		"attack_cost": 10.0,
		"armor": 14.0,
		"passive": "硬皮",
		"passive_hint": "生命低于一半时受到的击退效果降低",
		"skill": "獠牙突阵",
		"skill_hint": "向目标短距冲锋，造成伤害和强力击退",
		"skill_feedback": "冲锋撕开了包围，目标已被撞离原位",
		"skill_color": "#e0a467",
		"skill_cooldown": 7.5,
		"skill_cost": 22.0,
		"aggression": 0.48,
		"courage": 0.68,
		"hunger_rate": 0.18,
		"preferred_prey": ["rabbit", "snake"],
		"tip": "借冲锋撞散围攻者，再钻入树林切断追击路线。"
	},
	"lynx": {
		"name": "荒原猞猁",
		"subtitle": "潜伏突袭者",
		"color": "#b68a58",
		"accent": "#ead6ae",
		"size": 2,
		"diet": "carnivore",
		"health": 108.0,
		"xp_reward": 41,
		"stamina": 122.0,
		"speed": 7.05,
		"sprint": 1.62,
		"regen": 18.0,
		"attack": 20.0,
		"attack_range": 1.55,
		"attack_interval": 0.72,
		"attack_cost": 8.0,
		"armor": 5.0,
		"passive": "静猎",
		"passive_hint": "静止片刻后进入潜伏，更难被远处猎食者发现",
		"skill": "无声飞扑",
		"skill_hint": "从潜伏中扑向猎物，造成伤害并短暂减速",
		"skill_feedback": "飞扑命中，猎物的逃跑节奏已经被打断",
		"skill_color": "#f0cb79",
		"skill_cooldown": 6.5,
		"skill_cost": 19.0,
		"aggression": 0.60,
		"courage": 0.40,
		"hunger_rate": 0.16,
		"preferred_prey": ["rabbit", "fox", "snake"],
		"tip": "别参与正面混战。静止潜伏，等待受伤的小型动物脱离队伍。"
	},
	"bison": {
		"name": "草原野牛",
		"subtitle": "重型群居者",
		"color": "#4e392d",
		"accent": "#9c7651",
		"size": 4,
		"diet": "herbivore",
		"health": 335.0,
		"xp_reward": 82,
		"stamina": 118.0,
		"speed": 5.15,
		"sprint": 1.46,
		"regen": 14.0,
		"attack": 37.0,
		"attack_range": 2.10,
		"attack_interval": 1.12,
		"attack_cost": 14.0,
		"armor": 31.0,
		"passive": "结阵",
		"passive_hint": "附近有同类时更加勇敢，不容易被小型动物惊吓",
		"skill": "踏阵冲锋",
		"skill_hint": "向前猛冲并撞飞目标，惊退沿途小型动物",
		"skill_feedback": "沉重脚步震动草原，小型动物开始四散",
		"skill_color": "#d5b06f",
		"skill_cooldown": 9.0,
		"skill_cost": 27.0,
		"aggression": 0.18,
		"courage": 0.82,
		"hunger_rate": 0.19,
		"preferred_prey": [],
		"tip": "利用体型守住食物区，冲锋只用来脱围或惩罚靠得太近的猎手。"
	},
	"crocodile": {
		"name": "沼泽鳄",
		"subtitle": "水岸伏击者",
		"color": "#465d38",
		"accent": "#b4aa71",
		"size": 4,
		"diet": "carnivore",
		"health": 285.0,
		"xp_reward": 88,
		"stamina": 94.0,
		"speed": 4.75,
		"sprint": 1.42,
		"regen": 13.0,
		"attack": 45.0,
		"attack_range": 2.25,
		"attack_interval": 1.18,
		"attack_cost": 15.0,
		"armor": 35.0,
		"passive": "伏岸",
		"passive_hint": "静止时降低被发现距离，适合守在浅水与鱼群附近",
		"skill": "死亡翻滚",
		"skill_hint": "咬住近距离目标造成重伤，并大幅降低其移动速度",
		"skill_feedback": "翻滚撕裂目标，它暂时难以逃离水岸",
		"skill_color": "#9dbb64",
		"skill_cooldown": 10.0,
		"skill_cost": 26.0,
		"aggression": 0.66,
		"courage": 0.80,
		"hunger_rate": 0.15,
		"preferred_prey": ["rabbit", "fox", "deer", "wolf", "snake", "boar", "lynx"],
		"tip": "守住鱼群和尸体，不要在开阔地浪费耐力追逐高速猎物。"
	},
	"tiger": {
		"name": "山林猛虎",
		"subtitle": "顶级独行猎手",
		"color": "#d8792e",
		"accent": "#f0d7ad",
		"size": 4,
		"diet": "carnivore",
		"health": 245.0,
		"xp_reward": 96,
		"stamina": 120.0,
		"speed": 6.45,
		"sprint": 1.58,
		"regen": 15.0,
		"attack": 43.0,
		"attack_range": 2.05,
		"attack_interval": 0.90,
		"attack_cost": 13.0,
		"armor": 19.0,
		"passive": "独猎",
		"passive_hint": "附近没有同类时，更愿意持续追击受伤猎物",
		"skill": "裂风扑杀",
		"skill_hint": "远距离扑向猎物并造成高额伤害，惊吓附近小型动物",
		"skill_feedback": "扑杀落地，周围的弱小动物已被震慑",
		"skill_color": "#ffad52",
		"skill_cooldown": 8.5,
		"skill_cost": 28.0,
		"aggression": 0.78,
		"courage": 0.76,
		"hunger_rate": 0.20,
		"preferred_prey": ["rabbit", "fox", "deer", "wolf", "snake", "boar", "lynx", "moose"],
		"tip": "从战团侧面寻找残血目标，扑杀命中后不要恋战大型群居动物。"
	},
	"moose": {
		"name": "巨角驼鹿",
		"subtitle": "高地守卫者",
		"color": "#70503a",
		"accent": "#c49b69",
		"size": 4,
		"diet": "herbivore",
		"health": 300.0,
		"xp_reward": 84,
		"stamina": 132.0,
		"speed": 5.75,
		"sprint": 1.52,
		"regen": 16.0,
		"attack": 39.0,
		"attack_range": 2.35,
		"attack_interval": 1.08,
		"attack_cost": 13.0,
		"armor": 24.0,
		"passive": "巨角警戒",
		"passive_hint": "面对小于自己的攻击者时更倾向反击而非逃跑",
		"skill": "巨角横扫",
		"skill_hint": "横扫身前与两侧敌人，造成伤害并击退",
		"skill_feedback": "巨角清空了近身区域，包围出现缺口",
		"skill_color": "#e5c486",
		"skill_cooldown": 8.0,
		"skill_cost": 24.0,
		"aggression": 0.22,
		"courage": 0.78,
		"hunger_rate": 0.17,
		"preferred_prey": [],
		"tip": "背靠树木或岩石作战，用横扫一次处理多个贴身猎手。"
	},
	"rhino": {
		"name": "披甲犀牛",
		"subtitle": "不可阻挡的巨兽",
		"color": "#7b817d",
		"accent": "#d5c9ae",
		"size": 5,
		"diet": "herbivore",
		"health": 470.0,
		"xp_reward": 122,
		"stamina": 108.0,
		"speed": 4.95,
		"sprint": 1.50,
		"regen": 12.0,
		"attack": 56.0,
		"attack_range": 2.45,
		"attack_interval": 1.30,
		"attack_cost": 18.0,
		"armor": 56.0,
		"passive": "厚甲",
		"passive_hint": "高护甲抵御正面围攻，但长距离追击消耗很大",
		"skill": "破阵角冲",
		"skill_hint": "蓄势冲撞远处目标，造成重伤与极强击退",
		"skill_feedback": "角冲贯穿战团，沿途生物已被撞散",
		"skill_color": "#d9d3bd",
		"skill_cooldown": 11.0,
		"skill_cost": 32.0,
		"aggression": 0.28,
		"courage": 0.94,
		"hunger_rate": 0.22,
		"preferred_prey": [],
		"tip": "提前规划冲锋方向，撞开顶级猎食者后立刻去找食物恢复。"
	},
	"hippo": {
		"name": "领地河马",
		"subtitle": "湿地霸主",
		"color": "#776d72",
		"accent": "#c68d91",
		"size": 5,
		"diet": "herbivore",
		"health": 525.0,
		"xp_reward": 135,
		"stamina": 102.0,
		"speed": 4.65,
		"sprint": 1.42,
		"regen": 12.0,
		"attack": 63.0,
		"attack_range": 2.40,
		"attack_interval": 1.34,
		"attack_cost": 19.0,
		"armor": 49.0,
		"passive": "领地暴怒",
		"passive_hint": "受到攻击后会坚决反击，极少被小型动物吓退",
		"skill": "裂颚震慑",
		"skill_hint": "猛咬近敌并震退周围所有较小动物",
		"skill_feedback": "巨颚合拢，湿地周围的生物开始逃离",
		"skill_color": "#e2a3a8",
		"skill_cooldown": 10.5,
		"skill_cost": 30.0,
		"aggression": 0.70,
		"courage": 0.98,
		"hunger_rate": 0.24,
		"preferred_prey": [],
		"tip": "别追逐高速目标。控制湿地食物区，让敌人不得不靠近你的领地。"
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


static func available_species(campaign_level: int) -> Array[String]:
	var pool: Array[String] = []
	for species_id in ORDER:
		if int(UNLOCK_LEVEL.get(species_id, 1)) <= campaign_level:
			pool.append(species_id)
	return pool


static func unlock_level(species_id: String) -> int:
	return int(UNLOCK_LEVEL.get(species_id, 1))


static func preferred_regions(species_id: String) -> Array[String]:
	var regions: Array[String] = []
	for region_id in BIOME_PREFERENCES.get(species_id, ["forest", "grassland", "wetland", "highland"]):
		regions.append(str(region_id))
	return regions


static func build_roster(rng: RandomNumberGenerator, count: int = 10, species_type_range: Vector2i = Vector2i(6, 6), campaign_level: int = 1) -> Array[String]:
	var pool := available_species(campaign_level)
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
	if campaign_level > 1:
		for species_id in pool:
			if unlock_level(species_id) != campaign_level or selected.has(species_id):
				continue
			var replace_index := selected.size() - 1
			while replace_index > 0 and selected[replace_index] == "rabbit":
				replace_index -= 1
			selected[replace_index] = species_id

	var roster: Array[String] = selected.duplicate()
	while roster.size() < count:
		var weighted: Array[String] = []
		for species_id in selected:
			var weight := 2
			if species_id == "rabbit":
				weight = 3
			elif species_id in ["bear", "bison", "crocodile", "tiger", "moose"]:
				weight = 1
			elif species_id in ["rhino", "hippo"]:
				weight = 1 if campaign_level >= 10 else 0
			for i in range(weight):
				weighted.append(species_id)
		if weighted.is_empty():
			weighted = selected.duplicate()
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
