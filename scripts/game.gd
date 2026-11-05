extends Node
## Run state and economy. Simulation stays in Arena; menus use native Controls.

const SaveStore = preload("res://scripts/save_store.gd")
const Arena = preload("res://scripts/arena.gd")
const GameUI = preload("res://scripts/game_ui.gd")
const GameAudio = preload("res://scripts/game_audio.gd")
const Preferences = preload("res://scripts/preferences.gd")
const BUILD_MAP = {"attack": "offense", "damage": "offense", "range": "offense", "speed": "mobility", "magnet": "mobility", "vitality": "defense", "armor": "defense", "resource": "economy"}
const BUILD_NAMES = {"offense": "OFFENSIV", "mobility": "MOBIL", "defense": "TANK", "economy": "ECONOMY"}
const DEFAULT_KEYS = Preferences.DEFAULT_KEYS

var catalog: Dictionary
var store = SaveStore.new()
var arena: Node2D
var ui: CanvasLayer
var audio: Node
var state := "title"
var selected_character := "unknown"
var mode := "survival"
var stats: Dictionary = {}
var wave := 1
var hp := 10
var max_hp := 10
var points := 0
var combo := 0
var combo_time := 0.0
var wave_time := 20.0
var run_time := 600.0
var elapsed := 0.0
var invincible := 0.0
var focus := ""
var pierce := false
var modifier := ""
var goal_unlocked := false
var boss_wave := false
var waves_cleared := 0
var resource_mult := 1
var enemy_speed_mult := 1.0
var enemy_hp_mult := 1.0
var enemy_damage_mult := 1.0
var test_mode := false
var run_preferences: Dictionary = Preferences.defaults()
var overtime_time := 0.0
var overtime_level := 0
var focused := true
var preference_defaults: Dictionary = Preferences.defaults()

func _ready() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/game_data.json"))
	store.load_progress()
	selected_character = str(store.data.character)
	if not catalog.characters.has(selected_character) or not is_unlocked(selected_character):
		selected_character = "unknown"
	mode = str(store.data.mode)
	if not catalog.modes.has(mode):
		mode = "survival"
	audio = GameAudio.new()
	add_child(audio)
	arena = Arena.new()
	arena.game = self
	add_child(arena)
	ui = GameUI.new()
	ui.game = self
	add_child(ui)
	apply_preferences()
	ui.title_screen()

func _setup_input() -> void:
	var bindings = {"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "pause_run": [KEY_P, KEY_ESCAPE], "dash": [KEY_SHIFT]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key in bindings[action]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for entry in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0], ["move_up", JOY_AXIS_LEFT_Y, -1.0], ["move_down", JOY_AXIS_LEFT_Y, 1.0]]:
		var motion = InputEventJoypadMotion.new()
		motion.axis = entry[1]
		motion.axis_value = entry[2]
		InputMap.action_add_event(entry[0], motion)
	for entry in [["pause_run", JOY_BUTTON_START], ["dash", JOY_BUTTON_X]]:
		var button = InputEventJoypadButton.new()
		button.button_index = entry[1]
		InputMap.action_add_event(entry[0], button)
	for entry in [["move_up", JOY_BUTTON_DPAD_UP], ["move_down", JOY_BUTTON_DPAD_DOWN], ["move_left", JOY_BUTTON_DPAD_LEFT], ["move_right", JOY_BUTTON_DPAD_RIGHT]]:
		var button = InputEventJoypadButton.new()
		button.button_index = entry[1]
		InputMap.action_add_event(entry[0], button)
	for action in store.data.settings.get("keys", {}):
		if DEFAULT_KEYS.has(action):
			bind_key(action, int(store.data.settings["keys"][action]), false)
	for action in ["move_up", "move_down", "move_left", "move_right"]:
		InputMap.action_set_deadzone(action, float(pref("stick_deadzone")))

func bind_key(action: String, key: int, persist: bool = true) -> void:
	if not DEFAULT_KEYS.has(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode not in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ESCAPE]:
			InputMap.action_erase_event(action, event)
	var event = InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)
	if not store.data.settings.has("keys"):
		store.data.settings["keys"] = {}
	store.data.settings["keys"][action] = key
	if persist:
		store.save_progress()

