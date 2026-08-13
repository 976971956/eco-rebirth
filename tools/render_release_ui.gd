extends SceneTree

const UIScript = preload("res://scripts/game_ui.gd")
const ActorScript = preload("res://scripts/eco_actor.gd")
const Catalog = preload("res://scripts/species_catalog.gd")


class PreviewGame:
	extends Node
	var quality := "medium"
	var state := "playing"
	var level_elapsed := 0.0
	var world_seed := 11818
	var current_level := 2
	var world: Node
	func get_living_actors() -> Array[EcoActor]: return []
	func play_ui_sound() -> void: pass
	func is_music_enabled() -> bool: return true
	func is_sfx_enabled() -> bool: return true
	func set_music_enabled(_value: bool) -> void: pass
	func set_sfx_enabled(_value: bool) -> void: pass
	func get_quality_preset() -> String: return quality
	func set_quality_preset(value: String) -> void: quality = value
	func has_campaign_progress() -> bool: return true
	func menu_start_text() -> String: return "继续轮回"
	func get_selected_free_level() -> int: return 7
	func get_selected_free_species() -> String: return "cheetah"
	func set_selected_free_level(_value: int) -> void: pass
	func set_selected_free_species(_value: String) -> void: pass
	func reset_tutorial_progress() -> void: pass


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var background_layer := CanvasLayer.new()
	root.add_child(background_layer)
	var background := TextureRect.new()
	background.texture = load("res://assets/ui/menu_background.jpg")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_layer.add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.045, 0.04, 0.48)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_layer.add_child(shade)

	var game := PreviewGame.new()
	root.add_child(game)
	var ui: GameUI = UIScript.new()
	root.add_child(ui)
	ui.setup(game)
	for _frame in range(5):
		await process_frame
	var home_result := root.get_texture().get_image().save_png("res://docs/images/v14-home.png")
	ui.show_free_mode()
	for _frame in range(5):
		await process_frame
	var free_mode_result := root.get_texture().get_image().save_png("res://docs/images/v14-free-mode.png")
	ui.modal_root.hide()
	var preview_actor: EcoActor = ActorScript.new()
	preview_actor.process_mode = Node.PROCESS_MODE_DISABLED
	game.add_child(preview_actor)
	preview_actor.setup(game, 1, "wolf", true, Vector3.ZERO, 0)
	preview_actor.gain_experience(79, "bear")
	preview_actor.health = 132.0
	preview_actor.stamina = 76.0
	preview_actor.hunger = 32.0
	ui.show_hud(preview_actor, game.world_seed, 1, 2, false)
	ui.update_hud(preview_actor, 16, 20, "古木林地 · 白昼 · 晴朗", "生态热点 · 下一次信号 26s", "迁徙监测 · 尚无活动", "生态踪迹 · 暂无线索")
	ui.touch_root.show()
	ui.intro_panel.hide()
	ui.seed_label.text = "世界种子 11337"
	ui.skill_label.text = "扑咬　就绪"
	ui.skill_hint_label.text = "扑向猎物并造成短暂减速"
	ui.update_leaderboard([
		{"rank": 1, "name": "金雕", "level": 4, "experience": 21, "kills": 5, "is_player": false},
		{"rank": 2, "name": "山林猛虎", "level": 3, "experience": 62, "kills": 4, "is_player": false},
		{"rank": 3, "name": "狼", "level": 2, "experience": 34, "kills": 2, "is_player": true},
		{"rank": 4, "name": "棕熊", "level": 2, "experience": 18, "kills": 1, "is_player": false},
		{"rank": 5, "name": "赤狐", "level": 1, "experience": 31, "kills": 2, "is_player": false},
		{"rank": 6, "name": "野猪", "level": 1, "experience": 12, "kills": 1, "is_player": false},
	])
	game.level_elapsed = 22.0
	ui.add_battle_report("山林猛虎击倒了马鹿 · 累计3击杀 · 剩余18", "击杀", "#ecc89d")
	game.level_elapsed = 49.0
	ui.add_battle_report("你·狼升至 Lv.2 · 群猎进化", "成长", "#f1d46b")
	game.level_elapsed = 73.0
	ui.add_battle_report("赤狐对野猪形成生态助攻，获得18经验", "助攻", "#f0cf78")
	game.level_elapsed = 96.0
	ui.add_battle_report("金雕击倒了雪兔 · 累计5击杀 · 剩余16", "击杀", "#ecc89d")
	for _frame in range(5):
		await process_frame
	var gameplay_image := root.get_texture().get_image()
	var leaderboard_result := gameplay_image.save_png("res://docs/images/v15-leaderboard-ticker.png")
	var mobile_safe_result := gameplay_image.save_png("res://docs/images/v26-adaptive-mobile-ui.png")
	preview_actor.habit_buff_name = "群猎分食"
	preview_actor.habit_buff_kind = "hunt"
	preview_actor.habit_buff_timer = 4.2
	ui.update_hud(preview_actor, 16, 20, "古木林地 · 白昼 · 晴朗", "生态热点 · 下一次信号 26s", "迁徙监测 · 尚无活动", "生态踪迹 · 暂无线索")
	for _frame in range(5):
		await process_frame
	var habit_hud_result := root.get_texture().get_image().save_png("res://docs/images/v28-ecological-habit-hud.png")
	ui.battle_ticker_button.hide()
	ui.enemy_name_label.text = "Lv.2 非洲巨象"
	ui.combat_stats_label.text = "攻 24.7　速 6.41　甲 9.2　恢复 16.4\n伏击就绪 · 首击可逆袭强敌"
	ui.combat_stats_label.add_theme_color_override("font_color", Color("#8fe8b7"))
	ui.enemy_status_label.text = "伏击可逆袭 · 状态稳定"
	ui.enemy_name_label.add_theme_color_override("font_color", Color("#8fe8b7"))
	ui.enemy_status_label.add_theme_color_override("font_color", Color("#8fe8b7"))
	ui.enemy_hp_bar.max_value = 540.0
	ui.enemy_hp_bar.value = 540.0
	ui.enemy_hp_value_label.text = "540 / 540"
	ui.enemy_hp_bar.add_theme_stylebox_override("fill", ui._bar_style(Color("#62c99d")))
	ui.enemy_panel.add_theme_stylebox_override("panel", ui._panel_style(Color(0.025, 0.14, 0.10, 0.76), 14, Color("#8fe8b7"), 2))
	ui.enemy_panel.show()
	ui.show_hint("草丛伏击就绪：步行离开掩体后用首次普通攻击命中强敌")
	for _frame in range(5):
		await process_frame
	var cover_ambush_result := root.get_texture().get_image().save_png("res://docs/images/v19-cover-ambush.png")
	ui.species_label.text = "Lv.2 岩岭山羊 · 高地迁徙者"
	ui.region_label.text = "当前位置 · 岩丘高地 · 白昼 · 晴朗 · 主场适应"
	ui.combat_stats_label.text = "攻 23.3　速 6.13　甲 10.1　恢复 18.5\n岩径反制就绪 · 可反制客场强敌"
	ui.combat_stats_label.add_theme_color_override("font_color", Color("#70cfe8"))
	ui.enemy_name_label.text = "Lv.2 草原雄狮"
	ui.enemy_status_label.text = "地形可逆袭 · 状态稳定"
	ui.enemy_name_label.add_theme_color_override("font_color", Color("#70cfe8"))
	ui.enemy_status_label.add_theme_color_override("font_color", Color("#70cfe8"))
	ui.enemy_hp_bar.max_value = 285.0
	ui.enemy_hp_bar.value = 285.0
	ui.enemy_hp_value_label.text = "285 / 285"
	ui.enemy_hp_bar.add_theme_stylebox_override("fill", ui._bar_style(Color("#58bcd8")))
	ui.enemy_panel.add_theme_stylebox_override("panel", ui._panel_style(Color(0.025, 0.11, 0.15, 0.78), 14, Color("#70cfe8"), 2))
	ui.enemy_panel.show()
	ui.show_hint("岩径反制就绪：把客场强敌留在高地，用普通攻击发动逆袭")
	for _frame in range(5):
		await process_frame
	var terrain_counter_result := root.get_texture().get_image().save_png("res://docs/images/v20-terrain-counter.png")
	ui.species_label.text = "Lv.2 雪兔 · 灵巧逃生者"
	ui.region_label.text = "当前位置 · 开阔草原 · 白昼 · 晴朗 · 熟悉地形"
	ui.combat_stats_label.text = "攻 7.4　速 7.79　甲 0.8　恢复 20.5\n生态借力就绪 · 引向披甲犀牛"
	ui.combat_stats_label.add_theme_color_override("font_color", Color("#d7a2f2"))
	ui.enemy_name_label.text = "Lv.2 非洲巨象"
	ui.enemy_status_label.text = "可生态借力 · 引向披甲犀牛"
	ui.enemy_name_label.add_theme_color_override("font_color", Color("#d7a2f2"))
	ui.enemy_status_label.add_theme_color_override("font_color", Color("#d7a2f2"))
	ui.enemy_hp_bar.max_value = 540.0
	ui.enemy_hp_bar.value = 506.0
	ui.enemy_hp_value_label.text = "506 / 540"
	ui.enemy_hp_bar.add_theme_stylebox_override("fill", ui._bar_style(Color("#b77bd6")))
	ui.enemy_panel.add_theme_stylebox_override("panel", ui._panel_style(Color(0.12, 0.055, 0.16, 0.78), 14, Color("#d7a2f2"), 2))
	ui.enemy_panel.show()
	ui.show_hint("生态借力就绪：把巨象引向披甲犀牛，诱使它们互相消耗")
	for _frame in range(5):
		await process_frame
	var ecology_leverage_result := root.get_texture().get_image().save_png("res://docs/images/v21-ecology-leverage.png")
	ui.combat_stats_label.text = "攻 7.4　速 7.79　甲 0.8　恢复 20.5\n生态掌控 · 生命与耐力已恢复"
	ui.combat_stats_label.add_theme_color_override("font_color", Color("#ffb86b"))
	ui.enemy_status_label.text = "战术连携 2/2 · 已掌控"
	ui.enemy_name_label.add_theme_color_override("font_color", Color("#ffb86b"))
	ui.enemy_status_label.add_theme_color_override("font_color", Color("#ffcf8c"))
	ui.enemy_hp_bar.value = 462.0
	ui.enemy_hp_value_label.text = "462 / 540"
	ui.enemy_hp_bar.add_theme_stylebox_override("fill", ui._bar_style(Color("#e79a55")))
	ui.enemy_panel.add_theme_stylebox_override("panel", ui._panel_style(Color(0.15, 0.075, 0.025, 0.78), 14, Color("#ffb86b"), 2))
	ui.show_hint("生态掌控！草丛伏击 + 生态借力完成连携，恢复 4 生命 / 23 耐力")
	for _frame in range(5):
		await process_frame
	var counterplay_mastery_result := root.get_texture().get_image().save_png("res://docs/images/v22-counterplay-mastery.png")
	ui.species_label.text = "Lv.2 狼 · 群猎者"
	ui.region_label.text = "当前位置 · 古木林地 · 白昼 · 晴朗"
	ui.combat_stats_label.text = "攻 24.7　速 6.41　甲 9.2　恢复 16.4"
	ui.combat_stats_label.add_theme_color_override("font_color", Color("#b9d9bd"))
	ui.ecology_event_label.text = "生态热点 · 落果潮 · 西北 38m · 41s"
	ui.enemy_panel.hide()
	ui.battle_ticker_button.show()
	ui.battle_ticker_button.text = "战报 [展开] · 落果潮正在吸引附近动物"
	ui.show_hint("落果潮 · 古木林地：成熟果实集中坠落，附近动物开始迁徙")
	for _frame in range(5):
		await process_frame
	var ecology_hotspot_result := root.get_texture().get_image().save_png("res://docs/images/v23-ecology-hotspot.png")
	ui.ecology_activity_label.text = "迁徙 6 · 猎手 2 · 风险：高危"
	ui.ecology_activity_label.add_theme_color_override("font_color", Color("#ef7d68"))
	ui.battle_ticker_button.text = "战报 [展开] · 2名猎手正在落果潮外围追踪猎物"
	ui.show_hint("落果潮已成高危围猎区：绕行、等待混战，或寻找其他食物")
	for _frame in range(5):
		await process_frame
	var food_chain_migration_result := root.get_texture().get_image().save_png("res://docs/images/v24-food-chain-migration.png")
	ui.ecology_activity_label.text = "迁徙 4 · 猎手 1 · 风险：警戒"
	ui.ecology_activity_label.add_theme_color_override("font_color", Color("#f0b46f"))
	ui.ecology_trace_label.text = "追踪线索 · 林鹿血迹 东北 18m · 5s前"
	ui.ecology_trace_label.add_theme_color_override("font_color", Color("#d5b27a"))
	ui.battle_ticker_button.text = "战报 [展开] · 灰狼只获得过去位置，正在调查林鹿血迹"
	ui.show_hint("发现5秒前的林鹿血迹：沿线调查，草丛中的目标仍需重新感知")
	for _frame in range(5):
		await process_frame
	var ecology_traces_result := root.get_texture().get_image().save_png("res://docs/images/v25-ecology-traces.png")
	ui.species_label.text = "Lv.2 狼 · 群猎者"
	ui.region_label.text = "当前位置 · 古木林地 · 白昼 · 晴朗"
	ui.enemy_name_label.text = "Lv.2 非洲巨象"
	ui.combat_stats_label.text = "攻 24.7　速 6.41　甲 9.2　恢复 16.4"
	ui.combat_stats_label.add_theme_color_override("font_color", Color("#b9d9bd"))
	ui.enemy_status_label.text = "可逆袭 · 力竭破绽"
	ui.enemy_name_label.add_theme_color_override("font_color", Color("#ffe078"))
	ui.enemy_status_label.add_theme_color_override("font_color", Color("#ffe078"))
	ui.enemy_hp_bar.max_value = 540.0
	ui.enemy_hp_bar.value = 318.0
	ui.enemy_hp_value_label.text = "318 / 540"
	ui.enemy_hp_bar.add_theme_stylebox_override("fill", ui._bar_style(Color("#e8b93f")))
	ui.enemy_panel.add_theme_stylebox_override("panel", ui._panel_style(Color(0.14, 0.10, 0.025, 0.76), 14, Color(1.0, 0.80, 0.24, 0.86), 2))
	ui.enemy_panel.show()
	ui.hint_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	for _frame in range(5):
		await process_frame
	var opportunity_result := root.get_texture().get_image().save_png("res://docs/images/v18-opportunity-strike.png")
	ui.enemy_panel.hide()
	ui.battle_ticker_button.show()
	ui.show_battle_report()
	for _frame in range(5):
		await process_frame
	var battle_report_result := root.get_texture().get_image().save_png("res://docs/images/v15-battle-report.png")
	ui.hide_battle_report()
	ui.show_tutorial_step(2, 5, "学会控制耐力", "移动时按住右侧“冲刺”。冲刺、攻击和技能都会消耗耐力。")
	for _frame in range(5):
		await process_frame
	var tutorial_result := root.get_texture().get_image().save_png("res://docs/images/v12-release-tutorial.png")
	ui.hide_tutorial()
	preview_actor.species_id = "rabbit"
	preview_actor.data = Catalog.get_data("rabbit")
	preview_actor.level = 1
	preview_actor.max_health = float(preview_actor.data["health"])
	preview_actor.health = preview_actor.max_health
	preview_actor.max_stamina = float(preview_actor.data["stamina"])
	preview_actor.stamina = preview_actor.max_stamina
	preview_actor.hunger = 18.0
	preview_actor.experience = 12
	preview_actor.habit_buff_timer = 0.0
	preview_actor.habit_buff_kind = ""
	preview_actor.habit_buff_name = ""
	ui.update_hud(preview_actor, 16, 20, "古木林地 · 白昼 · 晴朗", "生态热点 · 下一次信号 26s", "迁徙监测 · 尚无活动", "生态踪迹 · 暂无线索")
	ui.show_species_intro("rabbit")
	for _frame in range(5):
		await process_frame
	var guide_result := root.get_texture().get_image().save_png("res://docs/images/v28-species-habit-guide.png")
	ui.intro_panel.hide()
	preview_actor.health = 31.0
	preview_actor.stamina = 34.0
	preview_actor.hunger = 68.0
	ui.update_hud(preview_actor, 16, 20, "古木林地 · 白昼 · 晴朗", "生态热点 · 下一次信号 26s", "迁徙监测 · 尚无活动", "生态本能 · 嫩草 东北 18m · 完美习性")
	for _frame in range(5):
		await process_frame
	var instinct_result := root.get_texture().get_image().save_png("res://docs/images/v29-ecological-instinct.png")
	ui.show_settings(false)
	for _frame in range(5):
		await process_frame
	var settings_result := root.get_texture().get_image().save_png("res://docs/images/v14-settings.png")
	if home_result == OK and free_mode_result == OK and leaderboard_result == OK and mobile_safe_result == OK and habit_hud_result == OK and cover_ambush_result == OK and terrain_counter_result == OK and ecology_leverage_result == OK and counterplay_mastery_result == OK and ecology_hotspot_result == OK and food_chain_migration_result == OK and ecology_traces_result == OK and opportunity_result == OK and battle_report_result == OK and tutorial_result == OK and guide_result == OK and instinct_result == OK and settings_result == OK:
		print("RELEASE_UI_PREVIEW_OK")
		quit(0)
	else:
		push_error("发布界面预览生成失败")
		quit(1)
