extends RefCounted
## Re-roll both the room arrangement and the wall vocabulary for every wave.

const THEMES = ["ruins", "courtyards", "passages", "pillars"]
const POOLS = {
	"ruins": ["L", "T", "zigzag", "cross", "gate"],
	"courtyards": ["room", "U", "gate", "L"],
	"passages": ["zigzag", "parallel", "T", "gate"],
	"pillars": ["pillars", "cross", "L", "parallel"],
}

static func generate(previous: String) -> Dictionary:
	var choices = THEMES.duplicate()
	choices.erase(previous)
	var theme: String = choices.pick_random()
	var walls: Array[Rect2] = [Rect2(0, 0, 4800, 28), Rect2(0, 3572, 4800, 28), Rect2(0, 0, 28, 3600), Rect2(4772, 0, 28, 3600)]
	var footprints: Array[Rect2] = []
	var kinds: Array[String] = []
	var count = randi_range(18, 26)
	for attempt in 350:
		if footprints.size() >= count:
			break
		var center = Vector2(randf_range(380, 4420), randf_range(380, 3220))
		var span = randf_range(210, 420)
		var footprint = Rect2(center - Vector2.ONE * (span * 0.7 + 90), Vector2.ONE * (span * 1.4 + 180))
		var overlaps = false
		for other in footprints:
			if footprint.intersects(other):
				overlaps = true
				break
		if overlaps:
			continue
		var kind: String = POOLS[theme].pick_random()
		var pieces = structure(kind, span)
		var angle = (randi() % 4) * PI / 2.0
		for piece in pieces:
			var rotated_center = piece.get_center().rotated(angle) + center
			var extent = piece.size if int(round(angle / (PI / 2))) % 2 == 0 else Vector2(piece.size.y, piece.size.x)
			walls.append(Rect2(rotated_center - extent / 2, extent))
		footprints.append(footprint)
		kinds.append(kind)
	return {"walls": walls, "theme": theme, "structures": kinds}

static func structure(kind: String, span: float) -> Array[Rect2]:
	var t = 28.0
	var h = span / 2
	match kind:
		"L": return [Rect2(-h, -h, span, t), Rect2(-h, -h, t, span)]
		"U": return [Rect2(-h, -h, span, t), Rect2(-h, -h, t, span), Rect2(h - t, -h, t, span)]
		"T": return [Rect2(-h, -h, span, t), Rect2(-t / 2, -h, t, span)]
		"cross": return [Rect2(-h, -t / 2, span, t), Rect2(-t / 2, -h, t, span)]
		"parallel": return [Rect2(-h, -h, span, t), Rect2(-h, h - t, span, t)]
		"zigzag": return [Rect2(-h, -h, span * 0.7, t), Rect2(-t / 2, -h, t, span), Rect2(-span * 0.2, h - t, span * 0.7, t)]
		"gate": return [Rect2(-span * 0.8, -t / 2, span * 0.45, t), Rect2(span * 0.35, -t / 2, span * 0.45, t)]
		"room":
			var gap = 180.0
			var side = maxf(50, (span * 1.4 - gap) / 2)
			var edge = span * 0.7
			return [Rect2(-edge, -edge, side, t), Rect2(gap / 2, -edge, side, t), Rect2(-edge, edge - t, side, t), Rect2(gap / 2, edge - t, side, t), Rect2(-edge, -edge, t, span * 1.4), Rect2(edge - t, -edge, t, span * 1.4)]
		"pillars":
			var pieces: Array[Rect2] = []
			for y in 2:
				for x in 3:
					pieces.append(Rect2(-h + x * h, -h + y * span, 48, 48))
			return pieces
	return []
