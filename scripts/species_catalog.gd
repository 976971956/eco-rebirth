class_name SpeciesCatalog
extends RefCounted

const OPPORTUNITY_BASE_HEALTH_RATIO := 0.02
const OPPORTUNITY_RATIO_PER_GAP := 0.01
const OPPORTUNITY_MAX_GAP := 4
const COUNTERPLAY_ROUTE_XP_RATIO := 0.10
const COUNTERPLAY_TARGET_XP_CAP_RATIO := 0.32
const FIRST_LEVEL_BEAR_CHANCE := 0.42

const BIOME_DISPLAY_NAMES := {
	"forest": "古木林地",
	"grassland": "日照草原",
	"wetland": "浅水湿地",
	"highland": "岩丘高地",
}


const ORDER: Array[String] = [
	"rabbit", "fox", "deer", "wolf", "snake", "bear",
	"boar", "raccoon", "porcupine", "crocodile", "capybara", "otter", "lynx", "goat", "wolverine",
	"bison", "zebra", "elephant", "tiger", "monkey", "owl", "moose", "turtle", "cheetah",
	"rhino", "gorilla", "eagle", "hippo", "hyena", "lion"
]

const UNLOCK_LEVEL := {
	"rabbit": 1, "fox": 1, "deer": 1, "wolf": 1, "snake": 1, "bear": 1,
	"boar": 2, "raccoon": 2, "porcupine": 2, "crocodile": 3, "capybara": 3, "otter": 3,
	"lynx": 4, "goat": 4, "wolverine": 4, "bison": 5, "zebra": 5, "elephant": 5,
	"tiger": 6, "monkey": 6, "owl": 6, "moose": 7, "turtle": 7, "cheetah": 7,
	"rhino": 8, "gorilla": 8, "eagle": 8,
	"hippo": 9, "hyena": 9, "lion": 9,
}

const BIOME_PREFERENCES := {
	"rabbit": ["forest", "grassland"],
	"fox": ["forest", "highland"],
	"deer": ["forest", "grassland"],
	"wolf": ["forest", "highland"],
	"snake": ["wetland", "forest"],
	"bear": ["forest", "highland"],
	"boar": ["forest", "wetland"],
	"raccoon": ["forest", "wetland"],
	"porcupine": ["forest", "highland"],
	"lynx": ["highland", "forest"],
	"capybara": ["wetland", "grassland"],
	"otter": ["wetland"],
	"goat": ["highland"],
	"wolverine": ["highland", "forest"],
	"bison": ["grassland"],
	"zebra": ["grassland"],
	"elephant": ["grassland", "wetland"],
	"crocodile": ["wetland"],
	"tiger": ["forest"],
	"monkey": ["forest"],
	"owl": ["forest", "highland"],
	"moose": ["highland", "wetland"],
	"turtle": ["wetland", "highland"],
	"cheetah": ["grassland"],
	"rhino": ["grassland", "highland"],
	"gorilla": ["forest"],
	"eagle": ["highland", "grassland"],
	"hippo": ["wetland"],
	"hyena": ["grassland", "highland"],
	"lion": ["grassland"],
}

const TRAITS := {
	"rabbit": ["alert", "escape"],
	"fox": ["scavenger", "finisher", "flanker"],
	"deer": ["herd_mover", "straight_runner", "retaliator"],
	"wolf": ["pack_hunter", "flanker"],
	"snake": ["ambusher"],
	"bear": ["territorial", "retaliator"],
	"boar": ["scavenger", "retaliator", "charger"],
	"raccoon": ["scavenger", "resource_thief", "escape"],
	"porcupine": ["retaliator", "quilled", "escape"],
	"lynx": ["ambusher", "finisher", "flanker"],
	"capybara": ["herd_mover", "calmer", "escape", "wetland_swimmer"],
	"otter": ["wetland_swimmer", "scavenger", "flanker", "escape"],
	"goat": ["herd_mover", "straight_runner", "climber", "retaliator"],
	"wolverine": ["scavenger", "finisher", "brave_vs_large"],
	"bison": ["herd_mover", "straight_runner", "retaliator", "charger"],
	"zebra": ["herd_mover", "straight_runner", "escape"],
	"elephant": ["herd_mover", "straight_runner", "retaliator", "giant", "obstacle_breaker"],
	"crocodile": ["ambusher", "scavenger", "territorial", "wetland_swimmer"],
	"tiger": ["ambusher", "finisher", "flanker"],
	"monkey": ["climber", "canopy_mover", "resource_thrower", "scavenger", "flanker"],
	"owl": ["flying", "ambusher", "finisher", "night_hunter"],
	"moose": ["herd_mover", "retaliator"],
	"turtle": ["armored", "defensive_stance", "retaliator", "escape"],
	"cheetah": ["straight_runner", "finisher", "flanker", "weather_runner"],
	"rhino": ["straight_runner", "retaliator", "charger"],
	"gorilla": ["territorial", "retaliator", "leader"],
	"eagle": ["flying", "ambusher", "finisher", "day_hunter"],
	"hippo": ["territorial", "retaliator", "wetland_swimmer"],
	"hyena": ["pack_hunter", "scavenger", "finisher", "flanker"],
	"lion": ["pack_hunter", "finisher", "flanker", "leader"],
}

# Water adaptation is explicit for every playable species.  `wade_depth` is
# safe standing water, `comfort_depth` is the deepest route AI will normally
# choose, and `breath` is gameplay-scaled submersion endurance in seconds.
# Flying animals still use these values when forced to land; normal flight is
# above the water surface and does not consume breath.
const WATER_PROFILES := {
	"rabbit": {"name": "怕水", "grade": 0, "wade_depth": 0.14, "comfort_depth": 0.18, "breath": 6.0, "swim_speed": 0.44, "fish_catch": 0.0},
	"fox": {"name": "短距泅渡", "grade": 1, "wade_depth": 0.18, "comfort_depth": 0.30, "breath": 14.0, "swim_speed": 0.68, "fish_catch": 0.38},
	"deer": {"name": "长程泅渡", "grade": 2, "wade_depth": 0.34, "comfort_depth": 0.62, "breath": 38.0, "swim_speed": 0.92, "fish_catch": 0.0},
	"wolf": {"name": "稳定泅渡", "grade": 2, "wade_depth": 0.24, "comfort_depth": 0.58, "breath": 34.0, "swim_speed": 0.96, "fish_catch": 0.58},
	"snake": {"name": "水面蜿行", "grade": 3, "wade_depth": 0.08, "comfort_depth": 0.82, "breath": 52.0, "swim_speed": 1.12, "fish_catch": 0.92},
	"bear": {"name": "强力游泳", "grade": 3, "wade_depth": 0.42, "comfort_depth": 0.78, "breath": 56.0, "swim_speed": 1.05, "fish_catch": 0.78},
	"boar": {"name": "耐力泅渡", "grade": 2, "wade_depth": 0.32, "comfort_depth": 0.52, "breath": 32.0, "swim_speed": 0.86, "fish_catch": 0.30},
	"raccoon": {"name": "浅水捕食", "grade": 2, "wade_depth": 0.20, "comfort_depth": 0.48, "breath": 28.0, "swim_speed": 0.90, "fish_catch": 0.66},
	"porcupine": {"name": "谨慎涉水", "grade": 1, "wade_depth": 0.22, "comfort_depth": 0.26, "breath": 12.0, "swim_speed": 0.60, "fish_catch": 0.0},
	"crocodile": {"name": "水域统治", "grade": 4, "wade_depth": 0.10, "comfort_depth": 1.35, "breath": 105.0, "swim_speed": 1.30, "fish_catch": 1.30},
	"capybara": {"name": "半水栖", "grade": 4, "wade_depth": 0.24, "comfort_depth": 1.15, "breath": 82.0, "swim_speed": 1.24, "fish_catch": 0.0},
	"otter": {"name": "潜水猎手", "grade": 4, "wade_depth": 0.12, "comfort_depth": 1.35, "breath": 96.0, "swim_speed": 1.45, "fish_catch": 1.48},
	"lynx": {"name": "短距泅渡", "grade": 1, "wade_depth": 0.20, "comfort_depth": 0.34, "breath": 16.0, "swim_speed": 0.72, "fish_catch": 0.44},
	"goat": {"name": "怕深水", "grade": 0, "wade_depth": 0.18, "comfort_depth": 0.20, "breath": 7.0, "swim_speed": 0.48, "fish_catch": 0.0},
	"wolverine": {"name": "寒水泅渡", "grade": 2, "wade_depth": 0.24, "comfort_depth": 0.56, "breath": 36.0, "swim_speed": 0.92, "fish_catch": 0.56},
	"bison": {"name": "重体渡水", "grade": 2, "wade_depth": 0.48, "comfort_depth": 0.62, "breath": 30.0, "swim_speed": 0.80, "fish_catch": 0.0},
	"zebra": {"name": "迁徙泅渡", "grade": 1, "wade_depth": 0.34, "comfort_depth": 0.44, "breath": 20.0, "swim_speed": 0.74, "fish_catch": 0.0},
	"elephant": {"name": "长鼻渡水", "grade": 3, "wade_depth": 0.72, "comfort_depth": 1.08, "breath": 74.0, "swim_speed": 1.02, "fish_catch": 0.0},
	"tiger": {"name": "强力游泳", "grade": 3, "wade_depth": 0.26, "comfort_depth": 0.88, "breath": 58.0, "swim_speed": 1.15, "fish_catch": 0.82},
	"monkey": {"name": "谨慎泅渡", "grade": 1, "wade_depth": 0.18, "comfort_depth": 0.32, "breath": 16.0, "swim_speed": 0.70, "fish_catch": 0.30},
	"owl": {"name": "贴水掠食", "grade": 1, "wade_depth": 0.08, "comfort_depth": 0.22, "breath": 9.0, "swim_speed": 0.52, "fish_catch": 0.72},
	"moose": {"name": "深水迁徙", "grade": 3, "wade_depth": 0.58, "comfort_depth": 0.90, "breath": 54.0, "swim_speed": 1.04, "fish_catch": 0.0},
	"turtle": {"name": "持久浮游", "grade": 3, "wade_depth": 0.16, "comfort_depth": 1.02, "breath": 90.0, "swim_speed": 0.86, "fish_catch": 0.0},
	"cheetah": {"name": "畏水", "grade": 0, "wade_depth": 0.16, "comfort_depth": 0.19, "breath": 7.0, "swim_speed": 0.46, "fish_catch": 0.24},
	"rhino": {"name": "重体涉水", "grade": 2, "wade_depth": 0.66, "comfort_depth": 0.76, "breath": 40.0, "swim_speed": 0.82, "fish_catch": 0.0},
	"gorilla": {"name": "短距泅渡", "grade": 1, "wade_depth": 0.36, "comfort_depth": 0.42, "breath": 14.0, "swim_speed": 0.64, "fish_catch": 0.0},
	"eagle": {"name": "水面擒鱼", "grade": 1, "wade_depth": 0.08, "comfort_depth": 0.24, "breath": 8.0, "swim_speed": 0.50, "fish_catch": 1.12},
	"hippo": {"name": "水陆霸主", "grade": 4, "wade_depth": 0.76, "comfort_depth": 1.35, "breath": 100.0, "swim_speed": 1.32, "fish_catch": 0.0},
	"hyena": {"name": "谨慎渡水", "grade": 1, "wade_depth": 0.24, "comfort_depth": 0.38, "breath": 18.0, "swim_speed": 0.76, "fish_catch": 0.34},
	"lion": {"name": "耐力泅渡", "grade": 2, "wade_depth": 0.30, "comfort_depth": 0.52, "breath": 30.0, "swim_speed": 0.86, "fish_catch": 0.32},
}

