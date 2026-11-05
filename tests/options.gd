extends SceneTree
## Verify new behavior through the real game, menus, persistence and InputMap.
const Preferences = preload("res://scripts/preferences.gd")
var game: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if value: print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func approx(a: float, b: float) -> bool:
	return absf(a - b) < 0.001

func run() -> void:
	seed(48723)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.store.path = "user://options_test.json"
	DirAccess.remove_absolute(game.store.path)
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.start_run()
	var arena = game.arena
	var ui = game.ui
	arena.enemies.clear()
	var mob = arena.spawn_enemy("tank", arena.player + Vector2(200, 0))
	mob.hp *= 0.5
	var initial_max = mob.max_hp
	var initial_interval = arena.spawn_interval()
	expect(approx(game.overtime_factor(), 1), "Normal waves start without overtime multipliers")
	game.goal_unlocked = true
	game.advance_overtime(0)
	expect(game.overtime_level == 1 and approx(game.overtime_factor(), 1.5), "Unlocking the shop immediately adds 1.5x pressure")
	expect(approx(arena.spawn_interval(), initial_interval / 1.5), "Overtime shortens spawn intervals instead of making spawns slower")
	expect(arena.spawn_count(2) == 3, "Overtime increases the number of enemies per spawn")
	expect(approx(mob.max_hp, initial_max * 1.5) and approx(mob.hp / mob.max_hp, 0.5), "Existing enemies gain HP while preserving the damage fraction")
	game.advance_overtime(7.49)
	expect(game.overtime_level == 1, "Pressure does not rise before 7.5 seconds")
	game.advance_overtime(0.01)
	expect(game.overtime_level == 2 and approx(game.overtime_factor(), 2.25), "Exactly 7.5 seconds multiplies pressure by another 1.5")
	game.advance_overtime(15)
	expect(game.overtime_level == 4 and approx(game.overtime_factor(), 5.0625), "Long updates account for all missed pressure steps")
	var fresh = arena.spawn_enemy("runner", arena.player + Vector2(300, 0))
	expect(approx(fresh.max_hp, game.overtime_factor()), "New enemies inherit the current escalating HP multiplier")
	arena.enemies.clear()
	arena.warnings.clear()
	arena.objects.clear()
	arena.spawn_cd = 0
	game.invincible = 100
	arena.simulate(0.01)
	expect(arena.warnings.size() > 0, "Enemies keep spawning while the shop is active")
	for i in 60: arena.simulate(0.01)
	expect(arena.enemies.size() > 0, "Overtime warnings actually become live enemies")
	game.pause_run()
	var time = game.overtime_time
	game._physics_process(0.05)
	expect(game.overtime_time == time, "Pausing freezes overtime escalation")
	game.resume_run()
	game.open_shop()
	game._physics_process(0.05)
	expect(game.overtime_time == time and game.state == "shop", "Entering the shop freezes combat and escalation")
	game.next_wave()
	expect(game.overtime_level == 0 and game.overtime_time == 0 and approx(game.overtime_factor(), 1), "Every new wave resets overtime pressure")
	game.boss_wave = true
	game.goal_unlocked = false
	game.advance_overtime(30)
	expect(game.overtime_level == 0, "Boss fights do not escalate before the boss is defeated")
	game.boss_wave = false
	game.goal_unlocked = true
	game.advance_overtime(10000)
	expect(is_finite(game.overtime_factor()) and arena.spawn_interval() >= 0.04 and arena.spawn_count(2) <= 160, "Extreme overtime stays finite and spawning has bounded actor and interval limits")
	game.start_run()
	game.pause_run()
	ui.open_options("paused", "audio")
	var volume_before = float(game.pref("volume"))
	ui.options_editor.fields.volume.value = 0.23
	expect(approx(game.pref("volume"), volume_before) and approx(ui.options_draft.volume, 0.23), "Editing a slider changes only the draft")
	expect(not ui.buttons.apply_options.disabled and ui.dirty_options_count() == 1, "Apply becomes available when the draft changes")
	var full_event = InputEventKey.new()
	full_event.keycode = KEY_F11
	full_event.pressed = true
	game._unhandled_input(full_event)
	expect(game.pref("window_mode") == "windowed" and ui.options_draft.window_mode == "fullscreen", "Fullscreen shortcut respects pending edits inside settings")
	game._unhandled_input(full_event)
	ui.open_options("paused", "hud")
	expect(approx(ui.options_draft.volume, 0.23), "Switching categories preserves pending changes")
	ui.options_editor.fields.show_minimap.button_pressed = false
	ui.apply_options()
	expect(approx(game.pref("volume"), 0.23) and not game.pref("show_minimap") and ui.dirty_options_count() == 0, "Apply commits all edited categories together")
	var saved = load("res://scripts/save_store.gd").new()
	saved.path = game.store.path
	saved.load_progress()
	expect(approx(saved.data.settings.volume, 0.23) and not saved.data.settings.show_minimap, "Applied preferences survive a real save and reload")
	ui.options_editor.fields.show_minimap.button_pressed = true
	ui.buttons.discard_options.pressed.emit()
	expect(not ui.options_draft.show_minimap and not game.pref("show_minimap"), "Discard restores the applied values without altering the game")
	ui.options_editor.fields.show_health.button_pressed = false
	ui.return_from_options()
	expect(ui.buttons.has("apply_and_back") and ui.buttons.has("discard_and_back") and ui.buttons.has("keep_editing"), "Leaving a dirty draft offers apply, discard and continue")
	ui.buttons.keep_editing.pressed.emit()
	expect(not ui.options_draft.show_health and game.state == "options", "Continue editing preserves the draft and paused run")
	ui.return_from_options()
	ui.buttons.discard_and_back.pressed.emit()
	expect(game.state == "paused" and game.pref("show_health"), "Discard and return abandons changes and resumes the pause menu")
	ui.open_options("paused", "audio")
	ui.options_editor.fields.volume.value = 0.44
	ui.return_from_options()
	ui.buttons.apply_and_back.pressed.emit()
	expect(game.state == "paused" and approx(game.pref("volume"), 0.44), "Apply and return saves changes before leaving settings")
	ui.open_options("paused", "audio")
	ui.options_editor.fields.volume.value = 0.55
	var normal_path = game.store.path
	game.store.path = "user://missing-directory/preferences.json"
	var result = ui.apply_options()
	expect(not result and approx(game.pref("volume"), 0.44) and approx(ui.options_draft.volume, 0.55), "Failed saving keeps applied values and retains the recoverable draft")
	game.store.path = normal_path
	ui.buttons.discard_options.pressed.emit()
	for category in Preferences.CATEGORIES:
		ui.open_options("paused", category)
		expect(ui.options_editor.fields.size() == Preferences.schema()[category].size(), "Every preference has a working native control: " + category)
	ui.open_options("paused", "controls")
	var old_up = int(game.pref("keys").move_up)
	ui.stage_key("move_up", KEY_I)
	expect(int(game.pref("keys").move_up) == old_up and ui.options_draft["keys"].move_up == KEY_I, "Rebinding is staged until Apply")
	expect(ui.stage_key("move_down", KEY_I) != "" and ui.options_draft["keys"].move_down == KEY_S, "Duplicate key assignments are rejected")
	expect(ui.stage_key("move_up", KEY_UP) != "", "Fixed alternate keys remain reserved")
	ui.apply_options()
	var bound = false
	for event in InputMap.action_get_events("move_up"):
		if event is InputEventKey and event.physical_keycode == KEY_I: bound = true
	expect(bound and game.pref("keys").move_up == KEY_I, "Applying a binding updates the real InputMap")
	ui.options_editor.fields.stick_deadzone.value = 0.35
	ui.apply_options()
	expect(approx(InputMap.action_get_deadzone("move_left"), 0.35), "Stick deadzone applies to actual movement actions")
	ui.options_editor.fields.smooth_movement.button_pressed = false
	ui.apply_options()
	arena.walls.clear()
	arena.monument_walls.clear()
	arena.player = Vector2(2000, 2000)
	arena.player_velocity = Vector2.ZERO
	arena.step_player(Vector2.RIGHT, 1.0 / 60)
	expect(approx(arena.player_velocity.x, game.player_speed()), "Disabling movement smoothing gives immediate movement response")
	ui.open_options("paused", "difficulty")
	ui.options_editor.fields.difficulty_preset.select(2)
	ui.options_editor.fields.difficulty_preset.item_selected.emit(2)
	await process_frame
	expect(approx(ui.options_draft.enemy_health, 1.5) and ui.options_draft.difficulty_preset == "hard", "Difficulty profile updates its related draft sliders")
	ui.options_editor.fields.enemy_health.value = 2.0
	expect(ui.options_draft.difficulty_preset == "custom", "Individual balance edits select the custom profile")
	ui.apply_options()
	expect(approx(game.run_pref("enemy_health"), 1), "Applying balance preserves the running game's difficulty snapshot")
	ui.close_options()
	game.start_run()
	expect(approx(game.run_pref("enemy_health"), 2), "A new run adopts the chosen difficulty")
	arena.enemies.clear()
	var adjusted = arena.spawn_enemy("runner", arena.player + Vector2(200, 0))
	expect(approx(adjusted.max_hp, 2), "Enemy health uses the configured run multiplier")
	game.pause_run()
	ui.open_options("paused", "accessibility")
	ui.options_editor.fields.reduce_motion.button_pressed = true
	ui.options_editor.fields.text_scale.value = 1.4
	ui.options_editor.fields.high_contrast.button_pressed = true
	ui.apply_options()
	arena.player_velocity = Vector2.ZERO
	arena.trail.clear()
	for i in 30: arena.step_player(Vector2.RIGHT, 1.0 / 60)
	expect(arena.trail.is_empty() and arena.visual_stretch == 1, "Reduced motion disables trails and player deformation")
	expect(ui.root.theme.default_font_size >= 25, "Accessibility font scaling updates the native UI")
	ui.open_options("paused", "hud")
	ui.options_editor.fields.show_health.button_pressed = false
	ui.options_editor.fields.show_timer.button_pressed = false
	ui.options_editor.fields.show_currency.button_pressed = false
	ui.apply_options()
	ui.close_options()
	game.resume_run()
	expect(not ui.health_plate.visible and not ui.wave_plate.visible and not ui.minimap_frame.visible and ui.pause_button.visible, "HUD visibility preferences hide chosen elements while keeping pause accessible")
	game.modifier = "fog"
	ui.update_hud()
	expect(not ui.hud_bar.visible and not ui.minimap_frame.visible and ui.fog_pause.visible, "Fog overrides HUD preferences while preserving its pause button")
	game.modifier = ""
	game.pause_run()
	ui.open_options("paused", "audio")
	ui.options_editor.fields.master_volume.value = 0.5
	ui.options_editor.fields.sfx_volume.value = 0.6
	ui.options_editor.fields.shot_volume.value = 0.2
	ui.apply_options()
	game.audio.apply_settings(game.store.data.settings)
	expect(approx(game.audio.effect_gain("shot"), 0.06), "Master, effects and per-group volume multiply correctly")
	ui.options_editor.fields.master_volume.value = 0
	ui.apply_options()
	game.audio.apply_settings(game.store.data.settings)
	expect(game.audio.music.stream_paused and game.audio.effect_gain("collect") == 0, "Zero master volume fully mutes music and effects")
	ui.options_editor.fields.master_volume.value = 1
	ui.apply_options()
	game.audio.apply_settings(game.store.data.settings)
	game.audio.set_focus(false)
	expect(game.audio.music.stream_paused, "Background mute pauses music when focus is lost")
	game.audio.set_focus(true)
	expect(not game.audio.music.stream_paused, "Music resumes on focus return when enabled")
	ui.open_options("paused", "display")
	ui.options_editor.fields.floor_detail.value = 0
	ui.options_editor.fields.fps_limit.value = 60
	ui.apply_options()
	expect(approx(arena.floor_surface.material.get_shader_parameter("detail"), 0) and Engine.max_fps == 60, "Graphics preferences reach the floor shader and engine frame limiter")
	ui.close_options()
	ui.request_restart()
	expect(ui.buttons.has("confirm_restart") and ui.buttons.has("cancel_restart"), "Restart confirmation protects the current run by default")
	ui.buttons.cancel_restart.pressed.emit()
	expect(game.state == "paused", "Cancel restart preserves the pause state")
	var legacy = Preferences.normalize({"music": false, "volume": 0.21})
	expect(not legacy.music and approx(legacy.volume, 0.21) and legacy.has("overtime_period") and legacy.has("keys"), "Old settings gain defaults while retaining existing choices")
	var invalid = Preferences.normalize({"master_volume": 99, "enemy_health": -20, "window_mode": "invalid", "keys": false, "music": "no", "fps_limit": NAN})
	expect(invalid.master_volume == 1 and invalid.enemy_health == 0.25 and invalid.window_mode == "windowed" and invalid.music and invalid.fps_limit == 120, "Invalid or out-of-range saved settings are safely normalized")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(800, 600)
	await process_frame
	ui.open_options("paused", "accessibility")
	await process_frame
	var picker: OptionButton
	for option in ui.overlay.find_children("*", "OptionButton", true, false):
		if option.get_item_text(0).begins_with("Kategorie:"): picker = option
	expect(is_instance_valid(picker), "Small windows use a compact category picker instead of eight large tabs")
	picker.select(4)
	picker.item_selected.emit(4)
	await process_frame
	expect(ui.options_section == "controls" and ui.buttons.has("bind_move_up"), "Compact category navigation opens its actual settings")
	var footer = ui.buttons.apply_options.get_global_rect()
	expect(footer.end.y <= root.size.y and footer.position.x >= 0, "Apply stays on screen at 800x600 with 140 percent text")
	game.audio.music.stop()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(normal_path)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
