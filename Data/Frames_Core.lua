local AddonName, ns = ...

local Registry = ns.Registry

-- ============================================================================
-- Core Always-Loaded Blizzard Windows
-- Contributors: Add standard UIPanels here using declarative fields only.
-- ============================================================================

Registry:RegisterBatch(nil, {
    CHARACTER = {
        frame = "CharacterFrame",
        labelKey = "WIN_CHARACTER",
        category = "CAT_CHARACTER",
        defaultCompactScale = 0.85,
        protected = true,
        linkedFrames = { "TokenFramePopup", "GearManagerDialogPopup", "ReputationDetailFrame" },
    },
    QUESTLOG = {
        candidates = { "QuestLogFrame", "QuestLogPopupDetailFrame" },
        labelKey = "WIN_QUESTLOG",
        category = "CAT_QUEST_WORLD",
        defaultCompactScale = 0.82,
    },
    QUESTMAP = {
        frame = "WorldMapFrame",
        labelKey = "WIN_QUESTMAP",
        category = "CAT_QUEST_WORLD",
        defaultCompactScale = 0.82,
        protected = true,
        dragSubFrames = { "BorderFrame", "NavBar" },
        linkedFrames = { "QuestLogPopupDetailFrame" },
    },
    QUEST_DIALOG = {
        frame = "QuestFrame",
        labelKey = "WIN_QUEST_DIALOG",
        category = "CAT_QUEST_WORLD",
        defaultCompactScale = 0.85,
    },
    GOSSIP = {
        frame = "GossipFrame",
        labelKey = "WIN_GOSSIP",
        category = "CAT_QUEST_WORLD",
        defaultCompactScale = 0.85,
    },
    MERCHANT = {
        frame = "MerchantFrame",
        labelKey = "WIN_MERCHANT",
        category = "CAT_CRAFT_ECON",
        defaultCompactScale = 0.85,
    },
    MAIL = {
        frame = "MailFrame",
        labelKey = "WIN_MAIL",
        category = "CAT_CRAFT_ECON",
        defaultCompactScale = 0.85,
    },
    BANK = {
        candidates = { "BankFrame" },
        labelKey = "WIN_BANK",
        category = "CAT_CRAFT_ECON",
        defaultCompactScale = 0.82,
    },
    DRESSUP = {
        frame = "DressUpFrame",
        labelKey = "WIN_DRESSUP",
        category = "CAT_CHARACTER",
        defaultCompactScale = 0.84,
        linkedFrames = { "SideDressUpFrame" },
    },
    FRIENDS = {
        frame = "FriendsFrame",
        labelKey = "WIN_FRIENDS",
        category = "CAT_SOCIAL",
        defaultCompactScale = 0.84,
        linkedFrames = { "AddFriendFrame", "FriendsFriendsFrame" },
    },
    GROUP_FINDER = {
        candidates = { "PVEFrame", "LFGParentFrame" },
        labelKey = "WIN_GROUP_FINDER",
        category = "CAT_SOCIAL",
        defaultCompactScale = 0.82,
        protected = true,
    },
    ITEMTEXT = {
        frame = "ItemTextFrame",
        labelKey = "WIN_ITEMTEXT",
        category = "CAT_QUEST_WORLD",
        defaultCompactScale = 0.85,
    },
    TAXI = {
        candidates = { "TaxiFrame", "FlightMapFrame" },
        labelKey = "WIN_TAXI",
        category = "CAT_QUEST_WORLD",
        defaultCompactScale = 0.85,
    },
    LOOT = {
        frame = "LootFrame",
        labelKey = "WIN_LOOT",
        category = "CAT_QUEST_WORLD",
        defaultCompactScale = 0.88,
    },
    TABARD = {
        frame = "TabardFrame",
        labelKey = "WIN_TABARD",
        category = "CAT_CHARACTER",
        defaultCompactScale = 0.85,
    },
})