const REPEAT_WEIGHT := {
	"rabbit": 3,
	"bear": 1, "bison": 1, "crocodile": 1, "tiger": 1,
	"elephant": 1, "owl": 1, "moose": 1, "turtle": 1, "cheetah": 1,
	"rhino": 1, "gorilla": 1, "eagle": 1, "hippo": 1, "lion": 1,
}

const REPEAT_FROM_LEVEL := {"elephant": 10, "owl": 10, "rhino": 10, "eagle": 10, "hippo": 10, "lion": 10}

const GROWTH_ARCHETYPE := {
	"rabbit": "survivor", "raccoon": "survivor", "monkey": "survivor",
	"fox": "skirmisher", "lynx": "skirmisher", "otter": "skirmisher", "owl": "skirmisher", "cheetah": "skirmisher", "eagle": "skirmisher",
	"wolf": "hunter", "snake": "hunter", "wolverine": "hunter", "crocodile": "hunter", "tiger": "hunter", "hyena": "hunter", "lion": "hunter",
	"deer": "runner", "capybara": "runner", "goat": "runner", "zebra": "runner",
	"bear": "guardian", "boar": "guardian", "porcupine": "guardian", "bison": "guardian", "moose": "guardian", "turtle": "guardian", "gorilla": "guardian",
	"elephant": "giant", "rhino": "giant", "hippo": "giant",
}

const GROWTH_PROFILES := {
	"survivor": {"name": "生存适应", "health": 0.080, "attack": 0.055, "speed": 0.025, "stamina": 0.060, "armor": 0.8, "regen": 0.025},
	"skirmisher": {"name": "敏捷猎手", "health": 0.085, "attack": 0.070, "speed": 0.022, "stamina": 0.055, "armor": 0.9, "regen": 0.024},
	"hunter": {"name": "捕食进化", "health": 0.090, "attack": 0.075, "speed": 0.018, "stamina": 0.050, "armor": 1.2, "regen": 0.022},
	"runner": {"name": "迁徙强化", "health": 0.095, "attack": 0.060, "speed": 0.021, "stamina": 0.065, "armor": 1.1, "regen": 0.030},
	"guardian": {"name": "重装成长", "health": 0.115, "attack": 0.065, "speed": 0.012, "stamina": 0.055, "armor": 1.8, "regen": 0.024},
	"giant": {"name": "巨兽蜕变", "health": 0.120, "attack": 0.070, "speed": 0.008, "stamina": 0.050, "armor": 2.2, "regen": 0.020},
}

# Growth is driven by continuous body mass rather than by the species' original
# threat tier.  This makes a fully grown rabbit a genuine medium-sized animal,
# while naturally large species still retain the highest possible ceiling.
const MAX_GROWTH_LEVEL := 10
const GROWTH_MILESTONES: Array[int] = [3, 6, 9]
const EXPERIENCE_THRESHOLDS: Array[int] = [45, 90, 150, 225, 315, 420, 540, 675, 825]
const BODY_GROWTH_BY_SIZE := {
	1: {"start": 1.0, "maximum": 3.2, "visual_max": 1.75},
	2: {"start": 1.8, "maximum": 3.8, "visual_max": 1.55},
	3: {"start": 2.7, "maximum": 4.6, "visual_max": 1.40},
	4: {"start": 3.8, "maximum": 5.4, "visual_max": 1.28},
	5: {"start": 4.9, "maximum": 6.4, "visual_max": 1.18},
}
const GROWTH_ARCHETYPE_CORE_MODIFIERS := {
	"survivor": {"health": 0.96, "attack": 0.94, "armor": -1.0, "speed_growth": 0.18, "stamina_growth": 0.34},
	"skirmisher": {"health": 0.94, "attack": 1.04, "armor": -1.0, "speed_growth": 0.17, "stamina_growth": 0.32},
	"hunter": {"health": 0.99, "attack": 1.06, "armor": 0.0, "speed_growth": 0.14, "stamina_growth": 0.28},
	"runner": {"health": 1.01, "attack": 0.96, "armor": 0.0, "speed_growth": 0.18, "stamina_growth": 0.36},
	"guardian": {"health": 1.07, "attack": 0.99, "armor": 2.0, "speed_growth": 0.11, "stamina_growth": 0.30},
	"giant": {"health": 1.08, "attack": 1.03, "armor": 3.0, "speed_growth": 0.09, "stamina_growth": 0.27},
}

const ADAPTATION_ROUTE_ORDER: Array[String] = ["habitat", "combat", "ecology"]
const ADAPTATION_ROUTE_DISPLAY_NAMES := {
	"habitat": "生境适应",
	"combat": "战斗技艺",
	"ecology": "生态关系",
}
const INSTINCT_STAGE_ORDER: Array[String] = ["prepare", "survive", "compete"]
const INSTINCT_STAGE_REWARDS := [
	{"xp": 8, "health_ratio": 0.0, "stamina_ratio": 0.08},
	{"xp": 12, "health_ratio": 0.05, "stamina_ratio": 0.12},
	{"xp": 18, "health_ratio": 0.08, "stamina_ratio": 0.16},
]
const SPECIES_ADAPTATION_NAMES := {
	"rabbit": ["草影", "折返", "多点觅食"],
	"fox": ["林缘", "佯攻扩散", "机会食腐"],
	"deer": ["开阔步幅", "断后蹬踏", "迁徙记忆"],
	"wolf": ["驱赶者", "截击扑杀", "分食秩序"],
	"snake": ["湿草潜行", "迟发毒性", "血味隐藏"],
	"bear": ["杂食储备", "震地余势", "有限领地"],
	"boar": ["泥地冲线", "破围突阵", "拱土寻路"],
	"raccoon": ["林间小径", "夺食翻滚", "巧手藏果"],
	"porcupine": ["窄路固守", "怒刺节奏", "啮根固刺"],
	"crocodile": ["浅流伏岸", "翻滚咬合", "水岸分食"],
	"capybara": ["水路同栖", "安抚撤离", "共享水草"],
	"otter": ["水线穿梭", "旋水回身", "鱼群感知"],
	"lynx": ["岩隙静猎", "无声收割", "藏餐"],
	"goat": ["崖径步伐", "角击换位", "岩根迁徙"],
	"wolverine": ["寒岩耐性", "巨兽撕咬", "大尸不屈"],
	"bison": ["草浪结阵", "踏阵开路", "守群进食"],
	"zebra": ["旷野变线", "乱纹扰敌", "迁徙补草"],
	"elephant": ["水草长途", "践踏通路", "象群记忆"],
	"tiger": ["密林侧翼", "裂风扑杀", "独食警戒"],
	"monkey": ["树冠路线", "投果标记", "林果见闻"],
	"owl": ["夜航", "静默俯冲", "夜栖精食"],
	"moose": ["湿岸步伐", "横扫断后", "岸线觅食"],
	"turtle": ["岩隙慢行", "出壳反击", "慢食疗养"],
	"cheetah": ["晴野呼吸", "极速收束", "猎后进食"],
	"rhino": ["草原冲线", "破阵角冲", "厚皮拱根"],
	"gorilla": ["林地边界", "震地示威", "林果护群"],
	"eagle": ["高地气流", "日照俯冲", "高地精食"],
	"hippo": ["浅水边界", "裂颚震慑", "湿地水草"],
	"hyena": ["腐味路线", "狂笑分工", "碎骨分食"],
	"lion": ["狮群前线", "围猎扑杀", "狮群分食"],
}

const HABIT_BUFF_NAMES := {
	"escape": "轻捷", "recover": "调息", "guard": "守势", "hunt": "猎性", "conceal": "匿踪",
}

const HABIT_FOOD_NAMES := {
	"grass": "嫩草", "berries": "野莓", "mushroom": "蘑菇", "fruit": "落果", "roots": "块根", "fish": "鱼群", "corpse": "猎物尸体",
}

