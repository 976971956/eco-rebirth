class_name TouchActionIcon
extends Control


const SKILL_ICON_FAMILIES := {
	"rabbit": "moon",
	"fox": "scent",
	"deer": "hoof",
	"wolf": "pack",
	"snake": "venom",
	"bear": "quake",
	"boar": "tusk",
	"lynx": "pounce",
	"bison": "charge",
	"crocodile": "roll",
	"tiger": "slash",
	"moose": "antler",
	"rhino": "horn",
	"hippo": "jaw",
	"raccoon": "steal",
	"porcupine": "spikes",
	"goat": "leap",
	"wolverine": "rage",
	"zebra": "speed",
	"hyena": "pack",
	"capybara": "calm",
	"monkey": "fruit",
	"gorilla": "quake",
	"lion": "roar",
	"otter": "water",
	"turtle": "shield",
	"elephant": "stomp",
	"owl": "shadow_wing",
	"cheetah": "speed",
	"eagle": "wing",
}

var action_kind := "attack"
var species_id := ""
var accent := Color.WHITE
var progress := 1.0
var available := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure(kind: String, species: String = "", color: Color = Color.WHITE) -> void:
	action_kind = kind
	species_id = species
	accent = color
	queue_redraw()


func set_progress(value: float, is_available: bool) -> void:
	var next_progress := clampf(value, 0.0, 1.0)
	if is_equal_approx(progress, next_progress) and available == is_available:
		return
	progress = next_progress
	available = is_available
	queue_redraw()


static func skill_icon_family(species: String) -> String:
	return str(SKILL_ICON_FAMILIES.get(species, "paw"))


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 2.0:
		return
	var center := size * 0.5
	var radius := side * 0.43
	var icon_color := Color(accent.lightened(0.60), 0.98 if available else 0.62)
	draw_circle(center + Vector2(0.0, side * 0.025), radius * 0.82, Color(0.01, 0.055, 0.045, 0.25))
	if action_kind == "skill":
		_draw_skill(center, radius, icon_color)
	else:
		match action_kind:
			"eat":
				_draw_fruit(center, radius, icon_color)
			"sprint":
				_draw_speed(center, radius, icon_color)
			_:
				_draw_slash(center, radius, icon_color)
	var ring_color := Color(accent.lightened(0.54), 0.92 if available else 0.46)
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 30, ring_color, maxf(side * 0.045, 2.0), true)


