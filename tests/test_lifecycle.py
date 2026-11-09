"""Removed window bindings must become inert, including delayed work."""
import unittest

from test_runtime import new_runtime


SETUP = '''
    function CustomWindow(name, id, protected)
        local frame = CreateFrame("Frame", name or "CustomFrame", UIParent)
        frame.protected = protected
        local desc = {frame=frame:GetName(), isCustom=true, protected=protected}
        ns.Registry:RegisterWindow(id or "CUSTOM", desc)
        return frame, ns.Registry:GetDescriptor(id or "CUSTOM")
    end
'''


class LifecycleTests(unittest.TestCase):
    def check_lua(self, source):
        lua = new_runtime()
        lua.execute(SETUP + source)
        self.assertEqual(list(lua.globals().errors.values()), [])

    def test_removed_custom_window_stays_native_on_show_and_setpoint(self):
        self.check_lua('''
            local frame = CustomWindow()
            ns.Engine:SetWindowScale("CUSTOM", .8)
            ns.Engine:SetWindowAlpha("CUSTOM", .5, false)
            assert(ns.Profiles:RemoveCustomWindow("CUSTOM"))
            assert(frame:GetScale()==1 and frame:GetAlpha()==1)
            frame:SetScale(1.2); frame:SetAlpha(.9)
            local writes=frame.scaleWrites
            frame:Hide(); frame:Show()
            frame:ClearAllPoints(); frame:SetPoint("CENTER",UIParent,"CENTER",20,30)
            assert(frame:GetScale()==1.2 and frame:GetAlpha()==.9 and frame.scaleWrites==writes)
            assert(frame:GetPoint(1)=="CENTER")
            assert(ns:GetWindowConfig("CUSTOM",false)==nil)
        ''')

    def test_unregister_restores_original_scale_alpha_and_anchors(self):
        self.check_lua('''
            local frame = CustomWindow()
            ns.Engine:SetWindowScale("CUSTOM",.8)
            ns.Engine:SetWindowAlpha("CUSTOM",.4,false)
            assert(ns.Registry:UnregisterWindow("CUSTOM"))
            assert(frame:GetScale()==1 and frame:GetAlpha()==1)
            local point,relative,relativePoint,x,y=frame:GetPoint(1)
            assert(point=="TOPLEFT" and relative==UIParent and relativePoint=="TOPLEFT")
            assert(x==100 and y==-180)
        ''')

    def test_nested_frame_uses_ui_parent_units_for_read_and_apply(self):
        self.check_lua('''
            UIParent:SetScale(.7)
            local outer = CreateFrame("Frame", nil, UIParent)
            outer:SetScale(.8)
            local inner = CreateFrame("Frame", nil, outer)
            inner:SetScale(.5)
            local frame = CreateFrame("Frame", "Nested", inner)
            frame.left = 100
            frame.top = 900
            frame:SetScale(.75)
            local function close(actual, expected)
                assert(math.abs(actual - expected) < .001)
            end
            local x, y = ns.Engine:ReadUipTopLeft(frame)
            close(x, 30)
            close(y, 270 - UIParent:GetHeight())

            -- Binding applies the default scale; measure the native geometry first.
            ns.Registry:RegisterWindow("NESTED", { frame = "Nested" })
            local cfg = ns:GetWindowConfig("NESTED", true)
            cfg.mode = ns.MODE_SCALE_MOVE
            cfg.pos = { uipX = 180, uipY = -100 }
            assert(ns.Engine:SetWindowScale("NESTED", 1))
            local point, relative, relativePoint, offsetX, offsetY = frame:GetPoint(1)
            assert(point == "TOPLEFT" and relative == UIParent and relativePoint == "TOPLEFT")
            close(offsetX, 450)
            close(offsetY, -250)
            assert(frame:GetParent() == inner)

            ns.db.settings.clampToScreen = true
            local clampedX = ns.Engine:ClampUipPosition(frame, 1, -300, -100)
            close(clampedX, -20)
        ''')

    def test_pending_addon_binding_is_removed(self):
        self.check_lua('''
            ns.Registry:RegisterWindow("LATE",{frame="LateFrame",addon="LateAddon"})
            local old=ns.Registry:GetDescriptor("LATE")
            assert(ns.Registry:UnregisterWindow("LATE"))
            local frame=CreateFrame("Frame","LateFrame",UIParent);frame.scale=1.2
            ns.Registry:OnAddOnLoaded("LateAddon")
            assert(ns.Registry.pendingByAddon.LateAddon==nil)
            assert(old.boundFrame==nil and ns.Engine:GetManagedState(frame)==nil)
            assert(frame:GetScale()==1.2 and frame.scaleWrites==0)
        ''')

    def test_reregistered_frame_uses_new_owner_and_installs_no_duplicate_hooks(self):
        self.check_lua('''
            local frame=CustomWindow("Reusable","FIRST")
            ns.Engine:SetWindowScale("FIRST",.8)
            ns.Registry:UnregisterWindow("FIRST")
            frame:SetScale(.9)
            ns.Registry:RegisterWindow("SECOND",{frame="Reusable",isCustom=true})
            assert(ns.Engine:GetManagedState(frame).windowId=="SECOND")
            assert(#frame.hooks.OnShow==1 and #frame.hooks.OnMouseDown==1)
            ns.Engine:SetWindowScale("SECOND",.7)
            frame:Hide();frame:Show()
            assert(frame:GetScale()==.7)
            ns.Registry:UnregisterWindow("SECOND")
            assert(frame:GetScale()==.9)
        ''')

    def test_same_id_replacement_uses_new_protected_hint(self):
        self.check_lua('''
            local frame,old=CustomWindow()
            ns.Registry:UnregisterWindow("CUSTOM")
            ns.Registry:RegisterWindow("CUSTOM",{frame=frame:GetName(),protected=true,isCustom=true})
            assert(ns.Registry:GetDescriptor("CUSTOM")~=old)
            combat=true
            assert(ns.Engine:SetWindowScale("CUSTOM",.8)==false)
            assert(frame:GetScale()==1 and ns.Guard:HasQueuedTasks())
            combat=false;ns.Guard:FlushCombatQueue()
            assert(frame:GetScale()==.8)
        ''')

    def test_removed_mouse_hooks_do_not_recreate_config(self):
        self.check_lua('''
            local frame=CustomWindow()
            ns.Profiles:RemoveCustomWindow("CUSTOM")
            frame:Run("OnMouseDown","LeftButton");frame:Run("OnMouseUp","LeftButton")
            assert(ns:GetWindowConfig("CUSTOM",false)==nil)
            assert(frame:GetAlpha()==1 and frame:GetScale()==1)
        ''')

    def test_title_region_dispatches_to_replacement_binding(self):
        self.check_lua('''
            local frame=CreateFrame("Frame","Reusable",UIParent)
            local title=CreateFrame("Frame",nil,frame);frame.TitleContainer=title
            ns.Registry:RegisterWindow("FIRST",{frame="Reusable",isCustom=true})
            ns.Profiles:RemoveCustomWindow("FIRST")
            ns.Registry:RegisterWindow("SECOND",{frame="Reusable",isCustom=true})
            assert(#title.hooks.OnMouseDown==1)
            title:Run("OnMouseDown","LeftButton")
            assert(ns.Engine:GetManagedState(frame).isDragging)
            title:Run("OnMouseUp","LeftButton")
            assert(ns:GetWindowConfig("FIRST",false)==nil)
            assert(ns:GetWindowConfig("SECOND",false).pos~=nil)
        ''')

    def test_removal_during_drag_stops_without_recreating_config(self):
        self.check_lua('''
            local frame,desc=CustomWindow()
            ns.Engine:StartWindowDrag("CUSTOM",frame,desc)
            cursorX=cursorX+30
            for _,driver in ipairs(frames) do
                if driver:IsShown() and driver:GetScript("OnUpdate") then driver:Run("OnUpdate") end
            end
            ns.Profiles:RemoveCustomWindow("CUSTOM")
            assert(not ns.Engine:GetManagedState(frame).isDragging)
            assert(frame:GetAlpha()==1 and ns:GetWindowConfig("CUSTOM",false)==nil)
            frame:Run("OnMouseUp","LeftButton")
            assert(ns:GetWindowConfig("CUSTOM",false)==nil)
        ''')

    def test_removal_of_docked_member_preserves_only_valid_group_configs(self):
        self.check_lua('''
            local frame,desc=CustomWindow("Main","FIRST")
            local other=CustomWindow("Docked","SECOND");other.left=456
            ns.Engine:StartWindowDrag("FIRST",frame,desc)
            ns.Profiles:RemoveCustomWindow("SECOND")
            assert(not ns.Engine:GetManagedState(frame).isDragging)
            assert(ns:GetWindowConfig("SECOND",false)==nil)
            assert(frame:GetAlpha()==1 and other:GetAlpha()==1)
        ''')

    def test_fade_watcher_and_enter_hook_become_inert(self):
        self.check_lua('''
            local frame=CustomWindow()
            ns.Engine:SetWindowAlpha("CUSTOM",.5,true)
            frame.mouseover=true;frame:Run("OnEnter")
            ns.Profiles:RemoveCustomWindow("CUSTOM")
            frame:SetAlpha(.7);local writes=frame.alphaWrites
            frame:Run("OnEnter")
            for _,watcher in ipairs(frames) do
                if watcher:GetScript("OnUpdate") then
                    assert(not watcher:IsShown())
                    watcher:Run("OnUpdate")
                end
            end
            assert(frame:GetAlpha()==.7 and frame.alphaWrites==writes)
            assert(ns:GetWindowConfig("CUSTOM",false)==nil)
        ''')

    def test_never_applied_combat_work_cannot_modify_removed_frame(self):
        self.check_lua('''
            local frame=CustomWindow(nil,nil,true)
            combat=true;ns.Engine:SetWindowScale("CUSTOM",.8)
            ns.Profiles:RemoveCustomWindow("CUSTOM")
            frame.scale=1.2;local writes=frame.scaleWrites
            combat=false;ns.Guard:FlushCombatQueue()
            assert(frame:GetScale()==1.2 and frame.scaleWrites==writes)
            assert(ns:GetWindowConfig("CUSTOM",false)==nil)
        ''')

    def test_protected_cleanup_finishes_after_removal(self):
        self.check_lua('''
            local frame=CustomWindow(nil,nil,true)
            ns.Engine:SetWindowScale("CUSTOM",.8)
            ns.Engine:SetWindowAlpha("CUSTOM",.5,false)
            combat=true;ns.Profiles:RemoveCustomWindow("CUSTOM")
            assert(frame:GetScale()==.8 and ns.Guard:HasQueuedTasks())
            combat=false;ns.Guard:FlushCombatQueue()
            assert(frame:GetScale()==1 and frame:GetAlpha()==1)
            assert(ns:GetWindowConfig("CUSTOM",false)==nil)
        ''')

    def test_rebinding_waits_for_old_cleanup_then_applies_current_new_config(self):
        self.check_lua('''
            local frame=CustomWindow("Reusable","FIRST",true)
            ns.Engine:SetWindowScale("FIRST",.8)
            combat=true;ns.Profiles:RemoveCustomWindow("FIRST")
            ns.Registry:RegisterWindow("SECOND",{frame="Reusable",isCustom=true})
            assert(ns.Registry:GetDescriptor("SECOND").boundFrame==nil)
            ns.Engine:SetWindowScale("SECOND",.7)
            combat=false;ns.Guard:FlushCombatQueue()
            assert(ns.Registry:GetDescriptor("SECOND").boundFrame==frame)
            assert(frame:GetScale()==.7)
            ns.Registry:UnregisterWindow("SECOND")
            assert(frame:GetScale()==1)
        ''')

    def test_retired_linked_owner_restores_protected_child_after_combat(self):
        self.check_lua('''
            local child=CreateFrame("Frame","Child",UIParent);child.scale=.6;child.protected=true
            local main=CreateFrame("Frame","Main",UIParent)
            ns.Registry:RegisterWindow("CUSTOM",{frame="Main",linkedFrames={"Child"},isCustom=true})
            combat=true;ns.Profiles:RemoveCustomWindow("CUSTOM")
            assert(ns.Guard:HasQueuedTasks())
            combat=false;ns.Guard:FlushCombatQueue()
            assert(child:GetScale()==.6)
            child:SetScale(.9);child:Hide();child:Show()
            assert(child:GetScale()==.9)
        ''')

    def test_new_linked_owner_inherits_original_snapshot_from_pending_retired_owner(self):
        self.check_lua('''
            local child=CreateFrame("Frame","Child",UIParent);child.scale=.6;child.protected=true
            local main=CreateFrame("Frame","Main",UIParent)
            ns.Registry:RegisterWindow("FIRST",{frame="Main",linkedFrames={"Child"},isCustom=true})
            combat=true;ns.Profiles:RemoveCustomWindow("FIRST")
            ns.Registry:RegisterWindow("SECOND",{frame="Main",linkedFrames={"Child"},isCustom=true})
            ns.Engine:SetWindowScale("SECOND",.8)
            combat=false;ns.Guard:FlushCombatQueue()
            assert(child:GetScale()==.8)
            ns.Profiles:RemoveCustomWindow("SECOND")
            assert(child:GetScale()==.6)
        ''')

    def test_stale_ctrl_wheel_target_cannot_recreate_removed_config(self):
        self.check_lua('''
            local frame=CustomWindow()
            local catcher
            for _,f in ipairs(frames) do if f.wheelEnabled then catcher=f end end
            catcher.targetWindowId="CUSTOM";catcher:Show()
            ns.Profiles:RemoveCustomWindow("CUSTOM")
            assert(catcher.targetWindowId==nil and not catcher:IsShown())
            assert(ns.Engine:StepWindowScale("CUSTOM",1,false,false)==false)
            assert(ns:GetWindowConfig("CUSTOM",false)==nil)
        ''')

    def test_repeated_linked_bindings_install_one_companion_dispatcher(self):
        self.check_lua('''
            local child=CreateFrame("Frame","Child",UIParent);child.scale=.6
            CreateFrame("Frame","Main",UIParent)
            for i=1,3 do
                ns.Registry:RegisterWindow("CUSTOM",{frame="Main",linkedFrames={"Child"},isCustom=true})
                ns.Engine:SetWindowScale("CUSTOM",.8)
                child:Hide();child:Show();assert(child:GetScale()==.8)
                ns.Profiles:RemoveCustomWindow("CUSTOM")
                assert(child:GetScale()==.6)
            end
            assert(#child.hooks.OnShow==1)
            child:SetScale(.9);child:Hide();child:Show();assert(child:GetScale()==.9)
        ''')

    def test_removing_protected_drag_in_combat_defers_all_restoration(self):
        self.check_lua('''
            local frame,desc=CustomWindow(nil,nil,true)
            ns.Engine:StartWindowDrag("CUSTOM",frame,desc)
            local alpha=frame:GetAlpha();local writes=frame.alphaWrites
            combat=true;ns.Profiles:RemoveCustomWindow("CUSTOM")
            assert(frame:GetAlpha()==alpha and frame.alphaWrites==writes)
            assert(not ns.Engine:GetManagedState(frame).isDragging)
            combat=false;ns.Guard:FlushCombatQueue()
            assert(frame:GetAlpha()==1 and ns:GetWindowConfig("CUSTOM",false)==nil)
        ''')

    def test_removed_frame_emits_no_managed_visibility_events(self):
        self.check_lua('''
            local frame=CustomWindow()
            local count=0
            ns:On("OnManagedFrameShown",function() count=count+1 end)
            ns:On("OnManagedFrameHidden",function() count=count+1 end)
            ns.Profiles:RemoveCustomWindow("CUSTOM")
            frame:Hide();frame:Show()
            assert(count==0)
        ''')

    def test_linked_restore_uses_replacement_primary_descriptor(self):
        self.check_lua('''
            local child=CustomWindow("Child","PRIMARY")
            ns.Engine:SetWindowScale("PRIMARY",.8)
            CreateFrame("Frame","Main",UIParent)
            ns.Registry:RegisterWindow("LINKED",{frame="Main",linkedFrames={"Child"}})
            ns.Engine:SetWindowScale("LINKED",.7)
            ns.Registry:UnregisterWindow("PRIMARY")
            ns.Registry:RegisterWindow("NEW_PRIMARY",{frame="Child"})
            ns.Engine:SetWindowScale("NEW_PRIMARY",.9)
            ns.Engine:SetWindowEnabled("LINKED",false)
            assert(child:GetScale()==.9)
            ns.Registry:UnregisterWindow("NEW_PRIMARY")
            assert(child:GetScale()==1)
        ''')

    def test_primary_bound_after_companion_inherits_true_native_snapshot(self):
        self.check_lua('''
            local child=CreateFrame("Frame","Child",UIParent);child.scale=.6
            CreateFrame("Frame","Main",UIParent)
            ns.Registry:RegisterWindow("LINKED",{frame="Main",linkedFrames={"Child"}})
            ns.Engine:SetWindowScale("LINKED",.8)
            ns.Registry:RegisterWindow("PRIMARY",{frame="Child"})
            ns.Engine:SetWindowScale("PRIMARY",.9)
            ns.Engine:SetWindowEnabled("LINKED",false)
            assert(child:GetScale()==.9)
            ns.Registry:UnregisterWindow("PRIMARY")
            assert(child:GetScale()==.6)
        ''')

    def test_primary_disable_preserves_active_linked_owner_until_both_disable(self):
        self.check_lua('''
            local child=CreateFrame("Frame","Child",UIParent);child.scale=.6
            CreateFrame("Frame","Main",UIParent)
            ns.Registry:RegisterWindow("LINKED",{frame="Main",linkedFrames={"Child"}})
            ns.Engine:SetWindowScale("LINKED",.8)
            ns.Registry:RegisterWindow("PRIMARY",{frame="Child"})
            ns.Engine:SetWindowScale("PRIMARY",.9)
            ns.Engine:SetWindowEnabled("PRIMARY",false)
            assert(child:GetScale()==.8)
            ns.Engine:SetWindowEnabled("LINKED",false)
            assert(child:GetScale()==.6)
        ''')

    def test_linked_restore_respects_new_primary_protected_hint(self):
        self.check_lua('''
            local child=CustomWindow("Child","PRIMARY")
            CreateFrame("Frame","Main",UIParent)
            ns.Registry:RegisterWindow("LINKED",{frame="Main",linkedFrames={"Child"}})
            ns.Engine:SetWindowScale("LINKED",.7)
            ns.Registry:UnregisterWindow("PRIMARY")
            ns.Registry:RegisterWindow("NEW_PRIMARY",{frame="Child",protected=true})
            ns.Engine:SetWindowScale("NEW_PRIMARY",.9)
            ns.Engine:SetWindowScale("LINKED",.7)
            local writes=child.scaleWrites
            combat=true;ns.Engine:SetWindowEnabled("LINKED",false)
            assert(child:GetScale()==.7 and child.scaleWrites==writes and ns.Guard:HasQueuedTasks())
            combat=false;ns.Guard:FlushCombatQueue()
            assert(child:GetScale()==.9)
        ''')

    def test_primary_removed_before_companion_still_restores_true_native_scale(self):
        self.check_lua('''
            local child=CreateFrame("Frame","Child",UIParent);child.scale=.6
            CreateFrame("Frame","Main",UIParent)
            ns.Registry:RegisterWindow("LINKED",{frame="Main",linkedFrames={"Child"}})
            ns.Engine:SetWindowScale("LINKED",.8)
            ns.Registry:RegisterWindow("PRIMARY",{frame="Child"})
            ns.Engine:SetWindowScale("PRIMARY",.9)
            ns.Registry:UnregisterWindow("PRIMARY")
            assert(child:GetScale()==.8)
            ns.Engine:SetWindowEnabled("LINKED",false)
            assert(child:GetScale()==.6)
        ''')


if __name__ == "__main__":
    unittest.main()
