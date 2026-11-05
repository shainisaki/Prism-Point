extends Node2D
## Native world simulation and vector rendering. All movement uses seconds.

const SIZE = Vector2(4800, 3600)
const Layout = preload("res://scripts/arena_layout.gd")
const HEART_DROP_CHANCE = 0.08
const MONUMENT_RADIUS = 360.0
const MONUMENT_WALL_WIDTH = 32.0
const MONUMENT_GATE_WIDTH = 200.0
const DISCOVERY_SCALE = 10.0
const ENEMY_DATA = {
	"runner": [10.0, 2.6, 4.0, "ff5555"], "tank": [16.0, 0.9, 14.0, "aa3333"],
	"shooter": [16.0, 1.35, 7.0, "ff8844"], "dasher": [11.0, 2.9, 4.0, "292939"],
	"splitter": [13.0, 1.6, 9.0, "cc66ff"], "hunter": [11.0, 1.9, 8.0, "44ffaa"],
	"lootling": [12.0, 2.3, 12.0, "b8ff3a"], "drone": [8.0, 3.0, 1.0, "c070ff"],
}
const BOSS_KINDS = ["hexagon", "triangle", "square", "cylinder"]
var game: Node
var player = SIZE / 2.0
var player_radius := 14.0
var facing := Vector2.RIGHT
var camera: Camera2D
var walls: Array[Rect2] = []
var monument_walls: Array[Dictionary] = []
var layout_theme := ""
var structure_kinds: Array[String] = []
var hazards: Array[Rect2] = []
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var enemy_bullets: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var warnings: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []
var objects: Array[Dictionary] = []
var lasers: Array[Dictionary] = []
var floor_dots: Array[Vector2] = []
var goal := Vector2.ZERO
var route := PackedVector2Array()
var grid := AStarGrid2D.new()
var reachable: Array[Vector2i] = []
var discovery: Image
var discovery_texture: ImageTexture
var last_revealed_rect := Rect2i()
var shot_cd := 0.0
var spawn_cd := 1.0
var dash_cd := 0.0
var dash_left := 0.0
var dash_direction := Vector2.RIGHT
var shake := 0.0
var pointer_id := -1
var pointer_start := Vector2.ZERO
var pointer_vector := Vector2.ZERO
var next_id := 1
var laser_event_cd := 3.0
var crystal_texture: Texture2D

func _ready() -> void:
	camera = Camera2D.new()
	add_child(camera)
	camera.position = player
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(SIZE.x)
	camera.limit_bottom = int(SIZE.y)
	crystal_texture = load("res://assets/images/crystal.png")
	reset_discovery()

func _process(_delta: float) -> void:
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if game.state != "playing":
		return
	if event is InputEventScreenTouch:
		if event.pressed and pointer_id == -1:
			pointer_id = event.index
			pointer_start = event.position
		elif not event.pressed and event.index == pointer_id:
			release_pointer()
	elif event is InputEventScreenDrag and event.index == pointer_id:
		pointer_vector = ((event.position - pointer_start) / 65.0).limit_length()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_id = 99
			pointer_start = event.position
		else:
			release_pointer()
	elif event is InputEventMouseMotion and pointer_id == 99:
		pointer_vector = ((event.position - pointer_start) / 65.0).limit_length()

func release_pointer() -> void:
	pointer_id = -1
	pointer_vector = Vector2.ZERO

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_pointer()
		if game != null and game.state == "playing":
			game.pause_run()

func generate_wave() -> void:
	for collection in [walls, monument_walls, hazards, enemies, bullets, enemy_bullets, pickups, warnings, particles, floating_texts, objects, lasers, reachable, floor_dots]:
		collection.clear()
	reset_discovery()
	release_pointer()
	player_radius = float(game.character().radius)
	shot_cd = 0.0
	spawn_cd = 1.0
	laser_event_cd = 3.0
	dash_cd = 0.0
	dash_left = 0.0
	var layout = Layout.generate(layout_theme)
	layout_theme = layout.theme
	walls.assign(layout.walls)
	structure_kinds.assign(layout.structures)
	if not game.boss_wave:
		place_old_monument()
	grid.region = Rect2i(0, 0, 96, 72)
	grid.cell_size = Vector2(50, 50)
	grid.offset = Vector2(25, 25)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var open_cells: Array[Vector2i] = []
	for y in 72:
		for x in 96:
			var cell = Vector2i(x, y)
			grid.set_point_solid(cell, blocked(grid.get_point_position(cell), 57.0))
			if not grid.is_point_solid(cell):
				open_cells.append(cell)
	var start = open_cells.pick_random()
	player = grid.get_point_position(start)
	# Flood-fill once instead of running A* for each prospective pickup.
	var queue: Array[Vector2i] = [start]
	var seen: Dictionary = {start: true}
	var index = 0
	while index < queue.size():
		var cell = queue[index]
		index += 1
		reachable.append(cell)
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var adjacent = cell + direction
			if grid.is_in_boundsv(adjacent) and not seen.has(adjacent) and not grid.is_point_solid(adjacent):
				seen[adjacent] = true
				queue.append(adjacent)
	var goal_cell = reachable.pick_random()
	for attempt in 100:
		goal_cell = reachable.pick_random()
		if grid.get_point_position(goal_cell).distance_to(player) > 1000:
			break
	goal = grid.get_point_position(goal_cell)
	route = grid.get_point_path(start, goal_cell)
	for i in 1800:
		floor_dots.append(Vector2(randf_range(35, SIZE.x - 35), randf_range(35, SIZE.y - 35)))
	if game.boss_wave:
		spawn_boss("endboss" if game.wave == 20 and game.mode != "bossrush" else "")
	else:
		for i in 30:
			objects.append({"kind": "crate", "p": random_open(180), "r": 22.0, "hp": 1.0})
		for i in 8:
			objects.append({"kind": "barrel", "p": random_open(200), "r": 26.0, "hp": 1.0})
		for i in 7:
			hazards.append(Rect2(random_open(300) - Vector2(36, 36), Vector2(72, 72)))
		if randf() < 0.7:
			var near = grid.get_point_position(closest_cell(goal + Vector2(200, 0)))
			objects.append({"kind": "crystal", "p": near, "r": 20.0, "hp": 20.0})
		if randf() < 0.7:
			var p = random_open(400)
			# Satellites must also be reachable and unobstructed.
			for attempt in 60:
				var clear = true
				for i in 6:
					if blocked(p + Vector2.from_angle(TAU * i / 6.0) * 135, 40):
						clear = false
				if clear:
					break
				p = random_open(400)
			objects.append({"kind": "monument", "p": p, "r": 35.0, "activated": [], "used": false})
		objects.append({"kind": "switch", "p": random_open(300), "r": 20.0, "used": false})
		if game.modifier == "elite":
			spawn_boss(BOSS_KINDS.pick_random(), true)
		if game.modifier == "rich":
			for i in 5:
				spawn_enemy("lootling", random_spawn())
	camera.position = player
	camera.reset_smoothing()
	camera.force_update_scroll()
	reveal_view()

