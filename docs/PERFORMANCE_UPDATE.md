# Performance-Analyse ohne weniger Spielobjekte

## Gefundene Ursachen

Die stärksten gemessenen Kosten lagen in der CPU-Simulation:

- Jeder Gegner prüfte seine Abstände zu sämtlichen anderen Gegnern.
- Jedes Spielergeschoss kopierte die Gegnerliste und prüfte jeden Gegner sowie
  alle zerstörbaren Objekte.
- Bewegung, Geschosse und Sichtlinien durchliefen immer sämtliche Wände und
  Monumentsegmente, auch wenn diese weit entfernt lagen.
- Mehrere Gegner suchten dieselben navigierbaren Zielzellen und Wege erneut.
- Jeder kurze Soundeffekt wurde beim Abspielen aus einzelnen Samples neu erzeugt.

HUD und Kartenaufdeckung waren im gemessenen Szenario vergleichsweise günstig.
Die steigende Spawnmenge verstärkte die Kosten der Vollsuchen zusätzlich.

## Änderungen an der Berechnung

Räumliche Indizes teilen die Welt in Zellen von 128 Einheiten. Die Simulation
prüft zunächst nur potenziell passende Gegner, Geschosse, Objekte und Wände.
Danach gelten dieselben genauen Kollisions- und Trefferregeln. Trefferkandidaten
werden in der bisherigen Reihenfolge verarbeitet; neu erzeugte Gegner kommen
sofort in den Index. Bei sehr langen Suchbereichen verhindert eine alternative
Vollsuche unnötige Besuche tausender leerer Zellen.

Bei Gegnerkontakten werden die für den gesamten Schritt relevanten Wandkandidaten
einmal bestimmt und wiederverwendet. Ein konservativer Bewegungsbereich erfasst
auch Nachbarn, die erst durch eine vorherige Verschiebung relevant werden.
Das vermeidet wiederholte räumliche Suchen innerhalb dicht gedrängter Gruppen.

Statische Geometrie wird nur bei tatsächlichen Änderungen neu indiziert.
Zielzellen und identische A*-Wege werden innerhalb eines Simulationsschritts
geteilt. Jeder Gegner erhält eine eigene bearbeitbare Kopie seines Weges,
damit das Entfernen bereits erreichter Wegpunkte andere Gegner nicht beeinflusst.

Alle sieben Effekt-Wellenformen werden einmal vorbereitet. Die acht vorhandenen
Audiostimmen verwenden diese Ressourcen weiter; Lautstärke, Soundauswahl und
gleichzeitige Stimmen bleiben erhalten.

Für diese Optimierung wurden **keine Objektgrenzen gesenkt**, Grafikdetails
reduziert oder Gegner außerhalb des Bildes aus der Simulation genommen.
Gegner, Geschosse, Wände, Sammelobjekte und Effekte bleiben erhalten.

## Messung mit denselben Objektzahlen

Godot 4.6.3, Headless-CPU-Test auf derselben Cloud-Umgebung, deterministischer
Seed 20261105. Ausgangspunkt ist Commit
`6871ffae29c3a61374b6ba47692b3fd87bce28e7`.
Jeder gemessene Simulationsschritt beginnt mit denselben **160 Gegnern,
200 Spieler- und 200 Gegnergeschossen, 400 Sammelobjekten, 64 Wänden und
sechs Monumentsegmenten**. Der Zustand wird vor jeder Wiederholung zurückgesetzt;
dieser Testaufbau gehört nicht zur gemessenen Zeit. Nach drei Aufwärmläufen
folgen 40 Wiederholungen. Die Messung der Soundeffekte verwendet zehn Wiederholungen.
Die Sammelobjekte sind Herzen, damit automatisches Verschmelzen von Punkten
die Objektzahl im Vergleich nicht verändert.

| Berechnung | Vorher, Median | Nachher, Median |
| --- | --- | --- |
| Vollständiger Simulationsschritt | 70,616 ms | 8,634 ms |
| Gegnerbewegung und Kontakte | 33,362 ms | 5,670 ms |
| 200 Spielergeschosse | 33,791 ms | 1,458 ms |
| 200 Gegnergeschosse | 4,514 ms | 0,660 ms |
| 160 Sichtlinien | 5,942 ms | 0,467 ms |
| 400 Wand-Kollisionsabfragen | 8,737 ms | 0,921 ms |
| 20 Soundereignisse | 7,112 ms | 0,092 ms |

Das entspricht rund **88% weniger Zeit für den Simulationsschritt**.
Sein 95. Perzentil sank von **80,899 auf 9,876 ms**. Die Teilmessungen sind
separate Versuche und werden nicht zur Gesamtdauer addiert.

Ein zusätzlicher künstlicher Extremfall setzt 160 Gegner in ein etwa 32×20
Einheiten kleines Gebiet. Für deren isolierte Bewegung benötigt die Vollsuche
als Referenz im aktuellen Build 426,119 ms, die indizierte Suche 55,658 ms
im Median. Auch dieser Grenzfall bleibt also teuer, wird aber deutlich günstiger,
ohne Gegner zu entfernen. Dieser Vergleich umfasst nicht den gesamten Frame.

Rohdaten: [Ausgangsstand](performance/before.json),
[optimierter Stand samt Extremfall](performance/after.json).

Die Zahlen messen CPU-Rechenzeit, nicht die komplette sichtbare Bildrate.
Grafikkarte, Auflösung, Gerät und konkrete Spielszene beeinflussen die FPS
weiterhin. Es handelt sich nicht um eine Garantie für jedes Gerät.

## Angepasste Balance

Unabhängig von der Berechnungsoptimierung wurde die gewünschte Eskalation geändert:

- Die Gegner spawnen während der Shopsuche weiter.
- Anzahl pro Spawn und Spawnintervall werden durch die Eskalation nicht mehr vervielfacht.
- Sofort bei Shop-Aktivierung und danach alle 7,5 Sekunden: **HP ×1,5**.
- Das Tempo wächst standardmäßig linear um **3% des Basistempos je Stufe**,
  maximal +60%. Bestehende und neue normale Gegner verwenden denselben Faktor.
- Schaden bleibt beim HP-Wachstum anteilig erhalten. Eine neue Welle setzt
  die Eskalation zurück; Pause und Shop-Menü halten sie an.

Der neue Tempo-Regler ergänzt die Schwierigkeitseinstellungen. Es gibt nun
61 Einstellungen plus sechs Tastenbelegungen. Die bestehenden Gegnergrenzen
und übrigen Objektlimits bleiben unverändert. Die Vergleichsmessung oben
verwendet ausdrücklich dieselben hohen Objektzahlen und profitiert daher
nicht von der veränderten Spawn-Balance.

## Nachprüfen

```sh
python3 tests/run.py
godot --headless --path . --script tests/performance.gd -- /tmp/prism-performance.json
```

**234 Checks bestanden**, ohne Engine- oder Scriptfehler. Die neuen 20 Checks
vergleichen unter anderem 1.600 Kollisionsproben plus Monumentecken, 1.000
Sichtlinien, acht Bewegungsschritte mit 80 überlappenden Gegnern, Geschoss-
und Kistentreffer sowie gemeinsam berechnete Wege mit den bisherigen Regeln.
Sound-Wiederverwendung, unveränderte Audiostimmen und die neue Eskalation
werden ebenfalls geprüft. Darstellung und exportiertes Ressourcenpaket wurden
zusätzlich kontrolliert.
