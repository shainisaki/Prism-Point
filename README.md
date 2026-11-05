# PRISM POINT — Godot

Native 2D-Version für **Godot 4.6+**, entwickelt und geprüft mit Godot 4.6.3.
Das Spiel verwendet GDScript, Godot-Controls, Camera2D, AudioStreamPlayer und
AStarGrid2D. Es benötigt **keinen Browser, kein HTML und keinen Webserver**.

Die neuesten Änderungen mit Bildern stehen im [Gameplay-Update](docs/GAMEPLAY_UPDATE.md).

## Öffnen und spielen

1. Godot 4.6 oder neuer installieren (Standard-Version, .NET nicht nötig).
2. Im Projektmanager **Importieren** wählen und `project.godot` öffnen.
3. Den ersten Asset-Import abwarten und mit **F5** starten.
4. **Spielen → Charakter/Modus wählen → Run starten**.

Alternativ im Projektverzeichnis: `godot --path .`

| Aktion | Eingabe |
| --- | --- |
| Bewegen | WASD / Pfeiltasten / linker Stick / Steuerkreuz |
| Maus oder Touch | Auf der Spielfläche ziehen |
| Schießen | Automatisch auf ein nahes, sichtbares Ziel |
| Dash ab Tempo-Level 10 | Shift / Gamepad X |
| Pause / Fortsetzen | P / Esc / Gamepad Start |
| Menüs | Maus / Touch / Pfeile + Enter / Gamepad A |
| Vollbild | F11 |

Die Haupttasten lassen sich in **Optionen** neu belegen; Pfeiltasten und
Gamepad bleiben als Alternativen verfügbar. Der erste Kauf legt den Build fest.
Nach dem Wellen-Timer dem markierten Pfad zum Shop folgen. Boss-Wellen enden
erst nach dem Sieg über den Boss. Gold schaltet dauerhaft Charaktere frei.

HP bleiben beim Shopbesuch und Wellenwechsel erhalten. Besiegte Gegner haben
eine **8%-Chance**, ein rotes Herz fallenzulassen: Aufsammeln heilt **1 HP**,
bis zum Maximum. Bei vollen HP bleiben Herzen liegen. Nur ein neuer Run
beginnt mit vollen HP; gezielte Vitalitäts-Upgrades können weiterhin heilen.

Die Minikarte deckt den tatsächlich sichtbaren Kartenausschnitt dauerhaft auf;
unbesuchte Bereiche bleiben verborgen und werden bei einer neuen Welle
zurückgesetzt. Der Nebel-Modifier erzeugt weichen Dunst über die ganze Sicht
und blendet HP, Timer, Punkte/Gold und Minikarte aus. Pause bleibt erreichbar.
Statuswerte stehen ausschließlich im Pausenmenü, Combo-Zahlen erscheinen
kurzzeitig gelb am besiegten Gegner.

## Übertragene Inhalte

- Titelgrafiken, Kristallgrafik und alle drei Musikstücke aus dem Original;
  keine externen Downloads während des Spiels.
- Standard, Runner, Bomber, Tank und Sniper mit Kosten, Startwerten,
  Granaten, Tempo-Schaden, Durchdringen/Abprallen und Combo-Freischaltung.
- Survival, Endless, Boss Rush, Hardcore und zehnminütiger Time Attack.
- Prozedurale 4800×3600-Arena, Kollisionen, A*-Navigation, Shop-Pfad, Minikarte,
  Spawn-Warnungen, sechs reguläre Gegnerarten, Splitter und Beute-Gegner.
- Wellen-Skalierung, acht Upgrades, Build-Rabatte, Punkte, Gold, Combos,
  Magnetismus, Rüstung/Dornen, Mehrfachschuss und Dash.
- Vier Boss-Arten mit Phasen, Lasern, Drohnen, geteiltem Leben und
  Hexagon-Duplikaten; Welle 20 mit sechs Endboss-Knoten und Kern.
- Kisten, explosive Fässer, Kristalle, Satelliten-Monument, Altes Monument mit
  drei Offenbarungen, versteckter Shop-Schalter und sieben Wellen-Events.