func place_old_monument() -> void:
	var center = Vector2(randf_range(650, SIZE.x - 650), randf_range(650, SIZE.y - 650))
	var footprint = Rect2(center - Vector2.ONE * (MONUMENT_RADIUS + 130), Vector2.ONE * (MONUMENT_RADIUS + 130) * 2)
	# Reserve a whole clearing so all three entrances open onto usable terrain.
	for i in range(walls.size() - 1, 3, -1):
		if walls[i].intersects(footprint):
			walls.remove_at(i)
	var object = {"kind": "old", "p": center, "r": 95.0, "radius": MONUMENT_RADIUS, "charge": 0.0, "used": false}
	objects.append(object)
	var vertices = polygon(center, MONUMENT_RADIUS, 3, -PI / 2)
	for i in 3:
		var a = vertices[i]
		var b = vertices[(i + 1) % 3]
		var middle = (a + b) / 2
		var direction = (b - a).normalized()
		monument_walls.append({"a": a, "b": middle - direction * MONUMENT_GATE_WIDTH / 2, "width": MONUMENT_WALL_WIDTH})
		monument_walls.append({"a": middle + direction * MONUMENT_GATE_WIDTH / 2, "b": b, "width": MONUMENT_WALL_WIDTH})

func reset_discovery() -> void:
	discovery = Image.create(int(SIZE.x / DISCOVERY_SCALE), int(SIZE.y / DISCOVERY_SCALE), false, Image.FORMAT_RGBA8)
	discovery.fill(Color(0.015, 0.025, 0.035, 1))
	discovery_texture = ImageTexture.create_from_image(discovery)
	last_revealed_rect = Rect2i()

func visible_world_rect() -> Rect2:
	var extent = get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - extent / 2, extent).intersection(Rect2(Vector2.ZERO, SIZE))

func reveal_view() -> void:
	var view = visible_world_rect()
	var begin = Vector2i((view.position / DISCOVERY_SCALE).floor())
	var end = Vector2i((view.end / DISCOVERY_SCALE).ceil())
	var rectangle = Rect2i(begin, end - begin).intersection(Rect2i(Vector2i.ZERO, discovery.get_size()))
	if rectangle == last_revealed_rect:
		return
	last_revealed_rect = rectangle
	discovery.fill_rect(rectangle, Color.TRANSPARENT)
	discovery_texture.update(discovery)

func is_discovered(p: Vector2) -> bool:
	var point = Vector2i(p / DISCOVERY_SCALE)
	return Rect2i(Vector2i.ZERO, discovery.get_size()).has_point(point) and discovery.get_pixelv(point).a < 0.5

func random_open(min_distance: float = 0.0) -> Vector2:
	var p = player
	for attempt in 100:
		p = grid.get_point_position(reachable.pick_random())
		var reserved = false
		for object in objects:
			if object.kind == "old" and p.distance_to(object.p) < MONUMENT_RADIUS + 120:
				reserved = true
		if not reserved and p.distance_to(player) >= min_distance:
			break
	return p

func closest_cell(p: Vector2) -> Vector2i:
	var cell = Vector2i((p / grid.cell_size).floor())
	if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):
		return cell
	var nearest = reachable[0]
	var distance = INF
	for candidate in reachable:
		var d = grid.get_point_position(candidate).distance_squared_to(p)
		if d < distance:
			distance = d
			nearest = candidate
	return nearest

func random_spawn() -> Vector2:
	for attempt in 30:
		var p = player + Vector2.from_angle(randf() * TAU) * randf_range(200, 360)
		if not blocked(p, 22) and p.x > 50 and p.y > 50 and p.x < SIZE.x - 50 and p.y < SIZE.y - 50:
			return p
	return random_open(180)

func blocked(p: Vector2, radius: float) -> bool:
	for wall in walls:
		if circle_rect(p, radius, wall):
			return true
	for segment in monument_walls:
		if Geometry2D.get_closest_point_to_segment(p, segment.a, segment.b).distance_to(p) < radius + segment.width / 2:
			return true
	return false

func circle_rect(p: Vector2, radius: float, rect: Rect2) -> bool:
	return p.distance_squared_to(p.clamp(rect.position, rect.end)) < radius * radius

func move_circle(p: Vector2, movement: Vector2, radius: float, include_objects: bool = false) -> Vector2:
	var steps = maxi(1, int(ceil(movement.length() / maxf(8, radius))))
	var step = movement / steps
	for i in steps:
		var next = p + Vector2(step.x, 0)
		if not blocked(next, radius):
			p = next
		next = p + Vector2(0, step.y)
		if not blocked(next, radius):
			p = next
	if include_objects:
		for object in objects:
			if object.kind not in ["crate", "barrel"] or object.hp <= 0:
				continue
			var diff = p - object.p
			var min_dist = radius + object.r
			if diff.length() < min_dist:
				var pushed = object.p + diff.normalized() * min_dist
				if not blocked(pushed, radius):
					p = pushed
	return p.clamp(Vector2.ONE * (radius + 28), SIZE - Vector2.ONE * (radius + 28))

func line_clear(a: Vector2, b: Vector2) -> bool:
	for segment in monument_walls:
		if Geometry2D.segment_intersects_segment(a, b, segment.a, segment.b) != null:
			return false
	for wall in walls:
		if Geometry2D.segment_intersects_segment(a, b, wall.position, Vector2(wall.end.x, wall.position.y)) != null or Geometry2D.segment_intersects_segment(a, b, Vector2(wall.end.x, wall.position.y), wall.end) != null or Geometry2D.segment_intersects_segment(a, b, wall.end, Vector2(wall.position.x, wall.end.y)) != null or Geometry2D.segment_intersects_segment(a, b, Vector2(wall.position.x, wall.end.y), wall.position) != null:
			return false
	return true

