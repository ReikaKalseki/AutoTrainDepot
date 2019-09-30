if Config.unloader and data.raw.loader["express-loader"] then

	local loader = table.deepcopy(data.raw.loader["express-loader"])
	loader.name = "train-unloader"
	loader.minable.result = loader.name
	loader.icon = "__AutoTrainDepot__/graphics/icons/unloader.png"

	loader.structure.direction_in.sheet.filename = "__AutoTrainDepot__/graphics/entity/unloader.png"
	loader.structure.direction_out.sheet.filename = "__AutoTrainDepot__/graphics/entity/unloader.png"
	
	local belt = --[[data.raw["transport-belt"]["turbo-transport-belt"] and data.raw["transport-belt"]["turbo-transport-belt"] or --]]data.raw["transport-belt"]["express-transport-belt"]
	
	for _,belt2 in pairs(data.raw["transport-belt"]) do
		if belt2.speed > belt.speed then
			belt = belt2
		end
	end

	loader.speed = belt.speed
	
	loader.belt_horizontal = belt.belt_horizontal
	loader.belt_vertical = belt.belt_vertical
	loader.ending_top = belt.ending_top
	loader.ending_bottom = belt.ending_bottom
	loader.ending_side = belt.ending_side
	loader.starting_top = belt.starting_top
	loader.starting_bottom = belt.starting_bottom
	loader.starting_side = belt.starting_side
	
	local item = table.deepcopy(data.raw.item["express-loader"])
	item.name = loader.name
	item.place_result = item.name
	item.icon = loader.icon
	
	local recipe = table.deepcopy(data.raw.recipe["train-reloader"])
	if not recipe then 
		recipe = table.deepcopy(data.raw.recipe["stack-filter-inserter"])
	end
	recipe.name = loader.name
	recipe.result = loader.name
	recipe.energy_required = 24
	for _,ing in pairs(recipe.ingredients) do
		if ing[1] == "express-loader" then
			ing[2] = 2
		end
	end

	data:extend({
		loader,
		item,
		recipe
	})
end
