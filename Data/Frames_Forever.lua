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