# Ecological habits are deliberately separate from combat traits. Every animal
# gets one readable food-and-habitat loop, while TRAITS continue to own its
# combat, movement-domain and social behavior. A source can trigger its habit
# only once per actor, so regrowing beside one food patch is never optimal.
const ECO_HABITS := {
	"rabbit": {"name": "草窟反刍", "foods": ["grass"], "health": 0.080, "stamina": 0.120, "hunger": 4.0, "buff": "escape", "duration": 4.5, "condition": "cover", "seek_health": 0.90, "summary": "吃嫩草额外恢复生命与耐力；在森林、草原或草丛中效果最强，并短暂轻捷。"},
	"fox": {"name": "林缘藏食", "foods": ["corpse"], "health": 0.040, "stamina": 0.140, "hunger": 2.0, "buff": "escape", "duration": 3.8, "condition": "small_carcass", "prey_max": 2, "seek_health": 0.68, "summary": "取食尸体后补充耐力并轻捷撤离；小型猎物和林缘主场收益更高。"},
	"deer": {"name": "嫩叶迁徙", "foods": ["grass", "berries"], "health": 0.040, "stamina": 0.180, "hunger": 4.0, "buff": "recover", "duration": 5.5, "seek_health": 0.76, "summary": "沿森林与草原取食嫩草、野莓，大幅补回耐力并获得迁徙调息。"},
	"wolf": {"name": "群猎分食", "foods": ["corpse"], "health": 0.040, "stamina": 0.130, "hunger": 2.0, "buff": "hunt", "duration": 4.2, "condition": "large_carcass", "prey_min": 2, "seek_health": 0.62, "summary": "分食中型以上尸体可恢复耐力并短暂激发猎性，主场内更稳定。"},
	"snake": {"name": "冷伏精食", "foods": ["corpse", "fish"], "health": 0.050, "stamina": 0.100, "hunger": 2.0, "buff": "conceal", "duration": 4.8, "condition": "small_carcass", "prey_max": 2, "seek_health": 0.74, "summary": "取食鱼群或小型尸体后压低气味，在湿地与林下更难被远处发现。"},
	"bear": {"name": "杂食储能", "foods": ["berries", "fruit", "corpse"], "health": 0.035, "stamina": 0.100, "hunger": 5.0, "buff": "guard", "duration": 5.5, "condition": "injured", "seek_health": 0.58, "summary": "果实、野莓与尸体都能快速储能；受伤时进食会进入短暂守势。"},
	"boar": {"name": "拱土寻菌", "foods": ["mushroom", "roots"], "health": 0.050, "stamina": 0.120, "hunger": 5.0, "buff": "guard", "duration": 4.8, "condition": "injured", "seek_health": 0.68, "summary": "挖食蘑菇和块根可回复生命，受伤时还会绷紧硬皮抵抗追击。"},
	"raccoon": {"name": "巧手藏果", "foods": ["berries", "fruit"], "health": 0.040, "stamina": 0.160, "hunger": 5.0, "buff": "escape", "duration": 5.0, "xp": 3, "seek_health": 0.78, "summary": "第一次搜刮野莓或落果获得额外见闻，并借轻捷迅速离开食物点。"},
	"porcupine": {"name": "啮根固刺", "foods": ["roots", "mushroom"], "health": 0.060, "stamina": 0.100, "hunger": 4.0, "buff": "guard", "duration": 5.8, "condition": "injured", "seek_health": 0.82, "summary": "块根和蘑菇可恢复生命，受伤后取食会让背刺进入稳固守势。"},
	"crocodile": {"name": "伏岸吞食", "foods": ["fish", "corpse"], "health": 0.040, "stamina": 0.130, "hunger": 3.0, "buff": "conceal", "duration": 5.0, "seek_health": 0.62, "summary": "在湿地吞食鱼群或尸体后收敛水面痕迹，恢复耐力并重新伏岸。"},
	"capybara": {"name": "水草同栖", "foods": ["grass", "mushroom"], "health": 0.060, "stamina": 0.160, "hunger": 5.0, "buff": "recover", "duration": 6.0, "seek_health": 0.84, "summary": "取食湿地水草和蘑菇会稳定恢复生命、耐力，并延长同栖调息。"},
	"otter": {"name": "鱼群嬉食", "foods": ["fish"], "health": 0.050, "stamina": 0.200, "hunger": 4.0, "buff": "escape", "duration": 4.5, "condition": "rain", "seek_health": 0.78, "summary": "鱼群能大幅补回耐力；湿地、暴雨与风暴中触发更强的水面轻捷。"},
	"lynx": {"name": "岩隙藏餐", "foods": ["corpse"], "health": 0.040, "stamina": 0.150, "hunger": 2.0, "buff": "conceal", "duration": 5.2, "condition": "small_carcass", "prey_max": 2, "seek_health": 0.68, "summary": "吞食小型猎物后迅速藏身，在岩丘与林缘重新获得匿踪优势。"},
	"goat": {"name": "岩根反刍", "foods": ["roots", "grass"], "health": 0.060, "stamina": 0.180, "hunger": 5.0, "buff": "escape", "duration": 4.8, "seek_health": 0.82, "summary": "高地块根与嫩草能快速补给耐力，进食后以岩径轻捷脱离。"},
	"wolverine": {"name": "寒岩食腐", "foods": ["corpse"], "health": 0.050, "stamina": 0.160, "hunger": 3.0, "buff": "hunt", "duration": 5.0, "condition": "large_carcass", "prey_min": 3, "seek_health": 0.64, "summary": "大型尸体能激发不屈猎性，在高地与林下回复更多生命和耐力。"},
	"bison": {"name": "草浪蓄力", "foods": ["grass"], "health": 0.050, "stamina": 0.170, "hunger": 6.0, "buff": "guard", "duration": 6.0, "seek_health": 0.70, "summary": "草原进食嫩草能重整呼吸和队形，恢复耐力并短暂稳固身体。"},
	"zebra": {"name": "迁徙补草", "foods": ["grass", "fruit"], "health": 0.035, "stamina": 0.220, "hunger": 5.0, "buff": "escape", "duration": 5.2, "seek_health": 0.78, "summary": "草原上快速取食嫩草或落果，重点补回耐力并继续迁徙。"},
	"elephant": {"name": "水草长食", "foods": ["grass", "fruit"], "health": 0.025, "stamina": 0.100, "hunger": 10.0, "buff": "guard", "duration": 6.5, "seek_health": 0.58, "summary": "草原与湿地植物能满足巨额食量，进食后稳固巨体并降低围攻风险。"},
	"tiger": {"name": "密林独食", "foods": ["corpse"], "health": 0.045, "stamina": 0.140, "hunger": 2.0, "buff": "hunt", "duration": 5.0, "condition": "large_carcass", "prey_min": 3, "seek_health": 0.60, "summary": "在密林独占中大型尸体可恢复爆发耐力，并短暂激发独猎猎性。"},
	"monkey": {"name": "林冠果宴", "foods": ["fruit", "berries"], "health": 0.050, "stamina": 0.180, "hunger": 5.0, "buff": "escape", "duration": 5.2, "xp": 3, "seek_health": 0.82, "summary": "林地果实与野莓提供额外见闻和耐力，便于进食后迅速转入树冠路线。"},
	"owl": {"name": "夜栖精食", "foods": ["corpse"], "health": 0.040, "stamina": 0.200, "hunger": 2.0, "buff": "conceal", "duration": 5.5, "condition": "night", "prey_max": 2, "seek_health": 0.72, "summary": "夜间吞食小型猎物能快速补回巡航耐力，并借夜幕重新匿踪。"},
	"moose": {"name": "湿岸啃食", "foods": ["grass", "roots"], "health": 0.050, "stamina": 0.160, "hunger": 6.0, "buff": "guard", "duration": 5.5, "seek_health": 0.70, "summary": "湿岸嫩草与岩根可补回生命与耐力，进食后稳住巨角防线对抗围攻。"},
	"turtle": {"name": "岩隙慢食", "foods": ["mushroom", "roots"], "health": 0.080, "stamina": 0.130, "hunger": 5.0, "buff": "guard", "duration": 7.0, "condition": "clear", "seek_health": 0.90, "summary": "蘑菇与块根提供最高的慢速疗养；晴朗时进食会延长岩甲守势。"},
	"cheetah": {"name": "猎后喘息", "foods": ["corpse"], "health": 0.035, "stamina": 0.220, "hunger": 2.0, "buff": "recover", "duration": 6.0, "condition": "clear", "prey_min": 2, "prey_max": 3, "seek_health": 0.62, "summary": "晴朗草原上进食中型猎物可大幅补回爆发耐力，缩短猎后喘息的危险期。"},
	"rhino": {"name": "厚皮拱根", "foods": ["roots", "grass"], "health": 0.035, "stamina": 0.120, "hunger": 7.0, "buff": "guard", "duration": 6.2, "condition": "injured", "seek_health": 0.62, "summary": "草根与块根稳定巨兽体力，受伤进食后厚皮进入额外守势。"},
	"gorilla": {"name": "林果疗养", "foods": ["fruit", "berries"], "health": 0.050, "stamina": 0.160, "hunger": 6.0, "buff": "guard", "duration": 6.0, "xp": 2, "seek_health": 0.68, "summary": "在森林领地取食果实可恢复生命与见闻，并强化短暂领地守势。"},
	"eagle": {"name": "高地精食", "foods": ["corpse"], "health": 0.040, "stamina": 0.220, "hunger": 2.0, "buff": "hunt", "duration": 4.5, "condition": "day", "prey_max": 2, "seek_health": 0.70, "summary": "白天在高地或草原取食小型猎物，大幅补回飞行耐力并恢复猎性。"},
	"hippo": {"name": "湿地水草", "foods": ["grass"], "health": 0.040, "stamina": 0.120, "hunger": 8.0, "buff": "guard", "duration": 6.5, "condition": "rain", "seek_health": 0.62, "summary": "湿地嫩草能补足巨额饱腹，雨天进食后更能强化水岸守势。"},
	"hyena": {"name": "碎骨食腐", "foods": ["corpse"], "health": 0.050, "stamina": 0.160, "hunger": 3.0, "buff": "hunt", "duration": 5.2, "condition": "large_carcass", "prey_min": 3, "seek_health": 0.66, "summary": "大型尸体能补回生命与耐力，并让鬣狗以碎骨猎性守住战利品。"},
	"lion": {"name": "狮群分食", "foods": ["corpse"], "health": 0.045, "stamina": 0.140, "hunger": 3.0, "buff": "hunt", "duration": 5.0, "condition": "large_carcass", "prey_min": 3, "seek_health": 0.62, "summary": "草原上分食中大型猎物可恢复体力，并延续狮群的围猎猎性。"},
}

