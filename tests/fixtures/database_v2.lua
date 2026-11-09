ELLADB = {
    schemaVersion = 2,
    activeProfile = "Raid",
    profiles = {
        Default = {windows={}},
        Raid = {windows={CHARACTER={scale=.8}}, savedSnapshot={CHARACTER={scale=.75}}},
    },
    settings = {managerHeight=500,managerWidth=740,widthMigratedV110=true},
}
ELLADB.windows = ELLADB.profiles.Raid.windows
