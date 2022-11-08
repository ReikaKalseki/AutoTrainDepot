data:extend({
{
	type = "virtual-signal",
	name = "train-alert-deadlock",
	icon = "__AutoTrainDepot__/graphics/icons/deadlock.png",
	icon_size = 64,
	icon_mipmaps = 0,
	subgroup = "virtual-signal-special",
	order = "train-alert-deadlock",
	hidden = true,
},
{
	type = "virtual-signal",
	name = "train-alert-nopath",
	icon = "__AutoTrainDepot__/graphics/icons/nopath.png",
	icon_size = 64,
	icon_mipmaps = 0,
	subgroup = "virtual-signal-special",
	order = "train-alert-nopath",
	hidden = true,
},--[[ vanilla now
{
	type = "virtual-signal",
	name = "train-alert-nofuel",
	icon = "__AutoTrainDepot__/graphics/icons/nofuel.png",
	icon_size = 64,
	icon_mipmaps = 0,
	subgroup = "virtual-signal-special",
	order = name,
	hidden = true,
},--]]
{
	type = "sound",
	name = "train-alert",
	filename = "__core__/sound/message.ogg",
	volume = 1
},
})