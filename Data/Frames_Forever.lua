local AddonName, ns = ...

local Registry = ns.Registry

-- ============================================================================
-- World of Warcraft: Forever (Project Camelot / Interface 16001) Panels
-- Community contributors: Add newly introduced Forever patch windows here!
-- Missing candidates stay completely dormant with 0 errors until loaded.
-- ============================================================================

-- Account-wide Legacy Skill Trees & Challenges (Adventure / Resourcefulness)
Registry:RegisterWindow("FOREVER_LEGACY", {
    addon = "Blizzard_LegacyUI",
    candidates = {
        "LegacyFrame",
        "LegacyTreeFrame",
        "CamelotLegacyFrame",
    },
    labelKey = "WIN_LEGACY_TREE",
    category = "CAT_FOREVER",
    defaultCompactScale = 0.80,
    protected = true,
})

-- Cooperative Camping System & Profession Camp Blueprints
Registry:RegisterWindow("FOREVER_CAMPING", {
    addon = "Blizzard_CampingUI",
    candidates = {
        "CampingFrame",
        "CampfireManagementFrame",
        "BlueprintJournalFrame",
    },
    labelKey = "WIN_CAMPING_UI",
    category = "CAT_FOREVER",
    defaultCompactScale = 0.82,
})

-- New Azeroth Factions / Renown-style Quartermaster Summary (14 Forever Factions)
Registry:RegisterWindow("FOREVER_FACTIONS", {
    addon = "Blizzard_MajorFactions",
    candidates = {
        "MajorFactionRenownFrame",
        "FactionOverviewFrame",
        "CamelotFactionFrame",
    },
    labelKey = "WIN_FACTION_QUARTERMASTER",
    category = "CAT_FOREVER",
    defaultCompactScale = 0.82,
})

-- ============================================================================
-- Pre-Registered Community & Quality-of-Life AddOns (Out-of-the-Box)
-- When not installed: 0.00 ms CPU, 0 bytes RAM (dormant candidates).
-- When loaded: Instantly provides %-badge, mouse-wheel zoom & manager control.
-- ============================================================================

Registry:RegisterBatch(nil, {
    COMM_DETAILS = {
        candidates = { "DetailsBaseWindow1", "_detalhes" },
        labelKey = "WIN_COMM_DETAILS",
        category = "CAT_CUSTOM",
        defaultCompactScale = 0.85,
    },
    COMM_QUESTIE = {
        candidates = { "Questie_BaseFrame", "QuestieFrame", "QuestieTracker" },
        labelKey = "WIN_COMM_QUESTIE",
        category = "CAT_CUSTOM",
        defaultCompactScale = 0.85,
    },
    COMM_BAGNON = {
        candidates = { "BagnonFrameinventory", "BagnonFramebank", "Baganator_CategoryView_BackpackViewFrame", "Baganator_SingleView_BackpackViewFrame" },
        labelKey = "WIN_COMM_BAGNON",
        category = "CAT_CUSTOM",
        defaultCompactScale = 0.85,
    },
    COMM_THREAT = {
        candidates = { "ThreatClassic2BarFrame", "ThreatClassicFrame" },
        labelKey = "WIN_COMM_THREAT",
        category = "CAT_CUSTOM",
        defaultCompactScale = 0.85,
    },
    COMM_TOMTOM = {
        candidates = { "TomTomBlock" },
        labelKey = "WIN_COMM_TOMTOM",
        category = "CAT_CUSTOM",
        defaultCompactScale = 0.90,
    },
    COMM_WEAKAURAS = {
        candidates = { "WeakAurasOptions" },
        labelKey = "WIN_COMM_WEAKAURAS",
        category = "CAT_CUSTOM",
        defaultCompactScale = 0.85,
    },
    COMM_AUCTIONATOR = {
        candidates = { "AuctionatorShoppingFrame", "AuctionatorConfigFrame" },
        labelKey = "WIN_COMM_AUCTIONATOR",
        category = "CAT_CUSTOM",
        defaultCompactScale = 0.85,
    },
    COMM_ATLASLOOT = {
        candidates = { "AtlasLoot_GUI-Frame", "AtlasLootDefaultFrame" },
        labelKey = "WIN_COMM_ATLASLOOT",
        category = "CAT_CUSTOM",
        defaultCompactScale = 0.82,
    },
    COMM_POSTAL = {
        candidates = { "Postal_OpenAllMenu" },
        labelKey = "WIN_COMM_POSTAL",
        category = "CAT_CUSTOM",
        defaultCompactScale = 0.90,
    },
})
