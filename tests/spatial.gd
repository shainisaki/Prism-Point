extends SceneTree
## Compare the accelerated broad phase with exhaustive game rules.
const SpatialIndex = preload("res://scripts/spatial_index.gd")
var game: Node
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if value: print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func run() -> void:
	seed(93733)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.store.path = "user://spatial_test.json"
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	var arena = game.arena
	var probes: Array[Dictionary] = []
	for i in 1600:
		var p = Vector2(randf_range(-80, arena.SIZE.x + 80), randf_range(-80, arena.SIZE.y + 80))
		var radius = [0.0, 2.0, 14.0, 57.0, 110.0][i % 5]
		probes.append({"p": p, "r": radius, "blocked": arena.blocked(p, radius)})
	for segment in arena.monument_walls:
		for point in segment.polygon:
			for offset in [Vector2.ZERO, Vector2.ONE, -Vector2.ONE]:
				var p = point + offset
				probes.append({"p": p, "r": 14.0, "blocked": arena.blocked(p, 14)})
	var rays: Array[Dictionary] = []
	for i in 1000:
		var a = Vector2(randf_range(0, arena.SIZE.x), randf_range(0, arena.SIZE.y))
		var b = a + Vector2.from_angle(randf() * TAU) * randf_range(0, 700)
		if i % 5 == 0: b = Vector2(randf_range(0, arena.SIZE.x), randf_range(0, arena.SIZE.y))
		if i % 7 == 0: b.x = a.x
		if i % 11 == 0: b.y = a.y
		rays.append({"a": a, "b": b, "clear": arena.line_clear(a, b)})
	arena.begin_spatial_frame()
	var collisions_match = true
	for probe in probes:
		if arena.blocked(probe.p, probe.r) != probe.blocked: collisions_match = false
	expect(collisions_match, "Indexed collisions match exhaustive checks for 1600 probes, five radii and monument corners")
	var rays_match = true
	for ray in rays:
		if arena.line_clear(ray.a, ray.b) != ray.clear: rays_match = false
	expect(rays_match, "Indexed visibility matches 1000 short, long, horizontal and vertical exhaustive rays")
	arena.end_spatial_frame()
	var original_wall = arena.walls[4]
	arena.walls[4] = Rect2(Vector2(1700, 1700), Vector2(200, 40))
	arena.begin_spatial_frame()
	expect(arena.blocked(Vector2(1800, 1710), 4), "Replacing geometry with an unchanged wall count rebuilds the index")
	arena.end_spatial_frame()
	arena.walls[4] = original_wall
	var index = SpatialIndex.new()
	index.add(Rect2(-130, -130, 260, 260))
	index.add(Rect2(127, 127, 2, 2))
	expect(index.query(Rect2(-1, -1, 130, 130)) == [0, 1], "Spatial queries deduplicate multi-cell entries and preserve insertion order")
	index.update(0, Rect2(500, 500, 20, 20))
	expect(index.query(Rect2(-1, -1, 130, 130)) == [1] and index.query(Rect2(490, 490, 40, 40)) == [0], "Moving across cell boundaries removes stale memberships")
	expect(index.query(Rect2(-10000, -10000, 20000, 20000)) == [0, 1], "Very large queries use a bounded exhaustive fallback without dropping objects")
	arena.enemies.clear()
	for i in 80:
		var enemy = arena.spawn_enemy("runner" if i % 3 else "tank", arena.player + Vector2((i % 10) * 23 - 100, int(i / 10) * 19 - 80))
		enemy.cd = 10
		enemy.nav_cd = 100
		enemy.hp = 1000
	var initial = arena.enemies.duplicate(true)
	for i in 8:
		for enemy in arena.enemies: arena.update_enemy(enemy, 1.0 / 60)
	var exhaustive = arena.enemies.duplicate(true)
	arena.enemies.assign(initial.duplicate(true))
	for i in 8:
		arena.begin_spatial_frame()
		for enemy in arena.enemies: arena.update_enemy(enemy, 1.0 / 60)
		arena.end_spatial_frame()
	var movement_matches = true
	for i in exhaustive.size():
		if arena.enemies[i].p.distance_to(exhaustive[i].p) > 0.001: movement_matches = false
	expect(movement_matches and arena.enemies.size() == 80, "Eighty overlapping enemies move and separate identically over eight steps without removing actors")
	var neighbors = arena.enemies.duplicate(true)
	var center = arena.player + Vector2(300, 0)
	arena.enemies.clear()
	for i in 6:
		var enemy = arena.spawn_enemy("tank", center + Vector2(i * 13, 0))
		enemy.hp = 1000
		enemy.max_hp = 1000
	var targets = arena.enemies.duplicate(true)
	var bullets: Array[Dictionary] = []
	for i in 20:
		bullets.append({"p": center + Vector2(-30, 0), "v": Vector2(2000, 0), "life": 5.0, "r": 4.0, "color": Color.WHITE, "damage": 1.0, "grenade": false, "pierce": i % 2 == 0, "bounce": 0, "hit": {}})
	arena.bullets.assign(bullets.duplicate(true))
	arena.update_projectiles(arena.bullets, 0.05, false)
	var hits = arena.enemies.duplicate(true)
	var survivors = arena.bullets.duplicate(true)
	arena.enemies.assign(targets.duplicate(true))
	arena.bullets.assign(bullets.duplicate(true))
	arena.begin_spatial_frame()
	arena.update_projectiles(arena.bullets, 0.05, false)
	arena.end_spatial_frame()
	var hits_match = arena.bullets == survivors
	for i in targets.size():
		if arena.enemies[i].hp != hits[i].hp: hits_match = false
	expect(hits_match, "Indexed bullets preserve exact hit order, piercing damage and surviving projectiles")
	var saved_objects = arena.objects.duplicate(true)
	var crate_p = arena.random_open(200)
	arena.objects.assign([{"kind": "crate", "p": crate_p, "r": 22.0, "hp": 20.0}])
	var crate_bullet = bullets[1].duplicate(true)
	crate_bullet.p = crate_p - Vector2(30, 0)
	arena.bullets.assign([crate_bullet.duplicate(true)])
	arena.update_projectiles(arena.bullets, 0.05, false)
	var crate_hp = arena.objects[0].hp
	var crate_survivors = arena.bullets.size()
	arena.objects[0].hp = 20.0
	arena.bullets.assign([crate_bullet.duplicate(true)])
	arena.begin_spatial_frame()
	arena.update_projectiles(arena.bullets, 0.05, false)
	arena.end_spatial_frame()
	expect(arena.objects[0].hp == crate_hp and arena.bullets.size() == crate_survivors and crate_hp < 20, "Indexed destructible objects preserve projectile damage and removal")
	arena.objects.assign(saved_objects)
	var blocked_point = arena.grid.get_point_position(Vector2i.ZERO)
	var nearest = arena.closest_cell(blocked_point)
	arena.begin_spatial_frame()
	var cached = arena.closest_cell(blocked_point)
	expect(cached == nearest and arena.cell_cache.has(blocked_point) and arena.closest_cell(blocked_point) == cached, "Blocked destination lookup is shared without changing the nearest navigable cell")
	var walker = {"p": arena.grid.get_point_position(arena.reachable[-1]), "nav_cd": 0.0, "path": PackedVector2Array()}
	arena.navigate(walker, 0.01)
	var stored_path = arena.path_cache.values()[0]
	var stored_count = stored_path.size()
	walker.path.clear()
	expect(stored_count > 1 and arena.path_cache.values()[0].size() == stored_count, "Consuming an enemy path cannot mutate a shared cached route")
	arena.end_spatial_frame()
	arena.enemies.assign(neighbors)
	arena.begin_spatial_frame()
	var child = arena.spawn_enemy("runner", center)
	expect(arena.enemy_candidates(center, center, 2).has(child), "Enemies spawned during a step immediately participate in indexed collisions")
	arena.end_spatial_frame()
	game.audio.apply_settings(game.store.data.settings)
	var stream = game.audio.effect_streams.collect
	game.audio.effect("collect")
	game.audio.effect("collect")
	expect(is_same(game.audio.sounds[0].stream, stream) and is_same(game.audio.sounds[1].stream, stream), "Concurrent sound voices reuse the same precomputed waveform")
	expect(game.audio.effect_streams.size() == 7 and game.audio.sounds.size() == 8, "Audio caching preserves all seven sound types and all eight voices")
	game.goal_unlocked = true
	var speed = child.speed
	var count = arena.spawn_count(4)
	var interval = arena.spawn_interval()
	game.advance_overtime(0)
	expect(is_equal_approx(child.speed, speed * 1.03), "Shop activation adds only three percent enemy speed")
	game.advance_overtime(7.5)
	expect(is_equal_approx(child.speed, speed * 1.06), "Enemy speed increases linearly instead of exponentially")
	expect(arena.spawn_count(4) == count and is_equal_approx(arena.spawn_interval(), interval), "HP and speed escalation preserves configured spawn amounts and intervals")
	var new_enemy = arena.spawn_enemy("runner", center)
	expect(is_equal_approx(new_enemy.speed, speed * 1.06), "Newly spawned enemies inherit the same gradual speed increase")
	game.advance_overtime(1000)
	expect(is_equal_approx(game.overtime_speed_factor(), 1.6), "Gradual enemy speed has a predictable upper bound")
	game.next_wave()
	expect(game.overtime_speed_factor() == 1, "The next wave resets the overtime speed increase")
	game.audio.music.stop()
	game.audio.music.stream = null
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://spatial_test.json")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