const VICTORY_GUIDES := {
	"rabbit": "前期沿森林与草原的草丛寻找嫩草，用草窟反刍回血、补耐力和轻捷迁徙，不和捕食者换血。中期把狼、狐引向熊或蛇制造混战；终局保留月影折跃和半条以上耐力，用伏击、主场反制与连续变向拖垮最后的追猎者。",
	"fox": "围绕尸体和残血目标行动，不做第一只开战的动物。先用血味佯攻把猎物暴露给其他捕食者，再补刀获取经验；终局依靠速度和更高等级逐个收割。",
	"deer": "优先积累耐力与等级，保持长直线移动，不在树林死角停留。用蹬踏把追兵推入其他战团；终局控制耐力节奏，让敌人冲刺耗尽后再反击。",
	"wolf": "尽快靠近同类，选择中小型落单猎物，不要独自挑战巨兽。扑杀前先让狼群形成夹击；终局若失去同伴，利用速度反复脱战，等目标残血后再收尾。",
	"snake": "藏在植物、尸体或狭窄路线附近，避免长距离追击。用毒迫使强敌离开资源点并交给第三方消耗；终局保持距离，反复上毒后等待生命自然下降。",
	"bear": "占据尸体和植物都丰富的区域，以反击而非追击为主。重击用于打断围攻并守住资源；终局靠高生命和怒意换血，但要防止毒与群猎持续破甲。",
	"boar": "在开阔路线积累冲锋空间，撞散小型围攻并抢先吃掉资源。不要把突阵浪费在巨兽正面；终局用低血量抗击退优势守住中央食物。",
	"raccoon": "避开正面战斗，持续偷取植物和尸体，把资源转化为等级。技能后立刻撤离并更换热点；终局依靠速度成长诱导最后两名强敌互斗。",
	"porcupine": "选择狭窄通路或尸体旁防守，让近战敌人主动承受反刺。怒刺绽放留给多人贴身时使用；终局不要追人，守住收束区资源迫使对手靠近。",
	"crocodile": "长期围绕湿地、鱼群和过河点伏击，离水后不做远追。死亡翻滚优先锁住正在进食或耐力不足的目标；终局提前进入中央水岸，逼敌在你的优势地形接战。",
	"capybara": "利用湿地续航和安抚穿过混战，优先吃植物稳定升级。安抚不是进攻技能，用它打断追猎并带同类转移；终局保存耐力，以反复脱战等待强敌互相消耗。",
	"otter": "把湿地当作高速公路，快速争夺鱼群和残血目标。旋水突袭在水中收益最高，命中后立刻回到水带；终局不要在陆地和重装动物持续换血。",
	"lynx": "保持静止或利用高地隐藏，专找小型、残血和脱队目标。无声飞扑用于确认能击杀的猎物；终局耐心等待敌人技能进入冷却，再从侧后方收割。",
	"goat": "沿岩丘和狭窄路线活动，利用高地出生优势避开大型追兵。角击主要用于突围和把敌人推入混战；终局依靠速度与耐力成长争夺最后资源。",
	"wolverine": "以尸体热点为中心骚扰大型动物，但不要一次打到底。不屈狂袭在巨兽被围攻时切入收益最高；终局靠高攻击成长处理重装目标，生命过半前就准备脱战。",
	"bison": "保持直线迁徙，避免被树林和岩石限制转向。踏阵冲锋用来拆散狼群或保护进食窗口；终局用生命、护甲成长占住中央，但不要连续空放冲锋。",
	"zebra": "与同类保持相近方向，通过群体转向摆脱猎手。技能用来穿过战团而不是单纯逃远；终局保留一次完整冲刺，在对手技能落空后回头反击。",
	"elephant": "前期持续寻找植物，避免因体型优势忽视饥饿。践踏只在多人贴身或能推倒小树开路时使用；终局优先处理毒蛇和群猎者，靠等级成长建立生命优势。",
	"tiger": "利用森林侧翼接近，选择一轮爆发能压低的中型目标。扑杀后不要停在尸体中央，先观察其他捕食者；终局依靠攻击成长快速结束战斗，避免被围攻。",
	"monkey": "靠森林植物和远程投掷安全积累经验，始终记住附近可攀爬树木。被贴身时进入树冠换位；终局用投掷减速、落地进食和再次上树形成循环。",
	"owl": "夜晚从巡航空域侦察小型落单目标，白天降低冒险频率。俯冲前确认附近没有大型守尸者；终局必须控制落地点，命中后立即拉升或脱离。",
	"moose": "在湿地与高地边缘活动，用体型和横扫阻止多人贴身。不要追逐高速小动物；终局站住资源热点，等对手靠近后用范围技能建立换血优势。",
	"turtle": "前期安静吃植物升级，遇到爆发攻击再缩壳，不要长期空耗时间。利用其他动物争夺你的低收益目标；终局在收束区保存技能，等敌人攻击后解除防御反打。",
	"cheetah": "晴朗草原是主战场，锁定生命低且没有同伴的猎物。极速猎杀后会疲劳，必须预留撤离方向；终局等对手交完控制技能再爆发，避免坏天气下强追。",
	"rhino": "选择开阔道路蓄力，破阵角冲用来击穿战团而不是贴墙起步。靠植物维持巨兽消耗；终局用护甲成长逼迫对手正面接战，同时警惕毒和群猎破甲。",
	"gorilla": "把森林资源区设为领地，追击超出范围后主动返回。震地示威用于驱散入侵者并重设安全区；终局随着收束迁移领地，保持自己始终靠近食物。",
	"eagle": "白天从高空选择小型、孤立且远离守尸者的目标。天穹贯击距离越长收益越高，但落点也更危险；终局用巡航侦察等待机会，不要反复无效落地。",
	"hippo": "守住湿地水源和高价值食物，让其他动物主动进入你的攻击范围。裂颚震慑用于阻止围攻，不做长距离追击；终局提前占据中央水岸，以生命和攻击成长硬控资源。",
	"hyena": "跟随同类和尸体热点行动，通过围堵夺走其他捕食者的战利品。狂笑围猎优先标记残血或落单目标；终局不要单挑满血巨兽，先持续骚扰等待破绽。",
	"lion": "在草原寻找同类并控制开阔区域，避免在密林里浪费号令。先标记目标再让狮群夹击，自己保留耐力收尾；终局失去同伴后要像伏击者一样耐心，不能硬追。",
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
		"wetland_speed": 1.12,
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
		"wetland_speed": 1.08,
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
	},
	"raccoon": {
		"name": "林地浣熊",
		"subtitle": "资源窃取者",
		"color": "#59616a",
		"accent": "#d5d0bc",
		"size": 2,
		"diet": "omnivore",
		"health": 92.0,
		"xp_reward": 34,
		"stamina": 124.0,
		"speed": 6.5,
		"sprint": 1.62,
		"regen": 18.0,
		"attack": 14.0,
		"attack_range": 1.50,
		"attack_interval": 0.74,
		"attack_cost": 7.0,
		"armor": 4.0,
		"passive": "巧手寻踪",
		"passive_hint": "更远发现食物与尸体，进食后短暂加速",
		"skill": "顺手牵食",
		"skill_hint": "快速夺取附近食物并翻滚撤离，也能借敌人掩护脱身",
		"skill_feedback": "食物已经到手，趁争夺者反应前迅速撤离",
		"skill_color": "#a7d5c8",
		"skill_cooldown": 7.0,
		"skill_cost": 16.0,
		"aggression": 0.31,
		"courage": 0.27,
		"hunger_rate": 0.15,
		"preferred_prey": ["rabbit", "snake"],
		"tip": "不要正面换血。偷走热点资源后把追兵带进其他动物的领地。"
	},
	"porcupine": {
		"name": "针背豪猪",
		"subtitle": "反伤防御者",
		"color": "#4d4136",
		"accent": "#dfcfaa",
		"size": 2,
		"diet": "herbivore",
		"health": 122.0,
		"xp_reward": 42,
		"stamina": 104.0,
		"speed": 4.7,
		"sprint": 1.42,
		"regen": 16.0,
		"attack": 12.0,
		"attack_range": 1.55,
		"attack_interval": 0.96,
		"attack_cost": 7.0,
		"armor": 18.0,
		"passive": "针背",
		"passive_hint": "近身攻击者会受到反刺伤害，技能期间反伤更强",
		"skill": "怒刺绽放",
		"skill_hint": "竖起背刺震开近敌，并在短时间内强化反伤",
		"skill_feedback": "背刺完全竖起，贸然近身的敌人会付出代价",
		"skill_color": "#e8d18f",
		"skill_cooldown": 9.0,
		"skill_cost": 20.0,
		"aggression": 0.08,
		"courage": 0.48,
		"hunger_rate": 0.13,
		"preferred_prey": [],
		"tip": "靠近狭窄通路和强者战团防守，等捕食者被反刺后再撤离。"
	},
	"goat": {
		"name": "岩岭山羊",
		"subtitle": "高地突围者",
		"color": "#b7aa8a",
		"accent": "#5b4a38",
		"size": 3,
		"diet": "herbivore",
		"health": 152.0,
		"xp_reward": 46,
		"stamina": 138.0,
		"speed": 6.0,
		"sprint": 1.58,
		"regen": 18.0,
		"attack": 22.0,
		"attack_range": 1.80,
		"attack_interval": 0.92,
		"attack_cost": 9.0,
		"armor": 9.0,
		"passive": "岩径步伐",
		"passive_hint": "直线奔跑更省耐力，并优先选择岩丘高地出生",
		"skill": "崖跃角击",
		"skill_hint": "向目标跃进角击，撞开追兵并获得短暂脱身距离",
		"skill_feedback": "角击改变了追逃位置，立刻借高地路线甩开敌人",
		"skill_color": "#e1d29d",
		"skill_cooldown": 7.5,
		"skill_cost": 21.0,
		"aggression": 0.14,
		"courage": 0.49,
		"hunger_rate": 0.14,
		"preferred_prey": [],
		"tip": "在岩丘与窄道保留耐力，追兵贴近时用角击夺回路线主动权。"
	},
	"wolverine": {
		"name": "高山狼獾",
		"subtitle": "逆体型斗士",
		"color": "#3c3028",
		"accent": "#c19a62",
		"size": 2,
		"diet": "omnivore",
		"health": 138.0,
		"xp_reward": 52,
		"stamina": 112.0,
		"speed": 6.1,
		"sprint": 1.52,
		"regen": 16.0,
		"attack": 24.0,
		"attack_range": 1.62,
		"attack_interval": 0.78,
		"attack_cost": 9.0,
		"armor": 11.0,
		"passive": "无畏咬合",
		"passive_hint": "攻击比自己更大的动物时伤害提高，不轻易因体型逃跑",
		"skill": "不屈狂袭",
		"skill_hint": "扑向目标连续撕咬，对大型目标额外增伤并恢复少量耐力",
		"skill_feedback": "体型差反而激起了斗志，但不要在尸体热点恋战",
		"skill_color": "#d69b57",
		"skill_cooldown": 8.0,
		"skill_cost": 22.0,
		"aggression": 0.62,
		"courage": 0.72,
		"hunger_rate": 0.18,
		"preferred_prey": ["rabbit", "fox", "snake", "raccoon", "porcupine"],
		"tip": "骚扰大型动物和残血目标，抢到尸体后及时退出第二场混战。"
	},
	"zebra": {
		"name": "疾风斑马",
		"subtitle": "群体逃生者",
		"color": "#e4dfce",
		"accent": "#25282a",
		"size": 3,
		"diet": "herbivore",
		"health": 176.0,
		"xp_reward": 48,
		"stamina": 146.0,
		"speed": 7.0,
		"sprint": 1.62,
		"regen": 18.0,
		"attack": 18.0,
		"attack_range": 1.82,
		"attack_interval": 0.94,
		"attack_cost": 9.0,
		"armor": 6.0,
		"passive": "同群疾驰",
		"passive_hint": "附近同类会共享逃跑方向，直线冲刺耗耐更低",
		"skill": "乱纹奔逃",
		"skill_hint": "高速变向并带动附近同类奔逃，短暂扰乱追猎者锁定",
		"skill_feedback": "交错条纹打乱了锁定，同群正在一起转向",
		"skill_color": "#f2edcf",
		"skill_cooldown": 8.0,
		"skill_cost": 22.0,
		"aggression": 0.10,
		"courage": 0.34,
		"hunger_rate": 0.15,
		"preferred_prey": [],
		"tip": "在开阔地保持速度，把追猎者拖进迁徙群和大型动物附近。"
	},
	"hyena": {
		"name": "斑鬣狗",
		"subtitle": "群体争尸者",
		"color": "#9b8157",
		"accent": "#3f3328",
		"size": 3,
		"diet": "carnivore",
		"health": 162.0,
		"xp_reward": 56,
		"stamina": 124.0,
		"speed": 6.0,
		"sprint": 1.54,
		"regen": 16.0,
		"attack": 25.0,
		"attack_range": 1.78,
		"attack_interval": 0.82,
		"attack_cost": 10.0,
		"armor": 10.0,
		"passive": "争尸耐性",
		"passive_hint": "更远发现尸体，附近同类会降低攻击耐力消耗",
		"skill": "狂笑围猎",
		"skill_hint": "咬伤并标记目标，召集附近鬣狗持续围堵",
		"skill_feedback": "狂笑传遍战团，同类正在从不同方向逼近目标",
		"skill_color": "#e3b864",
		"skill_cooldown": 8.5,
		"skill_cost": 24.0,
		"aggression": 0.68,
		"courage": 0.61,
		"hunger_rate": 0.17,
		"preferred_prey": ["rabbit", "fox", "deer", "snake", "raccoon", "porcupine", "goat", "zebra"],
		"tip": "围绕尸体与受伤猎物持续施压，单独面对猛虎或巨兽时先等待同类。"
	},
	"capybara": {
		"name": "湿地水豚",
		"subtitle": "群体缓冲者",
		"color": "#9a6846",
		"accent": "#d6b58a",
		"size": 3,
		"diet": "herbivore",
		"health": 168.0,
		"xp_reward": 43,
		"stamina": 132.0,
		"speed": 5.5,
		"wetland_speed": 1.08,
		"sprint": 1.52,
		"regen": 19.0,
		"attack": 12.0,
		"attack_range": 1.72,
		"attack_interval": 0.96,
		"attack_cost": 7.0,
		"armor": 7.0,
		"passive": "同栖",
		"passive_hint": "附近水豚会更快恢复耐力，遭遇威胁时保持松散群体",
		"skill": "同栖安抚",
		"skill_hint": "安抚周围非饥饿动物，打断追猎并为同群恢复耐力",
		"skill_feedback": "紧张气味暂时消散，周围动物降低了攻击意愿",
		"skill_color": "#8edbb8",
		"skill_cooldown": 9.0,
		"skill_cost": 20.0,
		"aggression": 0.06,
		"courage": 0.32,
		"hunger_rate": 0.13,
		"preferred_prey": [],
		"tip": "靠近群体和湿地资源活动，用安抚拆散追击，再选择安全方向迁徙。"
	},
	"monkey": {
		"name": "林冠猕猴",
		"subtitle": "攀爬投掷者",
		"color": "#8b684d",
		"accent": "#d0a07e",
		"size": 2,
		"diet": "omnivore",
		"health": 90.0,
		"xp_reward": 36,
		"stamina": 128.0,
		"speed": 6.7,
		"sprint": 1.58,
		"regen": 19.0,
		"attack": 13.0,
		"attack_range": 1.45,
		"attack_interval": 0.72,
		"attack_cost": 7.0,
		"armor": 2.0,
		"passive": "林冠机敏",
		"passive_hint": "靠近树木释放技能可短暂进入树冠层，避开地面追击并缩小绕障半径",
		"skill": "果实投掷",
		"skill_hint": "投掷果实造成伤害和气味标记；靠近树木时同时攀上树冠短暂脱离地面",
		"skill_feedback": "投射物划过林间，附近树冠也成为了短暂逃生路线",
		"skill_color": "#d7f07a",
		"skill_cooldown": 6.5,
		"skill_cost": 16.0,
		"aggression": 0.34,
		"courage": 0.25,
		"hunger_rate": 0.15,
		"preferred_prey": ["rabbit", "snake"],
		"tip": "保持距离投掷骚扰，不要落入中大型动物的近战范围。"
	},
	"gorilla": {
		"name": "银背猩猩",
		"subtitle": "领地控制者",
		"color": "#34383a",
		"accent": "#aeb4b2",
		"size": 4,
		"diet": "omnivore",
		"health": 365.0,
		"xp_reward": 104,
		"stamina": 116.0,
		"speed": 4.9,
		"sprint": 1.42,
		"regen": 14.0,
		"attack": 46.0,
		"attack_range": 2.25,
		"attack_interval": 1.08,
		"attack_cost": 15.0,
		"armor": 29.0,
		"passive": "银背领地",
		"passive_hint": "会守护出生区域和附近食物，但不会无限追杀越界目标",
		"skill": "震地示威",
		"skill_hint": "拍击地面造成范围伤害并威慑小型动物离开领地",
		"skill_feedback": "震动标示了领地边界，弱小入侵者开始撤离",
		"skill_color": "#c7d1ce",
		"skill_cooldown": 10.0,
		"skill_cost": 30.0,
		"aggression": 0.52,
		"courage": 0.88,
		"hunger_rate": 0.21,
		"preferred_prey": ["rabbit", "snake", "raccoon"],
		"tip": "控制林地资源而不是长途追击，利用震地把围攻者推出领地。"
	},
	"lion": {
		"name": "草原雄狮",
		"subtitle": "狮群首领",
		"color": "#b98745",
		"accent": "#5a3926",
		"size": 4,
		"diet": "carnivore",
		"health": 285.0,
		"xp_reward": 94,
		"stamina": 121.0,
		"speed": 5.9,
		"sprint": 1.52,
		"regen": 15.0,
		"attack": 42.0,
		"attack_range": 2.08,
		"attack_interval": 0.94,
		"attack_cost": 13.0,
		"armor": 20.0,
		"passive": "狮群首领",
		"passive_hint": "附近同类共享猎物目标并降低攻击耐力消耗，落单时弱于猛虎",
		"skill": "狮群号令",
		"skill_hint": "扑咬并召集附近狮子分散合围，同时震慑小型猎物",
		"skill_feedback": "号令已经传开，狮群正从两侧压缩猎物路线",
		"skill_color": "#f1bf62",
		"skill_cooldown": 9.0,
		"skill_cost": 28.0,
		"aggression": 0.74,
		"courage": 0.79,
		"hunger_rate": 0.21,
		"preferred_prey": ["rabbit", "fox", "deer", "wolf", "boar", "raccoon", "porcupine", "capybara", "goat", "zebra", "hyena"],
		"tip": "先用号令让同类形成包围，落单时不要和猛虎或巨兽正面换血。"
	},
	"otter": {
		"name": "灵巧水獭",
		"subtitle": "两栖游猎者",
		"color": "#76513a",
		"accent": "#e2c79b",
		"size": 2,
		"diet": "carnivore",
		"health": 96.0,
		"xp_reward": 39,
		"stamina": 132.0,
		"speed": 6.2,
		"wetland_speed": 1.30,
		"sprint": 1.55,
		"regen": 19.0,
		"attack": 17.0,
		"attack_range": 1.52,
		"attack_interval": 0.70,
		"attack_cost": 7.0,
		"armor": 3.0,
		"passive": "水陆游猎",
		"passive_hint": "在浅水湿地区域移动更快、冲刺消耗更低，并优先寻找鱼群",
		"skill": "旋水突袭",
		"skill_hint": "贴水冲过目标并造成减速，在湿地区域获得更长位移和耐力返还",
		"skill_feedback": "水花遮住了突袭路线，目标已经被拖慢",
		"skill_color": "#70d9dc",
		"skill_cooldown": 6.8,
		"skill_cost": 17.0,
		"aggression": 0.42,
		"courage": 0.30,
		"hunger_rate": 0.17,
		"preferred_prey": ["rabbit", "snake", "raccoon"],
		"tip": "围绕浅滩鱼群活动，借湿地速度差反复突袭；离水后不要和中型动物换血。"
	},
	"turtle": {
		"name": "岩甲陆龟",
		"subtitle": "姿态防御者",
		"color": "#64734c",
		"accent": "#b6a76b",
		"size": 2,
		"diet": "herbivore",
		"health": 192.0,
		"xp_reward": 54,
		"stamina": 145.0,
		"speed": 3.0,
		"sprint": 1.24,
		"regen": 15.0,
		"attack": 10.0,
		"attack_range": 1.48,
		"attack_interval": 1.12,
		"attack_cost": 6.0,
		"armor": 65.0,
		"passive": "岩甲",
		"passive_hint": "常态护甲极高但移动缓慢，缩壳时几乎免疫击退",
		"skill": "缩壳坚守",
		"skill_hint": "收起四肢停止移动，大幅降低伤害与击退，等待围攻者转移目标",
		"skill_feedback": "岩甲完全闭合，正面强攻现在收益很低",
		"skill_color": "#d6c77b",
		"skill_cooldown": 10.5,
		"skill_cost": 18.0,
		"aggression": 0.02,
		"courage": 0.58,
		"hunger_rate": 0.10,
		"preferred_prey": [],
		"tip": "你很难追击收尾。用缩壳熬过混战，再靠食物、毒和第三方冲突改变残局。"
	},
	"elephant": {
		"name": "非洲巨象",
		"subtitle": "生态工程巨兽",
		"color": "#777b78",
		"accent": "#d9d0b6",
		"size": 5,
		"diet": "herbivore",
		"health": 540.0,
		"xp_reward": 148,
		"stamina": 108.0,
		"speed": 4.15,
		"sprint": 1.34,
		"regen": 10.0,
		"attack": 58.0,
		"attack_range": 2.65,
		"attack_interval": 1.36,
		"attack_cost": 20.0,
		"armor": 44.0,
		"passive": "巨体开路",
		"passive_hint": "能够推倒挡路的小型树木，但食量巨大、转向慢且目标明显",
		"skill": "象群践踏",
		"skill_hint": "震击大片地面，击退周围动物、惊散小型生物并压倒轻型障碍",
		"skill_feedback": "地面正在震动，周围战团和轻型障碍都被推开",
		"skill_color": "#d8caa2",
		"skill_cooldown": 12.0,
		"skill_cost": 35.0,
		"aggression": 0.18,
		"courage": 0.96,
		"hunger_rate": 0.38,
		"preferred_prey": [],
		"tip": "用体型改变战团位置和通路，不要远离植物热点；高饥饿会迅速耗尽巨兽优势。"
	},
	"owl": {
		"name": "暗夜雕鸮",
		"subtitle": "夜行低空猎手",
		"color": "#6b5947",
		"accent": "#d5c292",
		"size": 2,
		"diet": "carnivore",
		"health": 82.0,
		"xp_reward": 46,
		"stamina": 130.0,
		"speed": 7.2,
		"sprint": 1.42,
		"regen": 17.0,
		"attack": 19.0,
		"attack_range": 1.82,
		"attack_interval": 0.78,
		"attack_cost": 8.0,
		"armor": 3.0,
		"flight_height": 4.2,
		"passive": "夜幕巡猎",
		"passive_hint": "巡航可越过地面障碍，夜晚感知和飞行速度提高，白天略微削弱",
		"skill": "影夜俯冲",
		"skill_hint": "从低空无声俯冲小型猎物，夜晚伤害更高并短暂扰乱其视野",
		"skill_feedback": "俯冲切断了猎物退路，你会在命中后重新拉升",
		"skill_color": "#b7a7e8",
		"skill_cooldown": 8.4,
		"skill_cost": 23.0,
		"aggression": 0.55,
		"courage": 0.34,
		"hunger_rate": 0.17,
		"preferred_prey": ["rabbit", "snake", "raccoon", "otter"],
		"tip": "保持巡航寻找落单小型目标；进食和俯冲后的低空窗口会让你暴露。"
	},
	"cheetah": {
		"name": "草原猎豹",
		"subtitle": "天气型极速猎手",
		"color": "#d4a94f",
		"accent": "#3b2b22",
		"size": 3,
		"diet": "carnivore",
		"health": 126.0,
		"xp_reward": 59,
		"stamina": 112.0,
		"speed": 8.2,
		"sprint": 1.75,
		"regen": 13.0,
		"attack": 27.0,
		"attack_range": 1.78,
		"attack_interval": 0.72,
		"attack_cost": 10.0,
		"armor": 4.0,
		"passive": "晴原疾驰",
		"passive_hint": "晴朗草原速度最高；暴雨和风暴会降低抓地力，爆发后进入短暂疲劳",
		"skill": "极速猎杀",
		"skill_hint": "锁定前方猎物高速追击并撕咬，晴天位移更长，结束后短暂减速",
		"skill_feedback": "极速爆发已经结束，利用障碍度过短暂疲劳期",
		"skill_color": "#ffd568",
		"skill_cooldown": 9.0,
		"skill_cost": 28.0,
		"aggression": 0.68,
		"courage": 0.40,
		"hunger_rate": 0.20,
		"preferred_prey": ["rabbit", "fox", "deer", "raccoon", "capybara", "goat", "zebra"],
		"tip": "在开阔草原选择一次有把握的追猎；爆发落空和坏天气都会留下耐力真空。"
	},
	"eagle": {
		"name": "高原金雕",
		"subtitle": "日行俯冲猎手",
		"color": "#6d4a2f",
		"accent": "#d6b76d",
		"size": 2,
		"diet": "carnivore",
		"health": 90.0,
		"xp_reward": 50,
		"stamina": 136.0,
		"speed": 7.8,
		"sprint": 1.48,
		"regen": 18.0,
		"attack": 23.0,
		"attack_range": 1.92,
		"attack_interval": 0.84,
		"attack_cost": 9.0,
		"armor": 3.0,
		"flight_height": 4.8,
		"passive": "高空锐眼",
		"passive_hint": "白天拥有更远感知和更快巡航；夜晚与强风会明显削弱空中优势",
		"skill": "天穹贯击",
		"skill_hint": "锁定远处小型目标高速俯冲，距离越远冲击越强，命中后重新拉升",
		"skill_feedback": "金色俯冲轨迹暴露了落点，立刻重新选择巡航方向",
		"skill_color": "#f0cb65",
		"skill_cooldown": 8.8,
		"skill_cost": 26.0,
		"aggression": 0.62,
		"courage": 0.42,
		"hunger_rate": 0.18,
		"preferred_prey": ["rabbit", "snake", "raccoon", "otter", "porcupine"],
		"tip": "白天从高地巡航并挑选孤立猎物；落地进食时不要贪恋尸体。"
	}
}


