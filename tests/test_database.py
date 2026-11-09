"""Cold-start migration and recovery of real SavedVariables-shaped fixtures."""
from pathlib import Path
import unittest

from test_runtime import new_runtime

FIXTURES = Path(__file__).with_name("fixtures")


class DatabaseTests(unittest.TestCase):
    def check_lua(self, saved, checks):
        lua = new_runtime(saved_variables=saved)
        lua.execute(checks)
        self.assertEqual(list(lua.globals().errors.values()), [])

    def test_legacy_windows_migrate_without_losing_positions_or_extensions(self):
        self.check_lua((FIXTURES / "database_v1.lua").read_text(), '''
            assert(ns.db.schemaVersion==2 and ns.db.activeProfile=="Default")
            local cfg=ns.db.windows.CHARACTER
            assert(cfg.scale==.8 and cfg.pos.uipX==120 and cfg.pos.uipY==-80)
            assert(cfg.extension.note=="keep" and ns.db.extension.quality==7)
            assert(ns.db.windows==ns.db.profiles.Default.windows)
            assert(ns.db.profiles["Laptop / Deck"] and ns.db.recovery==nil)
            assert(ns.databaseStatus.fromVersion==1 and ns.databaseStatus.toVersion==2)
        ''')

    def test_repeated_initialization_preserves_valid_references_and_checkpoint(self):
        self.check_lua((FIXTURES / "database_v2.lua").read_text(), '''
            local db,windows,profile,checkpoint=ns.db,ns.db.windows,ns.db.profiles.Raid,ns.db.profiles.Raid.savedSnapshot
            ns:InitDatabase();ns.Profiles:Init();ns:InitDatabase()
            assert(ns.db==db and ns.db.windows==windows and ns.db.profiles.Raid==profile)
            assert(profile.savedSnapshot==checkpoint and checkpoint.CHARACTER.scale==.75)
            assert(ns.db.windows.CHARACTER.scale==.8 and ns.db.recovery==nil)
            assert(ns.db.settings.managerHeight==500 and ns.db.settings.managerWidth==740)
        ''')

    def test_scalar_active_profile_is_quarantined_and_other_profiles_survive(self):
        self.check_lua('ELLADB={schemaVersion=2,activeProfile="Raid",profiles={Raid=42,Good={windows={W={scale=.7}}}}}', '''
            assert(type(ns.db.windows)=="table" and ns.db.activeProfile=="Raid")
            assert(ns.db.profiles.Good.windows.W.scale==.7)
            assert(ns.db.recovery.entries['profiles["Raid"]'].value==42)
            assert(ns.Profiles:SwitchProfile("Good",true))
            assert(ns.db.windows.W.scale==.7)
        ''')

    def test_missing_active_windows_are_repaired_before_alias_is_bound(self):
        self.check_lua('ELLADB={schemaVersion=2,activeProfile="Raid",profiles={Raid={}}}', '''
            assert(type(ns.db.windows)=="table" and ns.db.windows==ns.db.profiles.Raid.windows)
            assert(ns:GetWindowConfig("W",true).scale==1)
            ns:GetWindowConfig("W",true).scale=.8
            assert(ns.Profiles:HasUnsavedChanges())
        ''')

    def test_active_windows_can_be_recovered_from_legacy_alias(self):
        self.check_lua('ELLADB={schemaVersion=2,activeProfile="Raid",profiles={Raid={windows="broken"}},windows={W={scale=.8}}}', '''
            assert(ns.db.windows.W.scale==.8)
            assert(ns.db.recovery.entries['profiles["Raid"].windows'].value=="broken")
        ''')

    def test_corrupt_settings_are_repaired_with_original_values_saved(self):
        self.check_lua((FIXTURES / "database_corrupt.lua").read_text(), '''
            local s=ns.db.settings
            assert(s.enabled==true and s.managerScale==1 and s.managerHeight==620)
            assert(s.managerWidth==1080 and s.minimapPos==220)
            assert(s.activePreset==nil and s.widthMigratedV110==true)
            assert(ns.db.recovery.entries['settings.managerHeight'].value=="oops")
            assert(ns.db.recovery.entries['settings.enabled'].value=="false")
            assert(ns.db.extension=="untouched")
        ''')

    def test_all_profiles_and_saved_snapshots_are_normalized(self):
        self.check_lua((FIXTURES / "database_corrupt.lua").read_text(), '''
            local cfg=ns.db.profiles.Other.windows.W
            assert(cfg.scale==1.5 and cfg.alpha==.3 and cfg.mode==nil and cfg.prevMode==nil)
            assert(cfg.locked==false and cfg.hideBadge==false and cfg.mouseoverFade==false)
            assert(cfg.pos==nil and cfg.extra=="keep")
            assert(ns.db.profiles.Other.windows.BROKEN==nil)
            assert(ns.db.profiles.Other.savedSnapshot.W.scale==1)
            assert(ns.Profiles:SwitchProfile("Other",true))
            assert(type(ns.Profiles:HasUnsavedChanges())=="boolean")
        ''')

    def test_nonfinite_positions_are_dropped_as_a_unit(self):
        for value in ("0/0", "math.huge", "-math.huge", '"12"', "1000001"):
            with self.subTest(value=value):
                self.check_lua('ELLADB={profiles={Default={windows={W={pos={uipX='+value+',uipY=-50}}}}}}', '''
                    assert(ns.db.windows.W.pos==nil)
                    assert(ns.db.recovery.entries['profiles["Default"].windows["W"].pos'])
                ''')

    def test_valid_position_edges_and_disabled_third_party_mode_are_preserved(self):
        self.check_lua('ELLADB={schemaVersion=2,profiles={Default={windows={W={mode="DISABLED",pos={uipX=1000000,uipY=-1000000}}}}}}', '''
            assert(ns.db.windows.W.mode==ns.MODE_DISABLED)
            assert(ns.db.windows.W.pos.uipX==1000000 and ns.db.windows.W.pos.uipY==-1000000)
            assert(ns.db.recovery==nil)
        ''')

    def test_recovery_is_idempotent_and_keeps_the_first_invalid_value(self):
        self.check_lua('ELLADB={schemaVersion=2,settings={managerHeight="first"},profiles={Default={windows={}}}}', '''
            local recovery=ns.db.recovery
            local count=0;for _ in pairs(recovery.entries) do count=count+1 end
            ns:InitDatabase();ns.Profiles:Init();ns:InitDatabase()
            local again=0;for _ in pairs(recovery.entries) do again=again+1 end
            assert(ns.db.recovery==recovery and count==again)
            ns.db.settings.managerHeight="second";ns:InitDatabase()
            assert(recovery.entries['settings.managerHeight'].value=="first")
        ''')

    def test_invalid_root_and_invalid_recovery_metadata_remain_recoverable(self):
        self.check_lua('ELLADB=42', '''
            assert(ns.db.recovery.entries.ELLADB.value==42 and type(ns.db.windows)=="table")
        ''')
        self.check_lua('ELLADB={recovery="old backup",settings=false}', '''
            assert(ns.db.recovery.previous=="old backup")
            assert(ns.db.recovery.entries.settings.value==false)
        ''')

    def test_invalid_profile_keys_and_character_bindings_are_backed_up(self):
        self.check_lua('''
            ELLADB={schemaVersion=2,activeProfile="Missing",profiles={[5]={windows={}},Good={windows={}}},
                customWindows={Frame=false,[7]={label="bad"}},charProfiles={Alice="Good",Bob="Missing",[3]="Good"}}
        ''', '''
            assert(ns.db.activeProfile=="Default" and ns.db.profiles[5]==nil)
            assert(ns.db.customWindows.Frame.label=="Frame" and ns.db.customWindows[7]==nil)
            assert(ns.db.charProfiles.Alice=="Good" and ns.db.charProfiles.Bob==nil and ns.db.charProfiles[3]==nil)
            ns.Profiles:ListProfiles();ns.Profiles:RestoreCustomWindows()
        ''')

    def test_future_schema_is_never_downgraded_or_overwritten(self):
        self.check_lua('''
            ELLADB={schemaVersion=99,activeProfile="Future",profiles={Future={windows={W={scale=.8}}}},futureData={x=42}}
            original=ELLADB
        ''', '''
            assert(ELLADB==original and ELLADB.schemaVersion==99 and ELLADB.settings==nil)
            assert(ns.db~=ELLADB and ns.db.settings.enabled==false)
            assert(ns.databaseStatus.code=="unsupported_schema" and ns.databaseStatus.sourceVersion==99)
            ns:GetWindowConfig("W",true).scale=.5;ns:InitDatabase()
            assert(ELLADB.profiles.Future.windows.W.scale==.8 and ELLADB.futureData.x==42)
        ''')

    def test_failed_migration_rolls_back_and_records_a_diagnostic(self):
        self.check_lua('''
            ELLADB={schemaVersion=1,windows={W={scale=.8}}};original=ELLADB
            ns.Database.migrations[1]=function(db) db.windows.W.scale=.5;error("fixture failure") end
        ''', '''
            assert(ELLADB==original and ELLADB.schemaVersion==1 and ELLADB.windows.W.scale==.8)
            assert(ns.databaseStatus.code=="migration_failed" and ns.databaseStatus.fromVersion==1)
            assert(string.find(ns.databaseStatus.error,"fixture failure",1,true))
            assert(ns.db~=ELLADB and ns.db.settings.enabled==false and type(ns.db.windows)=="table")
        ''')

    def test_invalid_schema_version_is_backed_up_and_migrated(self):
        for version in ('"oops"', "0", "-1", "0/0", "math.huge", "1.5"):
            with self.subTest(version=version):
                self.check_lua('ELLADB={schemaVersion='+version+',windows={W={scale=.8}}}', '''
                    assert(ns.db.schemaVersion==2 and ns.db.windows.W.scale==.8)
                    assert(ns.db.recovery.entries.schemaVersion)
                ''')

    def test_v2_missing_profiles_salvage_legacy_windows(self):
        self.check_lua('ELLADB={schemaVersion=2,activeProfile="Lost",windows={W={scale=.8}}}', '''
            assert(ns.db.activeProfile=="Default" and ns.db.windows.W.scale==.8)
        ''')

    def test_deep_backup_does_not_alias_repaired_configuration(self):
        self.check_lua('ELLADB={schemaVersion=2,profiles={Default={windows={W={pos={uipX="bad",uipY=-10,extra={x=7}}}}}}}', '''
            local original=ns.db.recovery.entries['profiles["Default"].windows["W"].pos'].value
            ns.db.windows.W.pos={uipX=10,uipY=-10,extra={x=2}}
            assert(original.uipX=="bad" and original.extra.x==7)
            ns:InitDatabase();assert(original.extra.x==7)
        ''')

    def test_detached_legacy_alias_is_backed_up_before_rebinding(self):
        self.check_lua('ELLADB={schemaVersion=2,profiles={Default={windows={W={scale=.8}}}},windows={Lost={scale=.6}}}', '''
            assert(ns.db.windows.W.scale==.8 and ns.db.windows.Lost==nil)
            assert(ns.db.recovery.entries.windows.value.Lost.scale==.6)
        ''')

    def test_recovery_messages_are_localized_and_format_correctly(self):
        for locale in ("enUS", "deDE"):
            with self.subTest(locale=locale):
                lua = new_runtime(locale, 'ELLADB={schemaVersion=2,settings=false}')
                lua.execute('''
                    local expected=string.format(ns.L.DB_RECOVERED,ns.databaseStatus.repairs)
                    assert(string.find(messages[#messages],expected,1,true))
                ''')
                self.assertEqual(list(lua.globals().errors.values()), [])

    def test_shared_checkpoint_is_detached_from_live_values(self):
        self.check_lua('''
            local windows={W={scale=.8,pos={uipX=10,uipY=-10}}}
            ELLADB={schemaVersion=2,profiles={Default={windows=windows,savedSnapshot=windows}}}
        ''', '''
            local checkpoint=ns.db.profiles.Default.savedSnapshot
            ns.db.windows.W.scale=.6;ns.db.windows.W.pos.uipX=30
            assert(checkpoint.W.scale==.8 and checkpoint.W.pos.uipX==10)
            assert(ns.Profiles:HasUnsavedChanges())
        ''')

    def test_missing_migration_step_preserves_the_source(self):
        self.check_lua('''
            ELLADB={schemaVersion=1,windows={W={scale=.8}}};original=ELLADB
            ns.Database.migrations[1]=nil
        ''', '''
            assert(ELLADB==original and ELLADB.schemaVersion==1 and ELLADB.windows.W.scale==.8)
            assert(ns.databaseStatus.code=="migration_failed")
        ''')


if __name__ == "__main__":
    unittest.main()
