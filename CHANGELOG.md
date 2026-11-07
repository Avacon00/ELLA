# Changelog

## v1.9.1 – In-Game Feinschliff: Tooltip-Randschutz, Minimap-Maskierung & Custom-Zähler
* **Intelligente Badge-Tooltip-Verankerung (`UI/Badge.lua`):**
  * Der Tooltip des `%`-Badges öffnet sich auf der mittleren und rechten Bildschirmhälfte nun automatisch nach **unten-links** (`ANCHOR_BOTTOMLEFT`) statt nach unten-rechts und klappt nur nahe am linken Bildschirmrand auf `ANCHOR_BOTTOMRIGHT` um – kein abgeschnittener Tooltip mehr am rechten Bildschirmrand.
* **Präziser `Custom (X)`-Zähler auch nach Preset-Anwendung (`UI/SettingsPanel.lua`):**
  * Vorregistrierte Community-AddOns (`Details!`, `Questie`, `Bagnon` etc.) werden im Zähler `Custom (X)` und in der Standardliste nur noch geführt, wenn das jeweilige AddOn tatsächlich im Client geladen ist – nicht mehr allein deshalb, weil ein 1-Klick-Preset (`WQHD / 4K` etc.) pauschal Skalierungswerte in `ELLADB` hinterlegt hat (`Custom (0)` statt `Custom (9)`).
* **Kreisrunde Minimap-Icon-Maskierung & Pixel-Zentrierung (`UI/MinimapButton.lua`):**
  * Exakte `31×31` / `53×53` `MiniMap-TrackingBorder`-Geometrie plus kreisförmige `MaskTexture` (`TempPortraitAlphaMask`) und nativer runder Hintergrund (`UI-Minimap-Background`), sodass keine eckigen Icon-Ecken mehr unter dem Goldring hervorstehen.

## v1.9.0 – Design-System-Politur, Deutsche Typografie, Engine-Härtung & UX-Feinschliff
* **Dark-Slate UI-Überarbeitung & Visuelle Hierarchie (`SettingsPanel`, `Badge`, `MinimapButton`, `Tutorial`):**
  * **Maßgeschneiderte Flat-Controls in der Fensterliste:** Ersetzt die repetitiven knallroten Blizzard-Buttons pro Zeile durch ruhige Dark-Slate-Steuerelemente (`CreateFlatButton`) mit subtilen Hover-Rahmen und Zeilenglanz.
  * **Semantische Modus-Farben & Skalen-Akzente:** Der Modus-Button signalisiert seinen Zustand nun sofort farblich (**Smaragdgrün** für *Skalieren + Bewegen*, **Bernsteingold** für *Nur Skalieren*, **Schiefergrau** für *Deaktiviert*). Veränderte Skalierungen leuchten in Gold (bzw. Cyan bei aktiver 75%-Instanzbegrenzung).
  * **8 Kategorie-Filter & Kontextsensitive Leerzustände:** Neuer Filter-Tab **`Forever`** für *WoW: Forever*-Systeme, exakter `Custom (X)`-Zähler (ruhende, nicht installierte Community-AddOns blähen die Liste nicht mehr auf) sowie hilfreiche Leerzustands-Hinweise inklusive `[Alle Fenster anzeigen]`-Schnellbutton.
  * **Suchfeld mit Fokus-Ring & `[×]`-Reset:** Eingelassenes Suchfeld mit Cyan-Fokusrahmen und Ein-Klick-Löschbutton.
  * **Persistentes Ausrichtungsgitter:** Das Vollbild-Gitter bleibt beim Schließen des Managers bewusst aktiv, damit Spielfenster frei ausgerichtet werden können; `[# Gitter]` zeigt im Manager und Minimap-QuickMenu einen leuchtenden Cyan-Aktivstatus und nutzt eigene Ein-/Ausschalt-Sounds (`HIGH`-Strata für sichtbare Leitlinien auch über Standardfenstern).
  * **2-Klick-Sicherheitsbestätigung:** Schutz vor Fehlklicks bei `Alle Reset` und `Profil löschen` durch direkte Inline-Bestätigung (`Sicher? Klick!`).
  * **Symmetrisches Einstellungs-Grid & Neuer Standardmodus-Schalter:** Die Karte *Maus- & Bewegungsverhalten* bildet nun ein symmetrisches 3×2-Raster inklusive der bisher versteckten Option *Neue Fenster standardmäßig „Nur Skalieren“* sowie vollflächig klickbaren Checkbox-Beschriftungen und lückenlosen Tooltips.
  * **Popover-, Minimap- & Tutorial-Feinschliff:** Verbreitertes Badge-Popover (`304×224`) mit intelligentem Rand-Flip, eigener Mausrad-Steuerung auf dem Deckkraft-Slider und Sperr-/Instanz-Hinweisen; dynamische QuickMenu-Breite mit Außenklick-Schließung; überlappungsfreier Tutorial-Header (`434px`) mit dynamischer Texthöhe und `ESC`-Schließung für alle Popups & Dialoge.
