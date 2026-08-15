extends SceneTree

const MainScript = preload("res://scripts/main.gd")
const WorldScript = preload("res://scripts/eco_world.gd")
const ActorScript = preload("res://scripts/eco_actor.gd")
const AudioScript = preload("res://scripts/audio_manager.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")
const UIScript = preload("res://scripts/game_ui.gd")
const Catalog = preload("res://scripts/species_catalog.gd")
const VisualCatalog = preload("res://scripts/species_visual_catalog.gd")
const SkeletonRig = preload("res://scripts/species_skeleton_rig.gd")
const FlightRig = preload("res://scripts/species_flight_rig.gd")
const CrocodileRig = preload("res://scripts/species_crocodile_rig.gd")

var failures: Array[String] = []


class ExternalModelGame:
	extends Node
	var batch_mode: bool = false
	var player: EcoActor
	var world: Node
	var world_seed: int = 20260815
	var current_level: int = 1
	var quality_preset: String = "high"

	func get_quality_preset() -> String:
		return quality_preset


func _initialize() -> void:
	_run_validation.call_deferred()


func _run_validation() -> void:
	_validate_save_migration()
	_validate_bestiary_and_recap_contract()
	_validate_release_candidate_contract()
	_validate_quality_presets()
	_validate_spawn_distribution_contract()
	_validate_tutorial_contract()
	_validate_free_mode_contract()
	_validate_leaderboard_contract()
	_validate_world_transition_contract()
	_validate_death_lifecycle_contract()
	_validate_export_contract()
	_validate_performance_baseline_contract()
	_validate_web_audio_contract()
	_validate_visual_kit_contract()
	_validate_level_identity_contract()
	_validate_world_navigation_contract()
	_validate_external_species_model_contract()
	_validate_adaptive_ui_contract()
	_validate_opportunity_contract()
	_validate_cover_ambush_contract()
	_validate_terrain_counter_contract()
	_validate_ecology_leverage_contract()
	_validate_counterplay_mastery_contract()
	_validate_ecology_hotspot_contract()
	_validate_ecology_trace_contract()
	_validate_ai_tactical_contract()
	_validate_ecological_habit_contract()
	_validate_growth_hud_contract()
	if failures.is_empty():
		print("[release] V1.41 发布候选校验通过：30 种 Blender V2 双档骨骼模型、烘焙动作运行时、自动门禁与三端发布契约正常")
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
	main.discovered_species = ["rabbit", "eagle"]
	main.species_records = {"rabbit": {"runs": 3, "wins": 1, "best_level": 4, "best_survival": 123.0, "best_player_level": 3, "most_kills": 2}}
	main.recent_runs = [{"species_id": "rabbit", "level": 4, "won": false, "survival": 123.0, "player_level": 3, "kills": 2}]
	main._save_progress(test_path)
	var reload := MainScript.new()
	reload._load_progress(test_path)
	_expect(reload.campaign_level == 6 and reload.last_completed_level == 5, "新存档关卡进度无法回读")
	_expect(reload.selected_free_level == 9 and reload.selected_free_species == "eagle", "自由模式选择无法回读")
	_expect(reload.current_level == 6, "自由模式选择不应覆盖战役关卡")
	_expect(reload.quality_preset == "high", "画质档位无法回读")
	_expect(reload.tutorial_completed, "教学完成状态无法回读")
	_expect(reload.discovered_species == ["rabbit", "eagle"], "图鉴发现顺序或内容无法回读")
	_expect(int(reload.species_records.get("rabbit", {}).get("runs", 0)) == 3, "物种个人记录无法回读")
	_expect(reload.recent_runs.size() == 1 and int(reload.recent_runs[0].get("level", 0)) == 4, "最近轮回记录无法回读")
	DirAccess.remove_absolute(test_path)
	main.free()
	reload.free()


func _validate_bestiary_and_recap_contract() -> void:
	var main := MainScript.new()
	_expect(main.bestiary_progress_text() == "生态图鉴　发现 0 / 30", "空白图鉴进度不正确")
	main._discover_roster(["wolf", "rabbit", "wolf"], false)
	_expect(main.discovered_species == ["rabbit", "wolf"], "同局重复物种没有去重或目录顺序不稳定")
	_expect(main.new_discoveries_current_run == ["wolf", "rabbit"], "本局新发现列表没有保留实际遇见顺序")
	var entries := main.get_bestiary_entries()
	_expect(entries.size() == Catalog.ORDER.size(), "图鉴没有覆盖全部 30 种动物")
	_expect(bool(entries[Catalog.ORDER.find("rabbit")].get("discovered", false)), "已发现动物仍显示为锁定")
	_expect(not bool(entries[Catalog.ORDER.find("eagle")].get("discovered", true)), "未发现动物提前泄露完整图鉴")
	var hostile_records := {"rabbit": {"runs": -4, "wins": 99, "best_level": 99, "best_player_level": 99}, "missing": {"runs": 8}}
	var sanitized := main._sanitize_species_records(hostile_records)
	_expect(int(sanitized["rabbit"]["runs"]) == 0 and int(sanitized["rabbit"]["wins"]) == 0, "损坏的图鉴战绩没有限制到安全范围")
	_expect(int(sanitized["rabbit"]["best_level"]) == 10 and int(sanitized["rabbit"]["best_player_level"]) == 8, "图鉴最佳成绩上限没有与玩法一致")
	_expect(not sanitized.has("missing"), "图鉴保留了不存在的物种记录")
	var player_actor := ActorScript.new()
	player_actor.species_id = "rabbit"
	player_actor.level = 4
	player_actor.experience = 37
	player_actor.kills = 2
	player_actor.assists = 3
	player_actor.tactical_actions = 5
	player_actor.food_bites = 8
	main.player = player_actor
	main.current_level = 4
	main.run_uses_free_mode = false
	var recap := main._record_completed_run(false, "草原雄狮结束了你的这次生命", "lion", 318.0)
	_expect(int(main.species_records["rabbit"]["runs"]) == 1 and int(main.species_records["rabbit"]["most_kills"]) == 2, "局后数据没有汇总到物种个人记录")
	_expect(main.recent_runs.size() == 1 and str(recap.get("killer_species", "")) == "lion", "局后复盘没有记录死亡来源")
	_expect(str(recap.get("advice", "")).contains("不要正面对耗"), "被强敌击败后没有生成可执行建议")
	var ui_source := FileAccess.get_file_as_string("res://scripts/game_ui.gd")
	_expect(ui_source.contains("func show_bestiary()") and ui_source.contains("SpeciesIndex") and ui_source.contains("SpeciesDetail"), "首页图鉴缺少可滚动物种索引或详情")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(ui_source.contains("func recent_battle_report_lines") and main_source.contains("最后 10 秒"), "结算没有接入最后十秒生态事件")
	_expect(main_source.contains("图鉴只解锁知识与战绩，不会永久增加任何属性"), "图鉴没有明确保持无永久属性加成")
	player_actor.free()
	main.free()


func _validate_release_candidate_contract() -> void:
	var candidate_script := FileAccess.get_file_as_string("res://tools/build_release_candidate.sh")
	_expect(candidate_script.contains("--quit-after 1200") and candidate_script.contains("run_performance_baseline.sh"), "发布候选脚本缺少长运行烟测或 1/5/10 关性能基线")
	_expect(candidate_script.contains("validate_performance_baseline.gd") and candidate_script.contains("ECO_RC_SOAK"), "发布候选脚本没有对性能门槛或可选完整生态收束执行验证")
	_expect(candidate_script.contains("index.wasm") and candidate_script.contains("CODE_SIGNING_ALLOWED=NO") and candidate_script.contains("android-export"), "发布候选脚本没有覆盖 Web、iOS 与 Android 构建路径")
	_expect(candidate_script.contains("shasum -a 256") and candidate_script.contains("release_candidate_manifest.json"), "发布候选没有生成可核对的构建哈希清单")
	var workflow := FileAccess.get_file_as_string("res://.github/workflows/deploy-web.yml")
	_expect(workflow.contains("validate_species.gd") and workflow.contains("validate_release.gd") and workflow.contains("--quit-after 300"), "GitHub Pages 在导出前没有执行数据、发布与运行门禁")
	_expect(workflow.contains("actions/checkout@v6") and workflow.contains("actions/upload-pages-artifact@v5") and workflow.contains("actions/deploy-pages@v5"), "GitHub Pages Actions 没有使用 Node.js 24 对应主版本")
	var release_checklist := FileAccess.get_file_as_string("res://docs/15_发布候选与真机验收.md")
	_expect(release_checklist.contains("Android 真机") and release_checklist.contains("iPhone 真机") and release_checklist.contains("不能声称"), "发布清单没有区分自动化构建与真实设备验收")
	var privacy := FileAccess.get_file_as_string("res://docs/16_隐私说明.md")
	_expect(privacy.contains("不包含广告") and privacy.contains("不会由游戏代码上传") and privacy.contains("GitHub Pages"), "隐私说明没有覆盖本地数据、第三方组件与 Web 托管边界")


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
	_expect(presets.contains("version/name=\"1.41.0\"") and presets.contains("application/short_version=\"1.41.0\""), "Android/iOS 发布版本不一致")
	_expect(presets.contains("version/code=510") and presets.contains("application/version=\"510\""), "Android/iOS 内部构建号没有同步递增")
	_expect(MainScript.RELEASE_VERSION == "1.41.0", "运行时性能报告版本没有与导出版本同步")
	_expect(presets.contains("privacy/camera_usage_description=\"当前版本不使用相机功能。\""), "iOS 相机隐私用途说明为空")
	_expect(presets.contains("privacy/microphone_usage_description=\"当前版本不使用麦克风功能。\""), "iOS 麦克风隐私用途说明为空")
	_expect(presets.contains("privacy/photolibrary_usage_description=\"当前版本不使用照片图库功能。\""), "iOS 照片图库隐私用途说明为空")


