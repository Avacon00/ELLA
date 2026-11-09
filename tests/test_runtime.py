"""Regression tests execute original modules in isolated Lua 5.1 runtimes.

Install tests/requirements.txt and run:
    python3 -m unittest discover -s tests -p 'test_*.py'

Frame doubles exercise logic, not native WoW rendering, taint or combat security.
"""
from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parent.parent
MODULES = (
    "Locales/enUS.lua", "Locales/deDE.lua", "Core/Init.lua", "Core/Guard.lua",
    "Core/Registry.lua", "Core/Engine.lua", "Core/Profiles.lua", "API/PublicAPI.lua",
)


def new_runtime(locale="enUS"):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().clientLocale = locale
    lua.execute((ROOT / "tests/wow_stub.lua").read_text(encoding="utf-8"))
    lua.globals().ns = lua.table()
    compile_lua = lua.eval("function(source, name) return assert(loadstring(source, name)) end")
    for file in MODULES:
        compile_lua((ROOT / file).read_text(encoding="utf-8"), "@" + file)("ELLA", lua.globals().ns)
    lua.execute("ns:InitDatabase(); ns.Profiles:Init(); ns.Registry:EnableBindingAndScan()")
    return lua


class RuntimeTests(unittest.TestCase):
    def check_lua(self, source, locale="enUS"):
        lua = new_runtime(locale)
        lua.execute(source)
        self.assertEqual(list(lua.globals().errors.values()), [], "Suppressed callback error")

    def test_all_toc_lua_files_compile_with_lua51(self):
        lua = LuaRuntime()
        self.assertEqual(lua.eval("_VERSION"), "Lua 5.1")
        compile_lua = lua.eval("function(source, name) return assert(loadstring(source, name)) end")
        count = 0
        for line in (ROOT / "ELLA.toc").read_text(encoding="utf-8").splitlines():
            relative = line.strip().replace("\\", "/")
            if relative.endswith(".lua") and not relative.startswith("#"):
                with self.subTest(file=relative):
                    compile_lua((ROOT / relative).read_text(encoding="utf-8"), "@" + relative)
                count += 1
        self.assertGreater(count, 0)

    def test_profile_collision_preserves_target_active_profile_checkpoint_and_undo(self):
        self.check_lua('''
            RegisterTestWindow("WINDOW")
            ns.Profiles:CreateOrCopyProfile("Raid", true)
            ns.Engine:SetWindowScale("WINDOW", .65)
            ns.Profiles:SaveActiveProfileSnapshot(true)
            local raid = ns.db.profiles.Raid
            local windows, saved = raid.windows, raid.savedSnapshot
            ns.Profiles:SwitchProfile("Default", true)
            ns.Engine:SetWindowScale("WINDOW", .8)
            local activeWindows = ns.db.windows
            local switches = 0
            ns:On("OnProfileSwitched", function() switches = switches + 1 end)
            local ok, reason = ns.Profiles:CreateOrCopyProfile("Raid", true)
            assert(ok == false and reason == "profile_exists")
            assert(ns.db.profiles.Raid == raid and raid.windows == windows and raid.savedSnapshot == saved)
            assert(windows.WINDOW.scale == .65 and saved.WINDOW.scale == .65)
            assert(ns.db.activeProfile == "Default" and ns.db.windows == activeWindows)
            assert(activeWindows.WINDOW.scale == .8 and switches == 0)
            assert(ns.Profiles:CanUndo() and ns.Profiles:UndoLastChange())
            assert(ns.db.windows.WINDOW.scale == 1)
        ''')

    def test_normalized_default_collision_is_rejected_with_localized_message(self):
        for locale in ("enUS", "deDE"):
            with self.subTest(locale=locale):
                self.check_lua('''
                    local original = ns.db.profiles.Default
                    local before = #messages
                    local ok, reason = ns.Profiles:CreateOrCopyProfile("  :Default;  ", true)
                    assert(ok == false and reason == "profile_exists")
                    assert(ns.db.profiles.Default == original)
                    assert(#messages == before + 1)
                    assert(string.find(messages[#messages], string.format(ns.L.UI_PROFILE_EXISTS, "Default"), 1, true))
                ''', locale)

    def test_collision_with_active_profile_keeps_its_saved_checkpoint(self):
        self.check_lua('''
            RegisterTestWindow("WINDOW")
            ns.Engine:SetWindowScale("WINDOW", .8)
            ns.Profiles:SaveActiveProfileSnapshot(true)
            ns.Engine:SetWindowScale("WINDOW", .7)
            local profile = ns.db.profiles.Default
            assert(ns.Profiles:CreateOrCopyProfile("Default", true) == false)
            assert(ns.db.profiles.Default == profile)
            assert(profile.windows.WINDOW.scale == .7 and profile.savedSnapshot.WINDOW.scale == .8)
        ''')

    def test_new_profile_copy_keeps_source_and_copies_nested_position(self):
        self.check_lua('''
            RegisterTestWindow("WINDOW")
            ns.Engine:SetWindowScale("WINDOW", .8)
            ns:GetWindowConfig("WINDOW", true).pos = { uipX = 100, uipY = -100 }
            local source = ns.db.windows
            assert(ns.Profiles:CreateOrCopyProfile("  New;:Profile  ", true))
            assert(ns.db.activeProfile == "NewProfile" and ns.db.windows ~= source)
            assert(ns.db.windows.WINDOW.scale == .8 and ns.db.windows.WINDOW.pos ~= source.WINDOW.pos)
            ns.db.windows.WINDOW.pos.uipX = 200
            assert(source.WINDOW.pos.uipX == 100)
            assert(ns.db.profiles.NewProfile.savedSnapshot.WINDOW.pos.uipX == 100)
        ''')

    def test_new_empty_profile_and_invalid_names(self):
        self.check_lua('''
            RegisterTestWindow("WINDOW")
            ns.Engine:SetWindowScale("WINDOW", .8)
            local source = ns.db.profiles.Default
            assert(ns.Profiles:CreateOrCopyProfile("Empty", false))
            assert(next(ns.db.windows) == nil and source.windows.WINDOW.scale == .8)
            assert(ns.Profiles:CreateOrCopyProfile(" ;: ", true) == false)
            assert(ns.Profiles:CreateOrCopyProfile(nil, true) == false)
            assert(ns.db.activeProfile == "Empty")
        ''')

    def test_api_unknown_window_returns_error_without_config_event_or_undo(self):
        self.check_lua('''
            local events = 0
            ns:On("OnWindowConfigChanged", function() events = events + 1 end)
            for _, setter in ipairs({ ELLA_API.SetWindowEnabled, ELLA_API.SetWindowBadgeHidden }) do
                local ok, reason = setter(ELLA_API, "MISSING", true)
                assert(ok == false and reason == "unknown_window")
            end
            assert(ns:GetWindowConfig("MISSING", false) == nil)
            assert(events == 0 and not ns.Profiles:CanUndo())
        ''')

    def test_api_valid_setters_apply_config_and_return_success(self):
        self.check_lua('''
            RegisterTestWindow("WINDOW")
            assert(ELLA_API:SetWindowEnabled("WINDOW", false) == true)
            assert(ns:GetWindowConfig("WINDOW", false).mode == ns.MODE_DISABLED)
            assert(ELLA_API:SetWindowEnabled("WINDOW", true) == true)
            assert(ns:GetWindowConfig("WINDOW", false).mode == ns.MODE_SCALE_MOVE)
            assert(ELLA_API:SetWindowBadgeHidden("WINDOW", true) == true)
            assert(ns:GetWindowConfig("WINDOW", false).hideBadge == true)
            assert(ELLA_API:SetWindowBadgeHidden("WINDOW", false) == true)
            assert(ns:GetWindowConfig("WINDOW", false).hideBadge == false)
        ''')

    def test_api_success_accepts_config_while_frame_restore_is_deferred(self):
        self.check_lua('''
            local frame = RegisterTestWindow("WINDOW", { protected = true })
            ns.Engine:SetWindowScale("WINDOW", .8)
            combat = true
            assert(ELLA_API:SetWindowEnabled("WINDOW", false) == true)
            assert(ns:GetWindowConfig("WINDOW", false).mode == ns.MODE_DISABLED)
            assert(frame:GetScale() == .8 and ns.Guard:HasQueuedTasks())
            combat = false
            ns.Guard:FlushCombatQueue()
            assert(frame:GetScale() == 1 and not ns.Guard:HasQueuedTasks())
        ''')

    def test_drag_restores_default_alpha_on_mouse_release_repeatedly(self):
        self.check_lua('''
            local frame, desc = RegisterTestWindow("WINDOW")
            for i = 1, 3 do
                ns.Engine:StartWindowDrag("WINDOW", frame, desc)
                assert(frame:GetAlpha() == .78)
                frame:Run("OnMouseUp", "LeftButton")
                assert(frame:GetAlpha() == 1)
                assert(not ns.Engine:GetManagedState(frame).isDragging)
            end
        ''')

    def test_drag_preserves_native_alpha_and_does_not_claim_permanent_ownership(self):
        self.check_lua('''
            local frame, desc = RegisterTestWindow("WINDOW", { alpha = .9 })
            ns.Engine:StartWindowDrag("WINDOW", frame, desc)
            ns.Engine:StopActiveDrag()
            assert(frame:GetAlpha() == .9)
            ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(frame:GetAlpha() == .9)
        ''')

    def test_drag_keeps_configured_alpha_and_original_native_restore(self):
        self.check_lua('''
            local frame, desc = RegisterTestWindow("WINDOW", { alpha = .9 })
            ns.Engine:SetWindowAlpha("WINDOW", .5, false)
            ns.Engine:StartWindowDrag("WINDOW", frame, desc)
            ns.Engine:StopActiveDrag()
            assert(frame:GetAlpha() == .5)
            ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(frame:GetAlpha() == .9)
        ''')

    def test_drag_without_opacity_does_not_write_alpha(self):
        self.check_lua('''
            local frame, desc = RegisterTestWindow("WINDOW", { alpha = .9 })
            ns.db.settings.dragOpacity = false
            local writes = frame.alphaWrites
            ns.Engine:StartWindowDrag("WINDOW", frame, desc)
            ns.Engine:StopActiveDrag()
            assert(frame:GetAlpha() == .9 and frame.alphaWrites == writes)
        ''')

    def test_drag_restores_opacity_even_if_setting_disabled_before_mouse_release(self):
        self.check_lua('''
            local frame, desc = RegisterTestWindow("WINDOW")
            ns.Engine:StartWindowDrag("WINDOW", frame, desc)
            ns.db.settings.dragOpacity = false
            ns.Engine:StopActiveDrag()
            assert(frame:GetAlpha() == 1)
        ''')

    def test_drag_does_not_restore_alpha_it_never_changed(self):
        self.check_lua('''
            local frame, desc = RegisterTestWindow("WINDOW")
            ns.db.settings.dragOpacity = false
            ns.Engine:StartWindowDrag("WINDOW", frame, desc)
            frame:SetAlpha(.92) -- The owning AddOn updates its own alpha during the drag.
            ns.Engine:StopActiveDrag()
            assert(frame:GetAlpha() == .92)
        ''')

    def test_already_transparent_native_frame_keeps_external_alpha_update(self):
        self.check_lua('''
            local frame, desc = RegisterTestWindow("WINDOW", { alpha = .6 })
            local writes = frame.alphaWrites
            ns.Engine:StartWindowDrag("WINDOW", frame, desc)
            assert(frame:GetAlpha() == .6 and frame.alphaWrites == writes)
            frame:SetAlpha(.7)
            ns.Engine:StopActiveDrag()
            assert(frame:GetAlpha() == .7 and frame.alphaWrites == writes + 1)
        ''')

    def test_alpha_change_during_drag_captures_pristine_native_alpha(self):
        self.check_lua('''
            local frame, desc = RegisterTestWindow("WINDOW", { alpha = .9 })
            ns.Engine:StartWindowDrag("WINDOW", frame, desc)
            ns.Engine:SetWindowAlpha("WINDOW", .6, false)
            ns.Engine:StopActiveDrag()
            assert(frame:GetAlpha() == .6)
            ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(frame:GetAlpha() == .9)
        ''')

    def test_drag_reapplies_fade_for_current_mouseover_state(self):
        for mouseover in ("true", "false"):
            with self.subTest(mouseover=mouseover):
                self.check_lua('''
                    local frame, desc = RegisterTestWindow("WINDOW")
                    ns.Engine:SetWindowAlpha("WINDOW", .4, true)
                    frame.mouseover = true
                    frame:Run("OnEnter")
                    ns.Engine:StartWindowDrag("WINDOW", frame, desc)
                    frame.mouseover = ''' + mouseover + '''
                    ns.Engine:StopActiveDrag()
                    assert(frame:GetAlpha() == (frame.mouseover and 1 or .4))
                ''')

    def test_sticky_group_restores_each_native_alpha_even_when_alt_detached(self):
        for detached in ("true", "false"):
            with self.subTest(detached=detached):
                self.check_lua('''
                    local frame, desc = RegisterTestWindow("A")
                    local other = RegisterTestWindow("B", { alpha = .9, left = 456 })
                    ns.Engine:StartWindowDrag("A", frame, desc)
                    assert(frame:GetAlpha() == .78 and other:GetAlpha() == .78)
                    alt = ''' + detached + '''
                    ns.Engine:StopActiveDrag()
                    assert(frame:GetAlpha() == 1 and other:GetAlpha() == .9)
                ''')

    def test_hiding_dragged_frame_restores_alpha(self):
        self.check_lua('''
            local frame, desc = RegisterTestWindow("WINDOW")
            ns.Engine:StartWindowDrag("WINDOW", frame, desc)
            frame:Hide()
            assert(frame:GetAlpha() == 1 and not ns.Engine:GetManagedState(frame).isDragging)
        ''')

    def test_sticky_group_keeps_unmodified_transparent_member_alpha_update(self):
        self.check_lua('''
            local frame, desc = RegisterTestWindow("A")
            local other = RegisterTestWindow("B", { alpha = .6, left = 456 })
            local writes = other.alphaWrites
            ns.Engine:StartWindowDrag("A", frame, desc)
            assert(other:GetAlpha() == .6 and other.alphaWrites == writes)
            other:SetAlpha(.7)
            ns.Engine:StopActiveDrag()
            assert(frame:GetAlpha() == 1 and other:GetAlpha() == .7)
            assert(other.alphaWrites == writes + 1)
        ''')

    def test_global_disable_during_drag_still_restores_temporary_alpha(self):
        self.check_lua('''
            local frame, desc = RegisterTestWindow("WINDOW", { alpha = .9 })
            ns.Engine:StartWindowDrag("WINDOW", frame, desc)
            ns.db.settings.enabled = false
            ns.Engine:ReapplyAllShown()
            ns.Engine:StopActiveDrag()
            assert(frame:GetAlpha() == .9)
        ''')


if __name__ == "__main__":
    unittest.main()
