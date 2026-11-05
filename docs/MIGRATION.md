# Stand der Godot-Übertragung

## Grundlage

Quelle: `prism_point (33).html` aus Commit
`5a2738be36f7d1e38bf27465e51770a76b3811cb`.
Die Originaldatei bleibt bytegleich unter `reference/original_source.html.txt`
erhalten. Sie wird weder geladen noch ausgeführt. Charaktere, Modi,
Upgrade-Metadaten und Kompendium wurden als JSON übernommen, Bilder und MP3s
aus den Data-URLs extrahiert. Die Laufzeit enthält kein JavaScript/WebView.

## Bewusste Anpassungen

- Native Godot-Menüs statt DOM und frei beweglicher Lobby-Figur.
- Neue, offen verbundene Raumcluster statt identischer Browser-Kartenformen.
  Eine Flutfüllung und A* stellen einen erreichbaren Shop-Pfad sicher.
- Zeitbasierte Bewegung, segmentbasierte Geschosstreffer und Sichtlinien beim
  Auto-Aim. Kisten/Fässer sind bei fehlenden näheren Gegnern ebenfalls Ziele.
- Boss-Angriffe sind native Annäherungen: Hexagon mit Unsichtbarkeit,
  Drohnen und geteilten Duplikaten; Dreieck mit angekündigten Lasern;
  Viereck mit Ansturm; fünf Zylinder mit gemeinsamem Leben. Die genauen
  Browser-Animationen, Laserfolgen und Ninja-/Sprungbewegungen sind nicht 1:1.
- Die sechs Endboss-Knoten schützen den Kern. Nach dem Endboss öffnet sich
  wie bei anderen Bossen der Shop; weitere Wellen bleiben möglich.
- Der native Rabatt beträgt 20%, entsprechend der ursprünglichen Preisformel.
  Die alte UI behauptete abweichend 25%.
- Titelgrafiken und Musik sind original; Kampf-Vektorgrafik, Lichtkreise,
  Partikel und synthetisierte Effekte wurden neu erstellt. Kein identisches
  Bildschirmblitzen/Hitstop, keine vollständige optische Kopie.
- Kartenfunde werden neu verteilt. Das Alte Monument verwendet die positiven,
  gemischten und negativen Offenbarungen mit denselben Hauptwahrscheinlichkeiten.
  Kleine Monumentboni verwenden eine reduzierte Auswahl von Beträgen.
- Eine neue native Spielstandsdatei ersetzt Browser-localStorage. Ein Import
  alter Browserdaten ist noch nicht implementiert.

## Noch nicht 1:1 übernommen / nicht geprüft

- Auswahl des konkreten Audio-Ausgabegeräts, Vibrationsstärke/Haptik,
  die alte frei bewegliche Lobby-Figur und alle kosmetischen Effekte.
- Exakte Balance über einen kompletten 20+-Wellen-Run; physische Gamepads,
  echtes Touchgerät und hörbare Audioausgabe.
- Mobile-Export, App-Store-Pakete und signierte Desktop-Installationsdateien.
  Windows-/Linux-Exportvorlagen müssen separat installiert werden.

## Verifikation

`python3 tests/run.py` importiert das Projekt und prüft Titel/Lobby,
Run-Start, Kartenzugang, Bewegung, Kollision, Auto-Aim/Treffer, Punkte,
Pause, Timer, Shop, Upgrades, Wellenwechsel, Unverwundbarkeit, Hardcore,
Boss Rush, alle Boss-Arten, Gold, Freischaltungen, Spielstand-Roundtrip,
Time Attack, Optionen, Kompendium und Simulation der Wellen 6/10/20/25.
Laufzeitdiagnosen werden zusätzlich zum Exitcode ausgewertet.
Die 52 Basis-Checks werden durch `tests/feedback.gd` um 69 Regressionen
erweitert: Monument-Wände und Eingänge auch für den Tank, Aktivierung von innen,
Sichtbereichsaufdeckung und Erinnern/Zurücksetzen der Minikarte, versteckte
Nebel-HUDs und nutzbare Pause, ausschließlich dort angezeigte Statuswerte,
nummerierte Combo-Popups, Herzen und HP-Übernahme, Rollanimation,
2000/240 Endboss-HP sowie acht unterschiedliche, begehbare Kartenlayouts.
Weitere 31 Checks in `tests/feel.gd` prüfen additive Punkteverschmelzung samt
Sammelboni, 5.000 dichte Drops, Hindernisse, Bewegungsverhalten bei 30/60/120 Hz,
Bewegungsspuren, bündige Modulecken und die Funktionen des neuen Pausenmenüs.
Weitere 62 Checks in `tests/options.gd` prüfen die Eskalation nach Shop-Aktivierung,
vorhandene und neue Gegner-HP, Pausieren/Zurücksetzen, transaktionale Optionen,
Speichern und Speicherfehler, sieben Kategorien, Tasten-Konflikte, Run-Balance,
Audio-/Grafik-/HUD-Wirkungen und kleine Fenster mit großer Schrift.
Aktuelles Gesamtergebnis mit Godot 4.6.3: 214 Checks bestanden, keine
Engine-/Scriptfehler. Bilder und Änderungen: [Gameplay-Update](GAMEPLAY_UPDATE.md).
Die neue UI-Kombination und kleine Fenstergrößen: [UI-Update](UI_UPDATE.md).

`tests/render.gd` rendert zusätzlich das technische Schaltmodul mit blauen Glühbirnen,
zwei Rollphasen des Fassbosses, flächigen Nebel, die Pausen-Statusübersicht
und Combo-Popups/Herzen mit echtem OpenGL-Renderer für die Sichtprüfung.
Headless-Tests allein belegen keine korrekte Darstellung.
Titel, Lobby, Arena, Shop und Optionen wurden mit OpenGL/llvmpipe gerendert
und visuell geprüft. Ein exportiertes PCK wurde aus `/tmp` ohne Zugriff auf
das Projektverzeichnis gestartet; Einstieg und drei Sekunden Spielsimulation
liefen erfolgreich. Vollständige Desktop-Binaries sind noch nicht geprüft.

Die aktuelle technische Ausführung mit Druckplatte, Datenchip und Schaltkreis-Boden
ist im [Elektronik-Update](TECH_UPDATE.md) beschrieben.
Punkte, Bewegungsgefühl und das neue Pausenmenü zeigt das
[Bewegungs- und UI-Update](FEEL_UPDATE.md).
Shopsuche ohne Weglinie und die neue Einstellungszentrale stehen im
[Options-Update](OPTIONS_UPDATE.md).
