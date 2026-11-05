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
			object.pressed = true
			game.arena.player = object.p
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
	game.wave = 6
	game.wave_time = 28
	game.hp = 9
	game.points = 142
	game.store.data.gold = 8
	game.ui.update_hud()
	game.ui.toast_label.hide()
	await capture("combined-ui")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(800, 600)
	await capture("combined-ui-compact")
	root.size = Vector2i(1280, 800)
	game.start_run()
	game.arena.objects.clear()
	game.arena.enemies.clear()
	game.arena.pickups.clear()
	game.arena.monument_walls.clear()
	game.arena.walls.assign([Rect2(0, 0, game.arena.SIZE.x, 28)])
	var center = game.arena.SIZE / 2
	game.arena.player = center + Vector2(-200, 60)
	game.arena.camera.position = center
	var chip = {"kind": "monument", "p": center, "r": 45.0, "activated": [], "used": false}
	game.arena.objects.append(chip)
	game.arena.objects.append({"kind": "crystal", "p": center + Vector2(250, 50), "r": 20.0, "hp": 20.0})
	game.arena.reset_discovery()
	game.arena.camera.force_update_scroll()
	game.arena.reveal_view()
	game.ui.toast_label.hide()
	game.elapsed = 1.4
	for i in 5:
		game.arena.player = game.arena.data_field_position(chip, i)
		game.arena.update_objects(0.01)
		for frame in 3: game.arena.update_objects(0.1)
	await capture("rune-monument-crystal")
	game.arena.player = game.arena.data_field_position(chip, 5)
	game.arena.update_objects(0.01)
	game.arena.update_objects(0.55)
	await capture("data-transfer")
	game.arena.update_objects(0.7)
	await capture("data-decoded")
	game.arena.objects.clear()
	game.arena.pickups.clear()
	game.arena.enemies.clear()
	game.arena.monument_walls.clear()
	game.arena.player = center
	game.arena.player_velocity = Vector2.ZERO
	for i in 24: game.arena.step_player(Vector2.RIGHT, 1.0 / 60)
	game.arena.camera.position = game.arena.player
	game.arena.camera.force_update_scroll()
	for i in 60:
		game.arena.pickups.append({"kind": "point", "p": game.arena.player + Vector2(150 + i % 4, -60 + i % 3), "value": 1})
	game.arena.PointClusters.step(game.arena, 0.1)
	for offset in [Vector2(220, 70), Vector2(270, -110), Vector2(90, 130)]:
		game.arena.pickups.append({"kind": "point", "p": game.arena.player + offset, "value": 1})
	game.ui.toast_label.hide()
	await capture("point-clusters-motion")
	game.pause_run()
	await capture("pause-console")
	game.ui.buttons.pause_audio.pressed.emit()
	await capture("pause-audio")
	game.ui.return_from_options()
	game.ui.buttons.pause_controls.pressed.emit()
	await capture("pause-controls")
	for section in ["all", "audio", "display", "difficulty", "controls", "hud", "accessibility", "gameplay"]:
		game.ui.open_options("paused", section)
		await capture("settings-" + section)
	game.ui.open_options("paused", "difficulty")
	game.ui.options_editor.fields.enemy_health.value = 1.7
	await capture("settings-draft")
	game.ui.return_from_options()
	await capture("settings-unsaved")
	game.ui.buttons.discard_and_back.pressed.emit()
	game.resume_run()
	game.wave_time = 0
	game.goal_unlocked = true
	game.advance_overtime(15)
	for i in 12:
		game.arena.spawn_enemy(["runner", "tank", "shooter"][i % 3], game.arena.player + Vector2.from_angle(TAU * i / 12.0) * (170 + i * 8))
	game.ui.update_hud()
	game.ui.toast_label.hide()
	await capture("overtime")
	game.pause_run()
	game.ui.open_options("paused", "accessibility")
	game.ui.options_editor.fields.text_scale.value = 1.4
	game.ui.options_editor.fields.high_contrast.button_pressed = true
	game.ui.apply_options()
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(800, 600)
	game.ui.open_options("paused", "accessibility")
	await capture("settings-accessible-compact")
	# Scroll to check the last settings and the persistent action bar too.
	for scroll in game.ui.overlay.find_children("*", "ScrollContainer", true, false):
		scroll.scroll_vertical = 10000
	await capture("settings-accessible-bottom")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://render_test.json")
	quit()
