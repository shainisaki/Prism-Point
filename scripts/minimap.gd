extends Control

var arena: Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if arena == null or arena.walls.is_empty():
		return
	var scale_xy = size / arena.SIZE
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.035, 0.05, 0.92))
	for wall in arena.walls:
		draw_rect(Rect2(wall.position * scale_xy, wall.size * scale_xy), Color("607184"))
	if arena.route.size() > 1:
		var points = PackedVector2Array()
		for point in arena.route:
			points.append(point * scale_xy)
		draw_polyline(points, Color("395d68"), 1, true)
	for cell in arena.visited:
		draw_rect(Rect2(Vector2(cell) * 100 * scale_xy, Vector2(100, 100) * scale_xy), Color(0.4, 0.7, 0.8, 0.12))
	draw_circle(arena.goal * scale_xy, 3, Color("5dffc0") if arena.game.goal_unlocked else Color("6b829a"))
	draw_circle(arena.player * scale_xy, 3.5, Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color("36495e"), false, 1)