- Großes Dreiecksmonument mit kollidierenden Steinwänden, drei Eingängen und
  grünen Flammen; zum Aktivieren innen auf dem zentralen Feld stehen bleiben.
- Pro Welle neu angeordnete Wände mit neun Strukturen in vier wechselnden
  Layout-Familien; Fassboss mit Holzdauben, Metallreifen und Rollanimation.
  Endboss: 2000 Kern-HP und 240 HP je Knoten (+100% gegenüber der ersten Portierung).
- Pause, Neustart, Game Over, Kompendium, Musik-/Effektlautstärke und
  native Speicherung von Gold, Freischaltungen, Rekorden und Einstellungen.

Dies ist eine spielbare **native Neuimplementierung**, keine automatisch
übersetzte oder bildgenaue Kopie. Kartenformen, Rendering, Treffer-Effekte,
Soundeffekte und Boss-Angriffsmuster sind für Godot neu umgesetzt; Details
und Timing unterscheiden sich vom Browser-Original. Bewegung ist jetzt
zeitbasiert statt an die Browser-Bildrate gekoppelt. Automatische Schüsse
berücksichtigen Sichtlinien und können Kisten/Fässer anvisieren. Die Endboss-
Knoten schützen den Kern. Weitere Abweichungen und Prüfgrenzen stehen in
[docs/MIGRATION.md](docs/MIGRATION.md).

## Spielstand

Godot speichert unter `user://progress.json`, auf normalen Desktop-Systemen
im Godot-Benutzerdatenverzeichnis (`app_userdata/PRISM POINT`). Testläufe
verwenden eigene Dateien. Browser-Spielstände werden nicht automatisch
übernommen; sie bleiben im bisherigen Browser erhalten.

## Tests

```sh
python3 tests/run.py
```

Der Runner importiert Assets und führt echte GDScript-Integrationstests aus.
Die Tests umfassen 52 Basis-Checks sowie 45 Regressionen für Monument,
Kartenaufdeckung, Nebel, HP-Verlauf, Herzen, Combo-Anzeigen und neue Layouts.
Er prüft zusätzlich Engine-/Scriptfehler, weil Godot bei manchen Laufzeitfehlern
trotzdem Exitcode 0 liefert. Es gibt keine npm-/Python-Paketabhängigkeiten.
Für den optionalen visuellen Test mit verfügbarem Bildschirm:

```sh
godot --path . --audio-driver Dummy --script tests/render.gd
```

Er erzeugt Screenshots unter `/tmp/prism-*.png` (Linux). Die Spieltests prüfen
keinen hörbaren Klang, keine physischen Controller und keine Mobilgeräte.

## Desktop exportieren

Unter **Editor → Exportvorlagen verwalten** die zu deiner Godot-Version
passenden Vorlagen installieren. Danach **Projekt → Exportieren** verwenden.
Presets für Windows und Linux sind vorbereitet; Ausgabe unter `exports/`.
Das Ressourcenpaket (PCK) wurde erfolgreich exportiert und unabhängig vom
Checkout gestartet. Eine fertige EXE/Linux-Binary wurde ohne installierte
Exportvorlagen noch nicht validiert. Das Projekt lässt sich bereits direkt
im Godot-Editor spielen.

## Aufbau

- `scenes/main.tscn`: Einstiegsszene.
- `scripts/game.gd`: Run-Zustände, Werte, Wirtschaft und Eingaben.
- `scripts/arena.gd`: Welt, Kampf, Gegner, Bosse und Vektorgrafik.
- `scripts/game_ui.gd`, `minimap.gd`: native Menüs und HUD.
- `scripts/game_audio.gd`, `save_store.gd`: Audio und Fortschritt.
- `assets/game_data.json`: Charakter-/Modus-/Upgrade-/Kompendium-Daten.
- `reference/original_source.html.txt`: unveränderte historische Quelle zur
  Nachverfolgung; von Godot ignoriert und aus Exporten ausgeschlossen.

Die früheren leeren bzw. `PLACEHOLDER`-Dateien wurden durch dieses Projekt
ersetzt. Die historischen Assets stammen unverändert aus dem Repository;
durch die Migration werden keine zusätzlichen Nutzungsrechte eingeräumt.
