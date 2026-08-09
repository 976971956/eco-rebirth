class_name GameUI
extends CanvasLayer

const JoystickScript = preload("res://scripts/virtual_joystick.gd")
const Catalog = preload("res://scripts/species_catalog.gd")

signal start_requested
signal free_mode_requested(level: int, species_id: String)
signal retry_requested
signal menu_requested
signal pause_requested
signal tutorial_skipped
signal battle_report_opened
signal battle_report_closed
signal orientation_blocked_changed(blocked: bool)

const MENU_MARGIN := Vector4(64.0, 54.0, 64.0, 42.0)
const MOBILE_EDGE_PADDING := Vector4(12.0, 10.0, 12.0, 14.0)
const TOUCH_PREVIEW_PADDING := Vector4(30.0, 12.0, 30.0, 18.0)
const TOUCH_ATTACK_OFFSET := Vector2(-174.0, -166.0)
const TOUCH_ATTACK_SIZE := Vector2(150.0, 150.0)
const TOUCH_SKILL_OFFSET := Vector2(-174.0, -310.0)
const TOUCH_SKILL_SIZE := Vector2(132.0, 132.0)
const TOUCH_EAT_OFFSET := Vector2(-306.0, -224.0)
const TOUCH_EAT_SIZE := Vector2(112.0, 96.0)
const TOUCH_SPRINT_OFFSET := Vector2(-306.0, -116.0)
const TOUCH_SPRINT_SIZE := Vector2(112.0, 96.0)
const HUD_STATUS_BACKGROUND := Color(0.018, 0.09, 0.075, 0.62)
const HUD_INFO_BACKGROUND := Color(0.018, 0.09, 0.075, 0.54)
const HUD_LEADERBOARD_BACKGROUND := Color(0.018, 0.09, 0.075, 0.58)
const HUD_SKILL_BACKGROUND := Color(0.018, 0.09, 0.075, 0.58)
const HUD_TICKER_BACKGROUND := Color(0.055, 0.13, 0.095, 0.64)
const HUD_ENEMY_BACKGROUND := Color(0.13, 0.035, 0.035, 0.70)

var game: Node
var menu_root: Control
var menu_content_margin: MarginContainer
var menu_start_button: Button
var hud_root: Control
var modal_root: Control
var modal_shade: ColorRect
var modal_safe_root: Control
var orientation_root: Control
var touch_root: Control
var joystick
var attack_held: bool = false
var sprint_held: bool = false
var skill_requested: bool = false
var interact_requested: bool = false

var species_label: Label
var combat_stats_label: Label
var hp_bar: ProgressBar
var stamina_bar: ProgressBar
var hunger_bar: ProgressBar
var hp_value_label: Label
var stamina_value_label: Label
var satiety_value_label: Label
var xp_bar: ProgressBar
var xp_value_label: Label
var remaining_label: Label
var leaderboard_panel: PanelContainer
var leaderboard_content: RichTextLabel
var leaderboard_entries: Array[Dictionary] = []
var enemy_panel: PanelContainer
var enemy_name_label: Label
var enemy_status_label: Label
var enemy_hp_bar: ProgressBar
var enemy_hp_value_label: Label
var enemy_target: EcoActor
var enemy_visible_until_msec: int = 0
var threat_label: Label
var seed_label: Label
var region_label: Label
var ecology_event_label: Label
var ecology_activity_label: Label
var skill_label: Label
var skill_hint_label: Label
var skill_bar: ProgressBar
var hint_label: Label
var hint_tween: Tween
var intro_panel: PanelContainer
var intro_title: Label
var intro_body: Label
var intro_controls: Label
var battle_ticker_button: Button
var battle_reports: Array[Dictionary] = []
var battle_ticker_index: int = -1
var battle_ticker_elapsed: float = 0.0
var intro_tween: Tween
var event_feed: RichTextLabel
var event_lines: Array[String] = []
var attack_button: Button
var skill_button: Button
var eat_button: Button
var sprint_button: Button
var settings_from_pause: bool = false
var tutorial_panel: PanelContainer
var tutorial_title: Label
var tutorial_body: Label
var tutorial_progress_label: Label
var orientation_blocked: bool = false
var adaptive_poll_remaining: float = 0.0
var last_safe_margins := Vector4(-1.0, -1.0, -1.0, -1.0)


func setup(game_ref: Node) -> void:
	game = game_ref
	layer = 20
	_build_menu()
	_build_hud()
	_build_modal_root()
	_build_orientation_guard()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_adaptive_layout(true)
	show_menu()


func _process(delta: float) -> void:
	adaptive_poll_remaining -= delta
	if adaptive_poll_remaining <= 0.0:
		adaptive_poll_remaining = 0.45
		_update_adaptive_layout()
	if battle_ticker_button == null or battle_reports.size() <= 1 or not hud_root.visible:
		return
	if game == null or str(game.get("state")) != "playing" or enemy_panel.visible:
		return
	battle_ticker_elapsed += delta
	if battle_ticker_elapsed < 4.0:
		return
	battle_ticker_elapsed = 0.0
	var first_recent_index := maxi(battle_reports.size() - 8, 0)
	battle_ticker_index += 1
	if battle_ticker_index < first_recent_index or battle_ticker_index >= battle_reports.size():
		battle_ticker_index = first_recent_index
	_refresh_battle_ticker()


static func safe_margins_from_rect(viewport_size: Vector2, window_size: Vector2i, safe_area: Rect2i) -> Vector4:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or window_size.x <= 0 or window_size.y <= 0:
		return Vector4.ZERO
	var safe_left := clampi(safe_area.position.x, 0, window_size.x)
	var safe_top := clampi(safe_area.position.y, 0, window_size.y)
	var safe_right := clampi(window_size.x - safe_area.end.x, 0, window_size.x)
	var safe_bottom := clampi(window_size.y - safe_area.end.y, 0, window_size.y)
	return Vector4(
		float(safe_left) * viewport_size.x / float(window_size.x),
		float(safe_top) * viewport_size.y / float(window_size.y),
		float(safe_right) * viewport_size.x / float(window_size.x),
		float(safe_bottom) * viewport_size.y / float(window_size.y)
	)


static func portrait_layout_needed(viewport_size: Vector2, touch_layout: bool) -> bool:
	return touch_layout and viewport_size.y > viewport_size.x


static func touch_rect(viewport_size: Vector2, offset: Vector2, size_value: Vector2) -> Rect2:
	return Rect2(viewport_size + offset, size_value)


func _uses_touch_layout() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or "--touch-preview" in OS.get_cmdline_user_args()


func _font_size(desktop_size: int, touch_size: int) -> int:
	return touch_size if _uses_touch_layout() else desktop_size


func _on_viewport_size_changed() -> void:
	_update_adaptive_layout(true)


func _display_safe_margins() -> Vector4:
	if not _uses_touch_layout():
		return Vector4.ZERO
	var margins := MOBILE_EDGE_PADDING
	if "--touch-preview" in OS.get_cmdline_user_args():
		margins = TOUCH_PREVIEW_PADDING
	if OS.has_feature("mobile"):
		var window_size := DisplayServer.window_get_size()
		var safe_area := DisplayServer.get_display_safe_area()
		var window_position := DisplayServer.window_get_position()
		safe_area.position -= window_position
		var native_margins := safe_margins_from_rect(get_viewport().get_visible_rect().size, window_size, safe_area)
		margins = Vector4(
			maxf(margins.x, native_margins.x), maxf(margins.y, native_margins.y),
			maxf(margins.z, native_margins.z), maxf(margins.w, native_margins.w)
		)
	return margins


func _update_adaptive_layout(force: bool = false) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var margins := _display_safe_margins()
	if force or not margins.is_equal_approx(last_safe_margins):
		last_safe_margins = margins
		if menu_content_margin != null:
			menu_content_margin.add_theme_constant_override("margin_left", roundi(MENU_MARGIN.x + margins.x))
			menu_content_margin.add_theme_constant_override("margin_top", roundi(MENU_MARGIN.y + margins.y))
			menu_content_margin.add_theme_constant_override("margin_right", roundi(MENU_MARGIN.z + margins.z))
			menu_content_margin.add_theme_constant_override("margin_bottom", roundi(MENU_MARGIN.w + margins.w))
		if hud_root != null:
			hud_root.offset_left = margins.x
			hud_root.offset_top = margins.y
			hud_root.offset_right = -margins.z
			hud_root.offset_bottom = -margins.w
		if modal_safe_root != null:
			modal_safe_root.offset_left = margins.x
			modal_safe_root.offset_top = margins.y
			modal_safe_root.offset_right = -margins.z
			modal_safe_root.offset_bottom = -margins.w
	var should_block := portrait_layout_needed(viewport_size, _uses_touch_layout())
	if orientation_root != null:
		orientation_root.visible = should_block
	if should_block != orientation_blocked:
		orientation_blocked = should_block
		orientation_blocked_changed.emit(orientation_blocked)


