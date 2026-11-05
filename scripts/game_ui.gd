extends CanvasLayer

const MiniMap = preload("res://scripts/minimap.gd")
const HudClock = preload("res://scripts/hud_clock.gd")
const PointSymbol = preload("res://scripts/point_symbol.gd")
const Preferences = preload("res://scripts/preferences.gd")
const OptionsEditor = preload("res://scripts/options_editor.gd")
const ACCENT = Color("60dce4")
const AMBER = Color("edb854")
const MUTED = Color("8ea5b2")
var game: Node
var root: Control
var overlay: Control
var hud: Control
var hud_stats: Label
var hud_bar: Control
var minimap: Control
var minimap_frame: PanelContainer
var health_plate: PanelContainer
var wave_plate: PanelContainer
var currency_row: HBoxContainer
var hp_text: Label
var timer_text: Label
var point_text: Label
var gold_text: Label
var clock: Control
var pause_button: Button
var last_hud_size := Vector2.ZERO
var fog: ColorRect
var fog_pause: Button
var health: ProgressBar
var toast_label: Label
var toast_id := 0
var toast_time := 0.0
var options_origin := "hub"
var options_section := "all"
var compendium_origin := "hub"
var rebind_action := ""
var options_active := false
var options_draft: Dictionary = {}
var options_editor = OptionsEditor.new()
var buttons: Dictionary = {}
var title_background: TextureRect
var landscape = preload("res://assets/images/title_landscape.jpg")
var portrait = preload("res://assets/images/title_portrait.jpg")

func _ready() -> void:
	options_editor.ui = self
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
	var top = Control.new()
	hud_bar = top
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 84
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top)
	health_plate = _hud_panel(top)
	health_plate.name = "HealthCapsule"
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_plate.add_child(row)
	row.add_child(_label("♥", 25, Color("e3eef2")))
	hp_text = _label("9 / 10", 22)
	row.add_child(hp_text)
	health = ProgressBar.new()
	health.custom_minimum_size = Vector2(130, 8)
	health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	health.show_percentage = false
	health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health.add_theme_stylebox_override("background", _style(Color("233b46"), Color.TRANSPARENT, 4, 0))
	health.add_theme_stylebox_override("fill", _style(ACCENT, Color.TRANSPARENT, 4, 0))
	row.add_child(health)
	wave_plate = _hud_panel(top, 28)
	wave_plate.name = "WaveCapsule"
	var wave_row = HBoxContainer.new()
	wave_row.add_theme_constant_override("separation", 12)
	wave_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wave_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_plate.add_child(wave_row)
	hud_stats = _label("WELLE 01", 22)
	wave_row.add_child(hud_stats)
	var divider = ColorRect.new()
	divider.color = Color("354c58")
	divider.custom_minimum_size = Vector2(1, 28)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_row.add_child(divider)
	clock = HudClock.new()
	clock.custom_minimum_size = Vector2(30, 30)
	clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_row.add_child(clock)
	timer_text = _label("00:20", 24, AMBER)
	wave_row.add_child(timer_text)
	currency_row = HBoxContainer.new()
	currency_row.add_theme_constant_override("separation", 10)
	currency_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(currency_row)
	point_text = _currency_chip(currency_row, "◇", ACCENT)
	gold_text = _currency_chip(currency_row, "◉", AMBER)
	pause_button = _button(currency_row, "Ⅱ", game.pause_run, "pause")
	pause_button.custom_minimum_size = Vector2(52, 54)
	pause_button.tooltip_text = "Pause"
	pause_button.add_theme_font_size_override("font_size", 26)
	pause_button.add_theme_stylebox_override("normal", _style(Color(0.035, 0.06, 0.075, 0.9), Color("6c8794"), 14, 12))
	minimap_frame = _hud_panel(hud, 12)
	minimap_frame.name = "MinimapFrame"
	var map = MiniMap.new()
	minimap = map
	map.arena = game.arena
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_frame.add_child(map)
	fog = ColorRect.new()
	fog.name = "AtmosphericFog"
	fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fog_material = ShaderMaterial.new()
	fog_material.shader = preload("res://shaders/fog.gdshader")
	fog.material = fog_material
	root.add_child(fog)
	fog.hide()
	fog_pause = _button(root, "Ⅱ", game.pause_run)
	fog_pause.tooltip_text = "Pause"
	fog_pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fog_pause.offset_left = -130
	fog_pause.offset_right = -20
	fog_pause.offset_top = 20
	fog_pause.offset_bottom = 68
	fog_pause.hide()
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
	_layout_hud()

