class_name GameUI
extends CanvasLayer

const JoystickScript = preload("res://scripts/virtual_joystick.gd")
const Catalog = preload("res://scripts/species_catalog.gd")

signal start_requested
signal retry_requested
signal menu_requested
signal pause_requested
signal tutorial_skipped

var game: Node
var menu_root: Control
var menu_start_button: Button
var hud_root: Control
var modal_root: Control
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
var enemy_panel: PanelContainer
var enemy_name_label: Label
var enemy_hp_bar: ProgressBar
var enemy_hp_value_label: Label
var enemy_target: EcoActor
var enemy_visible_until_msec: int = 0
var threat_label: Label
var seed_label: Label
var region_label: Label
var skill_label: Label
var skill_hint_label: Label
var skill_bar: ProgressBar
var hint_label: Label
var hint_tween: Tween
var intro_panel: PanelContainer
var intro_title: Label
var intro_body: Label
var intro_controls: Label
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


func setup(game_ref: Node) -> void:
	game = game_ref
	layer = 20
	_build_menu()
	_build_hud()
	_build_modal_root()
	show_menu()


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
	button.custom_minimum_size = Vector2(220.0, 58.0)
	button.add_theme_font_size_override("font_size", 24)
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

	var content_margin := MarginContainer.new()
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left", 64)
	content_margin.add_theme_constant_override("margin_right", 64)
	content_margin.add_theme_constant_override("margin_top", 54)
	content_margin.add_theme_constant_override("margin_bottom", 42)
	menu_root.add_child(content_margin)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	content_margin.add_child(content)

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
	hud_root = Control.new()
	hud_root.name = "HUD"
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)

	var status_panel := PanelContainer.new()
	status_panel.position = Vector2(20, 20)
	status_panel.custom_minimum_size = Vector2(400, 252)
	status_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.09, 0.075, 0.88), 16, Color(0.48, 0.80, 0.53, 0.40), 1))
	hud_root.add_child(status_panel)
	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 6)
	status_panel.add_child(status_box)
	species_label = Label.new()
	species_label.add_theme_font_size_override("font_size", 25)
	species_label.add_theme_color_override("font_color", Color("#f4f2d3"))
	status_box.add_child(species_label)
	combat_stats_label = Label.new()
	combat_stats_label.add_theme_font_size_override("font_size", 15)
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
	remaining_label.add_theme_font_size_override("font_size", 30)
	remaining_label.add_theme_color_override("font_color", Color("#f4f3d7"))
	remaining_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	remaining_label.position = Vector2(-160, 20)
	remaining_label.size = Vector2(320, 46)
	hud_root.add_child(remaining_label)

	enemy_panel = PanelContainer.new()
	enemy_panel.name = "EnemyHealth"
	enemy_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	enemy_panel.position = Vector2(-220, 70)
	enemy_panel.size = Vector2(440, 78)
	enemy_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.13, 0.035, 0.035, 0.92), 14, Color(0.95, 0.38, 0.32, 0.60), 2))
	hud_root.add_child(enemy_panel)
	var enemy_box := VBoxContainer.new()
	enemy_box.add_theme_constant_override("separation", 6)
	enemy_panel.add_child(enemy_box)
	var enemy_title_row := HBoxContainer.new()
	enemy_box.add_child(enemy_title_row)
	enemy_name_label = Label.new()
	enemy_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_name_label.add_theme_font_size_override("font_size", 21)
	enemy_name_label.add_theme_color_override("font_color", Color("#fff0df"))
	enemy_title_row.add_child(enemy_name_label)
	enemy_hp_value_label = Label.new()
	enemy_hp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_hp_value_label.add_theme_font_size_override("font_size", 18)
	enemy_hp_value_label.add_theme_color_override("font_color", Color("#ffd0c4"))
	enemy_title_row.add_child(enemy_hp_value_label)
	enemy_hp_bar = _make_bar(Color("#d6534f"), 100.0)
	enemy_hp_bar.custom_minimum_size.y = 17.0
	enemy_box.add_child(enemy_hp_bar)
	enemy_panel.hide()

	var info_panel := PanelContainer.new()
	info_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	info_panel.position = Vector2(-366, 20)
	info_panel.size = Vector2(346, 142)
	info_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.09, 0.075, 0.82), 14))
	hud_root.add_child(info_panel)
	var info_box := VBoxContainer.new()
	info_panel.add_child(info_box)
	threat_label = Label.new()
	threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	threat_label.add_theme_font_size_override("font_size", 20)
	info_box.add_child(threat_label)
	region_label = Label.new()
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	region_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	region_label.add_theme_font_size_override("font_size", 17)
	region_label.add_theme_color_override("font_color", Color("#cce4a6"))
	info_box.add_child(region_label)
	seed_label = Label.new()
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	seed_label.add_theme_font_size_override("font_size", 15)
	seed_label.add_theme_color_override("font_color", Color(0.75, 0.86, 0.78, 0.78))
	info_box.add_child(seed_label)

	var skill_panel := PanelContainer.new()
	skill_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skill_panel.position = Vector2(-215, -120)
	skill_panel.size = Vector2(430, 98)
	skill_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.09, 0.075, 0.85), 14))
	hud_root.add_child(skill_panel)
	var skill_box := VBoxContainer.new()
	skill_panel.add_child(skill_box)
	skill_label = Label.new()
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_label.add_theme_font_size_override("font_size", 19)
	skill_box.add_child(skill_label)
	skill_hint_label = Label.new()
	skill_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_hint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	skill_hint_label.add_theme_font_size_override("font_size", 14)
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
	event_feed.add_theme_font_size_override("normal_font_size", 17)
	event_feed.add_theme_color_override("default_color", Color(0.93, 0.96, 0.88, 0.85))
	hud_root.add_child(event_feed)

	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.set_anchors_preset(Control.PRESET_CENTER)
	hint_label.position = Vector2(-260, 120)
	hint_label.size = Vector2(520, 48)
	hint_label.add_theme_font_size_override("font_size", 22)
	hint_label.add_theme_color_override("font_color", Color("#f6f0c9"))
	hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	hint_label.add_theme_constant_override("shadow_offset_x", 2)
	hint_label.add_theme_constant_override("shadow_offset_y", 2)
	hud_root.add_child(hint_label)

	var pause_button := Button.new()
	pause_button.text = "Ⅱ"
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-58, 170)
	pause_button.size = Vector2(42, 42)
	pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
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
	bar.custom_minimum_size = Vector2(190, 15)
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.0, 0.0, 0.0, 0.42)))
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
	label.custom_minimum_size.x = 52
	label.add_theme_font_size_override("font_size", 17)
	row.add_child(label)
	row.add_child(bar)
	if value_label != null:
		row.add_child(value_label)
	return row