func _validate_performance_baseline_contract() -> void:
	_expect(MainScript.batch_results_filename(1) == "batch_level_01_results.csv", "第一关批测结果文件名不稳定")
	_expect(MainScript.batch_results_filename(10) == "batch_level_10_results.csv", "第十关批测结果会覆盖其他关卡")
	_expect(MainScript.batch_deaths_filename(1) != MainScript.batch_deaths_filename(10), "不同关卡的死亡明细仍会互相覆盖")
	_expect(MainScript.benchmark_report_filename(5, "medium") == "benchmark_level_05_medium.json", "性能报告文件名没有包含关卡和画质")
	_expect(MainScript.benchmark_report_filename(99, "invalid") == "benchmark_level_10_medium.json", "性能报告参数没有安全修正")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(main_source.contains("--report-dir") and main_source.contains("--benchmark-level") and main_source.contains("Performance.TIME_PHYSICS_PROCESS"), "运行时缺少独立输出目录或真实性能采样")
	_expect(main_source.contains("stuck_recoveries,route_replans,food_bites,habit_activations") and main_source.contains("func _collect_batch_actor_metrics"), "生态批测没有记录 AI 脱困、改道与进食行为")
	var baseline_script := FileAccess.get_file_as_string("res://tools/run_performance_baseline.sh")
	_expect(baseline_script.contains("run_level 1 133701") and baseline_script.contains("run_level 5 133705") and baseline_script.contains("run_level 10 133710"), "性能基线没有覆盖第 1/5/10 关")
	var doctor_script := FileAccess.get_file_as_string("res://tools/check_platform_toolchain.sh")
	_expect(doctor_script.contains("android-36") and doctor_script.contains("web_nothreads_release.zip") and doctor_script.contains("ios.zip"), "三端工具链诊断不完整")


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
	var grassland_texture := load(texture_paths[1]) as Texture2D
	var wetland_texture := load(texture_paths[2]) as Texture2D
	var highland_texture := load(texture_paths[3]) as Texture2D
	_expect(forest_texture != null, "森林 AI 地表材质无法加载")
	var terrain := Factory.terrain_material(Color("#244833"), Color("#3b603d"), 12.0, forest_texture, 5.0, 0.24)
	_expect(terrain.shader != null, "V2 地表着色器没有创建")
	_expect(is_equal_approx(float(terrain.get_shader_parameter("texture_strength")), 0.24), "AI 地表混合强度没有传入着色器")
	var biome_blend := Factory.biome_blend_material(forest_texture, grassland_texture, wetland_texture, highland_texture, 70.0)
	_expect(biome_blend.shader != null, "V3 连续生态地表着色器没有创建")
	_expect(is_equal_approx(float(biome_blend.get_shader_parameter("world_extent")), 70.0), "V3 地表没有按地图尺度弯曲生态边界")
	var faceted := Factory.sphere("VisualContract", Color("#a86f43"), Vector3.ONE, Vector3.ZERO, 8, 5)
	_expect(faceted.mesh is ArrayMesh, "V3 物种基础体没有使用程序曲面网格")
	if faceted.mesh is ArrayMesh:
		var arrays := (faceted.mesh as ArrayMesh).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		_expect(not colors.is_empty(), "V3 物种程序网格缺少连续体色")
		_expect(normals.size() == vertices.size(), "V3 物种程序网格缺少平滑法线")
		var normals_by_vertex := {}
		var minimum_shared_normal_dot := 1.0
		var shared_vertex_count := 0
		for vertex_index in range(vertices.size()):
			var vertex := vertices[vertex_index]
			if normals_by_vertex.has(vertex):
				minimum_shared_normal_dot = minf(minimum_shared_normal_dot, Vector3(normals_by_vertex[vertex]).dot(normals[vertex_index]))
				shared_vertex_count += 1
			else:
				normals_by_vertex[vertex] = normals[vertex_index]
		_expect(shared_vertex_count > 0 and minimum_shared_normal_dot > 0.98, "V3 物种相邻曲面仍使用割裂的逐面法线")
	var factory_source := FileAccess.get_file_as_string("res://scripts/low_poly_factory.gd")
	_expect(factory_source.contains("_organic_vertex_color") and factory_source.contains("biome_blend_material"), "V3 有机曲面或连续生态地表实现缺失")
	var loft := Factory.loft("LoftWindingContract", Color("#7f6248"), [Vector3(0.0, 0.7, 0.9), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.25, -1.0)], [Vector2(0.42, 0.36), Vector2(0.66, 0.58), Vector2(0.28, 0.25)], 8)
	if loft.mesh is ArrayMesh:
		var loft_arrays := (loft.mesh as ArrayMesh).surface_get_arrays(0)
		var loft_vertices: PackedVector3Array = loft_arrays[Mesh.ARRAY_VERTEX]
		var loft_normals: PackedVector3Array = loft_arrays[Mesh.ARRAY_NORMAL]
		var minimum_winding_dot := 1.0
		for triangle_start in range(0, loft_vertices.size(), 3):
			var face_normal := (loft_vertices[triangle_start + 1] - loft_vertices[triangle_start]).cross(loft_vertices[triangle_start + 2] - loft_vertices[triangle_start]).normalized()
			var average_normal := (loft_normals[triangle_start] + loft_normals[triangle_start + 1] + loft_normals[triangle_start + 2]).normalized()
			minimum_winding_dot = minf(minimum_winding_dot, face_normal.dot(average_normal))
		_expect(minimum_winding_dot > 0.0, "有机 loft 网格绕序与外法线相反，模型会出现黑色背面")
	else:
		failures.append("有机 loft 网格无法生成")
	var actor_source := FileAccess.get_file_as_string("res://scripts/eco_actor.gd")
	_expect(actor_source.contains("tail_visuals") and actor_source.contains("body_pitch_scale"), "V3 动物步态缺少身体起伏或尾部摆动")
	_expect(actor_source.contains("game.get(\"batch_mode\") == true"), "缺少 batch_mode 字段的预览/工具场景仍会对 null 调用 bool 构造")
	faceted.free()
	loft.free()


func _validate_level_identity_contract() -> void:
	_expect(WorldScript.LEVEL_WORLD_PROFILES.size() == 10, "十关世界档案数量不完整")
	var ids := {}
	var titles := {}
	var signatures := {}
	for level in range(1, 11):
		var profile := WorldScript.level_profile(level)
		var profile_id := str(profile.get("id", ""))
		var title := str(profile.get("title", ""))
		ids[profile_id] = true
		titles[title] = true
		signatures[int(profile.get("signature", 0))] = true
		_expect(int(profile.get("level", 0)) == level, "第%d关世界档案缺少稳定关卡编号" % level)
		_expect(not profile_id.is_empty() and not title.is_empty() and not str(profile.get("rule", "")).is_empty(), "第%d关缺少标题或玩法规则" % level)
		_expect(float(profile.get("tree", 0.0)) >= 0.50 and float(profile.get("tree", 0.0)) <= 1.35, "第%d关树木密度越界" % level)
		_expect(float(profile.get("rock", 0.0)) >= 0.60 and float(profile.get("rock", 0.0)) <= 1.35, "第%d关岩石密度越界" % level)
		_expect(float(profile.get("cover", 0.0)) >= 0.75 and float(profile.get("cover", 0.0)) <= 1.35, "第%d关掩体密度越界" % level)
		_expect(float(profile.get("food", 0.0)) >= 0.75 and float(profile.get("food", 0.0)) <= 1.25, "第%d关食物密度越界" % level)
		_expect(float(profile.get("water", 0.0)) >= 0.60 and float(profile.get("water", 0.0)) <= 1.50, "第%d关水域尺度越界" % level)
		_expect(int(profile.get("side_trails", 0)) >= 2 and int(profile.get("side_trails", 0)) <= 6, "第%d关支路数量越界" % level)
		_expect(float(profile.get("collapse", 0.0)) >= 0.18 and float(profile.get("collapse", 0.0)) <= 0.24, "第%d关终局收束半径越界" % level)
		for phase in profile.get("phases", []):
			_expect(str(phase) in ["day", "night"], "第%d关出现无效昼夜档案" % level)
		for weather in profile.get("weather", []):
			_expect(str(weather) in ["clear", "rain", "fog", "storm"], "第%d关出现无效天气档案" % level)
	_expect(ids.size() == 10 and titles.size() == 10 and signatures.size() == 10, "十关缺少独立 ID、标题或中央图腾剪影")
	_expect(WorldScript.level_identity(1) == "第1关 · 新生林地" and WorldScript.level_identity(10) == "第10关 · 终极生物圈", "首尾关卡身份文本错误")
	_expect(str(WorldScript.level_profile(6)["phases"][0]) == "night", "第六关没有固定暮夜身份")
	_expect(not WorldScript.level_profile(7)["weather"].has("clear"), "第七关风暴边境仍会生成无天气关局")
	_expect(float(WorldScript.level_profile(9)["food"]) < float(WorldScript.level_profile(1)["food"]), "第九关资源稀缺没有区别于教学关")
	_expect(WorldScript.ecology_event_repeat_delay(10, 0.0) < WorldScript.ecology_event_repeat_delay(5, 0.0), "终极生物圈的生态事件没有进入高频节奏")
	var ui_source := FileAccess.get_file_as_string("res://scripts/game_ui.gd")
	_expect(ui_source.contains("本关生态：") and ui_source.contains("level_profile"), "随机物种攻略没有显示当前关卡规则")


