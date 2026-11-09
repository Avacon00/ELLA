"""Guard hierarchy and linked-scale ownership regressions (#16, #19)."""
import unittest

from test_runtime import new_runtime


class HierarchyTests(unittest.TestCase):
    def check_lua(self, source):
        lua = new_runtime()
        lua.execute(source)
        self.assertEqual(list(lua.globals().errors.values()), [])

    def test_blacklisted_roots_and_their_children_are_blocked(self):
        self.check_lua('''
            for _, name in ipairs({"PlayerFrame", "MainMenuBar", "RightManagedFrameContainer", "WorldFrame"}) do
                local root = CreateFrame("Frame", name, UIParent)
                local child = CreateFrame("Frame", name .. "Child", root)
                local grandchild = CreateFrame("Frame", nil, child)
                assert(ns.Guard:ValidateTarget(root) == false)
                local ok, reason = ns.Guard:ValidateTarget(grandchild)
                assert(ok == false and reason == ns.L.GUARD_ERR_EDITMODE)
            end
        ''')

    def test_dynamic_editmode_ancestor_blocks_child(self):
        self.check_lua('''
            local root = CreateFrame("Frame", "DynamicSystem", UIParent)
            root.systemIndex = 0
            root.HighlightSystem = function() end
            local child = CreateFrame("Frame", "DynamicChild", root)
            assert(ns.Guard:ValidateTarget(child) == false)
        ''')

    def test_uiparent_is_forbidden_as_target_but_allowed_as_ancestor(self):
        self.check_lua('''
            local container = CreateFrame("Frame", "AddonContainer", UIParent)
            local child = CreateFrame("Frame", nil, container)
            UIParent.GetParent = function() error("must stop at UIParent") end
            assert(ns.Guard:ValidateTarget(UIParent) == false)
            assert(ns.Guard:ValidateTarget(container) == true)
            assert(ns.Guard:ValidateTarget(child) == true)
        ''')

    def test_forbidden_ancestor_is_not_inspected_further(self):
        self.check_lua('''
            local root = CreateFrame("Frame", "ForbiddenContainer", UIParent)
            root.forbidden = true
            root.GetName = function() error("forbidden name access") end
            root.GetParent = function() error("forbidden parent access") end
            local child = CreateFrame("Frame", "SafeLookingChild", root)
            local ok, reason = ns.Guard:ValidateTarget(child)
            assert(ok == false and reason == ns.L.GUARD_ERR_FORBIDDEN)
        ''')

    def test_broken_parent_or_name_getters_fail_closed(self):
        for getter in ("GetName", "GetParent"):
            with self.subTest(getter=getter):
                self.check_lua('''
                    local root = CreateFrame("Frame", "BrokenContainer", UIParent)
                    root.''' + getter + ''' = function() error("unreadable hierarchy") end
                    local child = CreateFrame("Frame", "Child", root)
                    local ok, reason = ns.Guard:ValidateTarget(child)
                    assert(ok == false and reason == ns.L.GUARD_ERR_HIERARCHY)
                ''')

    def test_missing_parent_getter_or_invalid_parent_fails_closed(self):
        self.check_lua('''
            local frame = CreateFrame("Frame", "BadParent", UIParent)
            frame.GetParent = false
            assert(ns.Guard:ValidateTarget(frame) == false)
            frame.GetParent = function() return "not a frame" end
            assert(ns.Guard:ValidateTarget(frame) == false)
        ''')

    def test_parent_cycle_is_rejected(self):
        self.check_lua('''
            local first = CreateFrame("Frame", "First", UIParent)
            local second = CreateFrame("Frame", "Second", first)
            first.parent = second
            local ok, reason = ns.Guard:ValidateTarget(first)
            assert(ok == false and reason == ns.L.GUARD_ERR_HIERARCHY)
        ''')

    def test_hierarchy_depth_is_bounded(self):
        self.check_lua('''
            local parent = UIParent
            for i = 1, 64 do parent = CreateFrame("Frame", nil, parent) end
            assert(ns.Guard:ValidateTarget(parent) == true)
            local tooDeep = CreateFrame("Frame", "TooDeep", parent)
            assert(ns.Guard:ValidateTarget(tooDeep) == false)
        ''')

    def test_registry_does_not_bind_hud_child(self):
        self.check_lua('''
            local root = CreateFrame("Frame", "PlayerFrame", UIParent)
            local child = CreateFrame("Frame", "PlayerFrameHealthBar", root)
            ns.Registry:RegisterWindow("CUSTOM_HUD", { frame = "PlayerFrameHealthBar", isCustom = true })
            assert(ns.Registry:GetDescriptor("CUSTOM_HUD").boundFrame == nil)
            assert(child:GetScale() == 1 and child.scaleWrites == 0)
        ''')

    def test_engine_rechecks_ancestor_after_reparenting(self):
        self.check_lua('''
            local frame = RegisterTestWindow("WINDOW")
            frame.parent = CreateFrame("Frame", "PlayerFrame", UIParent)
            assert(ns.Engine:SetWindowScale("WINDOW", .5) == false)
            assert(frame:GetScale() == 1 and frame.scaleWrites == 0)
        ''')

    def test_protected_normal_ancestor_still_defers_in_combat(self):
        self.check_lua('''
            local parent = CreateFrame("Frame", "SecureAddonContainer", UIParent)
            parent.protected = true
            local child = CreateFrame("Frame", "AddonChild", parent)
            assert(ns.Guard:ValidateTarget(child) == true)
            combat = true
            local ok, reason = ns.Guard:CanModifyNow(child)
            assert(ok == false and reason == "DEFERRED_COMBAT")
        ''')