func _draw_skill(center: Vector2, radius: float, color: Color) -> void:
	match skill_icon_family(species_id):
		"moon":
			draw_arc(center - Vector2(radius * 0.05, 0.0), radius * 0.48, -PI * 0.72, PI * 0.72, 18, color, radius * 0.14, true)
			_polyline([_p(center, radius, 0.05, 0.25), _p(center, radius, 0.42, 0.03), _p(center, radius, 0.19, -0.08)], color, radius * 0.11)
		"scent":
			_draw_drop(center - Vector2(radius * 0.20, radius * 0.02), radius * 0.44, color)
			for index in range(3):
				draw_arc(center + Vector2(radius * 0.20, radius * 0.08), radius * (0.23 + index * 0.13), -PI * 0.48, PI * 0.48, 10, color, radius * 0.075, true)
		"hoof", "stomp":
			draw_arc(center - Vector2(0.0, radius * 0.08), radius * 0.42, 0.05, PI - 0.05, 16, color, radius * 0.15, true)
			for x_value in [-0.42, 0.0, 0.42]:
				_polyline([_p(center, radius, x_value, 0.34), _p(center, radius, x_value * 1.12, 0.62)], color, radius * 0.08)
		"pack":
			for x_value in [-0.42, 0.0, 0.42]:
				var peak := _p(center, radius, x_value, -0.48 if is_zero_approx(x_value) else -0.28)
				var left := peak + Vector2(-radius * 0.17, radius * 0.54)
				var right := peak + Vector2(radius * 0.17, radius * 0.54)
				draw_colored_polygon(PackedVector2Array([peak, left, right]), color)
		"venom":
			_draw_fangs(center - Vector2(0.0, radius * 0.14), radius, color)
			_draw_drop(center + Vector2(0.0, radius * 0.43), radius * 0.26, color)
		"quake":
			_polyline([_p(center, radius, 0.0, -0.56), _p(center, radius, 0.0, 0.08)], color, radius * 0.18)
			for width in [0.34, 0.62]:
				draw_arc(_p(center, radius, 0.0, 0.20), radius * width, 0.08, PI - 0.08, 15, color, radius * 0.085, true)
		"tusk", "horn", "charge":
			_draw_horns(center, radius, color, skill_icon_family(species_id) == "charge")
		"pounce":
			_draw_paw(center + Vector2(radius * 0.10, radius * 0.04), radius * 0.78, color)
			_polyline([_p(center, radius, -0.60, 0.32), _p(center, radius, -0.18, 0.06)], color, radius * 0.10)
		"roll":
			draw_arc(center, radius * 0.48, -PI * 0.18, PI * 1.42, 24, color, radius * 0.13, true)
			draw_colored_polygon(PackedVector2Array([_p(center, radius, 0.27, -0.49), _p(center, radius, 0.66, -0.43), _p(center, radius, 0.46, -0.12)]), color)
		"slash", "rage":
			_draw_slash(center, radius, color)
			if skill_icon_family(species_id) == "rage":
				_polyline([_p(center, radius, -0.55, -0.45), _p(center, radius, -0.25, -0.12), _p(center, radius, -0.52, 0.16)], color, radius * 0.09)
		"antler":
			for side_sign in [-1.0, 1.0]:
				_polyline([_p(center, radius, side_sign * 0.11, 0.55), _p(center, radius, side_sign * 0.24, -0.38), _p(center, radius, side_sign * 0.54, -0.58)], color, radius * 0.11)
				_polyline([_p(center, radius, side_sign * 0.21, -0.12), _p(center, radius, side_sign * 0.55, -0.22)], color, radius * 0.09)
		"jaw":
			_polyline([_p(center, radius, -0.58, -0.22), _p(center, radius, -0.15, -0.02), _p(center, radius, 0.13, -0.18), _p(center, radius, 0.56, -0.02)], color, radius * 0.13)
			_polyline([_p(center, radius, -0.58, 0.30), _p(center, radius, -0.12, 0.12), _p(center, radius, 0.14, 0.30), _p(center, radius, 0.56, 0.10)], color, radius * 0.13)
		"steal":
			_draw_paw(center - Vector2(radius * 0.10, 0.0), radius * 0.72, color)
			_polyline([_p(center, radius, 0.14, 0.42), _p(center, radius, 0.55, 0.08), _p(center, radius, 0.35, -0.02)], color, radius * 0.10)
		"spikes":
			for index in range(7):
				var angle := lerpf(-PI * 0.88, -PI * 0.12, float(index) / 6.0)
				_polyline([center + Vector2(cos(angle), sin(angle)) * radius * 0.12, center + Vector2(cos(angle), sin(angle)) * radius * 0.67], color, radius * 0.09)
			draw_arc(center + Vector2(0.0, radius * 0.18), radius * 0.34, PI, TAU, 12, color, radius * 0.11, true)
		"leap":
			_polyline([_p(center, radius, -0.56, 0.38), _p(center, radius, -0.06, -0.38), _p(center, radius, 0.47, -0.12)], color, radius * 0.14)
			draw_colored_polygon(PackedVector2Array([_p(center, radius, 0.47, -0.12), _p(center, radius, 0.22, -0.42), _p(center, radius, 0.65, -0.35)]), color)
		"speed":
			_draw_speed(center, radius, color)
		"calm":
			_draw_heart(center - Vector2(0.0, radius * 0.08), radius * 0.72, color)
			_polyline([_p(center, radius, -0.58, 0.50), _p(center, radius, -0.18, 0.40), _p(center, radius, 0.18, 0.50), _p(center, radius, 0.58, 0.40)], color, radius * 0.08)
		"fruit":
			_draw_fruit(center, radius, color)
		"roar":
			draw_circle(center - Vector2(radius * 0.22, 0.0), radius * 0.18, color)
			for scale_value in [0.30, 0.52, 0.72]:
				draw_arc(center - Vector2(radius * 0.08, 0.0), radius * scale_value, -PI * 0.43, PI * 0.43, 12, color, radius * 0.075, true)
		"water":
			for row in [-0.22, 0.12, 0.45]:
				_polyline([_p(center, radius, -0.62, row), _p(center, radius, -0.30, row - 0.14), _p(center, radius, 0.03, row), _p(center, radius, 0.34, row - 0.14), _p(center, radius, 0.64, row)], color, radius * 0.09)
		"shield":
			var shield := PackedVector2Array([_p(center, radius, 0.0, -0.68), _p(center, radius, 0.58, -0.35), _p(center, radius, 0.46, 0.34), _p(center, radius, 0.0, 0.68), _p(center, radius, -0.46, 0.34), _p(center, radius, -0.58, -0.35)])
			draw_polyline(shield, color, radius * 0.13, true)
			_polyline([_p(center, radius, -0.28, 0.0), _p(center, radius, 0.0, 0.25), _p(center, radius, 0.34, -0.28)], color, radius * 0.11)
		"shadow_wing", "wing":
			_draw_wing(center, radius, color, skill_icon_family(species_id) == "shadow_wing")
		_:
			_draw_paw(center, radius * 0.82, color)


