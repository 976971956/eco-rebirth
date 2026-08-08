extends SceneTree

const MainScript = preload("res://scripts/main.gd")
const WorldScript = preload("res://scripts/eco_world.gd")
const AudioScript = preload("res://scripts/audio_manager.gd")

var failures: Array[String] = []


func _init() -> void:
	_validate_save_migration()
	_validate_quality_presets()
	_validate_tutorial_contract()
	_validate_free_mode_contract()
	_validate_web_audio_contract()
	if failures.is_empty():
		print("[release] V1.2 发布校验通过：首页自由模式、指定物种、旧存档迁移与 Web 音频正常")
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