func _unhandled_input(event: InputEvent) -> void:
	if ui != null and ui.rebind_action != "" and event is InputEventKey and event.pressed and not event.echo:
		var message = ""
		if event.keycode != KEY_ESCAPE:
			message = ui.stage_key(ui.rebind_action, event.physical_keycode)
		ui.rebind_action = ""
		ui.open_options(ui.options_origin, ui.options_section)
		if message != "": ui.toast(message, true)
		get_viewport().set_input_as_handled()
		return
	if state == "title" and ((event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE]) or (event is InputEventJoypadButton and event.pressed)):
		show_hub()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause_run"):
		if state == "playing":
			pause_run()
		elif state == "paused":
			resume_run()
		elif state == "options":
			ui.return_from_options()
		elif state == "compendium":
			ui.return_from_compendium()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		if state == "options":
			ui.options_draft.window_mode = "fullscreen" if ui.options_draft.window_mode == "windowed" else "windowed"
			ui.open_options(ui.options_origin, ui.options_section)
		else:
			store.data.settings.window_mode = "fullscreen" if store.data.settings.window_mode == "windowed" else "windowed"
			apply_preferences()
			store.save_progress()

func pref(key: String) -> Variant:
	return store.data.settings.get(key, preference_defaults.get(key))

func run_pref(key: String) -> Variant:
	return run_preferences[key]

func apply_preferences() -> void:
	_setup_input()
	Engine.max_fps = int(pref("fps_limit"))
	if not test_mode:
		audio.apply_settings(store.data.settings)
	if DisplayServer.get_name() != "headless":
		var window_mode = str(pref("window_mode"))
		var mode_value = DisplayServer.WINDOW_MODE_WINDOWED
		if window_mode == "borderless": mode_value = DisplayServer.WINDOW_MODE_FULLSCREEN
		elif window_mode == "fullscreen": mode_value = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		DisplayServer.window_set_mode(mode_value)
		if window_mode == "windowed":
			var dimensions = str(pref("resolution")).split("x")
			var target = Vector2i(int(dimensions[0]), int(dimensions[1]))
			var available = DisplayServer.screen_get_usable_rect().size
			DisplayServer.window_set_size(Vector2i(mini(target.x, available.x), mini(target.y, available.y)))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if pref("vsync") else DisplayServer.VSYNC_DISABLED)
	if is_instance_valid(arena):
		arena.release_pointer()
		arena.floor_surface.material.set_shader_parameter("detail", float(pref("floor_detail")))
		if not pref("player_trail") or pref("reduce_motion"): arena.trail.clear()
	if is_instance_valid(ui): ui.apply_preferences()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = what == NOTIFICATION_APPLICATION_FOCUS_IN
		if is_instance_valid(audio): audio.set_focus(focused)

func _physics_process(delta: float) -> void:
	if state != "playing":
		return
	delta = minf(delta, 0.05)
	elapsed += delta
	invincible = maxf(0.0, invincible - delta)
	combo_time -= delta
	if combo_time <= 0.0:
		combo = 0
	if mode == "timeattack":
		run_time = maxf(0.0, run_time - delta)
		if run_time <= 0.0:
			finish_run("TIME ATTACK – %d Wellen geschafft!" % waves_cleared)
			return
	if not boss_wave:
		var before = wave_time
		wave_time = maxf(0.0, wave_time - delta)
		if wave_time <= 0.0 and not goal_unlocked:
			goal_unlocked = true
			ui.toast("Shop aktiv · Finde ihn! Der Gegnerdruck steigt alle %.1f Sekunden." % run_pref("overtime_period"))
		if goal_unlocked: advance_overtime(maxf(0, delta - before) if before > 0 else delta)
	arena.simulate(delta)
	ui.update_hud()

func character() -> Dictionary:
	return catalog.characters[selected_character]

func is_unlocked(id: String) -> bool:
	return bool(store.data.characters.get(id, false)) or (id == "sniper" and int(store.data.max_combo) >= 1000)

func choose_character(id: String) -> bool:
	if not catalog.characters.has(id):
		return false
	if not is_unlocked(id):
		var cost = int(catalog.characters[id].cost)
		if id == "sniper" or store.data.gold < cost:
			return false
		store.data.gold -= cost
		store.data.characters[id] = true
	selected_character = id
	store.data.character = id
	store.save_progress()
	return true

func show_hub() -> void:
	state = "hub"
	ui.hub_screen()

