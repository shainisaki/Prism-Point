extends RefCounted
## Conservative broad phase: keeps every object and returns stable insertion order.
const CELL_SIZE = 128.0
var buckets: Dictionary = {}
var bounds: Array[Rect2] = []

func clear() -> void:
	buckets.clear()
	bounds.clear()

func cells(rect: Rect2) -> Rect2i:
	var first = Vector2i((rect.position / CELL_SIZE).floor())
	var last = Vector2i((rect.end / CELL_SIZE).floor())
	return Rect2i(first, last - first + Vector2i.ONE)

func add(rect: Rect2) -> int:
	var slot = bounds.size()
	bounds.append(rect)
	add_cells(slot, cells(rect))
	return slot

func add_cells(slot: int, region: Rect2i) -> void:
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var cell = Vector2i(x, y)
			if not buckets.has(cell): buckets[cell] = []
			buckets[cell].append(slot)

func update(slot: int, rect: Rect2) -> void:
	var old_cells = cells(bounds[slot])
	var new_cells = cells(rect)
	bounds[slot] = rect
	if old_cells == new_cells: return
	for y in range(old_cells.position.y, old_cells.end.y):
		for x in range(old_cells.position.x, old_cells.end.x):
			var cell = Vector2i(x, y)
			buckets[cell].erase(slot)
			if buckets[cell].is_empty(): buckets.erase(cell)
	add_cells(slot, new_cells)

func query(rect: Rect2, after_slot: int = -1) -> Array[int]:
	var region = cells(rect)
	var result: Array[int] = []
	# Very long diagonal rays should not visit thousands of mostly empty cells.
	if region.get_area() > maxi(16, bounds.size() * 2):
		for slot in range(after_slot + 1, bounds.size()):
			if bounds[slot].intersects(rect, true): result.append(slot)
		return result
	var found: Dictionary = {}
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			for slot in buckets.get(Vector2i(x, y), []):
				if slot > after_slot and not found.has(slot) and bounds[slot].intersects(rect, true): found[slot] = true
	result.assign(found.keys())
	result.sort()
	return result
