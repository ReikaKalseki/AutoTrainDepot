Config = {}

Config.largerWarehouses = settings.startup["add-larger-warehouses"].value--[[@as boolean]]

Config.reloader = settings.startup["add-reloader"].value--[[@as boolean]]
Config.unloader = settings.startup["add-unloader"].value--[[@as boolean]]
Config.inserterUnloader = Config.unloader and settings.startup["inserter-unloader"].value--[[@as boolean]]

Config.blockStations = settings.startup["block-stations"].value--[[@as boolean]]

Config.deadlockSound = settings.startup["enable-deadlock-alert-sound"].value--[[@as boolean]]
Config.noPathSound = settings.startup["enable-nopath-alert-sound"].value--[[@as boolean]]