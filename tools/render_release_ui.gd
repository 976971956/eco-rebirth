extends SceneTree

const UIScript = preload("res://scripts/game_ui.gd")


class PreviewGame:
	extends Node
	var quality := "medium"
	func play_ui_sound() -> void: pass
	func is_music_enabled() -> bool: return true
	func is_sfx_enabled() -> bool: return true
	func set_music_enabled(_value: bool) -> void: pass
	func set_sfx_enabled(_value: bool) -> void: pass
	func get_quality_preset() -> String: return quality
	func set_quality_preset(value: String) -> void: quality = value
	func has_campaign_progress() -> bool: return true
	func menu_start_text() -> String: return "继续轮回"
	func is_all_levels_unlocked() -> bool: return true
	func get_selected_free_level() -> int: return 7
	func set_all_levels_unlocked(_value: bool) -> void: pass
	func set_selected_free_level(_value: int) -> void: pass
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
	var settings_result := root.get_texture().get_image().save_png("res://docs/images/v13-settings-levels.png")
	if tutorial_result == OK and guide_result == OK and settings_result == OK:
		print("RELEASE_UI_PREVIEW_OK")
		quit(0)
	else:
		push_error("发布界面预览生成失败")
		quit(1)