func is_orientation_blocked() -> bool:
	return orientation_blocked


func _panel_style(color: Color, radius: int = 16, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	return style


func _style_button(button: Button, primary: bool = true) -> void:
	button.custom_minimum_size = Vector2(220.0, 62.0 if _uses_touch_layout() else 58.0)
	button.add_theme_font_size_override("font_size", _font_size(24, 27))
	button.add_theme_color_override("font_color", Color("#f4fff2"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _panel_style(Color("#277452") if primary else Color(0.03, 0.12, 0.11, 0.88), 14, Color(0.57, 0.92, 0.64, 0.5), 1))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#36966a") if primary else Color(0.08, 0.24, 0.21, 0.94), 14, Color(0.72, 1.0, 0.78, 0.8), 2))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#194d3a"), 14, Color("#b8f4b7"), 2))
	button.pressed.connect(_play_ui_sound)


func _play_ui_sound() -> void:
	if game != null and game.has_method("play_ui_sound"):
		game.play_ui_sound()


func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.name = "MainMenu"
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu_root)

	var background := TextureRect.new()
	background.name = "Background"
	background.texture = load("res://assets/ui/menu_background.jpg")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.065, 0.065, 0.38)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(shade)

	menu_content_margin = MarginContainer.new()
	menu_content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_content_margin.add_theme_constant_override("margin_left", int(MENU_MARGIN.x))
	menu_content_margin.add_theme_constant_override("margin_right", int(MENU_MARGIN.z))
	menu_content_margin.add_theme_constant_override("margin_top", int(MENU_MARGIN.y))
	menu_content_margin.add_theme_constant_override("margin_bottom", int(MENU_MARGIN.w))
	menu_root.add_child(menu_content_margin)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	menu_content_margin.add_child(content)

	var eyebrow := Label.new()
	eyebrow.text = "SINGLE-PLAYER ECO ROGUELITE"
	eyebrow.add_theme_font_size_override("font_size", 15)
	eyebrow.add_theme_color_override("font_color", Color("#b7e7b0"))
	content.add_child(eyebrow)

	var title := Label.new()
	title.text = "生态轮回"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color("#f3f3d7"))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "每次成为不同生命 · 每次死亡都是新世界"
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color("#e2eed5"))
	content.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 22
	content.add_child(spacer)

	var start_button := Button.new()
	menu_start_button = start_button
	start_button.text = "开始轮回"
	_style_button(start_button, true)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	start_button.pressed.connect(func(): start_requested.emit())
	content.add_child(start_button)

	var free_button := Button.new()
	free_button.text = "自由模式"
	_style_button(free_button, false)
	free_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	free_button.pressed.connect(show_free_mode)
	content.add_child(free_button)

	var settings_button := Button.new()
	settings_button.text = "游戏设置"
	_style_button(settings_button, false)
	settings_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	settings_button.pressed.connect(func(): show_settings(false))
	content.add_child(settings_button)

	var description := Label.new()
	description.text = "随机物种 · AI 自主互斗 · 程序化森林 · 活到最后"
	description.add_theme_font_size_override("font_size", 16)
	description.add_theme_color_override("font_color", Color(0.86, 0.94, 0.83, 0.86))
	content.add_child(description)

	var platform := Label.new()
	platform.text = "Godot 4 · iOS / Android / Web / Desktop"
	platform.add_theme_font_size_override("font_size", 13)
	platform.add_theme_color_override("font_color", Color(0.75, 0.85, 0.78, 0.70))
	platform.size_flags_vertical = Control.SIZE_EXPAND_FILL
	platform.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	content.add_child(platform)


