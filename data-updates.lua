require "prototypes.warehouses"

if data.raw.tool["logistic-science-pack"] then --cut pack count in half, but add logi packs
	data.raw.technology.depot.unit.count = data.raw.technology.depot.unit.count/2
	table.insert(data.raw.technology.depot.unit.ingredients, {"logistic-science-pack", 1})
	
	data.raw.technology["fluid-depot"].unit.count = data.raw.technology["fluid-depot"].unit.count/2
	table.insert(data.raw.technology["fluid-depot"].unit.ingredients, {"logistic-science-pack", 1})
	
	data.raw.technology["depot-base"].unit.count = data.raw.technology["depot-base"].unit.count/2 --halve this too, even though it is not getting any new packs -> keeps the higher techs more expensive than the lower
	
	if data.raw.technology.unloader then
		data.raw.technology.unloader.unit.count = data.raw.technology.unloader.unit.count*3/5
		table.insert(data.raw.technology.unloader.unit.ingredients, {"logistic-science-pack", 1})
	end
end

if data.raw.item["bronze-alloy"] then
	table.insert(data.raw.recipe["basic-depot-controller"].ingredients, {"bronze-alloy", 20})
	table.insert(data.raw.technology["depot-base"].prerequisites, "alloy-processing-1")
	table.insert(data.raw.recipe["basic-depot-controller"].ingredients, {"steel-plate", 10})
else
	table.insert(data.raw.recipe["basic-depot-controller"].ingredients, {"steel-plate", 30})
end

if data.raw.item["aluminium-plate"] then
	table.insert(data.raw.recipe["depot-controller"].ingredients, {"aluminium-plate", 20})
	table.insert(data.raw.recipe["depot-fluid-controller"].ingredients, {"aluminium-plate", 20})
	table.insert(data.raw.technology["depot"].prerequisites, "aluminium-processing")
	table.insert(data.raw.technology["fluid-depot"].prerequisites, "aluminium-processing")
else
	table.insert(data.raw.recipe["depot-controller"].ingredients, {"steel-plate", 40})
	table.insert(data.raw.recipe["depot-fluid-controller"].ingredients, {"steel-plate", 40})
end