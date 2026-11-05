extends CanvasLayer

const MiniMap = preload("res://scripts/minimap.gd")
const ACCENT = Color("75d4ff")
const MUTED = Color("8a9bb0")
var game: Node
var root: Control
var overlay: Control
var hud: Control
var hud_stats: Label
var hud_detail: Label
var health: ProgressBar
var toast_label: Label
var toast_id := 0
var toast_time := 0.0
var options_origin := "hub"
var rebind_action := ""
var buttons: Dictionary = {}
var title_background: TextureRect
var landscape = preload("res://assets/images/title_landscape.jpg")
var portrait = preload("res://assets/images/title_portrait.jpg")

func _ready() -> void:
	root = Control.new()
	root.name = "Interface"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme = Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("e3ecf7"))
	var base = _style(Color("121e2d"), Color("30465d"), 10, 14)
	var hover = _style(Color("20384c"), ACCENT, 10, 14)
	theme.set_stylebox("normal", "Button", base)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", _style(Color("284b61"), ACCENT, 10, 14))
	theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), ACCENT, 10, 0))
	theme.set_stylebox("disabled", "Button", _style(Color("111924"), Color("202c3b"), 10, 14))
	theme.set_color("font_disabled_color", "Button", Color("657386"))
	theme.set_color("font_color", "Button", Color("e3ecf7"))
	root.theme = theme
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	var top = PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 16
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", _style(Color(0.025, 0.045, 0.07, 0.95), Color("26384c"), 12, 14))
	hud.add_child(top)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	hud_stats = _label("", 20)
	col.add_child(hud_stats)
	health = ProgressBar.new()
	health.custom_minimum_size.y = 4
	health.show_percentage = false
	health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health.add_theme_stylebox_override("background", _style(Color("2d2431"), Color.TRANSPARENT, 2, 0))
	health.add_theme_stylebox_override("fill", _style(Color("ff6b88"), Color.TRANSPARENT, 2, 0))
	col.add_child(health)
	_button(row, "Ⅱ  Pause", game.pause_run, "pause")
	hud_detail = _label("", 14, MUTED)
	hud_detail.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hud_detail.offset_left = 24
	hud_detail.offset_right = -24
	hud_detail.offset_top = -70
	hud_detail.offset_bottom = -16
	hud_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(hud_detail)
	var map = MiniMap.new()
	map.arena = game.arena
	map.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map.offset_left = -212
	map.offset_right = -24
	map.offset_top = 106
	map.offset_bottom = 247
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(map)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	toast_label = _label("", 20, ACCENT)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast_label.offset_left = 40
	toast_label.offset_right = -40
	toast_label.offset_top = 100
	toast_label.offset_bottom = 175
	root.add_child(toast_label)

func _style(background: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box

func _label(text: String, font_size: int = 18, color: Color = Color("e3ecf7")) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _text(parent: Node, text: String, font_size: int = 18, color: Color = MUTED) -> Label:
	var label = _label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable, id: String = "") -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	parent.add_child(button)
	if id != "":
		button.name = id
		buttons[id] = button
	return button

func _clear() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	buttons.clear()
	toast_label.hide()
	hud.hide()
	overlay.show()

func _menu(title: String, subtitle: String = "") -> VBoxContainer:
	_clear()
	var shade = ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.045, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	overlay.add_child(margin)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 16)
	scroll.add_child(box)
	_text(box, "PRISM POINT   /   " + title.to_upper(), 14, ACCENT)
	_text(box, title, 36, Color.WHITE)
	if subtitle != "":
		_text(box, subtitle, 17, MUTED)
	return box

func _focus_first() -> void:
	call_deferred("_focus_current")

func _focus_current() -> void:
	if not is_inside_tree():
		return
	var all = overlay.find_children("*", "Button", true, false)
	for button in all:
		if not button.disabled:
			button.grab_focus()
			return

