Config = {}

Config.largerWarehouses = settings.startup["add-larger-warehouses"].value

Config.reloader = settings.startup["add-reloader"].value
Config.unloader = settings.startup["add-unloader"].value
Config.inserterUnloader = Config.unloader and settings.startup["inserter-unloader"].value

Config.blockStations = settings.startup["block-stations"].value

Config.deadlockSound = settings.startup["enable-deadlock-alert-sound"].value
Config.noPathSound = settings.startup["enable-nopath-alert-sound"].value