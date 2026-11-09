"""Profile import validates the whole bounded payload before mutating state."""
import unittest

from test_runtime import new_runtime

SETUP = '''
    RegisterTestWindow("WINDOW"); RegisterTestWindow("OTHER")
    local cfg=ns:GetWindowConfig("WINDOW",true)
    ns:GetWindowConfig("OTHER",true)
    cfg.scale=.9;cfg.alpha=.6;cfg.mouseoverFade=true;cfg.hideBadge=true
    ns.db.settings.activePreset="COMPACT_80"
    local windows=ns.db.windows
    local before=ns.Profiles:ExportString()
    local events=0
    ns:On("OnProfileImported",function() events=events+1 end)
    ns:On("OnWindowApplied",function() events=events+1 end)
    ns:On("OnWindowConfigChanged",function() events=events+1 end)
    function RejectImport(raw,expected)
        local valid,count,_,_,reason=ns.Profiles:InspectImportString(raw)
        assert(not valid and count==0 and reason==expected,"preview: "..tostring(reason))
        local ok,message,code=ns.Profiles:ImportString(raw)
        assert(not ok and code==expected and type(message)=="string" and #message>0,"import: "..tostring(code))
        assert(ns.db.windows==windows and ns.db.windows.WINDOW==cfg)
        assert(ns.Profiles:ExportString()==before and not ns.Profiles:CanUndo())
        assert(ns.db.settings.activePreset=="COMPACT_80" and events==0)
    end
'''


