require "config"
require "constants"

require "__DragonIndustries__.tech"
require "__DragonIndustries__.mathhelper"

local function createTech(name, deps, packs, count)
	for _,pack in pairs(packs) do
		table.insert(deps, getPrereqTechForPack(pack))
	end
	table.insert(packs, {"automation-science-pack", 1})
	table.insert(packs, {"logistic-science-pack", 1})
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
	elseif string.find(name, "item-slots", 1, true) then
		ico = "__AutoTrainDepot__/graphics/technology/depot-items.png"
		if lvl == 1 then
			table.insert(deps, "depot-base")
		else
			table.insert(deps, "depot-item-slots-" .. (lvl-1))
		end
		upgrade = true
		table.insert(effects, {type = "nothing", effect_description = {"modifier-description.depot-item-slots", tostring(SLOT_COUNT_TIERS[lvl])}})
	elseif string.find(name, "wagon-slot", 1, true) then
		ico = "__AutoTrainDepot__/graphics/technology/depot-wagon-slot.png"
		if lvl == 1 then
			table.insert(deps, "depot-base")
		else
			table.insert(deps, "depot-wagon-slot-" .. (lvl-1))
		end
		table.insert(deps, "depot-wagon-item-count-" .. math.ceil(lvl/2))
		upgrade = true
		table.insert(effects, {type = "nothing", effect_description = {"modifier-description.depot-wagon-slot", tostring(WAGON_SLOT_TIERS[lvl])}})
	elseif name == "depot-base" then
		table.insert(effects, {type = "nothing", effect_description = {"modifier-description.depot-item-count", tostring(ITEM_COUNT_TIERS[1])}})
		table.insert(effects, {type = "unlock-recipe", recipe = "depot-controller"})
		table.insert(effects, {type = "unlock-recipe", recipe = "depot-stop"})
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
	if #effects > 0 and effects[1].type == "nothing" then
		effects[1].icons = {{icon = ico, icon_size = 128}}
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
		  count = roundToNearest(count, 25),
		  ingredients = packs,
		  time = 30
		},
		order = "[logistics]-3",
		icon_size = 128,
	},
	})
end

createTech("depot-base", {"automated-rail-transportation", "circuit-network", "automation-2", "logistics-2", "alloy-processing-1"}, {}, 150)
createTech("depot-fluid", {"fluid-handling", "advanced-electronics", "nickel-processing", "logistics-3"}, {{"chemical-science-pack", 1}}, 200)
createTech("depot-redbar-control", {"optics"}, {}, 50)
createTech("depot-inserter-cleaning", {"more-inserters-1"}, {}, 25)
createTech("depot-balancing", {"fast-loader"}, {}, 200)
createTech("depot-dynamic-filters", {"optics"}, {}, 80)
createTech("depot-cargo-filters", {}, {}, 100)
--createTech("depot-category-limits", {"advanced-electronics"}, {{"chemical-science-pack", 1}}, 100)

for i = 2,6 do
	local pack = {{"chemical-science-pack", 1}}
	local pack3 = false
	if i >= 5 then
		if data.raw.tool["bob-logistic-science-pack"] then
			table.insert(pack, {"bob-logistic-science-pack", 1})
		else

		end
	end
	if i >= 6 then
		table.insert(pack, {"utility-science-pack", 1})
	end
	createTech("depot-fluid-count-" .. i, {}, pack, math.floor((30*(1.5^(i-1)))/5)*5)
end

for i = 1,#ITEM_COUNT_TIERS-1 do
	local pack = {}
	local pack3 = false
	if i >= 4 then
		if data.raw.tool["bob-logistic-science-pack"] then
			table.insert(pack, {"bob-logistic-science-pack", 1})
		else
			table.insert(pack, {"chemical-science-pack", 1})
			pack3 = true
		end
	end
	if i >= 6 and not pack3 then
		table.insert(pack, {"chemical-science-pack", 1})
	end
	if i >= 7 then
		table.insert(pack, {"utility-science-pack", 1})
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

