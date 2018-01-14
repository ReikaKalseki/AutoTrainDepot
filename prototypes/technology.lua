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
		icon = "__Depot__/graphics/technology/depot.png",
		effects =
		{
			{
				type = "unlock-recipe",
				recipe = "depot-controller"
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
		}
})