class ImportTests(unittest.TestCase):
    def check_lua(self, source, locale="enUS"):
        lua = new_runtime(locale)
        lua.execute(SETUP + source)
        self.assertEqual(list(lua.globals().errors.values()), [])

    def test_malformed_coordinates_cannot_cause_a_partial_import(self):
        for x, y in (("--1", "-20"), (".", "0"), ("1.2.3", "0"), ("", "-20"),
                     ("20", ""), ("nan", "0"), ("inf", "0"), ("1e309", "0"), ("+1", "0")):
            with self.subTest(x=x, y=y):
                self.check_lua('RejectImport("!ELLA:v2:Test;OTHER=80,M,0,,;WINDOW=80,M,0,'+x+','+y+'","invalid_position")')

    def test_position_magnitude_is_bounded(self):
        for x in ("1000001", "-1000001", "9" * 400):
            with self.subTest(x=x[:30]):
                self.check_lua('RejectImport("!ELLA:v2:Test;WINDOW=80,M,0,'+x+',0","invalid_position")')

    def test_nonfinite_scale_and_alpha_overflows_are_rejected(self):
        huge = "9" * 400
        self.check_lua('RejectImport("!ELLA:v2:Test;WINDOW='+huge+',M,0,,","invalid_number")')
        self.check_lua('RejectImport("!ELLA:v2:Test;WINDOW=80,M,0,,,'+huge+'","invalid_number")')

    def test_invalid_mandatory_and_optional_fields_are_rejected(self):
        for payload, reason in (("80,X,0,,", "invalid_entry"), ("80,M,2,,", "invalid_entry"),
                                ("-5,M,0,,", "invalid_number"), ("nan,M,0,,", "invalid_number"),
                                ("80,M,0,,,nan", "invalid_number"), ("80,M,0,,,60,2", "invalid_entry"),
                                ("80,M,0,,,60,1,x", "invalid_entry"), ("80,M,0,,,60,1,0,extra", "invalid_entry")):
            with self.subTest(payload=payload):
                self.check_lua('RejectImport("!ELLA:v2:Test;WINDOW='+payload+'","'+reason+'")')

    def test_truncated_mandatory_fields_are_rejected(self):
        for payload in ("", "80", "80,", "80,M", "80,M,0", "80,M,0,10"):
            with self.subTest(payload=payload):
                self.check_lua('RejectImport("!ELLA:v2:Test;WINDOW='+payload+'","invalid_entry")')

    def test_header_must_be_an_exact_supported_version(self):
        for header in ("!ELLA:v3:Test", "!ELLAgarbage", "ELLA2junk", "ELLA10", "FSCALE10", "Other", "!ELLA:v2:"):
            with self.subTest(header=header):
                self.check_lua('RejectImport("'+header+';WINDOW=80,M,0,,","invalid_header")')

    def test_unknown_ids_are_skipped_after_validation(self):
        self.check_lua('''
            local raw="!ELLA:v2:Test;UNKNOWN=70,S,1,10,-10,50,1,1;WINDOW=80,M,0,,"
            local valid,count=ns.Profiles:InspectImportString(raw)
            assert(valid and count==1 and not ns.Profiles:CanUndo())
            assert(ns.Profiles:ImportString(raw))
            assert(ns.db.windows.UNKNOWN==nil and ns.db.windows.WINDOW.scale==.8)
        ''')

    def test_malformed_unknown_ids_are_not_silently_accepted(self):
        self.check_lua('RejectImport("!ELLA:v2:Test;WINDOW=80,M,0,,;UNKNOWN=80,M,0,--1,0","invalid_position")')

    def test_duplicate_ids_are_rejected_before_any_write(self):
        self.check_lua('RejectImport("!ELLA:v2:Test;WINDOW=80,M,0,,;WINDOW=90,S,1,,","duplicate_window")')
        self.check_lua('RejectImport("ELLA1;UNKNOWN=80,M,0,,;UNKNOWN=90,M,0,,;WINDOW=70,M,0,,","duplicate_window")')

    def test_empty_and_unknown_only_profiles_do_not_change_undo_or_settings(self):
        self.check_lua('''
            RejectImport("!ELLA:v2:Empty","no_known_windows")
            RejectImport("!ELLA:v2:Empty;UNKNOWN=80,M,0,,","no_known_windows")
            RejectImport(nil,"invalid_type")
            RejectImport(42,"invalid_type")
        ''')

    def test_empty_tokens_and_trailing_data_are_rejected(self):
        for raw in ("!ELLA:v2:Test;;WINDOW=80,M,0,,", "!ELLA:v2:Test;WINDOW=80,M,0,,;",
                    "!ELLA:v2:Test;WINDOW=80,M,0,,;garbage", "!ELLA:v2:Test;WINDOW=80,M,0,,=oops"):
            with self.subTest(raw=raw):
                self.check_lua('RejectImport("'+raw+'","invalid_entry")')

    def test_raw_byte_limit_is_applied_before_trimming(self):
        self.check_lua('''
            RejectImport(string.rep(" ",65536).."!ELLA:v2:Test;WINDOW=80,M,0,,","too_large")
            local suffix=";WINDOW=80,M,0,,"
            local header="!ELLA:v2:"
            local raw=header..string.rep("n",65536-#header-#suffix)..suffix
            assert(#raw==65536 and ns.Profiles:InspectImportString(raw))
            assert(ns.Profiles:ImportString(raw))
        ''')

    def test_entry_limit_counts_unknown_windows_too(self):
        self.check_lua('''
            local parts={"ELLA1","WINDOW=80,M,0,,"}
            for i=1,1024 do parts[#parts+1]="UNKNOWN"..i.."=80,M,0,," end
            RejectImport(table.concat(parts,";"),"too_many_entries")
        ''')

    def test_entry_limit_allows_exactly_1024_known_windows(self):
        self.check_lua('''
            local parts={"ELLA1"}
            for i=1,1024 do
                ns.Registry:RegisterWindow("LIMIT"..i,{frame="Unavailable"})
                parts[#parts+1]="LIMIT"..i.."=80,M,0,,"
            end
            local raw=table.concat(parts,";")
            local valid,count=ns.Profiles:InspectImportString(raw)
            assert(valid and count==1024)
            assert(ns.Profiles:ImportString(raw))
            assert(ns.db.windows.LIMIT1024.scale==.8)
        ''')

    def test_supported_legacy_headers_and_missing_optional_fields(self):
        for header in ("ELLA1", "FSCALE1", "ELLA2", "ELLA2:Old", "!ELLA:v2", "!ELLA:v2:Old"):
            with self.subTest(header=header):
                self.check_lua('''
                    local raw="'''+header+''';WINDOW=80,S,1,,"
                    assert(ns.Profiles:InspectImportString(raw))
                    assert(ns.Profiles:ImportString(raw))
                    local cfg=ns.db.windows.WINDOW
                    assert(cfg.scale==.8 and cfg.mode==ns.MODE_SCALE_ONLY and cfg.locked and cfg.pos==nil)
                    assert(cfg.alpha==.6 and cfg.mouseoverFade and cfg.hideBadge)
                ''')

    def test_progressively_added_optional_fields_remain_compatible(self):
        for suffix in (",50", ",50,0", ",50,0,0", ",,0,0", ",,,", ",50,,"):
            with self.subTest(suffix=suffix):
                self.check_lua('assert(ns.Profiles:ImportString("ELLA1;WINDOW=80,M,0,10,-20'+suffix+'"))')

    def test_decimal_position_and_exact_position_bounds_are_supported(self):
        for x, y in (("1000000", "-1000000"), ("-.5", "-12.75"), ("1.", "0.25")):
            with self.subTest(x=x, y=y):
                self.check_lua('''
                    ns.db.settings.clampToScreen=false
                    assert(ns.Profiles:ImportString("!ELLA:v2:Test;WINDOW=80,M,0,'''+x+','+y+'''"))
                    assert(ns.db.windows.WINDOW.pos.uipX=='''+x+''' and ns.db.windows.WINDOW.pos.uipY=='''+y+''')
                ''')

    def test_scale_and_alpha_still_use_existing_clamp_rules(self):
        self.check_lua('''
            assert(ns.Profiles:ImportString("ELLA1;WINDOW=0,M,0,,,0;OTHER=999,M,0,,,999"))
            assert(ns.db.windows.WINDOW.scale==.5 and ns.db.windows.WINDOW.alpha==.3)
            assert(ns.db.windows.OTHER.scale==1.5 and ns.db.windows.OTHER.alpha==1)
        ''')

    def test_successful_imports_are_each_undoable_and_emit_one_import_event(self):
        self.check_lua('''
            local imported=0
            ns:On("OnProfileImported",function(count) imported=imported+1;assert(count==1) end)
            assert(ns.Profiles:ImportString("ELLA1;WINDOW=80,M,0,,"))
            assert(ns.db.settings.activePreset==nil and imported==1)
            assert(ns.Profiles:ImportString("ELLA1;WINDOW=70,S,1,,"))
            assert(imported==2 and ns.db.windows.WINDOW.scale==.7)
            assert(ns.Profiles:UndoLastChange() and ns.db.windows.WINDOW.scale==.8)
            assert(ns.Profiles:UndoLastChange() and ns.db.windows.WINDOW.scale==.9)
            assert(not ns.Profiles:CanUndo())
        ''')

    def test_rejected_import_does_not_add_to_existing_undo_history(self):
        self.check_lua('''
            ns.Engine:SetWindowScale("WINDOW",.7)
            assert(ns.Profiles:ImportString("ELLA1;WINDOW=80,M,0,--1,0")==false)
            assert(ns.Profiles:UndoLastChange() and ns.db.windows.WINDOW.scale==.9)
            assert(not ns.Profiles:CanUndo())
        ''')

    def test_preview_is_read_only_and_reports_a_limited_name_summary(self):
        self.check_lua('''
            local parts={"!ELLA:v2:Preview"}
            for i=1,6 do
                ns.Registry:RegisterWindow("PREVIEW"..i,{frame="Missing",label="Label "..i})
                parts[#parts+1]="PREVIEW"..i.."=80,M,0,,"
            end
            local valid,count,names,name=ns.Profiles:InspectImportString(table.concat(parts,";"))
            assert(valid and count==6 and name=="Preview")
            assert(string.find(names,"Label 1",1,true) and not string.find(names,"Label 5",1,true))
            assert(ns.db.windows.PREVIEW1==nil and events==0 and not ns.Profiles:CanUndo())
        ''')

    def test_export_roundtrip_keeps_utf8_profile_name_and_window_fields(self):
        self.check_lua('''
            assert(ns.Profiles:CreateOrCopyProfile("Übergrößen",true))
            local cfg=ns.db.windows.WINDOW
            cfg.scale=.83;cfg.mode=ns.MODE_SCALE_ONLY;cfg.locked=true
            cfg.pos={uipX=120,uipY=-80};cfg.alpha=.47;cfg.mouseoverFade=true;cfg.hideBadge=true
            local raw=ns.Profiles:ExportString()
            assert(ns.Profiles:CreateOrCopyProfile("Destination",false))
            local valid,count,_,name=ns.Profiles:InspectImportString(raw)
            assert(valid and name=="Übergrößen" and count==2)
            assert(ns.Profiles:ImportString(raw) and ns.db.activeProfile=="Destination")
            cfg=ns.db.windows.WINDOW
            assert(cfg.scale==.83 and cfg.alpha==.47 and cfg.locked and cfg.mouseoverFade and cfg.hideBadge)
            assert(cfg.mode==ns.MODE_SCALE_ONLY and cfg.pos.uipX==120 and cfg.pos.uipY==-80)
        ''')

    def test_header_prefixes_and_dots_in_window_ids_do_not_drop_entries(self):
        self.check_lua('''
            local parts={"ELLA1"}
            for _,id in ipairs({"ELLA_EXTRA","FSCALE_EXTRA","Addon.Panel"}) do
                ns.Registry:RegisterWindow(id,{frame="Missing"})
                parts[#parts+1]=id.."=80,M,0,,"
            end
            local valid,count=ns.Profiles:InspectImportString(table.concat(parts,";"))
            assert(valid and count==3 and ns.Profiles:ImportString(table.concat(parts,";")))
            assert(ns.db.windows.ELLA_EXTRA.scale==.8 and ns.db.windows["Addon.Panel"].scale==.8)
        ''')

    def test_input_never_executes_lua(self):
        self.check_lua('''
            RejectImport("ELLA1;WINDOW=80,M,0,,;evil=loadstring('executed=true')()","invalid_entry")
            assert(executed==nil)
        ''')

    def test_error_messages_are_localized(self):
        for locale in ("enUS", "deDE"):
            with self.subTest(locale=locale):
                self.check_lua('''
                    local _,message,code=ns.Profiles:ImportString(string.rep("x",65537))
                    assert(code=="too_large" and message==ns.L.UI_IMPORT_TOO_LARGE)
                    assert(message~= "UI_IMPORT_TOO_LARGE")
                ''', locale)


if __name__ == "__main__":
    unittest.main()