func simulate(delta: float) -> void:
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if pointer_vector.length() > 0.1:
		direction = pointer_vector
	if direction.length() > 0.1:
		facing = direction.normalized()
	dash_cd = maxf(0, dash_cd - delta)
	if Input.is_action_just_pressed("dash") and game.stats.speed >= 10 and dash_cd <= 0:
		dash_left = 0.2
		dash_cd = 2.0
		dash_direction = facing
		burst(player, Color("aaccff"), 14)
	var movement = direction * game.player_speed() * delta
	if dash_left > 0:
		movement = dash_direction * 1900.0 * clampf(game.player_speed() / 288.0, 0.75, 1.6) * delta
		dash_left -= delta
	player = move_circle(player, movement, player_radius, true)
	camera.position = player
	shake = move_toward(shake, 0.0, delta * 25)
	camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	camera.force_update_scroll()
	reveal_view()
	shot_cd -= delta
	if shot_cd <= 0:
		if shoot():
			shot_cd = game.shot_interval()
	spawn_cd -= delta
	if game.modifier == "laser":
		laser_event_cd -= delta
		if laser_event_cd <= 0:
			laser_event_cd = 3.0
			var origin = random_spawn()
			lasers.append({"a": origin, "b": origin + (player - origin).normalized() * 900, "time": 0.0})
	if spawn_cd <= 0 and not game.boss_wave and not game.goal_unlocked:
		spawn_cd = maxf(0.65, 2.2 - (game.wave - 1) * 0.048 - game.difficulty() * 0.00018)
		var count = randi_range(1, mini(8, 2 + int((game.wave - 1) * 0.4))) + (2 if game.modifier == "swarm" else 0)
		for i in mini(count, 55 - enemies.size() - warnings.size()):
			warnings.append({"p": random_spawn(), "time": 0.55, "kind": pick_enemy_type()})
	for i in range(warnings.size() - 1, -1, -1):
		warnings[i].time -= delta
		if warnings[i].time <= 0:
			spawn_enemy(warnings[i].kind, warnings[i].p)
			warnings.remove_at(i)
	for enemy in enemies.duplicate():
		if enemy.hp > 0:
			update_enemy(enemy, delta)
	update_projectiles(bullets, delta, false)
	update_projectiles(enemy_bullets, delta, true)
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].hp <= 0:
			enemies.remove_at(i)
	update_pickups(delta)
	update_objects(delta)
	for hazard in hazards:
		if hazard.has_point(player) and sin(game.elapsed * 2.0) > 0.25:
			game.hurt(1)
	for i in range(lasers.size() - 1, -1, -1):
		var beam = lasers[i]
		beam.time += delta
		if beam.time > 0.9 and beam.time < 1.3 and Geometry2D.get_closest_point_to_segment(player, beam.a, beam.b).distance_to(player) < player_radius + 8:
			game.hurt(2)
		if beam.time > 1.4:
			lasers.remove_at(i)
	if game.state == "playing" and game.goal_unlocked and not game.boss_wave and player.distance_to(goal) < player_radius + 28:
		game.open_shop()
	for i in range(particles.size() - 1, -1, -1):
		particles[i].life -= delta
		particles[i].p += particles[i].v * delta
		if particles[i].life <= 0:
			particles.remove_at(i)
	for i in range(floating_texts.size() - 1, -1, -1):
		floating_texts[i].life -= delta
		floating_texts[i].p.y -= 42.0 * delta
		if floating_texts[i].life <= 0:
			floating_texts.remove_at(i)

func pick_enemy_type() -> String:
	if game.modifier == "swarm":
		return "runner" if randf() < 0.85 else "tank"
	if game.modifier == "dash" and randf() < 0.45:
		return "dasher"
	if game.wave <= 4:
		return "runner" if randf() < 0.92 else "tank"
	var pool = ["runner", "runner", "tank", "shooter"]
	if game.wave >= 7:
		pool.append_array(["dasher", "splitter"])
	if game.wave >= 10:
		pool.append("hunter")
	return pool.pick_random()

func spawn_enemy(kind: String, p: Vector2) -> Dictionary:
	var data = ENEMY_DATA[kind]
	var w = game.wave
	var speed_mul = 1 + minf(0.45, (w - 1) * 0.025 + game.difficulty() * 0.1 / 280)
	var health = 1.0 if w == 1 else round(1 + maxf(1, data[2] / 4.0) * (w - 1) * 0.85 + (w - 1) * 0.55 + game.difficulty() * 0.25 / 60 + pow(maxi(0, w - 5), 1.1) * 0.12)
	var enemy = {"id": next_id, "kind": kind, "p": p, "r": data[0], "speed": (data[1] + (w * 0.04 if kind == "runner" else 0.0)) * 60.0 * speed_mul * game.enemy_speed_mult,
		"hp": maxf(1, health * game.enemy_hp_mult), "max_hp": maxf(1, health * game.enemy_hp_mult), "color": Color(data[3]), "flash": 0.0,
		"cd": randf_range(0.6, 1.8), "nav_cd": 0.0, "path": PackedVector2Array(), "boss": false, "dash": 0.0, "velocity": Vector2.ZERO, "age": 0.0}
	if game.modifier == "haste":
		enemy.speed *= 1.22
	if kind == "lootling":
		enemy.hp = 12.0
		enemy.max_hp = 12.0
	next_id += 1
	enemies.append(enemy)
	return enemy