* **100 % Saubere Deutsche Typografie & Ehrliches Copywriting (`deDE` & `enUS`):**
  * **Echte Umlaute überall:** Alle über 30 verbliebenen ASCII-Ersatzschreibweisen (`ae`, `oe`, `ue`, `ss`) in Einstellungen, Tooltips, Picker, Presets und allen 13 Tutorial-Schritten wurden durch saubere deutsche Umlaute (`ä`, `ö`, `ü`, `ß`) ersetzt; Tippfehler in `ELLA.toc` behoben.
  * **Kritischer Format-Crash-Fix (`HANDHELD_DIALOG_BODY`):** Unmaskiertes `(72%)` in `string.format` auf kompakten Auflösungen ($\le 1400 \times 800$, z. B. Steam Deck) behoben (`72%%`) und Erststart-Doppel-Popup verhindert.
  * **Ehrliches Export-Copywriting & Vollständige Lokalisierung:** Da WoWs Lua-Sandbox kein automatisches Beschreiben der Zwischenablage ohne Tastendruck erlaubt, heißt der Button nun transparent *Code markieren* / *Highlight String* mit klarem `Strg+C`-Hinweis; `/ella test` und alle UI-Strings sind nun zu 100 % zweisprachig lokalisiert.
* **Engine-, Taint- & Registry-Härtung (`Core/`, `Data/`, `Bindings.xml`):**
  * **Picker-Validierung & EditMode-Container-Schutz:** Kritischer Bug im Fenster-Picker behoben, durch den gesperrte Blizzard-Container (wie `RightManagedFrameContainer`) trotz roter Warnung per Linksklick registriert werden konnten; `Guard`-Blacklist umfassend erweitert und bestehende Fehl-Einträge in `SavedVariables` werden beim Start automatisch bereinigt.
  * **Verzögerte Frame-Bindung & Sichere Alpha-Grenzen:** Frühes Frame-Binding vor `ADDON_LOADED` verhindert; `MODE_DISABLED` wird auch in `HookFrameFade`/`ApplyAlphaToFrame` strikt respektiert; Mindest-Deckkraft einheitlich auf `30 %` abgesichert.
  * **Starres Gruppen-Clamping & Cursor-Pivot im Kompaktmodus:** Angedockte Sticky-Window-Gruppen stoppen am Bildschirmrand nun als starrer Verbund ohne Relativversatz; Cursor-Pivot-Zoom arbeitet auch unter aktivem 75%-Instanz-Deckel ohne Koordinaten-Drift; `SyncLinkedFrames` beachtet den 75%-Deckel und überspringt `boundFrame`.
  * **16001-Vorschau, Keybindings & Daten-Fixes:** Live-Vorschau (`ToggleWindowPreview`) für moderne 16001-Module (`Gilde & Communitys`, `Gruppensuche`, `Talente`, `Sammlungen`, `Abenteuerführer`, `Makros`, `Kalender`) repariert; `category="ADDONS"` in `Bindings.xml` ergänzt; Kandidaten-Konflikt zwischen `QUESTLOG` und `QUESTMAP` sowie `_detalhes`-Tabellenreferenz in `COMM_DETAILS` behoben; Validierungs-Suite (`tests/validate_addon.py`) auf Format-Strings, `Bindings.xml` und `cp1252`-Glyphen erweitert.

## v1.8.0 – Audio-Feedback & Dynamische Echtzeit-Filterzähler
* **Haptisches & Akustisches Feedback (Native Blizzard Sound-Engine):**
  * **Magnetisches Einrasten (Snap-Sound):** Sanfter, haptischer Klick (`SOUNDKIT.UI_BAG_SORTING_01`), sobald ein Fenster an Hilfslinien oder Nachbarfenstern einrastet. Intelligente Flankenerkennung mit Cooldown verhindert Sound-Spam während des Ziehens.
  * **Boss-Key (Panic Action):** Sattes Zuklapp-Geräusch (`SOUNDKIT.IG_SPELLBOOK_CLOSE`) beim Schließen aller Fenster und Aufblättern (`SOUNDKIT.IG_SPELLBOOK_OPEN`) beim Wiederherstellen.
  * **Profil- & Preset-Klicks:** Bestätigungssound beim Durchschalten von Profilen (`Shift + Klick`), Anwenden von Presets und Umschalten des Ausrichtungsgitters.
  * **Vollständig abschaltbar:** Neue Option *Akustisches Feedback (Sounds)* im Reiter *Einstellungen* unter *Anzeige & Interface* (standardmäßig aktiv).
* **Dynamische Echtzeit-Kategoriezähler (`Offen (X)` & `Custom (X)`):**
  * Die Filter-Pills im Manager zeigen nun in Echtzeit an, wie viele Fenster aktuell im Spiel geöffnet sind (z. B. `Offen (2)`) bzw. wie viele benutzerdefinierte Fenster existieren (`Custom (1)`).
  * Vollständig ereignisgesteuert über `OnManagedFrameShown` / `OnManagedFrameHidden` (0,00 ms Leerlauf-CPU, kein Polling).