static func get_data(species_id: String) -> Dictionary:
	return DATA.get(species_id, DATA["rabbit"]).duplicate(true)


static func water_profile(species_id: String) -> Dictionary:
	return WATER_PROFILES.get(species_id, WATER_PROFILES["rabbit"]).duplicate(true)


static func water_grade(species_id: String) -> int:
	return clampi(int(WATER_PROFILES.get(species_id, WATER_PROFILES["rabbit"]).get("grade", 0)), 0, 4)


static func water_wade_depth(species_id: String) -> float:
	return maxf(float(WATER_PROFILES.get(species_id, WATER_PROFILES["rabbit"]).get("wade_depth", 0.14)), 0.05)


static func water_comfort_depth(species_id: String) -> float:
	return maxf(float(WATER_PROFILES.get(species_id, WATER_PROFILES["rabbit"]).get("comfort_depth", 0.18)), water_wade_depth(species_id))


static func water_breath_seconds(species_id: String) -> float:
	return maxf(float(WATER_PROFILES.get(species_id, WATER_PROFILES["rabbit"]).get("breath", 6.0)), 1.0)


static func water_speed_multiplier(species_id: String) -> float:
	return clampf(float(WATER_PROFILES.get(species_id, WATER_PROFILES["rabbit"]).get("swim_speed", 0.5)), 0.35, 1.55)