func _build_hud() -> void:
	var touch_layout := _uses_touch_layout()
	hud_root = Control.new()
	hud_root.name = "HUD"
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)

	var status_panel := PanelContainer.new()
	status_panel.position = Vector2(16, 16) if touch_layout else Vector2(20, 20)
	status_panel.custom_minimum_size = Vector2(360, 270) if touch_layout else Vector2(400, 252)
	status_panel.add_theme_stylebox_override("panel", _panel_style(HUD_STATUS_BACKGROUND, 16, Color(0.48, 0.80, 0.53, 0.48), 1))
	hud_root.add_child(status_panel)
	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 6)
	status_panel.add_child(status_box)
	species_label = Label.new()
	species_label.add_theme_font_size_override("font_size", _font_size(25, 29))
	species_label.add_theme_color_override("font_color", Color("#f4f2d3"))
	status_box.add_child(species_label)
	combat_stats_label = Label.new()
	combat_stats_label.add_theme_font_size_override("font_size", _font_size(15, 18))
	combat_stats_label.add_theme_color_override("font_color", Color("#b9d9bd"))
	status_box.add_child(combat_stats_label)
	hp_bar = _make_bar(Color("#d84d4d"), 100.0)
	hp_value_label = _make_value_label()
	status_box.add_child(_bar_row("生命", hp_bar, hp_value_label))
	stamina_bar = _make_bar(Color("#e5c34f"), 100.0)
	stamina_value_label = _make_value_label()
	status_box.add_child(_bar_row("耐力", stamina_bar, stamina_value_label))
	hunger_bar = _make_bar(Color("#78b85c"), 100.0)
	satiety_value_label = _make_value_label()
	status_box.add_child(_bar_row("饱腹", hunger_bar, satiety_value_label))
	xp_bar = _make_bar(Color("#63aee8"), 45.0)
	xp_value_label = _make_value_label()
	status_box.add_child(_bar_row("经验", xp_bar, xp_value_label))

	remaining_label = Label.new()
	remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remaining_label.add_theme_font_size_override("font_size", _font_size(30, 34))
	remaining_label.add_theme_color_override("font_color", Color("#f4f3d7"))
	remaining_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	remaining_label.position = Vector2(-150, 16) if touch_layout else Vector2(-160, 20)
	remaining_label.size = Vector2(300, 48) if touch_layout else Vector2(320, 46)
	hud_root.add_child(remaining_label)

	battle_ticker_button = Button.new()
	battle_ticker_button.name = "BattleTicker"
	battle_ticker_button.text = "战报 [展开] · 等待生态事件"
	battle_ticker_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	battle_ticker_button.position = Vector2(-160, 70) if touch_layout else Vector2(-220, 70)
	battle_ticker_button.size = Vector2(320, 56) if touch_layout else Vector2(440, 50)
	battle_ticker_button.mouse_filter = Control.MOUSE_FILTER_STOP
	battle_ticker_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	battle_ticker_button.add_theme_font_size_override("font_size", _font_size(16, 19))
	battle_ticker_button.add_theme_color_override("font_color", Color("#f3e5b5"))
	battle_ticker_button.add_theme_stylebox_override("normal", _panel_style(HUD_TICKER_BACKGROUND, 13, Color(0.74, 0.78, 0.40, 0.60), 1))
	battle_ticker_button.add_theme_stylebox_override("hover", _panel_style(Color(0.085, 0.22, 0.15, 0.78), 13, Color(0.92, 0.88, 0.50, 0.84), 2))
	battle_ticker_button.add_theme_stylebox_override("pressed", _panel_style(Color(0.04, 0.10, 0.075, 0.84), 13, Color("#f2df7a"), 2))
	battle_ticker_button.pressed.connect(_play_ui_sound)
	battle_ticker_button.pressed.connect(show_battle_report)
	hud_root.add_child(battle_ticker_button)

	enemy_panel = PanelContainer.new()
	enemy_panel.name = "EnemyHealth"
	enemy_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	enemy_panel.position = Vector2(-160, 70) if touch_layout else Vector2(-220, 70)
	enemy_panel.size = Vector2(320, 110) if touch_layout else Vector2(440, 102)
	enemy_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_panel.add_theme_stylebox_override("panel", _panel_style(HUD_ENEMY_BACKGROUND, 14, Color(0.95, 0.38, 0.32, 0.70), 2))
	hud_root.add_child(enemy_panel)
	var enemy_box := VBoxContainer.new()
	enemy_box.add_theme_constant_override("separation", 4)
	enemy_panel.add_child(enemy_box)
	var enemy_title_row := HBoxContainer.new()
	enemy_box.add_child(enemy_title_row)
	enemy_name_label = Label.new()
	enemy_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_name_label.add_theme_font_size_override("font_size", _font_size(21, 22))
	enemy_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	enemy_name_label.add_theme_color_override("font_color", Color("#fff0df"))
	enemy_title_row.add_child(enemy_name_label)
	enemy_hp_value_label = Label.new()
	enemy_hp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_hp_value_label.add_theme_font_size_override("font_size", _font_size(18, 20))
	enemy_hp_value_label.add_theme_color_override("font_color", Color("#ffd0c4"))
	enemy_title_row.add_child(enemy_hp_value_label)
	enemy_status_label = Label.new()
	enemy_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	enemy_status_label.add_theme_font_size_override("font_size", _font_size(17, 19))
	enemy_status_label.add_theme_color_override("font_color", Color("#edc7b4"))
	enemy_box.add_child(enemy_status_label)
	enemy_hp_bar = _make_bar(Color("#d6534f"), 100.0)
	enemy_hp_bar.custom_minimum_size.y = 17.0
	enemy_box.add_child(enemy_hp_bar)
	enemy_panel.hide()

	var info_panel := PanelContainer.new()
	info_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	info_panel.position = Vector2(-390, 16) if touch_layout else Vector2(-420, 20)
	info_panel.size = Vector2(320, 174) if touch_layout else Vector2(350, 168)
	info_panel.add_theme_stylebox_override("panel", _panel_style(HUD_INFO_BACKGROUND, 14, Color(0.48, 0.80, 0.53, 0.32), 1))
	hud_root.add_child(info_panel)
	var info_box := VBoxContainer.new()
	info_panel.add_child(info_box)
	threat_label = Label.new()
	threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	threat_label.add_theme_font_size_override("font_size", _font_size(20, 22))
	info_box.add_child(threat_label)
	region_label = Label.new()
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	region_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	region_label.add_theme_font_size_override("font_size", _font_size(17, 19))
	region_label.add_theme_color_override("font_color", Color("#cce4a6"))
	info_box.add_child(region_label)
	ecology_event_label = Label.new()
	ecology_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ecology_event_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ecology_event_label.add_theme_font_size_override("font_size", _font_size(15, 17))
	ecology_event_label.add_theme_color_override("font_color", Color("#f0cf78"))
	info_box.add_child(ecology_event_label)
	ecology_activity_label = Label.new()
	ecology_activity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ecology_activity_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ecology_activity_label.add_theme_font_size_override("font_size", _font_size(15, 17))
	ecology_activity_label.add_theme_color_override("font_color", Color("#9bd69b"))
	info_box.add_child(ecology_activity_label)
	seed_label = Label.new()
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	seed_label.add_theme_font_size_override("font_size", _font_size(15, 18))
	seed_label.add_theme_color_override("font_color", Color(0.75, 0.86, 0.78, 0.78))
	info_box.add_child(seed_label)

	leaderboard_panel = PanelContainer.new()
	leaderboard_panel.name = "LevelLeaderboard"
	leaderboard_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	leaderboard_panel.position = Vector2(-390, 198) if touch_layout else Vector2(-420, 196)
	leaderboard_panel.size = Vector2(320, 194) if touch_layout else Vector2(350, 188)
	leaderboard_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leaderboard_panel.add_theme_stylebox_override("panel", _panel_style(HUD_LEADERBOARD_BACKGROUND, 14, Color(0.48, 0.80, 0.53, 0.44), 1))
	hud_root.add_child(leaderboard_panel)
	var leaderboard_box := VBoxContainer.new()
	leaderboard_box.add_theme_constant_override("separation", 4)
	leaderboard_panel.add_child(leaderboard_box)
	var leaderboard_title := Label.new()
	leaderboard_title.text = "等级排行榜"
	leaderboard_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leaderboard_title.add_theme_font_size_override("font_size", _font_size(21, 23))
	leaderboard_title.add_theme_color_override("font_color", Color("#f0e7b5"))
	leaderboard_box.add_child(leaderboard_title)
	leaderboard_content = RichTextLabel.new()
	leaderboard_content.bbcode_enabled = true
	leaderboard_content.fit_content = false
	leaderboard_content.scroll_active = false
	leaderboard_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leaderboard_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	leaderboard_content.add_theme_font_size_override("normal_font_size", _font_size(16, 18))
	leaderboard_content.add_theme_color_override("default_color", Color("#dcebd6"))
	leaderboard_box.add_child(leaderboard_content)

	var skill_panel := PanelContainer.new()
	skill_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skill_panel.position = Vector2(-170, -118) if touch_layout else Vector2(-215, -120)
	skill_panel.size = Vector2(340, 100) if touch_layout else Vector2(430, 98)
	skill_panel.add_theme_stylebox_override("panel", _panel_style(HUD_SKILL_BACKGROUND, 14, Color(0.48, 0.80, 0.53, 0.36), 1))
	hud_root.add_child(skill_panel)
	var skill_box := VBoxContainer.new()
	skill_panel.add_child(skill_box)
	skill_label = Label.new()
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_label.add_theme_font_size_override("font_size", _font_size(19, 22))
	skill_box.add_child(skill_label)
	skill_hint_label = Label.new()
	skill_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_hint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	skill_hint_label.add_theme_font_size_override("font_size", _font_size(14, 17))
	skill_hint_label.add_theme_color_override("font_color", Color(0.82, 0.91, 0.84, 0.88))
	skill_box.add_child(skill_hint_label)
	skill_bar = _make_bar(Color("#5db98a"), 1.0)
	skill_bar.custom_minimum_size.y = 10.0
	skill_box.add_child(skill_bar)

	event_feed = RichTextLabel.new()
	event_feed.bbcode_enabled = true
	event_feed.fit_content = false
	event_feed.scroll_active = false
	event_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_feed.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	event_feed.position = Vector2(20, -154)
	event_feed.size = Vector2(380, 130)
	event_feed.add_theme_font_size_override("normal_font_size", _font_size(17, 19))
	event_feed.add_theme_color_override("default_color", Color(0.93, 0.96, 0.88, 0.85))
	hud_root.add_child(event_feed)

	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.clip_text = true
	hint_label.set_anchors_preset(Control.PRESET_CENTER)
	hint_label.position = Vector2(-270, 68) if touch_layout else Vector2(-300, 92)
	hint_label.size = Vector2(540, 76) if touch_layout else Vector2(600, 58)
	hint_label.add_theme_font_size_override("font_size", _font_size(19, 24))
	hint_label.add_theme_color_override("font_color", Color("#f6f0c9"))
	hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	hint_label.add_theme_constant_override("shadow_offset_x", 2)
	hint_label.add_theme_constant_override("shadow_offset_y", 2)
	hud_root.add_child(hint_label)

	var pause_button := Button.new()
	pause_button.text = "Ⅱ"
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-64, 16) if touch_layout else Vector2(-68, 20)
	pause_button.size = Vector2(56, 56)
	pause_button.add_theme_font_size_override("font_size", _font_size(18, 24))
	pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_button.add_theme_stylebox_override("normal", _panel_style(Color(0.02, 0.10, 0.085, 0.54), 14, Color(0.62, 0.93, 0.64, 0.46), 1))
	pause_button.add_theme_stylebox_override("hover", _panel_style(Color(0.04, 0.18, 0.13, 0.76), 14, Color(0.72, 1.0, 0.78, 0.78), 2))
	pause_button.add_theme_stylebox_override("pressed", _panel_style(Color(0.02, 0.09, 0.07, 0.84), 14, Color("#b8f4b7"), 2))
	pause_button.pressed.connect(_play_ui_sound)
	pause_button.pressed.connect(func(): pause_requested.emit())
	hud_root.add_child(pause_button)

	_build_intro()
	_build_tutorial()
	_build_touch_controls()


func _make_bar(fill_color: Color, maximum: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maximum
	bar.value = maximum
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(160, 18) if _uses_touch_layout() else Vector2(190, 15)
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.0, 0.0, 0.0, 0.30)))
	bar.add_theme_stylebox_override("fill", _bar_style(fill_color))
	return bar


func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


func _bar_row(title: String, bar: ProgressBar, value_label: Label = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 48 if _uses_touch_layout() else 52
	label.add_theme_font_size_override("font_size", _font_size(17, 19))
	row.add_child(label)
	row.add_child(bar)
	if value_label != null:
		row.add_child(value_label)
	return row


func _make_value_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size.x = 70.0 if _uses_touch_layout() else 78.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", _font_size(15, 18))
	label.add_theme_color_override("font_color", Color("#edf6e8"))
	return label


func _build_intro() -> void:
	var touch_layout := _uses_touch_layout()
	intro_panel = PanelContainer.new()
	intro_panel.set_anchors_preset(Control.PRESET_CENTER_TOP if touch_layout else Control.PRESET_CENTER)
	intro_panel.position = Vector2(-400, 40) if touch_layout else Vector2(-390, -220)
	intro_panel.size = Vector2(640, 410) if touch_layout else Vector2(780, 440)
	intro_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.10, 0.085, 0.94), 24, Color(0.61, 0.92, 0.61, 0.62), 2))
	hud_root.add_child(intro_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	intro_panel.add_child(box)
	var eyebrow := Label.new()
	eyebrow.text = "本次轮回"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 15)
	eyebrow.add_theme_color_override("font_color", Color("#8fd898"))
	box.add_child(eyebrow)
	intro_title = Label.new()
	intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_title.add_theme_font_size_override("font_size", _font_size(38, 40))
	intro_title.add_theme_color_override("font_color", Color("#f4f0cd"))
	box.add_child(intro_title)
	intro_body = Label.new()
	intro_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	intro_body.add_theme_font_size_override("font_size", _font_size(18, 20))
	intro_body.add_theme_color_override("font_color", Color("#dfecd9"))
	box.add_child(intro_body)
	intro_controls = Label.new()
	intro_controls.text = "WASD / 摇杆移动　Shift 冲刺　按住攻击　空格释放技能　E 进食"
	intro_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_controls.add_theme_font_size_override("font_size", _font_size(17, 19))
	intro_controls.add_theme_color_override("font_color", Color(0.75, 0.86, 0.75, 0.82))
	box.add_child(intro_controls)