func _draw_slash(center: Vector2, radius: float, color: Color) -> void:
	for index in range(3):
		var shift := (float(index) - 1.0) * radius * 0.29
		_polyline([center + Vector2(-radius * 0.44 + shift, radius * 0.54), center + Vector2(radius * 0.18 + shift, -radius * 0.54)], color, radius * 0.13)


func _draw_speed(center: Vector2, radius: float, color: Color) -> void:
	for row in [-0.38, 0.0, 0.38]:
		_polyline([_p(center, radius, -0.64, row), _p(center, radius, 0.18, row), _p(center, radius, -0.02, row - 0.20)], color, radius * 0.11)


func _draw_fruit(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center + Vector2(-radius * 0.10, radius * 0.13), radius * 0.38, color)
	draw_circle(center + Vector2(radius * 0.22, radius * 0.10), radius * 0.32, color)
	_polyline([_p(center, radius, 0.02, -0.12), _p(center, radius, 0.10, -0.60)], color, radius * 0.10)
	var leaf := PackedVector2Array([_p(center, radius, 0.10, -0.50), _p(center, radius, 0.54, -0.58), _p(center, radius, 0.22, -0.24)])
	draw_colored_polygon(leaf, color)


func _draw_drop(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius), center + Vector2(radius * 0.72, radius * 0.20),
		center + Vector2(radius * 0.46, radius * 0.78), center + Vector2(0.0, radius),
		center + Vector2(-radius * 0.46, radius * 0.78), center + Vector2(-radius * 0.72, radius * 0.20),
	])
	draw_colored_polygon(points, color)


func _draw_fangs(center: Vector2, radius: float, color: Color) -> void:
	for side_sign in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			_p(center, radius, side_sign * 0.46, -0.46), _p(center, radius, side_sign * 0.10, -0.28), _p(center, radius, side_sign * 0.22, 0.44),
		]), color)


func _draw_horns(center: Vector2, radius: float, color: Color, charged: bool) -> void:
	for side_sign in [-1.0, 1.0]:
		draw_arc(center + Vector2(side_sign * radius * 0.12, radius * 0.02), radius * 0.48, -PI * 0.60 if side_sign < 0.0 else PI * 0.10, -PI * 0.10 if side_sign < 0.0 else PI * 0.60, 14, color, radius * 0.13, true)
	if charged:
		_polyline([_p(center, radius, -0.58, 0.54), _p(center, radius, 0.56, 0.54)], color, radius * 0.10)


func _draw_paw(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center + Vector2(0.0, radius * 0.20), radius * 0.34, color)
	for angle in [-1.05, -0.35, 0.35, 1.05]:
		draw_circle(center + Vector2(sin(angle) * radius * 0.50, -cos(angle) * radius * 0.47), radius * 0.14, color)


func _draw_heart(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center + Vector2(-radius * 0.22, -radius * 0.12), radius * 0.30, color)
	draw_circle(center + Vector2(radius * 0.22, -radius * 0.12), radius * 0.30, color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-radius * 0.50, 0.0), center + Vector2(radius * 0.50, 0.0), center + Vector2(0.0, radius * 0.62),
	]), color)


func _draw_wing(center: Vector2, radius: float, color: Color, shadowed: bool) -> void:
	var upper := -0.12 if shadowed else -0.42
	_polyline([
		_p(center, radius, -0.65, 0.40), _p(center, radius, -0.10, upper), _p(center, radius, 0.62, -0.56),
		_p(center, radius, 0.36, -0.08), _p(center, radius, 0.66, 0.10), _p(center, radius, 0.18, 0.22), _p(center, radius, 0.42, 0.48), _p(center, radius, -0.65, 0.40),
	], color, radius * 0.11)


func _p(center: Vector2, radius: float, x_value: float, y_value: float) -> Vector2:
	return center + Vector2(x_value, y_value) * radius


func _polyline(points: Array[Vector2], color: Color, width: float) -> void:
	draw_polyline(PackedVector2Array(points), color, width, true)
