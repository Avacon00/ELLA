# SavedVariables und Migrationen

Ella speichert weiterhin **Schema 2** in `ELLADB`. Die Addon-Version und das
Datenbankschema sind unabhängig. Die zusätzliche Reparaturhistorie ist optional
und erfordert keine Änderung der bestehenden Profilstruktur.

| Feld | Invariante nach erfolgreichem Start |
| --- | --- |
| `schemaVersion` | Ganzzahl `2` |
| `settings` | Tabelle; bekannte Felder besitzen ihren erwarteten Typ |
| `profiles` | Nichtleere Profilnamen als String, Werte als Profiltabelle; `Default` existiert |
| `profiles[name].windows` | Tabelle mit Fenster-IDs und Konfigurationstabellen |
| `profiles[name].savedSnapshot` | Unabhängige Konfigurationstabelle; fehlt sie, wird der aktuelle Stand kopiert |
| `activeProfile` | Name eines vorhandenen Profils |
| `windows` | Referenz auf `profiles[activeProfile].windows`, keine zweite Datenquelle |
| `customWindows` | Framepfad als String, Metadaten als Tabelle, optionaler String `label` |
| `charProfiles` | Charaktername als String, Wert als vorhandener Profilname |

Fensterskalierung liegt zwischen `0.5` und `1.5`, Alpha zwischen `0.3` und `1`.
Optionale Modi sind `SCALE_AND_MOVE`, `SCALE_ONLY` und `DISABLED`.
Positionen benötigen zwei endliche Zahlen mit jeweils höchstens `1 000 000`
UIParent-Einheiten als Absolutwert. Ungültige Positionen werden vollständig
entfernt, sodass der native Anker verwendet wird. Der Bildschirm-Clamp bleibt
zusätzlich aktiv, wenn der Nutzer ihn eingeschaltet hat. Fehlende optionale
Konfigurationsfelder verwenden weiterhin die fensterspezifischen Standardwerte.

Managergrenzen entsprechen der UI: Skalierung `0.6–1.4`, Breite `720–1080`, Höhe
`440–860`. Die bestehende Anpassung an Version 1.10 (mindestens `760×620`) läuft
einmal über `widthMigratedV110`; spätere gültige Größen bleiben erhalten.

## Migrationspipeline

`Core/Database.lua` enthält `Database.schemaVersion` und `Database.migrations`.
Der Eintrag mit Schlüssel `n` migriert von `n` nach `n+1`.

1. Fehlende oder ungültige Versionsangaben werden als Legacy-Schema 1 behandelt;
   ein vorhandener ungültiger Wert wird gesichert.
2. Migrationen arbeiten auf einer tiefen Kopie. `1 → 2` übernimmt Legacy-`windows`
   in `Default` und ergänzt `Laptop / Deck`, wenn noch keine Profiltabelle existiert.
3. Jede erfolgreiche Stufe erhöht die Versionsnummer. Erst nach der gesamten
   Kette und Normalisierung wird das Ergebnis als `ELLADB` übernommen.
4. Vor einer künftigen Strukturänderung: `migrations[2]` für `2 → 3` ergänzen,
   `schemaVersion` auf `3` erhöhen und Fixtures für beide Ausgangsversionen testen.
   Leere Platzhaltermigrationen und ein Versionssprung ohne Strukturänderung
   sind nicht nötig.

Eine fehlende oder fehlschlagende Stufe verwirft die Arbeitskopie. `ELLADB` bleibt
erhalten. Ella verwendet für diese Sitzung einen inaktiven Ersatzdatenbestand.
`ns.databaseStatus` liefert `migration_failed`, die Ausgangsversion und den
Fehlertext. Eine unbekannte neuere Version erhält `unsupported_schema`; sie wird
ebenfalls nie heruntergestuft oder überschrieben. Einstellungen in diesen
Ersatzdatenbeständen werden nicht gespeichert. Im Chat erscheint ein lokalisierter
Hinweis. Diagnosezustand und Fehlertext werden nicht extern gesendet.

## Reparatur und Sicherung

Nach der Migration werden **alle** Profile und Checkpoints normalisiert, bevor
`db.windows` an das aktive Profil gebunden wird. Gültige Tabellen, unbekannte
Zusatzfelder und Profile bleiben erhalten. Bei einem beschädigten aktiven Profil
kann eine noch gültige Legacy-Referenz `db.windows` als Quelle dienen; ein sonst
überschriebener separater Legacy-Datenbestand wird gesichert.

Vor jeder Änderung eines ungültigen vorhandenen Werts wird eine tiefe Kopie in
`ELLADB.recovery.entries[path]` gespeichert:

```lua
ELLADB.recovery.entries['profiles["Raid"].windows["CHARACTER"].pos'] = {
    value = { uipX = "ungültig", uipY = -80 },
    reason = "invalid_position",
}
```

Der erste gesicherte Wert eines Pfads bleibt erhalten; wiederholtes Initialisieren
verdoppelt keine Einträge. Fehlerhafte alte Recovery-Metadaten bleiben unter
`recovery.previous` erhalten. Fehlende Standardwerte allein erzeugen keine
Sicherung. Der Chat meldet die Anzahl neu gesicherter Werte.

Die Sicherung dient der manuellen Wiederherstellung nach Prüfung. Es gibt keinen
automatischen Rückimport ungültiger Daten. Vor einer manuellen Bearbeitung des
SavedVariables-Files WoW beenden und eine Dateikopie anlegen.

Die Tests `tests/test_database.py` laden Lua-Fixtures für Schema 1, Schema 2 und
beschädigte Daten in einer echten Lua-5.1-Runtime. Sie prüfen unter anderem
Migration, Aliasbindung, Checkpoints, Positionsgrenzen, Wiederholung, Rollback
bei einem absichtlich fehlschlagenden Migrationsschritt und den Schutz neuerer
Schemas. Das native Speichern und Laden durch den WoW-Client bleibt ein
In-Game-Prüfpunkt.
