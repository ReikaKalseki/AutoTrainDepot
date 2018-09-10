require("config")

require("prototypes.depot")
require("prototypes.fluid-depot")
require("prototypes.unloader")
--require("prototypes.large-storage")
--require("prototypes.technology")

data:extend({
{
	type = "virtual-signal",
	name = "train-alert-deadlock",
	icon = "__AutoTrainDepot__/graphics/icons/deadlock.png",
	icon_size = 64,
	subgroup = "virtual-signal-special",
	order = name,
	hidden = true,
},
{
	type = "virtual-signal",
	name = "train-alert-nopath",
	icon = "__AutoTrainDepot__/graphics/icons/nopath.png",
	icon_size = 64,
	subgroup = "virtual-signal-special",
	order = name,
	hidden = true,
},
{
	type = "sound",
	name = "train-alert",
	filename = "__core__/sound/message.ogg",
	volume = 1
},
})