for i = 1,#SLOT_COUNT_TIERS do
	local pack = {}
	local pack3 = false
	if i >= 4 then
		if data.raw.tool["bob-logistic-science-pack"] then
			table.insert(pack, {"bob-logistic-science-pack", 1})
		else
			table.insert(pack, {"chemical-science-pack", 1})
			pack3 = true
		end
	end
	if i >= 5 and not pack3 then
		table.insert(pack, {"chemical-science-pack", 1})
	end
	if i >= 6 then
		table.insert(pack, {"utility-science-pack", 1})
	end
	if i >= 7 then
		table.insert(pack, {"space-science-pack", 1})
	end
	local dep = {}
	if i == 5 then
		table.insert(dep, "logistics-3")
	end
	if i == 6 then
		table.insert(dep, "bob-logistics-4")
	end
	if i == 7 then
		table.insert(dep, "bob-logistics-5")
	end
	createTech("depot-item-slots-" .. i, dep, pack, 20*(1.6^(i*1.2)))
end

for i = 1,#WAGON_SLOT_TIERS do
	local pack = {}
	if i >= 5 and data.raw.tool["bob-logistic-science-pack"] then
		table.insert(pack, {"bob-logistic-science-pack", 1})
	end
	if i >= 4 then
		table.insert(pack, {"chemical-science-pack", 1})
	end
	if i >= 6 then
		table.insert(pack, {"utility-science-pack", 1})
	end
	local dep = {}
	if i == 4 then
		table.insert(dep, "logistics-3")
	end
	if i == 5 then
		table.insert(dep, "bob-logistics-4")
	end
	if i == 6 then
		table.insert(dep, "bob-logistics-5")
	end
	createTech("depot-wagon-slot-" .. i, dep, pack, 10*5^(i/2))
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
			{"automation-science-pack", 1},
			{"logistic-science-pack", 1},
			{"chemical-science-pack", 1},
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
			{"automation-science-pack", 1},
			{"logistic-science-pack", 1},
		  },
		  time = 30
		},
		order = "[railway]-3",
		icon_size = 128,
	},
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
			{"automation-science-pack", 1},
			{"logistic-science-pack", 1},
		  },
		  time = 30
		},
		order = "[logistics]-3",
		icon_size = 128,
	},
	{
		type = "technology",
		name = "smart-train-stop",
		prerequisites =
		{
			"depot-base",
			"logistics-3",
			"rail-signals",
			"advanced-electronics",
		},
		icon = "__AutoTrainDepot__/graphics/technology/smart-train-stop.png",
		effects =
		{
			{
				type = "unlock-recipe",
				recipe = "smart-train-stop"
			}
		},
		unit =
		{
		  count = 100,
		  ingredients =
		  {
			{"automation-science-pack", 1},
			{"logistic-science-pack", 1},
		  },
		  time = 30
		},
		order = "[logistics]-3",
		icon_size = 128,
	},
})

if data.raw.tool["bob-logistic-science-pack"] then
	table.insert(data.raw.technology["bypass-beacons"].unit.ingredients, {"bob-logistic-science-pack", 1})
	data.raw.technology["bypass-beacons"].unit.count = 60
end

if data.raw.technology["zinc-processing"] then
	table.insert(data.raw.technology["smart-train-stop"].prerequisites, "zinc-processing")
end

if Config.reloader and data.raw.loader["fast-loader"] then
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
			{"automation-science-pack", 1},
			{"logistic-science-pack", 1},
			{"chemical-science-pack", 1},
		  },
		  time = 30
		},
		order = "[logistics]-3",
		icon_size = 128,
	},
})

	if data.raw.tool["bob-logistic-science-pack"] then
		table.insert(data.raw.technology["rapid-loading"].unit.ingredients, {"bob-logistic-science-pack", 1})
		data.raw.technology["rapid-loading"].unit.count = 90
	end
end

if Config.unloader and data.raw.loader["fast-loader"] then
data:extend({
	{
		type = "technology",
		name = "rapid-unloading",
		prerequisites =
		{
			"logistics-3",
			"depot-item-count-3",
			"inserter-capacity-bonus-4",
			"concrete",
			"advanced-electronics-2",
			"low-density-structure"
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
			{"automation-science-pack", 1},
			{"logistic-science-pack", 1},
			{"chemical-science-pack", 1},
			{"production-science-pack", 1},
		  },
		  time = 30
		},
		order = "[logistics]-3",
		icon_size = 128,
	},
})

	if data.raw.tool["bob-logistic-science-pack"] then
		table.insert(data.raw.technology["rapid-unloading"].unit.ingredients, {"bob-logistic-science-pack", 1})
		data.raw.technology["rapid-loading"].unit.count = 75
	end

	if data.raw.technology["express-loader"] then
		table.insert(data.raw.technology["rapid-unloading"].prerequisites, "express-loader")
	end
end