func _make_value_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size.x = 78.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("#edf6e8"))
	return label


func _build_intro() -> void:
	intro_panel = PanelContainer.new()
	intro_panel.set_anchors_preset(Control.PRESET_CENTER)
	intro_panel.position = Vector2(-390, -220)
	intro_panel.size = Vector2(780, 440)
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
	intro_title.add_theme_font_size_override("font_size", 38)
	intro_title.add_theme_color_override("font_color", Color("#f4f0cd"))
	box.add_child(intro_title)
	intro_body = Label.new()
	intro_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	intro_body.add_theme_font_size_override("font_size", 18)
	intro_body.add_theme_color_override("font_color", Color("#dfecd9"))
	box.add_child(intro_body)
	intro_controls = Label.new()
	intro_controls.text = "WASD / 摇杆移动　Shift 冲刺　按住攻击　空格释放技能　E 进食"
	intro_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_controls.add_theme_font_size_override("font_size", 17)
	intro_controls.add_theme_color_override("font_color", Color(0.75, 0.86, 0.75, 0.82))
	box.add_child(intro_controls)


func _build_tutorial() -> void:
	tutorial_panel = PanelContainer.new()
	tutorial_panel.name = "Tutorial"
	tutorial_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tutorial_panel.position = Vector2(-280, 155)
	tutorial_panel.size = Vector2(560, 162)
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
	tutorial_title.add_theme_font_size_override("font_size", 23)
	tutorial_title.add_theme_color_override("font_color", Color("#f4e7a7"))
	header.add_child(tutorial_title)
	tutorial_progress_label = Label.new()
	tutorial_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tutorial_progress_label.add_theme_font_size_override("font_size", 17)
	tutorial_progress_label.add_theme_color_override("font_color", Color("#bdd9b8"))
	header.add_child(tutorial_progress_label)
	tutorial_body = Label.new()
	tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tutorial_body.add_theme_font_size_override("font_size", 18)
	tutorial_body.add_theme_color_override("font_color", Color("#edf3df"))
	box.add_child(tutorial_body)
	var skip_button := Button.new()
	skip_button.text = "跳过教学"
	skip_button.custom_minimum_size = Vector2(132, 36)
	skip_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip_button.add_theme_font_size_override("font_size", 17)
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

	attack_button = _make_touch_button("攻击", Vector2(-184, -180), Vector2(150, 150), Color("#a94c45"))
	attack_button.button_down.connect(func(): attack_held = true)
	attack_button.button_up.connect(func(): attack_held = false)
	skill_button = _make_touch_button("技能", Vector2(-336, -286), Vector2(132, 132), Color("#338c68"))
	skill_button.pressed.connect(func(): skill_requested = true)
	eat_button = _make_touch_button("进食", Vector2(-464, -160), Vector2(112, 96), Color("#6b863b"))
	eat_button.pressed.connect(func(): interact_requested = true)
	sprint_button = _make_touch_button("冲刺", Vector2(-332, -128), Vector2(112, 96), Color("#9d7f34"))
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
	button.add_theme_font_size_override("font_size", 24)
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
	modal_root.hide()