func _validate_world_navigation_contract() -> void:
	_expect(WorldScript.REGION_LANDMARK_PROFILES.size() == 4, "四生态区地标配置不完整")
	var motifs := {}
	for region_id in WorldScript.REGION_ORDER:
		var profile: Dictionary = WorldScript.REGION_LANDMARK_PROFILES.get(region_id, {})
		_expect(not profile.is_empty(), "生态区缺少地标配置：%s" % region_id)
		motifs[str(profile.get("motif", ""))] = true
	_expect(motifs.size() == 4, "四生态区地标缺少可辨识的独立剪影")
	for level_case in [
		{"level": 1, "size": 140.0, "seed": 132001, "cell": 3.4},
		{"level": 10, "size": 470.0, "seed": 132010, "cell": 4.2},
	]:
		var world := WorldScript.new()
		root.add_child(world)
		world.setup(int(level_case["seed"]), float(level_case["size"]), int(level_case["level"]), false, "clear", "day", "low")
		_expect(world.region_landmark_positions.size() == 4, "第%d关没有生成四个生态区地标" % int(level_case["level"]))
		_expect(world.find_children("LevelSignature_*", "Node3D", true, false).size() == 1, "第%d关没有生成独立中央生态图腾" % int(level_case["level"]))
		_expect(world.migration_routes.size() == 2, "第%d关没有生成横纵迁徙主通道" % int(level_case["level"]))
		for region_id in WorldScript.REGION_ORDER:
			var marker_position: Vector3 = world.region_landmark_positions.get(region_id, Vector3.ZERO)
			_expect(world.is_landing_clear(marker_position, 0.85), "第%d关 %s 地标周边被障碍物封锁" % [int(level_case["level"]), region_id])
		for obstacle_index in range(world.obstacles.size()):
			var required_clearance := WorldScript.MIGRATION_CORRIDOR_HALF_WIDTH + world.obstacle_radii[obstacle_index]
			_expect(world.migration_route_clearance(world.obstacles[obstacle_index]) + 0.01 >= required_clearance, "第%d关迁徙通道出现阻路障碍物" % int(level_case["level"]))
		var report: Dictionary = world.navigation_connectivity_report(0.85, float(level_case["cell"]))
		print("[navigation] level=%d size=%.0f open=%d largest=%d ratio=%.2f%%" % [int(level_case["level"]), float(level_case["size"]), int(report.get("open_cells", 0)), int(report.get("largest_component", 0)), float(report.get("ratio", 0.0)) * 100.0])
		_expect(float(report.get("ratio", 0.0)) >= 0.97, "第%d关可通行区最大连通块低于 97%%：%.2f%%" % [int(level_case["level"]), float(report.get("ratio", 0.0)) * 100.0])
		world.free()


