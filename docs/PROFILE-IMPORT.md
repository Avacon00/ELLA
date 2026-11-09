# Profilimport

Vorschau (`InspectImportString`) und Übernahme (`ImportString`) verwenden denselben
Parser in `Core/Profiles.lua`. Die gesamte Eingabe wird geprüft, bevor Ella eine
Konfiguration erstellt, einen Undo-Schritt anlegt oder Frames neu anwendet.

## Unterstützte Formate

Aktuelle Exporte haben die Form:

```text
!ELLA:v2:Profilname;CHARACTER=80,M,0,120,-80,70,1,0
```

Gültige Header sind `!ELLA:v2:Name`, `ELLA2:Name`, `!ELLA:v2`, `ELLA2`, `ELLA1`
und `FSCALE1`. Andere Versionsnummern oder bloße passende Präfixe werden abgewiesen.
Ein vorhandener Profilname darf keine Steuerzeichen, Doppelpunkte oder Semikolons
enthalten; UTF-8-Namen bleiben erhalten. Äußerer Leerraum wird entfernt, zählt
aber zur Größenbegrenzung. Der Name dient der Vorschau; der Import ändert die
Fenstereinstellungen im **aktiven** Profil.

| Feld | Bedeutung |
| --- | --- |
| Fenster-ID | Buchstaben/Ziffern, Unterstrich, Bindestrich oder Punkt |
| 1 | Skalierung als ganzzahliger Prozentwert |
| 2 | `M` = Skalieren/Bewegen, `S` = Nur Skalieren, `D` = Aus |
| 3 | Drag-Sperre: `0` oder `1` |
| 4 und 5 | X/Y in UIParent-Koordinaten; beide leer löscht die gespeicherte Position |
| 6, optional | Deckkraft als ganzzahliger Prozentwert |
| 7, optional | Mouseover-Fade: `0` oder `1` |
| 8, optional | Badge ausblenden: `0` oder `1` |

Die ersten fünf Felder sind erforderlich. Fehlende oder leere optionale Felder
behalten den bisherigen Wert bei. Damit bleiben alte Exporte ohne Alpha/Fade/
Badge-Feld unterstützt. Ein Abschluss direkt nach Feld 5, 6 oder 7 kann deshalb
ein gültiger älterer Code sein. Abgeschnittene Pflichtfelder werden abgewiesen.

Koordinaten akzeptieren Dezimalzahlen mit optionalem Minuszeichen, z. B. `-80`,
`12.5`, `-.5` oder `1.`. Exponenten, Pluszeichen, NaN, Unendlich und fehlerhafte
Zahlen wie `--1` oder `.` werden abgewiesen. Skalierung und Deckkraft behalten
ihre bisherigen Clamp-Regeln: `50–150 %` und `30–100 %`.

## Grenzen und unbekannte Fenster

- Höchstens **65 536 Bytes** vor dem Entfernen äußeren Leerraums (64 KiB).
- Höchstens **1024 Einträge** nach dem Header, einschließlich unbekannter IDs.
- Beide Positionswerte müssen endlich sein und jeweils innerhalb von
  **−1 000 000 bis +1 000 000** UIParent-Einheiten liegen. Der übliche
  Bildschirm-Clamp wird zusätzlich angewendet, wenn er eingeschaltet ist.
- Jede ID darf nur einmal vorkommen. Leere Tokens, zusätzliche Felder oder
  ein abschließendes Semikolon sind Fehler.

Die Grenzen liegen deutlich über dem Umfang der mitgelieferten Fensterliste.
Unbekannte IDs können zu einem anderen Client oder Addon gehören: Ihre Syntax
und Werte werden ebenfalls geprüft, dann werden sie übersprungen. Es entstehen
keine neuen Fensterregistrierungen. Mindestens ein bekanntes Fenster muss
enthalten sein. Ein leerer Export oder ausschließlich unbekannte Fenster liefern
eine entsprechende Meldung und verändern nichts.

## Ergebnisse und Fehler

`ImportString(raw)` liefert bei Erfolg `true, lokalisierteMeldung`. Jeder
erfolgreiche Import erhält einen eigenen Undo-Schritt. Bei einem Prüfungsfehler
lautet das Ergebnis `false, lokalisierteMeldung, fehlercode`.

`InspectImportString(raw)` liefert weiterhin
`gültig, anzahl, namensübersicht, profilname` und bei Fehlern zusätzlich den Code
als fünften Rückgabewert. Die Vorschau verändert weder Datenbank noch Undo.

| Fehlercode | Bedeutung |
| --- | --- |
| `invalid_type` | Eingabe ist kein String |
| `too_large` | Bytegrenze überschritten |
| `invalid_header` | Unbekanntes oder fehlerhaftes Headerformat |
| `too_many_entries` | Eintragsgrenze überschritten |
| `invalid_entry` | Pflichtfelder, Modus, Flags oder Tokenstruktur ungültig |
| `invalid_number` | Skalierung/Deckkraft ungültig oder nicht endlich |
| `invalid_position` | Position unvollständig, ungültig oder außerhalb der Grenze |
| `duplicate_window` | ID mehrfach vorhanden |
| `no_known_windows` | Keine importierbaren Fenstereinstellungen |

Bei Prüfungsfehlern bleiben Konfigurationen, aktive Preset-Markierung, Undo und
Events unverändert. Nach erfolgreicher Prüfung werden alle bekannten Einträge
übernommen, das aktive Preset zurückgesetzt und die sichtbaren Fenster neu
angewendet. Es wird kein Lua-Code aus dem Profilstring ausgeführt.

`tests/test_import.py` prüft echte Modulaufrufe in Lua 5.1, einschließlich exakter
Grenzen, Überläufen, Fehlern nach einem gültigen Eintrag, älteren Formaten,
UTF-8-Roundtrip, unbekannten IDs und Undo. Native UI-Darstellung und Einfügen über
die WoW-Zwischenablage sind zusätzlich im Client zu prüfen.