func spawn_boss(kind: String = "", elite: bool = false) -> void:
	if kind == "":
		kind = BOSS_KINDS.pick_random() if game.mode == "bossrush" else BOSS_KINDS[posmod(int(game.wave / 10.0) - 1, 4)]
	var health = round(140 * (1.2 + (game.wave - 1) * 0.22 + game.difficulty() * 0.25 / 50.0)) * game.enemy_hp_mult
	if game.mode == "bossrush":
		health *= 0.9
	if elite:
		health *= 0.4
	var center = random_open(400)
	if kind == "endboss":
		center = Vector2(2450, 1850)
		for i in range(walls.size() - 1, -1, -1):
			if walls[i].get_center().distance_to(center) < 450:
				walls.remove_at(i)
		for i in 6:
			var node = boss_dictionary("endboss_node", center + Vector2.from_angle(TAU * i / 6.0) * 220, 36, 240, Color.WHITE, false)
			enemies.append(node)
		enemies.append(boss_dictionary(kind, center, 70, 2000, Color.WHITE, false))
		player = center + Vector2(0, 420)
		return
	var colors = {"hexagon": Color("c070ff"), "triangle": Color("ff6644"), "square": Color("44aaff"), "cylinder": Color("8b5a2b")}
	var boss = boss_dictionary(kind, center, 60.0 if kind != "cylinder" else 110.0, health, colors[kind], elite)
	enemies.append(boss)
	if kind == "cylinder":
		var shared = {"hp": health, "max_hp": health}
		boss.shared = shared
		for i in 4:
			var clone = boss_dictionary(kind, Vector2(220, 600 + i * 700), 110, health, colors[kind], elite)
			clone.shared = shared
			clone.velocity = Vector2(randf_range(270, 330), 0)
			enemies.append(clone)
		boss.velocity = Vector2(300, 0)

func boss_dictionary(kind: String, p: Vector2, radius: float, health: float, color: Color, elite: bool) -> Dictionary:
	var result = {"id": next_id, "kind": kind, "p": p, "r": radius, "hp": health, "max_hp": health, "color": color, "flash": 0.0,
		"speed": 90.0, "boss": true, "elite": elite, "cd": 1.5, "age": 0.0, "roll": 0.0, "nav_cd": 0.0, "path": PackedVector2Array(), "dash": 0.0, "velocity": Vector2.ZERO, "invisible": false}
	next_id += 1
	return result

func update_enemy(enemy: Dictionary, delta: float) -> void:
	enemy.age += delta
	enemy.flash = maxf(0, enemy.flash - delta)
	enemy.cd -= delta
	if enemy.boss:
		update_boss(enemy, delta)
	else:
		var diff = player - enemy.p
		var direction = diff.normalized()
		if enemy.kind == "shooter":
			if diff.length() < 180:
				direction = -direction
			elif diff.length() < 260:
				direction = direction.rotated(PI / 2) * 0.4
			if enemy.cd <= 0 and line_clear(enemy.p, player):
				fire_enemy(enemy.p, diff.angle(), 300)
				enemy.cd = 1.4
		elif enemy.kind == "hunter":
			direction = direction.rotated(sin(enemy.age * 1.5) * 0.75)
		elif enemy.kind == "lootling":
			direction = Vector2.from_angle(enemy.age + enemy.id)
		elif enemy.kind == "dasher":
			if enemy.cd <= 0:
				enemy.velocity = direction * 650
				enemy.dash = 0.32
				enemy.cd = 2.5
			if enemy.cd < 0.5:
				direction = Vector2.ZERO
		if not line_clear(enemy.p, player) and enemy.kind != "lootling":
			direction = navigate(enemy, delta)
		var movement = direction * enemy.speed * delta
		if enemy.dash > 0:
			enemy.dash -= delta
			movement = enemy.velocity * delta
		enemy.p = move_circle(enemy.p, movement, enemy.r)
	# Mild separation keeps overlapping hordes readable without blocking paths.
	for other in enemies:
		if other.id == enemy.id or other.hp <= 0:
			continue
		var diff = enemy.p - other.p
		var radius = (enemy.r + other.r) * 0.8
		if diff.length_squared() < radius * radius and diff.length_squared() > 0.01:
			enemy.p = move_circle(enemy.p, diff.normalized() * 35 * delta, enemy.r)
	if enemy.p.distance_to(player) < player_radius + enemy.r and not enemy.get("invisible", false):
		game.hurt(maxi(1, int(round(game.enemy_damage_mult * (2 if enemy.boss else 1)))), enemy)

func navigate(enemy: Dictionary, delta: float) -> Vector2:
	enemy.nav_cd -= delta
	if enemy.nav_cd <= 0:
		enemy.nav_cd = randf_range(0.4, 0.7)
		var a = closest_cell(enemy.p)
		var b = closest_cell(player)
		enemy.path = grid.get_point_path(a, b)
	while enemy.path.size() > 0 and enemy.p.distance_to(enemy.path[0]) < 65:
		enemy.path.remove_at(0)
	return (enemy.path[0] - enemy.p).normalized() if enemy.path.size() > 0 else (player - enemy.p).normalized()

func update_boss(enemy: Dictionary, delta: float) -> void:
	var phase = 1 + int((1.0 - enemy.hp / enemy.max_hp) * 2.99)
	var diff = player - enemy.p
	var kind = enemy.kind
	if kind == "endboss_node":
		return
	if kind == "endboss":
		if enemy.cd <= 0:
			for i in 3:
				fire_enemy(enemy.p, diff.angle() + (i - 1) * 0.2, 132, Color.WHITE, 10, true)
			enemy.cd = 1.4
		return
	if kind == "hexagon":
		if phase >= 3 and not enemy.get("duplicated", false):
			enemy.duplicated = true
			enemy.shared = {"hp": enemy.hp, "max_hp": enemy.max_hp}
			for i in 2:
				var clone = boss_dictionary("hexagon", enemy.p + Vector2.from_angle(TAU * i / 2) * 140, enemy.r, enemy.max_hp, enemy.color, enemy.elite)
				clone.shared = enemy.shared
				clone.hp = enemy.hp
				clone.duplicated = true
				enemies.append(clone)
		enemy.invisible = phase >= 2 and fmod(enemy.age, 8.0) > 6.0
		if enemy.cd <= 0:
			for i in 6 + phase * 2:
				fire_enemy(enemy.p, TAU * i / (6 + phase * 2) + enemy.age, 180 + phase * 30, enemy.color)
			if phase >= 2 and enemies.size() < 50:
				for i in phase:
					spawn_enemy("drone", enemy.p + Vector2.from_angle(randf() * TAU) * 80)
			enemy.cd = 2.6 - phase * 0.3
		enemy.p = move_circle(enemy.p, diff.normalized() * 75 * delta, enemy.r)
	elif kind in ["triangle", "square"]:
		if enemy.cd <= 0:
			enemy.velocity = diff.normalized() * (700 if kind == "square" else 420)
			enemy.dash = 0.5
			enemy.cd = 3.0 - phase * 0.35
			if kind == "triangle":
				for i in phase:
					var angle = diff.angle() + (i - (phase - 1) / 2.0) * 0.25
					lasers.append({"a": enemy.p, "b": enemy.p + Vector2.from_angle(angle) * 1300, "time": 0.0})
		if enemy.dash > 0:
			enemy.dash -= delta
			enemy.p = move_circle(enemy.p, enemy.velocity * delta, enemy.r)
		elif enemy.cd > 0.7:
			enemy.p = move_circle(enemy.p, diff.normalized().rotated(sin(enemy.age) * 0.5) * 120 * delta, enemy.r)
	elif kind == "cylinder":
		var before = enemy.p
		enemy.p = move_circle(enemy.p, enemy.velocity * delta, enemy.r)
		# Rotate in proportion to actual travel, including reversing on impact.
		enemy.roll += (enemy.p.x - before.x) / (enemy.r * 0.68)
		if absf(enemy.p.x - before.x) < 0.1:
			enemy.velocity.x = -enemy.velocity.x
			shake = 6.0
		if enemy.cd <= 0:
			for i in 4 + phase * 2:
				fire_enemy(enemy.p, TAU * i / (4 + phase * 2), 170, Color("dfb481"))
			enemy.cd = 3.0

