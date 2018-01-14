require "prototypes.warehouses"

if data.raw.tool["logistic-science-pack"] then --cut pack count in half, but add logi packs
	data.raw.technology.depot.unit.count = 100
	table.insert(data.raw.technology.depot.unit.ingredients, {"logistic-science-pack", 1})
end