## v1.7.3 – Native Minimap-Schnellauswahl & Direktes Profil-Durchschalten
* **Eigenständiges, ausfallsicheres Minimap-QuickMenu (Zero-Taint & Client-agnostisch):**
  * Das Minimap-Rechtsklick-Menü basierte zuvor auf Blizzards veraltetem `EasyMenu`/`UIDropDownMenuTemplate`, welches auf modernen Retail- und *WoW: Forever*-Clients (Camelot, Interface 16001) fehlschlägt oder durch Taint blockiert wird.
  * Komplett neu implementiert als natives EĹLA-Frame (`EllaMinimapQuickMenuFrame`) mit edlem Dunkelblau/Gold-Design, Backdrops und automatischer Bildschirmrand-Erkennung.
  * **Inhalte der Schnellauswahl:**
    * **Profile:** Liste aller angelegten Profile mit visueller Markierung (`» Profil «` in Hellgrün) für das derzeit aktive Profil. 1 Klick wechselt sofort das Profil.
    * **Presets (1-Klick-Vorlagen):** Direkter Zugriff auf Standard (100%), Classic Kompakt (80%), WQHD / 4K (85%) und Laptop / Deck (72%).
    * **Werkzeuge:** Schnellstarter für Fenster-Picker, Bildschirm-Gitter und das 13-Schritte-Tutorial.
* **Neues Tastaturkürzel: Shift + Klick auf das Minimap-Icon:**
  * Durch `Shift + Klick` (Links- oder Rechtsklick) auf das Minimap-Icon oder die LDB-Leiste (TitanPanel etc.) wird sofort zum nächsten Profil durchgeschaltet (`CycleNextProfile`), ohne dass ein Menü geöffnet werden muss.
  * Aktualisierter Minimap- und LDB-Tooltip mit Hinweis auf Shift+Klick.

## v1.7.2 – Erweitertes 13-Schritte Onboarding-Tutorial
* **Umfassende Tutorial-Erweiterung auf 13 geführte Schritte:**
  * Das interaktive Ingame-Tutorial (`/ella tour`) wurde auf 13 präzise, übersichtliche Schritte ausgebaut:
    1. *Willkommen & Grundkonzept* (Reiter: Fenster)
    2. *Fensterliste & Feineinstellung (+ / -, 100% Reset, Live-Vorschau-Auge)* (Reiter: Fenster)
    3. *Die 3 Skalierungsmodi (Skalieren+Bewegen, Nur Skalieren, Deaktiviert)* (Reiter: Fenster)
    4. *Suchleiste & 7 Kategorie-Filter* (Reiter: Fenster)
    5. *Fenster-Picker 2.0 mit Hover-HUD & Mausrad-Hierarchie für AddOns* (Reiter: Fenster)
    6. *Bildschirm-Ausrichtungsgitter (Screen-Grid mit Zentrum-Kreuz & Drittel-Achsen)* (Reiter: Fenster)
    7. *1-Klick-Vorlagen (Classic Kompakt, WQHD/4K, Laptop/Deck, Standard)* (Reiter: Profile)
    8. *Profile, Snapshots & Charakter-Bindung* (Reiter: Profile)
    9. *Profil-Sharing 2.0 (Export / Import mit Live-Prüfung & 1-Klick-Kopieren)* (Reiter: Profile)
    10. *Magnetisches Einrasten, 10px-Raster (Shift) & Sticky Windows (Alt)* (Reiter: Einstellungen)
    11. *Kampf- & Instanz-Schutz (Auto-Schließen & 75%-Kompaktmodus)* (Reiter: Einstellungen)
    12. *Titelleisten-Badges (%), Deckkraft (30%-100%) & Mouseover-Fade* (Reiter: Einstellungen)
    13. *Boss-Key (/ella panic), Blizzard-Tastenbelegung & Startklar!* (Reiter: Fenster)
  * Automatische Reiter-Navigation und präziser Spotlight-Rahmen für jeden Schritt.
  * Leicht vergrößerte Callout-Karte (400x195px) für perfekten Lesekomfort.

