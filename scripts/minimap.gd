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
	for segment in arena.monument_walls:
		var points = PackedVector2Array()
		for point in segment.polygon: points.append(point * scale_xy)
		draw_colored_polygon(points, Color("91a99b"))
	draw_circle(arena.goal * scale_xy, 3, Color("5dffc0") if arena.game.goal_unlocked else Color("6b829a"))
	# The same world-to-map transform and visibility mask apply to every feature.
	draw_texture_rect(arena.discovery_texture, Rect2(Vector2.ZERO, size), false)
	for landmark in arena.known_landmarks():
		var p = landmark.p * scale_xy
		var color = Color("54caff") if landmark.kind == "old" else Color("8de4ff")
		if landmark.used:
			color = color.darkened(0.35)
		var sides = 3 if landmark.kind == "old" else 4
		var points = PackedVector2Array()
		for i in sides:
			points.append(p + Vector2.from_angle(TAU * i / sides - (PI / 2 if sides == 3 else PI / 4)) * 5)
		draw_circle(p, 7, Color(0.015, 0.025, 0.035, 0.95))
		points.append(points[0])
		draw_polyline(points, color, 1.5, true)
		if landmark.used:
			draw_circle(p, 1.5, color)
	draw_circle(arena.player * scale_xy, 3.5, Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color("36495e"), false, 1)
