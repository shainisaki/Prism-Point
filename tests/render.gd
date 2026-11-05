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
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://render_test.json")
	quit()