func _validate_external_species_model_contract() -> void:
	var fur_texture_paths := [
		"res://assets/textures/animals/shared/quadruped_fur_atlas_albedo.png",
		"res://assets/textures/animals/shared/quadruped_fur_atlas_normal.png",
		"res://assets/textures/animals/shared/quadruped_fur_atlas_roughness.png",
	]
	for texture_path in fur_texture_paths:
		_expect(ResourceLoader.exists(texture_path), "四足物种毛发 PBR 图集缺失：%s" % texture_path)
		var texture := load(texture_path) as Texture2D
		_expect(texture != null and texture.get_width() == 256 and texture.get_height() == 256, "毛发 PBR 图集没有保持 256×256 移动端预算：%s" % texture_path)
		var import_source := FileAccess.get_file_as_string(texture_path + ".import")
		_expect(import_source.contains("compress/mode=2") and import_source.contains("mipmaps/generate=true"), "毛发 PBR 图集没有启用跨端 VRAM 压缩与 mipmap：%s" % texture_path)
	var normal_import := FileAccess.get_file_as_string(fur_texture_paths[1] + ".import")
	_expect(normal_import.contains("compress/normal_map=1"), "毛发法线图集没有使用法线压缩模式")
	_expect(VisualCatalog.FUR_ATLAS_REGIONS.size() == 4 and VisualCatalog.FUR_ATLAS_REGIONS["bear"] == Vector2(0.5, 0.5), "四种四足动物的 2×2 材质图集分区异常")
	# All V2 animals are driven by armature bones; legacy Node3D pivots must not
	# survive beside the imported skeleton or the pose would be applied twice.
	var expected_motion_nodes := {}
	for species_id in VisualCatalog.EXTERNAL_SPECIES:
		expected_motion_nodes[species_id] = {}
	_expect(VisualCatalog.profile_for(true, "high") == "hero", "高画质玩家没有选择 Hero 物种模型")
	_expect(VisualCatalog.profile_for(true, "low") == "mobile", "低画质玩家没有降级到 Mobile 物种模型")
	_expect(VisualCatalog.profile_for(false, "high") == "mobile", "AI 错误加载 Hero 物种模型，移动端可能超预算")
	_expect(VisualCatalog.V2_SPECIES == VisualCatalog.EXTERNAL_SPECIES and VisualCatalog.V2_SPECIES.size() == 30, "Blender V2 三十物种清单异常")
	_expect(VisualCatalog.SKELETAL_SPECIES.size() == 26, "V2 地面骨骼物种清单异常")
	_expect(VisualCatalog.FLIGHT_RIG_SPECIES == ["owl", "eagle"], "飞行骨架物种清单异常")
	_expect(VisualCatalog.LONG_BODY_RIG_SPECIES == ["snake", "crocodile"], "长躯干骨架物种清单异常")
	_expect(SkeletonRig.WEIGHTED_SKIN_SPECIES == VisualCatalog.SKELETAL_SPECIES, "地面动物连续权重蒙皮物种清单异常")
	_expect(SkeletonRig.SKILL_SOCKET_NAMES == ["SkillSocket_Mouth", "SkillSocket_Chest"], "地面动物技能挂点契约异常")
	_expect(SkeletonRig.RABBIT_ANIMATION_STATES == ["idle", "run", "forage", "attack", "skill", "hit", "dead"], "雪兔骨架缺少觅食、折跃或倒地状态")
	_expect(FlightRig.RIGGED_SPECIES == ["owl", "eagle"], "飞行动物骨架控制器物种清单异常")
	_expect(FlightRig.ANIMATION_STATES == ["glide", "flap", "dive", "hit"], "金雕飞行骨架缺少滑翔、振翅、俯冲或受击状态")
	_expect(FlightRig.SKILL_SOCKET_NAMES == ["SkillSocket_Beak", "SkillSocket_Wing_L", "SkillSocket_Wing_R"], "金雕飞行技能挂点契约异常")
	_expect(FlightRig.resolve_state(0.0, 0.0, 0.0, 0.0, true) == "glide", "金雕空中低速时没有进入滑翔")
	_expect(FlightRig.resolve_state(0.8, 0.0, 0.0, 0.0, true) == "flap", "金雕空中移动时没有进入振翅")
	_expect(FlightRig.resolve_state(0.8, 0.2, 0.0, 0.0, true) == "dive" and FlightRig.resolve_state(0.8, 0.2, 0.0, 0.2, true) == "hit", "金雕俯冲/受击状态优先级异常")
	_expect(CrocodileRig.RIGGED_SPECIES == ["snake", "crocodile"], "长体动物骨架控制器物种清单异常")
	_expect(CrocodileRig.ANIMATION_STATES == ["idle", "crawl", "swim", "attack", "roll", "hit"], "沼泽鳄骨架缺少待机、爬行、游动、咬击、翻滚或受击状态")
	_expect(CrocodileRig.SKILL_SOCKET_NAMES == ["SkillSocket_Jaw", "SkillSocket_TailTip"], "沼泽鳄吻部/尾端技能挂点契约异常")
	_expect(CrocodileRig.resolve_state(0.0, 0.0, 0.0, 0.0, false) == "idle", "沼泽鳄静止时没有进入待机")
	_expect(CrocodileRig.resolve_state(0.8, 0.0, 0.0, 0.0, false) == "crawl" and CrocodileRig.resolve_state(0.8, 0.0, 0.0, 0.0, true) == "swim", "沼泽鳄没有按水深切换爬行/游动")
	_expect(CrocodileRig.resolve_state(0.8, 0.2, 0.3, 0.0, true) == "roll" and CrocodileRig.resolve_state(0.8, 0.2, 0.3, 0.2, true) == "hit", "沼泽鳄翻滚/受击状态优先级异常")
	_expect(SkeletonRig.RIG_PROFILES.size() == 4 and SkeletonRig.FAMILY_PROFILES.size() == 6, "地面骨架缺少物种或科属步态参数")
	_expect(SkeletonRig.V2_ANIMATION_STATES == ["idle", "run", "sprint", "forage", "attack", "skill", "hit", "dead"], "V2 地面骨架缺少完整八态动画接口")
	_expect(SkeletonRig.ANIMATION_STATES == ["idle", "run", "attack", "hit"], "骨骼控制器没有提供完整四态动画接口")
	_expect(SkeletonRig.resolve_state(0.0, 0.0, 0.0) == "idle" and SkeletonRig.resolve_state(0.8, 0.0, 0.0) == "run", "骨骼待机/奔跑状态切换异常")
	_expect(SkeletonRig.resolve_state(0.8, 0.1, 0.0) == "attack" and SkeletonRig.resolve_state(0.8, 0.1, 0.1) == "hit", "骨骼攻击/受击状态优先级异常")
	_expect(SkeletonRig.resolve_state(0.0, 0.0, 0.0, 0.8, 0.0, false, "rabbit") == "forage", "雪兔进食没有切换觅食状态")
	_expect(SkeletonRig.resolve_state(0.8, 0.0, 0.0, 0.0, 0.2, false, "rabbit") == "skill", "雪兔月影折跃没有切换技能状态")
	_expect(SkeletonRig.resolve_state(0.8, 0.1, 0.1, 0.8, 0.2, true, "rabbit") == "dead", "雪兔倒地状态没有最高优先级")
	_expect(VisualCatalog.EXTERNAL_SPECIES == Catalog.ORDER and VisualCatalog.THIRD_BATCH_SPECIES.size() == 11 and VisualCatalog.FOURTH_BATCH_SPECIES.size() == 10 and VisualCatalog.VISUAL_SCALE_CONTRACT.size() == VisualCatalog.EXTERNAL_SPECIES.size(), "三十种外部动物、第四批模型或视觉比例契约不完整")
	_expect(is_equal_approx(float(VisualCatalog.VISUAL_SCALE_CONTRACT["rabbit"]), 1.02) and is_equal_approx(float(VisualCatalog.VISUAL_SCALE_CONTRACT["bear"]), 1.22), "小型雪兔与大型棕熊比例契约异常")
	var total_mobile_vertices := 0
	for species_id in VisualCatalog.EXTERNAL_SPECIES:
		var profile_vertices := {}
		for profile in ["hero", "mobile"]:
			var model_path := VisualCatalog.model_path(species_id, profile)
			_expect(ResourceLoader.exists(model_path), "%s 的 %s GLB 模型缺失" % [species_id, profile])
			var model := VisualCatalog.instantiate(species_id, profile)
			if model == null:
				failures.append("%s 的 %s GLB 模型无法实例化" % [species_id, profile])
				continue
			_expect(is_equal_approx(model.scale.x, float(VisualCatalog.VISUAL_SCALE_CONTRACT[species_id])) and model.scale.is_equal_approx(Vector3.ONE * model.scale.x), "%s 的 %s 模型没有遵循统一根缩放契约" % [species_id, profile])
			var stats := _external_model_stats(model)
			profile_vertices[profile] = int(stats["vertices"])
			var minimum_meshes := 4 if species_id in VisualCatalog.V2_SPECIES else 6
			_expect(int(stats["meshes"]) >= minimum_meshes, "%s 的 %s 模型层级异常或网格过少" % [species_id, profile])
			_expect(int(stats["vertices"]) > 120, "%s 的 %s 模型没有有效几何细节" % [species_id, profile])
			_expect(int(stats["colored_surfaces"]) > 0, "%s 的 %s 模型材质丢失或退化为纯白" % [species_id, profile])
			if profile == "mobile":
				_expect(int(stats["vertices"]) <= 16000, "%s 的 Mobile 模型超出移动端顶点预算" % species_id)
				total_mobile_vertices += int(stats["vertices"])
			_expect(int(stats["lod_meshes"]) == int(stats["meshes"]), "%s 的 %s 网格没有完整配置自动可见距离 LOD" % [species_id, profile])
			_expect(int(stats["detail_lod_meshes"]) > 0, "%s 的 %s 没有可独立裁剪的远景细节层" % [species_id, profile])
			_expect(int(stats["organic_body_islands"]) == 1, "%s 的 %s OrganicBodyV2 不是单一连通体，足、耳或尾可能脱离躯干" % [species_id, profile])
			if species_id in ["owl", "eagle", "elephant", "turtle"]:
				_expect(int(stats["silhouette_lod_meshes"]) > 0, "%s 的 %s 翼、长鼻或主甲壳被错分为短距离细节" % [species_id, profile])
			if species_id in VisualCatalog.SKELETAL_SPECIES:
				_expect(int(stats["skeletons"]) == 1, "%s 的 %s 运行时模型没有唯一 Skeleton3D" % [species_id, profile])
				_expect(int(stats["bones"]) >= 12, "%s 的 %s 骨骼数量不足，躯干、头颈或两段式四肢可能丢失" % [species_id, profile])
				_expect((stats["pbr_slots"] as Dictionary).size() >= 3, "%s 的 %s 缺少物种化体表、眼部或细节 PBR 材质槽" % [species_id, profile])
				if species_id not in VisualCatalog.V2_SPECIES:
					_expect(int(stats["textured_coat_surfaces"]) > 0 and int(stats["atlas_coat_surfaces"]) == int(stats["textured_coat_surfaces"]), "%s 的 %s 毛皮材质没有绑定共享 PBR 图集" % [species_id, profile])
				if species_id in SkeletonRig.WEIGHTED_SKIN_SPECIES:
					var species_label: String = Catalog.display_name(species_id)
					_expect(int(stats["bones"]) >= 12, "%s 的 %s 模型缺少 Chest/Neck/Head 连续躯干骨链" % [species_label, profile])
					if species_id in VisualCatalog.V2_SPECIES:
						_expect(int(stats["continuous_coat_skinned_meshes"]) == 1, "%s 的 %s 模型没有唯一的 Blender V2 连续毛皮躯干" % [species_label, profile])
						_expect(int(stats["articulated_paw_bones"]) == 4, "%s 的 %s 模型没有四条两段式腿骨" % [species_label, profile])
						_expect(int(stats["required_actions"]) == 8, "%s 的 %s 模型没有导入完整八态动作" % [species_label, profile])
					else:
						_expect(int(stats["skinned_meshes"]) == 1, "%s 的 %s 模型没有唯一连续蒙皮躯干" % [species_label, profile])
					_expect(int(stats["weighted_vertices"]) > 100, "%s 的 %s 连续蒙皮顶点不足" % [species_label, profile])
					_expect(int(stats["blended_vertices"]) > 20, "%s 的 %s 躯干没有跨骨骼平滑权重" % [species_label, profile])
					_expect(int(stats["invalid_weight_vertices"]) == 0, "%s 的 %s 蒙皮权重没有归一化" % [species_label, profile])
					_expect(int(stats["skill_sockets"]) == 2, "%s 的 %s 技能挂点数量异常" % [species_label, profile])
			elif species_id in VisualCatalog.FLIGHT_RIG_SPECIES:
				var flight_label := Catalog.display_name(species_id)
				_expect(int(stats["skeletons"]) == 1, "%s 的 %s 模型没有唯一飞行 Skeleton3D" % [flight_label, profile])
				_expect(int(stats["bones"]) >= 10, "%s 的 %s 模型缺少身体、头、双段翼、尾羽或双爪骨骼" % [flight_label, profile])
				_expect(int(stats["continuous_coat_skinned_meshes"]) == 1 and int(stats["skinned_meshes"]) >= 1, "%s 的 %s 模型没有连续蒙皮羽体" % [flight_label, profile])
				_expect(int(stats["weighted_vertices"]) > 100 and int(stats["invalid_weight_vertices"]) == 0, "%s 的 %s 飞行蒙皮权重异常" % [flight_label, profile])
				_expect(int(stats["required_actions"]) == 8, "%s 的 %s 模型没有导入完整八态动作" % [flight_label, profile])
				_expect(int(stats["skill_sockets"]) == 3, "%s 的 %s 模型缺少喙部或双翼技能挂点" % [flight_label, profile])
				_expect((stats["pbr_slots"] as Dictionary).size() >= 3, "%s 的 %s 缺少羽毛、眼部或喙爪 PBR 材质槽" % [flight_label, profile])
			elif species_id in VisualCatalog.LONG_BODY_RIG_SPECIES:
				var long_label := Catalog.display_name(species_id)
				var minimum_long_bones := 8 if species_id == "snake" else 12
				_expect(int(stats["skeletons"]) == 1, "%s 的 %s 模型没有唯一长躯干 Skeleton3D" % [long_label, profile])
				_expect(int(stats["bones"]) >= minimum_long_bones, "%s 的 %s 模型缺少头颈、颌部或多段尾链" % [long_label, profile])
				_expect(int(stats["continuous_coat_skinned_meshes"]) == 1 and int(stats["skinned_meshes"]) >= 1, "%s 的 %s 模型没有连续蒙皮主躯干" % [long_label, profile])
				_expect(int(stats["weighted_vertices"]) > 100, "%s 的 %s 连续蒙皮顶点不足" % [long_label, profile])
				_expect(int(stats["blended_vertices"]) > 20, "%s 的 %s 躯干与尾部没有跨骨平滑权重" % [long_label, profile])
				_expect(int(stats["invalid_weight_vertices"]) == 0, "%s 的 %s 蒙皮权重没有归一化" % [long_label, profile])
				_expect(int(stats["required_actions"]) == 8, "%s 的 %s 模型没有导入完整八态动作" % [long_label, profile])
				_expect(int(stats["skill_sockets"]) == 2, "%s 的 %s 模型缺少吻部或尾端技能挂点" % [long_label, profile])
				_expect((stats["pbr_slots"] as Dictionary).size() >= 3, "%s 的 %s 缺少鳞片、眼部或口腔 PBR 材质槽" % [long_label, profile])
			else:
				_expect(int(stats["skeletons"]) == 0 and int(stats["skinned_meshes"]) == 0, "%s 的 %s 轻量模型被意外接入高成本骨架" % [species_id, profile])
				_expect((stats["pbr_slots"] as Dictionary).size() >= 3, "%s 的 %s 缺少物种化 PBR 材质槽" % [species_id, profile])
			for node_prefix in expected_motion_nodes[species_id]:
				var actual_count := int(stats["named_nodes"].get(node_prefix, 0))
				_expect(actual_count >= int(expected_motion_nodes[species_id][node_prefix]), "%s 的 %s 模型缺少 %s 动画枢轴" % [species_id, profile, node_prefix])
			model.free()
		if profile_vertices.has("hero") and profile_vertices.has("mobile"):
			_expect(int(profile_vertices["hero"]) > int(profile_vertices["mobile"]), "%s 的 Hero 模型细节没有高于 Mobile LOD" % species_id)
	_expect(total_mobile_vertices <= 140000, "三十种外部动物 Mobile 模型总顶点超出 140000 性能基线")
	print("[visual] external=%d fourth_batch=%d mobile_vertices=%d budget=140000" % [VisualCatalog.EXTERNAL_SPECIES.size(), VisualCatalog.FOURTH_BATCH_SPECIES.size(), total_mobile_vertices])
	var actor_source := FileAccess.get_file_as_string("res://scripts/eco_actor.gd")
	_expect(actor_source.contains("uses_external_model = _build_external_species_visual()"), "角色运行时没有优先加载外部物种模型")
	_expect(actor_source.contains("_bind_external_motion_nodes(model)"), "外部物种模型没有接入共享步态动画")
	_expect(actor_source.contains("_bind_external_skill_sockets(model)"), "外部物种模型没有绑定技能挂点")
	_expect(actor_source.contains("skill_socket_world_position(\"SkillSocket_Mouth\"") and actor_source.contains("skill_socket_world_position(\"SkillSocket_Chest\""), "雪兔折跃或灰狼群猎特效没有使用骨骼挂点")
	_expect(actor_source.contains("FlightRig.resolve_state") and actor_source.contains("_play_external_baked_animation"), "真实角色流程没有用烘焙动作驱动金雕骨架")
	_expect(actor_source.contains("skill_socket_world_position(\"SkillSocket_Beak\"") and actor_source.contains("skill_socket_world_position(\"SkillSocket_Wing_L\"") and actor_source.contains("skill_socket_world_position(\"SkillSocket_Wing_R\""), "金雕俯冲和翼流特效没有使用骨骼挂点")
	_expect(actor_source.contains("CrocodileRig.resolve_state") and actor_source.contains("_play_external_baked_animation"), "真实角色流程没有用烘焙动作驱动沼泽鳄长躯干骨架")
	_expect(actor_source.contains("skill_socket_world_position(\"SkillSocket_Jaw\"") and actor_source.contains("skill_socket_world_position(\"SkillSocket_TailTip\""), "沼泽鳄死亡翻滚没有使用吻部和尾端骨骼挂点")
	_expect(actor_source.contains("if not uses_external_model:"), "外部模型失败时没有保留程序模型降级路径")
	var game_stub := ExternalModelGame.new()
	root.add_child(game_stub)
	var hero_actor: EcoActor = ActorScript.new()
	hero_actor.process_mode = Node.PROCESS_MODE_DISABLED
	game_stub.add_child(hero_actor)
	hero_actor.setup(game_stub, 901, "rabbit", true, Vector3.ZERO, 0)
	_expect(hero_actor.uses_external_model and hero_actor.external_model_profile == "hero", "真实角色流程没有为高画质玩家加载 Hero GLB")
	_expect(is_instance_valid(hero_actor.external_skeleton) and hero_actor.external_skeleton.get_bone_count() >= 12, "真实角色流程没有绑定雪兔连续躯干 Skeleton3D")
	_expect(is_instance_valid(hero_actor.external_animation_player) and hero_actor.external_animation_player.has_animation("locomotion"), "真实雪兔角色没有绑定 Blender 烘焙动作")
	_expect(hero_actor.external_baked_animation == "idle", "真实雪兔角色没有从完整体表待机动作开始")
	_expect(hero_actor.external_skill_sockets.size() == 2, "真实雪兔角色流程没有绑定嘴部和胸部技能挂点")
	_expect(hero_actor.leg_pivots.is_empty() and hero_actor.ear_pivots.is_empty() and hero_actor.tail_visuals.is_empty(), "骨骼物种仍被旧节点枢轴重复驱动")
	var run_pose := SkeletonRig.pose_targets("run", 1.2, 0.6, 1.0, 0.0, 0.0, 0.2, "rabbit")
	var forage_pose := SkeletonRig.pose_targets("forage", 1.2, 0.0, 0.0, 0.0, 0.0, 0.2, "rabbit")
	var rabbit_skill_pose := SkeletonRig.pose_targets("skill", 1.2, 0.6, 1.0, 0.5, 0.0, 0.2, "rabbit")
	var rabbit_dead_pose := SkeletonRig.pose_targets("dead", 1.2, 0.0, 0.0, 0.0, 0.0, 0.2, "rabbit")
	var attack_pose := SkeletonRig.pose_targets("attack", 1.2, 0.6, 1.0, 0.5, 0.0, 0.2, "wolf")
	var hit_pose := SkeletonRig.pose_targets("hit", 1.2, 0.6, 1.0, 0.0, 0.5, 0.2, "bear")
	_expect(Vector3(run_pose.get("Leg_LF", Vector3.ZERO)).length() > 0.1, "骨骼奔跑状态没有驱动腿部")
	_expect(Vector3(forage_pose.get("Neck", Vector3.ZERO)).x > 0.5, "雪兔觅食没有低头驱动头颈骨链")
	_expect(Vector3(rabbit_skill_pose.get("Leg_LH", Vector3.ZERO)).x > 0.7, "雪兔月影折跃没有驱动后足蹬地")
	_expect(absf(Vector3(rabbit_dead_pose.get("Spine", Vector3.ZERO)).z) > 1.0, "雪兔倒地没有驱动身体侧卧")
	_expect(Vector3(attack_pose.get("Spine", Vector3.ZERO)).length() > 0.1, "骨骼攻击状态没有驱动躯干前扑")
	_expect(Vector3(hit_pose.get("Spine", Vector3.ZERO)).length() > 0.1, "骨骼受击状态没有驱动躯干后坐")
	var deer_run := SkeletonRig.pose_targets("run", 1.2, 0.6, 1.0, 0.0, 0.0, 0.2, "deer")
	var bear_run := SkeletonRig.pose_targets("run", 1.2, 0.6, 1.0, 0.0, 0.0, 0.2, "bear")
	_expect(not Vector3(deer_run["Leg_LH"]).is_equal_approx(Vector3(bear_run["Leg_LH"])), "林鹿小跑与棕熊重步仍错误共用同一动作参数")
	_expect(Vector3(deer_run["Neck"]).length() > 0.01 and Vector3(bear_run["Chest"]).length() > 0.005, "林鹿或棕熊连续体轴没有响应奔跑姿势")
	hero_actor._play_attack_pulse()
	hero_actor._update_visual_motion(0.016)
	_expect(hero_actor.external_animation_state == "attack", "真实普通攻击事件没有切换骨骼攻击状态")
	_expect(hero_actor.external_baked_animation == "attack", "真实普通攻击没有播放 Blender 攻击动作")
	hero_actor._play_hit_pulse()
	hero_actor._update_visual_motion(0.016)
	_expect(hero_actor.external_animation_state == "hit", "真实受击事件没有以更高优先级切换骨骼受击状态")
	_expect(hero_actor.external_baked_animation == "hit", "真实受击事件没有播放 Blender 受击动作")
	hero_actor.external_hit_animation_timer = 0.0
	hero_actor.external_attack_animation_timer = 0.0
	hero_actor.eat_timer = 1.0
	hero_actor._update_visual_motion(0.016)
	_expect(hero_actor.external_animation_state == "forage", "真实雪兔进食流程没有切换觅食状态")
	_expect(hero_actor.external_baked_animation == "eat", "真实雪兔进食流程没有播放 Blender 进食动作")
	hero_actor.eat_timer = 0.0
	hero_actor.external_skill_animation_timer = SkeletonRig.RABBIT_SKILL_DURATION
	hero_actor._update_visual_motion(0.016)
	_expect(hero_actor.external_animation_state == "skill", "真实雪兔技能流程没有切换月影折跃状态")
	_expect(hero_actor.external_baked_animation == "skill", "真实雪兔技能流程没有播放 Blender 技能动作")
	_expect(ActorScript.baked_action_for_state("run", 0.8) == "locomotion" and ActorScript.baked_action_for_state("run", 1.2) == "sprint", "普通移动和冲刺没有分流到对应烘焙动作")
	_expect(ActorScript.baked_action_for_state("forage", 0.0) == "eat" and ActorScript.baked_action_for_state("dead", 0.0) == "death", "觅食或死亡状态没有映射到模型动作")
	game_stub.quality_preset = "low"
	var mobile_actor: EcoActor = ActorScript.new()
	mobile_actor.process_mode = Node.PROCESS_MODE_DISABLED
	game_stub.add_child(mobile_actor)
	mobile_actor.setup(game_stub, 902, "wolf", false, Vector3.ZERO, 0)
	_expect(mobile_actor.uses_external_model and mobile_actor.external_model_profile == "mobile", "真实角色流程没有为 AI 加载 Mobile GLB")
	_expect(is_instance_valid(mobile_actor.external_skeleton) and mobile_actor.external_skeleton.get_bone_count() >= 12, "真实角色流程没有为灰狼 Mobile 模型绑定连续躯干骨链")
	_expect(is_instance_valid(mobile_actor.external_animation_player) and mobile_actor.external_baked_animation == "idle", "真实灰狼 AI 没有启用 Mobile 烘焙动作")
	_expect(mobile_actor.external_skill_sockets.size() == 2, "真实灰狼角色流程没有绑定两个技能挂点")
	var wolf_mouth_position := mobile_actor.skill_socket_world_position("SkillSocket_Mouth", 1.55)
	var wolf_mouth_offset := wolf_mouth_position - mobile_actor.global_position
	_expect(wolf_mouth_offset.length() > 0.5, "灰狼嘴部技能挂点退化到了角色原点")
	_expect(wolf_mouth_offset.dot(-mobile_actor.global_basis.z) > 0.5, "灰狼 V2 模型前向轴反转，嘴部挂点没有位于角色朝向前方")
	_expect(Vector3(attack_pose.get("Neck", Vector3.ZERO)).length() > 0.05 and Vector3(attack_pose.get("Head", Vector3.ZERO)).length() > 0.02, "灰狼扑咬没有驱动连续蒙皮头颈骨链")
	for species_id in VisualCatalog.SKELETAL_SPECIES:
		if species_id in ["rabbit", "wolf"]:
			continue
		var quadruped_actor: EcoActor = ActorScript.new()
		quadruped_actor.process_mode = Node.PROCESS_MODE_DISABLED
		game_stub.add_child(quadruped_actor)
		quadruped_actor.setup(game_stub, 910 + VisualCatalog.SKELETAL_SPECIES.find(species_id), species_id, false, Vector3.ZERO, 0)
		_expect(is_instance_valid(quadruped_actor.external_skeleton) and quadruped_actor.external_skeleton.get_bone_count() >= 12, "%s 没有接入连续体轴 Skeleton3D" % species_id)
		_expect(is_instance_valid(quadruped_actor.external_animation_player) and quadruped_actor.external_baked_animation == "idle", "%s 没有在真实角色流程启用烘焙动作" % species_id)
		_expect(quadruped_actor.external_skill_sockets.size() == 2, "%s 没有接入嘴部和胸部技能挂点" % species_id)
		var mouth_offset := quadruped_actor.skill_socket_world_position("SkillSocket_Mouth", 0.70) - quadruped_actor.global_position
		_expect(mouth_offset.length() > 0.35 and mouth_offset.dot(-quadruped_actor.global_basis.z) > 0.25, "%s 的嘴部挂点没有位于模型前方" % species_id)
		_expect(quadruped_actor.leg_pivots.is_empty() and quadruped_actor.ear_pivots.is_empty(), "%s 仍被骨骼与旧节点步态重复驱动" % species_id)
		quadruped_actor.free()
	game_stub.quality_preset = "high"
	var eagle_actor: EcoActor = ActorScript.new()
	eagle_actor.process_mode = Node.PROCESS_MODE_DISABLED
	game_stub.add_child(eagle_actor)
	eagle_actor.setup(game_stub, 920, "eagle", true, Vector3.ZERO, 0)
	_expect(eagle_actor.uses_external_model and eagle_actor.external_model_profile == "hero", "真实金雕角色流程没有加载 Hero GLB")
	_expect(is_instance_valid(eagle_actor.external_skeleton) and eagle_actor.external_skeleton.get_bone_count() >= 8, "真实金雕角色流程没有绑定飞行 Skeleton3D")
	_expect(is_instance_valid(eagle_actor.external_animation_player), "真实金雕角色没有绑定 Blender 飞行动作")
	_expect(eagle_actor.wing_pivots.is_empty() and eagle_actor.tail_visuals.is_empty(), "金雕仍被飞行骨架与旧节点振翅重复驱动")
	_expect(eagle_actor.external_skill_sockets.size() == 3, "真实金雕角色流程没有绑定喙部和双翼技能挂点")
	_expect(eagle_actor.skill_socket_world_position("SkillSocket_Beak", 1.65).distance_to(eagle_actor.global_position) > 0.5, "金雕喙部技能挂点退化到了角色原点")
	var flap_pose := FlightRig.pose_targets("flap", 1.2, 1.0, 0.0, 0.0, 0.4)
	var dive_pose := FlightRig.pose_targets("dive", 1.2, 1.0, 0.5, 0.0, 0.4)
	var flight_hit_pose := FlightRig.pose_targets("hit", 1.2, 1.0, 0.0, 0.5, 0.4)
	_expect(Vector3(flap_pose["Wing_L"]).distance_to(Vector3(flap_pose["Wing_R"])) > 0.25, "金雕振翅没有镜像驱动左右翼")
	_expect(absf(Vector3(dive_pose["Wing_L"]).y) > 0.20 and absf(Vector3(dive_pose["Talon_L"]).x) > 0.25, "金雕俯冲没有收翼伸爪")
	_expect(Vector3(flight_hit_pose["Body"]).length() > 0.10, "金雕受击没有产生身体失衡")
	eagle_actor.flight_dive_timer = FlightRig.DIVE_DURATION
	eagle_actor._update_visual_motion(0.016)
	_expect(eagle_actor.external_animation_state == "dive", "真实天穹贯击没有切换飞行骨架俯冲状态")
	_expect(eagle_actor.external_baked_animation == "dive", "真实天穹贯击没有播放 Blender 俯冲动作")
	eagle_actor._play_hit_pulse()
	eagle_actor._update_visual_motion(0.016)
	_expect(eagle_actor.external_animation_state == "hit", "真实金雕受击没有以最高优先级切换飞行骨架状态")
	_expect(eagle_actor.external_baked_animation == "hit", "真实金雕受击没有播放 Blender 受击动作")
	var owl_actor: EcoActor = ActorScript.new()
	owl_actor.process_mode = Node.PROCESS_MODE_DISABLED
	game_stub.add_child(owl_actor)
	owl_actor.setup(game_stub, 921, "owl", false, Vector3.ZERO, 0)
	_expect(owl_actor.uses_external_model and is_instance_valid(owl_actor.external_skeleton), "真实雪鸮 AI 没有加载 Mobile 飞行骨架")
	_expect(is_instance_valid(owl_actor.external_animation_player), "真实雪鸮 AI 没有绑定 Blender 飞行动作")
	_expect(owl_actor.external_skill_sockets.size() == 3, "真实雪鸮 AI 没有绑定喙部和双翼技能挂点")
	_expect(owl_actor.skill_socket_world_position("SkillSocket_Beak", 1.65).distance_to(owl_actor.global_position) > 0.5, "雪鸮喙部技能挂点退化到了角色原点")
	var crocodile_actor: EcoActor = ActorScript.new()
	crocodile_actor.process_mode = Node.PROCESS_MODE_DISABLED
	game_stub.add_child(crocodile_actor)
	crocodile_actor.setup(game_stub, 930, "crocodile", true, Vector3.ZERO, 0)
	_expect(crocodile_actor.uses_external_model and crocodile_actor.external_model_profile == "hero", "真实沼泽鳄角色流程没有加载 Hero GLB")
	_expect(is_instance_valid(crocodile_actor.external_skeleton) and crocodile_actor.external_skeleton.get_bone_count() >= 12, "真实沼泽鳄角色流程没有绑定长躯干/尾链 Skeleton3D")
	_expect(is_instance_valid(crocodile_actor.external_animation_player), "真实沼泽鳄角色没有绑定 Blender 长躯干动作")
	_expect(crocodile_actor.leg_pivots.is_empty() and crocodile_actor.tail_visuals.is_empty(), "沼泽鳄仍被长躯干骨架与旧节点步态重复驱动")
	_expect(crocodile_actor.external_skill_sockets.size() == 2, "真实沼泽鳄角色流程没有绑定吻部和尾端技能挂点")
	_expect(crocodile_actor.skill_socket_world_position("SkillSocket_Jaw", 0.66).distance_to(crocodile_actor.global_position) > 1.0, "沼泽鳄吻部技能挂点退化到了角色原点")
	_expect(crocodile_actor.skill_socket_world_position("SkillSocket_TailTip", 0.58).distance_to(crocodile_actor.global_position) > 0.30, "沼泽鳄尾端技能挂点退化到了角色原点")
	var crawl_pose := CrocodileRig.pose_targets("crawl", 1.4, 1.0, 0.0, 0.0, 0.0, 0.7)
	var swim_pose := CrocodileRig.pose_targets("swim", 1.4, 1.0, 0.0, 0.0, 0.0, 0.7)
	var bite_pose := CrocodileRig.pose_targets("attack", 1.4, 1.0, 0.5, 0.0, 0.0, 0.7)
	var roll_pose := CrocodileRig.pose_targets("roll", 1.4, 1.0, 0.0, 0.5, 0.0, 0.7)
	var crocodile_hit_pose := CrocodileRig.pose_targets("hit", 1.4, 1.0, 0.0, 0.0, 0.5, 0.7)
	_expect(absf(Vector3(swim_pose["Tail_Tip"]).y) > absf(Vector3(crawl_pose["Tail_Tip"]).y), "沼泽鳄游动尾摆没有强于陆地爬行")
	_expect(absf(Vector3(bite_pose["Jaw"]).x) > 0.30, "沼泽鳄普通咬击没有驱动颌骨")
	_expect(absf(Vector3(roll_pose["Body"]).z) > 0.60 and absf(Vector3(roll_pose["Tail_Mid"]).y) > 0.30, "沼泽鳄死亡翻滚没有驱动身体侧翻与尾链")
	_expect(Vector3(crocodile_hit_pose["Body"]).length() > 0.12, "沼泽鳄受击没有产生长躯干失衡")
	crocodile_actor._play_attack_pulse()
	crocodile_actor._update_visual_motion(0.016)
	_expect(crocodile_actor.external_animation_state == "attack", "真实沼泽鳄普通攻击没有切换咬击状态")
	_expect(crocodile_actor.external_baked_animation == "attack", "真实沼泽鳄普通攻击没有播放 Blender 咬击动作")
	crocodile_actor.external_skill_animation_timer = CrocodileRig.ROLL_DURATION
	crocodile_actor._update_visual_motion(0.016)
	_expect(crocodile_actor.external_animation_state == "roll", "真实沼泽鳄死亡翻滚没有切换长躯干骨架状态")
	_expect(crocodile_actor.external_baked_animation == "skill", "真实沼泽鳄死亡翻滚没有播放 Blender 技能动作")
	crocodile_actor._play_hit_pulse()
	crocodile_actor._update_visual_motion(0.016)
	_expect(crocodile_actor.external_animation_state == "hit", "真实沼泽鳄受击没有以最高优先级切换骨架状态")
	var snake_actor: EcoActor = ActorScript.new()
	snake_actor.process_mode = Node.PROCESS_MODE_DISABLED
	game_stub.add_child(snake_actor)
	snake_actor.setup(game_stub, 931, "snake", false, Vector3.ZERO, 0)
	_expect(snake_actor.uses_external_model and is_instance_valid(snake_actor.external_skeleton) and snake_actor.external_skeleton.get_bone_count() >= 8, "真实森蚺 AI 没有加载 Mobile 长体骨架")
	_expect(is_instance_valid(snake_actor.external_animation_player), "真实森蚺 AI 没有绑定 Blender 长体动作")
	_expect(snake_actor.external_skill_sockets.size() == 2, "真实森蚺 AI 没有绑定颌部和尾端技能挂点")
	_expect(snake_actor.skill_socket_world_position("SkillSocket_Jaw", 0.66).distance_to(snake_actor.global_position) > 0.7, "森蚺颌部技能挂点退化到了角色原点")
	var expansion_actors: Array[EcoActor] = []
	var lightweight_species: Array = VisualCatalog.EXTERNAL_SPECIES.filter(func(species_id: String) -> bool:
		return species_id not in VisualCatalog.SKELETAL_SPECIES and species_id not in VisualCatalog.FLIGHT_RIG_SPECIES and species_id not in VisualCatalog.LONG_BODY_RIG_SPECIES
	)
	for species_id in lightweight_species:
		var expansion_actor: EcoActor = ActorScript.new()
		expansion_actor.process_mode = Node.PROCESS_MODE_DISABLED
		game_stub.add_child(expansion_actor)
		expansion_actor.setup(game_stub, 940 + expansion_actors.size(), species_id, false, Vector3.ZERO, 0)
		_expect(expansion_actor.uses_external_model and expansion_actor.external_model_profile == "mobile", "%s 没有在真实 AI 流程加载 Mobile GLB" % species_id)
		_expect(not is_instance_valid(expansion_actor.external_skeleton), "%s 的轻量外部模型不应绑定骨架" % species_id)
		var motion_contract: Dictionary = expected_motion_nodes[species_id]
		_expect(expansion_actor.leg_pivots.size() >= int(motion_contract.get("LegPivot_", 0)), "%s 的腿部动作节点没有接入 EcoActor" % species_id)
		_expect(expansion_actor.ear_pivots.size() >= int(motion_contract.get("EarPivot_", 0)), "%s 的耳部动作节点没有接入 EcoActor" % species_id)
		_expect(expansion_actor.wing_pivots.size() >= int(motion_contract.get("WingPivot_", 0)), "%s 的翼部动作节点没有接入 EcoActor" % species_id)
		_expect(expansion_actor.tail_visuals.size() >= int(motion_contract.get("TailPivot", 0)), "%s 的尾部动作节点没有接入 EcoActor" % species_id)
		expansion_actors.append(expansion_actor)
	game_stub.batch_mode = true
	var fallback_actor: EcoActor = ActorScript.new()
	fallback_actor.process_mode = Node.PROCESS_MODE_DISABLED
	game_stub.add_child(fallback_actor)
	fallback_actor.setup(game_stub, 903, "rabbit", false, Vector3.ZERO, 0)
	_expect(not fallback_actor.uses_external_model and fallback_actor.body_root.get_child_count() > 0, "无画面/资源降级流程没有恢复程序模型")
	hero_actor.free()
	mobile_actor.free()
	fallback_actor.free()
	eagle_actor.free()
	owl_actor.free()
	crocodile_actor.free()
	snake_actor.free()
	for expansion_actor in expansion_actors:
		expansion_actor.free()
	game_stub.free()