## v1.7.1 – UI/UX-Entzerrung & Moderne 3-Reiter-Architektur
* **Vollständige Benutzeroberflächen-Entzerrung (User-Friendly UI/UX):**
  * Das bisher überfüllte Hauptmenü mit über 30 gleichzeitig sichtbaren Steuerelementen wurde in **3 logische Hauptbereiche** aufgeteilt:
    1. **Reiter 1: Fenster & Skalierung (`tabViewWindows`):**
       * Konzentriert sich zu 100 % auf das Verwalten und Skalieren von Spielfenstern.
       * Die Fensterliste beginnt nun direkt bei $y = -84$ statt bisher $y = -274$ – **über 120 Pixel mehr vertikaler Raum**!
       * Bis zu 12–14 Fensterreihen sind nun gleichzeitig ohne Scrollen sichtbar.
       * Schlanke Aktionszeile: Profil-Schnellwechsler, Rückgängig-Button und die Fensterwerkzeuge `[+ Fenster-Picker]`, `[# Gitter]` und `[Alle Reset]` mit großzügigem Abstand.
       * Durchgehende Suchleiste und 7 Kategorie-Tabs mit reaktiver Breitenanpassung.
    2. **Reiter 2: Einstellungen & Optionen (`tabViewSettings`):**
       * Alle Schalter und Checkboxen sind jetzt in 3 thematisch gegliederte Karten mit erklärenden Tooltips unterteilt:
         * *Kampf- & Instanz-Schutz:* Kampf-Schutz (Auto-Schließen) & Instanz-Kompaktmodus (75 %).
         * *Maus- & Bewegungsverhalten:* Strg+Mausrad, Halbtransparent beim Ziehen, Magnetisches Einrasten, Sticky Windows & Bildschirm-Clamping.
         * *Anzeige & Interface:* EĹLA aktivieren, Titelleisten-Badges (%) & Minimap-Icon.
    3. **Reiter 3: Profile & Vorlagen (`tabViewProfiles`):**
       * Aufgeräumte Profilverwaltung: Profilwechsel, Speichern, Zurücksetzen, Rückgängig, Neues Profil, Löschen und Charakter-Bindung.
       * 1-Klick-Vorlagen (Presets): Standard (100 %), Classic Kompakt (80 %), WQHD/4K (85 %) und Laptop/Deck (72 %).
       * Profil Teilen & Sichern: Schneller Zugriff auf das Profil-Sharing 2.0 (Export / Import).
* **Tutorial-Synchronisation:**
  * Das interaktive Ingame-Tutorial (`/ella tour`) steuert während der einzelnen Erklärschritte automatisch den passenden Reiter an, sodass der Spotlight-Rahmen immer exakt auf das erklärte Element zeigt.

## v1.7.0 – Screen-Grid, Profil-Sharing 2.0 & Boss-Key
* **Option A: Visuelles UI-Ausrichtungs-Gitter (Screen-Grid Overlay):**
  * Neues dezent transparentes Vollbild-Raster zur millimetergenauen Fenster-Ausrichtung.
  * **Zentrum-Kreuz:** Cyan-leuchtende Leitlinien durch den exakten Bildschirmmittelpunkt (`UIParent`).
  * **Drittel-Achsen:** Goldene Hilfslinien bei 33,3 % und 66,6 % für ästhetische Menüplatzierung.
  * **32px-Raster:** Subtile Feinausrichtungs-Linien über den gesamten Bildschirm.
  * Ein-/Ausschaltbar über den neuen Button `[# Gitter]` im Manager oder per `/ella grid`.
  * Schaltet sich beim Verlassen des Managers automatisch ab; 0,00 ms Leerlauf-CPU im Ruhezustand.
* **Option B: Profil-Sharing 2.0 (1-Klick Import / Export mit Live-Vorschau):**
  * Modernisierter Import/Export-Dialog mit `!ELLA:v2:`-Format und automatischer Validierung.
  * **Live-Vorschau:** Erkennt beim Einfügen sofort den Profilnamen, die Anzahl der Fenster und zeigt eine lesbare Zusammenfassung an, bevor das Profil angewendet wird.
  * Neuer `[Alles kopieren]`-Button zum bequemen Teilen mit Freunden oder Gildenmitgliedern.
* **Option C: „Boss-Key“ & Globale Panik-Aktionen:**
  * **Panik-Schließen:** Schließt alle aktuell geöffneten ungeschützten EĹLA-Fenster blitzschnell mit einem Tastendruck.
  * **Intelligente Wiederherstellung:** Ein zweiter Tastendruck stellt exakt die zuvor geschlossenen Fenster wieder her.
  * **Blizzard-Tastenbelegung:** Volle Integration in Blizzards Tastenbelegungs-Menü (`Optionen` -> `Tastenbelegung` -> `Ella`).
  * Schnellausführung via `/ella panic` oder `/ella boss`.

## v1.6.1 – Fix: Konsolidierung von Charakterinfo, Ausrüstung & Ruf
* **Verschachtelungs- und Überlappungs-Fix (`CharacterFrame` vs. `ReputationFrame`):**
  * `ReputationFrame` ist in Blizzards Interface kein eigenständiges Fenster, sondern Reiter 3 innerhalb des `CharacterFrame`.
  * Die separate Registrierung von `REPUTATION` führte bei Vorschauen und Skalierungen dazu, dass Blizzards Tab-System umgangen wurde und sowohl `PaperDollFrame` (3D-Charaktermodell & Attribute) als auch `ReputationFrame` gleichzeitig übereinander gezeichnet wurden.
  * `ReputationFrame` wurde aus der separaten Fenster-Registrierung entfernt und als nativer Bestandteil von `CharacterFrame` konsolidiert.
  * Das ausklappbare Fraktions-Detailfenster (`ReputationDetailFrame`) wurde als `linkedFrame` an `CharacterFrame` gebunden und übernimmt nun exakt dessen Skalierung.
  * Titelleiste und Manager führen das Fenster nun einheitlich als **Charakterinfo, Ausrüstung & Ruf** – 100 % frei von doppelten Badges oder Frame-Überlagerungen.

