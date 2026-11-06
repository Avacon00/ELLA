# Changelog

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
