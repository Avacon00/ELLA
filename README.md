# EĹLA (`Ella`) – Easy Layout & Location Assistant

<p align="center">
  <img src="assets/ella-banner.png" alt="EĹLA – Easy Layout & Location Assistant Hero Banner" width="840" />
</p>

> **Per-Window UI Scaler & Position Memory for *World of Warcraft: Forever* (`Interface: 16001` / `Project Camelot`)**

![Version 1.9.0](https://img.shields.io/badge/Version-v1.9.0-ffaa00)
![Interface 16001](https://img.shields.io/badge/WoW_Forever-Interface_16001-00ccff)
![Project Camelot](https://img.shields.io/badge/GameType-camelot-ffd100)
![Zero Taint](https://img.shields.io/badge/Architecture-Zero_Taint-00ff96)
![License MIT](https://img.shields.io/badge/License-MIT-blue)

**EĹLA** (**E**asy **L**ayout & **L**ocation **A**ssistant — im Spiel aufgrund von Blizzards `Friz Quadrata`-Schriftart sauber als **`Ella`** dargestellt) löst eines der größten UI-Probleme in **World of Warcraft: Forever**: Moderne Retail-Menüfenster (Berufe, Zauberbuch, Questlog, Auktionshaus, Ruf) wirken überdimensioniert, während die globale UI-Skalierung sofort auch Chat, Tooltips und Aktionsleisten unleserlich klein macht.

---

## Deutsch (Übersicht & Bedienung)

### Highlights
* **Dark-Slate UI-Überarbeitung, Typografie & Engine-Härtung (`v1.9.0`):**
  * *Ruhiges Flat-UI in der Fensterliste:* Maßgeschneiderte dunkle Slate-Steuerelemente statt greller Blizzard-Rot-Buttons – mit semantischen Modusfarben (**Smaragdgrün** für *Skalieren + Bewegen*, **Bernsteingold** für *Nur Skalieren*, **Schiefergrau** für *Deaktiviert*) und Gold-/Cyan-Akzenten bei abweichender Skalierung.
  * *Echte deutsche Typografie:* 100 % saubere Umlaute (`ä`, `ö`, `ü`, `ß`) in allen Menüs, Tooltips, Dialogen und allen 13 Tutorial-Schritten.
  * *Persistentes Ausrichtungsgitter & 8 Filter-Kategorien:* Das Screen-Grid bleibt auch nach dem Schließen des Managers aktiv (inklusive leuchtendem Cyan-Aktivstatus auf `[# Gitter]`); neuer eigener Filter-Reiter **`Forever`** sowie kontextsensitive Leerzustände.
  * *2-Klick-Sicherheitsbestätigung & Gruppen-Clamping:* Schutz vor versehentlichem `Alle Reset` oder Profil-Löschen direkt auf dem Button; angedockte Sticky-Window-Gruppen gleiten am Bildschirmrand synchron ohne Versatz.
  * *Gehärteter Picker 2.0 & EditMode-Schutz:* Automatische Bereinigung verwalteter Blizzard-Container (`RightManagedFrameContainer` u. a.) sowie vollständige `ESC`-Unterstützung in allen Popups, Popovern und Dialogen.
* **Audio- & Haptisches Feedback (`v1.8.0`):** Native Blizzard-Soundeffekte beim magnetischen Einrasten (Snap-Sound), Boss-Key, Profil- und Preset-Wechsel sowie Gitter-Umschaltung. Vollständig abschaltbar unter *Einstellungen*.
* **Dynamische Echtzeit-Filterzähler (`v1.8.0`):** Die Kategorie-Tabs im Manager zeigen in Echtzeit an, wie viele Fenster gerade offen sind (`Offen (2)`) bzw. wie viele eigene Drittanbieter-Fenster existieren (`Custom (1)`).
* **Minimap-Schnellauswahl & Shift+Klick (`v1.7.3`):** Eigenständiges, ausfallsicheres Popover direkt an der Minimap mit Außenklick-Schließung, Profil-Schnellwechsler, 1-Klick-Presets und Schnellstartern (Picker, Gitter, Tutorial). Halte `Shift` gedrückt und klicke auf das Icon, um sofort zum nächsten Profil durchzuschalten!
* **Erweitertes 13-Schritte Onboarding-Tutorial (`v1.7.2`):** Vollständig ausgebaute, geführte Tour (`/ella tour`) mit automatischer Reiter-Navigation und Scheinwerfer-Spotlight über alle 3 Hauptbereiche.
* **Entzerrte 3-Reiter-Benutzeroberfläche (`v1.7.1`):** Übersichtliche Aufteilung des Managers in *Fenster & Skalierung*, *Einstellungen* und *Profile & Vorlagen* mit über 120px mehr vertikalem Platz (12–14 Fensterzeilen gleichzeitig ohne Scrollen sichtbar).
* **Screen-Grid Overlay (`v1.7.0`):** Schalte per Klick auf `[# Gitter]` im Manager, in der Minimap-Schnellauswahl oder per `/ella grid` ein dezentes Vollbild-Ausrichtungsgitter mit leuchtendem Zentrum-Kreuz (Cyan), Drittel-Achsen (Gold) und 32px-Raster ein.
* **Profil-Sharing 2.0 mit Live-Vorschau (`v1.7.0`):** Teile deine Layouts blitzschnell via `!ELLA:v2:`-Codes. Beim Einfügen analysiert Ella den String sofort und zeigt eine Infobox mit Profilnamen und enthaltenen Fenstern an, bevor du ihn übernimmst.
* **Boss-Key & Panik-Aktion (`v1.7.0`):** Ein einziger Tastendruck schließt alle aktuell offenen Fenster blitzschnell – ein zweiter Tastendruck stellt genau dieselben Fenster wieder an Ort und Stelle her! Frei belegbar in Blizzards Menü (*Tastenbelegung* -> *AddOns* -> *Ella*) oder per `/ella panic`.
* **Kampf- & Instanz-Schutz (`v1.6`):**
  * *Auto-Close im Kampf:* Schließt ungeschützte Menüs, Zauberbuch und Berufsfenster beim Kampfeintritt (`PLAYER_REGEN_DISABLED`) sofort automatisch.
  * *Instanz-Kompaktmodus:* Begrenzt geöffnete Fenster in Dungeons, Raids und PvP-Instanzen vorübergehend auf maximal 75 % Skalierung. Beim Verlassen wird deine Wunschskalierung nahtlos wiederhergestellt.
* **Synchrones Fenster-Docking & Sticky Windows (`v1.6`):**
  * Aneinanderliegende oder bündige Fensterkanten ($\le 16\text{ px}$) docken automatisch aneinander an und bewegen sich synchron als Gruppe!
  * Halte `[Alt]` beim Ziehen gedrückt, um ein Fenster einzeln aus der Gruppe zu lösen.
* **Vor-Registrierte Community-AddOns (`v1.6`):**
  * Vorkonfigurierte Unterstützung für *Details! Damage Meter*, *Questie*, *Bagnon / Baganator*, *ThreatClassic2*, *TomTom*, *WeakAuras*, *Auctionator*, *AtlasLoot* und *Postal* (erscheinen automatisch, sobald das jeweilige AddOn geladen ist).
* **Fenster-Picker 2.0 (`v1.5`):** Visuelle Drittanbieter-Erkennung mit Live Hover-Highlighter, schwebendem Cursor-HUD und **Mausrad-Hierarchie-Navigation** (`Child` <-> `Parent`), um verschachtelte AddOns zielsicher aufzunehmen.
* **Fenster-Deckkraft & Mouseover-Fade (`v1.4`):** Passe die Transparenz jedes Fensters stufenlos (`30 %` – `100 %`) an. Mit *Mouseover-Fade* bleiben Fenster dezent durchscheinend, bis du mit der Maus darüberfährst (0,00 ms Leerlauf-CPU).
* **Charakter-gebundene Profile & Handheld-Erkennung (`v1.4`):** Binde Layout-Profile direkt an deine Charaktere. Auf kompakten Displays wie dem Steam Deck ($\le 1400 \times 800$) schlägt Ella automatisch das handliche 72%-Preset vor.
* **Einzel-Fenster-Skalierung (`50 %` – `150 %`) & Cursor-Pivot-Zoom:** Skaliere jedes Blizzard- und *WoW: Forever*-Fenster individuell über das `%`-Badge in der Titelleiste, per `Strg + Mausrad` oder im `/ella`-Manager – der Punkt unter deinem Mauszeiger bleibt dabei pixelgenau fixiert.
* **„Nur Skalieren“-Modus (`Scale Only`):** Behalte Blizzards automatische Nebeneinander-Anordnung bei, öffne jedes Fenster aber in deiner kompakten Wunschgröße (auch als globaler Standard für neue Fenster wählbar).
* **100 % Taint-frei & Edit-Mode-sicher:** Ignoriert konsequent alle HUD- und Kampfelemente aus Blizzards `EditModeManagerFrame`, reiht geschützte Fenster im Kampf sicher in eine Warteschlange ein (`InCombatLockdown()`) und verursacht **0,00 ms CPU-Last im Ruhezustand**.

### Chat-Befehle
| Befehl | Funktion |
| :--- | :--- |
| `/ella` | Öffnet bzw. schließt den durchsuchbaren **Ella Fenster-Manager** |
| `/ella tour` | Startet das interaktive **13-Schritte-Tutorial** |
| `/ella grid` | Schaltet das **Vollbild-Ausrichtungsgitter** ein oder aus |
| `/ella panic` | **Boss-Key:** Schließt alle offenen Fenster oder stellt sie wieder her |
| `/ella profile <Name>` | Wechselt zum angegebenen Layout-Profil (ohne Namen: nächstes Profil durchschalten) |
| `/ella compact` | Aktiviert sofort das **Classic Kompakt (80 %)**-Preset |
| `/ella pick` | Startet den interaktiven **Fenster-Picker 2.0** für Drittanbieter-Fenster |
| `/ella undo` | Macht die letzte Skalierungs- oder Positionsänderung rückgängig (bis zu 25 Schritte) |
| `/ella badges` | Blendet die `%`-Badges in den Fenstertitelleisten ein oder aus |
| `/ella reset` | Setzt alle Fensterskalierungen und Positionen auf `100 %` zurück |
| `/ella test` | Führt den integrierten 6-Punkte-Selbsttest zur Diagnose aus |

---

## English (Overview & Usage)

### Key Features
* **Dark-Slate UI Polish, Engine Hardening & UX Refinement (`v1.9.0`):**
  * *Custom Dark-Slate Row Controls:* Replaces repetitive red Blizzard buttons inside the scroll list with sleek flat Dark-Slate controls and semantic mode colors (**Emerald** for *Scale + Move*, **Amber Gold** for *Scale Only*, **Muted Slate** for *Disabled*) plus gold/cyan scale indicators.
  * *Persistent Alignment Grid & 8 Filter Pills:* The full-screen alignment grid now stays active after closing the manager so you can arrange game windows unobstructed (with glowing cyan active states on `[# Grid]`), joined by a dedicated **`Forever`** category pill and contextual empty-state helpers.
  * *Two-Click Inline Safety & Rigid Group Clamping:* Destructive actions (`Reset All`, `Delete Profile`) require a quick second confirmation click; docked Sticky Window clusters clamp rigidly at screen boundaries without breaking relative alignment.
  * *Hardened Picker 2.0 & EditMode Protection:* Expanded blacklist and automatic cleanup for Blizzard managed containers (`RightManagedFrameContainer`, etc.), plus universal `ESC` close support across all popovers and dialogs.
* **Audio Feedback & Sound Engine (`v1.8.0`):** Native Blizzard sound effects for magnetic edge snapping, Boss-Key panics, profile cycling, button clicks, and distinct grid on/off cues. Fully toggleable in *Settings*.
* **Dynamic Real-Time Category Counters (`v1.8.0`):** Live counts on manager category pills (`Open (2)`, `Custom (1)`) with zero-latency event updates.
* **Minimap Quick Menu & Shift+Click Cycle (`v1.7.3`):** Native, zero-taint popover anchored to the Minimap button with outside-click dismissal, quick profile switching, 1-click presets, and tool launchers (picker, grid, tutorial). Hold `Shift` and click the icon to instantly cycle through profiles!
* **Expanded 13-Step Onboarding Tutorial (`v1.7.2`):** Comprehensive guided interactive walkthrough (`/ella tour`) featuring automatic tab switching and spotlighting across all 3 main areas.
* **De-Cluttered 3-Tab Architecture (`v1.7.1`):** Clean separation into *Windows & Scale*, *Settings*, and *Profiles & Presets* with >120px more vertical height for up to 14 rows visible simultaneously.
* **Screen-Grid Overlay (`v1.7.0`):** Toggle a full-screen alignment grid (`[# Grid]` button or `/ella grid`) featuring a glowing cyan center crosshair, golden rule-of-thirds lines, and 32px precision grid lines.
* **Profile-Sharing 2.0 with Live Preview (`v1.7.0`):** Share your window layouts via `!ELLA:v2:` string codes. Pasting a string instantly previews the profile name and configured windows before importing.
* **Boss-Key & Panic Restore (`v1.7.0`):** Instantly closes all open windows on a single key press, and pressing it again restores those exact windows. Bindable via WoW Keybindings (`Options` -> `Keybindings` -> `AddOns` -> `Ella`) or `/ella panic`.
* **Combat & Instance Protection (`v1.6`):**
  * *Combat Auto-Close:* Automatically closes open unprotected menus, spellbook, quests, and profession windows upon entering combat (`PLAYER_REGEN_DISABLED`).
  * *Instance Compact Mode:* Temporarily caps open windows to 75% max scale inside dungeons, raids, and PvP instances, seamlessly restoring personal scales on exit.
* **Sticky Window Docking & Group Dragging (`v1.6`):**
  * Windows touching edge-to-edge ($\le 16\text{ px}$) dock together and move synchronously as a group (hold `[Alt]` while dragging to detach a single window).
* **Pre-Registered Community AddOns (`v1.6`):**
  * Built-in support for *Details!*, *Questie*, *Bagnon / Baganator*, *ThreatClassic2*, *TomTom*, *WeakAuras*, *Auctionator*, *AtlasLoot*, and *Postal* with zero overhead when uninstalled.
* **Window Picker 2.0 (`v1.5`):** Visual third-party inspector with real-time hover highlight, floating cursor HUD, and mouse-wheel hierarchy navigation (`Child` <-> `Parent`).
* **Per-Window Opacity & Mouseover Fade (`v1.4`):** Customize panel transparency (`30%` – `100%`) with smart mouseover fade-in and **0.00 ms idle CPU**.
* **Character-Bound Profiles & Handheld Auto-Detection (`v1.4`):** Bind profiles per character and enjoy automatic Steam Deck ($\le 1400 \times 800$) detection with tailored 72% handheld presets.
* **Individual Window Scaling (`50%` – `150%`), Cursor-Pivot Math & Scale-Only Mode:** Resize any Blizzard or *WoW: Forever* panel independently without coordinate drift, or keep Blizzard's side-by-side `UIPanel` push layout active while shrinking panels to Classic proportions.
* **Zero-Taint & Bilingual Out of the Box:** Strictly isolated from `EditModeManagerFrame` HUD elements, combat-lockdown safe, **0.00 ms idle CPU**, and 100% English (`enUS`) and German (`deDE`) parity.

### Slash Commands
| Command | Description |
| :--- | :--- |
| `/ella` | Opens or closes the searchable **Ella Window Manager** |
| `/ella tour` | Starts the interactive **13-step onboarding tutorial** |
| `/ella grid` | Toggles the full-screen **alignment grid overlay** |
| `/ella panic` | **Boss-Key:** Immediately closes or restores open windows |
| `/ella profile <Name>` | Switches to the named profile (or cycles to the next profile if omitted) |
| `/ella compact` | Applies the **Classic Compact (80%)** preset |
| `/ella pick` | Starts **Window Picker 2.0** to register third-party addon frames |
| `/ella undo` | Reverts the last scale or position change (up to 25 steps) |
| `/ella badges` | Shows or hides the `%` pills on window titlebars |
| `/ella reset` | Resets all window scales and positions back to `100%` |
| `/ella test` | Runs the built-in 6-point in-game diagnostic self-test |

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
├── Bindings.xml             # Blizzard Tastenbelegung (Kategorie ADDONS: Boss-Key, Manager, Gitter)
├── Media/
│   └── Icon.tga             # Custom 256x256 Addon-Icon (Addon-Liste, Minimap & UI)
├── assets/                  # CurseForge Avatar (400x400) & Hero-Banner (nur Repo/Web)
├── Libs/
│   └── LibStub/             # Eingebettete Public-Domain Bibliothek
├── Locales/
│   ├── enUS.lua             # Englische Lokalisierung (Fallback)
│   └── deDE.lua             # Deutsche Lokalisierung (100% Parität & echte Umlaute)
├── Core/
│   ├── Init.lua             # Namespace, Sound-Engine, SavedVariables Schema v2 (ELLADB)
│   ├── Guard.lua            # Anti-Taint-Wächter, EditMode-Blacklist & Combat-Queue
│   ├── Registry.lua         # Deklarative Fenster- & Preset-Registrierung + LoD-Loader
│   ├── Engine.lua           # Cursor-Pivot-Zoom, Magnetic-Snap, Sticky-Docking & Boss-Key
│   └── Profiles.lua         # Benannte Profile, Undo-Stack & Export/Import (!ELLA:v2:)
├── Data/
│   ├── Frames_Core.lua      # Immer geladene Standardfenster (Charakter, Quest, Ruf...)
│   ├── Frames_LoD.lua       # Load-on-Demand-Module (Berufe, Zauberbuch, AH, Talente...)
│   └── Frames_Forever.lua   # WoW: Forever Spezialfenster & Community-AddOns
├── UI/
│   ├── Badge.lua            # UIParent-isoliertes Titelleisten-Badge (%) & Popover-Slider
│   ├── GridOverlay.lua      # Persistentes Vollbild-Ausrichtungsgitter (Zentrum & Drittel)
│   ├── HandheldDialog.lua   # Kompakt-/Steam-Deck-Erkennung (<= 1400x800) & 72%-Empfehlung
│   ├── MinimapButton.lua    # Natives Minimap-QuickMenu, LDB & Shift+Klick-Durchschaltung
│   ├── Picker.lua           # Interaktiver "/ella pick" Inspektor + Hierarchie-Navigation
│   ├── SettingsPanel.lua    # 3-Reiter Dark-Slate Fenster-Manager (/ella) mit 8 Filter-Tabs
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
