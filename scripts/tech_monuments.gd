extends RefCounted
## Electronic landmark art, drawn directly into the arena's world canvas.

const BLUE = Color("54caff")
const IDLE = Color("3d5562")

static func draw_pressure_module(canvas: Node2D, object: Dictionary) -> void:
	var p = object.p
	for i in 3:
		var bulb = canvas.lamp_position(object, i)
		var socket = bulb + Vector2(0, 29)
		var progress = canvas.lamp_progress(object, i)
		canvas.draw_line(p, socket, IDLE, 1.5, true)
		if progress > 0:
			var end = p.lerp(socket, progress)
			canvas.draw_line(p, end, Color(BLUE, 0.12), 7, true)
			canvas.draw_line(p, end, BLUE, 2, true)
			canvas.draw_circle(end, 3, Color("c6f1ff"))
		draw_bulb(canvas, bulb, progress >= 0.999)
	var pressed = object.get("pressed", false)
	canvas.draw_ground_shadow(p + Vector2(5, 10), 72, 20)
	canvas.draw_style_box(plate_style(Color("263944"), Color("688694")), Rect2(p - Vector2(59, 59), Vector2(118, 118)))
	canvas.draw_style_box(plate_style(Color("172933") if pressed else Color("20303a"), BLUE if pressed or object.used else IDLE), Rect2(p - Vector2(49, 49), Vector2(98, 98)))
	for x in [-1, 1]:
		for y in [-1, 1]:
			canvas.draw_circle(p + Vector2(x * 53, y * 53), 2.5, Color("a0b2b9"))
	for y in [-18, -9, 0, 9, 18]:
		canvas.draw_line(p + Vector2(-24, y), p + Vector2(24, y), Color("4c646e"), 2, true)
	for i in 3:
		canvas.draw_circle(p + Vector2((i - 1) * 16, 33), 3, BLUE if canvas.lamp_progress(object, i) >= 0.999 else IDLE)

static func draw_bulb(canvas: Node2D, p: Vector2, lit: bool) -> void:
	if lit:
		canvas.draw_circle(p - Vector2(0, 4), 35, Color(BLUE, 0.06))
		canvas.draw_circle(p - Vector2(0, 4), 24, Color(BLUE, 0.10))
	canvas.draw_ground_shadow(p + Vector2(4, 32), 21, 7)
	canvas.draw_rect(Rect2(p + Vector2(-15, 25), Vector2(30, 10)), Color("253b46"))
	canvas.draw_rect(Rect2(p + Vector2(-8, 14), Vector2(16, 13)), Color("758a92"))
	for y in [16, 20, 24]:
		canvas.draw_line(p + Vector2(-8, y), p + Vector2(8, y - 2), Color("263a44"), 2, true)
	var glass = PackedVector2Array([p + Vector2(-7, 14), p + Vector2(-8, 7), p + Vector2(-15, -2), p + Vector2(-17, -12), p + Vector2(-12, -23), p + Vector2(0, -27), p + Vector2(12, -23), p + Vector2(17, -12), p + Vector2(15, -2), p + Vector2(8, 7), p + Vector2(7, 14)])
	canvas.draw_colored_polygon(glass, Color(0.15, 0.60, 0.83, 0.33) if lit else Color(0.20, 0.29, 0.33, 0.4))
	glass.append(glass[0])
	canvas.draw_polyline(glass, BLUE if lit else Color("7b929d"), 2, true)
	canvas.draw_polyline(PackedVector2Array([p + Vector2(-5, 13), p + Vector2(-5, -5), p + Vector2(0, 0), p + Vector2(5, -5), p + Vector2(5, 13)]), Color("d2f5ff") if lit else Color("708992"), 2, true)
	canvas.draw_line(p + Vector2(-11, -16), p + Vector2(-12, -10), Color("d8eff8"), 2, true)

static func draw_data_chip(canvas: Node2D, object: Dictionary) -> void:
	var p = object.p
	for i in 6:
		var field = canvas.data_field_position(object, i)
		var active = object.activated.has(i)
		var color = BLUE if active else IDLE
		canvas.draw_dashed_line(p, field, Color(color, 0.15), 1, 5, true)
		canvas.draw_ground_shadow(field + Vector2(3, 8), 40, 10)
		canvas.draw_style_box(plate_style(Color("172c35"), color), Rect2(field - Vector2(32, 32), Vector2(64, 64)))
		canvas.draw_rect(Rect2(field - Vector2(24, 24), Vector2(48, 48)), Color(color, 0.12), false, 1)
		for side in [-1, 1]:
			canvas.draw_line(field + Vector2(side * 26, -13), field + Vector2(side * 26, 13), color, 2, true)
		label(canvas, field + Vector2(0, 7), "%02d" % (i + 1), 20, BLUE if active else Color("839aa6"))
		if active:
			canvas.draw_line(field + Vector2(-15, 23), field + Vector2(15, 23), BLUE, 2, true)
	canvas.draw_ground_shadow(p + Vector2(5, 14), 62, 19)
	var board = PackedVector2Array([p + Vector2(-42, -47), p + Vector2(23, -47), p + Vector2(43, -27), p + Vector2(43, 45), p + Vector2(-42, 45)])
	canvas.draw_colored_polygon(board, Color("17353e"))
	board.append(board[0])
	canvas.draw_polyline(board, Color("5b8d9d"), 2, true)
	for i in 5:
		var x = (i - 2) * 11
		for side in [-1, 1]:
			canvas.draw_rect(Rect2(p + Vector2(x - 3, side * 24 - 4), Vector2(6, 9)), Color("baab78"))
			canvas.draw_line(p + Vector2(x, side * 30), p + Vector2(x, side * 39), Color("436975"), 1, true)
	canvas.draw_style_box(plate_style(Color("101c23"), BLUE if object.used or object.get("decoding", false) else Color("527580")), Rect2(p - Vector2(29, 19), Vector2(58, 38)))
	label(canvas, p + Vector2(0, 5), "DATA", 16, BLUE)
	label(canvas, p + Vector2(0, 70), "ENTSCHLÜSSELT" if object.used else ("TRANSFER" if object.get("decoding", false) else "%d / 6" % object.activated.size()), 14, BLUE if object.used else Color("94adba"))
	for bit in object.get("bits", []):
		var alpha = bit.get("alpha", 0.0)
		if alpha <= 0: continue
		var font = ThemeDB.fallback_font
		canvas.draw_string_outline(font, bit.p, bit.digit, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color(0.02, 0.05, 0.07, alpha))
		canvas.draw_string(font, bit.p, bit.digit, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.40, 0.84, 1.0, alpha))

static func plate_style(background: Color, border: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style

static func label(canvas: Node2D, p: Vector2, text: String, font_size: int, color: Color) -> void:
	var font = ThemeDB.fallback_font
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(font, p - Vector2(width / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