func _external_model_stats(root_node: Node) -> Dictionary:
	var stats := {
		"meshes": 0,
		"vertices": 0,
		"colored_surfaces": 0,
		"skeletons": 0,
		"bones": 0,
		"pbr_slots": {},
		"textured_coat_surfaces": 0,
		"atlas_coat_surfaces": 0,
		"lod_meshes": 0,
		"detail_lod_meshes": 0,
		"named_nodes": {},
		"skinned_meshes": 0,
		"weighted_vertices": 0,
		"blended_vertices": 0,
		"invalid_weight_vertices": 0,
		"skill_sockets": 0,
		"continuous_coat_skinned_meshes": 0,
		"organic_body_islands": 0,
		"articulated_paw_bones": 0,
		"silhouette_lod_meshes": 0,
		"required_actions": 0,
	}
	_accumulate_external_model_stats(root_node, stats)
	return stats


func _accumulate_external_model_stats(node: Node, stats: Dictionary) -> void:
	var node_name := str(node.name)
	if node_name in SkeletonRig.SKILL_SOCKET_NAMES or node_name in FlightRig.SKILL_SOCKET_NAMES or node_name in CrocodileRig.SKILL_SOCKET_NAMES:
		stats["skill_sockets"] = int(stats["skill_sockets"]) + 1
	for prefix in ["LegPivot_", "EarPivot_", "WingPivot_", "TailPivot"]:
		if node_name.begins_with(prefix):
			stats["named_nodes"][prefix] = int(stats["named_nodes"].get(prefix, 0)) + 1
	if node is Skeleton3D:
		stats["skeletons"] = int(stats["skeletons"]) + 1
		var skeleton := node as Skeleton3D
		stats["bones"] = int(stats["bones"]) + skeleton.get_bone_count()
		for paw_name in ["Paw_LF", "Paw_RF", "Paw_LH", "Paw_RH"]:
			if skeleton.find_bone(paw_name) >= 0:
				stats["articulated_paw_bones"] = int(stats["articulated_paw_bones"]) + 1
	if node is AnimationPlayer:
		var imported_actions := {}
		var animation_player := node as AnimationPlayer
		for library_name in animation_player.get_animation_library_list():
			var library := animation_player.get_animation_library(library_name)
			for animation_name in library.get_animation_list():
				imported_actions[str(animation_name).trim_prefix("RESET_")] = true
		for required_action in ["idle", "locomotion", "sprint", "attack", "skill", "hit", "eat", "death"]:
			if imported_actions.has(required_action):
				stats["required_actions"] = int(stats["required_actions"]) + 1
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.visibility_range_end > 0.0:
			stats["lod_meshes"] = int(stats["lod_meshes"]) + 1
			if str(mesh_instance.get_meta("lod_class", "")) == "detail":
				stats["detail_lod_meshes"] = int(stats["detail_lod_meshes"]) + 1
			elif str(mesh_instance.get_meta("lod_class", "")) == "silhouette":
				stats["silhouette_lod_meshes"] = int(stats["silhouette_lod_meshes"]) + 1
		var mesh := mesh_instance.mesh
		if mesh != null:
			if mesh_instance.skin != null:
				stats["skinned_meshes"] = int(stats["skinned_meshes"]) + 1
				if "OrganicBodyV2" in node_name:
					stats["continuous_coat_skinned_meshes"] = int(stats["continuous_coat_skinned_meshes"]) + 1
			stats["meshes"] = int(stats["meshes"]) + 1
			for surface_index in range(mesh.get_surface_count()):
				var arrays := mesh.surface_get_arrays(surface_index)
				if "OrganicBodyV2" in node_name:
					stats["organic_body_islands"] = int(stats["organic_body_islands"]) + _surface_mesh_island_count(arrays)
				if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
					stats["vertices"] = int(stats["vertices"]) + arrays[Mesh.ARRAY_VERTEX].size()
					if mesh_instance.skin != null and arrays.size() > Mesh.ARRAY_WEIGHTS and arrays[Mesh.ARRAY_WEIGHTS] is PackedFloat32Array:
						var vertex_count: int = arrays[Mesh.ARRAY_VERTEX].size()
						var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
						stats["weighted_vertices"] = int(stats["weighted_vertices"]) + vertex_count
						for vertex_index in range(vertex_count):
							var weight_sum := 0.0
							var positive_weights := 0
							for influence_index in range(4):
								var weight := weights[vertex_index * 4 + influence_index]
								weight_sum += weight
								if weight > 0.001:
									positive_weights += 1
							if positive_weights > 1:
								stats["blended_vertices"] = int(stats["blended_vertices"]) + 1
							# ArrayMesh may quantize skin weights on import/export, so accept the
							# renderer-safe one-percent normalization envelope.
							if absf(weight_sum - 1.0) > 0.01:
								stats["invalid_weight_vertices"] = int(stats["invalid_weight_vertices"]) + 1
				var material := mesh_instance.get_active_material(surface_index)
				if material is StandardMaterial3D and not (material as StandardMaterial3D).albedo_color.is_equal_approx(Color.WHITE):
					stats["colored_surfaces"] = int(stats["colored_surfaces"]) + 1
					var material_name := material.resource_name
					for slot_name in ["coat", "feather", "scale", "eye", "nose", "paw", "detail", "accent", "keratin"]:
						if "_%s_pbr" % slot_name in material_name:
							stats["pbr_slots"][slot_name] = true
					if "_coat_pbr" in material_name and (material as StandardMaterial3D).albedo_texture != null and (material as StandardMaterial3D).normal_texture != null and (material as StandardMaterial3D).roughness_texture != null:
						stats["textured_coat_surfaces"] = int(stats["textured_coat_surfaces"]) + 1
				elif material is ShaderMaterial and "_coat_atlas_pbr" in material.resource_name:
					var shader_material := material as ShaderMaterial
					stats["colored_surfaces"] = int(stats["colored_surfaces"]) + 1
					stats["pbr_slots"]["coat"] = true
					if shader_material.get_shader_parameter("albedo_atlas") is Texture2D and shader_material.get_shader_parameter("normal_atlas") is Texture2D and shader_material.get_shader_parameter("roughness_atlas") is Texture2D:
						stats["textured_coat_surfaces"] = int(stats["textured_coat_surfaces"]) + 1
						stats["atlas_coat_surfaces"] = int(stats["atlas_coat_surfaces"]) + 1
	for child in node.get_children():
		_accumulate_external_model_stats(child, stats)


