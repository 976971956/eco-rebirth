extends SceneTree

const UIScript = preload("res://scripts/game_ui.gd")


class PreviewGame:
	extends Node
	var quality := "medium"
	var state := "playing"
	var level_elapsed := 0.0
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
	ui.menu_root.hide()
	ui.hud_root.show()
	ui.touch_root.show()
	ui.intro_panel.hide()
	ui.species_label.text = "Lv.2 狼 · 群猎者"
	ui.combat_stats_label.text = "攻击 24.7　速度 6.41　护甲 9.2"
	ui.hp_value_label.text = "132 / 150"
	ui.stamina_value_label.text = "76 / 100"
	ui.satiety_value_label.text = "68 / 100"
	ui.xp_value_label.text = "34 / 70"
	ui.remaining_label.text = "存活个体　16 / 20"
	ui.threat_label.text = "第2关 · 世界威胁 1"
	ui.region_label.text = "当前位置 · 古木林地 · 白昼 · 晴朗"
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
	var leaderboard_result := root.get_texture().get_image().save_png("res://docs/images/v15-leaderboard-ticker.png")
	var mobile_safe_result := root.get_texture().get_image().save_png("res://docs/images/v17-mobile-safe-ui.png")
	ui.battle_ticker_button.hide()
	ui.enemy_name_label.text = "Lv.2 非洲巨象"
	ui.combat_stats_label.text = "攻击 24.7　速度 6.41　护甲 9.2\n伏击就绪 · 首击可逆袭强敌"
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
	ui.combat_stats_label.text = "攻击 23.3　速度 6.13　护甲 10.1\n岩径反制就绪 · 可反制客场强敌"
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
	ui.species_label.text = "Lv.2 狼 · 群猎者"
	ui.region_label.text = "当前位置 · 古木林地 · 白昼 · 晴朗"
	ui.enemy_name_label.text = "Lv.2 非洲巨象"
	ui.combat_stats_label.text = "攻击 24.7　速度 6.41　护甲 9.2"
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
	ui.show_species_intro("cheetah")
	for _frame in range(5):
		await process_frame
	var guide_result := root.get_texture().get_image().save_png("res://docs/images/v13-growth-guide.png")
	ui.intro_panel.hide()
	ui.show_settings(false)
	for _frame in range(5):
		await process_frame
	var settings_result := root.get_texture().get_image().save_png("res://docs/images/v14-settings.png")
	if home_result == OK and free_mode_result == OK and leaderboard_result == OK and mobile_safe_result == OK and cover_ambush_result == OK and terrain_counter_result == OK and opportunity_result == OK and battle_report_result == OK and tutorial_result == OK and guide_result == OK and settings_result == OK:
		print("RELEASE_UI_PREVIEW_OK")
		quit(0)
	else:
		push_error("发布界面预览生成失败")
		quit(1)