func _build_tutorial() -> void:
	var touch_layout := _uses_touch_layout()
	tutorial_panel = PanelContainer.new()
	tutorial_panel.name = "Tutorial"
	tutorial_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tutorial_panel.position = Vector2(-300, 142) if touch_layout else Vector2(-280, 155)
	tutorial_panel.size = Vector2(600, 190) if touch_layout else Vector2(560, 162)
	tutorial_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.09, 0.075, 0.95), 18, Color(0.86, 0.79, 0.39, 0.72), 2))
	hud_root.add_child(tutorial_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	tutorial_panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	tutorial_title = Label.new()
	tutorial_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_title.add_theme_font_size_override("font_size", _font_size(23, 25))
	tutorial_title.add_theme_color_override("font_color", Color("#f4e7a7"))
	header.add_child(tutorial_title)
	tutorial_progress_label = Label.new()
	tutorial_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tutorial_progress_label.add_theme_font_size_override("font_size", _font_size(17, 19))
	tutorial_progress_label.add_theme_color_override("font_color", Color("#bdd9b8"))
	header.add_child(tutorial_progress_label)
	tutorial_body = Label.new()
	tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tutorial_body.add_theme_font_size_override("font_size", _font_size(18, 20))
	tutorial_body.add_theme_color_override("font_color", Color("#edf3df"))
	box.add_child(tutorial_body)
	var skip_button := Button.new()
	skip_button.text = "跳过教学"
	skip_button.custom_minimum_size = Vector2(152, 52)
	skip_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip_button.add_theme_font_size_override("font_size", _font_size(17, 20))
	skip_button.add_theme_color_override("font_color", Color("#edf4de"))
	skip_button.add_theme_stylebox_override("normal", _panel_style(Color(0.08, 0.22, 0.18, 0.94), 10, Color(0.64, 0.83, 0.52, 0.46), 1))
	skip_button.add_theme_stylebox_override("hover", _panel_style(Color(0.12, 0.32, 0.25, 0.98), 10, Color(0.78, 0.92, 0.62, 0.72), 1))
	skip_button.pressed.connect(_play_ui_sound)
	skip_button.pressed.connect(func(): tutorial_skipped.emit())
	box.add_child(skip_button)
	tutorial_panel.hide()


func _build_touch_controls() -> void:
	touch_root = Control.new()
	touch_root.name = "TouchControls"
	touch_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(touch_root)
	joystick = JoystickScript.new()
	joystick.anchor_left = 0.0
	joystick.anchor_top = 0.38
	joystick.anchor_right = 0.52
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 0.0
	joystick.offset_top = 0.0
	joystick.offset_right = 0.0
	joystick.offset_bottom = 0.0
	touch_root.add_child(joystick)

	attack_button = _make_touch_button("攻击", TOUCH_ATTACK_OFFSET, TOUCH_ATTACK_SIZE, Color("#a94c45"))
	attack_button.button_down.connect(func(): attack_held = true)
	attack_button.button_up.connect(func(): attack_held = false)
	skill_button = _make_touch_button("技能", TOUCH_SKILL_OFFSET, TOUCH_SKILL_SIZE, Color("#338c68"))
	skill_button.pressed.connect(func(): skill_requested = true)
	eat_button = _make_touch_button("进食", TOUCH_EAT_OFFSET, TOUCH_EAT_SIZE, Color("#6b863b"))
	eat_button.pressed.connect(func(): interact_requested = true)
	sprint_button = _make_touch_button("冲刺", TOUCH_SPRINT_OFFSET, TOUCH_SPRINT_SIZE, Color("#9d7f34"))
	sprint_button.button_down.connect(func(): sprint_held = true)
	sprint_button.button_up.connect(func(): sprint_held = false)


func _make_touch_button(text_value: String, offset: Vector2, size_value: Vector2, color: Color, right_anchor: bool = true) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT if right_anchor else Control.PRESET_BOTTOM_LEFT)
	button.position = offset
	button.size = size_value
	button.add_theme_font_size_override("font_size", _font_size(24, 28))
	button.add_theme_stylebox_override("normal", _panel_style(Color(color, 0.78), 42, Color(1, 1, 1, 0.42), 3))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(color.lightened(0.18), 0.96), 42, Color(1, 1, 1, 0.78), 4))
	touch_root.add_child(button)
	return button


func _build_modal_root() -> void:
	modal_root = Control.new()
	modal_root.name = "ModalRoot"
	modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal_root)
	modal_shade = ColorRect.new()
	modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_root.add_child(modal_shade)
	modal_safe_root = Control.new()
	modal_safe_root.name = "SafeContent"
	modal_safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_safe_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_root.add_child(modal_safe_root)
	modal_root.hide()


func _build_orientation_guard() -> void:
	orientation_root = Control.new()
	orientation_root.name = "OrientationGuard"
	orientation_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	orientation_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(orientation_root)
	var shade := ColorRect.new()
	shade.color = Color(0.006, 0.025, 0.022, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	orientation_root.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-450, -230)
	panel.size = Vector2(900, 460)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.10, 0.085, 0.99), 28, Color(0.62, 0.93, 0.64, 0.72), 3))
	orientation_root.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var rotate_icon := Label.new()
	rotate_icon.text = "90°"
	rotate_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate_icon.add_theme_font_size_override("font_size", 100)
	rotate_icon.add_theme_color_override("font_color", Color("#92e1a0"))
	box.add_child(rotate_icon)
	var title := Label.new()
	title.text = "请横向握持手机"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color("#f5efc8"))
	box.add_child(title)
	var hint := Label.new()
	hint.text = "旋转到横屏后会自动继续，当前生态世界已经暂停。"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 36)
	hint.add_theme_color_override("font_color", Color("#c8ddc4"))
	box.add_child(hint)
	orientation_root.hide()


func _clear_modal_content(shade_color: Color) -> void:
	for child in modal_safe_root.get_children():
		child.queue_free()
	modal_shade.color = shade_color
	modal_root.show()


func _add_modal_panel(panel: PanelContainer, desired_size: Vector2) -> void:
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var available_size := modal_safe_root.size - Vector2(24.0, 24.0)
	var panel_size := Vector2(minf(desired_size.x, available_size.x), minf(desired_size.y, available_size.y))
	panel.position = -panel_size * 0.5
	panel.size = panel_size
	modal_safe_root.add_child(panel)


func show_menu() -> void:
	_cancel_intro_tween()
	if intro_panel != null:
		intro_panel.hide()
	if menu_start_button != null and game != null:
		menu_start_button.text = game.menu_start_text() if game.has_method("menu_start_text") else ("继续轮回" if game.has_campaign_progress() else "开始轮回")
	menu_root.show()
	hud_root.hide()
	modal_root.hide()
	hide_tutorial()
	clear_enemy_health()
	attack_held = false
	sprint_held = false


func show_hud(player_actor: EcoActor, world_seed: int, threat_level: int, level: int = 1, free_mode: bool = false) -> void:
	menu_root.hide()
	hud_root.show()
	modal_root.hide()
	hide_tutorial()
	clear_enemy_health()
	var touch_available := _uses_touch_layout()
	touch_root.visible = touch_available
	event_feed.visible = not touch_available
	seed_label.text = "世界种子 %s" % world_seed
	ecology_event_label.text = "生态热点 · 正在等待迁徙信号"
	ecology_activity_label.text = "迁徙监测 · 尚无活动"
	threat_label.text = "第%d关 · 自由模式" % level if free_mode else "第%d关 · 世界威胁 %d" % [level, threat_level]
	_reset_live_information()
	set_player(player_actor)