func _surface_mesh_island_count(arrays: Array) -> int:
	if arrays.size() <= Mesh.ARRAY_VERTEX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
		return 0
	var vertex_count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	if vertex_count == 0:
		return 0
	var parents := PackedInt32Array()
	parents.resize(vertex_count)
	for vertex_index in range(vertex_count):
		parents[vertex_index] = vertex_index
	var indices := PackedInt32Array()
	if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	if indices.is_empty():
		indices.resize(vertex_count)
		for vertex_index in range(vertex_count):
			indices[vertex_index] = vertex_index
	for triangle_index in range(0, indices.size() - 2, 3):
		_union_mesh_vertices(parents, indices[triangle_index], indices[triangle_index + 1])
		_union_mesh_vertices(parents, indices[triangle_index + 1], indices[triangle_index + 2])
	var roots := {}
	for vertex_index in range(vertex_count):
		roots[_mesh_vertex_root(parents, vertex_index)] = true
	return roots.size()


func _mesh_vertex_root(parents: PackedInt32Array, vertex_index: int) -> int:
	var root := vertex_index
	while parents[root] != root:
		root = parents[root]
	while parents[vertex_index] != vertex_index:
		var next_index := parents[vertex_index]
		parents[vertex_index] = root
		vertex_index = next_index
	return root


