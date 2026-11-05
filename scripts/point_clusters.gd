extends RefCounted
## Spatial bins bound neighbor searches even when thousands of points overlap.
const RANGE = 72.0
const MERGE_DISTANCE = 14.0

static func combine(a: Dictionary, b: Dictionary) -> void:
	var total = int(a.value) + int(b.value)
	a.p = (a.p * int(a.value) + b.p * int(b.value)) / maxf(1, total)
	# Keep a compact histogram, rather than one entry per original drop. This
	# preserves per-drop resource rounding when applying the existing economy.
	var parts = a.get("parts", {int(a.value): 1}).duplicate()
	for denomination in b.get("parts", {int(b.value): 1}):
		parts[denomination] = int(parts.get(denomination, 0)) + int(b.get("parts", {int(b.value): 1})[denomination])
	a.parts = parts
	a.value = total

static func reward(pickup: Dictionary, bonus: float, multiplier: int) -> int:
	var total = 0
	for denomination in pickup.get("parts", {int(pickup.value): 1}):
		total += maxi(1, int(int(denomination) + bonus)) * int(pickup.get("parts", {int(pickup.value): 1})[denomination])
	return total * multiplier

static func step(arena: Node2D, delta: float) -> void:
	var bins: Dictionary = {}
	var survivors: Array[Dictionary] = []
	for pickup in arena.pickups:
		if pickup.kind != "point":
			survivors.append(pickup)
			continue
		var cell = Vector2i((pickup.p / RANGE).floor())
		var nearest: Dictionary = {}
		var distance = RANGE
		for y in range(-1, 2):
			for x in range(-1, 2):
				for candidate in bins.get(cell + Vector2i(x, y), []):
					var d = pickup.p.distance_to(candidate.p)
					if d < distance and (d <= MERGE_DISTANCE or arena.line_clear(pickup.p, candidate.p)):
						distance = d
						nearest = candidate
		if not nearest.is_empty():
			if distance <= MERGE_DISTANCE:
				combine(nearest, pickup)
				continue
			var original = pickup.p
			pickup.p = arena.move_circle(pickup.p, (nearest.p - pickup.p).normalized() * minf(distance, delta * 180), 2)
			var share = float(pickup.value) / maxf(1, int(nearest.value) + int(pickup.value))
			nearest.p = arena.move_circle(nearest.p, (original - nearest.p).normalized() * delta * 75 * share, 2)
		else:
			if not bins.has(cell): bins[cell] = []
			bins[cell].append(pickup)
		survivors.append(pickup)
	arena.pickups.assign(survivors)
