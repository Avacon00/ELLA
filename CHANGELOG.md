# Changelog

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
