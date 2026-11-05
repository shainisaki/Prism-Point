extends SceneTree
## Run: godot --headless --path . --script tests/smoke.gd

var checks := 0
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func run() -> void:
	seed(12345)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.store.path = "user://smoke_progress.json"
	DirAccess.remove_absolute(game.store.path)
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	expect(game.state == "title" and game.ui.buttons.has("title_play"), "Native title scene loads")
	game.ui.buttons.title_play.pressed.emit()
	expect(game.state == "hub" and game.ui.buttons.has("start_run"), "Title button opens lobby")
	game.ui.buttons.mode_endless.pressed.emit()
	expect(game.mode == "endless", "Native mode button selects Endless")
	game.ui.buttons.mode_survival.pressed.emit()
	game.ui.buttons.start_run.pressed.emit()
	expect(game.state == "playing" and game.hp == 10 and game.wave == 1, "Run starts with base stats")
	expect(game.arena.route.size() > 1 and game.arena.reachable.size() > 500, "Map contains a reachable shop and connected corridors")
	expect(not game.arena.blocked(game.arena.player, game.arena.player_radius), "Player starts outside walls")
	var before = game.arena.player
	Input.action_press("move_right")
	for i in 10: game._physics_process(1.0 / 60)
	Input.action_release("move_right")
	expect(game.arena.player.x > before.x, "Input moves player in native simulation")
	var border = game.arena.move_circle(Vector2(80, 80), Vector2(-400, -400), 14)
	expect(border.x >= 42 and border.y >= 42 and not game.arena.blocked(border, 14), "Collision prevents tunneling through map boundary")
	game.arena.objects.clear()
	game.arena.enemies.clear()
	game.arena.player = game.arena.grid.get_point_position(game.arena.reachable[100])
	var enemy = game.arena.spawn_enemy("runner", game.arena.player + Vector2(60, 0))
	expect(game.arena.shoot(), "Auto aim creates a native projectile")
	for i in 20: game.arena.update_projectiles(game.arena.bullets, 1.0 / 60, false)
	expect(enemy.hp <= 0 and game.combo == 1, "Projectile kills and increments combo")
	game.arena.update_pickups(1.0)
	expect(game.points >= 1, "Magnet collects dropped points")
	game.ui.buttons.clear()
	game.pause_run()
	var time = game.wave_time
	var position_before_pause = game.arena.player
	for i in 30: game._physics_process(1.0 / 60)
	expect(game.wave_time == time and game.arena.player == position_before_pause, "Pause freezes timer and simulation")
	game.ui.buttons.resume.pressed.emit()
	game.wave_time = 0.01
	game._physics_process(1.0 / 60)
	expect(game.goal_unlocked, "Timer unlocks shop")
	game.arena.enemies.clear()
	game.arena.enemy_bullets.clear()
	game.arena.player = game.arena.goal
	game._physics_process(1.0 / 60)
	expect(game.state == "shop" and game.waves_cleared == 1, "Reaching shop transitions into upgrade menu")
	game.points = 100
	var cost = game.price("damage")
	game.ui.shop_screen()
	game.ui.buttons.buy_damage.pressed.emit()
	expect(game.stats.damage == 1 and game.points == 100 - cost and game.focus == "offense", "Shop deducts exact cost, applies upgrade and build")
	expect(not game.buy_upgrade("invalid"), "Invalid shop item is rejected")
	game.points = 0
	expect(not game.buy_upgrade("armor"), "Insufficient funds cannot purchase")
	game.ui.buttons.next_wave.pressed.emit()
	expect(game.wave == 2 and game.state == "playing" and game.stats.damage == 1, "Next wave retains upgrades")
	game.invincible = 0
	game.hurt(1)
	var health = game.hp
	game.hurt(1)
	expect(game.hp == health and health < game.max_hp, "Damage grants temporary invulnerability")
	game.mode = "hardcore"
	game.start_run()
	expect(game.hp == 1 and game.max_hp == 1, "Hardcore starts with exactly one life")
	game.open_shop()
	game.points = 100
	expect(not game.buy_upgrade("vitality"), "Hardcore blocks vitality purchases")
	game.mode = "bossrush"
	game.start_run()
	expect(game.boss_wave and game.arena.enemies.size() > 0 and game.attack_range() > 90000, "Boss Rush starts with a boss and unlimited range")
	for kind in ["hexagon", "triangle", "square", "cylinder", "endboss"]:
		game.state = "playing"
		game.arena.enemies.clear()
		game.arena.enemy_bullets.clear()
		game.arena.spawn_boss(kind)
		for boss in game.arena.enemies.duplicate():
			game.arena.update_boss(boss, 2.0)
		expect(game.arena.enemies.size() > 0, "Boss AI executes: " + kind)
	game.state = "playing"
	game.arena.enemies.clear()
	game.arena.spawn_boss("square")
	var gold_before = game.store.data.gold
	game.arena.damage_enemy(game.arena.enemies[0], 1000000)
	expect(game.state == "shop" and game.store.data.gold > gold_before, "Boss death awards persistent gold and opens shop")
	game.show_hub()
	game.store.data.gold = 50
	expect(game.choose_character("runner") and game.store.data.gold == 35, "Gold unlocks Runner once")
	expect(game.choose_character("runner") and game.store.data.gold == 35, "Unlocked character never charges twice")
	game.store.save_progress()
	var saved = load("res://scripts/save_store.gd").new()
	saved.path = game.store.path
	saved.load_progress()
	expect(saved.data.gold == 35 and saved.data.characters.runner, "Atomic save reloads progress and unlocks")
	game.mode = "timeattack"
	game.start_run()
	game.run_time = 0.01
	game._physics_process(1.0 / 60)
	expect(game.state == "gameover", "Time Attack finishes at ten-minute limit")
	game.show_hub()
	game.ui.open_options("hub")
	game.ui.return_from_options()
	expect(game.state == "hub", "Options return to lobby")
	game.ui.compendium_screen()
	expect(game.state == "compendium", "Compendium renders native entries")
	game.ui.open_options("hub")
	game.ui.buttons.bind_move_up.pressed.emit()
	var key_event = InputEventKey.new()
	key_event.physical_keycode = KEY_I
	key_event.keycode = KEY_I
	key_event.pressed = true
	game._unhandled_input(key_event)
	var new_key_bound = false
	var old_key_bound = false
	for event in InputMap.action_get_events("move_up"):
		if event is InputEventKey:
			new_key_bound = new_key_bound or event.physical_keycode == KEY_I
			old_key_bound = old_key_bound or event.physical_keycode == KEY_W
	expect(new_key_bound and not old_key_bound and game.store.data.settings["keys"].move_up == KEY_I, "Native remapping replaces primary key and saves it")
	game.bind_key("move_up", KEY_W)
	game.ui.return_from_options()
	game.mode = "survival"
	game.choose_character("unknown")
	game.start_run()
	game.arena.objects.clear()
	game.arena.enemies.clear()
	game.arena.pickups.clear()
	game.arena.bullets.clear()
	var target = game.arena.spawn_enemy("tank", game.arena.player + Vector2(80, 0))
	target.hp = 10.0
	target.max_hp = 10.0
	var crystal = {"kind": "crystal", "p": game.arena.player + Vector2(90, 0), "r": 20.0, "hp": 20.0}
	game.arena.damage_object(crystal, 20)
	expect(game.resource_mult == 3 and game.points == 150, "Crystal grants points and wave resource multiplier")
	game.arena.explode(target.p, 85, 12, false)
	expect(target.hp <= 0, "Grenade explosion deals area damage")
	game.combo = 99
	game.register_kill(game.arena.player)
	game.arena.update_pickups(0.01)
	expect(game.pierce, "Combo 100 drops and collects piercing perk")
	game.store.data.max_combo = 999
	game.combo = 999
	game.register_kill(game.arena.player)
	expect(game.is_unlocked("sniper"), "Combo 1000 unlocks Sniper")
	game.stats.speed = 10
	Input.action_press("dash")
	game.arena.simulate(1.0 / 60)
	Input.action_release("dash")
	expect(game.arena.dash_cd > 0 and game.arena.dash_left > 0, "Tempo level 10 enables dash and cooldown")
	game.state = "playing"
	game.arena.enemies.clear()
	game.arena.spawn_boss("hexagon")
	var hexagon = game.arena.enemies[0]
	game.arena.damage_enemy(hexagon, hexagon.max_hp * 0.75)
	game.arena.update_boss(hexagon, 0.01)
	expect(game.arena.enemies.size() == 3 and game.arena.enemies[1].has("shared"), "Hexagon phase three creates shared-health duplicates")
	var shared_health = hexagon.hp
	game.arena.damage_enemy(game.arena.enemies[1], 1)
	expect(hexagon.hp == shared_health - 1 and game.arena.enemies[2].hp == hexagon.hp, "Hexagon damage synchronizes across duplicates")
	game.arena.enemies.clear()
	game.arena.spawn_boss("endboss")
	var core = game.arena.enemies[-1]
	game.arena.damage_enemy(core, 100)
	expect(core.hp == 1000, "Endboss nodes shield the core")
	for node in game.arena.enemies.duplicate():
		if node.kind == "endboss_node": game.arena.damage_enemy(node, 1000)
	game.arena.damage_enemy(core, 100)
	expect(core.hp == 900, "Destroying endboss nodes exposes core")
	game.arena.objects.clear()
	game.arena.enemies.clear()
	game.arena.enemy_bullets.clear()
	game.arena.objects.append({"kind": "old", "p": game.arena.player, "r": 60.0, "charge": 2.39, "used": false})
	game.arena.update_objects(0.02)
	expect(game.state == "monument" and game.ui.buttons.has("choice_0"), "Old Monument pauses run and offers three choices")
	game.ui.buttons.choice_0.pressed.emit()
	expect(game.state == "playing", "Monument choice applies and resumes play")
	game.arena.objects.clear()
	game.arena.lasers.clear()
	game.modifier = "laser"
	game.arena.laser_event_cd = 0
	game.arena.simulate(0.01)
	expect(game.arena.lasers.size() > 0, "Laser modifier creates telegraphed beams")
	game.audio.apply_settings(game.store.data.settings)
	game.audio.effect("shot")
	expect(game.audio.music.stream != null and game.audio.music.playing, "Original MP3 loads and synthesized effects execute")
	# Let AudioStreamPlayer initialize its playback before testing scene shutdown.
	await create_timer(0.25).timeout
	game.show_hub()
	game.mode = "survival"
	game.start_run()
	for wave in [6, 10, 20, 25]:
		game.wave = wave
		game.prepare_wave()
		for i in 120: game._physics_process(1.0 / 60)
		expect(game.arena.enemies.size() > 0 or game.arena.warnings.size() > 0, "Simulation executes wave %d" % wave)
	game.audio.music.stop()
	game.audio.music.stream = null
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	# AudioServer releases stopped decoder playbacks on its next mixing cycle.
	await create_timer(0.15).timeout
	DirAccess.remove_absolute("user://smoke_progress.json")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