func fire_enemy(p: Vector2, angle: float, speed: float, color: Color = Color("ff8844"), radius: float = 6.0, sickle: bool = false) -> void:
	if enemy_bullets.size() < 400:
		enemy_bullets.append({"p": p, "v": Vector2.from_angle(angle) * speed, "life": 5.0, "r": radius, "color": color, "damage": 1, "sickle": sickle})

func shoot() -> bool:
	var target = Vector2.ZERO
	var nearest = game.attack_range()
	var found = false
	for enemy in enemies:
		if enemy.hp <= 0 or enemy.get("invisible", false):
			continue
		var distance = player.distance_to(enemy.p)
		if distance < nearest and line_clear(player, enemy.p):
			nearest = distance
			target = enemy.p
			found = true
	for object in objects:
		if object.kind not in ["crystal", "crate", "barrel"] or object.hp <= 0:
			continue
		var distance = player.distance_to(object.p)
		if distance < nearest and line_clear(player, object.p):
			nearest = distance
			target = object.p
			found = true
	if not found:
		return false
	var count = 1 if game.selected_character == "sniper" else 1 + int(game.stats.attack / 10.0)
	var grenade = game.character().get("passive", "") == "grenades"
	for i in count:
		var angle = player.angle_to_point(target) + ((float(i) / maxi(1, count - 1) - 0.5) * minf(0.44, 0.12 + (count - 1) * 0.07) if count > 1 else 0.0)
		bullets.append({"p": player, "v": Vector2.from_angle(angle) * (460 if grenade else 720), "life": maxf(0.3, game.attack_range() / (460.0 if grenade else 720.0)), "r": 7.0 if grenade else 4.0,
			"color": Color("ffba55") if grenade else Color("aee5ff"), "damage": game.player_damage(), "grenade": grenade, "pierce": game.pierce, "bounce": 2 if game.selected_character == "sniper" else 0, "hit": {}})
	if not game.test_mode:
		game.audio.effect("shot")
	return true

func update_projectiles(collection: Array[Dictionary], delta: float, hostile: bool) -> void:
	for i in range(collection.size() - 1, -1, -1):
		var bullet = collection[i]
		bullet.life -= delta
		var old = bullet.p
		if bullet.get("sickle", false):
			bullet.v = bullet.v.rotated(delta * 0.4)
		bullet.p += bullet.v * delta
		var remove = bullet.life <= 0
		if blocked(bullet.p, bullet.r):
			if not hostile and bullet.bounce > 0:
				if blocked(Vector2(bullet.p.x, old.y), bullet.r):
					bullet.v.x = -bullet.v.x
				else:
					bullet.v.y = -bullet.v.y
				bullet.bounce -= 1
				bullet.p = old
			else:
				remove = true
		if hostile:
			if Geometry2D.get_closest_point_to_segment(player, old, bullet.p).distance_to(player) < player_radius + bullet.r:
				game.hurt(bullet.damage)
				remove = true
		else:
			for enemy in enemies.duplicate():
				if enemy.hp <= 0 or bullet.hit.has(enemy.id) or enemy.get("invisible", false):
					continue
				if Geometry2D.get_closest_point_to_segment(enemy.p, old, bullet.p).distance_to(enemy.p) < enemy.r + bullet.r:
					bullet.hit[enemy.id] = true
					if not bullet.grenade:
						damage_enemy(enemy, bullet.damage)
					if not bullet.pierce or bullet.grenade:
						remove = true
						break
			for object in objects:
				if object.kind not in ["crate", "barrel", "crystal"] or object.hp <= 0:
					continue
				if Geometry2D.get_closest_point_to_segment(object.p, old, bullet.p).distance_to(object.p) < object.r + bullet.r:
					damage_object(object, bullet.damage)
					remove = true
					break
		if remove:
			if not hostile and bullet.grenade:
				explode(bullet.p, 85.0, bullet.damage, false)
			collection.remove_at(i)

func damage_enemy(enemy: Dictionary, amount: float) -> void:
	if enemy.hp <= 0 or enemy.get("invisible", false):
		return
	if enemy.get("kind") == "endboss":
		for other in enemies:
			if other.kind == "endboss_node" and other.hp > 0:
				return
	enemy.hp -= amount
	if enemy.has("shared"):
		enemy.shared.hp -= amount
		for other in enemies:
			if other.has("shared") and is_same(other.shared, enemy.shared):
				other.hp = enemy.shared.hp
	enemy.flash = 0.12
	burst(enemy.p, enemy.color, 4)
	if enemy.hp > 0:
		return
	burst(enemy.p, enemy.color, 16)
	game.register_kill(enemy.p)
	pickups.append({"p": enemy.p, "value": 1, "kind": "point"})
	if randf() < HEART_DROP_CHANCE:
		pickups.append({"p": enemy.p + Vector2(12, 0), "value": 1, "kind": "heart"})
	if enemy.kind == "splitter":
		for i in 2:
			var child = spawn_enemy("runner", enemy.p + Vector2(i * 22 - 11, 0))
			child.hp = 1.0
			child.r = 8.0
			child.color = Color("dd88ff")
	if enemy.kind == "lootling":
		if randf() < 0.5:
			game.points += 250
			game.ui.toast("+250 Punkte")
		else:
			for i in 3:
				apply_stat(game.stats.keys().pick_random(), 1)
	if enemy.boss:
		if enemy.kind == "endboss_node":
			return
		game.points += 25
		game.store.data.gold += randi_range(1, 2)
		game.store.save_progress()
		shake = 12.0
		if not game.test_mode:
			game.audio.effect("boss")
		if not enemy.elite:
			var remaining = false
			for other in enemies:
				if other.boss and not other.elite and other.hp > 0:
					remaining = true
			if not remaining:
				lasers.clear()
				game.open_shop()