func _hud_panel(parent: Node, radius: int = 14) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color(0.028, 0.048, 0.063, 0.92), Color(0.39, 0.51, 0.56, 0.72), radius, 12))
	parent.add_child(panel)
	return panel

func _currency_chip(parent: Node, icon: String, color: Color) -> Label:
	var panel = _hud_panel(parent)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	if icon == "◇":
		var symbol = PointSymbol.new()
		symbol.custom_minimum_size = Vector2(22, 22)
		symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(symbol)
	else:
		row.add_child(_label(icon, 22, color))
	var label = _label("0", 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return label

func _place(control: Control, rectangle: Rect2) -> void:
	control.position = rectangle.position
	control.size = rectangle.size

func _layout_hud() -> void:
	last_hud_size = root.size
	var width = root.size.x
	var compact = width < 1000
	var stacked = width < 900
	var margin = 24.0 if not stacked else 16.0
	var health_width = 300.0 if not compact else 226.0
	var wave_width = 314.0 if not compact else 260.0
	var scale_factor = minf(float(game.pref("hud_scale")), 1.0 if width < 1200 else 1.25)
	var currencies_width = (280.0 if not compact else 260.0) * scale_factor
	for control in [health_plate, wave_plate, currency_row]: control.scale = Vector2.ONE * scale_factor
	_place(health_plate, Rect2(margin, 22, health_width, 54))
	_place(wave_plate, Rect2((width - wave_width * scale_factor) / 2, 90 if stacked else 22, wave_width, 54))
	_place(currency_row, Rect2(width - margin - currencies_width, 22, currencies_width / scale_factor, 54))
	var map_width = minf(width * 0.33, (188.0 if not stacked else 152.0) * float(game.pref("map_size")))
	_place(minimap_frame, Rect2(width - margin - map_width, 162 if stacked else 100, map_width, (map_width - 24) * 0.75 + 24))
	hud_bar.offset_bottom = 146 if stacked else 78
	health.custom_minimum_size.x = 130 if not compact else 70
	hp_text.add_theme_font_size_override("font_size", 22 if not compact else 18)
	hud_stats.add_theme_font_size_override("font_size", 22 if not compact else 18)
	timer_text.add_theme_font_size_override("font_size", 24 if not compact else 20)
	toast_label.offset_top = 152 if stacked else 94
	toast_label.offset_bottom = 210 if stacked else 150
	toast_label.add_theme_font_size_override("font_size", 16 if stacked else 18)

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
	label.add_theme_font_size_override("font_size", roundi(font_size * float(game.pref("text_scale"))))
	label.add_theme_color_override("font_color", Color.WHITE if game.pref("high_contrast") and color == MUTED else color)
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
	button.add_theme_font_size_override("font_size", roundi(18 * float(game.pref("text_scale"))))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	button.pressed.connect(func():
		if not game.test_mode: game.audio.effect("ui"))
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
	fog.hide()
	fog_pause.hide()
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
	var remaining = int(ceil(game.run_time if game.mode == "timeattack" else game.wave_time))
	hud_stats.text = "WELLE %02d" % game.wave
	timer_text.text = "BOSS" if game.boss_wave else "%02d:%02d" % [remaining / 60, remaining % 60]
	if game.goal_unlocked: timer_text.text = "DRUCK %02d" % maxi(1, game.overtime_level)
	hp_text.text = "%d / %d" % [maxi(0, game.hp), game.max_hp]
	point_text.text = str(game.points)
	gold_text.text = str(game.store.data.gold)
	clock.fraction = float(remaining) / (600.0 if game.mode == "timeattack" else minf(90, 20 + (game.wave - 1) * 2) * float(game.run_pref("wave_duration")))
	clock.queue_redraw()
	health.max_value = game.max_hp
	health.value = game.hp
	var fog_active = game.modifier == "fog" and game.state == "playing"
	hud_bar.visible = not fog_active
	health_plate.visible = bool(game.pref("show_health"))
	wave_plate.visible = bool(game.pref("show_timer"))
	point_text.get_parent().get_parent().visible = bool(game.pref("show_currency"))
	gold_text.get_parent().get_parent().visible = bool(game.pref("show_currency"))
	minimap.visible = not fog_active and bool(game.pref("show_minimap"))
	minimap_frame.visible = minimap.visible
	hud_bar.modulate.a = float(game.pref("hud_opacity"))
	minimap_frame.modulate.a = float(game.pref("hud_opacity"))
	fog.visible = fog_active
	fog_pause.visible = fog_active

func pause_screen() -> void:
	var box = _menu("Pause", "Welle %d · %s · %s" % [game.wave, game.character().name, game.catalog.modes[game.mode].name])
	var panels = GridContainer.new()
	panels.columns = 2 if root.size.x >= 900 else 1
	panels.add_theme_constant_override("h_separation", 18)
	panels.add_theme_constant_override("v_separation", 18)
	box.add_child(panels)
	var run = _pause_panel(panels, "RUN-STEUERUNG")
	var resume = _button(run, "FORTSETZEN   →", game.resume_run, "resume")
	resume.custom_minimum_size.y = 74
	resume.add_theme_stylebox_override("normal", _style(Color("153c48"), ACCENT, 10, 14))
	_button(run, "Run neu starten", request_restart, "restart")
	_button(run, "Zur Charakterauswahl", game.show_hub, "quit_run")
	var modules = _pause_panel(panels, "EINSTELLUNGEN & INFORMATIONEN")
	var cards = GridContainer.new()
	cards.columns = 2
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 10)
	modules.add_child(cards)
	_pause_card(cards, "AUDIO", "Musik · Lautstärke · Effekte", func(): open_options("paused", "audio"), "pause_audio", AMBER)
	_pause_card(cards, "GRAFIK", "Fenster · Effekte · Leistung", func(): open_options("paused", "display"), "pause_display", ACCENT)
	_pause_card(cards, "STEUERUNG", "Tasten · Eingabe", func(): open_options("paused", "controls"), "pause_controls", Color("a3b9e5"))
	_pause_card(cards, "KOMPENDIUM", "Gegner · Objekte", func(): compendium_screen("paused"), "pause_compendium", Color("84cdbb"))
	_pause_card(cards, "HUD", "Anzeigen · Minikarte", func(): open_options("paused", "hud"), "pause_hud", Color("84cdbb"))
	_pause_card(cards, "BARRIEREFREIHEIT", "Kontrast · Bewegung", func(): open_options("paused", "accessibility"), "pause_accessibility", Color("ddafe1"))
	_button(modules, "Alle Einstellungen", func(): open_options("paused"), "options")
	_text(box, "STATUS & BUILD", 14, ACCENT)
	var overview = GridContainer.new()
	overview.columns = 4 if root.size.x >= 900 else 2
	overview.add_theme_constant_override("h_separation", 10)
	overview.add_theme_constant_override("v_separation", 10)
	box.add_child(overview)
	for entry in [["LEBEN", "%d / %d" % [game.hp, game.max_hp]], ["SCHADEN", "%.1f" % game.player_damage()], ["TEMPO", "%.0f" % game.player_speed()], ["REICHWEITE", "%.0f" % game.attack_range()]]:
		var panel = _pause_panel(overview, entry[0])
		_text(panel, entry[1], 24, Color.WHITE)
	_text(box, "Schussintervall %.2f s   ·   Schüsse/Sekunde %.2f   ·   Durchdringen: %s" % [game.shot_interval(), 1.0 / game.shot_interval(), "aktiv" if game.pierce else "nein"], 16, ACCENT)
	var levels = GridContainer.new()
	levels.columns = 4 if root.size.x >= 900 else 2
	levels.add_theme_constant_override("h_separation", 12)
	box.add_child(levels)
	for key in game.stats:
		var level = _text(levels, "%s: %s" % [game.catalog.passive_meta[key].name, str(game.stats[key])], 15)
		level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_focus_first()

