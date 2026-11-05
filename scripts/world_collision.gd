extends RefCounted
## Static geometry is indexed once per layout; exact collision rules stay intact.
const SpatialIndex = preload("res://scripts/spatial_index.gd")
var index = SpatialIndex.new()
var rectangles: Array[Rect2] = []
var segments: Array[Dictionary] = []

func sync(walls: Array[Rect2], monument_walls: Array[Dictionary]) -> void:
	if rectangles == walls and segments == monument_walls: return
	rectangles.assign(walls)
	segments.assign(monument_walls.duplicate(true))
	index.clear()
	for rect in rectangles: index.add(rect)
	for segment in segments:
		var rect = Rect2(segment.a, Vector2.ZERO).expand(segment.b).grow(segment.width / 2)
		if segment.has("polygon"):
			for point in segment.polygon: rect = rect.expand(point)
		index.add(rect)

func blocked(p: Vector2, radius: float) -> bool:
	return blocked_in(p, radius, index.query(Rect2(p - Vector2.ONE * radius, Vector2.ONE * radius * 2)))

func blocked_in(p: Vector2, radius: float, candidates: Array[int]) -> bool:
	for slot in candidates:
		if slot < rectangles.size():
			var wall = rectangles[slot]
			if p.distance_squared_to(p.clamp(wall.position, wall.end)) < radius * radius: return true
		else:
			var segment = segments[slot - rectangles.size()]
			if segment.has("polygon"):
				var shape = segment.polygon
				if Geometry2D.is_point_in_polygon(p, shape): return true
				for i in shape.size():
					if Geometry2D.get_closest_point_to_segment(p, shape[i], shape[(i + 1) % shape.size()]).distance_to(p) < radius: return true
			elif Geometry2D.get_closest_point_to_segment(p, segment.a, segment.b).distance_to(p) < radius + segment.width / 2: return true
	return false

func line_clear(a: Vector2, b: Vector2) -> bool:
	for slot in index.query(Rect2(a, Vector2.ZERO).expand(b)):
		if slot < rectangles.size():
			var wall = rectangles[slot]
			if Geometry2D.segment_intersects_segment(a, b, wall.position, Vector2(wall.end.x, wall.position.y)) != null or Geometry2D.segment_intersects_segment(a, b, Vector2(wall.end.x, wall.position.y), wall.end) != null or Geometry2D.segment_intersects_segment(a, b, wall.end, Vector2(wall.position.x, wall.end.y)) != null or Geometry2D.segment_intersects_segment(a, b, Vector2(wall.position.x, wall.end.y), wall.position) != null: return false
		else:
			var segment = segments[slot - rectangles.size()]
			if Geometry2D.segment_intersects_segment(a, b, segment.a, segment.b) != null: return false
			if segment.has("polygon"):
				var shape = segment.polygon
				for i in shape.size():
					if Geometry2D.segment_intersects_segment(a, b, shape[i], shape[(i + 1) % shape.size()]) != null: return false
	return true
