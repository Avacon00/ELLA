std = "lua51"

max_line_length = 160
unused_args = false

globals = {
    -- EĹLA documented globals (Golden Rule #6)
    "ELLADB",
    "ELLA_API",
    "SLASH_ELLA1",
    "SLASH_ELLA2",
}

read_globals = {
    -- WoW Lua 5.1 & Interface 16001 (Project Camelot) API
    "LibStub",
    "WOW_PROJECT_ID",
    "WOW_PROJECT_CAMELOT",
    "UIParent",
    "WorldFrame",
    "DEFAULT_CHAT_FRAME",
    "GameTooltip",
    "Settings",
    "SettingsPanel",
    "AddonCompartmentFrame",
    "BackdropTemplateMixin",
    "EventUtil",
    "SlashCmdList",
    "CreateFrame",
    "GetLocale",
    "GetTime",
    "GetCursorPosition",
    "GetMouseFoci",
    "GetMouseFocus",
    "HideUIPanel",
    "InCombatLockdown",
    "IsControlKeyDown",
    "IsShiftKeyDown",
    "IsModifierKeyDown",
    "IsMouseButtonDown",
    "hooksecurefunc",
    "geterrorhandler",
    "wipe",
}

files["Libs/**/*.lua"] = {
    ignore = { "111", "113", "212" },
}