func damage_object(object: Dictionary, damage: float) -> void:
	object.hp -= damage
	if object.hp > 0:
		return
	burst(object.p, Color("bca281"), 12)
	if object.kind == "barrel":
		explode(object.p, 70, 8, true)
	elif object.kind == "crystal":
		game.points += 150
		game.resource_mult = 3
		game.ui.toast("Kristall zerstört · +150 Punkte · Ressourcen ×3")
	else:
		pickups.append({"p": object.p, "value": 1, "kind": "point"})

func explode(p: Vector2, radius: float, damage: float, hurt_player: bool) -> void:
	burst(p, Color("ff9944"), 24)
	particles.append({"p": p, "v": Vector2.ZERO, "life": 0.25, "color": Color("ff9944"), "ring": radius})
	shake = 5.0
	for enemy in enemies.duplicate():
		if enemy.p.distance_to(p) < radius + enemy.r:
			damage_enemy(enemy, damage)
	if hurt_player and player.distance_to(p) < radius + player_radius:
		game.hurt(1)

func update_pickups(delta: float) -> void:
	var magnet = 75.0 + game.stats.magnet * 22 + (12 if game.focus == "mobility" else 0)
	for i in range(pickups.size() - 1, -1, -1):
		var pickup = pickups[i]
		var distance = pickup.p.distance_to(player)
		if pickup.kind == "heart" and game.hp >= game.max_hp:
			continue
		if distance < magnet:
			pickup.p = pickup.p.move_toward(player, (180 + (magnet - distance) * 3) * delta)
		if pickup.p.distance_to(player) < player_radius + 8:
			if pickup.kind == "pierce":
				game.pierce = true
			elif pickup.kind == "heart":
				game.hp = mini(game.max_hp, game.hp + 1)
				burst(player, Color("ff526a"), 8)
			else:
				game.points += maxi(1, int(pickup.value + floor(game.stats.resource * 0.6) + game.character().resource + (1 if game.focus == "economy" else 0))) * game.resource_mult
			pickups.remove_at(i)
			if not game.test_mode:
				game.audio.effect("collect")

func update_objects(delta: float) -> void:
	for object in objects:
		if object.get("used", false):
			continue
		if object.kind == "switch" and object.p.distance_to(player) < player_radius + object.r:
			object.used = true
			game.goal_unlocked = true
			game.ui.toast("Versteckten Schalter gefunden · Shop geöffnet")
		elif object.kind == "monument":
			for i in 6:
				var satellite = object.p + Vector2.from_angle(TAU * i / 6) * 135
				if not object.activated.has(i) and satellite.distance_to(player) < player_radius + 24:
					object.activated.append(i)
					burst(satellite, Color("ffd24a"), 12)
			if object.activated.size() == 6:
				object.used = true
				var key = game.stats.keys().pick_random()
				apply_stat(key, 1.0 if key in ["vitality", "armor"] else [0.25, 0.5, 0.75].pick_random())
		elif object.kind == "old":
			object.charge = clampf(object.charge + delta * (1.0 if player.distance_to(object.p) < object.r else -1.1), 0, 2.4)
			if object.charge >= 2.4:
				object.used = true
				game.state = "monument"
				release_pointer()
				game.ui.monument_screen()

func apply_stat(key: String, amount: float) -> void:
	game.stats[key] = maxf(0, game.stats[key] + amount)
	if key == "vitality":
		game.recalculate_health()
		game.hp = mini(game.max_hp, game.hp + maxi(0, int(amount)))
	game.ui.toast("Monument: %+.2f %s" % [amount, game.catalog.passive_meta[key].name])

func burst(p: Vector2, color: Color, count: int) -> void:
	for i in mini(count, 200 - particles.size()):
		particles.append({"p": p, "v": Vector2.from_angle(randf() * TAU) * randf_range(30, 180), "life": randf_range(0.15, 0.5), "color": color})

func polygon(center: Vector2, radius: float, sides: int, angle: float = 0.0) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in sides:
		points.append(center + Vector2.from_angle(TAU * i / sides + angle) * radius)
	return points

func glow(p: Vector2, radius: float, color: Color) -> void:
	draw_circle(p, radius * 2.2, Color(color, 0.05))
	draw_circle(p, radius * 1.5, Color(color, 0.10))
	draw_circle(p, radius, color)

