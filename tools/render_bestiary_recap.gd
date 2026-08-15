extends SceneTree

const UIScript = preload("res://scripts/game_ui.gd")
const Catalog = preload("res://scripts/species_catalog.gd")


class PreviewGame:
	extends Node
	var state := "menu"
	var level_elapsed := 318.0

	func play_ui_sound() -> void: pass
	func has_campaign_progress() -> bool: return true
	func menu_start_text() -> String: return "继续轮回"
	func bestiary_progress_text() -> String: return "生态图鉴　发现 8 / 30"
	func get_recent_runs() -> Array[Dictionary]:
		return [{"species_id": "rabbit", "level": 4, "won": false, "survival": 318.0, "player_level": 4, "kills": 2}]
	func get_bestiary_entries() -> Array[Dictionary]:
		var discovered := ["rabbit", "fox", "deer", "wolf", "snake", "bear", "eagle", "crocodile"]
		var entries: Array[Dictionary] = []
		for species_id in Catalog.ORDER:
			if species_id not in discovered:
				entries.append({"discovered": false, "list_text": "？？？　·　第 %d 关起可能出现" % Catalog.unlock_level(species_id), "detail": "继续探索更高关卡，在生态世界中遇见它即可记录。\n\n图鉴只解锁知识与战绩，不会永久增加任何属性。"})
				continue
			var data := Catalog.get_data(species_id)
			entries.append({
				"discovered": true,
				"list_text": "%s　·　%s　·　战斗阶位 %d" % [data["name"], "植食" if data["diet"] == "herbivore" else ("肉食" if data["diet"] == "carnivore" else "杂食"), Catalog.combat_tier(species_id)],
				"detail": "%s · %s\n植食　体型 %d　生命 %d　攻击 %.1f　速度 %.2f\n\n%s\n%s\n偏爱食物：%s\n反制组合：%s\n\n战斗被动：%s — %s\n主动技能：%s — %s\n\n获胜攻略：%s\n\n个人记录\n出战 3　获胜 1　最高挑战第 4 关\n最佳存活 05:18　最高 Lv.4　单局最多击杀 2" % [
					data["name"], data["subtitle"], data["size"], data["health"], data["attack"], data["speed"], Catalog.habitat_description(species_id), Catalog.habit_description(species_id), Catalog.habit_foods_display_text(species_id), Catalog.counterplay_plan(species_id), data["passive"], data["passive_hint"], data["skill"], data["skill_hint"], Catalog.victory_guide(species_id),
				],
			})
		return entries


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var game := PreviewGame.new()
	root.add_child(game)
	var ui: GameUI = UIScript.new()
	root.add_child(ui)
	ui.setup(game)
	for _frame in range(5):
		await process_frame
	ui.show_bestiary()
	for _frame in range(5):
		await process_frame
	var bestiary_result := root.get_texture().get_image().save_png("res://docs/images/v43-ecology-bestiary.png")
	ui.show_result("本次生命结束", "草原雄狮结束了你的这次生命\n\n物种：雪兔　关卡：4　存活：05:18　成长：Lv.4（37 经验）\n击杀：2　生态助攻：3　战术行动：5　进食：8\n伤害：造成 286 / 承受 194　冲刺：01:26\n生态热点：抵达 2 / 出现 4　猎手峰值：3\n生态踪迹：追踪 1　危险绕行 4\n世界威胁升至：3\n\n复盘建议：面对草原雄狮不要正面对耗。诱导追兵耗尽耐力，借草丛脱战后再引向第三方。\n新发现：草原雄狮、岩岭山羊（已写入生态图鉴）\n最后 10 秒：战斗 雄狮开始追击你；生存 饱腹低于 10；击杀 雄狮结束了这次生命\n\n旧世界已经终结。下一次，你会成为另一种生命。")
	for _frame in range(5):
		await process_frame
	var recap_result := root.get_texture().get_image().save_png("res://docs/images/v43-run-recap.png")
	if bestiary_result == OK and recap_result == OK:
		print("BESTIARY_RECAP_PREVIEW_OK")
		quit(0)
	else:
		push_error("图鉴与局后复盘预览生成失败")
		quit(1)
