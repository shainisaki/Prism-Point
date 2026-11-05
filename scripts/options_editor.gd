extends RefCounted
## Native, transactional settings. Every control is backed by a runtime preference.
const Preferences = preload("res://scripts/preferences.gd")
var ui: CanvasLayer
var fields: Dictionary = {}
var status: Label
var apply_button: Button
var discard_button: Button

func build() -> void:
	fields.clear()
	var section = ui.options_section
	var compact = ui.root.size.x < 900
	var subtitle = "Änderungen erst mit „Anwenden“ übernehmen." if compact else "Dein Spiel. Deine Einstellungen. Änderungen werden erst mit „Anwenden“ übernommen."
	var box = ui._menu("Einstellungen", subtitle)
	# Keep the action bar visible while the long list of settings scrolls.
	box.get_parent().get_parent().offset_bottom = -(110 + 24 * float(ui.game.pref("text_scale")))
	var categories = {"all": ["Übersicht", "", "60dce4"]}
	categories.merge(Preferences.CATEGORIES)
	if compact:
		var select = OptionButton.new()
		select.custom_minimum_size.y = 48
		select.add_theme_font_size_override("font_size", roundi(18 * float(ui.game.pref("text_scale"))))
		var ids = categories.keys()
		for id in ids:
			select.add_item("Kategorie: " + categories[id][0])
		select.select(ids.find(section))
		select.item_selected.connect(func(index): ui.open_options(ui.options_origin, ids[index]))
		box.add_child(select)
	else:
		var tabs = GridContainer.new()
		tabs.columns = 4
		tabs.add_theme_constant_override("h_separation", 8)
		tabs.add_theme_constant_override("v_separation", 8)
		box.add_child(tabs)
		for id in categories:
			var category = str(id)
			var button = ui._button(tabs, categories[id][0], func(): ui.open_options(ui.options_origin, category), "tab_" + id)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if category == section:
				button.add_theme_stylebox_override("normal", ui._style(Color("21414d"), Color(categories[id][2]), 8, 10))
				button.add_theme_color_override("font_color", Color.WHITE)
	if section == "all":
		build_overview(box)
	else:
		if compact:
			ui._text(box, Preferences.CATEGORIES[section][1], 15)
		else:
			var heading = HBoxContainer.new()
			heading.add_theme_constant_override("separation", 12)
			box.add_child(heading)
			var titles = VBoxContainer.new()
			titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			heading.add_child(titles)
			ui._text(titles, Preferences.CATEGORIES[section][0], 24, Color(Preferences.CATEGORIES[section][2]))
			ui._text(titles, Preferences.CATEGORIES[section][1], 15)
			ui._button(heading, "Zurücksetzen", func(): reset_category(section), "reset_category")
		var grid = GridContainer.new()
		grid.columns = 2 if ui.root.size.x >= 1100 and float(ui.game.pref("text_scale")) <= 1.2 else 1
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		box.add_child(grid)
		for row in Preferences.schema()[section]: build_field(grid, row)
		if section == "controls": build_keys(box)
		if compact: ui._button(box, "Kategorie zurücksetzen", func(): reset_category(section), "reset_category")
	build_footer()
	ui._focus_first()

func build_overview(box: VBoxContainer) -> void:
	ui._text(box, "EINSTELLUNGSZENTRALE", 14, ui.ACCENT)
	var grid = GridContainer.new()
	grid.columns = 2 if ui.root.size.x >= 900 else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for id in Preferences.CATEGORIES:
		var category = str(id)
		var entry = Preferences.CATEGORIES[id]
		var count = Preferences.schema()[id].size()
		ui._pause_card(grid, entry[0].to_upper() + "   /   %d" % count, entry[1], func(): ui.open_options(ui.options_origin, category), "category_" + id, Color(entry[2]))
	ui._text(box, "Audio, Grafik, Eingabe und Anzeigen wirken nach „Anwenden“. Die Balance wird beim Start eines neuen Runs übernommen. Der Nebel-Modifikator verdeckt weiterhin das HUD.", 16)
	ui._button(box, "Alle Einstellungen auf Standard setzen", func():
		ui.options_draft = Preferences.defaults()
		build(), "reset_all")