func show_tutorial_step(step: int, total: int, title_text: String, body_text: String) -> void:
	if tutorial_panel == null:
		return
	tutorial_title.text = title_text
	tutorial_progress_label.text = "教学 %d / %d" % [step, total]
	tutorial_body.text = body_text
	tutorial_panel.modulate = Color.WHITE
	tutorial_panel.move_to_front()
	tutorial_panel.show()


func hide_tutorial() -> void:
	if tutorial_panel != null:
		tutorial_panel.hide()


func _reset_live_information() -> void:
	leaderboard_entries.clear()
	battle_reports.clear()
	battle_ticker_index = -1
	battle_ticker_elapsed = 0.0
	if leaderboard_content != null:
		leaderboard_content.text = "[center][color=#9fb9a2]正在统计生态个体…[/color][/center]"
	if battle_ticker_button != null:
		battle_ticker_button.text = "战报 [展开] · 等待生态事件"
		battle_ticker_button.show()
	event_lines.clear()
	if event_feed != null:
		event_feed.clear()


func set_player(player_actor: EcoActor) -> void:
	var data := Catalog.get_data(player_actor.species_id)
	species_label.text = "Lv.%d %s · %s" % [player_actor.level, data["name"], data["subtitle"]]
	_update_player_combat_summary(player_actor)
	hp_bar.max_value = player_actor.max_health
	stamina_bar.max_value = player_actor.max_stamina
	hp_bar.value = player_actor.health
	stamina_bar.value = player_actor.stamina
	hunger_bar.value = 100.0 - player_actor.hunger
	xp_bar.max_value = maxf(float(player_actor.experience_to_next_level()), 1.0)
	xp_bar.value = player_actor.experience
	skill_label.text = "%s　[空格]" % data["skill"]
	skill_hint_label.text = str(data["skill_hint"])
	var skill_color := Color.from_string(str(data.get("skill_color", "#5db98a")), Color("#5db98a"))
	skill_label.add_theme_color_override("font_color", skill_color.lightened(0.18))
	skill_bar.max_value = float(data["skill_cooldown"])
	skill_bar.value = float(data["skill_cooldown"])
	skill_button.text = "%s\n就绪" % str(data["skill"])
	skill_button.add_theme_stylebox_override("normal", _panel_style(Color(skill_color.darkened(0.34), 0.88), 42, Color(skill_color.lightened(0.35), 0.72), 3))
	skill_button.add_theme_stylebox_override("pressed", _panel_style(Color(skill_color.lightened(0.06), 0.98), 42, Color.WHITE, 4))


func show_species_intro(species_id: String) -> void:
	_cancel_intro_tween()
	var data := Catalog.get_data(species_id)
	var touch_layout := _uses_touch_layout()
	intro_title.text = "%s · %s" % [data["name"], data["subtitle"]]
	intro_controls.text = ("左侧动态摇杆移动　右侧冲刺 / 攻击 / 技能 / 进食" if touch_layout else "WASD / 方向键移动　Shift 冲刺　按住攻击　空格释放技能　E 进食") + "\n黄色可逆袭目标：抓住强敌的低耐力、技能后摇或伏击窗口\n环境反制：在适应区域持续移动蓄势，把客场强敌引入主场后反击\n反制组合：%s" % Catalog.counterplay_plan(species_id)
	intro_body.text = "基础数值：生命 %d　攻击 %.1f　速度 %.2f　耐力 %d　护甲 %.1f\n%s\n%s\n被动：%s — %s\n主动技能：%s — %s\n\n获胜攻略：%s" % [
		int(data["health"]), float(data["attack"]), float(data["speed"]), int(data["stamina"]), float(data["armor"]),
		Catalog.growth_description(species_id), Catalog.habitat_description(species_id), data["passive"], data["passive_hint"], data["skill"], data["skill_hint"], Catalog.victory_guide(species_id)
	]
	intro_panel.modulate = Color.WHITE
	intro_panel.move_to_front()
	intro_panel.show()
	intro_tween = create_tween()
	intro_tween.tween_interval(8.0)
	intro_tween.tween_property(intro_panel, "modulate", Color(1, 1, 1, 0), 0.6)
	intro_tween.tween_callback(intro_panel.hide)


func _cancel_intro_tween() -> void:
	if intro_tween != null and intro_tween.is_valid():
		intro_tween.kill()
	intro_tween = null


func update_hud(player_actor: EcoActor, remaining: int, total: int = 10, current_region: String = "未知区域", ecology_event_status: String = "", ecology_activity_status: String = "") -> void:
	if not hud_root.visible or not is_instance_valid(player_actor):
		return
	hp_bar.value = maxf(player_actor.health, 0.0)
	stamina_bar.value = player_actor.stamina
	var satiety := clampf(100.0 - player_actor.hunger, 0.0, 100.0)
	hunger_bar.value = satiety
	hp_value_label.text = "%d / %d" % [maxi(ceili(player_actor.health), 0), ceili(player_actor.max_health)]
	stamina_value_label.text = "%d / %d" % [maxi(ceili(player_actor.stamina), 0), ceili(player_actor.max_stamina)]
	satiety_value_label.text = "%d / 100" % ceili(satiety)
	species_label.text = "Lv.%d %s · %s" % [player_actor.level, player_actor.data["name"], player_actor.data["subtitle"]]
	_update_player_combat_summary(player_actor)
	var needed_xp := player_actor.experience_to_next_level()
	xp_bar.max_value = maxf(float(needed_xp), 1.0)
	xp_bar.value = player_actor.experience if needed_xp > 0 else 1.0
	xp_value_label.text = ("最高等级" if needed_xp <= 0 else "%d / %d" % [player_actor.experience, needed_xp])
	remaining_label.text = "存活个体　%d / %d" % [remaining, total]
	region_label.text = "当前位置 · %s" % current_region
	ecology_event_label.text = ecology_event_status
	ecology_activity_label.text = ecology_activity_status
	var activity_color := Color("#ef7d68") if ecology_activity_status.contains("高危") else (Color("#f0cf78") if ecology_activity_status.contains("警戒") else Color("#9bd69b"))
	ecology_activity_label.add_theme_color_override("font_color", activity_color)
	var cooldown := float(player_actor.data["skill_cooldown"])
	var cooldown_remaining := player_actor.skill_timer
	skill_bar.max_value = cooldown
	skill_bar.value = cooldown - cooldown_remaining
	var skill_ready := cooldown_remaining <= 0.0 and not player_actor.exhausted and player_actor.stamina >= float(player_actor.data["skill_cost"])
	var skill_state := "力竭" if player_actor.exhausted else ("就绪" if skill_ready else ("耐力不足" if cooldown_remaining <= 0.0 else "%.1fs" % cooldown_remaining))
	skill_label.text = "%s　%s" % [player_actor.data["skill"], skill_state]
	skill_button.text = "%s\n%s" % [player_actor.data["skill"], skill_state]
	skill_button.modulate = Color.WHITE if skill_ready else Color(0.72, 0.76, 0.74, 0.88)
	_update_enemy_health_display()


func _update_player_combat_summary(player_actor: EcoActor) -> void:
	var tactical_status := ""
	var tactical_color := Color("#b9d9bd")
	var ecology_status := player_actor.ecology_leverage_status_text()
	var chain_status := player_actor.counterplay_chain_status_text()
	if player_actor.exhausted:
		tactical_status = "力竭破绽"
		tactical_color = Color("#f1d46b")
	elif player_actor.is_opportunity_exposed():
		tactical_status = player_actor.opportunity_status_text()
		tactical_color = Color("#f1d46b")
	elif player_actor.counterplay_mastery_timer > 0.0:
		tactical_status = chain_status
		tactical_color = Color("#ffb86b")
	elif player_actor.has_cover_ambush():
		tactical_status = "伏击就绪 · 首击可逆袭强敌"
		tactical_color = Color("#8fe8b7")
	elif player_actor.has_terrain_momentum():
		tactical_status = player_actor.tactical_terrain_status_text()
		tactical_color = Color("#70cfe8")
	elif ecology_status != "":
		tactical_status = ecology_status
		tactical_color = Color("#d7a2f2")
	elif chain_status != "":
		tactical_status = chain_status
		tactical_color = Color("#ffcf8c")
	elif player_actor.tactical_cover_status_text() != "":
		tactical_status = player_actor.tactical_cover_status_text()
		tactical_color = Color("#73d4c0")
	elif player_actor.tactical_terrain_status_text() != "":
		tactical_status = player_actor.tactical_terrain_status_text()
		tactical_color = Color("#8fc9d8")
	combat_stats_label.text = "攻击 %.1f　速度 %.2f　护甲 %.1f%s" % [
		float(player_actor.data["attack"]), float(player_actor.data["speed"]), float(player_actor.data["armor"]),
		"\n%s" % tactical_status if tactical_status != "" else "",
	]
	combat_stats_label.add_theme_color_override("font_color", tactical_color)


