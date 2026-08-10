extends SceneTree

const MainScript = preload("res://scripts/main.gd")
const WorldScript = preload("res://scripts/eco_world.gd")
const ActorScript = preload("res://scripts/eco_actor.gd")
const AudioScript = preload("res://scripts/audio_manager.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")
const UIScript = preload("res://scripts/game_ui.gd")
const Catalog = preload("res://scripts/species_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
	_validate_save_migration()
	_validate_quality_presets()
	_validate_spawn_distribution_contract()
	_validate_tutorial_contract()
	_validate_free_mode_contract()
	_validate_leaderboard_contract()
	_validate_world_transition_contract()
	_validate_death_lifecycle_contract()
	_validate_export_contract()
	_validate_web_audio_contract()
	_validate_visual_kit_contract()
	_validate_adaptive_ui_contract()
	_validate_opportunity_contract()
	_validate_cover_ambush_contract()
	_validate_terrain_counter_contract()
	_validate_ecology_leverage_contract()
	_validate_counterplay_mastery_contract()
	_validate_ecology_hotspot_contract()
	_validate_ecology_trace_contract()
	if failures.is_empty():
		print("[release] V1.16 发布校验通过：暂停安全、成长生态、关卡节奏与三端规则正常")
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


func _validate_spawn_distribution_contract() -> void:
	var world := WorldScript.new()
	world.world_size = 470.0
	world.rng.seed = 9137
	var occupied: Array[Vector3] = []
	var regions: Array[String] = ["forest", "grassland", "wetland", "highland"]
	var minimum_observed := INF
	for index in range(100):
		var expected_region := regions[index % regions.size()]
		var position_value := world.random_spawn_in_regions([expected_region], occupied, 8.0)
		if not occupied.is_empty():
			minimum_observed = minf(minimum_observed, WorldScript.minimum_spawn_distance(position_value, occupied))
		_expect(world.region_id_at(position_value) == expected_region, "高密度出生点丢失了物种生态区")
		occupied.append(position_value)
	_expect(minimum_observed >= 7.95, "100 个体生成时出生点过度重叠，可能开局瞬间死亡")
	world.free()


func _validate_tutorial_contract() -> void:
	_expect(MainScript.TUTORIAL_STEPS.size() == 5, "新手教学应包含 5 个步骤")
	var expected := ["move", "sprint", "attack", "skill", "eat"]
	for index in range(expected.size()):
		_expect(str(MainScript.TUTORIAL_STEPS[index]["id"]) == expected[index], "新手教学步骤顺序错误")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(main_source.contains("create_timer(8.75, false)"), "教学延迟仍会在暂停期间流逝并永久跳过")


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
	main.threat_level = 8
	_expect(is_equal_approx(main.get_ai_damage_multiplier(), 1.0), "自由模式仍继承战役威胁伤害")
	main.run_uses_free_mode = false
	_expect(is_equal_approx(main.get_ai_damage_multiplier(), 1.36), "战役威胁伤害倍率失效")
	_expect(float(MainScript.LEVEL_CONFIG[0]["world_size"]) == 140.0 and float(MainScript.LEVEL_CONFIG[9]["world_size"]) == 470.0, "十关地图没有恢复到 GDD 的有效生态尺度")
	_expect(float(MainScript.LEVEL_CONFIG[0]["forced_collapse"]) >= 300.0 and float(MainScript.LEVEL_CONFIG[9]["forced_collapse"]) >= 1200.0, "关卡强制收束早于 GDD 的目标局长")
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
	_expect(not ActorScript.should_queue_free_after_death(true), "玩家死亡动画后被提前释放，结算会丢失物种与战绩")
	_expect(ActorScript.should_queue_free_after_death(false), "AI 死亡动画后没有释放角色节点")
	var stale_actor := ActorScript.new()
	_expect(ActorScript.safe_actor_reference(stale_actor) == stale_actor, "有效动物引用被错误清理")
	stale_actor.free()
	_expect(ActorScript.safe_actor_reference(stale_actor) == null, "已释放动物引用仍被强制转换，可能造成逐帧错误")
	_expect(actor_source.contains("var game_player := _game_player()"), "视觉 LOD 没有使用安全的玩家引用")
	_expect(actor_source.contains("create_timer(warning_time, false)"), "飞行延迟技能仍会在暂停时结算伤害")
	_expect(ActorScript.opening_caution_seconds(1) >= 30.0, "第一关没有留出完整的移动与技能观察时间")
	_expect(ActorScript.opening_caution_seconds(2) > 0.0, "第二关没有从教学节奏平滑过渡")
	_expect(ActorScript.opening_caution_seconds(3) < ActorScript.opening_caution_seconds(2), "中期关卡建立期没有随难度缩短")
	_expect(ActorScript.opening_caution_seconds(10) >= 18.0, "第十关长距离技能仍可在开局首帧击杀动物")
	_expect(ActorScript.opening_caution_seconds(10) < ActorScript.opening_caution_seconds(1), "高压关卡的建立期不应长于教学关")


func _validate_export_contract() -> void:
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_expect(presets.contains("gradle_build/target_sdk=\"36\""), "Android 目标 API 未更新到 36")
	_expect(presets.contains("version/name=\"1.16.0\"") and presets.contains("application/short_version=\"1.16.0\""), "Android/iOS 发布版本不一致")
	_expect(presets.contains("privacy/camera_usage_description=\"当前版本不使用相机功能。\""), "iOS 相机隐私用途说明为空")
	_expect(presets.contains("privacy/microphone_usage_description=\"当前版本不使用麦克风功能。\""), "iOS 麦克风隐私用途说明为空")
	_expect(presets.contains("privacy/photolibrary_usage_description=\"当前版本不使用照片图库功能。\""), "iOS 照片图库隐私用途说明为空")


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
	_expect(UIScript.compact_touch_layout_needed(safe_viewport, true), "手机安全区没有启用紧凑 HUD")
	_expect(not UIScript.compact_touch_layout_needed(Vector2(1220, 820), true), "大屏平板被错误压缩成手机 HUD")
	_expect(not UIScript.compact_touch_layout_needed(safe_viewport, false), "桌面窗口不应启用手机紧凑 HUD")
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
	var status_rect := Rect2(Vector2(12.0, 12.0), UIScript.COMPACT_STATUS_SIZE)
	var info_rect := Rect2(Vector2(safe_viewport.x - 368.0, 12.0), UIScript.COMPACT_INFO_SIZE)
	var leaderboard_rect := Rect2(Vector2(safe_viewport.x - 368.0, 190.0), UIScript.COMPACT_LEADERBOARD_SIZE)
	var ticker_rect := Rect2(Vector2(safe_viewport.x * 0.5 - 155.0, 58.0), Vector2(310.0, 50.0))
	_expect(not status_rect.intersects(ticker_rect), "紧凑玩家状态框遮挡顶部战报")
	_expect(not info_rect.intersects(ticker_rect), "紧凑关卡信息框遮挡顶部战报")
	_expect(not info_rect.intersects(leaderboard_rect), "紧凑关卡信息框与排行榜重叠")
	_expect(status_rect.size.y < 250.0 and info_rect.size.y < 180.0 and leaderboard_rect.size.y < 180.0, "手机 HUD 信息框仍占据过多垂直视野")
	var skill_panel_rect := Rect2(Vector2((safe_viewport.x - UIScript.COMPACT_SKILL_SIZE.x) * 0.5, safe_viewport.y - 104.0), UIScript.COMPACT_SKILL_SIZE)
	var intro_rect := Rect2(Vector2(safe_viewport.x * 0.5 - 360.0, 28.0), UIScript.COMPACT_INTRO_SIZE)
	for touch_button_rect in touch_rects:
		_expect(not skill_panel_rect.intersects(touch_button_rect), "触控按钮仍遮挡技能状态栏")
		_expect(not intro_rect.intersects(touch_button_rect), "物种攻略仍遮挡触控按钮")
	var phone_modal_size := UIScript.modal_size_for_available(Vector2(1000.0, 700.0), safe_viewport, true)
	_expect(phone_modal_size.x <= safe_viewport.x * 0.94 and phone_modal_size.y <= safe_viewport.y * 0.92, "手机弹窗没有保留足够的周边视野")
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


func _validate_ecology_leverage_contract() -> void:
	var actor_source := FileAccess.get_file_as_string("res://scripts/eco_actor.gd")
	_expect(actor_source.contains("ECOLOGY_LEVERAGE_COOLDOWN := 9.0"), "生态借力缺少防止连续引战的冷却")
	_expect(actor_source.contains("func ecology_leverage_candidate"), "弱势物种无法评估可介入的第三方")
	_expect(actor_source.contains("_prepare_escape_intervention(target)"), "弱势 AI 逃跑没有规划第三方引战路线")
	_expect(actor_source.contains("threat.register_ecology_influence(self, ECOLOGY_LEVERAGE_INFLUENCE, \"生态借力\")"), "生态借力没有登记助攻归属")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(main_source.contains("func on_ecology_intervention"), "主流程没有接收生态借力战况")
	_expect(main_source.contains("influence_source.assists += 1"), "生态助攻仍只奖励玩家而没有统一到所有物种")
	var ui_source := FileAccess.get_file_as_string("res://scripts/game_ui.gd")
	_expect(ui_source.contains("counterplay_plan") and ui_source.contains("可生态借力"), "HUD 和敌方血条没有生态借力提示")


func _validate_counterplay_mastery_contract() -> void:
	_expect(is_equal_approx(Catalog.COUNTERPLAY_ROUTE_XP_RATIO, 0.10), "单条反制路线经验不是目标价值的 10%")
	_expect(is_equal_approx(Catalog.COUNTERPLAY_TARGET_XP_CAP_RATIO, 0.32), "单目标战术经验上限不是目标价值的 32%")
	_expect(Catalog.counterplay_experience_reward("elephant", 1) < Catalog.counterplay_experience_cap("elephant", 1), "战术经验单次奖励没有受到总上限约束")
	for species_id in Catalog.ORDER:
		_expect(Catalog.counterplay_plan(species_id).length() >= 24, "%s 缺少反制组合攻略" % species_id)
	var actor_source := FileAccess.get_file_as_string("res://scripts/eco_actor.gd")
	_expect(actor_source.contains("COUNTERPLAY_CHAIN_WINDOW := 18.0"), "战术连携窗口不是 18 秒")
	_expect(actor_source.contains("COUNTERPLAY_MASTERY_HEALTH_RATIO := 0.06"), "生态掌控生命恢复不是 6%")
	_expect(actor_source.contains("COUNTERPLAY_MASTERY_STAMINA_RATIO := 0.18"), "生态掌控耐力恢复不是 18%")
	_expect(actor_source.contains("counterplay_route_awards.has(award_key)"), "同目标同路线缺少防刷记录")
	_expect(actor_source.contains("counterplay_mastered_targets.has(target_key)"), "同目标缺少一次性掌控限制")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(main_source.contains("func on_counterplay_progress"), "主流程没有接收战术连携战况")
	_expect(main_source.contains("战术行动：%d"), "结算页没有展示战术行动数")
	var ui_source := FileAccess.get_file_as_string("res://scripts/game_ui.gd")
	_expect(ui_source.contains("反制组合：%s") and ui_source.contains("counterplay_chain_status_text"), "物种简报与 HUD 没有解释战术连携")


func _validate_ecology_hotspot_contract() -> void:
	_expect(WorldScript.ecology_event_ids_for_level(1) == ["fruit_fall"], "第一关应只教学落果潮")
	_expect(WorldScript.ecology_event_ids_for_level(3) == ["fruit_fall", "grass_flush", "fish_run"], "第三关没有按顺序解锁鱼群洄游")
	_expect(WorldScript.ecology_event_ids_for_level(10).size() == 4, "第十关没有开放全部四种生态热点")
	_expect(WorldScript.ecology_event_first_delay(1, 0.0) >= 35.0, "首个热点过早打断出生观察期")
	_expect(WorldScript.ecology_event_repeat_delay(10, 0.0) < WorldScript.ecology_event_repeat_delay(1, 0.0), "高关卡热点节奏没有加快")
	_expect(WorldScript.compass_direction(Vector3.ZERO, Vector3(8.0, 0.0, -8.0)) == "东北", "热点方向提示没有正确识别东北")
	var world := WorldScript.new()
	root.add_child(world)
	world.world_size = 100.0
	world.campaign_level = 10
	world.event_rng.seed = 1110
	var event: Dictionary = world.start_ecology_event("fish_run")
	_expect(not event.is_empty() and str(event.get("title", "")) == "鱼群洄游", "无法确定性启动鱼群生态热点")
	_expect(world.active_event_patches.size() == 6, "第十关生态热点应生成 6 个真实食物点")
	for patch in world.active_event_patches:
		_expect(is_instance_valid(patch) and bool(patch.ecology_hotspot) and patch is FoodPatch, "生态热点生成了非食物装饰或缺少热点标记")
	var main := MainScript.new()
	main.world = world
	var event_position: Vector3 = event.get("position", Vector3.ZERO)
	var migrant_food := main.nearest_food(event_position + Vector3(30.0, 0.0, 0.0), 8.0, "crocodile")
	_expect(is_instance_valid(migrant_food) and bool(migrant_food.ecology_hotspot), "远处 AI 无法循生态信号迁徙到真实可食资源")
	_expect(world.ecology_event_status(event_position + Vector3(20.0, 0.0, 20.0)).contains("鱼群洄游"), "HUD 热点状态缺少标题、方向或距离")
	_expect(WorldScript.ecology_activity_risk(4, 0) == "平稳" and WorldScript.ecology_activity_risk(2, 2) == "高危", "热点迁徙风险分级不符合猎手压力")
	_expect(WorldScript.ecology_activity_status(5, 2).contains("迁徙 5") and WorldScript.ecology_activity_status(5, 2).contains("猎手 2"), "热点活动摘要缺少迁徙或猎手数")
	var ambush_a := WorldScript.ecology_ambush_offset(7.0, 2, 1)
	var ambush_b := WorldScript.ecology_ambush_offset(7.0, 3, 1)
	_expect(ambush_a.length() > 9.5 and not ambush_a.is_equal_approx(ambush_b), "猎手没有分散到热点外围不同伏击位")
	_expect(ActorScript.should_follow_hotspot_signal(62.0, 0.82, 1.0, 0.9, 3, false, false, 4, 2), "健康高攻击性猎手不会响应迁徙猎物信号")
	_expect(not ActorScript.should_follow_hotspot_signal(62.0, 0.82, 1.0, 0.9, 3, true, false, 4, 2), "能直接进食的物种被错误归类为外围猎手")
	_expect(not ActorScript.should_follow_hotspot_signal(62.0, 0.82, 0.30, 0.9, 3, false, false, 4, 2), "重伤猎手仍会贸然离开安全区围猎")
	world._end_ecology_event("自动测试切换信号")
	var fruit_event: Dictionary = world.start_ecology_event("fruit_fall")
	var migrant := ActorScript.new()
	migrant.actor_id = 1
	migrant.species_id = "fox"
	migrant.data = Catalog.get_data("fox")
	migrant.game = main
	migrant.ai_state = "food"
	migrant.resource_target = world.active_event_patches[0]
	migrant.position = fruit_event.get("position", Vector3.ZERO)
	migrant.max_health = 100.0
	migrant.health = 100.0
	migrant.max_stamina = 100.0
	migrant.stamina = 100.0
	migrant.hunger = 52.0
	var ordinary_resource := Node3D.new()
	migrant.resource_target = ordinary_resource
	_expect(not migrant.is_migrating_to_ecology_hotspot(int(fruit_event.get("sequence", -1)), fruit_event.get("position", Vector3.ZERO) + Vector3(40.0, 0.0, 0.0), 7.0), "普通资源目标被错误当作生态热点并触发布尔转换")
	migrant.resource_target = world.active_event_patches[0]
	var hunter := ActorScript.new()
	hunter.actor_id = 4
	hunter.species_id = "wolf"
	hunter.data = Catalog.get_data("wolf")
	hunter.game = main
	hunter.max_health = 100.0
	hunter.health = 100.0
	hunter.max_stamina = 100.0
	hunter.stamina = 100.0
	hunter.hunger = 70.0
	main.actors = [migrant, hunter]
	_expect(main.ecology_hotspot_prey_signal_count(hunter) == 1, "猎手无法读取正在迁徙的可捕食物种")
	_expect(hunter._begin_ecology_hotspot_stalk() and hunter.is_stalking_ecology_hotspot(int(fruit_event.get("sequence", -1))), "猎手未前往热点外围伏击位")
	main._refresh_ecology_hotspot_activity(1.0)
	_expect(main.ecology_hotspot_risk_level() == "高危" and main.ecology_hotspot_activity_status().contains("猎手 1"), "世界没有汇总真实迁徙和猎手压力")
	_expect(not is_instance_valid(migrant._best_wild_food(30.0)), "非紧急的胆小小型物种不会避开高危热点")
	migrant.hunger = 82.0
	_expect(is_instance_valid(migrant._best_wild_food(30.0)), "极度饥饿物种被风险判断永久阻止进食")
	world.trigger_collapse()
	_expect(world.get_active_ecology_event().is_empty(), "栖息地收束后生态热点仍在继续刷新")
	main.actors.clear()
	ordinary_resource.free()
	migrant.free()
	hunter.free()
	main.world = null
	main.free()
	world.free()
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(main_source.contains("player_hotspots_visited") and main_source.contains("_update_player_ecology_hotspot"), "主流程没有记录玩家抵达生态热点")
	_expect(main_source.contains("ecology_hotspot_prey_signal_count") and main_source.contains("_actor_is_hotspot_hunter"), "主流程没有汇总迁徙猎物和围猎者")
	var ui_source := FileAccess.get_file_as_string("res://scripts/game_ui.gd")
	_expect(ui_source.contains("ecology_event_label") and ui_source.contains("生态热点 · 正在等待迁徙信号"), "移动 HUD 没有持续显示生态热点状态")
	_expect(ui_source.contains("ecology_activity_label") and ui_source.contains("迁徙监测 · 尚无活动"), "移动 HUD 没有显示迁徙数、猎手数和风险")


func _validate_ecology_trace_contract() -> void:
	_expect(WorldScript.ecology_trace_lifetime("clear", true, true, false) > WorldScript.ecology_trace_lifetime("clear", false, false, false), "受伤与奔跑没有增强生态踪迹")
	_expect(WorldScript.ecology_trace_lifetime("storm", true, true, false) < WorldScript.ecology_trace_lifetime("clear", true, true, false), "暴雨没有缩短生态踪迹寿命")
	_expect(not WorldScript.should_record_ecology_trace(1.2, true, false, false, false, false), "安静穿过草丛仍留下可追踪足迹，破坏隐蔽")
	_expect(WorldScript.should_record_ecology_trace(1.2, true, true, false, false, false), "草丛中冲刺没有暴露足迹")
	_expect(not WorldScript.should_record_ecology_trace(2.0, false, true, true, true, true), "飞行动物错误留下地面足迹")
	_expect(ActorScript.should_investigate_ecology_trace(62.0, 0.68, 0.9, 0.8, false, false), "健康饥饿猎手不会调查猎物足迹")
	_expect(not ActorScript.should_investigate_ecology_trace(62.0, 0.68, 0.4, 0.8, false, false), "重伤猎手仍会冒险追踪")
	_expect(ActorScript.should_avoid_danger_memory(0.18, 48.0, 0.9, 1, false), "胆小猎物不会避开危险记忆")
	_expect(not ActorScript.should_avoid_danger_memory(0.18, 86.0, 0.9, 1, false), "极饿猎物被危险记忆永久阻止觅食")
	var world := WorldScript.new()
	world.weather_id = "clear"
	world.ecology_clock = 0.0
	var trace := world.record_movement_trace(7, "rabbit", Vector3(8.0, 0.0, 0.0), Vector3.RIGHT, true, true)
	_expect(not trace.is_empty() and str(trace.get("kind", "")) == "血迹", "受伤猎物没有留下血迹")
	world.ecology_clock = 0.5
	_expect(world.best_prey_trace(4, "wolf", Vector3.ZERO, 20.0).is_empty(), "猎手读取了过于实时的精确足迹")
	world.ecology_clock = 1.0
	var found_trace := world.best_prey_trace(4, "wolf", Vector3.ZERO, 20.0)
	_expect(int(found_trace.get("source_id", -1)) == 7 and float(found_trace.get("age", 0.0)) >= 0.75, "猎手无法读取已延迟的猎物足迹")
	_expect(world.best_prey_trace(8, "deer", Vector3.ZERO, 20.0).is_empty(), "非捕食者错误读取其他动物为猎物线索")
	var danger := world.record_danger_memory(Vector3(18.0, 0.0, 0.0), "deer", 3, "wolf")
	_expect(not danger.is_empty() and str(danger.get("kind", "")) == "血战残迹", "战斗死亡没有形成危险记忆")
	var excluded := {str(int(danger.get("sequence", 0))): true}
	_expect(world.nearest_danger_memory(Vector3(18.0, 0.0, 0.0), 5.0, excluded).is_empty(), "已记住的危险地点被 AI 反复触发")
	_expect(world.ecology_trace_status(4, "wolf", Vector3.ZERO).contains("追踪线索"), "HUD 没有显示猎物踪迹方向与距离")
	var main := MainScript.new()
	main.world = world
	var hunter := ActorScript.new()
	hunter.actor_id = 4
	hunter.species_id = "wolf"
	hunter.data = Catalog.get_data("wolf")
	hunter.game = main
	hunter.position = Vector3.ZERO
	hunter.max_health = 100.0
	hunter.health = 90.0
	hunter.max_stamina = 100.0
	hunter.stamina = 80.0
	hunter.hunger = 62.0
	main.actors = [hunter]
	_expect(hunter._begin_ecology_trace_investigation() and hunter.ai_state == "trace_investigate", "真实 AI 没有进入足迹调查状态")
	var timid := ActorScript.new()
	timid.actor_id = 9
	timid.species_id = "rabbit"
	timid.data = Catalog.get_data("rabbit")
	timid.game = main
	timid.position = Vector3(17.0, 0.0, 0.0)
	timid.max_health = 100.0
	timid.health = 90.0
	timid.max_stamina = 100.0
	timid.stamina = 90.0
	timid.hunger = 48.0
	main.actors.append(timid)
	_expect(timid._begin_danger_memory_avoidance() and timid.ai_state == "danger_avoid", "真实胆小 AI 没有绕开附近危险记忆")
	_expect(main.ecology_trace_investigations == 1 and main.danger_memory_avoidances == 1, "主流程没有统计踪迹调查与危险绕行")
	main.actors.clear()
	hunter.free()
	timid.free()
	main.world = null
	main.free()
	world.free()
	var ui_source := FileAccess.get_file_as_string("res://scripts/game_ui.gd")
	_expect(ui_source.contains("ecology_trace_label") and ui_source.contains("生态踪迹 · 暂无线索"), "移动 HUD 没有持续显示生态踪迹")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
