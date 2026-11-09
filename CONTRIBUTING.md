# Contributing & Das Goldene Regelwerk (`EĹLA – Easy Layout & Location Assistant`)

Vielen Dank für dein Interesse, **EĹLA** (im Spiel **`Ella`**) für *World of Warcraft: Forever* (`Interface: 16001` / `WOW_PROJECT_CAMELOT`) zu erweitern oder zu pflegen!

---

## 1. Neues Fenster in 5 Zeilen ergänzen (Zero-Engine-Code)

Wenn ein neuer *WoW: Forever*-Patch ein weiteres Menüfenster einführt, musst du den Engine-Kern (`Core/`) **nicht** anfassen. Ergänze einfach einen deklarativen Eintrag in:
* `Data/Frames_Core.lua` (immer geladene Standardfenster),
* `Data/Frames_LoD.lua` (Blizzard Load-on-Demand-Module), oder
* `Data/Frames_Forever.lua` (*Forever*-exklusive Systeme wie Camping, Legacy, Fraktionen sowie Community-AddOns).

```lua
Registry:RegisterWindow("MEIN_NEUES_FENSTER", {
    addon = "Blizzard_NewForeverModule", -- Optional: Name des LoD-Moduls
    frame = "NewForeverFrame",           -- Oder candidates = { "FrameA", "FrameB" }
    labelKey = "WIN_NEW_FOREVER",        -- Schlüssel in Locales/enUS.lua & deDE.lua
    category = "CAT_FOREVER",
    defaultCompactScale = 0.82,
    protected = true,                    -- Auf true setzen, falls im Kampf geschützt
})
```

> **Tipp:** Im Spiel kannst du `/ella pick` eingeben und ein Fenster anklicken – Ella generiert dir automatisch den fertigen Lua-Block zum Markieren & Kopieren!

Vor dem Erstellen eines Pull Requests bitte einmal den lokalen Validator starten:
```bash
python3 tests/validate_addon.py
```

Die Lua-Verhaltenstests führen Originalmodule unter Lua 5.1 aus. Einmalig eine
Python-Umgebung außerhalb des Checkouts anlegen (damit sie nicht im Release-ZIP landet):
```bash
python3 -m venv /tmp/ella-tests-venv
/tmp/ella-tests-venv/bin/python -m pip install -r tests/requirements.txt
/tmp/ella-tests-venv/bin/python -m unittest discover -s tests -p 'test_*.py' -v
```
Die CI führt diese Tests einschließlich echter Lua-5.1-Syntaxprüfung aus.
Frame-Doubles prüfen die Programmlogik; Rendering, Fokus, Combat-Lockdown und
Taint müssen zusätzlich im tatsächlichen WoW-Client abgenommen werden.

---

## 2. Drittanbieter-API (`ELLA_API` / `_G.Ella` / `LibStub`)

Eigene Addons können ihre Fenster direkt an EĹLA übergeben, ohne eigene Drag-/Skalierungslogik zu programmieren:

```lua
local api = _G.ELLA_API or (LibStub and LibStub("ELLA-1.0", true))
if api then
    api:RegisterWindow("MYADDON_MAIN", {
        addon = "MyAddon",
        frame = "MyAddonMainFrame",
        label = "My Addon Window",
        defaultCompactScale = 0.85,
    })
end
```

Unterstützte Methoden auf `ELLA_API` (sowie Alias `_G.Ella` und `LibStub("ELLA-1.0")`):
* `ELLA_API:GetVersion()` – Gibt Versionsstring (`"1.9.1"`) und API-Level (`2`) zurück.
* `ELLA_API:IsForeverClient()` – `true`, wenn auf `WOW_PROJECT_CAMELOT` (`18`) ausgeführt.
* `ELLA_API:GetActiveProfile()` – Gibt den Namen des derzeit aktiven Layout-Profils zurück.
* `ELLA_API:GetProfiles()` – Gibt ein sortiertes Array aller vorhandenen Profilnamen zurück.
* `ELLA_API:SwitchProfile(profileName)` – Wechselt zum angegebenen Profil.
* `ELLA_API:RegisterWindow(windowId, descriptor)` – Registriert ein einzelnes Fenster.
* `ELLA_API:RegisterAddonWindows(addonName, windowsTable)` – Registriert mehrere Fenster eines Addons gesammelt.
* `ELLA_API:RegisterPreset(presetId, presetDefinition)` – Fügt ein eigenes Skalierungs-Preset hinzu.
* `ELLA_API:ApplyPreset(presetId)` – Wendet ein registriertes Preset (`"STANDARD_100"`, `"CLASSIC_80"`, `"WQHD_85"`, `"LAPTOP_72"`, ...) an.
* `ELLA_API:SetWindowScale(windowId, scale)` – Setzt die Skalierung (`0.50` – `1.50`) eines Fensters.
* `ELLA_API:SetWindowAlpha(windowId, alpha, mouseoverFade)` – Setzt Deckkraft (`0.30` – `1.00`) und optionales Mouseover-Fade eines Fensters.
* `ELLA_API:SetWindowEnabled(windowId, enabled)` – Aktiviert/deaktiviert die Verwaltung. Liefert `true`, wenn die Konfiguration angenommen wurde, oder `false, "unknown_window"` bei unbekannter ID. Geschützte Frame-Änderungen können bis nach dem Kampf warten.
* `ELLA_API:SetWindowBadgeHidden(windowId, hidden)` – Blendet das Fenster-Badge aus/ein. Liefert `true` oder bei unbekannter ID `false, "unknown_window"`.
* `ELLA_API:GetWindowConfig(windowId)` – Liest eine sichere Kopie der aktuellen Fenstereinstellungen (`scale`, `mode`, `locked`, `alpha`, `mouseoverFade`, `uipX`, `uipY`).
* `ELLA_API:ToggleManager()` – Öffnet oder schließt den Ella-Fenstermanager (`/ella`).
* `ELLA_API:ToggleBossKey()` – Führt den Boss-Key (Panik-Schließen / Wiederherstellen) aus.
* `ELLA_API:ToggleGrid()` – Schaltet das Vollbild-Ausrichtungsgitter ein oder aus (mit Chat-Bestätigung).
* `ELLA_API:RegisterCallback(eventName, callback)` – Lauscht auf `OnWindowRegistered`, `OnWindowBound`, `OnWindowApplied`, `OnWindowConfigChanged`, `OnPresetApplied`, `OnProfileSwitched`, `OnProfileImported`, `OnResetAll`, `OnCharProfileBindingChanged`.