func _draw() -> void:
	if walls.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("11151a"))
	var visible = Rect2(camera.get_screen_center_position() - get_viewport_rect().size / 2 - Vector2(150, 150), get_viewport_rect().size + Vector2(300, 300))
	for p in floor_dots:
		if visible.has_point(p):
			draw_circle(p, 1.3, Color("49443b"))
	for x in range(0, 4800, 100):
		draw_line(Vector2(x, 0), Vector2(x, 3600), Color(0.4, 0.6, 0.7, 0.025))
	for y in range(0, 3600, 100):
		draw_line(Vector2(0, y), Vector2(4800, y), Color(0.4, 0.6, 0.7, 0.025))
	if route.size() > 1:
		var color = Color("4b9e8b") if game.goal_unlocked else Color("394653")
		draw_polyline(route, Color(color, 0.12), 16, true)
		for i in range(1, route.size()):
			draw_dashed_line(route[i - 1], route[i], Color(color, 0.65), 2, 7, true)
	for hazard in hazards:
		draw_rect(hazard, Color(0.8, 0.2, 0.25, 0.16 if sin(game.elapsed * 2) > 0.25 else 0.04))
		draw_rect(hazard, Color("813b47"), false, 1)
	for wall in walls:
		if not visible.intersects(wall):
			continue
		draw_rect(Rect2(wall.position + Vector2(6, 8), wall.size), Color(0, 0, 0, 0.4))
		draw_rect(wall, Color("303a44"))
		draw_rect(wall, Color("586573"), false, 2)
		draw_line(wall.position + Vector2(2, 2), Vector2(wall.end.x - 2, wall.position.y + 2), Color("6b7782"), 2)
	for segment in monument_walls:
		draw_line(segment.a + Vector2(6, 8), segment.b + Vector2(6, 8), Color(0, 0, 0, 0.5), segment.width + 8, true)
		draw_line(segment.a, segment.b, Color("56636a"), segment.width, true)
		draw_line(segment.a, segment.b, Color("85918e"), segment.width - 8, true)
		draw_line(segment.a, segment.b, Color("424d50"), 3, true)
	var goal_color = Color("5dffc0") if game.goal_unlocked else Color("526476")
	draw_arc(goal, 36 + sin(game.elapsed * 3) * 3, 0, TAU, 48, Color(goal_color, 0.5), 2, true)
	draw_colored_polygon(polygon(goal, 22, 6, game.elapsed * 0.4), goal_color)
	draw_string(ThemeDB.fallback_font, goal + Vector2(-22, -48), "SHOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, goal_color)
	for object in objects:
		if not visible.grow(MONUMENT_RADIUS if object.kind == "old" else 150).has_point(object.p) or object.get("hp", 1) <= 0:
			continue
		draw_object(object)
	for warning in warnings:
		draw_arc(warning.p, 12 + warning.time * 25, 0, TAU, 24, Color("ff6b6b"), 1.5, true)
		draw_line(warning.p - Vector2(6, 6), warning.p + Vector2(6, 6), Color("ff6b6b"), 2)
		draw_line(warning.p - Vector2(-6, 6), warning.p + Vector2(-6, 6), Color("ff6b6b"), 2)
	for pickup in pickups:
		if visible.has_point(pickup.p):
			if pickup.kind == "heart":
				draw_heart(pickup.p + Vector2(0, sin(game.elapsed * 4) * 2))
			else:
				glow(pickup.p, 5 if pickup.kind == "point" else 10, Color("6ebeff") if pickup.kind == "point" else Color("e8b0ff"))
	for enemy in enemies:
		if not visible.has_point(enemy.p) or enemy.hp <= 0:
			continue
		draw_enemy(enemy)
	for collection in [bullets, enemy_bullets]:
		for bullet in collection:
			if visible.has_point(bullet.p):
				draw_line(bullet.p - bullet.v.normalized() * 12, bullet.p, Color(bullet.color, 0.45), bullet.r * 1.2, true)
				glow(bullet.p, bullet.r, bullet.color)
	for beam in lasers:
		var active = beam.time > 0.9 and beam.time < 1.3
		draw_line(beam.a, beam.b, Color(1, 0.3, 0.2, 0.9 if active else 0.25), 12 if active else 2, true)
	for particle in particles:
		if particle.has("ring"):
			draw_arc(particle.p, particle.ring * (1 - particle.life / 0.3), 0, TAU, 40, Color(particle.color, particle.life * 2), 3, true)
		else:
			draw_circle(particle.p, 2.0, Color(particle.color, minf(1.0, particle.life * 3)))
	var player_color = Color(game.character().color)
	if game.selected_character == "sniper":
		player_color = Color("b0b8cc")
	if game.invincible <= 0 or fmod(game.invincible, 0.14) < 0.07:
		draw_circle(player + Vector2(3, 6), player_radius + 2, Color(0, 0, 0, 0.4))
		draw_arc(player, player_radius + 5, 0, TAU, 40, Color(player_color, 0.15), 5, true)
		draw_circle(player, player_radius, player_color)
		draw_line(player, player + facing * (player_radius + 8), Color("75d4ff"), 5, true)
	for popup in floating_texts:
		var alpha = clampf(popup.life / 0.4, 0, 1)
		var font = ThemeDB.fallback_font
		var origin = popup.p - Vector2(font.get_string_size(popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x / 2, 0)
		draw_string_outline(font, origin, popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, 6, Color(0.06, 0.04, 0, alpha))
		draw_string(font, origin, popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color(1, 0.85, 0.15, alpha))

func draw_enemy(enemy: Dictionary) -> void:
	var color = Color.WHITE if enemy.flash > 0 else enemy.color
	if enemy.get("invisible", false):
		color = Color(color, 0.12)
	draw_circle(enemy.p + Vector2(3, 5), enemy.r, Color(0, 0, 0, 0.35))
	var kind = enemy.kind
	if kind in ["hexagon", "triangle", "square", "endboss", "endboss_node", "splitter", "dasher"]:
		var sides = 6 if kind == "hexagon" else (3 if kind == "triangle" else 4)
		var vertices = polygon(enemy.p, enemy.r, sides, enemy.age * 0.3)
		draw_colored_polygon(vertices, Color(color, 0.18))
		vertices.append(vertices[0])
		draw_polyline(vertices, color, 3, true)
		draw_circle(enemy.p, 4, color)
	elif kind == "cylinder":
		draw_barrel_boss(enemy, color)
	else:
		draw_circle(enemy.p, enemy.r, Color(color, 0.22))
		draw_arc(enemy.p, enemy.r, 0, TAU, 28, color, 2.5, true)
		draw_circle(enemy.p, enemy.r * 0.5, color)
	if enemy.kind == "dasher" and enemy.cd < 0.5:
		draw_line(enemy.p, enemy.p + (player - enemy.p).normalized() * 180, Color("f8adad"), 1.5)
	if game.store.data.settings.get("enemy_bars", false) or enemy.boss:
		var width = maxf(28, enemy.r * 2)
		draw_rect(Rect2(enemy.p - Vector2(width / 2, enemy.r + 13), Vector2(width, 4)), Color("292c35"))
		draw_rect(Rect2(enemy.p - Vector2(width / 2, enemy.r + 13), Vector2(width * maxf(0, enemy.hp / enemy.max_hp), 4)), enemy.color)

func draw_object(object: Dictionary) -> void:
	var p = object.p
	match object.kind:
		"crate":
			var rect = Rect2(p - Vector2(20, 20), Vector2(40, 40))
			draw_rect(rect, Color("594b3a"))
			draw_rect(rect, Color("9a7c55"), false, 2)
			draw_line(rect.position, rect.end, Color("9a7c55"), 2)
		"barrel":
			draw_circle(p, 24, Color("505762"))
			draw_arc(p, 24, 0, TAU, 24, Color("959ba4"), 3)
			draw_line(p - Vector2(18, 8), p + Vector2(18, -8), Color("d9a35a"), 3)
		"crystal":
			glow(p, 14, Color("48cfea"))
			draw_texture_rect(crystal_texture, Rect2(p - Vector2(28, 36), Vector2(56, 72)), false)
		"monument":
			draw_arc(p, 135, 0, TAU, 60, Color("594c28"), 1.5, true)
			for i in 6:
				var satellite = p + Vector2.from_angle(TAU * i / 6) * 135
				glow(satellite, 16, Color("ffd24a") if object.activated.has(i) else Color("5c5235"))
			draw_colored_polygon(polygon(p, 36, 6, -PI / 2), Color("ffd24a") if object.used else Color("7e6b39"))
		"old":
			var vertices = polygon(p, object.get("radius", MONUMENT_RADIUS), 3, -PI / 2)
			for i in 3:
				var flame = vertices[i].lerp(p, 0.18)
				draw_circle(flame, 20, Color("272f2c"))
				draw_arc(flame, 21, 0, TAU, 30, Color("56675d"), 3, true)
				var amount = clampf((object.charge - i * 0.8) / 0.8, 0.0, 1.0)
				draw_flame(flame, amount, i * 2.1)
			draw_arc(p, object.r, 0, TAU, 64, Color("31483c"), 3, true)
			draw_arc(p, object.r, -PI / 2, -PI / 2 + TAU * maxf(0.001, object.charge / 2.4), 64, Color("70ffa1"), 4, true)
			if not object.used:
				draw_string(ThemeDB.fallback_font, p + Vector2(-62, 5), "AKTIVIEREN", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("95bca0"))
		"switch":
			if object.used:
				draw_circle(p, 15, Color("4dff8a"))

func draw_flame(p: Vector2, amount: float, phase: float) -> void:
	# A small green pilot flame grows into a full, animated tongue of fire.
	var height = lerpf(16, 70, amount)
	var time = game.elapsed * 7 + phase
	var sway = sin(time) * 7
	var outline = PackedVector2Array([p + Vector2(-15, 0), p + Vector2(-18, -height * 0.3), p + Vector2(-9 + sway * 0.4, -height * 0.65), p + Vector2(sway, -height), p + Vector2(10, -height * 0.5), p + Vector2(18, -height * 0.28), p + Vector2(14, 0)])
	draw_circle(p - Vector2(0, height * 0.3), height * 0.7, Color(0.15, 1.0, 0.38, 0.07 + amount * 0.06))
	draw_colored_polygon(outline, Color("22b85e"))
	var inner = PackedVector2Array([p + Vector2(-10, -2), p + Vector2(-8, -height * 0.3), p + Vector2(sway * 0.4, -height * 0.72), p + Vector2(10, -height * 0.25), p + Vector2(9, -2)])
	draw_colored_polygon(inner, Color("77ff9b"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -2), p + Vector2(0, -height * 0.4), p + Vector2(5, -2)]), Color("ceffe0"))

