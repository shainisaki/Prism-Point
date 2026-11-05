extends SceneTree
## Optional rendering check; requires an X11/Wayland display (not --headless).

var game: Node

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	image.save_png("/tmp/prism-" + name + ".png")
	print("Rendered: " + name + " " + str(image.get_size()))

func run() -> void:
	seed(34567)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.store.path = "user://render_test.json"
	root.add_child(game)
	game.set_physics_process(false)
	await capture("title")
	game.show_hub()
	await capture("hub")
	game.start_run()
	game.arena.objects.clear()
	for i in 5:
		game.arena.spawn_enemy(["runner", "tank", "shooter", "hunter", "splitter"][i], game.arena.player + Vector2(100 + i * 50, i * 40 - 100))
	for i in 120:
		game._physics_process(1.0 / 60)
	await capture("arena")
	game.open_shop()
	game.points = 40
	game.ui.shop_screen()
	await capture("shop")
	game.ui.open_options("hub")
	await capture("options")
	game.start_run()
	for object in game.arena.objects:
		if object.kind == "old":
			object.charge = 1.6
			game.arena.player = object.p + Vector2(0, 120)
			game.arena.camera.position = object.p + Vector2(0, -60)
	game.elapsed = 2.3
	game.arena.camera.force_update_scroll()
	game.arena.reveal_view()
	await capture("monument")
	game.arena.enemies.clear()
	game.arena.spawn_boss("cylinder")
	var barrel = game.arena.enemies[0]
	barrel.p = game.arena.player + Vector2(180, 0)
	barrel.roll = 0.0
	game.arena.enemies.assign([barrel])
	await capture("barrel-0")
	barrel.roll = 1.4
	await capture("barrel-1")
	game.modifier = "fog"
	game.ui.update_hud()
	game.elapsed = 18.0
	await capture("fog")
	game.pause_run()
	await capture("pause-stats")
	game.modifier = ""
	game.start_run()
	game.arena.objects.clear()
	game.arena.enemies.clear()
	game.arena.pickups.clear()
	for i in 3:
		var enemy = game.arena.spawn_enemy("runner", game.arena.player + Vector2(80 + i * 100, i * 55 - 50))
		game.arena.damage_enemy(enemy, 100)
	game.arena.pickups.append({"kind": "heart", "p": game.arena.player + Vector2(-100, 70), "value": 1})
	await capture("combo-hearts")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://render_test.json")
	quit()