func update_leaderboard(entries: Array[Dictionary]) -> void:
	leaderboard_entries = entries.duplicate(true)
	if leaderboard_content == null:
		return
	leaderboard_content.clear()
	var visible_entries: Array[Dictionary] = []
	var top_count := mini(5, leaderboard_entries.size())
	for index in range(top_count):
		visible_entries.append(leaderboard_entries[index])
	var player_entry: Dictionary = {}
	for entry in leaderboard_entries:
		if bool(entry.get("is_player", false)):
			player_entry = entry
			break
	if not player_entry.is_empty() and int(player_entry.get("rank", 0)) > top_count:
		if visible_entries.size() >= 5:
			visible_entries.resize(4)
		visible_entries.append(player_entry)
	for entry in visible_entries:
		var is_player_entry := bool(entry.get("is_player", false))
		var row_color := "#f4df7b" if int(entry.get("rank", 0)) == 1 else ("#8fe0b0" if is_player_entry else "#dcebd6")
		var player_mark := "你·" if is_player_entry else ""
		leaderboard_content.append_text("[color=%s]%d　Lv.%d　%s%s　%d击杀[/color]\n" % [
			row_color, int(entry.get("rank", 0)), int(entry.get("level", 1)), player_mark,
			str(entry.get("name", "未知")), int(entry.get("kills", 0)),
		])


func add_battle_report(text_value: String, category: String = "战斗", color_hex: String = "#ecc89d") -> void:
	var elapsed_seconds := 0
	if game != null and game.get("level_elapsed") != null:
		elapsed_seconds = maxi(int(float(game.get("level_elapsed"))), 0)
	battle_reports.append({
		"time": elapsed_seconds,
		"category": category,
		"text": text_value,
		"color": color_hex,
	})
	if battle_reports.size() > 60:
		battle_reports.pop_front()
	battle_ticker_index = battle_reports.size() - 1
	battle_ticker_elapsed = 0.0
	_refresh_battle_ticker()


func _refresh_battle_ticker() -> void:
	if battle_ticker_button == null or battle_reports.is_empty():
		return
	battle_ticker_index = clampi(battle_ticker_index, 0, battle_reports.size() - 1)
	var report: Dictionary = battle_reports[battle_ticker_index]
	battle_ticker_button.text = "战报 [展开] · %s %s · %s" % [
		_format_report_time(int(report.get("time", 0))), str(report.get("category", "战斗")), str(report.get("text", "")),
	]


func show_battle_report() -> void:
	battle_report_opened.emit()
	_clear_modal_content(Color(0.006, 0.025, 0.022, 0.90))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.095, 0.078, 0.99), 24, Color(0.72, 0.86, 0.48, 0.68), 2))
	_add_modal_panel(panel, Vector2(1000, 620))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "生态战况"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _font_size(38, 43))
	title.add_theme_color_override("font_color", Color("#f4edc5"))
	box.add_child(title)
	var summary := Label.new()
	var player_rank := 0
	for entry in leaderboard_entries:
		if bool(entry.get("is_player", false)):
			player_rank = int(entry.get("rank", 0))
			break
	summary.text = "已记录 %d 条关键战报　·　玩家当前等级排名 %s" % [battle_reports.size(), (str(player_rank) if player_rank > 0 else "--")]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", _font_size(17, 20))
	summary.add_theme_color_override("font_color", Color("#b9d5b7"))
	box.add_child(summary)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	box.add_child(columns)
	var report_panel := PanelContainer.new()
	report_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.006, 0.045, 0.038, 0.90), 16, Color(0.40, 0.68, 0.44, 0.38), 1))
	columns.add_child(report_panel)
	var report_log := RichTextLabel.new()
	report_log.bbcode_enabled = true
	report_log.scroll_active = true
	report_log.scroll_following = false
	report_log.mouse_filter = Control.MOUSE_FILTER_STOP
	report_log.add_theme_font_size_override("normal_font_size", _font_size(18, 20))
	report_panel.add_child(report_log)
	if battle_reports.is_empty():
		report_log.append_text("[center][color=#9fb9a2]还没有关键战斗事件。[/color][/center]")
	else:
		for report_index in range(battle_reports.size() - 1, -1, -1):
			var report: Dictionary = battle_reports[report_index]
			report_log.append_text("[color=#91a999]%s[/color]　[color=%s][%s] %s[/color]\n\n" % [
				_format_report_time(int(report.get("time", 0))), str(report.get("color", "#dcebd6")),
				str(report.get("category", "战斗")), str(report.get("text", "")),
			])
	var rank_panel := PanelContainer.new()
	rank_panel.custom_minimum_size = Vector2(292, 0)
	rank_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.006, 0.045, 0.038, 0.90), 16, Color(0.40, 0.68, 0.44, 0.38), 1))
	columns.add_child(rank_panel)
	var rank_box := VBoxContainer.new()
	rank_box.add_theme_constant_override("separation", 8)
	rank_panel.add_child(rank_box)
	var rank_title := Label.new()
	rank_title.text = "完整等级排名"
	rank_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_title.add_theme_font_size_override("font_size", _font_size(21, 23))
	rank_title.add_theme_color_override("font_color", Color("#f0e7b5"))
	rank_box.add_child(rank_title)
	var rank_log := RichTextLabel.new()
	rank_log.bbcode_enabled = true
	rank_log.scroll_active = true
	rank_log.mouse_filter = Control.MOUSE_FILTER_STOP
	rank_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rank_log.add_theme_font_size_override("normal_font_size", _font_size(17, 19))
	rank_box.add_child(rank_log)
	for entry in leaderboard_entries:
		var row_color := "#f4df7b" if int(entry.get("rank", 0)) == 1 else ("#8fe0b0" if bool(entry.get("is_player", false)) else "#dcebd6")
		rank_log.append_text("[color=%s]%d. Lv.%d　%s%s　%d击杀[/color]\n" % [
			row_color, int(entry.get("rank", 0)), int(entry.get("level", 1)),
			("你·" if bool(entry.get("is_player", false)) else ""), str(entry.get("name", "未知")), int(entry.get("kills", 0)),
		])
	var close_button := Button.new()
	close_button.text = "返回生态战场"
	_style_button(close_button, true)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(hide_battle_report)
	box.add_child(close_button)


func hide_battle_report() -> void:
	modal_root.hide()
	battle_report_closed.emit()


func _format_report_time(seconds_value: int) -> String:
	return "%02d:%02d" % [seconds_value / 60, seconds_value % 60]


func show_enemy_health(target: EcoActor) -> void:
	if enemy_panel == null or not is_instance_valid(target) or target.dead:
		return
	enemy_target = target
	enemy_visible_until_msec = Time.get_ticks_msec() + 4200
	if battle_ticker_button != null:
		battle_ticker_button.hide()
	enemy_panel.show()
	_refresh_enemy_health()


func clear_enemy_health() -> void:
	enemy_target = null
	enemy_visible_until_msec = 0
	if enemy_panel != null:
		enemy_panel.hide()
	if battle_ticker_button != null and hud_root.visible:
		battle_ticker_button.show()


func _update_enemy_health_display() -> void:
	if enemy_panel == null or not enemy_panel.visible:
		return
	if not is_instance_valid(enemy_target) or Time.get_ticks_msec() > enemy_visible_until_msec:
		clear_enemy_health()
		return
	_refresh_enemy_health()


