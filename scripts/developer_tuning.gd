class_name DeveloperTuning
extends RefCounted

const SCHEMA_VERSION := 1

const CATEGORIES: Array[Dictionary] = [
	{"id": "actor", "name": "动物属性", "description": "统一作用于玩家与 AI，保持同物种同规则。"},
	{"id": "growth", "name": "成长资源", "description": "控制升级速度、恢复效率与经验雨。"},
	{"id": "world", "name": "世界规则", "description": "结构参数会在下一局生成世界时应用。"},
	{"id": "ai", "name": "AI 智能", "description": "只改变信息处理与协作，不提供全图透视。"},
]

const PARAMETERS: Array[Dictionary] = [
	{"id": "health_scale", "category": "actor", "name": "生命上限", "description": "全体动物最大生命乘数", "default": 1.0, "min": 0.25, "max": 5.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "attack_scale", "category": "actor", "name": "攻击伤害", "description": "普通攻击与技能基础伤害乘数", "default": 1.0, "min": 0.25, "max": 5.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "armor_scale", "category": "actor", "name": "护甲强度", "description": "全体动物护甲数值乘数", "default": 1.0, "min": 0.0, "max": 4.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "body_size_scale", "category": "actor", "name": "动物体型", "description": "模型、碰撞、涉水线与实时体型整体乘数", "default": 1.0, "min": 0.50, "max": 2.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "speed_scale", "category": "actor", "name": "移动速度", "description": "行走、追击与逃跑速度乘数", "default": 1.0, "min": 0.50, "max": 2.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "stamina_scale", "category": "actor", "name": "耐力上限", "description": "全体动物最大耐力乘数", "default": 1.0, "min": 0.25, "max": 4.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "stamina_regen_scale", "category": "actor", "name": "耐力恢复", "description": "停止高耗动作后的恢复速度", "default": 1.0, "min": 0.25, "max": 4.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "hunger_rate_scale", "category": "actor", "name": "饥饿增长", "description": "设为 0 可关闭自然饥饿", "default": 1.0, "min": 0.0, "max": 4.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "skill_cost_scale", "category": "actor", "name": "技能耐力消耗", "description": "设为 0 可无消耗释放技能", "default": 1.0, "min": 0.0, "max": 3.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "skill_cooldown_scale", "category": "actor", "name": "技能冷却时间", "description": "数值越小，技能恢复越快", "default": 1.0, "min": 0.20, "max": 3.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},

	{"id": "experience_gain_scale", "category": "growth", "name": "经验获得", "description": "击杀、觅食、本能与普通经验包奖励", "default": 1.0, "min": 0.10, "max": 10.0, "step": 0.10, "decimals": 1, "unit": "×", "apply": "live"},
	{"id": "experience_need_scale", "category": "growth", "name": "升级需求", "description": "每级所需经验乘数", "default": 1.0, "min": 0.25, "max": 5.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "food_heal_scale", "category": "growth", "name": "野外食物回血", "description": "草、野莓、蘑菇、落果、块根和鱼的治疗", "default": 1.0, "min": 0.0, "max": 5.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "corpse_heal_scale", "category": "growth", "name": "尸体回血", "description": "进食动物尸体获得的生命恢复", "default": 1.0, "min": 0.0, "max": 5.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "experience_interval_seconds", "category": "growth", "name": "经验雨间隔", "description": "每轮经验包刷新的秒数", "default": 60.0, "min": 10.0, "max": 300.0, "step": 5.0, "decimals": 0, "unit": "秒", "apply": "live"},
	{"id": "experience_wave_scale", "category": "growth", "name": "每轮经验包数量", "description": "关卡基础刷新数量乘数", "default": 1.0, "min": 0.25, "max": 3.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "experience_cap_scale", "category": "growth", "name": "经验包总量上限", "description": "活动包容量乘数；始终不少于一整轮", "default": 1.0, "min": 0.50, "max": 3.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "level_pack_chance_scale", "category": "growth", "name": "直接升级包概率", "description": "跃迁经验包出现概率乘数", "default": 1.0, "min": 0.0, "max": 10.0, "step": 0.10, "decimals": 1, "unit": "×", "apply": "live"},
	{"id": "food_capacity_scale", "category": "growth", "name": "食物容量", "description": "每个食物点可进食总量", "default": 1.0, "min": 0.25, "max": 4.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "food_regrow_speed_scale", "category": "growth", "name": "食物再生速度", "description": "设为 0 可关闭食物再生", "default": 1.0, "min": 0.0, "max": 5.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},

	{"id": "actor_count_scale", "category": "world", "name": "动物数量", "description": "关卡初始动物数量，安全限制为 2–150", "default": 1.0, "min": 0.25, "max": 1.50, "step": 0.05, "decimals": 2, "unit": "×", "apply": "next_run"},
	{"id": "world_size_scale", "category": "world", "name": "地图大小", "description": "地表、河流、资源和边界整体尺寸", "default": 1.0, "min": 0.50, "max": 1.50, "step": 0.05, "decimals": 2, "unit": "×", "apply": "next_run"},
	{"id": "collapse_start_scale", "category": "world", "name": "终局开始时间", "description": "建立期与强制收束时间乘数", "default": 1.0, "min": 0.25, "max": 3.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "collapse_speed_scale", "category": "world", "name": "安全圈收缩速度", "description": "数值越大，终局圈缩得越快", "default": 1.0, "min": 0.25, "max": 4.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},

	{"id": "ai_think_speed_scale", "category": "ai", "name": "AI 思考速度", "description": "感知与重新决策频率；数值越大越快", "default": 1.0, "min": 0.25, "max": 3.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "ai_perception_scale", "category": "ai", "name": "AI 感知范围", "description": "发现动物、资源和危险的距离", "default": 1.0, "min": 0.25, "max": 3.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "ai_memory_scale", "category": "ai", "name": "AI 追踪记忆", "description": "失去视野后继续搜索目标的时间", "default": 1.0, "min": 0.25, "max": 3.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
	{"id": "ai_cooperation_scale", "category": "ai", "name": "AI 协作范围", "description": "同类分享猎物、危险与资源信息的强度", "default": 1.0, "min": 0.25, "max": 3.0, "step": 0.05, "decimals": 2, "unit": "×", "apply": "live"},
]


static func category_definitions() -> Array[Dictionary]:
	return CATEGORIES.duplicate(true)


static func parameter_definitions(category_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for parameter in PARAMETERS:
		if category_id.is_empty() or str(parameter["category"]) == category_id:
			result.append(parameter.duplicate(true))
	return result


static func parameter_definition(parameter_id: String) -> Dictionary:
	for parameter in PARAMETERS:
		if str(parameter["id"]) == parameter_id:
			return parameter.duplicate(true)
	return {}


static func default_values() -> Dictionary:
	var result: Dictionary = {}
	for parameter in PARAMETERS:
		result[str(parameter["id"])] = float(parameter["default"])
	return result


static func sanitize_values(raw_values: Variant) -> Dictionary:
	var source: Dictionary = raw_values if raw_values is Dictionary else {}
	var result := default_values()
	for parameter in PARAMETERS:
		var parameter_id := str(parameter["id"])
		var value := float(source.get(parameter_id, parameter["default"]))
		if is_nan(value) or is_inf(value):
			value = float(parameter["default"])
		var step := float(parameter["step"])
		value = clampf(value, float(parameter["min"]), float(parameter["max"]))
		if step > 0.0:
			value = snappedf(value, step)
		result[parameter_id] = value
	return result


static func value(values: Dictionary, parameter_id: String) -> float:
	var parameter := parameter_definition(parameter_id)
	if parameter.is_empty():
		return 1.0
	return float(sanitize_values(values).get(parameter_id, parameter["default"]))


static func is_default(values: Dictionary) -> bool:
	var sanitized := sanitize_values(values)
	for parameter in PARAMETERS:
		var parameter_id := str(parameter["id"])
		if not is_equal_approx(float(sanitized[parameter_id]), float(parameter["default"])):
			return false
	return true


static func export_json(enabled: bool, values: Dictionary) -> String:
	return JSON.stringify({
		"schema": SCHEMA_VERSION,
		"developer_mode": enabled,
		"values": sanitize_values(values),
	}, "  ", false)


static func import_json(json_text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(json_text)
	if not parsed is Dictionary:
		return {}
	var payload: Dictionary = parsed
	if not payload.has("values") or not payload["values"] is Dictionary:
		return {}
	return {
		"enabled": bool(payload.get("developer_mode", true)),
		"values": sanitize_values(payload["values"]),
	}
