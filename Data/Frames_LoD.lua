local AddonName, ns = ...

local Registry = ns.Registry

-- ============================================================================
-- Load-on-Demand (LoD) Blizzard UI Modules
-- Bound safely via EventUtil.ContinueOnAddOnLoaded the instant they load.
-- ============================================================================

-- Spellbook & PlayerSpells (modernized 16001 panel + classic fallback)
Registry:RegisterWindow("SPELLBOOK", {
    addon = "Blizzard_PlayerSpells",
    candidates = { "PlayerSpellsFrame", "SpellBookFrame" },
    labelKey = "WIN_SPELLBOOK",
    category = "CAT_CHARACTER",
    defaultCompactScale = 0.80,
    protected = true,
})

-- Talents (standalone talent module when separated from PlayerSpells)
Registry:RegisterWindow("TALENTS", {
    addon = "Blizzard_TalentUI",
    candidates = { "ClassTalentFrame", "PlayerTalentFrame" },
    labelKey = "WIN_TALENTS",
    category = "CAT_CHARACTER",
    defaultCompactScale = 0.78,
    protected = true,
})

-- Modern Professions UI (one of the largest windows in 16001)
Registry:RegisterWindow("PROFESSIONS", {
    addon = "Blizzard_Professions",
    frame = "ProfessionsFrame",
    labelKey = "WIN_PROFESSIONS",
    category = "CAT_CRAFT_ECON",
    defaultCompactScale = 0.76,
    protected = true,
})

-- Classic-style TradeSkill / Craft fallbacks
Registry:RegisterWindow("TRADESKILL_CLASSIC", {
    addon = "Blizzard_TradeSkillUI",
    frame = "TradeSkillFrame",
    labelKey = "WIN_TRADESKILL_CLASSIC",
    category = "CAT_CRAFT_ECON",
    defaultCompactScale = 0.82,
})

Registry:RegisterWindow("CRAFT_CLASSIC", {
    addon = "Blizzard_CraftUI",
    frame = "CraftFrame",
    labelKey = "WIN_CRAFT_CLASSIC",
    category = "CAT_CRAFT_ECON",
    defaultCompactScale = 0.82,
})

-- Auction House (Modern AuctionHouseFrame + Classic AuctionFrame fallback)
Registry:RegisterWindow("AUCTION", {
    addon = "Blizzard_AuctionHouseUI",
    candidates = { "AuctionHouseFrame", "AuctionFrame" },
    labelKey = "WIN_AUCTION",
    category = "CAT_CRAFT_ECON",
    defaultCompactScale = 0.78,
})

-- Class & Profession Trainer
Registry:RegisterWindow("TRAINER", {
    addon = "Blizzard_TrainerUI",
    frame = "ClassTrainerFrame",
    labelKey = "WIN_TRAINER",
    category = "CAT_CHARACTER",
    defaultCompactScale = 0.82,
})

-- Mounts, Pets, Toys & Heirlooms
Registry:RegisterWindow("COLLECTIONS", {
    addon = "Blizzard_Collections",
    frame = "CollectionsJournal",
    labelKey = "WIN_COLLECTIONS",
    category = "CAT_SOCIAL",
    defaultCompactScale = 0.78,
    protected = true,
})

-- Guild & Communities
Registry:RegisterWindow("COMMUNITIES", {
    addon = "Blizzard_Communities",
    frame = "CommunitiesFrame",
    labelKey = "WIN_COMMUNITIES",
    category = "CAT_SOCIAL",
    defaultCompactScale = 0.78,
    protected = true,
})

-- Dungeon & Adventure Guide
Registry:RegisterWindow("ENCOUNTER_JOURNAL", {
    addon = "Blizzard_EncounterJournal",
    frame = "EncounterJournal",
    labelKey = "WIN_ENCOUNTER_JOURNAL",
    category = "CAT_SOCIAL",
    defaultCompactScale = 0.80,
    protected = true,
})

-- Inspect Player
Registry:RegisterWindow("INSPECT", {
    addon = "Blizzard_InspectUI",
    frame = "InspectFrame",
    labelKey = "WIN_INSPECT",
    category = "CAT_CHARACTER",
    defaultCompactScale = 0.85,
})

-- Calendar
Registry:RegisterWindow("CALENDAR", {
    addon = "Blizzard_Calendar",
    frame = "CalendarFrame",
    labelKey = "WIN_CALENDAR",
    category = "CAT_SOCIAL",
    defaultCompactScale = 0.82,
})

-- Macros
Registry:RegisterWindow("MACRO", {
    addon = "Blizzard_MacroUI",
    frame = "MacroFrame",
    labelKey = "WIN_MACRO",
    category = "CAT_CHARACTER",
    defaultCompactScale = 0.84,
    protected = true,
})
