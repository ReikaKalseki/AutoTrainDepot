require "prototypes.warehouses"

require("prototypes.technology")
--[[
if data.raw.tool["bob-logistic-science-pack"] then --cut pack count in half, but add logi packs
	data.raw.technology.depot.unit.count = data.raw.technology.depot.unit.count/2
	table.insert(data.raw.technology.depot.unit.ingredients, {"bob-logistic-science-pack", 1})
	
	data.raw.technology["fluid-depot"].unit.count = data.raw.technology["fluid-depot"].unit.count/2
	table.insert(data.raw.technology["fluid-depot"].unit.ingredients, {"bob-logistic-science-pack", 1})
	
	data.raw.technology["depot-base"].unit.count = data.raw.technology["depot-base"].unit.count/2 --halve this too, even though it is not getting any new packs -> keeps the higher techs more expensive than the lower
	
	if data.raw.technology.unloader then
		data.raw.technology.unloader.unit.count = data.raw.technology.unloader.unit.count*3/5
		table.insert(data.raw.technology.unloader.unit.ingredients, {"bob-logistic-science-pack", 1})
	end
end
--]]

if data.raw.item["bronze-alloy"] then
	table.insert(data.raw.recipe["depot-controller"].ingredients, {"bronze-alloy", 20})
else
	table.insert(data.raw.recipe["depot-controller"].ingredients, {"steel-plate", 30})
end

if data.raw.item["nickel-plate"] then
	table.insert(data.raw.recipe["depot-fluid-controller"].ingredients, {"nickel-plate", 20})
else
	table.insert(data.raw.recipe["depot-fluid-controller"].ingredients, {"steel-plate", 40})
end

if data.raw.item["brass-gear-wheel"] then
	table.insert(data.raw.recipe["smart-train-stop"].ingredients, {"brass-gear-wheel", 4})
else
	table.insert(data.raw.recipe["smart-train-stop"].ingredients, {"steel-plate", 8})
end

if Config.blockStations then
	local blocks = {"stopped_manually_controlled_train_without_passenger_penalty", "train_in_station_penalty", "train_in_station_with_no_other_valid_stops_in_schedule", "train_with_no_path_penalty", "train_arriving_to_station_penalty"}
	for _,k in pairs(blocks) do
		data.raw["utility-constants"].default.train_path_finding[k] = 999999999
	end
	
	local penalty = {"train_stop_penalty"}
	for _,k in pairs(penalty) do
		data.raw["utility-constants"].default.train_path_finding[k] = 100000
	end
end