## v1.6.0 – Kampf-Schutz, Synchrones Fenster-Docking & Community-AddOns
* **Option 1: Instanz- & Kampf-Schutz (Auto-Close & Kompaktmodus):**
  * **Kampf-Schutz (`combatAutoClose`):** Schließt ungeschützte Menüs, Zauberbuch, Questlog und Handwerksfenster sofort und automatisch beim Eintritt in den Kampf (`PLAYER_REGEN_DISABLED`), um das Sichtfeld sofort freizugeben.
  * **Instanz-Kompaktmodus (`instanceAutoCompact`):** Überwacht Instanzen (Dungeons, Raids, PvP) via `IsInInstance()`. Begrenzt alle geöffneten Fenster temporär auf maximal 75 % Skalierung für optimale Übersicht bei Bosskämpfen. Beim Verlassen wird die persönliche Wunschgröße nahtlos wiederhergestellt (0 Profil-Überschreibungen).
  * **Zero-Taint Garantie:** Geschützte Blizzard-Elemente (Aktionsleisten, UnitFrames) bleiben unangetastet.
* **Option 2: Synchrones Fenster-Docking (Sticky Windows & Gruppen-Verschiebung):**
  * **Intelligentes Edge-Docking:** Erkennt automatisch aneinanderliegende oder bündig ausgerichtete Fensterkanten ($\le 16\text{ px}$).
  * **Gruppen-Verschiebung:** Wird ein angedocktes Fenster verschoben, bewegen sich alle damit verbundenen Fenster synchron und nahtlos als Verbund mit.
  * **Alt-Unstick-Modifier:** Halte `[Alt]` beim Ziehen gedrückt, um die magnetische Bindung aufzubrechen und ein Fenster einzeln aus der Gruppe herauszuziehen.
  * **Persistente Verbund-Positionierung:** Nach dem Loslassen werden alle neuen Fensterkoordinaten automatisch im aktiven Profil gespeichert.
* **Option 3: Vor-Registrierte Community-AddOns (Out-of-the-Box für WoW: Forever):**
  * Vorab hinterlegte Deskriptoren für die beliebtesten AddOns:
    * *Details! Damage Meter* (`DetailsBaseWindow1`, `_detalhes`)
    * *Questie* (`Questie_BaseFrame`, `QuestieFrame`, `QuestieTracker`)
    * *Bagnon / Baganator* (`BagnonFrameinventory`, `BagnonFramebank`, `Baganator`)
    * *ThreatClassic2* (`ThreatClassic2BarFrame`, `ThreatClassicFrame`)
    * *TomTom* (`TomTomBlock`)
    * *WeakAuras Optionen* (`WeakAurasOptions`)
    * *Auctionator* (`AuctionatorShoppingFrame`, `AuctionatorConfigFrame`)
    * *AtlasLoot Enhanced* (`AtlasLoot_GUI-Frame`, `AtlasLootDefaultFrame`)
    * *Postal* (`Postal_OpenAllMenu`)
  * **Lazy-Resolution-System:** Völlig ruhend (0,00 ms CPU, 0 Bytes RAM) wenn das jeweilige AddOn fehlt. Sobald es aktiviert wird, erhält es sofort ein Titelleisten-`%`-Badge und erscheint in `/ella`.
* **Manager & UI-Optimierungen:**
  * Sauberes 6-Zeilen-Kontrollfeld mit Tooltips im Ella Manager (`/ella`).
  * Automatische Mindesthöhen-Anpassung auf 620 px für ermüdungsfreie Übersicht.
  * Aktualisierte interaktive Tutorial-Tour (Schritt 6 erklärt nun Sticky Windows und Alt-Unstick).

## v1.5.0 – Fenster-Picker 2.0 (Hover-Highlighter & Hierarchie-Inspektor)
* **Live Hover-Highlighter mit 3-Farben-Status:**
  * Legt in Echtzeit eine Bounding-Box um das anvisierte Fenster:
    * 🟢 **Smaragdgrün:** Sicheres Drittanbieter-Fenster, bereit zur Übernahme.
    * 🟡 **Gold / Bernstein:** Bereits in Ella registriertes Fenster.
    * 🔴 **Rubinrot:** Geschütztes Element (Aktionsleisten, EditMode, Nameplates) – zum Taint-Schutz gesperrt.
