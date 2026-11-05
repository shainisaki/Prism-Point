extends SceneTree
## Regression checks for monument geometry, exploration, fog and run health.

var game: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func run() -> void:
	seed(20261105)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.store.path = "user://feedback_test.json"
	DirAccess.remove_absolute(game.store.path)
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.start_run()
	var arena = game.arena
	var monument: Dictionary
	for object in arena.objects:
		if object.kind == "old": monument = object
	expect(not monument.is_empty() and monument.radius >= 315, "Triangular monument is at least three times the old radius")
	expect(arena.monument_walls.size() == 6, "Three monument sides contain real wall segments and openings")
	var center = monument.p
	var segment = arena.monument_walls[0]
	var midpoint = (segment.a + segment.b) / 2
	var inward = (center - midpoint).normalized()
	expect(arena.blocked(midpoint, 14), "Monument stone blocks player collision")
	expect(not arena.line_clear(midpoint - inward * 80, midpoint + inward * 80), "Monument stone blocks shooting sightlines")
	var stopped = arena.move_circle(midpoint - inward * 90, inward * 180, 14)
	expect(stopped.distance_to(midpoint + inward * 90) > 50, "Player cannot walk through the stone wall")
	for side in 3:
		var entrance = (arena.monument_walls[side * 2].b + arena.monument_walls[side * 2 + 1].a) / 2
		var normal = (center - entrance).normalized()
		var end = arena.move_circle(entrance - normal * 85, normal * 170, 45)
		expect(end.distance_to(entrance + normal * 85) < 1, "Entrance %d admits even the large Tank" % (side + 1))
	var monument_cell = arena.closest_cell(center)
	expect(arena.grid.get_point_path(arena.closest_cell(arena.player), monument_cell).size() > 0, "Monument center is reachable from the wave spawn")
	arena.player = center + Vector2(250, 0)
	arena.update_objects(1.0)
	expect(monument.charge == 0 and game.state == "playing", "Standing outside activation pad does not trigger monument")
	arena.player = center
	arena.update_objects(2.4)
	expect(game.state == "monument", "Entering monument and standing on pad opens choices")
	game.ui.buttons.choice_0.pressed.emit()
	expect(game.state == "playing", "Monument choice resumes run")

	game.start_run()
	arena.camera.force_update_scroll()
	var view = arena.visible_world_rect()
	var margins = [Vector2(10, 10), Vector2(view.size.x - 10, 10), Vector2(10, view.size.y - 10), view.size - Vector2(10, 10)]
	var correct = true
	for offset in margins:
		correct = correct and arena.is_discovered(view.position + offset)
	expect(correct, "Exploration reveals the actual visible area, including viewport corners")
	var distant = Vector2(100, 100) if view.get_center().distance_to(Vector2(100, 100)) > 1200 else Vector2(4600, 3400)
	expect(not arena.is_discovered(distant), "Unseen map areas remain hidden")
	var remembered = view.get_center()
	arena.player = distant
	arena.camera.position = distant
	arena.camera.force_update_scroll()
	arena.reveal_view()
	expect(arena.is_discovered(remembered) and arena.is_discovered(distant), "Exploration is retained after moving to another part of map")
	arena.reset_discovery()
	expect(not arena.is_discovered(remembered), "New-wave exploration mask resets cleanly")
	arena.reveal_view()

	game.modifier = "fog"
	game.ui.update_hud()
	expect(game.ui.fog.visible and not game.ui.hud_bar.visible and not game.ui.minimap.visible, "Fog hides timer, HP, counters and map")
	expect(game.ui.fog_pause.visible, "Pause remains accessible during fog")
	game.pause_run()
	expect(not game.ui.fog.visible and game.ui.buttons.has("resume"), "Pause menu remains usable in fog")
	var pause_labels = ""
	for label in game.ui.overlay.find_children("*", "Label", true, false):
		pause_labels += label.text + "\n"
	expect("Schussintervall" in pause_labels and "Magnetismus" in pause_labels and "Rüstung" in pause_labels, "Pause displays effective combat values and all upgrade levels")
	game.resume_run()
	expect(game.ui.fog.visible and not game.ui.hud_bar.visible, "Resuming restores fog without leaking HUD information")
	game.modifier = ""
	game.ui.update_hud()
	expect(game.ui.hud_bar.visible and game.ui.minimap.visible and not game.ui.fog.visible, "Normal wave restores HUD and map")
	var hud_labels = ""
	for label in game.ui.hud.find_children("*", "Label", true, false): hud_labels += label.text
	expect(not "COMBO" in hud_labels and not "TEMPO" in hud_labels and not "SCHADEN" in hud_labels, "No fixed combo or passive stat row remains in the gameplay HUD")

	game.start_run()
	arena.objects.clear()
	arena.enemies.clear()
	arena.pickups.clear()
	var death = arena.player + Vector2(80, 0)
	var enemy = arena.spawn_enemy("runner", death)
	arena.damage_enemy(enemy, 100)
	expect(arena.floating_texts.size() == 1 and arena.floating_texts[0].text == "1× COMBO", "Kill creates a numbered combo popup at the enemy")
	expect(arena.floating_texts[0].p.distance_to(death + Vector2(0, -25)) < 1, "Combo popup is anchored to the kill position")
	arena.simulate(0.05)
	expect(arena.floating_texts[0].p.y < death.y - 25 and arena.floating_texts[0].life < 1.15, "Combo popup rises and expires instead of staying in HUD")

	game.hp = 4
	game.open_shop()
	expect(game.hp == 4, "Shop does not heal the player")
	game.next_wave()
	expect(game.hp == 4, "Next wave carries current HP forward")
	game.start_run()
	expect(game.hp == game.max_hp, "Only a new run starts at full health")
	arena.pickups.clear()
	game.hp = 4
	var points_before = game.points
	arena.pickups.append({"p": arena.player, "kind": "heart", "value": 1})
	arena.update_pickups(0.01)
	expect(game.hp == 5 and game.points == points_before, "Red heart heals exactly one HP without awarding points")
	game.hp = game.max_hp - 1
	arena.pickups.append({"p": arena.player, "kind": "heart", "value": 1})
	arena.pickups.append({"p": arena.player, "kind": "heart", "value": 1})
	arena.update_pickups(0.01)
	expect(game.hp == game.max_hp and arena.pickups.size() == 1, "Hearts cannot overheal and are kept on the ground at full HP")
	arena.objects.clear()
	arena.enemies.clear()
	arena.pickups.clear()
	for i in 300:
		var mob = arena.spawn_enemy("runner", arena.player + Vector2(100, 0))
		arena.damage_enemy(mob, 10000)
		arena.enemies.clear()
	var hearts = 0
	for pickup in arena.pickups:
		if pickup.kind == "heart": hearts += 1
	expect(hearts >= 10 and hearts <= 40, "300 kills produce occasional heart drops at the configured 8%% rate (%d hearts)" % hearts)

	game.mode = "bossrush"
	game.start_run()
	arena.enemies.clear()
	arena.monument_walls.clear()
	arena.walls.assign([Rect2(0, 0, 4800, 28), Rect2(0, 3572, 4800, 28), Rect2(0, 0, 28, 3600), Rect2(4772, 0, 28, 3600)])
	arena.spawn_boss("cylinder")
	var barrel = arena.enemies[0]
	barrel.p = Vector2(1000, 1000)
	barrel.velocity = Vector2(300, 0)
	var start_roll = barrel.roll
	arena.update_boss(barrel, 0.1)
	expect(barrel.p.x > 1000 and barrel.roll > start_roll, "Barrel rolls as it travels right")
	barrel.velocity.x = -300
	var right_roll = barrel.roll
	arena.update_boss(barrel, 0.1)
	expect(barrel.roll < right_roll, "Barrel rotation reverses with travel direction")
	arena.enemies.clear()
	arena.spawn_boss("endboss")
	expect(arena.enemies[-1].max_hp == 2000 and arena.enemies[0].max_hp == 240, "Endboss core and all six nodes have 100% more health")

	game.mode = "survival"
	var old_theme = arena.layout_theme
	var old_walls = hash(arena.walls)
	var kinds: Dictionary = {}
	var changing = true
	var all_reachable = true
	for i in 8:
		game.start_run()
		changing = changing and old_theme != arena.layout_theme and old_walls != hash(arena.walls)
		old_theme = arena.layout_theme
		old_walls = hash(arena.walls)
		for kind in arena.structure_kinds: kinds[kind] = true
		for object in arena.objects:
			if object.kind == "old":
				all_reachable = all_reachable and arena.grid.get_point_path(arena.closest_cell(arena.player), arena.closest_cell(object.p)).size() > 0
		expect(arena.route.size() > 1 and not arena.blocked(arena.player, arena.player_radius), "Random layout %d has a valid spawn and shop route" % i)
	expect(changing and kinds.size() >= 7, "Each wave re-rolls arrangement and structure family (%d shapes sampled)" % kinds.size())
	expect(all_reachable, "Monument entrances remain navigable across randomized layouts")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://feedback_test.json")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