func _pause_panel(parent: Node, title: String) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color("101e28"), Color("2d4858"), 12, 16))
	parent.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	_text(column, title, 13, MUTED)
	return column

func _pause_card(parent: Node, title: String, detail: String, action: Callable, id: String, color: Color) -> void:
	var button = _button(parent, title + "\n" + detail, action, id)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 74
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", roundi(16 * float(game.pref("text_scale"))))
	button.add_theme_color_override("font_color", color)
	button.add_theme_stylebox_override("normal", _style(Color("142631"), color.darkened(0.55), 8, 12))
	button.add_theme_stylebox_override("hover", _style(Color("1c3543"), color, 8, 12))

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

func compendium_screen(origin: String = "hub") -> void:
	compendium_origin = origin
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
	_button(box, "Zurück", return_from_compendium, "back_compendium")
	_focus_first()

func return_from_compendium() -> void:
	if compendium_origin == "paused":
		game.state = "paused"
		pause_screen()
	else:
		game.show_hub()

func open_options(origin: String, section: String = "all") -> void:
	if not options_active:
		options_draft = game.store.data.settings.duplicate(true)
		options_active = true
	options_origin = origin
	options_section = section if section == "all" or Preferences.CATEGORIES.has(section) else "all"
	game.state = "options"
	options_editor.build()