func _union_mesh_vertices(parents: PackedInt32Array, first: int, second: int) -> void:
	if first < 0 or second < 0 or first >= parents.size() or second >= parents.size():
		return
	var first_root := _mesh_vertex_root(parents, first)
	var second_root := _mesh_vertex_root(parents, second)
	if first_root != second_root:
		parents[second_root] = first_root


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


func _validate_ai_tactical_contract() -> void:
	_expect(ActorScript.AI_PACK_SHARE_RADIUS > 0.0 and ActorScript.AI_HERD_SHARE_RADIUS > 0.0, "群猎或群居 AI 没有有限情报距离")
	_expect(ActorScript.AI_GROUP_ALERT_RANGE >= ActorScript.AI_PACK_SHARE_RADIUS, "群体目标警报范围小于成员交流范围")
	_expect(ActorScript.should_abandon_pursuit(0.0, 0.8, 0.8, 0.2, 6.0, 2.0, false), "低效用追击不会中止")
	_expect(not ActorScript.should_abandon_pursuit(0.0, 0.1, 0.1, 1.0, 30.0, 2.0, true), "最终竞争仍可被普通脱战打断")
	_expect(not ActorScript.should_approach_contested_food(1, 0.2, 0.3, 60.0, false, 0), "受伤独行者仍会无视守尸风险")
	_expect(ActorScript.hunting_motivation(18.0, 0.55, "omnivore", 4) < ActorScript.AI_HUNT_MOTIVATION_THRESHOLD, "饱腹的大型杂食者仍会主动清场")
	_expect(ActorScript.hunting_motivation(68.0, 0.55, "omnivore", 4) > ActorScript.AI_HUNT_MOTIVATION_THRESHOLD, "饥饿的大型杂食者不会恢复捕食动机")
	_expect(ActorScript.should_replan_blocked_route(3, false) and not ActorScript.should_replan_blocked_route(3, true), "AI 路线连续失败后不会改道，或终局会错误脱战")
	_expect(not ActorScript.should_escalate_territory_intrusion(true, false, 14.0, 2.0, 16.0), "领地 AI 仍会对远处入侵者跨区追杀")
	var actor_source := FileAccess.get_file_as_string("res://scripts/eco_actor.gd")
	_expect(actor_source.contains("func evaluate_prey_utility") and actor_source.contains("target_pressure_counts"), "AI 猎物选择没有战况效用与第三方压力")
	_expect(actor_source.contains("Catalog.has_trait(species_id, \"pack_hunter\")") and actor_source.contains("shared_pack_target"), "群猎物种没有共享追猎意图")
	_expect(actor_source.contains("Catalog.has_trait(species_id, \"herd_mover\")") and actor_source.contains("group_escape_direction"), "群居物种没有共享危险或逃生方向")
	_expect(actor_source.contains("func _corpse_is_safe") and actor_source.contains("stronger_competitor"), "尸体目标没有竞争风险评估")
	_expect(actor_source.contains("blocked_route_instance_id") and actor_source.contains("func _replan_blocked_route"), "AI 脱困后没有失败目标短期记忆")
	_expect(actor_source.contains("var spacing_weight := 0.46 if _collapse_competition_active()") and actor_source.contains("attack_intent = false"), "终局弱物种没有保留诱导强敌露出破绽的周旋逻辑")
	_expect(actor_source.contains("die(null)") and actor_source.contains("starvation_health_after"), "饥饿伤害无法归零或没有进入统一死亡结算")