func _refresh_enemy_health() -> void:
	if not is_instance_valid(enemy_target):
		return
	var target_data := Catalog.get_data(enemy_target.species_id)
	var player_actor := game.get("player") as EcoActor if game != null else null
	var status_parts: Array[String] = []
	if enemy_target.poison_timer > 0.0:
		status_parts.append("中毒 %.1fs" % enemy_target.poison_timer)
	if enemy_target.scent_mark_timer > 0.0:
		status_parts.append("血味 %.1fs" % enemy_target.scent_mark_timer)
	if is_instance_valid(player_actor) and enemy_target.ecology_influence_source == player_actor and enemy_target.ecology_influence_timer > 0.0:
		status_parts.append("%s %.1fs" % [enemy_target.ecology_influence_reason, enemy_target.ecology_influence_timer])
	if enemy_target.slow_timer > 0.0:
		status_parts.append("减速")
	if enemy_target.panic_timer > 0.0:
		status_parts.append("受惊")
	if enemy_target.is_cover_concealed():
		status_parts.append("草丛隐蔽")
	if is_instance_valid(player_actor):
		var chain_status := player_actor.counterplay_chain_status_text(enemy_target)
		if chain_status != "":
			status_parts.append(chain_status)
	var threat_gap := Catalog.opportunity_threat_gap(player_actor.species_id, enemy_target.species_id) if is_instance_valid(player_actor) else 0
	var can_ambush_strike := is_instance_valid(player_actor) and threat_gap > 0 and player_actor.has_cover_ambush()
	var can_terrain_strike := is_instance_valid(player_actor) and threat_gap > 0 and player_actor.can_terrain_counter(enemy_target)
	var leverage_responder := player_actor.ecology_leverage_candidate(enemy_target) if is_instance_valid(player_actor) and threat_gap > 0 else null
	var can_ecology_leverage := is_instance_valid(leverage_responder)
	var can_opportunity_strike := threat_gap > 0 and (enemy_target.is_opportunity_exposed() or can_ambush_strike or can_terrain_strike)
	if enemy_target.is_opportunity_exposed():
		status_parts.append(("可逆袭 · " if can_opportunity_strike else "") + enemy_target.opportunity_status_text())
	elif can_ambush_strike:
		status_parts.append("伏击可逆袭")
	elif can_terrain_strike:
		status_parts.append("地形可逆袭")
	elif can_ecology_leverage:
		status_parts.append("可生态借力 · 引向%s" % Catalog.display_name(leverage_responder.species_id))
	var terrain_highlight := can_terrain_strike and not enemy_target.is_opportunity_exposed() and not can_ambush_strike
	var ecology_highlight := can_ecology_leverage and not can_opportunity_strike
	var opportunity_color := Color("#d7a2f2") if ecology_highlight else (Color("#70cfe8") if terrain_highlight else Color("#ffe078"))
	var highlighted := can_opportunity_strike or ecology_highlight
	enemy_name_label.text = "Lv.%d %s" % [enemy_target.level, target_data["name"]]
	enemy_status_label.text = " / ".join(status_parts) if not status_parts.is_empty() else "状态稳定"
	enemy_name_label.add_theme_color_override("font_color", opportunity_color if highlighted else Color("#fff0df"))
	enemy_status_label.add_theme_color_override("font_color", opportunity_color if highlighted else Color("#edc7b4"))
	enemy_panel.add_theme_stylebox_override("panel", _panel_style(
		(Color(0.12, 0.055, 0.16, 0.78) if ecology_highlight else (Color(0.025, 0.11, 0.15, 0.78) if terrain_highlight else Color(0.14, 0.10, 0.025, 0.76))) if highlighted else HUD_ENEMY_BACKGROUND,
		14,
		opportunity_color if highlighted else Color(0.95, 0.38, 0.32, 0.70),
		2
	))
	enemy_hp_bar.max_value = maxf(enemy_target.max_health, 1.0)
	enemy_hp_bar.value = maxf(enemy_target.health, 0.0)
	enemy_hp_bar.add_theme_stylebox_override("fill", _bar_style(Color("#b77bd6") if ecology_highlight else (Color("#58bcd8") if terrain_highlight else (Color("#e8b93f") if can_opportunity_strike else Color("#d6534f")))))
	enemy_hp_value_label.text = "%d / %d" % [ceili(maxf(enemy_target.health, 0.0)), ceili(enemy_target.max_health)]


func show_hint(text_value: String) -> void:
	hint_label.text = text_value
	hint_label.modulate = Color.WHITE
	if hint_tween != null and hint_tween.is_valid():
		hint_tween.kill()
	hint_tween = create_tween()
	hint_tween.tween_interval(1.6)
	hint_tween.tween_property(hint_label, "modulate", Color(1, 1, 1, 0), 0.45)


func add_event(text_value: String, color_hex: String = "#dcebd6") -> void:
	event_lines.append("[color=%s]%s[/color]" % [color_hex, text_value])
	if event_lines.size() > 6:
		event_lines = event_lines.slice(event_lines.size() - 6, event_lines.size())
	event_feed.clear()
	for line in event_lines:
		event_feed.append_text("%s\n" % line)


func show_result(title_text: String, body_text: String, retry_text: String = "轮回重生", include_settings: bool = false) -> void:
	hide_tutorial()
	_clear_modal_content(Color(0.01, 0.045, 0.04, 0.78))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.11, 0.09, 0.98), 24, Color(0.58, 0.93, 0.60, 0.62), 2))
	_add_modal_panel(panel, Vector2(600, 440) if _uses_touch_layout() else Vector2(600, 410))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 15)
	panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _font_size(40, 46))
	title.add_theme_color_override("font_color", Color("#f5efc8"))
	box.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", _font_size(18, 22))
	body.add_theme_color_override("font_color", Color("#dcebd7"))
	box.add_child(body)
	var retry := Button.new()
	retry.text = retry_text
	_style_button(retry, true)
	retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry.pressed.connect(func(): retry_requested.emit())
	box.add_child(retry)
	if include_settings:
		var settings_button := Button.new()
		settings_button.text = "游戏设置"
		_style_button(settings_button, false)
		settings_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		settings_button.pressed.connect(func(): show_settings(true))
		box.add_child(settings_button)
	var menu_button := Button.new()
	menu_button.text = "返回主菜单"
	_style_button(menu_button, false)
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_button.pressed.connect(func(): menu_requested.emit())
	box.add_child(menu_button)


func show_pause() -> void:
	show_result("生态暂停", "世界的呼吸暂时停止。\n继续观察、追猎或寻找食物。", "继续游戏", true)


func show_free_mode() -> void:
	_clear_modal_content(Color(0.008, 0.035, 0.032, 0.88))

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.11, 0.09, 0.99), 24, Color(0.64, 0.94, 0.62, 0.72), 2))
	_add_modal_panel(panel, Vector2(940, 650))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)

	var title := Label.new()
	title.text = "自由模式"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _font_size(40, 44))
	title.add_theme_color_override("font_color", Color("#f5efc8"))
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "任选关卡与物种，专注练习地形、技能和生态策略。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", _font_size(18, 20))
	subtitle.add_theme_color_override("font_color", Color("#c5d9c2"))
	box.add_child(subtitle)

	var selectors := HBoxContainer.new()
	selectors.alignment = BoxContainer.ALIGNMENT_CENTER
	selectors.add_theme_constant_override("separation", 22)
	box.add_child(selectors)
	var level_label := Label.new()
	level_label.text = "挑选关卡"
	level_label.add_theme_font_size_override("font_size", _font_size(21, 23))
	level_label.add_theme_color_override("font_color", Color("#e8edcf"))
	selectors.add_child(level_label)
	var level_select := OptionButton.new()
	level_select.custom_minimum_size = Vector2(230, 54)
	level_select.add_theme_font_size_override("font_size", _font_size(20, 22))
	for level_number in range(1, 11):
		level_select.add_item("第 %d 关 · %d 个体" % [level_number, level_number * 10])
	level_select.selected = clampi(game.get_selected_free_level() - 1, 0, 9)
	selectors.add_child(level_select)
	var species_label_text := Label.new()
	species_label_text.text = "挑选物种"
	species_label_text.add_theme_font_size_override("font_size", _font_size(21, 23))
	species_label_text.add_theme_color_override("font_color", Color("#e8edcf"))
	selectors.add_child(species_label_text)
	var species_select := OptionButton.new()
	species_select.custom_minimum_size = Vector2(280, 54)
	species_select.add_theme_font_size_override("font_size", _font_size(20, 22))
	var selected_species_id: String = str(game.get_selected_free_species()) if game.has_method("get_selected_free_species") else "rabbit"
	var selected_species_index := 0
	for species_index in range(Catalog.ORDER.size()):
		var species_id: String = Catalog.ORDER[species_index]
		var species_data := Catalog.get_data(species_id)
		species_select.add_item(str(species_data["name"]))
		species_select.set_item_metadata(species_index, species_id)
		if species_id == selected_species_id:
			selected_species_index = species_index
	species_select.selected = selected_species_index
	selectors.add_child(species_select)

	var level_hint := Label.new()
	level_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_hint.add_theme_font_size_override("font_size", _font_size(16, 18))
	level_hint.add_theme_color_override("font_color", Color("#a9c9aa"))
	box.add_child(level_hint)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(0, 275)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.008, 0.055, 0.047, 0.88), 18, Color(0.45, 0.76, 0.49, 0.42), 1))
	box.add_child(preview_panel)
	var preview := Label.new()
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.add_theme_font_size_override("font_size", _font_size(17, 19))
	preview.add_theme_color_override("font_color", Color("#e2ebd6"))
	preview_panel.add_child(preview)

	var refresh_level := func(index: int):
		var level_number := index + 1
		level_hint.text = _free_level_description(level_number)
		if game.has_method("set_selected_free_level"):
			game.set_selected_free_level(level_number)
	var refresh_species := func(index: int):
		var species_id := str(species_select.get_item_metadata(index))
		preview.text = _free_species_description(species_id)
		if game.has_method("set_selected_free_species"):
			game.set_selected_free_species(species_id)
	level_select.item_selected.connect(refresh_level)
	species_select.item_selected.connect(refresh_species)
	refresh_level.call(level_select.selected)
	refresh_species.call(species_select.selected)

	var mode_hint := Label.new()
	mode_hint.text = "自由模式不推进战役，不计入死亡次数，不增加世界威胁。"
	mode_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_hint.add_theme_font_size_override("font_size", _font_size(15, 17))
	mode_hint.add_theme_color_override("font_color", Color("#d6cda8"))
	box.add_child(mode_hint)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	box.add_child(actions)
	var start_button := Button.new()
	start_button.text = "开始自由挑战"
	_style_button(start_button, true)
	start_button.pressed.connect(func():
		var species_id := str(species_select.get_item_metadata(species_select.selected))
		free_mode_requested.emit(level_select.selected + 1, species_id)
	)
	actions.add_child(start_button)
	var back_button := Button.new()
	back_button.text = "返回首页"
	_style_button(back_button, false)
	back_button.pressed.connect(func(): modal_root.hide())
	actions.add_child(back_button)


