# Contributing & Das Goldene Regelwerk (`EĹLA – Easy Layout & Location Assistant`)

Vielen Dank für dein Interesse, **EĹLA** (im Spiel **`Ella`**) für *World of Warcraft: Forever* (`Interface: 16001` / `WOW_PROJECT_CAMELOT`) zu erweitern oder zu pflegen!

---

## 1. Neues Fenster in 5 Zeilen ergänzen (Zero-Engine-Code)

Wenn ein neuer *WoW: Forever*-Patch ein weiteres Menüfenster einführt, musst du den Engine-Kern (`Core/`) **nicht** anfassen. Ergänze einfach einen deklarativen Eintrag in:
* `Data/Frames_Core.lua` (immer geladene Standardfenster),
* `Data/Frames_LoD.lua` (Blizzard Load-on-Demand-Module), oder
* `Data/Frames_Forever.lua` (*Forever*-exklusive Systeme wie Camping, Legacy, neue Fraktionen).

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

> **Tipp:** Im Spiel kannst du `/ella pick` eingeben und ein Fenster anklicken – Ella generiert dir automatisch den fertigen Lua-Block zum Kopieren!

Vor dem Erstellen eines Pull Requests bitte einmal den lokalen Validator starten:
```bash
python3 tests/validate_addon.py
```

---

## 2. Drittanbieter-API (`ELLA_API` / `LibStub`)

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

Unterstützte Methoden auf `ELLA_API`:
* `ELLA_API:GetVersion()` – Gibt Versionsstring und API-Level zurück.
* `ELLA_API:IsForeverClient()` – `true`, wenn auf `WOW_PROJECT_CAMELOT` (`18`) ausgeführt.
* `ELLA_API:RegisterWindow(windowId, descriptor)` – Registriert ein einzelnes Fenster.
* `ELLA_API:RegisterAddonWindows(addonName, windowsTable)` – Registriert mehrere Fenster eines Addons gesammelt.
* `ELLA_API:RegisterPreset(presetId, presetDefinition)` – Fügt ein eigenes Skalierungs-Preset hinzu.
* `ELLA_API:SetWindowScale(windowId, scale)` – Setzt die Skalierung (`0.50` – `1.50`) eines Fensters.
* `ELLA_API:GetWindowConfig(windowId)` – Liest eine sichere Kopie der aktuellen Fenstereinstellungen.
* `ELLA_API:RegisterCallback(eventName, callback)` – Lauscht auf `OnWindowRegistered`, `OnWindowBound`, `OnWindowApplied`, `OnWindowConfigChanged`, `OnPresetApplied`, `OnResetAll`.

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
2. **Edit-Mode-Quarantäne:** HUD- und Kampf-Frames (`PlayerFrame`, Actionbars, Minimap, Buffs, ObjectiveTracker, Chat) sind streng gesperrt.
3. **`UIPanelWindows` bleibt unberührt:** Niemals Felder in `UIPanelWindows` überschreiben oder löschen.
4. **Null Property-Injektion auf Blizzard-Frames:** Niemals `SomeBlizzardFrame.myProp = ...` schreiben oder Frame-Methoden direkt überschreiben (`hooksecurefunc` + Weak-Table in `Core/Engine.lua` nutzen!).
5. **Pflicht-Check `IsForbidden()`:** Vor jedem Frame-Zugriff über `Guard:IsForbidden(frame)` absichern.
6. **Null globale Leaks:** Jede `.lua`-Datei startet mit `local AddonName, ns = ...`. Keine unregistrierten globalen Variablen.
7. **Sicherheitsgrenzen:** Skalierung strikt auf `[0.50, 1.50]` begrenzt + Bildschirm-Clamping + `/ella reset` Notausgang.
8. **0,00 ms Ruhe-CPU:** Keine dauerhaften `OnUpdate`-Schleifen! `OnUpdate` darf ausschließlich während eines aktiven Maus-Ziehens oder aktiven Frame-Pickers laufen.