func build_field(parent: Node, definition: Array) -> void:
	var key = str(definition[0])
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", ui._style(Color("101e28"), Color("2d4858"), 10, 14))
	parent.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	ui._text(column, definition[1], 18, Color("e3ecf7"))
	ui._text(column, definition[2], 14)
	var current = ui.options_draft[key]
	if definition[3] is bool:
		var toggle = CheckButton.new()
		toggle.name = "setting_" + key
		toggle.text = "Ein" if current else "Aus"
		toggle.button_pressed = current
		toggle.toggled.connect(func(value):
			toggle.text = "Ein" if value else "Aus"
			change(key, value))
		column.add_child(toggle)
		fields[key] = toggle
	elif definition[3] is String:
		var select = OptionButton.new()
		select.name = "setting_" + key
		select.custom_minimum_size.y = 42
		select.fit_to_longest_item = false
		var choices = definition[4]
		for i in choices.size():
			select.add_item(choices[i][1])
			if current == choices[i][0]: select.select(i)
		select.item_selected.connect(func(index):
			change(key, choices[index][0])
			if key == "difficulty_preset" and choices[index][0] != "custom":
				ui.options_draft.merge(Preferences.difficulty_profile(choices[index][0]), true)
				ui.call_deferred("open_options", ui.options_origin, ui.options_section))
		column.add_child(select)
		fields[key] = select
	else:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		column.add_child(row)
		var slider = HSlider.new()
		slider.name = "setting_" + key
		slider.min_value = definition[4]
		slider.max_value = definition[5]
		slider.step = definition[6]
		slider.value = current
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(120, 38)
		row.add_child(slider)
		var value_label = ui._label(format_value(key, float(current)), 17, ui.ACCENT)
		value_label.custom_minimum_size.x = 84
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)
		slider.value_changed.connect(func(value):
			value_label.text = format_value(key, value)
			change(key, value))
		fields[key] = slider

func format_value(key: String, value: float) -> String:
	if key == "fps_limit": return "Unbegr." if value == 0 else str(int(value))
	if key == "overtime_period": return "%.1f s" % value
	if key in ["enemy_health", "enemy_speed", "enemy_damage", "spawn_amount", "spawn_frequency", "wave_duration", "overtime_growth"]: return "%.2f ×" % value
	return "%d %%" % roundi(value * 100)

func change(key: String, value: Variant) -> void:
	ui.options_draft[key] = value
	if ui.options_section == "difficulty" and key != "difficulty_preset":
		ui.options_draft.difficulty_preset = "custom"
		if fields.has("difficulty_preset"): fields.difficulty_preset.select(3)
	update_state()

func reset_category(category: String) -> void:
	for definition in Preferences.schema()[category]: ui.options_draft[definition[0]] = definition[3]
	if category == "controls": ui.options_draft["keys"] = Preferences.DEFAULT_KEYS.duplicate()
	build()

func build_keys(box: VBoxContainer) -> void:
	ui._text(box, "TASTENBELEGUNG", 16, Color("a3b9e5"))
	ui._text(box, "Taste auswählen und neue Taste drücken. Esc bricht ab. Pfeile, Esc und Gamepad bleiben als Alternativen verfügbar. Doppelte Belegungen werden abgelehnt.", 15)
	var grid = GridContainer.new()
	grid.columns = 3 if ui.root.size.x >= 1000 else 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	var names = {"move_up": "Hoch", "move_down": "Runter", "move_left": "Links", "move_right": "Rechts", "pause_run": "Pause", "dash": "Dash"}
	for action in Preferences.DEFAULT_KEYS:
		var action_id = str(action)
		var key = int(ui.options_draft["keys"][action])
		var button = ui._button(grid, "%s: %s" % [names[action], OS.get_keycode_string(key)], func():
			if ui.root.get_viewport().gui_get_focus_owner() != null: ui.root.get_viewport().gui_get_focus_owner().release_focus()
			ui.rebind_action = action_id
			ui.toast("Neue Taste drücken · Esc bricht ab", true), "bind_" + action)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui._button(box, "Standardbelegung wiederherstellen", func():
		ui.options_draft["keys"] = Preferences.DEFAULT_KEYS.duplicate()
		build(), "reset_binds")

func build_footer() -> void:
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 32
	panel.offset_right = -32
	panel.offset_top = -(100 + 24 * float(ui.game.pref("text_scale")))
	panel.offset_bottom = -14
	panel.add_theme_stylebox_override("panel", ui._style(Color("112632"), Color("3c6473"), 12, 12))
	ui.overlay.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	status = ui._text(box, "", 14, ui.ACCENT)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	apply_button = ui._button(row, "Anwenden", ui.apply_options, "apply_options")
	apply_button.add_theme_stylebox_override("normal", ui._style(Color("20505b"), ui.ACCENT, 8, 12))
	discard_button = ui._button(row, "Verwerfen", func():
		ui.options_draft = ui.game.store.data.settings.duplicate(true)
		build(), "discard_options")
	for button in [apply_button, discard_button, ui._button(row, "Zurück", ui.return_from_options, "back_options")]: button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	update_state()

func update_state() -> void:
	if not is_instance_valid(status): return
	var count = ui.dirty_options_count()
	status.text = "%d ungespeicherte Änderungen" % count if count > 0 else "Alle Einstellungen übernommen"
	apply_button.disabled = count == 0
	discard_button.disabled = count == 0
