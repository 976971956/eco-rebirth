extends SceneTree

const EXPECTED_VERSION := "1.57.2"
const CASES := [
	{"level": 1, "minimum_fps": 58.0, "maximum_physics_ms": 10.0, "maximum_memory_mib": 120.0},
	{"level": 5, "minimum_fps": 58.0, "maximum_physics_ms": 16.0, "maximum_memory_mib": 135.0},
	{"level": 10, "minimum_fps": 55.0, "maximum_physics_ms": 22.0, "maximum_memory_mib": 150.0},
]

var failures: Array[String] = []


func _initialize() -> void:
	_validate.call_deferred()


func _validate() -> void:
	var report_root := _argument_value("--report-dir")
	if report_root == "":
		report_root = "/tmp/eco-rebirth-performance"
	for test_case in CASES:
		var level := int(test_case["level"])
		var path := "%s/benchmark_level_%02d_medium.json" % [report_root, level]
		if not FileAccess.file_exists(path):
			failures.append("缺少第 %d 关性能报告：%s" % [level, path])
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			failures.append("第 %d 关性能报告不是合法 JSON" % level)
			continue
		var report: Dictionary = parsed
		var fps := float(report.get("wall_fps", 0.0))
		var physics_ms := float(report.get("average_physics_ms", INF))
		var memory_mib := float(report.get("max_static_memory_bytes", INF)) / 1048576.0
		_expect(str(report.get("game_version", "")) == EXPECTED_VERSION, "第 %d 关报告版本不是 %s" % [level, EXPECTED_VERSION])
		_expect(int(report.get("level", 0)) == level and str(report.get("quality", "")) == "medium", "第 %d 关报告关卡或画质不匹配" % level)
		_expect(str(report.get("outcome", "")) == "duration_complete", "第 %d 关性能采样未完整结束" % level)
		_expect(fps >= float(test_case["minimum_fps"]), "第 %d 关 %.1f FPS 低于 %.1f 门槛" % [level, fps, float(test_case["minimum_fps"])])
		_expect(physics_ms <= float(test_case["maximum_physics_ms"]), "第 %d 关物理平均 %.2f ms 超过 %.2f ms 门槛" % [level, physics_ms, float(test_case["maximum_physics_ms"])])
		_expect(memory_mib <= float(test_case["maximum_memory_mib"]), "第 %d 关静态内存 %.1f MiB 超过 %.1f MiB 门槛" % [level, memory_mib, float(test_case["maximum_memory_mib"])])
		print("[performance-gate] L%d · %.1f FPS · physics %.2f ms · memory %.1f MiB" % [level, fps, physics_ms, memory_mib])
	if failures.is_empty():
		print("PERFORMANCE_BASELINE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("[performance-gate] %s" % failure)
		quit(1)


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix + "="):
			return argument.trim_prefix(prefix + "=")
	return ""


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
