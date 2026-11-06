# EĹLA (`Ella`) – Easy Layout & Location Assistant

<p align="center">
  <img src="assets/ella-banner.png" alt="EĹLA – Easy Layout & Location Assistant Hero Banner" width="840" />
</p>

> **Per-Window UI Scaler & Position Memory for *World of Warcraft: Forever* (`Interface: 16001` / `Project Camelot`)**

![Version 1.8.0](https://img.shields.io/badge/Version-v1.8.0-ffaa00)
![Interface 16001](https://img.shields.io/badge/WoW_Forever-Interface_16001-00ccff)
![Project Camelot](https://img.shields.io/badge/GameType-camelot-ffd100)
![Zero Taint](https://img.shields.io/badge/Architecture-Zero_Taint-00ff96)
![License MIT](https://img.shields.io/badge/License-MIT-blue)

**EĹLA** (**E**asy **L**ayout & **L**ocation **A**ssistant — im Spiel aufgrund von Blizzards `Friz Quadrata`-Schriftart sauber als **`Ella`** dargestellt) löst eines der größten UI-Probleme in **World of Warcraft: Forever**: Moderne Retail-Menüfenster (Berufe, Zauberbuch, Questlog, Auktionshaus, Ruf) wirken überdimensioniert, während die globale UI-Skalierung sofort auch Chat, Tooltips und Aktionsleisten unleserlich klein macht.

---

## Deutsch (Übersicht & Bedienung)

### Highlights
* **Audio- & Haptisches Feedback (`v1.8.0`):** Native Blizzard-Soundeffekte beim magnetischen Einrasten (Snap-Sound), Boss-Key, Profil- und Preset-Wechsel. Vollständig abschaltbar unter *Einstellungen*.
* **Dynamische Echtzeit-Filterzähler (`v1.8.0`):** Die Kategorie-Tabs im Manager zeigen nun in Echtzeit an, wie viele Fenster gerade offen sind (`Offen (2)`) bzw. wie viele benutzerdefinierte Fenster existieren (`Custom (1)`).
* **Minimap-Schnellauswahl & Shift+Klick (`v1.7.3`):** Eigenständiges, ausfallsicheres Popover direkt an der Minimap mit Profil-Schnellwechsler, 1-Klick-Presets und Schnellstartern (Picker, Gitter, Tutorial). Halte `Shift` gedrückt und klicke auf das Icon, um sofort zum nächsten Profil durchzuschalten!
* **Erweitertes 13-Schritte Onboarding-Tutorial (`v1.7.2`):** Vollständig ausgebaute, geführte Tour (`/ella tour`) mit automatischer Reiter-Navigation und Scheinwerfer-Spotlight über alle 3 Hauptbereiche.
* **Entzerrte 3-Reiter-Benutzeroberfläche (`v1.7.1`):** Übersichtliche Aufteilung des Managers in *Fenster & Skalierung*, *Einstellungen* und *Profile & Vorlagen* mit über 120px mehr vertikalem Platz (12–14 Fensterzeilen gleichzeitig ohne Scrollen sichtbar).
* **Screen-Grid Overlay (`v1.7.0`):** Schalte per Klick auf `[# Gitter]` im Manager oder per `/ella grid` ein dezentes Vollbild-Ausrichtungsgitter mit leuchtendem Zentrum-Kreuz (Cyan), Drittel-Achsen (Gold) und 32px-Raster ein, um dein Interface symmetrisch wie ein Profi-Streamer einzurichten.
* **Profil-Sharing 2.0 mit Live-Vorschau (`v1.7.0`):** Teile deine Layouts blitzschnell via `!ELLA:v2:`-Codes. Beim Einfügen analysiert Ella den String sofort und zeigt eine Infobox mit Profilnamen und enthaltenen Fenstern an, bevor du ihn übernimmst.
* **Boss-Key & Panik-Aktion (`v1.7.0`):** Ein einziger Tastendruck schließt alle aktuell offenen Fenster blitzschnell – ein zweiter Tastendruck stellt genau dieselben Fenster wieder an Ort und Stelle her! Frei belegbar in Blizzards Menü (*Tastenbelegung* -> *Ella*) oder per `/ella panic`.
* **Kampf- & Instanz-Schutz (`v1.6`):**
  * *Auto-Close im Kampf:* Schließt ungeschützte Menüs, Zauberbuch und Berufsfenster beim Kampfeintritt (`PLAYER_REGEN_DISABLED`) sofort automatisch.
  * *Instanz-Kompaktmodus:* Schaltet in Dungeons, Raids und PvP-Instanzen automatisch auf maximal 75 % Skalierung um. Beim Verlassen wird deine Wunschskalierung nahtlos wiederhergestellt.
* **Synchrones Fenster-Docking & Sticky Windows (`v1.6`):**
  * Aneinanderliegende oder bündige Fensterkanten ($\le 16\text{ px}$) docken automatisch aneinander an.
  * Beim Verschieben eines Fensters bewegt sich der gesamte Verbund synchron mit!
  * Halte `[Alt]` beim Ziehen gedrückt, um ein Fenster einzeln aus der Gruppe zu lösen.
* **Vor-Registrierte Community-AddOns (`v1.6`):**
  * Vorkonfigurierte Unterstützung für *Details! Damage Meter*, *Questie*, *Bagnon / Baganator*, *ThreatClassic2*, *TomTom*, *WeakAuras*, *Auctionator*, *AtlasLoot* und *Postal*.
  * Völlig ruhend (0,00 ms CPU, 0 Bytes RAM) wenn das AddOn nicht installiert ist; sofort aktiv und skaliert, sobald es geladen wird!
* **Fenster-Picker 2.0 (`v1.5`):** Visuelle Drittanbieter-Erkennung mit Live Hover-Highlighter, schwebendem Cursor-HUD und innovativer **Mausrad-Hierarchie-Navigation** (`Child` <-> `Parent`), um verschachtelte AddOns zielsicher aufzunehmen.
* **Fenster-Deckkraft & Mouseover-Fade (`v1.4`):** Passe die Transparenz jedes Fensters stufenlos (30%–100%) an. Mit *Mouseover-Fade* bleiben Fenster dezent durchscheinend, bis du mit der Maus darüberfährst – dann schalten sie sofort auf 100% Sichtbarkeit (0,00 ms Leerlauf-CPU).
* **Charakter-gebundene Profile & Handheld-Erkennung (`v1.4`):** Binde Layout-Profile direkt an deine Charaktere. Auf kompakten Displays wie dem Steam Deck (<= 1400x800) schlägt Ella automatisch das handliche 72%-Preset vor.
* **Einzel-Fenster-Skalierung (`50 %` – `150 %`):** Skaliere jedes Blizzard- und *WoW: Forever*-Fenster individuell über das dezente `%`-Badge in der Titelleiste, per `Strg + Mausrad` oder im `/ella`-Manager.
* **Benannte Layout-Profile (`v1.1`):** Wechsle per Klick im `/ella`-Manager oder per `/ella profile <Name>` blitzschnell zwischen verschiedenen Setups (z. B. `Default`, `Laptop / Deck`, `Raid`, `Twink`).
* **Magnetisches Einrasten & Live-Hilfslinien (`v1.1`):** Beim Ziehen richten sich Fenster sanft an der Bildschirmmitte sowie an Oberkanten und Seiten anderer offener Fenster aus (inklusive leuchtender Cyan-Hilfslinien, `Shift` = `10px`-Raster und optionaler Halbtransparenz beim Verschieben).
* **Begleitfenster-Synchronisation (`v1.1`):** Verknüpfte Unter- und Begleitfenster (z. B. `QuestLogPopupDetailFrame`, `TokenFramePopup`, `ProfessionsCustomerOrdersFrame`, `MacroPopupFrame`) übernehmen automatisch die Skalierung ihres Hauptfensters.
* **Cursor-Pivot-Zoom:** Beim Scrollen mit dem Mausrad bleibt der Punkt direkt unter deinem Mauszeiger pixelgenau an Ort und Stelle – kein Wegspringen von Fenstern.
* **„Nur Skalieren“-Modus (`Scale Only`):** Du magst es, dass WoW Charakterfenster und Händler automatisch ordentlich nebeneinander anordnet, findest die Fenster aber zu klobig? Im *Nur Skalieren*-Modus bleibt Blizzards Auto-Anordnung aktiv, öffnet aber jedes Fenster in deiner kompakten Wunschgröße.
* **1-Klick-Presets:** Sofort startklar mit **Classic Kompakt (80 %)**, **WQHD / 4K (85 %)** oder **Laptop / Deck (72 %)**.
* **Eigenes Addon-Icon (`Media/Icon.tga`):** Eigene handgefertigte Kompass-Anker-Grafik in der WoW-Addon-Liste, im Minimap-`AddonCompartment` und im Manager.
* **100 % Taint-frei & Edit-Mode-sicher:** Ignoriert konsequent alle HUD- und Kampfelemente aus Blizzards `EditModeManagerFrame`, reiht geschützte Fenster im Kampf sicher in eine Warteschlange ein (`InCombatLockdown()`) und verursacht **0,00 ms CPU-Last im Ruhezustand**.
* **In-Game Frame-Inspektor (`/ella pick`):** Nimm unbekannte Drittanbieter-Fenster per Mausklick auf – inklusive fertigem Lua-Code-Generator für GitHub-Beiträge.

### Chat-Befehle
| Befehl | Funktion |
| :--- | :--- |
| `/ella` | Öffnet bzw. schließt den durchsuchbaren **Ella Fenster-Manager** |
| `/ella tour` | Startet das interaktive **Schritt-für-Schritt-Tutorial** |
| `/ella grid` | Schaltet das **Vollbild-Ausrichtungsgitter** ein oder aus |
| `/ella panic` | **Boss-Key:** Schließt alle offenen Fenster oder stellt sie wieder her |
| `/ella profile <Name>` | Wechselt zum angegebenen Layout-Profil (ohne Namen: nächstes Profil durchschalten) |
| `/ella compact` | Aktiviert sofort das **Classic Kompakt (80 %)**-Preset |
| `/ella pick` | Startet den interaktiven **Frame-Inspektor** für Drittanbieter-Fenster |
| `/ella badges` | Blendet die `%`-Badges in den Fenstertitelleisten ein oder aus |
| `/ella reset` | Setzt alle Fensterskalierungen und Positionen auf `100 %` zurück |

---

## English (Overview & Usage)

### Key Features
* **Audio Feedback & Sound Engine (`v1.8.0`):** Native Blizzard sound effects for magnetic edge snapping, boss-key panics, profile cycling, and grid toggling. Fully toggleable in Settings.
* **Dynamic Real-Time Category Counters (`v1.8.0`):** Live counts on manager category pills (`Open (2)`, `Custom (1)`) with zero-latency event updates.
* **Minimap Quick Menu & Shift+Click Cycle (`v1.7.3`):** Native, zero-taint popover anchored to the Minimap button for quick profile switching, 1-click presets, and tool launchers (picker, grid, tutorial). Hold `Shift` and click the icon to instantly cycle through profiles!
* **Expanded 13-Step Onboarding Tutorial (`v1.7.2`):** Comprehensive guided interactive walkthrough (`/ella tour`) featuring automatic tab switching and spotlighting across all 3 main areas.
* **De-Cluttered 3-Tab Architecture (`v1.7.1`):** Clean separation into *Windows & Scale*, *Settings*, and *Profiles & Presets* with >120px more vertical height for up to 14 rows visible simultaneously.
* **Screen-Grid Overlay (`v1.7.0`):** Toggle a full-screen alignment grid (`[# Grid]` button or `/ella grid`) featuring a glowing cyan center crosshair, golden rule-of-thirds lines, and 32px precision grid lines to align your UI like a professional streamer.
* **Profile-Sharing 2.0 with Live Preview (`v1.7.0`):** Share your window layouts with friends via `!ELLA:v2:` string codes. Pasting a string instantly previews the profile name and configured windows before importing.
* **Boss-Key & Panic Restore (`v1.7.0`):** Instantly closes all open windows on a single key press, and pressing it again restores exactly those same windows. Bindable via standard WoW Keybindings (`Options` -> `Keybindings` -> `Ella`) or `/ella panic`.
* **Combat & Instance Protection (`v1.6`):**
  * *Combat Auto-Close:* Automatically closes open menus, spellbook, quests, and profession windows upon entering combat (`PLAYER_REGEN_DISABLED`) for a clear field of view.
  * *Instance Compact Mode:* Automatically caps open windows to 75% max scale inside dungeons, raids, and PvP instances. Seamlessly restores your custom sizes when exiting.
* **Sticky Window Docking & Group Dragging (`v1.6`):**
  * Windows touching edge-to-edge ($\le 16\text{ px}$) dock together and move synchronously as a group!
  * Hold `[Alt]` while dragging to detach a single window from the cluster.
* **Pre-Registered Community AddOns (`v1.6`):**
  * Built-in support for *Details!*, *Questie*, *Bagnon / Baganator*, *ThreatClassic2*, *TomTom*, *WeakAuras*, *Auctionator*, *AtlasLoot*, and *Postal*.
  * Zero overhead (0.00 ms CPU, 0 bytes RAM) when absent; instantly recognized with %-badge and management when loaded!
* **Window Picker 2.0 (`v1.5`):** Visual third-party inspector with real-time hover highlight, floating cursor HUD, and mouse-wheel hierarchy navigation (`Child` <-> `Parent`) to capture nested addon frames with pixel precision.
* **Per-Window Opacity & Mouseover Fade (`v1.4`):** Customize panel transparency (30%–100%) with smart mouseover fade-in for distraction-free gameplay and 0.00 ms idle CPU.
* **Character-Bound Profiles & Handheld Auto-Detection (`v1.4`):** Bind profiles per character and enjoy automatic Steam Deck (<= 1400x800) detection with tailored 72% handheld presets.
* **Minimap Button & LDB Quick Menu (`v1.3`):** Circular compass launcher with profile cycling, 1-click presets, and live window preview toggles.
* **Individual Window Scaling (`50%` – `150%`):** Resize any Blizzard or *WoW: Forever* panel independently via the optional titlebar `%` pill badge, `Ctrl + Mouse Wheel`, or `/ella`.
* **Named Layout Profiles (`v1.1`):** Create, copy, delete, and switch between multiple named window layouts (`Default`, `Laptop / Deck`, custom profiles) via `/ella` or `/ella profile <Name>`.
* **Magnetic Edge Snapping & Drag Opacity (`v1.1`):** Live cyan alignment guides snap windows cleanly to screen center, top edges, or side-by-side docking (`Shift` = `10px` grid), with optional semi-transparency while dragging.
* **Companion Sub-Frame Sync (`v1.1`):** Linked popups (`QuestLogPopupDetailFrame`, `TokenFramePopup`, `ProfessionsCustomerOrdersFrame`, `MacroPopupFrame`, etc.) automatically inherit their parent panel's scale.
* **Cursor-Pivot Math:** Zooming keeps the hovered UI coordinate anchored right beneath your cursor without coordinate drift.
* **Scale-Only Mode:** Keep Blizzard's automatic side-by-side `UIPanel` push layout while shrinking panels to crisp Classic proportions.
* **Zero-Taint & Edit Mode Quarantine:** Strictly isolated from `EditModeManagerFrame` HUD elements, queues protected frame changes safely during combat lockdown, writes zero properties onto Blizzard frames, and runs at **0.00 ms idle CPU**.
* **Bilingual Out of the Box:** Full English (`enUS`) and German (`deDE`) localization.

---

## Installation

### Standard (Windows / macOS / Linux)
Entpacke den Ordner `ELLA` in dein *WoW: Forever*-AddOns-Verzeichnis, sodass folgender Pfad existiert:
```text
World of Warcraft/_forever_/Interface/AddOns/ELLA/ELLA.toc
```

### Linux Development Symlink (Faugus / Lutris / Steam / Bottles / Wine)
Für lokale Entwicklung unter Linux verlinkt das mitgelieferte Skript das Repository direkt in deine `_forever_`-Installation (Änderungen sind sofort per `/reload` im Spiel aktiv):
```bash
./scripts/link-addon.sh "/pfad/zu/World of Warcraft/_forever_/Interface/AddOns"
```

Release-Archiv lokal bauen & Regelwerk-Tests ausführen:
```bash
python3 tests/validate_addon.py
python3 scripts/build-release-zip.py
```

---

## Projektstruktur / Architecture

```text
ELLA/
├── ELLA.toc                 # Interface: 16001, AllowLoadGameType: camelot, standard
├── Media/
│   └── Icon.tga             # Custom 256x256 Addon-Icon (Addon-Liste, Minimap & UI)
├── assets/                  # CurseForge Avatar (400x400) & Hero-Banner (nur Repo/Web)
├── Libs/
│   └── LibStub/             # Eingebettete Public-Domain Bibliothek
├── Locales/
│   ├── enUS.lua             # Englische Lokalisierung (Fallback)
│   └── deDE.lua             # Deutsche Lokalisierung (100% Parität)
├── Core/
│   ├── Init.lua             # Namespace, Konstanten, SavedVariables Schema v2 (ELLADB)
│   ├── Guard.lua            # Anti-Taint-Wächter, EditMode-Blacklist & Combat-Queue
│   ├── Registry.lua         # Deklarative Fenster- & Preset-Registrierung + LoD-Loader
│   ├── Engine.lua           # Cursor-Pivot-Zoom, Magnetic-Snap, Drag-Alpha & LinkedFrames
│   └── Profiles.lua         # Benannte Profile, Presets & ASCII Export/Import (ELLA1;...)
├── Data/
│   ├── Frames_Core.lua      # Immer geladene Standardfenster (Charakter, Quest, Ruf...)
│   ├── Frames_LoD.lua       # Load-on-Demand-Module (Berufe, Zauberbuch, AH, Talente...)
│   └── Frames_Forever.lua   # WoW: Forever Spezialfenster (Camping, Legacy, Fraktionen)
├── UI/
│   ├── Badge.lua            # UIParent-isoliertes Titelleisten-Badge (%) & Popover-Slider
│   ├── GridOverlay.lua      # Bildschirm-Ausrichtungsgitter (Zentrum-Kreuz & Drittel-Achsen)
│   ├── MinimapButton.lua    # Natives Minimap-QuickMenu & Shift+Klick Durchschaltung
│   ├── Picker.lua           # Interaktiver "/ella pick" Inspektor + GitHub-Snippet-Generator
│   ├── SettingsPanel.lua    # 3-Reiter Fenster-Manager (/ella) mit Profilen & Optionen
│   ├── Tutorial.lua         # Interaktives 13-Schritte Onboarding-Tutorial (/ella tour)
│   └── WelcomeDialog.lua    # Einmaliger Erststart-Dialog zur Preset-Wahl
└── API/
    └── PublicAPI.lua        # Öffentliche Drittanbieter-API (ELLA_API & LibStub("ELLA-1.0"))
```

---

## Third-Party Addon API (`ELLA_API`)

Andere Addon-Autoren können ihre eigenen Fenster mit wenigen Zeilen an **EĹLA** anbinden:

```lua
local api = _G.ELLA_API or (LibStub and LibStub("ELLA-1.0", true))
if api then
    api:RegisterWindow("MY_ADDON_MAIN", {
        addon = "MyAddon",
        frame = "MyAddonMainFrame",
        label = "My Addon Window",
        defaultCompactScale = 0.85,
    })
end
```

Weitere Details und das verbindliche **Goldene Regelwerk** für Pull Requests findest du in [CONTRIBUTING.md](CONTRIBUTING.md).

## License
Veröffentlicht unter der [MIT License](LICENSE).