* **Mausrad-Hierarchie-Navigation (`Child` <-> `Parent`):**
  * Erkennt die vollständige Eltern-Kind-Kette verschachtelter AddOns (wie *Details!*, *Bagnon*, *Questie*, *WeakAuras*).
  * Durch Scrollen mit dem Mausrad wandert der Fokus ebenenweise nach oben (`Scroll Up` = Eltern-Container) oder tiefer (`Scroll Down` = Kind-Element).
  * 100 % Taint-frei über transparentes Overlay (`EnableMouse(false)`, `EnableMouseWheel(true)`).
* **Schwebender Inspektions-HUD am Cursor:**
  * Folgt dem Mauszeiger und zeigt Fensternamen, Pixelmaße ($B \times H$), Ebene ($X/Y$) und Status an.
  * Automatische Kanten-Erkennung (dreht sich am Bildschirmrand um, um nie abgeschnitten zu werden).
* **Direkte Sofort-Übernahme & Live-Test:**
  * Nach Klick auf ein neues Fenster wird es registriert und das EĹLA-Popover öffnet sich sofort daran zum Skalieren und Einstellen der Deckkraft.
* **Popover-Layout-Politur:**
  * Saubere vertikale Ausrichtung aller drei Checkboxen (*Nur Skalieren*, *Mouseover-Fade*, *Position sperren*) ohne Text-Überlappung.

## v1.4.0 – Per-Window Opacity & Mouseover-Fade, Character-Bound Profiles & Handheld Auto-Detection
* **Per-Window Opacity & Mouseover-Fade (Option A):**
  * Added a dedicated **Deckkraft (Opacity)** slider (30%–100%) to each window's quick popover badge.
  * Added **Mouseover-Fade** toggle: windows can remain subtle and semi-transparent during combat or exploration, automatically snapping to 100% full opacity as soon as the mouse cursor enters the frame.
  * Event-driven OnEnter/OnLeave watcher with automatic shutdown ensures **0.00 ms idle CPU** at rest and strict zero-taint compliance.
  * Resetting scale via `[100%]` now also restores opacity to 100% and disables fade.
  * Preserved across profile saving, checkpoints, and ASCII string exports.
* **Character-Bound Profiles (Option B):**
  * Added *"Profil an aktuellen Charakter binden"* checkbox in the Ella Manager (`/ella`).
  * Automatically switches to the character's designated layout upon login (`PLAYER_LOGIN`) with chat feedback.
  * Safe profile deletion automatically clears any character bindings pointing to deleted profiles.
* **Handheld & Steam Deck Auto-Detection (Option B):**
  * Automatically detects compact screen resolutions (<= 1400x800, such as Steam Deck at 1280x800, ROG Ally, or laptops).
  * Prompts the player on first login to activate the tailored `Laptop / Deck (72%)` preset.
  * Combat-safe prompt queuing prevents UI interruptions during encounters.

## v1.3.1 – Minimap Clipping Fix & Profession Category Mapping
* **Minimap Button Unclipped:**
  * Fixed button parenting by anchoring to `MinimapBackdrop` / `MinimapCluster` / `UIParent` instead of `_G.Minimap` directly, completely bypassing `Minimap`'s internal circular mask which was clipping perimeter buttons.
  * Added fallback initialization for `/reload` scenarios where `PLAYER_LOGIN` has already fired.
* **Profession Filter Category Mapping:**
  * Fixed category identifier from `CAT_PROFESSION` to `CAT_CRAFT_ECON` so clicking the `[Berufe]` filter pill immediately populates all crafting, merchant, bank, mail, and economy windows.
  * Added friendly empty-state label (*"Keine passenden Fenster in dieser Ansicht gefunden."*) when 0 windows match active filters.

## v1.3.0 – Minimap Icon & LDB Quick Menu, Category Filter Pills & Live Window Preview
* **Minimap Button & LDB Quick Menu:**
  * Added a circular minimap button featuring Ella's custom obsidian/gold compass icon.
  * Draggable anywhere around the minimap perimeter with saved angle persistence (`minimapPos`).
  * **Left-Click:** Toggles the Ella Manager (`/ella`).
  * **Right-Click:** Opens an elegant Quick Menu to switch Profiles, apply 1-Click Presets, or start the Picker/Tour directly.
  * **Middle-Click:** Starts the Window Picker immediately.
  * Built-in **LibDataBroker (LDB)** launcher for TitanPanel, ChocolateBar, and Bazooka.
  * Added a toggle checkbox (*"Minimap-Icon anzeigen"*) in `/ella` settings.
* **Category Filter Pills in Ella Manager:**
  * Added interactive filter pill buttons directly above the window list: `[Alle]`, `[Offen]`, `[Charakter]`, `[Berufe]`, `[Quests & Welt]`, `[Social]`, and `[Custom]`.
  * Instantly filters the displayed list without typing; the active filter glows in vibrant cyan.
  * Resizes smoothly and responsively when dragging the window corner.