func _validate_ecological_habit_contract() -> void:
	_expect(Catalog.ECO_HABITS.size() == Catalog.ORDER.size(), "生态习性没有覆盖全部 30 种动物")
	var rabbit_effect := Catalog.habit_food_effect("rabbit", "grass", "grassland", true, "day", "clear", 0.45, 0)
	_expect(float(rabbit_effect.get("health_ratio", 0.0)) >= 0.115, "雪兔在草原草丛吃草没有获得设计中的回血")
	_expect(float(rabbit_effect.get("stamina_ratio", 0.0)) >= 0.17, "雪兔在草原草丛吃草没有获得设计中的耐力恢复")
	_expect(str(rabbit_effect.get("buff", "")) == "escape", "雪兔吃草没有触发轻捷状态")
	_expect(Catalog.habit_food_effect("rabbit", "fruit", "grassland", true).is_empty(), "雪兔可用非偏好食物错误触发习性")
	_expect(int(rabbit_effect.get("xp_bonus", 0)) >= 4, "完美习性没有提供生态适应经验")
	_expect(Catalog.combat_experience_reward("bear", "rabbit", 1) < Catalog.experience_reward("rabbit", 1), "强物种捕杀弱物种仍会快速滚雪球")
	_expect(Catalog.combat_experience_reward("rabbit", "bear", 1) == Catalog.experience_reward("bear", 1), "弱物种击倒强敌被错误削减经验")
	var actor_source := FileAccess.get_file_as_string("res://scripts/eco_actor.gd")
	_expect(actor_source.contains("habit_rewarded_sources") and actor_source.contains("func _apply_food_habit"), "同一资源缺少生态习性限次结算")
	_expect(actor_source.contains("func _best_habit_food") and actor_source.contains("func _best_habit_corpse") and actor_source.contains("habit_seek_health_ratio"), "低血 AI 不会主动寻找合适的习性资源或尸体")
	_expect(actor_source.contains("func habit_resource_guidance_text") and actor_source.contains("preferred_resource := _best_habit_food") and actor_source.contains("func _best_nearby_food"), "玩家缺少生态本能引导、手动进食习性优先级或真实交互距离回退")
	_expect(actor_source.contains("func _habit_resource_inside_active_area"), "AI 或玩家可能被习性引导到收束圈外资源")
	_expect(actor_source.contains("eat_timer > 0.0 or attack_timer") and actor_source.contains("exhausted or eat_timer > 0.0 or skill_timer") and actor_source.contains("speed *= 0.55"), "进食咀嚼期间仍可全速移动、攻击或释放技能")
	_expect(actor_source.contains("has_habit_buff(\"escape\")") and actor_source.contains("has_habit_buff(\"guard\")") and actor_source.contains("has_habit_buff(\"hunt\")"), "习性短时状态没有接入实际移动或战斗")
	var ui_source := FileAccess.get_file_as_string("res://scripts/game_ui.gd")
	_expect(ui_source.contains("Catalog.habit_description") and ui_source.contains("habit_status_text") and ui_source.contains("生态本能"), "物种简报或 HUD 没有展示生态习性和资源引导")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(main_source.contains("Catalog.combat_experience_reward") and main_source.contains("habit_resource_guidance_text"), "主流程没有接入反滚雪球经验或生态本能")


func _validate_growth_hud_contract() -> void:
	var ui_source := FileAccess.get_file_as_string("res://scripts/game_ui.gd")
	_expect(ui_source.count("_sync_player_status_ranges(player_actor)") >= 2, "玩家升级后 HUD 没有持续同步生命与耐力上限")
	_expect(ui_source.contains("float(player_actor.data[\"regen\"])") and ui_source.contains("恢复 %.1f"), "HUD 没有显示会随等级成长的耐力恢复")
	var actor_source := FileAccess.get_file_as_string("res://scripts/eco_actor.gd")
	_expect(actor_source.contains("\"regen\": float(data[\"regen\"]) - old_regen"), "升级反馈没有传递耐力恢复增量")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(main_source.contains("gains.get(\"regen\""), "玩家升级提示没有显示耐力恢复增量")
	_expect(Catalog.FIRST_LEVEL_BEAR_CHANCE > 0.25 and Catalog.FIRST_LEVEL_BEAR_CHANCE < 0.60, "第一关可选熊穴的出现率不在合理范围")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