func _free_level_description(level: int) -> String:
	var sizes := ["小型森林", "小型拓展", "中型河流", "中型山地", "大型猎场", "大型夜境", "巨型天气", "多生态区", "顶级猎食场", "终极生态"]
	return "第 %d 关 · %s · %d 个生态个体" % [level, sizes[clampi(level - 1, 0, sizes.size() - 1)], level * 10]


func _free_species_description(species_id: String) -> String:
	var data := Catalog.get_data(species_id)
	return "%s · %s\n生命 %d　攻击 %.1f　速度 %.2f　耐力 %d　护甲 %.1f\n%s\n%s\n反制组合：%s\n被动：%s — %s\n主动：%s — %s\n\n获胜思路：%s" % [
		data["name"], data["subtitle"], int(data["health"]), float(data["attack"]), float(data["speed"]), int(data["stamina"]), float(data["armor"]),
		Catalog.growth_description(species_id), Catalog.habitat_description(species_id), Catalog.counterplay_plan(species_id), data["passive"], data["passive_hint"], data["skill"], data["skill_hint"], Catalog.victory_guide(species_id),
	]


func show_settings(from_pause: bool = false) -> void:
	settings_from_pause = from_pause
	_clear_modal_content(Color(0.008, 0.035, 0.032, 0.84))

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.11, 0.09, 0.98), 24, Color(0.58, 0.93, 0.60, 0.62), 2))
	_add_modal_panel(panel, Vector2(700, 620) if _uses_touch_layout() else Vector2(660, 600))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)

	var title := Label.new()
	title.text = "游戏设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _font_size(40, 44))
	title.add_theme_color_override("font_color", Color("#f5efc8"))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "声音、画质与教学选项会自动保存。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", _font_size(17, 19))
	subtitle.add_theme_color_override("font_color", Color("#c5d9c2"))
	box.add_child(subtitle)

	var audio_panel := PanelContainer.new()
	audio_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.01, 0.06, 0.052, 0.82), 16, Color(0.43, 0.73, 0.48, 0.35), 1))
	audio_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(audio_panel)
	var audio_box := VBoxContainer.new()
	audio_box.add_theme_constant_override("separation", 10)
	audio_panel.add_child(audio_box)
	var audio_title := Label.new()
	audio_title.text = "声音"
	audio_title.add_theme_font_size_override("font_size", _font_size(24, 26))
	audio_title.add_theme_color_override("font_color", Color("#e9edcf"))
	audio_box.add_child(audio_title)

	var music_toggle := CheckButton.new()
	music_toggle.text = "背景音乐与森林环境声"
	music_toggle.button_pressed = game.is_music_enabled()
	music_toggle.add_theme_font_size_override("font_size", _font_size(21, 23))
	music_toggle.toggled.connect(func(enabled: bool):
		game.set_music_enabled(enabled)
		if game.is_sfx_enabled():
			game.play_ui_sound()
	)
	audio_box.add_child(music_toggle)

	var sfx_toggle := CheckButton.new()
	sfx_toggle.text = "战斗、技能与界面音效"
	sfx_toggle.button_pressed = game.is_sfx_enabled()
	sfx_toggle.add_theme_font_size_override("font_size", _font_size(21, 23))
	sfx_toggle.toggled.connect(func(enabled: bool): game.set_sfx_enabled(enabled))
	audio_box.add_child(sfx_toggle)

	var quality_panel := PanelContainer.new()
	quality_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.01, 0.06, 0.052, 0.82), 16, Color(0.43, 0.73, 0.48, 0.35), 1))
	quality_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(quality_panel)
	var quality_row := HBoxContainer.new()
	quality_row.add_theme_constant_override("separation", 18)
	quality_panel.add_child(quality_row)
	var quality_text_box := VBoxContainer.new()
	quality_text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quality_row.add_child(quality_text_box)
	var quality_title := Label.new()
	quality_title.text = "画质"
	quality_title.add_theme_font_size_override("font_size", _font_size(23, 25))
	quality_title.add_theme_color_override("font_color", Color("#e9edcf"))
	quality_text_box.add_child(quality_title)
	var quality_hint := Label.new()
	quality_hint.text = "手机卡顿时选择性能；修改后立即生效"
	quality_hint.add_theme_font_size_override("font_size", _font_size(15, 17))
	quality_hint.add_theme_color_override("font_color", Color("#b8cbb5"))
	quality_text_box.add_child(quality_hint)
	var quality_select := OptionButton.new()
	quality_select.custom_minimum_size = Vector2(210, 54)
	quality_select.add_theme_font_size_override("font_size", _font_size(20, 22))
	quality_select.add_item("性能（低）")
	quality_select.add_item("平衡（中）")
	quality_select.add_item("高画质")
	var quality_values: Array[String] = ["low", "medium", "high"]
	quality_select.selected = maxi(quality_values.find(game.get_quality_preset()), 1)
	quality_select.item_selected.connect(func(index: int): game.set_quality_preset(quality_values[index]))
	quality_row.add_child(quality_select)

	var utility_row := HBoxContainer.new()
	utility_row.alignment = BoxContainer.ALIGNMENT_CENTER
	utility_row.add_theme_constant_override("separation", 12)
	box.add_child(utility_row)
	var tutorial_button := Button.new()
	tutorial_button.text = "重新开启新手教学"
	_style_button(tutorial_button, false)
	tutorial_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tutorial_button.pressed.connect(func():
		game.reset_tutorial_progress()
		tutorial_button.disabled = true
		tutorial_button.text = "已设置，下局显示教学"
	)
	utility_row.add_child(tutorial_button)

	var reset_button := Button.new()
	reset_button.text = "重置游戏进度"
	_style_button(reset_button, false)
	reset_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset_button.pressed.connect(func(): show_reset_confirmation())
	utility_row.add_child(reset_button)

	var reset_hint := Label.new()
	reset_hint.text = "重置会清除关卡、威胁和教学状态；声音与画质会保留。"
	reset_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reset_hint.add_theme_font_size_override("font_size", _font_size(16, 18))
	reset_hint.add_theme_color_override("font_color", Color("#d5c7a7"))
	box.add_child(reset_hint)

	var close_button := Button.new()
	close_button.text = "返回暂停菜单" if settings_from_pause else "返回主菜单"
	_style_button(close_button, true)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(func():
		if settings_from_pause:
			show_pause()
		else:
			show_menu()
	)
	box.add_child(close_button)


func show_reset_confirmation() -> void:
	_clear_modal_content(Color(0.008, 0.025, 0.022, 0.90))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.075, 0.045, 0.98), 24, Color(0.90, 0.69, 0.36, 0.75), 2))
	_add_modal_panel(panel, Vector2(620, 380) if _uses_touch_layout() else Vector2(600, 340))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := Label.new()
	title.text = "确认重置游戏？"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _font_size(34, 40))
	title.add_theme_color_override("font_color", Color("#f3ddb8"))
	box.add_child(title)
	var body := Label.new()
	body.text = "你将回到第一关，死亡次数和世界威胁归零。\n此操作无法撤销，但不会改变声音设置。"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", _font_size(20, 23))
	body.add_theme_color_override("font_color", Color("#e7e0cf"))
	box.add_child(body)
	var confirm := Button.new()
	confirm.text = "确认重置"
	_style_button(confirm, false)
	confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm.pressed.connect(func(): game.reset_game_progress())
	box.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "取消"
	_style_button(cancel, true)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(func(): show_settings(settings_from_pause))
	box.add_child(cancel)


func get_touch_move() -> Vector2:
	return joystick.output if joystick != null and touch_root.visible else Vector2.ZERO


func consume_skill() -> bool:
	var value := skill_requested
	skill_requested = false
	return value


func consume_interact() -> bool:
	var value := interact_requested
	interact_requested = false
	return value