func title_screen() -> void:
	_clear()
	var background = TextureRect.new()
	background.texture = landscape
	title_background = background
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(background)
	var shade = ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.4)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	var panel = VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -210
	panel.offset_right = 210
	panel.offset_top = -200
	panel.offset_bottom = -40
	panel.add_theme_constant_override("separation", 14)
	overlay.add_child(panel)
	var label = _label("NATIVE EDITION  ·  GODOT 4", 15, ACCENT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	_button(panel, "SPIELEN   →", game.show_hub, "title_play")
	var hint = _label("Enter / Leertaste / A zum Fortfahren", 14, Color("c3d0de"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hint)
	_focus_first()

func hub_screen() -> void:
	var box = _menu("Dein nächster Run", "Gold bleibt zwischen Runs erhalten. Der erste Upgrade-Kauf bestimmt deinen Build.")
	_text(box, "GOLD  %d     /     BESTE WELLE  %d     /     MAX. COMBO  %d" % [game.store.data.gold, game.store.data.best_waves, game.store.data.max_combo], 17, Color("ffd24a"))
	_text(box, "01  /  SPIELMODUS", 14, ACCENT)
	var modes = GridContainer.new()
	modes.columns = 5 if root.size.x >= 1000 else 2
	modes.add_theme_constant_override("h_separation", 10)
	modes.add_theme_constant_override("v_separation", 10)
	box.add_child(modes)
	for id in game.catalog.modes:
		var mode_id = str(id)
		var entry = game.catalog.modes[id]
		var button = _button(modes, ("●  " if game.mode == id else "") + entry.name + "\n" + entry.tag,
			func(): game.mode = mode_id; hub_screen(), "mode_" + id)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
	_text(box, "02  /  CHARAKTER", 14, ACCENT)
	var chars = GridContainer.new()
	chars.columns = 5 if root.size.x >= 1000 else 2
	chars.add_theme_constant_override("h_separation", 10)
	chars.add_theme_constant_override("v_separation", 10)
	box.add_child(chars)
	for id in game.catalog.characters:
		var char_id = str(id)
		var c = game.catalog.characters[id]
		var unlocked = game.is_unlocked(id)
		var status = "AUSGEWÄHLT" if game.selected_character == id else ("Verfügbar" if unlocked else ("Combo 1000" if id == "sniper" else "%d Gold · Freischalten" % c.cost))
		var button = _button(chars, c.name + "\n" + c.tag + "\n\n" + status,
			func():
				if game.choose_character(char_id): hub_screen()
				else: toast("Noch nicht freigeschaltet · Gold oder Combo-Voraussetzung fehlt"), "char_" + id)
		button.custom_minimum_size.y = 150
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var start = _button(row, "RUN STARTEN   →", game.start_run, "start_run")
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(row, "Kompendium", compendium_screen, "compendium")
	_button(row, "Optionen", func(): open_options("hub"), "options")
	_text(box, "WASD / Pfeile / linker Stick: bewegen   ·   Schießen: automatisch   ·   P / Esc / Start: Pause\nShift / X: Dash ab Tempo-Level 10   ·   Maus oder Touch: ziehen   ·   F11: Vollbild", 14)
	_focus_first()

func play_screen() -> void:
	_clear()
	overlay.hide()
	hud.show()
	update_hud()

func update_hud() -> void:
	var timer = "%02d:%02d" % [int(game.run_time / 60), int(game.run_time) % 60] if game.mode == "timeattack" else "%ds" % int(ceil(game.wave_time))
	hud_stats.text = "WELLE %02d     %s     HP %d / %d     %d PKT     %d GOLD" % [game.wave, "BOSS" if game.boss_wave else timer, maxi(0, game.hp), game.max_hp, game.points, game.store.data.gold]
	if root.size.x < 950:
		hud_stats.add_theme_font_size_override("font_size", 13)
	else:
		hud_stats.add_theme_font_size_override("font_size", 20)
	health.max_value = game.max_hp
	health.value = game.hp
	var text = "COMBO ×%d   ·   %s" % [game.combo, "DURCHDRINGEN AKTIV" if game.pierce else "Durchdringen ab Combo 100"]
	text += "   /   " + ("SHOP OFFEN · Folge dem Pfad" if game.goal_unlocked else "Überlebe die Welle")
	if game.store.data.settings.get("passives", true):
		text += "\nSCHADEN %.1f   ·   TEMPO %.0f   ·   REICHWEITE %.0f   ·   SCHUSS %.2fs" % [game.player_damage(), game.player_speed(), game.attack_range(), game.shot_interval()]
	hud_detail.text = text

func pause_screen() -> void:
	var box = _menu("Pause", "Welle %d · %s · %s" % [game.wave, game.character().name, game.catalog.modes[game.mode].name])
	_text(box, "HP %d / %d   ·   Schaden %.1f   ·   Tempo %.0f   ·   Reichweite %.0f" % [game.hp, game.max_hp, game.player_damage(), game.player_speed(), game.attack_range()], 18, Color.WHITE)
	_button(box, "Fortsetzen", game.resume_run, "resume")
	_button(box, "Optionen", func(): open_options("paused"), "options")
	_button(box, "Run neu starten", game.start_run, "restart")
	_button(box, "Zur Charakterauswahl", game.show_hub, "quit_run")
	_focus_first()

func shop_screen() -> void:
	var focus = "Erster Kauf bestimmt deinen Build" if game.focus == "" else "BUILD: %s · passende Upgrades −20%%" % game.BUILD_NAMES[game.focus]
	var box = _menu("Welle %d geschafft" % game.wave, "%d Punkte verfügbar · %s" % [game.points, focus])
	var grid = GridContainer.new()
	grid.columns = 2 if root.size.x >= 750 else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for key in ["vitality", "speed", "attack", "damage", "range", "magnet", "armor", "resource"]:
		var stat_key = str(key)
		var meta = game.catalog.passive_meta[key]
		var price = game.price(key)
		var button = _button(grid, "%s · Lv. %s    /    %d Punkte\n%s" % [meta.name, str(game.stats[key]), price, meta.desc], func(): game.buy_upgrade(stat_key), "buy_" + key)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = game.points < price or (key == "vitality" and game.mode == "hardcore")
		button.add_theme_font_size_override("font_size", 16)
	_button(box, "NÄCHSTE WELLE   →", game.next_wave, "next_wave")
	_button(box, "Run beenden", game.show_hub, "quit_run")
	_focus_first()

func gameover_screen(reason: String) -> void:
	var box = _menu("Run beendet", reason)
	_text(box, "WELLE %d   /   %d PUNKTE   /   %d GOLD" % [game.wave, game.points, game.store.data.gold], 26, Color("ffd24a"))
	_text(box, "Dein Gold und freigeschaltete Charaktere bleiben erhalten.")
	_button(box, "Charakter wählen", game.show_hub, "back_hub")
	_button(box, "Noch einmal", game.start_run, "restart")
	_focus_first()

func compendium_screen() -> void:
	game.state = "compendium"
	var box = _menu("Kompendium", "Gegner, Bosse und Funde")
	for entry in game.catalog.compendium:
		var panel = PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _style(Color("101a27"), Color("24354a"), 8, 14))
		box.add_child(panel)
		var content = VBoxContainer.new()
		panel.add_child(content)
		_text(content, entry.name, 20, Color(entry.color) if entry.color != "#111" else Color("b7b7cb"))
		_text(content, entry.desc, 16)
	_button(box, "Zurück", game.show_hub, "back_hub")
	_focus_first()

func open_options(origin: String) -> void:
	options_origin = origin
	game.state = "options"
	var box = _menu("Optionen", "Einstellungen werden im nativen Godot-Spielstand gespeichert.")
	for item in [["music", "Musik"], ["sound", "Soundeffekte"], ["enemy_bars", "Gegner-Lebensbalken"], ["passives", "Statuswerte anzeigen"]]:
		var key = str(item[0])
		var toggle = CheckButton.new()
		toggle.text = item[1]
		toggle.button_pressed = game.store.data.settings.get(key, true)
		toggle.toggled.connect(func(value): game.store.data.settings[key] = value; _save_options())
		box.add_child(toggle)
	for item in [["volume", "Musik-Lautstärke"], ["sfx_volume", "Effekt-Lautstärke"]]:
		var key = str(item[0])
		_text(box, item[1], 16)
		var slider = HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = game.store.data.settings.get(key, 0.7)
		slider.value_changed.connect(func(value): game.store.data.settings[key] = value; _save_options())
		box.add_child(slider)
	var song = OptionButton.new()
	var song_ids = game.audio.TRACKS.keys()
	for id in song_ids:
		song.add_item(game.audio.TRACKS[id])
	song.select(maxi(0, song_ids.find(game.store.data.settings.get("song", "sternenlauf"))))
	song.item_selected.connect(func(index): game.store.data.settings.song = song_ids[index]; _save_options())
	box.add_child(song)
	_text(box, "Steuerung: WASD oder Pfeile / linker Gamepad-Stick / Ziehen mit Maus oder Touch.\nPause: P / Esc / Start. Dash: Shift / X ab Tempo-Level 10. Menüs: Pfeile + Enter / Gamepad A.", 15)
	var keys = GridContainer.new()
	keys.columns = 3 if root.size.x >= 900 else 2
	box.add_child(keys)
	var names = {"move_up": "Hoch", "move_down": "Runter", "move_left": "Links", "move_right": "Rechts", "pause_run": "Pause", "dash": "Dash"}
	for action in game.DEFAULT_KEYS:
		var action_id = str(action)
		var key = int(game.store.data.settings.get("keys", {}).get(action, game.DEFAULT_KEYS[action]))
		var button = _button(keys, "%s: %s" % [names[action], OS.get_keycode_string(key)], func():
			if root.get_viewport().gui_get_focus_owner() != null:
				root.get_viewport().gui_get_focus_owner().release_focus()
			rebind_action = action_id
			toast("Neue Taste drücken · Esc bricht ab"), "bind_" + action)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(box, "Zurück", return_from_options, "back_options")
	_focus_first()

func _save_options() -> void:
	game.store.save_progress()
	if not game.test_mode:
		game.audio.apply_settings(game.store.data.settings)

func return_from_options() -> void:
	rebind_action = ""
	if options_origin == "paused":
		game.state = "paused"
		pause_screen()
	else:
		game.show_hub()

func monument_screen() -> void:
	var box = _menu("Altes Monument", "Wähle eine Offenbarung. Nutzen und Risiken gelten für diesen Run.")
	var outcome = randf()
	for i in 3:
		var good = outcome < 0.25 or (outcome < 0.6 and randf() < 0.5)
		var key = str(game.stats.keys().pick_random())
		var amount = randi_range(1, 12) if good else -randi_range(1, 3)
		var risk = randi() % 4 if not good else -1
		var labels = ["Gegner: +12% Lauftempo", "Gegner: +15% HP", "Gegner: +12% Schaden"]
		var text = "%+d %s" % [amount, game.catalog.passive_meta[key].name] if good or risk == 3 else labels[risk]
		_button(box, text, func():
			if good or risk == 3: game.arena.apply_stat(key, amount)
			elif risk == 0: game.enemy_speed_mult *= 1.12
			elif risk == 1: game.enemy_hp_mult *= 1.15
			else: game.enemy_damage_mult *= 1.12
			game.resume_run(), "choice_" + str(i))
	_focus_first()

func toast(text: String) -> void:
	toast_time = 3.0
	toast_label.text = text
	toast_label.show()

func _process(delta: float) -> void:
	if game.state == "title" and is_instance_valid(title_background):
		title_background.texture = portrait if root.size.y > root.size.x else landscape
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0:
			toast_label.hide()
