extends Control
## Compact, native countdown ring for the floating wave capsule.

var fraction := 1.0
var color := Color("edb854")

func _draw() -> void:
	var center = size / 2
	var radius = minf(size.x, size.y) / 2 - 3
	draw_arc(center, radius, 0, TAU, 48, Color("263e4b"), 3, true)
	draw_arc(center, radius, -PI / 2, -PI / 2 + TAU * clampf(fraction, 0.001, 1.0), 48, color, 3, true)
	draw_line(center, center + Vector2(0, -radius * 0.52), Color("dce8ed"), 1.5, true)
	draw_line(center, center + Vector2(radius * 0.4, 0), Color("dce8ed"), 1.5, true)