---

## 3. Das Goldene Regelwerk (Pflicht für jeden Pull Request)

Jeder Commit wird automatisiert gegen diese Regeln geprüft (`python3 tests/validate_addon.py` & `luacheck`):

### Teil A – Blizzard Add-On Development Policy
1. **100 % Kostenlos & Frei:** Keine Paywalls, Lizenzschlüssel, „Pro“-Presets oder In-Game-Spenden-Popups.
2. **Klartext-Code:** Keine Code-Verschleierung (Obfuscation).
3. **Reine Sandbox:** Keine externen Executables oder Speicher-Manipulationen.
4. **Respekt vor Kampf-Sandbox & Secret Values:** Keine Auswertung von `issecretvalue()`-Kampfdaten und keinerlei Gameplay-Automatisierung.

### Teil B – Die 8 Technischen Anti-Taint-Gesetze
1. **Kampf-Schutz (`InCombatLockdown()`):** Niemals `SetScale`, `SetPoint` oder `ClearAllPoints` während des Kampfes auf `Protected`-Frames aufrufen – immer über `Guard:CanModifyNow()` & `Guard:EnqueueAfterCombat()` leiten.
2. **Edit-Mode-Quarantäne:** HUD- und Kampf-Frames (`PlayerFrame`, Actionbars, Minimap, Buffs, ObjectiveTracker, `RightManagedFrameContainer`, Chat) und ihre Unterframes sind streng gesperrt (`Guard:ValidateTarget`). `UIParent` ist als normaler Vorfahr zulässig, als direktes Ziel gesperrt.
3. **`UIPanelWindows` bleibt unberührt:** Niemals Felder in `UIPanelWindows` überschreiben oder löschen.
4. **Null Property-Injektion auf Blizzard-Frames:** Niemals `SomeBlizzardFrame.myProp = ...` schreiben oder Frame-Methoden direkt überschreiben (`hooksecurefunc` + Weak-Table in `Core/Engine.lua` nutzen!).
5. **Pflicht-Check `IsForbidden()`:** Vor jedem Frame-Zugriff über `Guard:IsForbidden(frame)` absichern.
6. **Null globale Leaks:** Jede `.lua`-Datei startet mit `local AddonName, ns = ...`. Nur dokumentierte Globals (`ELLA_API`, `Ella`, `ELLADB`, `BINDING_*`) sind erlaubt.
7. **Sicherheitsgrenzen:** Skalierung strikt auf `[0.50, 1.50]` und Deckkraft auf `[0.30, 1.00]` begrenzt + Bildschirm-Clamping + `/ella reset` Notausgang.
8. **0,00 ms Ruhe-CPU:** Keine dauerhaften `OnUpdate`-Schleifen! `OnUpdate` darf ausschließlich während eines aktiven Maus-Ziehens, aktiven Mouseover-Fade-Hovers oder aktiven Frame-Pickers laufen. Die Strg-Mausrad-Zielsuche darf während gedrückter Strg-Taste bei aktivierter Funktion mit maximal 20 Prüfungen pro Sekunde laufen.

---

## 4. Feature- & Release-Checkliste (Tutorial- & Locale-Pflege)

Wann immer ein neues Core-Feature oder sichtbares UI-Element ergänzt wird:
1. **Tutorial-Synchronisation (`UI/Tutorial.lua`):**
   * Prüfe alle **13 Schritte** des interaktiven In-Game-Tutorials (`/ella tour`).
   * Müssen Erklärungen in `Locales/deDE.lua` & `Locales/enUS.lua` aktualisiert werden?
   * Passen die Spotlight-Rahmen (`STEPS[x].getTarget`) und Reiter-Sprünge (`STEPS[x].tab`) noch zu den Bedienelementen?
2. **Lokalisierungs-, Format- & Schriftart-Sicherheit:**
   * Jeder Text-Key und alle `string.format`-Platzhalter (`%s`, `%d`, `%%`) müssen in `Locales/enUS.lua` und `Locales/deDE.lua` exakt übereinstimmen.
   * Alle sichtbaren Zeichen müssen im `cp1252`-Zeichensatz von Blizzards `Friz Quadrata`-Schriftart enthalten sein (echte deutsche Umlaute `ä/ö/ü/ß` verwenden, keine `ae/oe/ue`-Ersatzschreibweisen).
3. **Automatisierte Validierung:**
   * `python3 tests/validate_addon.py` prüft `ELLA.toc`, `Bindings.xml` (`category="ADDONS"`), Locale-Parität, Format-Strings, `cp1252`-Glyphen und alle Goldenen Regeln und muss vor jedem Git-Tag 100 % grün sein.