static func fish_catch_multiplier(species_id: String) -> float:
	return clampf(float(WATER_PROFILES.get(species_id, WATER_PROFILES["rabbit"]).get("fish_catch", 0.0)), 0.0, 1.60)


static func ai_water_entry_depth(species_id: String, hunger_value: float = 0.0, breath_ratio: float = 1.0, pursuing_fish: bool = false, escape_advantage: bool = false) -> float:
	var wade_depth := water_wade_depth(species_id)
	if breath_ratio <= 0.34:
		return wade_depth
	var limit := water_comfort_depth(species_id)
	if pursuing_fish and fish_catch_multiplier(species_id) > 0.0 and hunger_value >= 76.0 and breath_ratio >= 0.68:
		limit += 0.16
	if escape_advantage and breath_ratio >= 0.56:
		limit += 0.22
	return clampf(limit, wade_depth, 1.35)


static func water_description(species_id: String) -> String:
	var profile: Dictionary = WATER_PROFILES.get(species_id, WATER_PROFILES["rabbit"])
	var fish_text := " · 捕鱼效率 %.0f%%" % (fish_catch_multiplier(species_id) * 100.0) if fish_catch_multiplier(species_id) > 0.0 else ""
	return "水性：%s（%d/4）· 安全涉水 %.2fm · 屏息 %.0fs · 游速 %.0f%%%s" % [
		str(profile.get("name", "怕水")), water_grade(species_id), water_wade_depth(species_id), water_breath_seconds(species_id), water_speed_multiplier(species_id) * 100.0, fish_text,
	]


static func growth_archetype(species_id: String) -> String:
	return str(GROWTH_ARCHETYPE.get(species_id, "survivor"))


static func growth_profile(species_id: String) -> Dictionary:
	var archetype := growth_archetype(species_id)
	return GROWTH_PROFILES.get(archetype, GROWTH_PROFILES["survivor"]).duplicate(true)


static func body_growth_profile(species_id: String) -> Dictionary:
	var authored_size := clampi(body_size(species_id), 1, 5)
	return BODY_GROWTH_BY_SIZE.get(authored_size, BODY_GROWTH_BY_SIZE[1]).duplicate(true)


static func growth_progress(level: int, maximum_level: int = MAX_GROWTH_LEVEL) -> float:
	if maximum_level <= 1:
		return 1.0
	var linear_progress := clampf(float(level - 1) / float(maximum_level - 1), 0.0, 1.0)
	return pow(linear_progress, 0.85)


static func effective_body_size(species_id: String, level: int, maximum_level: int = MAX_GROWTH_LEVEL) -> float:
	var profile := body_growth_profile(species_id)
	return lerpf(float(profile["start"]), float(profile["maximum"]), growth_progress(level, maximum_level))


static func maximum_effective_body_size(species_id: String) -> float:
	return float(body_growth_profile(species_id)["maximum"])


static func visual_growth_scale(species_id: String, level: int, maximum_level: int = MAX_GROWTH_LEVEL) -> float:
	var profile := body_growth_profile(species_id)
	return lerpf(1.0, float(profile["visual_max"]), growth_progress(level, maximum_level))


static func growth_stats(species_id: String, level: int, maximum_level: int = MAX_GROWTH_LEVEL) -> Dictionary:
	var base := get_data(species_id)
	var archetype := growth_archetype(species_id)
	var modifiers: Dictionary = GROWTH_ARCHETYPE_CORE_MODIFIERS.get(archetype, GROWTH_ARCHETYPE_CORE_MODIFIERS["survivor"])
	var progress := growth_progress(level, maximum_level)
	var effective_size := effective_body_size(species_id, level, maximum_level)
	# Health, attack and armor share one body-mass curve. Species identity is a
	# deliberately narrow ±6% role modifier; locomotion, skills and habits remain
	# the main matchup differences between animals of equal current size.
	var health := (28.0 + 28.0 * pow(effective_size, 1.65)) * float(modifiers["health"])
	var attack := (3.0 + 4.0 * pow(effective_size, 1.50)) * float(modifiers["attack"])
	var armor := 8.0 * maxf(effective_size - 1.0, 0.0) + float(modifiers["armor"])
	if has_trait(species_id, "armored"):
		armor += 10.0
	return {
		"effective_size": effective_size,
		"visual_scale": visual_growth_scale(species_id, level, maximum_level),
		"health": maxf(health, 20.0),
		"attack": maxf(attack, 4.0),
		"armor": maxf(armor, 0.0),
		"speed": float(base["speed"]) * (1.0 + progress * float(modifiers["speed_growth"])),
		"stamina": float(base["stamina"]) * (1.0 + progress * float(modifiers["stamina_growth"])),
		"regen": float(base["regen"]) * (1.0 + progress * 0.25),
		# A growing body needs more food and is easier to track. This keeps level
		# growth from becoming a free, consequence-less stat snowball.
		"hunger_rate": float(base["hunger_rate"]) * (1.0 + progress * 0.12 + maxf(effective_size / maxf(float(body_growth_profile(species_id)["start"]), 0.1) - 1.0, 0.0) * 0.10),
	}


static func experience_threshold(level: int, effective_size_value: float) -> int:
	if level < 1 or level >= MAX_GROWTH_LEVEL:
		return 0
	var base_threshold := EXPERIENCE_THRESHOLDS[clampi(level - 1, 0, EXPERIENCE_THRESHOLDS.size() - 1)]
	var body_cost := clampf(0.82 + maxf(effective_size_value, 0.5) * 0.12, 0.90, 1.58)
	return maxi(roundi(float(base_threshold) * body_cost), 1)


static func adaptation_name(species_id: String, route_id: String) -> String:
	var route_index := ADAPTATION_ROUTE_ORDER.find(route_id)
	var names: Array = SPECIES_ADAPTATION_NAMES.get(species_id, ["主场本能", "战术磨炼", "生态共生"])
	if route_index < 0 or route_index >= names.size():
		return "生态适应"
	return str(names[route_index])


static func adaptation_description(species_id: String, route_id: String, next_rank: int = 1) -> String:
	var rank := clampi(next_rank, 1, 3)
	match route_id:
		"habitat":
			return "主场移动与恢复 +%d%%，冲刺消耗降低 %d%%；更善于利用掩体和水陆路线。" % [rank * 3, rank * 6]
		"combat":
			return "主动技能消耗与冷却各降低 %d%%，抓住强敌破绽时获得更稳定的战术收益。" % [rank * 6]
		"ecology":
			return "首次探索新食物的经验 +%d%%，营养与生态习性恢复 +%d%%。" % [rank * 12, rank * 6]
		_:
			return "形成一项新的局内生态能力。"


