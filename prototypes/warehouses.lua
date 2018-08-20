require "config"

if not Config.largerWarehouses then return end

if data.raw.container["angels-warehouse"] then
	local tech = table.deepcopy(data.raw.technology["angels-warehouses"])
	tech.name = "bigger-" .. tech.name
	tech.unit.count = tech.unit.count*2
	table.insert(tech.unit.ingredients, {"science-pack-2", 1})
	tech.prerequisites = {"angels-warehouses", "advanced-electronics", "logistics-3"}
	tech.effects = {}
	
	local tech2 = table.deepcopy(data.raw.technology["angels-logistic-warehouses"])
	tech2.name = "bigger-" .. tech2.name
	tech2.unit.count = math.ceil(tech2.unit.count*1.5)
	if data.raw.tool["logistic-science-pack"] then
		table.insert(tech2.unit.ingredients, {"logistic-science-pack", 1})
	end
	tech2.prerequisites = {tech.name, "angels-logistic-warehouses", "advanced-electronics-2"}
	tech2.effects = {}
	
	tech.localised_name = {"bigger-warehouse.name", {"technology-name.angels-warehouses"}}
	tech2.localised_name = {"bigger-warehouse.name", {"technology-name.angels-logistic-warehouses"}}
	
	data:extend({tech, tech2})	

	local types = {"", "-active-provider", "-passive-provider", "-requester", "-buffer", "-storage"}
	
	for _,type in pairs(types) do
		local name = "angels-warehouse" .. type
		
		local research = tech.name
		
		local base = data.raw.container[name]
	
		if type ~= "" then
			research = tech2.name
			if not data.raw["logistic-container"][name] then --create missing buffer chest (lime green)
				local chest = table.deepcopy(data.raw["logistic-container"]["angels-warehouse-requester"])
				local item = table.deepcopy(data.raw.item["angels-warehouse"])
				chest.type = "logistic-container"
				chest.logistic_mode = string.sub(type, 2)
				chest.name = name
				item.name = name
				item.place_result = name
				chest.minable.result = item.name
				chest.icon = "__AutoTrainDepot__/graphics/icons/warehouse" .. type .. ".png"
				item.icon = chest.icon
				chest.picture.filename = "__AutoTrainDepot__/graphics/entity/warehouse" .. type .. ".png"
				local recipe = table.deepcopy(data.raw.recipe["angels-warehouse-requester"])
				recipe.name = name
				recipe.result = name
				data:extend({chest, item, recipe})
				log("Adding missing AngelWarehouse type '" .. type .. "'")
				table.insert(data.raw.technology["angels-logistic-warehouses"].effects, {type = "unlock-recipe", recipe = name})
			end
			
			base =  data.raw["logistic-container"][name]
		end

		local bigger = table.deepcopy(base)
		local item = table.deepcopy(data.raw.item[name])
		local recipe = table.deepcopy(data.raw.recipe[name])
		bigger.name = bigger.name .. "-large"
		if bigger.logistic_slots_count then
			bigger.logistic_slots_count = bigger.logistic_slots_count*2
		end
		item.name = bigger.name
		item.place_result = bigger.name
		bigger.inventory_size = 2500 --his is 768 by default
		bigger.minable.result = item.name
		bigger.localised_name = {"bigger-warehouse.name", {"entity-name." .. name}}
		item.localised_name = bigger.localised_name
		recipe.name = item.name
		recipe.result = item.name
		recipe.ingredients = {
			{name, 1},
			{"processing-unit", 20},
			{"refined-concrete", 200},
			{"steel-chest", 10},
		}
		
		log("Adding larger version of AngelWarehouse type '" .. (type == "" and "basic" or type) .. "'")
		
		data:extend({bigger, item, recipe})
		
		table.insert(data.raw.technology[research].effects, {type = "unlock-recipe", recipe = bigger.name})
	end
end