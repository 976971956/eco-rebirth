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

const VICTORY_GUIDES := {
	"rabbit": "前期沿地图外圈吃植物升级，不和任何捕食者换血。中期把狼、狐引向熊或蛇制造混战；终局保留月影折跃和半条以上耐力，用连续变向拖垮最后的追猎者。",
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


static func growth_archetype(species_id: String) -> String:
	return str(GROWTH_ARCHETYPE.get(species_id, "survivor"))


static func growth_profile(species_id: String) -> Dictionary:
	var archetype := growth_archetype(species_id)
	return GROWTH_PROFILES.get(archetype, GROWTH_PROFILES["survivor"]).duplicate(true)


static func growth_description(species_id: String) -> String:
	var profile := growth_profile(species_id)
	return "%s：每级生命 +%.1f%%、攻击 +%.1f%%、速度 +%.1f%%、耐力 +%.1f%%、护甲 +%.1f" % [
		str(profile["name"]),
		float(profile["health"]) * 100.0,
		float(profile["attack"]) * 100.0,
		float(profile["speed"]) * 100.0,
		float(profile["stamina"]) * 100.0,
		float(profile["armor"]),
	]


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
