extends SceneTree

const MainScript = preload("res://scripts/main.gd")
const WorldScript = preload("res://scripts/eco_world.gd")
const AudioScript = preload("res://scripts/audio_manager.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")
const UIScript = preload("res://scripts/game_ui.gd")
const Catalog = preload("res://scripts/species_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
	_validate_save_migration()
	_validate_quality_presets()
	_validate_tutorial_contract()
	_validate_free_mode_contract()
	_validate_leaderboard_contract()
	_validate_world_transition_contract()
	_validate_death_lifecycle_contract()
	_validate_web_audio_contract()
	_validate_visual_kit_contract()
	_validate_adaptive_ui_contract()
	_validate_opportunity_contract()
	_validate_cover_ambush_contract()
	_validate_terrain_counter_contract()
	if failures.is_empty():
		print("[release] V1.8 发布校验通过：主场反制、AI 环境选路、草丛伏击、生态逆袭、移动安全区与三端规则正常")
		quit(0)
	else:
		for failure in failures:
			push_error("[release] %s" % failure)
		quit(1)


func _validate_save_migration() -> void:
	var test_path := "/tmp/eco_rebirth_release_validation.cfg"
	var legacy := ConfigFile.new()
	legacy.set_value("campaign", "threat_level", 99)
	legacy.set_value("campaign", "total_deaths", -4)
	legacy.set_value("campaign", "last_species", "missing_species")
	legacy.set_value("campaign", "current_level", 99)
	legacy.set_value("audio", "music_enabled", false)
	legacy.set_value("gameplay", "all_levels_unlocked", true)
	legacy.set_value("gameplay", "selected_free_level", 7)
	if legacy.save(test_path) != OK:
		failures.append("无法创建临时旧存档")
		return
	var main := MainScript.new()
	main._load_progress(test_path)
	_expect(main.threat_level == 8, "旧存档威胁值未限制到 0–8")
	_expect(main.total_deaths == 0, "旧存档负死亡数未修正")
	_expect(main.current_level == 10, "旧存档关卡未限制到 1–10")
	_expect(main.last_player_species == "", "旧存档无效物种未清理")
	_expect(main.quality_preset == "medium", "旧存档未获得安全画质默认值")
	_expect(not main.tutorial_completed, "旧存档应默认显示新手教学")
	var migrated := ConfigFile.new()
	_expect(migrated.load(test_path) == OK, "迁移后存档无法重新读取")
	_expect(int(migrated.get_value("meta", "save_version", 0)) == MainScript.SAVE_VERSION, "迁移后未写入存档版本")
	_expect(not bool(migrated.get_value("audio", "music_enabled", true)), "迁移覆盖了原有声音设置")
	_expect(not migrated.has_section_key("gameplay", "all_levels_unlocked"), "已移除的自由选关开关仍留在存档中")
	main.campaign_level = 6
	main.current_level = 6
	main.last_completed_level = 5
	main.quality_preset = "high"
	main.tutorial_completed = true
	main.selected_free_level = 9
	main.selected_free_species = "eagle"
	main._save_progress(test_path)
	var reload := MainScript.new()
	reload._load_progress(test_path)
	_expect(reload.campaign_level == 6 and reload.last_completed_level == 5, "新存档关卡进度无法回读")
	_expect(reload.selected_free_level == 9 and reload.selected_free_species == "eagle", "自由模式选择无法回读")
	_expect(reload.current_level == 6, "自由模式选择不应覆盖战役关卡")
	_expect(reload.quality_preset == "high", "画质档位无法回读")
	_expect(reload.tutorial_completed, "教学完成状态无法回读")
	DirAccess.remove_absolute(test_path)
	main.free()
	reload.free()


func _validate_quality_presets() -> void:
	var world := WorldScript.new()
	world.world_size = 160.0
	world.weather_id = "storm"
	world.sun_light = DirectionalLight3D.new()
	world.precipitation = GPUParticles3D.new()
	world.apply_quality_preset("low")
	_expect(not world.sun_light.shadow_enabled, "性能画质未关闭主阴影")
	_expect(world.precipitation.amount == 150, "性能画质雨幕数量不正确")
	world.apply_quality_preset("high")
	_expect(world.sun_light.shadow_enabled, "高画质未开启主阴影")
	_expect(world.precipitation.amount == 440, "高画质雨幕数量不正确")
	world.sun_light.free()
	world.precipitation.free()
	world.free()


func _validate_tutorial_contract() -> void:
	_expect(MainScript.TUTORIAL_STEPS.size() == 5, "新手教学应包含 5 个步骤")
	var expected := ["move", "sprint", "attack", "skill", "eat"]
	for index in range(expected.size()):
		_expect(str(MainScript.TUTORIAL_STEPS[index]["id"]) == expected[index], "新手教学步骤顺序错误")


func _validate_free_mode_contract() -> void:
	var main := MainScript.new()
	main.rng.seed = 1207
	main.run_uses_free_mode = true
	main.selected_free_species = "eagle"
	main.last_player_species = "wolf"
	var roster: Array[String] = ["rabbit", "fox", "deer"]
	var player_index := main._select_player_roster_index(roster)
	_expect(player_index >= 0 and roster[player_index] == "eagle", "自由模式没有生成玩家指定的物种")
	_expect(main.last_player_species == "wolf", "自由模式污染了战役随机物种记录")
	main.campaign_level = 4
	main.selected_free_level = 10
	_expect(main.menu_start_text() == "继续轮回", "首页战役按钮被自由模式选择覆盖")
	main.free()


func _validate_leaderboard_contract() -> void:
	var entries: Array[Dictionary] = [
		{"actor_id": 1, "level": 2, "experience": 99, "kills": 9, "health_ratio": 1.0, "is_player": false},
		{"actor_id": 2, "level": 3, "experience": 50, "kills": 0, "health_ratio": 0.2, "is_player": false},
		{"actor_id": 3, "level": 3, "experience": 40, "kills": 3, "health_ratio": 0.2, "is_player": false},
		{"actor_id": 4, "level": 3, "experience": 40, "kills": 2, "health_ratio": 0.9, "is_player": false},
		{"actor_id": 5, "level": 3, "experience": 40, "kills": 2, "health_ratio": 0.8, "is_player": true},
		{"actor_id": 8, "level": 3, "experience": 40, "kills": 2, "health_ratio": 0.8, "is_player": false},
		{"actor_id": 6, "level": 4, "experience": 0, "kills": 0, "health_ratio": 0.1, "is_player": false},
	]
	var ranked := MainScript.rank_level_entries(entries)
	var expected_ids := [6, 2, 3, 4, 5, 8, 1]
	_expect(ranked.size() == expected_ids.size(), "等级排行丢失了存活个体")
	for index in range(mini(ranked.size(), expected_ids.size())):
		_expect(int(ranked[index].get("actor_id", -1)) == expected_ids[index], "等级榜未按等级、经验、击杀、生命和稳定 ID 排序")
		_expect(int(ranked[index].get("rank", 0)) == index + 1, "等级榜名次不连续")
	_expect(bool(ranked[4].get("is_player", false)), "玩家当前名次未保留")


func _validate_world_transition_contract() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(main_source.contains("_start_new_world.call_deferred(free_mode)"), "按钮触发的轮回切场没有脱离输入回调")
	_expect(main_source.contains("game_root.queue_free()"), "旧世界必须延迟销毁，避免 Web 输入回调访问已释放对象")
	_expect(not main_source.contains("game_root.free()"), "旧世界仍在使用会破坏 Web 回调的同步销毁")


func _validate_death_lifecycle_contract() -> void:
	var actor_source := FileAccess.get_file_as_string("res://scripts/eco_actor.gd")
	var die_start := actor_source.find("func die(killer: EcoActor) -> void:")
	var next_method := actor_source.find("\nfunc ", die_start + 1)
	var die_source := actor_source.substr(die_start, next_method - die_start)
	_expect(die_start >= 0 and next_method > die_start, "无法读取动物死亡生命周期")
	_expect(not die_source.contains("await "), "动物死亡仍会留下跨结算暂停的等待协程")
	_expect(die_source.contains("tween.tween_callback"), "动物死亡动画结束后没有安排安全销毁")


func _validate_web_audio_contract() -> void:
	var audio := AudioScript.new()
	audio._build_music_player()
	audio._build_effects()
	_expect(audio.music_player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "Web 背景音乐必须使用流式播放")
	_expect(audio.effects.has("level_up"), "升级提示音没有生成")
	var menu_frame := audio._music_frame(3.2)
	audio.set_context("game")
	audio.game_intensity = 0.8
	var game_frame := audio._music_frame(3.2)
	_expect(menu_frame.length() > 0.0001 and game_frame.length() > 0.0001 and menu_frame != game_frame, "动态背景音乐没有随场景变化")
	var peak := 0.0
	var all_finite := true
	for sample_index in range(int(AudioScript.MIX_RATE)):
		var frame := audio._music_frame(float(sample_index) / AudioScript.MIX_RATE)
		all_finite = all_finite and is_finite(frame.x) and is_finite(frame.y)
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	_expect(all_finite, "背景音乐生成了非法采样")
	_expect(peak > 0.01 and peak <= 0.82, "背景音乐音量范围异常")
	audio.free()


func _validate_visual_kit_contract() -> void:
	var texture_paths := [
		"res://assets/textures/terrain/forest_floor_ai.jpg",
		"res://assets/textures/terrain/grassland_ai.jpg",
		"res://assets/textures/terrain/wetland_ai.jpg",
		"res://assets/textures/terrain/highland_ai.jpg",
	]
	for texture_path in texture_paths:
		_expect(ResourceLoader.exists(texture_path), "V2 地表材质缺失：%s" % texture_path)
	var forest_texture := load(texture_paths[0]) as Texture2D
	_expect(forest_texture != null, "森林 AI 地表材质无法加载")
	var terrain := Factory.terrain_material(Color("#244833"), Color("#3b603d"), 12.0, forest_texture, 5.0, 0.24)
	_expect(terrain.shader != null, "V2 地表着色器没有创建")
	_expect(is_equal_approx(float(terrain.get_shader_parameter("texture_strength")), 0.24), "AI 地表混合强度没有传入着色器")
	var faceted := Factory.sphere("VisualContract", Color("#a86f43"), Vector3.ONE, Vector3.ZERO, 8, 5)
	_expect(faceted.mesh is ArrayMesh, "V2 物种基础体没有使用逐面程序网格")
	if faceted.mesh is ArrayMesh:
		var arrays := (faceted.mesh as ArrayMesh).surface_get_arrays(0)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		_expect(not colors.is_empty(), "V2 物种程序网格缺少逐面颜色")
	faceted.free()


func _validate_adaptive_ui_contract() -> void:
	var hud_backgrounds := [
		UIScript.HUD_STATUS_BACKGROUND, UIScript.HUD_INFO_BACKGROUND,
		UIScript.HUD_LEADERBOARD_BACKGROUND, UIScript.HUD_SKILL_BACKGROUND,
		UIScript.HUD_TICKER_BACKGROUND, UIScript.HUD_ENEMY_BACKGROUND,
	]
	for background_color in hud_backgrounds:
		_expect(background_color.a >= 0.50 and background_color.a <= 0.72, "HUD 状态面板透明度超出清晰且不挡视线的范围")
	var margins := UIScript.safe_margins_from_rect(Vector2(1280, 720), Vector2i(2532, 1170), Rect2i(177, 0, 2178, 1116))
	_expect(margins.x > 89.0 and margins.x < 90.0, "iOS 左侧安全区没有正确换算到逻辑坐标")
	_expect(margins.z > 89.0 and margins.z < 90.0, "iOS 右侧安全区没有正确换算到逻辑坐标")
	_expect(margins.w > 33.0 and margins.w < 34.0, "iOS 底部安全区没有正确换算到逻辑坐标")
	_expect(UIScript.portrait_layout_needed(Vector2(390, 844), true), "手机竖屏没有触发旋转守卫")
	_expect(not UIScript.portrait_layout_needed(Vector2(844, 390), true), "手机横屏被错误拦截")
	_expect(not UIScript.portrait_layout_needed(Vector2(390, 844), false), "桌面窗口不应触发手机旋转守卫")
	var safe_viewport := Vector2(1220, 690)
	var touch_rects := [
		UIScript.touch_rect(safe_viewport, UIScript.TOUCH_ATTACK_OFFSET, UIScript.TOUCH_ATTACK_SIZE),
		UIScript.touch_rect(safe_viewport, UIScript.TOUCH_SKILL_OFFSET, UIScript.TOUCH_SKILL_SIZE),
		UIScript.touch_rect(safe_viewport, UIScript.TOUCH_EAT_OFFSET, UIScript.TOUCH_EAT_SIZE),
		UIScript.touch_rect(safe_viewport, UIScript.TOUCH_SPRINT_OFFSET, UIScript.TOUCH_SPRINT_SIZE),
	]
	for first_index in range(touch_rects.size()):
		_expect(Rect2(Vector2.ZERO, safe_viewport).encloses(touch_rects[first_index]), "触控按钮超出安全 HUD 区域")
		for second_index in range(first_index + 1, touch_rects.size()):
			_expect(not touch_rects[first_index].intersects(touch_rects[second_index]), "右侧触控按钮彼此重叠")
	var skill_panel_rect := Rect2(Vector2((safe_viewport.x - 340.0) * 0.5, safe_viewport.y - 118.0), Vector2(340, 100))
	var intro_rect := Rect2(Vector2(safe_viewport.x * 0.5 - 400.0, 40.0), Vector2(640, 410))
	for touch_button_rect in touch_rects:
		_expect(not skill_panel_rect.intersects(touch_button_rect), "触控按钮仍遮挡技能状态栏")
		_expect(not intro_rect.intersects(touch_button_rect), "物种攻略仍遮挡触控按钮")
	var ui_source := FileAccess.get_file_as_string("res://scripts/game_ui.gd")
	_expect(ui_source.contains("DisplayServer.get_display_safe_area()"), "移动 HUD 没有读取系统安全显示区域")
	_expect(ui_source.contains("orientation_blocked_changed"), "竖屏守卫没有通知主流程暂停世界")


func _validate_opportunity_contract() -> void:
	_expect(Catalog.opportunity_threat_gap("rabbit", "elephant") == 4, "生态逆袭没有识别雪兔与巨象的威胁差")
	_expect(is_equal_approx(Catalog.opportunity_health_ratio(4), 0.06), "最高逆袭额外伤害不是目标最大生命 6%")
	var actor_source := FileAccess.get_file_as_string("res://scripts/eco_actor.gd")
	_expect(actor_source.contains("OPPORTUNITY_ARMOR_FACTOR := 0.50"), "逆袭没有实现 50% 有效护甲")
	_expect(actor_source.contains("EXHAUSTION_ENTER_RATIO := 0.10"), "力竭进入阈值不是 10%")
	_expect(actor_source.contains("EXHAUSTION_EXIT_RATIO := 0.25"), "力竭解除阈值不是 25%")
	_expect(actor_source.contains("not _collapse_competition_active()"), "最终争夺圈没有停止无限绕行")
	var ui_source := FileAccess.get_file_as_string("res://scripts/game_ui.gd")
	_expect(ui_source.contains("可逆袭"), "敌方血条没有可逆袭提示")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(main_source.contains("func on_opportunity_strike"), "主流程没有接收逆袭命中反馈")


func _validate_cover_ambush_contract() -> void:
	var world := WorldScript.new()
	world.cover_positions.append(Vector3.ZERO)
	world.cover_radii.append(2.0)
	_expect(world.cover_strength_at(Vector3(0.0, 0.45, 0.0), "rabbit") >= 0.9, "小型物种没有获得草丛掩护")
	_expect(world.cover_strength_at(Vector3(0.0, 0.45, 0.0), "elephant") == 0.0, "巨型物种不应获得草丛隐蔽")
	world.free()
	var actor_source := FileAccess.get_file_as_string("res://scripts/eco_actor.gd")
	_expect(actor_source.contains("ai_state = \"search\""), "AI 丢失草丛目标后没有搜索最后位置")
	_expect(actor_source.contains("ambush_attack_armed"), "草丛首击没有连接逆袭结算")
	var ui_source := FileAccess.get_file_as_string("res://scripts/game_ui.gd")
	_expect(ui_source.contains("伏击就绪") and ui_source.contains("伏击可逆袭"), "HUD 没有完整显示草丛伏击状态")


func _validate_terrain_counter_contract() -> void:
	var world := WorldScript.new()
	var highland := Vector3(6.0, 0.45, 6.0)
	_expect(Catalog.habitat_affinity("goat", "highland") >= 0.99, "物种目录没有识别第一主场")
	_expect(world.movement_multiplier("goat", highland) > 1.0, "主场没有提供移动优势")
	_expect(world.stamina_regen_multiplier("goat", highland) > 1.0, "主场没有提供耐力恢复优势")
	_expect(world.terrain_counter_strength("goat", highland, "lion", Vector3(9.0, 0.45, 6.0)) >= WorldScript.TERRAIN_COUNTER_THRESHOLD, "弱势物种无法在主场反制客场强敌")
	_expect(world.terrain_counter_strength("goat", highland, "eagle", Vector3(9.0, 0.45, 6.0)) == 0.0, "共同适应区域错误产生了地形反制")
	world.free()
	var actor_source := FileAccess.get_file_as_string("res://scripts/eco_actor.gd")
	_expect(actor_source.contains("terrain_attack_armed"), "主场蓄势没有连接普通攻击逆袭结算")
	_expect(actor_source.contains("best_counter_habitat"), "AI 逃跑没有寻找可反制追兵的主场")
	_expect(actor_source.contains("can_terrain_counter(nearest_threat)"), "AI 主场蓄势后没有回头反击逻辑")
	var ui_source := FileAccess.get_file_as_string("res://scripts/game_ui.gd")
	_expect(ui_source.contains("地形可逆袭") and ui_source.contains("环境反制"), "HUD 和物种简报没有解释环境反制")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