static func adaptation_choices(species_id: String, current_ranks: Dictionary = {}) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for route_id in ADAPTATION_ROUTE_ORDER:
		var next_rank := clampi(int(current_ranks.get(route_id, 0)) + 1, 1, 3)
		choices.append({
			"id": route_id,
			"route": str(ADAPTATION_ROUTE_DISPLAY_NAMES[route_id]),
			"name": adaptation_name(species_id, route_id),
			"rank": next_rank,
			"description": adaptation_description(species_id, route_id, next_rank),
		})
	return choices


static func instinct_chain(species_id: String) -> Array[Dictionary]:
	var species_data: Dictionary = DATA.get(species_id, DATA["rabbit"])
	var traits: Array = TRAITS.get(species_id, [])
	var favored_foods := habit_foods_display_text(species_id)
	var prepare_title := "觅食立足"
	var survive_title := "熟悉猎场"
	var compete_title := "生态竞争"
	if "flying" in traits:
		survive_title = "巡航落点"
	elif water_grade(species_id) >= 3:
		survive_title = "水陆迁徙"
	elif "escape" in traits or "canopy_mover" in traits or "herd_mover" in traits:
		survive_title = "安全迁徙"
	elif "territorial" in traits or "retaliator" in traits:
		survive_title = "巡守主场"
	if "pack_hunter" in traits or "leader" in traits:
		compete_title = "群体争胜"
	elif "territorial" in traits or "retaliator" in traits:
		compete_title = "领地反击"
	elif str(species_data.get("diet", "herbivore")) == "carnivore":
		compete_title = "合理捕食"
	elif "escape" in traits or "canopy_mover" in traits or str(species_data.get("diet", "herbivore")) == "herbivore":
		compete_title = "生态借力"
	var habit_name := str(habit_profile(species_id).get("name", "生态习性"))
	return [
		{
			"id": INSTINCT_STAGE_ORDER[0],
			"phase": "准备本能",
			"title": prepare_title,
			"description": "进食%s并触发「%s」；找不到时，完成两次普通进食也能立足。" % [favored_foods, habit_name],
		}.merged(INSTINCT_STAGE_REWARDS[0], true),
		{
			"id": INSTINCT_STAGE_ORDER[1],
			"phase": "生存本能",
			"title": survive_title,
			"description": "在适应区域迁徙24米，或对更强动物完成一次环境反制。",
		}.merged(INSTINCT_STAGE_REWARDS[1], true),
		{
			"id": INSTINCT_STAGE_ORDER[2],
			"phase": "竞争本能",
			"title": compete_title,
			"description": "通过击倒、生态助攻或新的逆袭路线影响一次竞争。",
		}.merged(INSTINCT_STAGE_REWARDS[2], true),
	]


static func instinct_stage_data(species_id: String, stage_index: int) -> Dictionary:
	var chain := instinct_chain(species_id)
	if stage_index < 0 or stage_index >= chain.size():
		return {}
	return chain[stage_index].duplicate(true)


static func instinct_chain_summary(species_id: String) -> String:
	var titles: Array[String] = []
	for goal in instinct_chain(species_id):
		titles.append(str(goal.get("title", "生态本能")))
	return " → ".join(titles)


static func growth_description(species_id: String) -> String:
	var profile := body_growth_profile(species_id)
	return "%s：最高 Lv.10 · 实时体型 %.1f → %.1f · 体型同步提高生命、攻击、护甲、速度与耐力；Lv.3/6/9 选择局内适应" % [
		str(growth_profile(species_id)["name"]), float(profile["start"]), float(profile["maximum"]),
	]


static func habit_profile(species_id: String) -> Dictionary:
	return ECO_HABITS.get(species_id, ECO_HABITS["rabbit"]).duplicate(true)


static func habit_description(species_id: String) -> String:
	var profile: Dictionary = ECO_HABITS.get(species_id, ECO_HABITS["rabbit"])
	return "生态习性：%s — %s" % [str(profile["name"]), str(profile["summary"])]


static func habit_favored_foods(species_id: String) -> Array[String]:
	var foods: Array[String] = []
	for food_kind in ECO_HABITS.get(species_id, ECO_HABITS["rabbit"]).get("foods", []):
		foods.append(str(food_kind))
	return foods


static func habit_seek_health_ratio(species_id: String) -> float:
	return clampf(float(ECO_HABITS.get(species_id, ECO_HABITS["rabbit"]).get("seek_health", 0.72)), 0.45, 0.95)


static func habit_buff_display_name(buff_id: String) -> String:
	return str(HABIT_BUFF_NAMES.get(buff_id, "生态调适"))


static func habit_food_display_name(food_kind: String) -> String:
	return str(HABIT_FOOD_NAMES.get(food_kind, "食物"))


static func habit_foods_display_text(species_id: String) -> String:
	var names: Array[String] = []
	for food_kind in habit_favored_foods(species_id):
		names.append(habit_food_display_name(food_kind))
	return "、".join(names)


static func habit_food_effect(species_id: String, food_kind: String, region_id: String, in_cover: bool = false, time_phase: String = "day", weather_id: String = "clear", health_ratio: float = 1.0, prey_size: int = 0) -> Dictionary:
	var profile: Dictionary = ECO_HABITS.get(species_id, {})
	if profile.is_empty() or food_kind not in profile.get("foods", []):
		return {}
	var scale := 1.0
	var home_active: bool = region_id in BIOME_PREFERENCES.get(species_id, [])
	if home_active:
		scale += 0.20
	var special_active := _habit_special_condition(profile, food_kind, in_cover, time_phase, weather_id, health_ratio, prey_size)
	if special_active:
		scale += 0.25
	return {
		"name": str(profile.get("name", "生态习性")),
		"health_ratio": float(profile.get("health", 0.0)) * scale,
		"stamina_ratio": float(profile.get("stamina", 0.0)) * scale,
		"hunger_bonus": float(profile.get("hunger", 0.0)) * scale,
		"xp_bonus": 2 + (1 if home_active else 0) + (1 if special_active else 0) + maxi(int(profile.get("xp", 0)), 0),
		"buff": str(profile.get("buff", "recover")),
		"duration": float(profile.get("duration", 4.0)) * (1.12 if home_active and special_active else 1.0),
		"home_active": home_active,
		"special_active": special_active,
	}


static func _habit_special_condition(profile: Dictionary, food_kind: String, in_cover: bool, time_phase: String, weather_id: String, health_ratio: float, prey_size: int) -> bool:
	var condition := str(profile.get("condition", ""))
	var condition_matches := false
	match condition:
		"cover": condition_matches = in_cover
		"injured": condition_matches = health_ratio <= 0.55
		"night": condition_matches = time_phase == "night"
		"day": condition_matches = time_phase == "day"
		"clear": condition_matches = weather_id == "clear"
		"rain": condition_matches = weather_id in ["rain", "storm"]
		"small_carcass": condition_matches = food_kind == "corpse" and prey_size > 0 and prey_size <= int(profile.get("prey_max", 2))
		"large_carcass": condition_matches = food_kind == "corpse" and prey_size >= int(profile.get("prey_min", 3))
		_: condition_matches = false
	if food_kind == "corpse" and condition not in ["small_carcass", "large_carcass"] and (profile.has("prey_min") or profile.has("prey_max")):
		var minimum_size := int(profile.get("prey_min", 1))
		var maximum_size := int(profile.get("prey_max", 5))
		condition_matches = condition_matches and prey_size >= minimum_size and prey_size <= maximum_size
	return condition_matches


static func victory_guide(species_id: String) -> String:
	return str(VICTORY_GUIDES.get(species_id, "优先获取食物和经验，观察其他动物互斗，在终局保留耐力与技能完成最后一战。"))


static func counterplay_plan(species_id: String) -> String:
	var traits: Array = TRAITS.get(species_id, [])
	var regions: Array[String] = preferred_regions(species_id)
	var home_name: String = str(BIOME_DISPLAY_NAMES.get(regions[0], "适应区域")) if not regions.is_empty() else "适应区域"
	var skill_name: String = str(DATA.get(species_id, DATA["rabbit"]).get("skill", "主动技能"))
	if "ambusher" in traits:
		return "草丛伏击 → %s反制；用「%s」脱战重置，等待第二种路线" % [home_name, skill_name]
	if "flying" in traits:
		return "高空观察后摇 → 用「%s」抓破绽；落地后借第三方换位" % skill_name
	if "canopy_mover" in traits or "escape" in traits:
		return "诱导追兵耗尽耐力 → %s反制；用「%s」脱战后再借力" % [home_name, skill_name]
	if "pack_hunter" in traits or "leader" in traits:
		return "群体施压制造破绽 → 用「%s」分割战场；再借第三方完成连携" % skill_name
	if "charger" in traits or "straight_runner" in traits:
		return "%s持续移动蓄势 → 用「%s」抓后摇；保留耐力完成第二种路线" % [home_name, skill_name]
	if "territorial" in traits or "retaliator" in traits:
		return "守住%s诱敌先手 → 用「%s」反击；必要时把追兵引向第三方" % [home_name, skill_name]
	return "%s周旋 → 用「%s」制造破绽 → 生态借力，完成两种路线" % [home_name, skill_name]


static func display_name(species_id: String) -> String:
	return str(DATA.get(species_id, DATA["rabbit"])["name"])


static func body_size(species_id: String) -> int:
	return int(DATA.get(species_id, DATA["rabbit"])["size"])


static func get_color(species_id: String) -> Color:
	return Color.from_string(str(DATA.get(species_id, DATA["rabbit"])["color"]), Color.WHITE)


static func experience_reward(species_id: String, victim_level: int = 1) -> int:
	var base_reward := int(DATA.get(species_id, DATA["rabbit"]).get("xp_reward", 20))
	return maxi(int(round(base_reward * (1.0 + maxi(victim_level - 1, 0) * 0.14))), 1)


static func combat_experience_reward(killer_id: String, victim_id: String, victim_level: int = 1, killer_size: float = -1.0, victim_size: float = -1.0, killer_power: float = 0.0, victim_power: float = 0.0) -> int:
	# Legacy/static callers still receive the authored-tier result. Live combat
	# passes current body size and power so a grown small species is no longer
	# treated as its Lv.1 silhouette for rewards or anti-snowballing.
	if killer_size < 0.0 or victim_size < 0.0:
		var base_reward := experience_reward(victim_id, victim_level)
		var tier_dominance := combat_tier(killer_id) - combat_tier(victim_id)
		var size_dominance := body_size(killer_id) - body_size(victim_id)
		var legacy_dominance_gap := clampi(maxi(tier_dominance, size_dominance), 0, 4)
		var multiplier: float = [1.0, 0.82, 0.68, 0.56, 0.48][legacy_dominance_gap]
		return maxi(roundi(float(base_reward) * multiplier), 1)
	var runtime_base := 10.0 + maxf(victim_size, 0.5) * 11.0 + float(maxi(victim_level, 1)) * 4.0
	var live_dominance_gap := runtime_opportunity_threat_gap(victim_size, killer_size, victim_power, killer_power)
	var underdog_gap := runtime_opportunity_threat_gap(killer_size, victim_size, killer_power, victim_power)
	var dominance_multiplier: float = [1.0, 0.82, 0.68, 0.56, 0.48][live_dominance_gap]
	var underdog_multiplier := 1.0 + float(underdog_gap) * 0.08
	return maxi(roundi(runtime_base * dominance_multiplier * underdog_multiplier), 1)


