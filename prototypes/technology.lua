require "config"
require "constants"

local function createTech(name, deps, packs, count)
	table.insert(packs, {"science-pack-1", 1})
	table.insert(packs, {"science-pack-2", 1})
	local effects = {}
	local ico = "__AutoTrainDepot__/graphics/technology/depot.png"
	local lvl = tonumber(string.sub(name, -1))
	local locale = nil
	local upgrade = false
	if string.find(name, "fluid-count", 1, true) then
		ico = "__AutoTrainDepot__/graphics/technology/depot-fluid.png"
		if lvl == 2 then
			table.insert(deps, "depot-fluid")
		else
			table.insert(deps, "depot-fluid-count-" .. (lvl-1))
		end
		upgrade = true
		table.insert(effects, {type = "nothing", effect_description = {"modifier-description.depot-fluid-count", tostring(lvl)}})
	elseif string.find(name, "item-count", 1, true) then
		ico = "__AutoTrainDepot__/graphics/technology/depot-items.png"
		if lvl == 1 then
			table.insert(deps, "depot-base")
		else
			table.insert(deps, "depot-item-count-" .. (lvl-1))
		end
		upgrade = true
		table.insert(effects, {type = "nothing", effect_description = {"modifier-description.depot-item-count", tostring(ITEM_COUNT_TIERS[lvl+1])}})
	elseif name == "depot-base" then
		table.insert(effects, {type = "unlock-recipe", recipe = "depot-controller"})
		table.insert(effects, {type = "unlock-recipe", recipe = "smart-train-stop"})
		table.insert(effects, {type = "nothing", effect_description = {"modifier-description.depot-item-count", tostring(ITEM_COUNT_TIERS[1])}})
	else
		table.insert(deps, "depot-base")
		ico = "__AutoTrainDepot__/graphics/technology/depot-feature.png"
		if name ~= "depot-fluid" then
			local id = string.sub(name, string.len("depot-")+1)
			locale = {"technology-name.depot-power", {"depot-power-name." .. id}}
			table.insert(effects, {type = "nothing", effect_description = {"modifier-description.depot-capability", {"depot-power-desc." .. id}}})
		end
	end
	if name == "depot-fluid" then
		ico = "__AutoTrainDepot__/graphics/technology/depot-fluid.png"
		table.insert(effects, {type = "unlock-recipe", recipe = "depot-fluid-controller"})
	end
	for i,dep in ipairs(deps) do
		if not data.raw.technology[dep] then
			log("Removing tech dependency " .. dep .. "; does not exist.")
			table.remove(deps, i)
		end
	end
	data:extend({
	{
		type = "technology",
		name = name,
		prerequisites = deps,
		icon = ico,
		effects = effects,
		localised_name = locale,
		upgrade = upgrade,
		unit =
		{
		  count = count,
		  ingredients = packs,
		  time = 30
		},
		order = "[logistics]-3",
		icon_size = 128,
	},
	})
end

createTech("depot-base", {"automated-rail-transportation", "circuit-network", "automation-2", "logistics-2", "alloy-processing-1"}, {}, 150)
createTech("depot-fluid", {"fluid-handling", "advanced-electronics", "nickel-processing"}, {}, 200)
createTech("depot-redbar-control", {"optics"}, {}, 50)
createTech("depot-inserter-cleaning", {"more-inserters-1"}, {}, 25)
createTech("depot-balancing", {"automation-3", "fast-loader"}, {{"science-pack-3", 1}}, 200)
createTech("depot-dynamic-filters", {"automation-3", "optics"}, {{"science-pack-3", 1}}, 80)
createTech("depot-cargo-filters", {"automation-3"}, {}, 100)

for i = 2,6 do
	local pack = {}
	local pack3 = false
	if i >= 5 then
		if data.raw.tool["logistic-science-pack"] then
			table.insert(pack, {"logistic-science-pack", 1})
		else
			table.insert(pack, {"science-pack-3", 1})
			pack3 = true
		end
	end
	if i >= 6 and not pack3 then
		table.insert(pack, {"science-pack-3", 1})
	end
	createTech("depot-fluid-count-" .. i, i == 5 and {"logistics-3"} or {}, pack, math.floor((30*(1.5^(i-1)))/5)*5)