func show_menu() -> void:
	if menu_start_button != null and game != null:
		menu_start_button.text = game.menu_start_text() if game.has_method("menu_start_text") else ("继续轮回" if game.has_campaign_progress() else "开始轮回")
	menu_root.show()
	hud_root.hide()
	modal_root.hide()
	hide_tutorial()
	clear_enemy_health()
	attack_held = false
	sprint_held = false


func show_hud(player_actor: EcoActor, world_seed: int, threat_level: int, level: int = 1) -> void:
	menu_root.hide()
	hud_root.show()
	modal_root.hide()
	hide_tutorial()
	clear_enemy_health()
	var touch_available := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or "--touch-preview" in OS.get_cmdline_user_args()
	touch_root.visible = touch_available
	seed_label.text = "世界种子 %s" % world_seed
	threat_label.text = "第%d关 · 世界威胁 %d" % [level, threat_level]
	set_player(player_actor)


func show_tutorial_step(step: int, total: int, title_text: String, body_text: String) -> void:
	if tutorial_panel == null:
		return
	tutorial_title.text = title_text
	tutorial_progress_label.text = "教学 %d / %d" % [step, total]
	tutorial_body.text = body_text
	tutorial_panel.modulate = Color.WHITE
	tutorial_panel.show()


func hide_tutorial() -> void:
	if tutorial_panel != null:
		tutorial_panel.hide()


func set_player(player_actor: EcoActor) -> void:
	var data := Catalog.get_data(player_actor.species_id)
	species_label.text = "Lv.%d %s · %s" % [player_actor.level, data["name"], data["subtitle"]]
	combat_stats_label.text = "攻击 %.1f　速度 %.2f　护甲 %.1f" % [float(player_actor.data["attack"]), float(player_actor.data["speed"]), float(player_actor.data["armor"])]
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
	var data := Catalog.get_data(species_id)
	var touch_layout := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or "--touch-preview" in OS.get_cmdline_user_args()
	intro_title.text = "%s · %s" % [data["name"], data["subtitle"]]
	intro_controls.text = "左侧动态摇杆移动　右侧冲刺 / 攻击 / 技能 / 进食" if touch_layout else "WASD / 方向键移动　Shift 冲刺　按住攻击　空格释放技能　E 进食"
	intro_body.text = "基础数值：生命 %d　攻击 %.1f　速度 %.2f　耐力 %d　护甲 %.1f\n%s\n被动：%s — %s\n主动技能：%s — %s\n\n获胜攻略：%s" % [
		int(data["health"]), float(data["attack"]), float(data["speed"]), int(data["stamina"]), float(data["armor"]),
		Catalog.growth_description(species_id), data["passive"], data["passive_hint"], data["skill"], data["skill_hint"], Catalog.victory_guide(species_id)
	]
	intro_panel.modulate = Color.WHITE
	intro_panel.move_to_front()
	intro_panel.show()
	var tween := create_tween()
	tween.tween_interval(8.0)
	tween.tween_property(intro_panel, "modulate", Color(1, 1, 1, 0), 0.6)
	tween.tween_callback(intro_panel.hide)