func start_run() -> void:
	run_preferences = store.data.settings.duplicate(true)
	stats = {"vitality": 0.0, "speed": 0.0, "magnet": 0.0, "armor": 0.0, "resource": 0.0, "damage": 0.0, "range": 0.0, "attack": 0.0}
	var c = character()
	for key in stats:
		if key != "vitality":
			stats[key] = maxf(0.0, float(c.get(key, 0.0)))
	wave = 1
	points = 0
	combo = 0
	combo_time = 0.0
	run_time = 600.0
	elapsed = 0.0
	focus = ""
	pierce = selected_character == "sniper"
	waves_cleared = 0
	enemy_speed_mult = 1.0
	enemy_hp_mult = 1.0
	enemy_damage_mult = 1.0
	recalculate_health()
	hp = max_hp
	store.data.mode = mode
	store.save_progress()
	prepare_wave()

func prepare_wave() -> void:
	state = "playing"
	wave_time = minf(90.0, 20.0 + (wave - 1) * 2.0) * float(run_pref("wave_duration"))
	goal_unlocked = false
	overtime_time = 0.0
	overtime_level = 0
	boss_wave = mode == "bossrush" or wave % 10 == 0
	modifier = ""
	resource_mult = 1
	invincible = 1.0
	combo = 0
	combo_time = 0.0
	if wave >= 6 and not boss_wave and randf() < (0.75 if wave <= 15 else 0.35):
		modifier = str(catalog.wave_modifiers.pick_random().id)
	arena.generate_wave()
	ui.play_screen()
	if modifier != "":
		for entry in catalog.wave_modifiers:
			if entry.id == modifier:
				ui.toast(entry.banner)
	elif boss_wave:
		ui.toast("ENDBOSS" if wave == 20 and mode != "bossrush" else "BOSS-WELLE")
	else:
		ui.toast("WELLE %02d · Überlebe und erreiche den Shop" % wave)

func pause_run() -> void:
	if state != "playing":
		return
	state = "paused"
	arena.release_pointer()
	ui.pause_screen()

func resume_run() -> void:
	state = "playing"
	ui.play_screen()

func open_shop() -> void:
	if state != "playing":
		return
	state = "shop"
	arena.release_pointer()
	waves_cleared = maxi(waves_cleared, wave)
	store.data.best_waves = maxi(int(store.data.best_waves), waves_cleared)
	store.save_progress()
	ui.shop_screen()

func next_wave() -> void:
	wave += 1
	prepare_wave()

func price(key: String) -> int:
	var base = int(catalog.passive_meta[key].basePrice)
	var level = float(stats[key])
	var value = int(floor(base * (1.0 + level * 1.55) + level * level * 1.1)) + int(floor((wave - 1) * 2.2))
	if focus != "" and BUILD_MAP[key] == focus:
		value = maxi(1, int(floor(value * 0.8)))
	value = maxi(1, int(floor(value * float(character().shopDiscount.get(key, 1.0)))))
	return value

func buy_upgrade(key: String) -> bool:
	if state != "shop" or not stats.has(key) or (key == "vitality" and mode == "hardcore"):
		return false
	var cost = price(key)
	if points < cost:
		return false
	points -= cost
	if focus == "":
		focus = BUILD_MAP[key]
	stats[key] += 1.0
	if key == "vitality":
		recalculate_health()
		hp = mini(max_hp, hp + 1 + (1 if focus == "defense" else 0))
	if not test_mode:
		audio.effect("collect")
	ui.shop_screen()
	return true

func recalculate_health() -> void:
	max_hp = 1 if mode == "hardcore" else maxi(1, int(round(10 + stats.get("vitality", 0.0) + character().hp)))
	hp = mini(hp, max_hp)

func player_speed() -> float:
	return maxf(2.2, 4.8 + stats.speed * 0.45 + character().speed + (0.35 if focus == "mobility" else 0.0)) * 60.0

func overtime_factor() -> float:
	# Keep arithmetic finite even in artificially long, invincible simulations.
	return exp(minf(log(float(run_pref("overtime_growth"))) * overtime_level, log(1.0e12)))

