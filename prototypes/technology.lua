require "config" 

data:extend({
	{
		type = "technology",
		name = "depot",
		prerequisites =
		{
			"logistics-3",
			"automated-rail-transportation",
		},
		icon = "__AutoTrainDepot__/graphics/technology/depot.png",
		effects =
		{
			{
				type = "unlock-recipe",
				recipe = "depot-controller"
			},
			{
				type = "unlock-recipe",
				recipe = "depot-fluid-controller"
			}
		},
		unit =
		{
		  count = 200,
		  ingredients =
		  {
			{"science-pack-1", 1},
			{"science-pack-2", 1},
			{"science-pack-3", 1},
		  },
		  time = 20
		},
		order = "[logistics]-3",
		icon_size = 128,
	},--[[
	{
		type = "technology",
		name = "large-depot",
		prerequisites =
		{
			"depot",
		},
		icon = "__AutoTrainDepot__/graphics/technology/depot.png",
		effects =
		{
			{
				type = "unlock-recipe",
				recipe = "large-depot"
			}
		},
		unit =
		{
		  count = 250,
		  ingredients =
		  {
			{"science-pack-1", 1},
			{"science-pack-2", 1},
			{"science-pack-3", 1},
		  },
		  time = 20
		},
		order = "[logistics]-3",
		icon_size = 128,
	},--]]
})

if Config.unloader then
data:extend({
	{
		type = "technology",
		name = "unloader",
		prerequisites =
		{
			"depot",
			"inserter-capacity-bonus-3",
		},
		icon = "__AutoTrainDepot__/graphics/technology/unloader.png",
		effects =
		{
			{
				type = "unlock-recipe",
				recipe = "train-unloader"
			},
			{
				type = "unlock-recipe",
				recipe = "dynamic-train-unloader"
			}
		},
		unit =
		{
		  count = 250,
		  ingredients =
		  {
			{"science-pack-1", 1},
			{"science-pack-2", 1},
			{"science-pack-3", 1},
		  },
		  time = 30
		},
		order = "[logistics]-3",
		icon_size = 128,
	},
})
end