end

for i = 1,#ITEM_COUNT_TIERS-1 do
	local pack = {}
	local pack3 = false
	if i >= 4 then
		if data.raw.tool["logistic-science-pack"] then
			table.insert(pack, {"logistic-science-pack", 1})
		else
			table.insert(pack, {"science-pack-3", 1})
			pack3 = true
		end
	end
	if i >= 6 and not pack3 then
		table.insert(pack, {"science-pack-3", 1})
	end
	if i >= 7 then
		table.insert(pack, {"high-tech-science-pack", 1})
	end
	local dep = {}
	if i == 4 then
		table.insert(dep, "logistics-3")
	end
	if i == 6 then
		table.insert(dep, "bob-logistics-4")
	end
	if i == 7 then
		table.insert(dep, "bob-logistics-5")
	end
	createTech("depot-item-count-" .. i, dep, pack, 50*2^i)
end

--[[
data:extend({
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
	},
})--]]

data:extend({
	{
		type = "technology",
		name = "train-alarms",
		prerequisites =
		{
			"railway",
			"circuit-network"
		},
		icon = "__AutoTrainDepot__/graphics/technology/alarms.png",
		effects =
		{
		
		},
		unit =
		{
		  count = 50,
		  ingredients =
		  {
			{"science-pack-1", 1},
			{"science-pack-2", 1},
		  },
		  time = 30
		},
		order = "[railway]-3",
		icon_size = 128,
	},
})

data:extend({
	{
		type = "technology",
		name = "bypass-beacons",
		prerequisites =
		{
			"depot-base",
			"logistics-3",
			"rail-signals",
		},
		icon = "__AutoTrainDepot__/graphics/technology/bypass.png",
		effects =
		{
			{
				type = "unlock-recipe",
				recipe = "station-bypass-beacon"
			}
		},
		unit =
		{
		  count = 100,
		  ingredients =
		  {
			{"science-pack-1", 1},
			{"science-pack-2", 1},
		  },
		  time = 30
		},
		order = "[logistics]-3",
		icon_size = 128,
	},
})

if data.raw.tool["logistic-science-pack"] then
	table.insert(data.raw.technology["bypass-beacons"].unit.ingredients, {"logistic-science-pack", 1})
	data.raw.technology["bypass-beacons"].unit.count = 60
end

if Config.reloader then
data:extend({
	{
		type = "technology",
		name = "rapid-loading",
		prerequisites =
		{
			"logistics-3",
			"depot-item-count-3",
			"inserter-capacity-bonus-4",
		},
		icon = "__AutoTrainDepot__/graphics/technology/reloader.png",
		effects =
		{
			{
				type = "unlock-recipe",
				recipe = "train-reloader"
			}
		},
		unit =
		{
		  count = 150,
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

	if data.raw.tool["logistic-science-pack"] then
		table.insert(data.raw.technology["rapid-loading"].unit.ingredients, {"logistic-science-pack", 1})
		data.raw.technology["rapid-loading"].unit.count = 90
	end
end

if Config.reloader and data.raw.loader["fast-loader"] then
data:extend({
	{
		type = "technology",
		name = "rapid-unloading",
		prerequisites =
		{
			"logistics-3",
			"depot-item-count-3",
			"inserter-capacity-bonus-4",
			"express-loader",
		},
		icon = "__AutoTrainDepot__/graphics/technology/unloader.png",
		effects =
		{
			{
				type = "unlock-recipe",
				recipe = "train-unloader"
			}
		},
		unit =
		{
		  count = 120,
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

	if data.raw.tool["logistic-science-pack"] then
		table.insert(data.raw.technology["rapid-unloading"].unit.ingredients, {"logistic-science-pack", 1})
		data.raw.technology["rapid-loading"].unit.count = 75
	end
end