func advance_overtime(delta: float) -> void:
	if not goal_unlocked or boss_wave: return
	overtime_time += delta
	var level = 1 + int(floor((overtime_time + 0.00001) / float(run_pref("overtime_period"))))
	if level == overtime_level: return
	var previous = overtime_factor()
	overtime_level = level
	var growth = overtime_factor() / previous
	# Preserve damage taken: current and maximum HP grow by the same factor.
	var shared_pools: Array[Dictionary] = []
	for enemy in arena.enemies:
		if enemy.hp > 0:
			enemy.hp *= growth
			enemy.max_hp *= growth
			if enemy.has("shared"):
				var already_scaled = false
				for pool in shared_pools:
					if is_same(pool, enemy.shared): already_scaled = true
				if not already_scaled:
					enemy.shared.hp *= growth
					enemy.shared.max_hp *= growth
					shared_pools.append(enemy.shared)
	arena.spawn_cd = minf(arena.spawn_cd / growth, arena.spawn_interval())

func player_damage() -> float:
	var level = float(stats.damage)
	var bonus = floor(1.0 + (level - 1) * 0.75 + log(1.0 + level) / log(2.0) * 0.5) if level > 0 else 0.0
	var base = maxf(1.0, 1.0 + bonus + character().damage + (1 if focus == "offense" else 0))
	if selected_character == "runner":
		base += stats.speed * 0.75
	var resource = minf(0.35, maxf(0.0, points - 500) / 40.0 * 0.01 * (1 + (stats.resource - 1) * 0.08)) if stats.resource > 0 else 0.0
	return snappedf(base * (1 + resource), 0.1)

func shot_interval() -> float:
	var per = 15.0 if selected_character == "sniper" else 30.0
	return maxf(50.0, 850.0 - stats.attack * per - character().attack * per - (30 if focus == "offense" else 0)) / 1000.0

func attack_range() -> float:
	return 99999.0 if mode == "bossrush" else 160.0 + stats.range * 38.0 + character().range * 38.0 + (25 if focus == "offense" else 0)

func difficulty() -> float:
	var dps = player_damage() / shot_interval() * (1.35 if pierce else 1.0)
	var mobility = 1.0 + stats.speed * 0.12 + maxf(0, character().speed) * 0.15
	var utility = 1.0 + stats.magnet * 0.05 + stats.armor * 0.08 + stats.resource * 0.06
	var power = maxf(0.25, (dps / 3.0) * (max_hp / 10.0) * mobility * utility)
	var raw = 20.0 * pow(1 + 0.035 * elapsed / 60.0, 1.65) * (1 + 0.15 * (sqrt(power) - 1))
	var mult = 2.5 if wave >= 15 else 1.0
	if wave >= 20:
		mult *= pow(1.5, floor((wave - 20) / 5.0) + 1)
	return 1000.0 * (1.0 - exp(-raw / 1000.0)) * mult

func hurt(amount: int, source: Dictionary = {}) -> void:
	if state != "playing" or invincible > 0.0:
		return
	var blocked = randf() < minf(0.95, stats.armor * 0.01)
	if not source.is_empty() and stats.armor > 0:
		arena.damage_enemy(source, (stats.armor + (1 if focus == "defense" else 0)) * (2 if blocked else 1))
	invincible = 0.35 if blocked else 0.7
	if blocked:
		return
	hp -= maxi(1, int(round(amount * (1.0 + difficulty() * 0.1 / 150.0) * float(run_pref("enemy_damage")))))
	combo = 0
	arena.burst(arena.player, Color("ff6b6b"), 12)
	arena.shake = 7.0
	if not test_mode:
		audio.effect("hurt")
	if hp <= 0:
		finish_run("Du hast keine Lebenspunkte mehr.")

func register_kill(position: Vector2) -> void:
	combo += 1
	if pref("combo_popups"):
		arena.floating_texts.append({"p": position + Vector2(0, -25), "text": str(combo), "life": 1.15})
	combo_time = 2.2
	points += maxi(0, mini(3, 1 + int(combo / 5.0)) - 1) + (1 if modifier == "rich" else 0)
	if combo > int(store.data.max_combo):
		store.data.max_combo = combo
		if combo >= 1000:
			store.data.characters.sniper = true
		store.save_progress()
	if combo == 100 and not pierce:
		arena.pickups.append({"p": position, "value": 0, "kind": "pierce"})
		ui.toast("DURCHDRINGEN freigeschaltet · aufsammeln!")
	if not test_mode:
		audio.effect("kill")

func finish_run(reason: String) -> void:
	state = "gameover"
	arena.release_pointer()
	store.data.best_waves = maxi(int(store.data.best_waves), waves_cleared)
	store.save_progress()
	ui.gameover_screen(reason)