func update_hud(player_actor: EcoActor, remaining: int, total: int = 10, current_region: String = "未知区域") -> void:
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
	combat_stats_label.text = "攻击 %.1f　速度 %.2f　护甲 %.1f" % [float(player_actor.data["attack"]), float(player_actor.data["speed"]), float(player_actor.data["armor"])]
	var needed_xp := player_actor.experience_to_next_level()
	xp_bar.max_value = maxf(float(needed_xp), 1.0)
	xp_bar.value = player_actor.experience if needed_xp > 0 else 1.0
	xp_value_label.text = ("最高等级" if needed_xp <= 0 else "%d / %d" % [player_actor.experience, needed_xp])
	remaining_label.text = "存活个体　%d / %d" % [remaining, total]
	region_label.text = "当前位置 · %s" % current_region
	var cooldown := float(player_actor.data["skill_cooldown"])
	var cooldown_remaining := player_actor.skill_timer
	skill_bar.max_value = cooldown
	skill_bar.value = cooldown - cooldown_remaining
	var skill_ready := cooldown_remaining <= 0.0 and player_actor.stamina >= float(player_actor.data["skill_cost"])
	var skill_state := "就绪" if skill_ready else ("耐力不足" if cooldown_remaining <= 0.0 else "%.1fs" % cooldown_remaining)
	skill_label.text = "%s　%s" % [player_actor.data["skill"], skill_state]
	skill_button.text = "%s\n%s" % [player_actor.data["skill"], skill_state]
	skill_button.modulate = Color.WHITE if skill_ready else Color(0.72, 0.76, 0.74, 0.88)
	_update_enemy_health_display()


func show_enemy_health(target: EcoActor) -> void:
	if enemy_panel == null or not is_instance_valid(target) or target.dead:
		return
	enemy_target = target
	enemy_visible_until_msec = Time.get_ticks_msec() + 4200
	enemy_panel.show()
	_refresh_enemy_health()


func clear_enemy_health() -> void:
	enemy_target = null
	enemy_visible_until_msec = 0
	if enemy_panel != null:
		enemy_panel.hide()


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
	var status_parts: Array[String] = []
	if enemy_target.poison_timer > 0.0:
		status_parts.append("中毒 %.1fs" % enemy_target.poison_timer)
	if enemy_target.scent_mark_timer > 0.0:
		status_parts.append("血味 %.1fs" % enemy_target.scent_mark_timer)
	if enemy_target.slow_timer > 0.0:
		status_parts.append("减速")
	if enemy_target.panic_timer > 0.0:
		status_parts.append("受惊")
	var status_text := " · " + " / ".join(status_parts) if not status_parts.is_empty() else ""
	enemy_name_label.text = "攻击目标 · Lv.%d %s%s" % [enemy_target.level, target_data["name"], status_text]
	enemy_hp_bar.max_value = maxf(enemy_target.max_health, 1.0)
	enemy_hp_bar.value = maxf(enemy_target.health, 0.0)
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
	for child in modal_root.get_children():
		child.queue_free()
	modal_root.show()
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.045, 0.04, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-300, -205)
	panel.size = Vector2(600, 410)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.11, 0.09, 0.98), 24, Color(0.58, 0.93, 0.60, 0.62), 2))
	modal_root.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 15)
	panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("#f5efc8"))
	box.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 18)
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