* **Live Window Preview (`[👁]`-Button) per Row:**
  * Added an eye preview toggle button to every window row in `/ella`.
  * Clicking pops open the window immediately (or closes it if already open) so players can test and adjust size/position without walking to an NPC or hunting through submenus.
  * Displays glowing green when the window is currently open, and neutral gray when closed.

## v1.2.1 – Tutorial Visual Polish, Layering & Smart Card Positioning
* **Dimmer Layering Fix (Crystal Clear Ella Window):**
  * Shifted screen dimmer to strata `HIGH` so it gracefully dims the 3D game world, chat, action bars, and minimap, while leaving the Ella Manager window (strata `DIALOG`) 100% bright, vibrant, crisp, and fully readable.
* **Smart Non-Obtrusive Card Positioning:**
  * The tutorial callout card now dynamically inspects screen boundaries. On wide monitors (1080p, 1440p, 4K), it automatically docks to the side of Ella Manager (`LEFT` or `RIGHT`). On compact screens (1024×576, 1280×720, laptops & Steam Deck), it intelligently anchors opposite the active spotlight (`BOTTOM` or `TOP`), ensuring highlighted controls and window rows are never blocked.
  * Slimmed callout card dimensions to a sleek `390×185` with zero wasted vertical space.
* **Refined Spotlight Multi-Element Highlights:**
  * Step 2 now encompasses the entire 4-preset button bar in a single glowing cyan spotlight frame.
  * Step 3 highlights row 1's scaling controls (`-`, `+`, `100%`), Step 4 highlights the 3-state window mode button, Step 5 encompasses the full profile toolbar, and Step 6 highlights the movement & magnetic snapping controls.
* **Instant ESC Tour Exit:**
  * Registered the tutorial card with `UISpecialFrames` so pressing `ESC` instantly exits the tour cleanly.

## v1.2.0 – Interactive In-Game Tutorial Tour & Onboarding
* **First-Run Tutorial Opt-In Prompt:**
  * When opening `/ella` for the first time, players are politely asked (*"Kleines Tutorial gefällig?"*) with options to start right away (`Ja, gerne!`) or postpone (`Später vielleicht`), never getting in the way of experienced users.
* **8-Step Interactive Walkthrough Tour:**
  * Displays a semi-transparent screen dimmer and cyan glowing spotlight box around the active feature being explained.
  * Features a movable, dark obsidian callout card with step indicator (*Schritt X von 8*), clear explanations, and navigation buttons (`‹ Zurück`, `Weiter ›`, `Fertigstellen`, `Tour beenden (ESC)`).
* **Always Replayable & Combat-Safe:**
  * A dedicated **`[?]`** button in the Ella titlebar (and `/ella tour` slash command) lets players replay the tour anytime.
  * Automatically closes cleanly if combat begins (`PLAYER_REGEN_DISABLED`) to protect game performance and guarantee zero taint.

## v1.1.2 – Profile Checkpoints (`Speichern` / `Auf Profil-Stand`) & Multi-Step `Rückgängig` (`Undo`)
* **Protected Profile Checkpoints (`savedSnapshot`):**
  * Experimenting with window sizes or dragging windows no longer silently destroys your saved profile layout.
  * Added **`Profil speichern` (`Speichern *`)** to explicitly save your current layout into the active profile's checkpoint, and **`Auf Profil-Stand` (`Revert Profile`)** to immediately restore all windows to the exact sizes and positions of your last saved profile checkpoint.
* **Multi-Step `Rückgängig` (`Undo`) & Per-Window `Zurück` in the `%`-Badge Popover:**
  * Automatically records up to 25 undo checkpoints before dragging, scaling, or applying presets (intelligently grouping continuous slider drags / wheel scrolls into a single step).
  * Added a **`Zurück` (`Undo`)** button directly inside every window's `%`-Badge Popover as well as **`Rückgängig`** in `/ella` (and `/ella undo`, `/ella revert`, `/ella save`).
* **Popover Slider Stability Fix:**
  * Anchored the `%`-Badge Popover to fixed `UIParent` screen coordinates while open so resizing a window never shifts the slider bar underneath your mouse cursor.

## v1.1.1 – Resizable & Scalable Ella Manager + Picker UX Polish
* **Resizable & Self-Scalable Ella Manager Window (`/ella`):**
  * Added a **bottom-right resize grip** (`680×440` up to `1080×860` with dynamic responsive row & button stretching; Right-Click resets to `720×580`).
  * Added a **`[100%]` scale pill** in Ella's own titlebar (`60%` – `140%` via Mouse Wheel, Left-Click cycle, or `Ctrl + Mouse Wheel` anywhere on the Ella window; Right-Click resets to `100%`).