LINKED_SETUP = '''
    function LinkedPair(options)
        options = options or {}
        local child = CreateFrame("Frame", "LinkedChild", UIParent)
        child.scale = options.childScale or .6
        child.protected = options.childProtected
        local main = CreateFrame("Frame", "LinkedMain", UIParent)
        main.scale = options.mainScale or 1
        main.protected = options.mainProtected
        ns.Registry:RegisterWindow("WINDOW", {
            frame = "LinkedMain", linkedFrames = {"LinkedChild"},
            protected = options.mainProtected, defaultMode = options.defaultMode,
        })
        return main, child, ns.Registry:GetDescriptor("WINDOW")
    end
'''


class LinkedFrameTests(unittest.TestCase):
    def check_lua(self, source):
        lua = new_runtime()
        lua.execute(LINKED_SETUP + source)
        self.assertEqual(list(lua.globals().errors.values()), [])

    def test_disable_restores_linked_only_changes_without_touching_main(self):
        self.check_lua('''
            local main, child = LinkedPair()
            assert(main:GetScale() == 1 and child:GetScale() == 1)
            ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(child:GetScale() == .6)
            assert(main:GetScale() == 1 and main.scaleWrites == 0)
        ''')

    def test_main_and_multiple_children_keep_distinct_original_scales(self):
        self.check_lua('''
            local main, first, desc = LinkedPair({mainScale = .9})
            local second = CreateFrame("Frame", "SecondLinkedChild", UIParent)
            second.scale = .7
            local untouched = CreateFrame("Frame", "UntouchedChild", UIParent)
            desc.linkedFrames = {"LinkedChild", "SecondLinkedChild", "UntouchedChild", "LinkedMain"}
            ns.Engine:ReapplyAllShown()
            ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(main:GetScale() == .9 and first:GetScale() == .6 and second:GetScale() == .7)
            assert(untouched:GetScale() == 1 and untouched.scaleWrites == 0)
        ''')

    def test_global_disable_restores_companion(self):
        self.check_lua('''
            local main, child = LinkedPair()
            ns.db.settings.enabled = false
            ns.Engine:ReapplyAllShown()
            assert(child:GetScale() == .6 and main.scaleWrites == 0)
        ''')

    def test_disabled_from_start_never_touches_companion(self):
        self.check_lua('''
            local main, child = LinkedPair({defaultMode = ns.MODE_DISABLED})
            ns.Engine:ReapplyAllShown()
            child:Hide(); child:Show()
            assert(child:GetScale() == .6 and child.scaleWrites == 0 and main.scaleWrites == 0)
            assert(child.hooks.OnShow == nil)
            child.scale = .7 -- Its native owner updates scale before opting in.
            ns.Engine:SetWindowEnabled("WINDOW", true)
            ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(child:GetScale() == .7)
        ''')

    def test_protected_companion_restore_is_queued_with_unprotected_main(self):
        self.check_lua('''
            local main, child = LinkedPair({childProtected = true})
            combat = true
            local writes = child.scaleWrites
            ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(child:GetScale() == 1 and child.scaleWrites == writes)
            assert(ns.Guard:HasQueuedTasks())
            combat = false; ns.Guard:FlushCombatQueue()
            assert(child:GetScale() == .6 and main.scaleWrites == 0)
            assert(not ns.Guard:HasQueuedTasks())
        ''')

    def test_protected_main_defers_parent_and_companion_restore(self):
        self.check_lua('''
            local main, child = LinkedPair({mainProtected = true})
            combat = true
            ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(child:GetScale() == 1 and ns.Guard:HasQueuedTasks())
            combat = false; ns.Guard:FlushCombatQueue()
            assert(child:GetScale() == .6 and main:GetScale() == 1)
        ''')

    def test_multiple_protected_companions_restore_after_combat(self):
        self.check_lua('''
            local main, first, desc = LinkedPair({childProtected = true})
            local second = CreateFrame("Frame", "SecondChild", UIParent)
            second.scale = .9; second.protected = true
            desc.linkedFrames = {"LinkedChild", "SecondChild"}
            ns.Engine:ReapplyAllShown()
            combat = true; ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(ns.Guard:HasQueuedTasks())
            combat = false; ns.Guard:FlushCombatQueue()
            assert(first:GetScale() == .6 and second:GetScale() == .9 and main.scaleWrites == 0)
            assert(not ns.Guard:HasQueuedTasks())
        ''')

    def test_queue_uses_current_config_if_reenabled_before_combat_ends(self):
        self.check_lua('''
            local main, child = LinkedPair({childProtected = true})
            combat = true
            ns.Engine:SetWindowEnabled("WINDOW", false)
            ns.Engine:SetWindowEnabled("WINDOW", true)
            ns.Engine:SetWindowScale("WINDOW", .8)
            combat = false; ns.Guard:FlushCombatQueue()
            assert(main:GetScale() == .8 and child:GetScale() == .8)
            ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(child:GetScale() == .6)
        ''')

    def test_restored_child_is_hands_off_on_later_show(self):
        self.check_lua('''
            local main, child = LinkedPair()
            ns.Engine:SetWindowEnabled("WINDOW", false)
            child:SetScale(.9)
            local writes = child.scaleWrites
            child:Hide(); child:Show()
            ns.Engine:ReapplyAllShown()
            assert(child:GetScale() == .9 and child.scaleWrites == writes)
        ''')

    def test_hidden_parent_does_not_prevent_deferred_companion_restore(self):
        self.check_lua('''
            local main, child = LinkedPair({childProtected = true})
            main:Hide()
            combat = true; ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(ns.Guard:HasQueuedTasks())
            combat = false; ns.Guard:FlushCombatQueue()
            assert(child:GetScale() == .6)
        ''')

    def test_forbidden_companion_waits_until_safe_before_restoring(self):
        self.check_lua('''
            local main, child = LinkedPair()
            child.forbidden = true
            local writes = child.scaleWrites
            ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(child.scaleWrites == writes and not ns.Guard:HasQueuedTasks())
            child.forbidden = false
            child:Hide(); child:Show()
            assert(child:GetScale() == .6)
        ''')

    def test_child_reparented_under_hud_cannot_be_restored_through_guard(self):
        self.check_lua('''
            local main, child = LinkedPair()
            child.parent = CreateFrame("Frame", "PlayerFrame", UIParent)
            local writes = child.scaleWrites
            ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(child.scaleWrites == writes)
            child.parent = UIParent
            child:Hide(); child:Show()
            assert(child:GetScale() == .6)
        ''')

    def test_primary_and_linked_ownership_do_not_share_native_scale_snapshots(self):
        self.check_lua('''
            local child = RegisterTestWindow("CHILD")
            ns.Engine:SetWindowScale("CHILD", .8)
            local main = CreateFrame("Frame", "OtherMain", UIParent)
            ns.Registry:RegisterWindow("WINDOW", { frame = "OtherMain", linkedFrames = {child:GetName()} })
            assert(child:GetScale() == 1)
            ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(child:GetScale() == .8)
            ns.Engine:SetWindowEnabled("CHILD", false)
            assert(child:GetScale() == 1)
        ''')

    def test_primary_then_companion_disable_restores_true_native_scale(self):
        self.check_lua('''
            local child = RegisterTestWindow("CHILD")
            ns.Engine:SetWindowScale("CHILD", .8)
            local main = CreateFrame("Frame", "OtherMain", UIParent)
            ns.Registry:RegisterWindow("WINDOW", { frame = "OtherMain", linkedFrames = {child:GetName()} })
            ns.Engine:SetWindowEnabled("CHILD", false)
            ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(child:GetScale() == 1)
        ''')

    def test_global_disable_with_primary_and_linked_roles_restores_native_scale(self):
        self.check_lua('''
            local child = RegisterTestWindow("CHILD")
            ns.Engine:SetWindowScale("CHILD", .8)
            local main = CreateFrame("Frame", "OtherMain", UIParent)
            ns.Registry:RegisterWindow("WINDOW", { frame = "OtherMain", linkedFrames = {child:GetName()} })
            ns.db.settings.enabled = false
            ns.Engine:ReapplyAllShown()
            assert(child:GetScale() == 1)
        ''')

    def test_late_loaded_protected_child_is_not_claimed_when_disabled_before_flush(self):
        self.check_lua('''
            local main = RegisterTestWindow("WINDOW")
            local desc = ns.Registry:GetDescriptor("WINDOW")
            desc.linkedFrames = {"LateChild"}
            local child = CreateFrame("Frame", "LateChild", UIParent)
            child.scale = .6; child.protected = true
            combat = true; ns.Engine:ReapplyAllShown()
            ns.Engine:SetWindowEnabled("WINDOW", false)
            combat = false; ns.Guard:FlushCombatQueue()
            assert(child:GetScale() == .6 and child.scaleWrites == 0)
        ''')

    def test_shared_companion_keeps_remaining_owner_then_restores_original(self):
        for first_disabled in ("FIRST", "SECOND"):
            with self.subTest(first_disabled=first_disabled):
                self.check_lua('''
                    local child = CreateFrame("Frame", "SharedChild", UIParent)
                    child.scale = .6
                    for _, id in ipairs({"FIRST", "SECOND"}) do
                        local main = CreateFrame("Frame", id .. "Main", UIParent)
                        ns.Registry:RegisterWindow(id, { frame = main:GetName(), linkedFrames = {"SharedChild"} })
                        ns.Engine:SetWindowScale(id, id == "FIRST" and .8 or .9)
                    end
                    local first = "''' + first_disabled + '''"
                    local remaining = first == "FIRST" and "SECOND" or "FIRST"
                    ns.Engine:SetWindowEnabled(first, false)
                    assert(child:GetScale() == (remaining == "FIRST" and .8 or .9))
                    ns.Engine:SetWindowEnabled(remaining, false)
                    assert(child:GetScale() == .6)
                ''')

    def test_shared_companion_with_equal_targets_stays_managed_until_both_disable(self):
        self.check_lua('''
            local child = CreateFrame("Frame", "SharedChild", UIParent)
            child.scale = .6
            for _, id in ipairs({"FIRST", "SECOND"}) do
                local main = CreateFrame("Frame", id .. "Main", UIParent)
                ns.Registry:RegisterWindow(id, { frame = main:GetName(), linkedFrames = {"SharedChild"} })
            end
            ns.Engine:SetWindowEnabled("FIRST", false)
            assert(child:GetScale() == 1)
            ns.Engine:SetWindowEnabled("SECOND", false)
            assert(child:GetScale() == .6)
        ''')

    def test_linked_onshow_queue_works_while_main_is_hidden(self):
        self.check_lua('''
            local main, child = LinkedPair({childProtected = true})
            main:Hide(); child:Hide(); child:SetScale(.9)
            combat = true; child:Show()
            assert(child:GetScale() == .9 and ns.Guard:HasQueuedTasks())
            combat = false; ns.Guard:FlushCombatQueue()
            assert(child:GetScale() == 1)
            ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(child:GetScale() == .6)
        ''')

    def test_replaced_global_does_not_lose_original_frame_restore(self):
        self.check_lua('''
            local main, original = LinkedPair()
            local replacement = CreateFrame("Frame", "LinkedChild", UIParent)
            replacement.scale = .7
            ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(original:GetScale() == .6)
            assert(replacement:GetScale() == .7 and replacement.scaleWrites == 0)
        ''')

    def test_removed_link_list_still_restores_recorded_companion(self):
        self.check_lua('''
            local main, child, desc = LinkedPair()
            desc.linkedFrames = {}
            ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(child:GetScale() == .6)
        ''')

    def test_deferred_linked_work_does_not_touch_an_unregistered_descriptor(self):
        self.check_lua('''
            local main, child = LinkedPair({childProtected = true})
            combat = true; ns.Engine:SetWindowEnabled("WINDOW", false)
            assert(ns.Guard:HasQueuedTasks())
            ns.Registry:UnregisterWindow("WINDOW")
            local writes = child.scaleWrites
            combat = false; ns.Guard:FlushCombatQueue()
            assert(child.scaleWrites == writes and not ns.Guard:HasQueuedTasks())
        ''')


if __name__ == "__main__":
    unittest.main()