func show_settings(from_pause: bool = false) -> void:
	settings_from_pause = from_pause
	for child in modal_root.get_children():
		child.queue_free()
	modal_root.show()
	var shade := ColorRect.new()
	shade.color = Color(0.008, 0.035, 0.032, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-350, -340)
	panel.size = Vector2(700, 680)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.11, 0.09, 0.98), 24, Color(0.58, 0.93, 0.60, 0.62), 2))
	modal_root.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)

	var title := Label.new()
	title.text = "游戏设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("#f5efc8"))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "声音、画质、教学与关卡选项会自动保存。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
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
	audio_title.add_theme_font_size_override("font_size", 24)
	audio_title.add_theme_color_override("font_color", Color("#e9edcf"))
	audio_box.add_child(audio_title)

	var music_toggle := CheckButton.new()
	music_toggle.text = "背景音乐与森林环境声"
	music_toggle.button_pressed = game.is_music_enabled()
	music_toggle.add_theme_font_size_override("font_size", 21)
	music_toggle.toggled.connect(func(enabled: bool):
		game.set_music_enabled(enabled)
		if game.is_sfx_enabled():
			game.play_ui_sound()
	)
	audio_box.add_child(music_toggle)

	var sfx_toggle := CheckButton.new()
	sfx_toggle.text = "战斗、技能与界面音效"
	sfx_toggle.button_pressed = game.is_sfx_enabled()
	sfx_toggle.add_theme_font_size_override("font_size", 21)
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
	quality_title.add_theme_font_size_override("font_size", 23)
	quality_title.add_theme_color_override("font_color", Color("#e9edcf"))
	quality_text_box.add_child(quality_title)
	var quality_hint := Label.new()
	quality_hint.text = "手机卡顿时选择性能；修改后立即生效"
	quality_hint.add_theme_font_size_override("font_size", 15)
	quality_hint.add_theme_color_override("font_color", Color("#b8cbb5"))
	quality_text_box.add_child(quality_hint)
	var quality_select := OptionButton.new()
	quality_select.custom_minimum_size = Vector2(210, 54)
	quality_select.add_theme_font_size_override("font_size", 20)
	quality_select.add_item("性能（低）")
	quality_select.add_item("平衡（中）")
	quality_select.add_item("高画质")
	var quality_values: Array[String] = ["low", "medium", "high"]
	quality_select.selected = maxi(quality_values.find(game.get_quality_preset()), 1)
	quality_select.item_selected.connect(func(index: int): game.set_quality_preset(quality_values[index]))
	quality_row.add_child(quality_select)

	var level_panel := PanelContainer.new()
	level_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.01, 0.06, 0.052, 0.82), 16, Color(0.43, 0.73, 0.48, 0.35), 1))
	level_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(level_panel)
	var level_box := VBoxContainer.new()
	level_box.add_theme_constant_override("separation", 3)
	level_panel.add_child(level_box)
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 18)
	level_box.add_child(level_row)
	var level_toggle := CheckButton.new()
	level_toggle.text = "自由选择全部关卡"
	level_toggle.button_pressed = game.is_all_levels_unlocked()
	level_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_toggle.add_theme_font_size_override("font_size", 21)
	level_row.add_child(level_toggle)
	var level_select := OptionButton.new()
	level_select.custom_minimum_size = Vector2(210, 52)
	level_select.add_theme_font_size_override("font_size", 19)
	for level_number in range(1, 11):
		level_select.add_item("第 %d 关" % level_number)
	level_select.selected = game.get_selected_free_level() - 1
	level_select.disabled = not level_toggle.button_pressed
	level_select.item_selected.connect(func(index: int): game.set_selected_free_level(index + 1))
	level_row.add_child(level_select)
	var level_hint := Label.new()
	level_hint.text = "自由选关用于练习，不改变正常战役进度、死亡次数和世界威胁。"
	level_hint.add_theme_font_size_override("font_size", 14)
	level_hint.add_theme_color_override("font_color", Color("#c9d3aa"))
	level_box.add_child(level_hint)
	level_toggle.toggled.connect(func(enabled: bool):
		level_select.disabled = not enabled
		game.set_all_levels_unlocked(enabled)
	)

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
	reset_hint.add_theme_font_size_override("font_size", 16)
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
	for child in modal_root.get_children():
		child.queue_free()
	modal_root.show()
	var shade := ColorRect.new()
	shade.color = Color(0.008, 0.025, 0.022, 0.90)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-300, -170)
	panel.size = Vector2(600, 340)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.075, 0.045, 0.98), 24, Color(0.90, 0.69, 0.36, 0.75), 2))
	modal_root.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := Label.new()
	title.text = "确认重置游戏？"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f3ddb8"))
	box.add_child(title)
	var body := Label.new()
	body.text = "你将回到第一关，死亡次数和世界威胁归零。\n此操作无法撤销，但不会改变声音设置。"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 20)
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