* **Frame Picker Auto-Return & Duplicate Guard:**
  * Launching `+ Pick Window` from `/ella` temporarily hides the Manager so it never blocks target frames, then **automatically re-opens Ella** as soon as you pick a window or cancel with Right-Click.
  * Clicking an already-managed Blizzard frame in the Picker now informs you which entry already controls it instead of creating a duplicate `CUSTOM_*` entry (and automatically cleans up any prior built-in duplicates on reload).
* **UI Clarity & Popover Spacing:**
  * Renamed the profile save button to **`+ Aktuelles Profil Speichern`** (`deDE`) / **`+ Save Current Profile`** (`enUS`).
  * Widened the titlebar badge quick-popover (`268px`) so longer German checkbox labels have clean right-side margin.

## v1.1.0 – Custom Artwork, Named Profiles & Magnetic Window Snapping
* **Custom Addon Icon & CurseForge Branding:**
  * Added custom 256x256 32-bit `.tga` emblem (`Media/Icon.tga`) displayed in WoW's AddOn List, Minimap `AddonCompartment`, Blizzard Options canvas, and `/ella` Window Manager.
  * Added CurseForge avatar (`400x400`) and 16:9 Dun Morogh Hero Banner in `assets/` (excluded from in-game release ZIPs to keep downloads lightweight).
* **Named Layout Profiles (`ELLADB` Schema v2):**
  * Seamlessly migrates existing `v1.0.x` window settings into the `"Default"` profile and pre-seeds `"Laptop / Deck"`.
  * Added an interactive **Profile Bar** in `/ella` (click to cycle profiles, `+ Copy Profile` modal to clone current layout, `Delete` button) plus `/ella profile <Name>` slash command.
* **Magnetic Edge Snapping & `Shift` 10px Grid:**
  * Dragged windows gently snap to horizontal screen center, top edges of other open windows, and side-by-side docking with live cyan alignment guides (`UIParent`-isolated, zero idle CPU). Hold `Shift` while dragging for crisp `10px` grid snapping.
* **Semi-Transparent Dragging:**
  * Optional `78%` window opacity while moving panels so you can see the game world and neighboring edges clearly underneath (automatically restored on mouse release).
* **Companion Sub-Frame Scale Sync (`linkedFrames`):**
  * Automatically syncs parent window scale onto companion popups (`TokenFramePopup`, `GearManagerDialogPopup`, `QuestLogPopupDetailFrame`, `ProfessionsCustomerOrdersFrame`, `AuctionDressUpFrame`, `SideDressUpFrame`, `AddFriendFrame`, `MacroPopupFrame`).
* **Public API `ELLA-1.0` Minor v2:**
  * Added `GetActiveProfile()`, `GetProfiles()`, `SwitchProfile(name)`, and `OnProfileSwitched` / `OnProfileImported` callbacks.

## v1.0.1 – EĹLA (`Ella`) Rebranding & UI Polish
* **Official Rebranding:** Renamed project to **EĹLA – Easy Layout & Location Assistant** (displayed in-game as **`Ella`** for 100% clean glyph rendering in Blizzard's `Friz Quadrata` font, with `/ella` as primary slash command).
* **Titlebar `%` Badge Layering Fix:** Elevated titlebar `%` pill badges onto the `HIGH` strata above modern `NineSlice` / `TitleContainer` borders while keeping them below `DIALOG` modals.
* **Window Manager Polish (`720px`):**
  * Automatically sorts currently open windows (`● Open Now` / `● Jetzt offen`) to the top of the list.
  * Refined compact button typography so long German (`deDE`) and English (`enUS`) labels fit cleanly without overflow.
  * Wrapped the Profile Export/Import multi-line `EditBox` inside a `ScrollFrame` so long strings never overlap bottom action buttons.

## v1.0.0 – Initial Launch for World of Warcraft: Forever (`16001`)
* Native support for **World of Warcraft: Forever** (`Project Camelot` / `Interface: 16001`).
* **Per-Window Scaling & Position Memory (`50%` – `150%`):** Scale and move individual Blizzard & *Forever* panels without shrinking chat, tooltips, or action bars.
* **Scale-Only Mode:** Preserve Blizzard's automatic side-by-side `UIPanel` layout while opening panels at compact Classic proportions.
* **Cursor-Pivot Zoom Math:** Scrolling on the titlebar `%` badge or via `Ctrl + Mouse Wheel` keeps the hovered point stationary under your cursor.
* **Zero-Taint & Edit Mode Quarantine:** Strict `InCombatLockdown()` queueing for protected panels, private weak-key state storage, `UIParent`-isolated UI widgets, and **0.00 ms idle CPU load**.
* **1-Click Presets:** *Classic Compact (80%)*, *WQHD / 4K (85%)*, and *Laptop / Deck (72%)*.
* **Interactive Frame Inspector (`/ella pick`) & Public API:** Register third-party addon windows in-game and generate ready-to-paste GitHub PR snippets, or integrate via `ELLA_API` / `LibStub("ELLA-1.0")`.
* **Full Bilingual Localization:** English (`enUS`) and German (`deDE`) out of the box.
