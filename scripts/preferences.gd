extends RefCounted
## One schema for defaults, validation, persistence and the native settings UI.
const DEFAULT_KEYS = {"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "pause_run": KEY_P, "dash": KEY_SHIFT}
const CATEGORIES = {
	"audio": ["Audio", "Mischpult für Musik und jede Effektgruppe", "edb854"],
	"display": ["Grafik", "Fenster, Leistung und visuelle Effekte", "60dce4"],
	"difficulty": ["Schwierigkeit", "Balance und Gegnerdruck · ab dem nächsten Run", "ed987c"],
	"controls": ["Steuerung", "Tastatur, Gamepad und Zeigerbewegung", "a3b9e5"],
	"hud": ["HUD", "Anzeigen, Minikarte und Benachrichtigungen", "84cdbb"],
	"accessibility": ["Barrierefreiheit", "Lesbarkeit, Kontrast und weniger Bewegung", "ddafe1"],
	"gameplay": ["Spiel", "Pausenverhalten und Kameraführung", "b7cb83"],
}

# [key, title, explanation, default, choices OR min/max/step]
static func schema() -> Dictionary:
	return {
	"audio": [
		["master_volume", "Gesamtlautstärke", "Regelt Musik und alle Effekte gemeinsam.", 1.0, 0.0, 1.0, 0.01],
		["music", "Musik", "Hintergrundmusik abspielen.", true],
		["volume", "Musik-Lautstärke", "Lautstärke der ausgewählten Musik.", 0.7, 0.0, 1.0, 0.01],
		["song", "Musiktitel", "Wähle den Soundtrack.", "sternenlauf", [["sternenlauf", "Sternenlauf Protokoll"], ["broken", "Broken Docking Bay"], ["lightspeed", "Lightspeed Galaxy"]]],
		["sound", "Soundeffekte", "Alle Effektgruppen ein- oder ausschalten.", true],
		["sfx_volume", "Effekt-Lautstärke", "Gemeinsamer Pegel aller Effektgruppen.", 0.8, 0.0, 1.0, 0.01],
		["shot_volume", "Schüsse", "Pegel deiner automatischen Schüsse.", 1.0, 0.0, 1.0, 0.01],
		["hit_volume", "Treffer und Kills", "Pegel erfolgreicher Treffer und besiegter Gegner.", 1.0, 0.0, 1.0, 0.01],
		["collect_volume", "Aufsammeln", "Pegel für Punkte, Herzen und Upgrades.", 1.0, 0.0, 1.0, 0.01],
		["warning_volume", "Schaden und Bosse", "Pegel für erlittenen Schaden und Boss-Effekte.", 1.0, 0.0, 1.0, 0.01],
		["ui_volume", "Menü-Klicks", "Pegel für Schaltflächen im Menü.", 0.6, 0.0, 1.0, 0.01],
		["mute_unfocused", "Stumm im Hintergrund", "Ton ausblenden, wenn das Spielfenster den Fokus verliert.", true],
	],
	"display": [
		["window_mode", "Fenstermodus", "Fenster, randloses Vollbild oder exklusives Vollbild.", "windowed", [["windowed", "Fenster"], ["borderless", "Randloses Vollbild"], ["fullscreen", "Exklusives Vollbild"]]],
		["resolution", "Fenstergröße", "Wirkt im Fenstermodus. Kleine Bildschirme begrenzen die Größe.", "1280x800", [["960x600", "960 × 600"], ["1280x800", "1280 × 800"], ["1600x900", "1600 × 900"], ["1920x1080", "1920 × 1080"]]],
		["vsync", "VSync", "Bildausgabe mit der Bildwiederholrate synchronisieren.", true],
		["fps_limit", "FPS-Limit", "0 bedeutet unbegrenzt. VSync kann zusätzlich begrenzen.", 120.0, 0.0, 240.0, 30.0],
		["particle_amount", "Partikeldichte", "Weniger Partikel können die Leistung verbessern.", 1.0, 0.0, 1.0, 0.1],
		["player_trail", "Spielerspur", "Farbige Nachbilder während der Bewegung.", true],
		["glow", "Leuchteffekte", "Weiche Leuchtsäume an Projektilen und Spieler.", true],
		["floor_detail", "Schaltkreis-Kontrast", "0 blendet die Schaltkreise aus. Der Boden bleibt #141414.", 1.0, 0.0, 1.5, 0.1],
		["screen_shake", "Bildschirmerschütterung", "Stärke der Kameraeffekte bei Schaden und Explosionen.", 1.0, 0.0, 1.0, 0.1],
	],
	"difficulty": [
		["difficulty_preset", "Schwierigkeitsprofil", "Ein Profil setzt die Balance-Regler. Einzeländerungen ergeben Individuell.", "standard", [["relaxed", "Entspannt"], ["standard", "Standard"], ["hard", "Fordernd"], ["custom", "Individuell"]]],
		["enemy_health", "Gegner-HP", "Multiplikator für neue Gegner und Bosse.", 1.0, 0.25, 4.0, 0.05],
		["enemy_speed", "Gegnertempo", "Bewegungstempo normaler Gegner.", 1.0, 0.5, 2.0, 0.05],
		["enemy_damage", "Eingehender Schaden", "Schaden nach Rüstung, mindestens 1 HP pro Treffer.", 1.0, 0.5, 3.0, 0.1],
		["spawn_amount", "Gegner pro Spawn", "Multiplikator für die Anzahl angekündigter Gegner.", 1.0, 0.5, 3.0, 0.1],
		["spawn_frequency", "Spawn-Häufigkeit", "Höhere Werte verkürzen die Zeit zwischen Spawns.", 1.0, 0.5, 3.0, 0.1],
		["heart_chance", "Herz-Dropchance", "Wahrscheinlichkeit pro besiegtem Gegner. Ein Herz heilt 1 HP.", 0.08, 0.0, 0.4, 0.01],
		["wave_duration", "Wellenlänge", "Multiplikator für die Zeit bis zur Shop-Aktivierung.", 1.0, 0.5, 2.0, 0.1],
		["overtime_period", "Eskalation: Zeitabstand", "Nach Shop-Aktivierung steigt der Druck in diesem Abstand (Sekunden).", 7.5, 5.0, 15.0, 0.5],
		["overtime_growth", "Eskalation: Wachstumsfaktor", "Mehr Gegner, kürzere Spawn-Abstände und mehr HP pro Stufe.", 1.5, 1.1, 2.0, 0.1],
	],
	"controls": [
		["gamepad", "Gamepad-Bewegung", "Linken Stick und Steuerkreuz zur Bewegung verwenden.", true],
		["stick_deadzone", "Stick-Totzone", "Verhindert unbeabsichtigtes Driften des Analogsticks.", 0.2, 0.05, 0.5, 0.01],
		["pointer_move", "Maus-/Touch-Bewegung", "Auf der Spielfläche ziehen, um dich zu bewegen.", true],
		["pointer_sensitivity", "Ziehempfindlichkeit", "Höhere Werte benötigen eine kürzere Ziehbewegung.", 1.0, 0.5, 2.0, 0.1],
		["smooth_movement", "Weiche Bewegung", "Kurzes Beschleunigen und Abbremsen. Aus: sofortige Reaktion.", true],
	],
	"hud": [
		["hud_scale", "HUD-Größe", "Größe der oberen Anzeigen. Auf schmalen Fenstern automatisch begrenzt.", 1.0, 0.85, 1.25, 0.05],
		["hud_opacity", "HUD-Deckkraft", "Transparenz von Anzeigen und Minikarte.", 1.0, 0.4, 1.0, 0.05],
		["show_health", "Lebensanzeige", "HP und Lebensbalken oben links.", true],
		["show_timer", "Welle und Timer", "Zeigt nach Zeitablauf die Eskalationsstufe.", true],
		["show_currency", "Punkte und Gold", "Ressourcenanzeige oben rechts.", true],
		["show_minimap", "Minikarte", "Bereits erkundete Bereiche und entdeckte Funde.", true],
		["map_size", "Minikarten-Größe", "Skaliert die Karte innerhalb des verfügbaren Platzes.", 1.0, 0.75, 1.5, 0.05],
		["enemy_bars", "Gegner-Lebensbalken", "Lebensbalken an normalen Gegnern anzeigen.", false],
		["boss_bars", "Boss-Lebensbalken", "Lebensbalken an Bossen und Endboss-Knoten.", true],
		["combo_popups", "Kill-Zahlen", "Gelbe Zahl am besiegten Gegner anzeigen.", true],
		["point_values", "Punktewerte am Boden", "Wert größerer Punkte-Rauten anzeigen.", true],
		["notifications", "Spielhinweise", "Kurze Hinweise für Wellen, Funde und Upgrades.", true],
	],
	"accessibility": [
		["text_scale", "Menü-Schriftgröße", "Größere Schrift in Menüs; Inhalte bleiben scrollbar.", 1.0, 1.0, 1.4, 0.1],
		["high_contrast", "Hoher Kontrast", "Hellerer Menütext und deutlichere Schaltflächenrahmen.", false],
		["enemy_outlines", "Gegner-Konturen", "Zusätzlicher heller Umriss, unabhängig von der Gegnerfarbe.", false],
		["player_marker", "Spieler-Markierung", "Ein heller Ring macht deinen Charakter leichter auffindbar.", false],
		["reduce_motion", "Bewegung reduzieren", "Deaktiviert Spur, Körperverformung, Kamera-Vorlauf und Erschütterung.", false],
		["flashes", "Trefferblinken", "Helle Trefferblitze und Blinken während Unverwundbarkeit.", true],
		["animate_fog", "Nebelanimation", "Aus: Nebel bleibt statisch, seine Spielwirkung bleibt erhalten.", true],
		["hazard_labels", "Gefahrenbeschriftung", "Zusätzlicher Text an aktiven Gefahrenflächen.", false],
	],
	"gameplay": [
		["pause_unfocused", "Pause im Hintergrund", "Pausiert den Run beim Verlassen des Spielfensters.", true],
		["camera_follow", "Sanfte Kameraführung", "Dezente Nachführung statt direkt an der Figur fixierter Kamera.", true],
		["spawn_markers", "Spawn-Warnungen", "Kreise und Kreuze vor neu erscheinenden Gegnern.", true],
		["confirm_restart", "Neustart bestätigen", "Fragt vor dem Verwerfen eines laufenden Runs nach.", true],
	],
	}

static func defaults() -> Dictionary:
	var result = {"keys": DEFAULT_KEYS.duplicate()}
	for rows in schema().values():
		for row in rows: result[row[0]] = row[3]
	return result

static func normalize(values: Dictionary) -> Dictionary:
	var result = defaults()
	for rows in schema().values():
		for row in rows:
			var key = row[0]
			var value = values.get(key, row[3])
			if row[3] is bool:
				if value is bool: result[key] = value
			elif row[3] is String:
				for choice in row[4]:
					if value == choice[0]: result[key] = value
			elif (value is float or value is int) and is_finite(float(value)):
				result[key] = clampf(float(value), row[4], row[5])
	var keys = values.get("keys", {})
	if keys is Dictionary:
		for action in DEFAULT_KEYS:
			var value = keys.get(action, DEFAULT_KEYS[action])
			if (value is int or value is float) and int(value) > 0: result["keys"][action] = int(value)
	return result

static func difficulty_profile(id: String) -> Dictionary:
	var result = {"enemy_health": 1.0, "enemy_speed": 1.0, "enemy_damage": 1.0, "spawn_amount": 1.0, "spawn_frequency": 1.0, "heart_chance": 0.08, "wave_duration": 1.0, "overtime_period": 7.5, "overtime_growth": 1.5}
	match id:
		"relaxed": result.merge({"enemy_health": 0.7, "enemy_speed": 0.85, "enemy_damage": 0.7, "spawn_amount": 0.7, "spawn_frequency": 0.8, "heart_chance": 0.16}, true)
		"hard": result.merge({"enemy_health": 1.5, "enemy_speed": 1.15, "enemy_damage": 1.5, "spawn_amount": 1.5, "spawn_frequency": 1.25, "heart_chance": 0.04}, true)
	return result