static func counterplay_experience_reward(target_id: String, target_level: int = 1) -> int:
	return maxi(int(round(experience_reward(target_id, target_level) * COUNTERPLAY_ROUTE_XP_RATIO)), 1)


static func counterplay_experience_cap(target_id: String, target_level: int = 1) -> int:
	return maxi(int(round(experience_reward(target_id, target_level) * COUNTERPLAY_TARGET_XP_CAP_RATIO)), 1)


static func combat_tier(species_id: String) -> int:
	var reward := int(DATA.get(species_id, DATA["rabbit"]).get("xp_reward", 20))
	if reward <= 30:
		return 1
	if reward <= 50:
		return 2
	if reward <= 80:
		return 3
	if reward <= 110:
		return 4
	return 5


static func opportunity_threat_gap(attacker_id: String, target_id: String) -> int:
	var attacker_data: Dictionary = DATA.get(attacker_id, DATA["rabbit"])
	var target_data: Dictionary = DATA.get(target_id, DATA["rabbit"])
	var tier_gap := combat_tier(target_id) - combat_tier(attacker_id)
	var size_gap := int(target_data["size"]) - int(attacker_data["size"])
	return clampi(maxi(tier_gap, size_gap), 0, OPPORTUNITY_MAX_GAP)


static func runtime_opportunity_threat_gap(attacker_size: float, target_size: float, attacker_power: float = 0.0, target_power: float = 0.0) -> int:
	var size_gap := maxi(ceili((target_size - attacker_size) / 0.90), 0)
	var power_gap := 0
	if attacker_power > 0.0 and target_power > 0.0:
		var ratio := target_power / maxf(attacker_power, 0.01)
		if ratio >= 2.30:
			power_gap = 4
		elif ratio >= 1.80:
			power_gap = 3
		elif ratio >= 1.45:
			power_gap = 2
		elif ratio >= 1.18:
			power_gap = 1
	return clampi(maxi(size_gap, power_gap), 0, OPPORTUNITY_MAX_GAP)


static func opportunity_health_ratio(threat_gap: int) -> float:
	if threat_gap <= 0:
		return 0.0
	return OPPORTUNITY_BASE_HEALTH_RATIO + float(clampi(threat_gap, 1, OPPORTUNITY_MAX_GAP)) * OPPORTUNITY_RATIO_PER_GAP


static func skill_exposure_duration(species_id: String) -> float:
	var data: Dictionary = DATA.get(species_id, DATA["rabbit"])
	return 0.85 + float(int(data["size"])) * 0.18 + float(combat_tier(species_id) - 1) * 0.12


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


static func habitat_affinity(species_id: String, region_id: String) -> float:
	# This helper runs in every actor's movement/stamina loop. Read the immutable
	# catalog array directly instead of allocating a duplicated typed array.
	var regions: Array = BIOME_PREFERENCES.get(species_id, ["forest", "grassland", "wetland", "highland"])
	var region_index := regions.find(region_id)
	if region_index < 0:
		return 0.0
	return 1.0 if region_index == 0 else 0.78


static func habitat_description(species_id: String) -> String:
	var regions: Array[String] = preferred_regions(species_id)
	if regions.is_empty():
		return "环境适应：无明确主场"
	var primary_name := str(BIOME_DISPLAY_NAMES.get(regions[0], regions[0]))
	if regions.size() == 1:
		return "环境适应：%s（主场）" % primary_name
	var familiar_names: Array[String] = []
	for index in range(1, regions.size()):
		familiar_names.append(str(BIOME_DISPLAY_NAMES.get(regions[index], regions[index])))
	return "环境适应：%s（主场） · %s（熟悉）" % [primary_name, " / ".join(familiar_names)]


static func has_trait(species_id: String, trait_id: String) -> bool:
	return trait_id in TRAITS.get(species_id, [])


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
	var mandatory: Array[String] = []
	if campaign_level > 1:
		for species_id in pool:
			if unlock_level(species_id) == campaign_level:
				mandatory.append(species_id)
	type_count = mini(maxi(type_count, mandatory.size() + (0 if mandatory.has("rabbit") else 1)), pool.size())
	var selected: Array[String] = []
	if pool.has("rabbit"):
		selected.append("rabbit")
	# The bear cave is an optional lesson, not the fixed answer to every teaching
	# ecosystem. When present the bear remains unique and dangerous; when absent,
	# wolves, foxes and snakes can produce a less predictable final contest.
	if campaign_level == 1 and pool.has("bear") and rng.randf() < FIRST_LEVEL_BEAR_CHANCE:
		selected.append("bear")
	for species_id in mandatory:
		if not selected.has(species_id):
			selected.append(species_id)
	for species_id in pool:
		if selected.size() >= type_count:
			break
		if campaign_level == 1 and species_id == "bear":
			continue
		if not selected.has(species_id):
			selected.append(species_id)
	var has_carnivore := false
	for species_id in selected:
		if str(DATA[species_id]["diet"]) == "carnivore":
			has_carnivore = true
			break
	if not has_carnivore:
		for candidate_id in pool:
			if str(DATA[candidate_id]["diet"]) != "carnivore" or selected.has(candidate_id):
				continue
			var replace_index := selected.size() - 1
			while replace_index >= 0 and (selected[replace_index] == "rabbit" or mandatory.has(selected[replace_index])):
				replace_index -= 1
			if replace_index >= 0:
				selected[replace_index] = candidate_id
			break

	var roster: Array[String] = selected.duplicate()
	while roster.size() < count:
		var weighted: Array[String] = []
		for species_id in selected:
			var species_cap := roster_species_cap(species_id, campaign_level)
			if species_cap > 0 and roster.count(species_id) >= species_cap:
				continue
			var weight := int(REPEAT_WEIGHT.get(species_id, 2))
			if campaign_level < int(REPEAT_FROM_LEVEL.get(species_id, 1)):
				weight = 0
			for i in range(weight):
				weighted.append(species_id)
		if weighted.is_empty():
			for species_id in selected:
				var species_cap := roster_species_cap(species_id, campaign_level)
				if species_cap <= 0 or roster.count(species_id) < species_cap:
					weighted.append(species_id)
		if weighted.is_empty():
			weighted.append("rabbit")
		roster.append(weighted[rng.randi_range(0, weighted.size() - 1)])

	# The first level is a teaching ecosystem, not a predator lottery. Preserve
	# every selected species while turning duplicate predator slots into enough
	# herbivores for at least two readable food-chain interactions.
	if campaign_level == 1:
		var early_foragers := 0
		for species_id in roster:
			if str(DATA[species_id]["diet"]) == "herbivore":
				early_foragers += 1
		while early_foragers < mini(5, roster.size()):
			var replacement_index := -1
			for index in range(roster.size() - 1, -1, -1):
				var species_id := roster[index]
				if str(DATA[species_id]["diet"]) != "herbivore" and roster.count(species_id) > 1:
					replacement_index = index
					break
			if replacement_index < 0:
				break
			roster[replacement_index] = "deer" if selected.has("deer") else "rabbit"
			early_foragers += 1

	_rebalance_roster_foragers(roster, selected, campaign_level, rng)

	for index in range(roster.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value: String = roster[index]
		roster[index] = roster[swap_index]
		roster[swap_index] = value
	return roster


static func roster_forager_bounds(count: int, campaign_level: int) -> Vector2i:
	var ratio_range := Vector2(0.50, 0.60)
	if campaign_level in [3, 4]:
		ratio_range = Vector2(0.45, 0.55)
	elif campaign_level in [5, 6, 7, 8]:
		ratio_range = Vector2(0.42, 0.50)
	elif campaign_level >= 9:
		ratio_range = Vector2(0.35, 0.45)
	return Vector2i(ceili(float(count) * ratio_range.x), floori(float(count) * ratio_range.y))


static func _rebalance_roster_foragers(roster: Array[String], selected: Array[String], campaign_level: int, rng: RandomNumberGenerator) -> void:
	var bounds := roster_forager_bounds(roster.size(), campaign_level)
	var forager_count := 0
	for species_id in roster:
		if str(DATA[species_id]["diet"]) == "herbivore":
			forager_count += 1
	var herbivores: Array[String] = []
	var non_herbivores: Array[String] = []
	for species_id in selected:
		if str(DATA[species_id]["diet"]) == "herbivore":
			herbivores.append(species_id)
		else:
			non_herbivores.append(species_id)
	while forager_count < bounds.x and not herbivores.is_empty():
		var replacement_index := -1
		for index in range(roster.size() - 1, -1, -1):
			var current_id := roster[index]
			if str(DATA[current_id]["diet"]) != "herbivore" and roster.count(current_id) > 1:
				replacement_index = index
				break
		if replacement_index < 0:
			break
		var replacement_id := _roster_candidate_with_capacity(herbivores, roster, campaign_level, rng)
		if replacement_id == "":
			break
		roster[replacement_index] = replacement_id
		forager_count += 1
	while forager_count > bounds.y and not non_herbivores.is_empty():
		var herbivore_index := -1
		for index in range(roster.size() - 1, -1, -1):
			var herbivore_id := roster[index]
			if str(DATA[herbivore_id]["diet"]) == "herbivore" and roster.count(herbivore_id) > 1:
				herbivore_index = index
				break
		if herbivore_index < 0:
			break
		var non_herbivore_id := _roster_candidate_with_capacity(non_herbivores, roster, campaign_level, rng)
		if non_herbivore_id == "":
			break
		roster[herbivore_index] = non_herbivore_id
		forager_count -= 1


static func _roster_candidate_with_capacity(candidates: Array[String], roster: Array[String], campaign_level: int, rng: RandomNumberGenerator) -> String:
	var eligible: Array[String] = []
	for species_id in candidates:
		var species_cap := roster_species_cap(species_id, campaign_level)
		if species_cap <= 0 or roster.count(species_id) < species_cap:
			eligible.append(species_id)
	if eligible.is_empty():
		return ""
	return eligible[rng.randi_range(0, eligible.size() - 1)]


static func roster_species_cap(species_id: String, campaign_level: int) -> int:
	if campaign_level == 1:
		if species_id == "bear":
			return 1
		if species_id == "wolf":
			return 3
	if campaign_level == 2 and species_id in ["boar", "porcupine"]:
		return 3
	if str(GROWTH_ARCHETYPE.get(species_id, "")) == "giant":
		if campaign_level == 5:
			return 1
		if campaign_level >= 6:
			return 2
	return 0


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