func dirty_options_count() -> int:
	var count = 0
	for key in options_draft:
		if options_draft[key] != game.store.data.settings.get(key): count += 1
	return count

func stage_key(action: String, key: int) -> String:
	if key in [KEY_ESCAPE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		return "Diese Taste bleibt als feste Alternative reserviert."
	for other in options_draft["keys"]:
		if other != action and int(options_draft["keys"][other]) == key:
			return "Taste bereits belegt · Bitte eine andere Taste wählen."
	options_draft["keys"][action] = key
	return ""

func apply_options() -> bool:
	var previous = game.store.data.settings.duplicate(true)
	game.store.data.settings = Preferences.normalize(options_draft)
	if not game.store.save_progress():
		game.store.data.settings = previous
		toast("Speichern fehlgeschlagen. Deine Änderungen bleiben im Entwurf.", true)
		return false
	options_draft = game.store.data.settings.duplicate(true)
	game.apply_preferences()
	options_editor.build()
	toast("Einstellungen übernommen · Balance gilt ab dem nächsten Run", true)
	return true

func return_from_options() -> void:
	rebind_action = ""
	if dirty_options_count() > 0:
		var box = _menu("Änderungen übernehmen?", "Deine Einstellungen wurden noch nicht angewendet.")
		_button(box, "Anwenden und zurück", func():
			if apply_options(): close_options(), "apply_and_back")
		_button(box, "Verwerfen und zurück", close_options, "discard_and_back")
		_button(box, "Weiter bearbeiten", func(): open_options(options_origin, options_section), "keep_editing")
		_focus_first()
		return
	close_options()

func close_options() -> void:
	options_active = false
	options_draft.clear()
	if options_origin == "paused":
		game.state = "paused"
		pause_screen()
	else:
		game.show_hub()

func apply_preferences() -> void:
	var contrast = bool(game.pref("high_contrast"))
	root.theme.default_font_size = roundi(18 * float(game.pref("text_scale")))
	root.theme.set_color("font_color", "Label", Color.WHITE if contrast else Color("e3ecf7"))
	root.theme.set_stylebox("normal", "Button", _style(Color("121e2d"), Color("98b9cb") if contrast else Color("30465d"), 10, 14))
	_layout_hud()
	if game.state == "playing": update_hud()

func request_restart() -> void:
	if not game.pref("confirm_restart"):
		game.start_run()
		return
	var box = _menu("Run neu starten?", "Der Fortschritt dieses Runs wird verworfen. Deine Freischaltungen bleiben erhalten.")
	_button(box, "Neuen Run starten", game.start_run, "confirm_restart")
	_button(box, "Zurück zur Pause", pause_screen, "cancel_restart")
	_focus_first()

func monument_screen() -> void:
	var box = _menu("Schaltmodul aktiviert", "Wähle eine Systemmodifikation. Nutzen und Risiken gelten für diesen Run.")
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

func toast(text: String, essential: bool = false) -> void:
	if not essential and not game.pref("notifications"): return
	toast_time = 3.0
	toast_label.text = text
	toast_label.show()

func _process(delta: float) -> void:
	if root.size != last_hud_size:
		_layout_hud()
	if fog.visible:
		fog.material.set_shader_parameter("mist_time", game.elapsed if game.pref("animate_fog") and not game.pref("reduce_motion") else 0.0)
		fog.material.set_shader_parameter("view_size", root.size)
		fog.material.set_shader_parameter("world_offset", game.arena.camera.position)
	if game.state == "title" and is_instance_valid(title_background):
		title_background.texture = portrait if root.size.y > root.size.x else landscape
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0:
			toast_label.hide()