func draw_heart(p: Vector2) -> void:
	var points = PackedVector2Array()
	for i in 48:
		var t = TAU * i / 48
		points.append(p + Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))) * 0.65)
	draw_circle(p, 18, Color(1, 0.15, 0.25, 0.1))
	draw_colored_polygon(points, Color("ff3e5a"))
	points.append(points[0])
	draw_polyline(points, Color("ff9aaa"), 1.5, true)

func barrel_outline(p: Vector2, half_width: float, half_height: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in 25:
		var t = float(i) / 24
		var y = lerpf(-half_height, half_height, t)
		var width = half_width * (0.78 + sin(PI * t) * 0.22)
		points.append(p + Vector2(width, y))
	for i in 25:
		var t = float(i) / 24
		var y = lerpf(half_height, -half_height, t)
		var width = half_width * (0.78 + sin(PI * t) * 0.22)
		points.append(p + Vector2(-width, y))
	return points

func draw_barrel_boss(enemy: Dictionary, color: Color) -> void:
	var p = enemy.p
	var r = enemy.r
	var half_width = r * 0.76
	var half_height = r * 0.91
	var roll = enemy.get("roll", 0.0)
	# A vertical axle rolls horizontally: wood seams and a bung travel over the bulge.
	var silhouette = barrel_outline(p, half_width, half_height)
	draw_colored_polygon(silhouette, color.darkened(0.25))
	for i in 16:
		var a = roll + TAU * i / 16
		if cos(a) <= 0:
			continue
		var seam = PackedVector2Array()
		for j in 19:
			var t = float(j) / 18
			seam.append(p + Vector2(sin(a) * half_width * (0.78 + sin(PI * t) * 0.22), lerpf(-half_height, half_height, t)))
		draw_polyline(seam, Color("e2af69").darkened((1 - cos(a)) * 0.65), 3, true)
	# Thin cross highlights give the wooden body volume without hiding the grain.
	for side in [-1, 1]:
		var band_y = side * half_height * 0.63
		var band_w = half_width * 0.96
		var band = Rect2(p + Vector2(-band_w, band_y - 7), Vector2(band_w * 2, 14))
		draw_rect(band, Color("414b51"))
		draw_line(band.position, band.position + Vector2(band.size.x, 0), Color("b3babc"), 2, true)
		draw_line(band.position + Vector2(0, 13), band.end, Color("20292e"), 2, true)
		for rivet in [-0.65, 0.65]:
			draw_circle(p + Vector2(band_w * rivet, band_y), 3, Color("b5b9b8"))
	# Elliptical end caps, instead of two disconnected circles.
	for side in [-1, 1]:
		var cap = PackedVector2Array()
		for i in 48:
			var a = TAU * i / 48
			cap.append(p + Vector2(cos(a) * half_width * 0.78, side * half_height + sin(a) * 13))
		draw_colored_polygon(cap, Color("73512e") if side == -1 else Color("4e3927"))
		cap.append(cap[0])
		draw_polyline(cap, Color("b5b7ae"), 4, true)
	if cos(roll) > 0:
		var bung = p + Vector2(sin(roll) * half_width, 0)
		draw_circle(bung, 8, Color("3e2c20"))
		draw_arc(bung, 8, 0, TAU, 20, Color("d6b480"), 2, true)
	silhouette.append(silhouette[0])
	draw_polyline(silhouette, Color("d7b483"), 2, true)
