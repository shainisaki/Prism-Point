extends Control
## The HUD and world pickups deliberately share the exact same diamond artwork.
const COLOR = Color("60dce4")

func _draw() -> void:
	draw_symbol(self, size / 2, minf(size.x, size.y) * 0.36)

static func draw_symbol(canvas: CanvasItem, p: Vector2, radius: float) -> void:
	var points = PackedVector2Array([p + Vector2(0, -radius), p + Vector2(radius, 0), p + Vector2(0, radius), p + Vector2(-radius, 0)])
	canvas.draw_colored_polygon(points, Color(COLOR, 0.10))
	points.append(points[0])
	canvas.draw_polyline(points, COLOR, 1.5, true)

static func radius(value: int) -> float:
	return minf(21, 5.0 + log(1.0 + maxi(1, value)) / log(2.0) * 1.7)
