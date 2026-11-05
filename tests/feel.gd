extends SceneTree
## Point conservation, movement response and categorized pause-menu regressions.
const Clusters = preload("res://scripts/point_clusters.gd")

var game: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func point(p: Vector2, value: int = 1) -> Dictionary:
	return {"p": p, "value": value, "kind": "point"}

func run() -> void:
	seed(54321)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.store.path = "user://feel_test.json"
	DirAccess.remove_absolute(game.store.path)
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.start_run()
	var arena = game.arena
	var a = point(Vector2(1000, 1000), 2)
	var b = point(Vector2(1006, 1000), 3)
	Clusters.combine(a, b)
	expect(a.value == 5 and Clusters.reward(a, 0, 1) == 5, "Two point values merge by addition, never multiplication")
	expect(Clusters.reward(a, 1.6, 3) == 21, "Merging preserves resource bonuses and per-drop rounding")
	expect(Clusters.reward(a, -1.75, 1) == 2, "Merged points preserve minimum payouts with negative character bonuses")
	arena.pickups.clear()
	for i in 5000:
		arena.pickups.append(point(Vector2(1200 + i % 3, 1200 + i % 2)))
	arena.pickups.append({"p": Vector2(1200, 1200), "value": 1, "kind": "heart"})
	arena.pickups.append({"p": Vector2(1200, 1200), "value": 0, "kind": "pierce"})
	var started = Time.get_ticks_usec()
	Clusters.step(arena, 0.1)
	print("Cluster stress: 5000 drops in %.2f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
	var total = 0
	var point_count = 0
	for pickup in arena.pickups:
		if pickup.kind == "point":
			total += pickup.value
			point_count += 1
			expect(pickup.parts.size() == 1, "Large point cluster uses a compact value histogram")
	expect(total == 5000 and point_count == 1, "5000 overlapping drops collapse to one value-preserving point")
	expect(arena.pickups.size() == 3, "Hearts and piercing perks never merge into points")
	arena.monument_walls.clear()
	arena.walls.clear()
	arena.objects.clear()
	arena.pickups.assign([point(Vector2(1000, 1000)), point(Vector2(1060, 1000))])
	Clusters.step(arena, 0.1)
	expect(arena.pickups[0].p.x > 1000 and arena.pickups[1].p.x < 1060, "Nearby points visibly attract each other")
	for i in 12: Clusters.step(arena, 0.1)
	expect(arena.pickups.size() == 1 and arena.pickups[0].value == 2, "Attracted points eventually merge with the exact summed value")
	arena.pickups.assign([point(Vector2(1000, 1000)), point(Vector2(1250, 1000))])
	Clusters.step(arena, 0.1)
	expect(arena.pickups.size() == 2 and arena.pickups[1].p.x == 1250, "Distant points are not pulled across the arena")
	arena.walls.append(Rect2(1020, 900, 28, 200))
	arena.pickups.assign([point(Vector2(1000, 1000)), point(Vector2(1060, 1000))])
	for i in 12: Clusters.step(arena, 0.1)
	expect(arena.pickups.size() == 2 and arena.pickups[0].p.x == 1000, "Point attraction cannot pull through solid walls")
	arena.walls.clear()
	game.stats.resource = 3
	game.resource_mult = 3
	game.points = 0
	arena.player = Vector2(1000, 1000)
	arena.pickups.assign([point(arena.player, 2), point(arena.player, 3)])
	arena.cluster_clock = 0
	arena.update_pickups(0.01)
	var separately = game.points
	game.points = 0
	var merged = point(arena.player, 2)
	Clusters.combine(merged, point(arena.player, 3))
	arena.pickups.assign([merged])
	arena.update_pickups(0.01)
	expect(game.points == separately, "Collecting a merged point pays exactly the same as collecting its sources separately")
	game.stats.resource = 0
	game.resource_mult = 1
	arena.player = Vector2(2000, 2000)
	arena.player_velocity = Vector2.ZERO
	arena.step_player(Vector2.RIGHT, 1.0 / 60)
	expect(arena.player_velocity.x > 0 and arena.player_velocity.x < game.player_speed(), "Movement accelerates smoothly instead of jumping to full speed")
	for i in 40: arena.step_player(Vector2.RIGHT, 1.0 / 60)
	expect(arena.player_velocity.x > game.player_speed() * 0.99, "Sustained movement reaches the unchanged character speed")
	expect(arena.trail.size() > 0 and arena.trail.size() <= 16 and arena.visual_stretch > 1, "Movement produces a bounded colored trail and subtle body stretch")
	var speed_before = arena.player_velocity.length()
	arena.step_player(Vector2.ZERO, 0.1)
	expect(arena.player_velocity.length() < speed_before * 0.1, "Releasing input brakes quickly without a long slide")
	for i in 20: arena.step_player(Vector2.ZERO, 0.05)
	expect(arena.trail.is_empty() and absf(arena.visual_stretch - 1) < 0.001, "Standing still fades the trail and restores the player shape")
	var travel: Array[float] = []
	for fps in [30, 60, 120]:
		arena.player = Vector2(2000, 2000)
		arena.player_velocity = Vector2.ZERO
		for i in fps: arena.step_player(Vector2.RIGHT, 1.0 / fps)
		travel.append(arena.player.x)
	expect(absf(travel[0] - travel[2]) < 0.01, "Movement distance is consistent at 30, 60 and 120 updates per second")
	arena.step_player(Vector2.LEFT, 0.1)
	expect(arena.player_velocity.x < 0, "Reversing direction responds promptly")
	game.start_run()
	expect(arena.player_velocity == Vector2.ZERO and arena.trail.is_empty(), "New runs reset momentum and afterimages")
	for corner in 3:
		var incoming = arena.monument_walls[(corner * 2 + 5) % 6].polygon
		var outgoing = arena.monument_walls[corner * 2].polygon
		expect(incoming[1].is_equal_approx(outgoing[0]) and incoming[2].is_equal_approx(outgoing[3]), "Module corner %d joins with identical inner and outer vertices" % (corner + 1))
	game.pause_run()
	expect(game.ui.buttons.has("pause_audio") and game.ui.buttons.has("pause_display") and game.ui.buttons.has("pause_controls") and game.ui.buttons.has("pause_compendium"), "Pause menu exposes themed functional module buttons")
	var timer = game.wave_time
	var health = game.hp
	game.ui.buttons.pause_audio.pressed.emit()
	expect(game.state == "options" and game.ui.options_section == "audio" and not game.ui.buttons.has("bind_move_up"), "Audio module opens only audio settings")
	var music_before = game.store.data.settings.music
	for toggle in game.ui.overlay.find_children("*", "CheckButton", true, false):
		if toggle.text == "Musik": toggle.button_pressed = not toggle.button_pressed
	expect(game.store.data.settings.music != music_before, "Audio module toggles and saves the real music setting")
	game.ui.buttons.back_options.pressed.emit()
	expect(game.state == "paused" and game.wave_time == timer and game.hp == health, "Settings return to the same frozen run")
	game.ui.buttons.pause_display.pressed.emit()
	expect(game.ui.options_section == "display", "Display module has its own page")
	game.ui.return_from_options()
	game.ui.buttons.pause_controls.pressed.emit()
	game.bind_key("move_up", KEY_I)
	game.ui.buttons.reset_binds.pressed.emit()
	expect(game.store.data.settings["keys"].move_up == KEY_W and game.ui.options_section == "controls", "Control module restores bindings without leaving its category")
	game.ui.return_from_options()
	game.ui.buttons.pause_compendium.pressed.emit()
	expect(game.state == "compendium", "Pause compendium opens game information")
	game.ui.buttons.back_compendium.pressed.emit()
	expect(game.state == "paused" and game.wave_time == timer, "Compendium returns to pause instead of ending the run")
	game.ui.buttons.resume.pressed.emit()
	expect(game.state == "playing", "The redesigned resume button continues the run")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://feel_test.json")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
