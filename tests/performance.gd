## Optional deterministic CPU benchmark; no object limits or quality settings are reduced.
extends SceneTree
var game: Node
var arena: Node2D
var report: Dictionary = {}
func _initialize(): call_deferred('run')
func sample(label: String, setup: Callable, action: Callable, repetitions: int = 40):
	var times: Array[float] = []
	for i in repetitions + 3:
		setup.call()
		var started = Time.get_ticks_usec()
		action.call()
		var elapsed = (Time.get_ticks_usec() - started) / 1000.0
		if i >= 3: times.append(elapsed)
	times.sort()
	report[label] = {'median_ms': times[times.size()/2], 'p95_ms': times[int(times.size()*0.95)], 'max_ms': times[-1]}
	print(label, ': ', JSON.stringify(report[label]))
func run():
	seed(20261105)
	game = load('res://scenes/main.tscn').instantiate()
	game.test_mode = true
	game.store.path = 'user://profile_test.json'
	DirAccess.remove_absolute(game.store.path)
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	arena = game.arena
	game.invincible = 1e9
	arena.enemies.clear()
	arena.warnings.clear()
	arena.bullets.clear()
	arena.enemy_bullets.clear()
	for i in 160:
		var enemy = arena.spawn_enemy('runner' if i % 4 else 'shooter', arena.random_spawn())
		enemy.hp = 1e9
		enemy.max_hp = 1e9
		enemy.cd = 100
		enemy.nav_cd = 0.05 + float(i % 30) / 60.0
	for i in 400:
		arena.pickups.append({'kind':'heart', 'p':arena.random_open(500), 'value':1})
	for i in 200:
		arena.bullets.append({'p':arena.random_open(500), 'v':Vector2.ZERO, 'life':1000.0, 'r':4.0, 'color':Color.WHITE, 'damage':0.0, 'grenade':false, 'pierce':true, 'bounce':0, 'hit':{}})
		arena.enemy_bullets.append({'p':arena.random_open(500), 'v':Vector2.ZERO, 'life':1000.0, 'r':6.0, 'color':Color.WHITE, 'damage':1})
	var enemies = arena.enemies.duplicate(true)
	var bullets = arena.bullets.duplicate(true)
	var hostile = arena.enemy_bullets.duplicate(true)
	var pickups = arena.pickups.duplicate(true)
	var player = arena.player
	var reset = func():
		arena.enemies.assign(enemies.duplicate(true))
		arena.bullets.assign(bullets.duplicate(true))
		arena.enemy_bullets.assign(hostile.duplicate(true))
		arena.pickups.assign(pickups.duplicate(true))
		arena.player = player
		arena.player_velocity = Vector2.ZERO
		arena.shot_cd = 1e9
		arena.spawn_cd = 1e9
		arena.cluster_clock = 0
		if arena.has_method('begin_spatial_frame'): arena.begin_spatial_frame()
	report['fixture'] = {'enemies':160,'bullets':200,'hostile':200,'pickups':400,'walls':arena.walls.size(),'monument_segments':arena.monument_walls.size()}
	print('FIXTURE: ', JSON.stringify(report.fixture))
	sample('full_simulation', reset, func(): arena.simulate(1.0/60))
	sample('enemy_updates', reset, func():
		for enemy in arena.enemies.duplicate(): arena.update_enemy(enemy, 1.0/60))
	sample('friendly_projectiles', reset, func(): arena.update_projectiles(arena.bullets, 1.0/60, false))
	sample('hostile_projectiles', reset, func(): arena.update_projectiles(arena.enemy_bullets, 1.0/60, true))
	var probes: Array[Vector2] = []
	for i in 160: probes.append(enemies[i].p)
	sample('visibility_160', func():pass, func():
		for p in probes: arena.line_clear(p, player))
	sample('collision_400', func():pass, func():
		for bullet in bullets: arena.blocked(bullet.p, 4)
		for bullet in hostile: arena.blocked(bullet.p, 6))
	sample('map_reveal', func(): arena.last_revealed_rect = Rect2i(), func(): arena.reveal_view())
	sample('hud_update', func():pass, func(): game.ui.update_hud())
	var dense_reset = func():
		reset.call()
		for i in arena.enemies.size():
			arena.enemies[i].p = player + Vector2(200 + (i % 16) * 2, int(i / 16) * 2)
		arena.begin_spatial_frame()
	var dense_slow = func():
		dense_reset.call()
		arena.end_spatial_frame()
	sample('dense_exhaustive', dense_slow, func():
		for enemy in arena.enemies: arena.update_enemy(enemy, 1.0/60), 15)
	sample('dense_indexed', dense_reset, func():
		for enemy in arena.enemies: arena.update_enemy(enemy, 1.0/60), 15)
	game.audio.apply_settings(game.store.data.settings)
	sample('audio_20_events', func():pass, func():
		for i in 20: game.audio.effect('collect'), 10)
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		var file = FileAccess.open(args[0], FileAccess.WRITE)
		file.store_string(JSON.stringify(report,'\t'))
	if arena.has_method('end_spatial_frame'): arena.end_spatial_frame()
	game.audio.music.stop()
	game.audio.music.stream = null
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute('user://profile_test.json')
	quit()
