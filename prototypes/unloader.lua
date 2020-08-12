require "config"

require "__DragonIndustries__.sprites"

if Config.unloader and data.raw.loader["express-loader"] then
	local isInserter = data.raw.loader["express-loader"] == nil or Config.inserterUnloader
	local loader = isInserter and table.deepcopy(data.raw.inserter["stack-inserter"]) or table.deepcopy(data.raw.loader["express-loader"])
	loader.name = "train-unloader"
	loader.minable.result = loader.name
	loader.icon = "__AutoTrainDepot__/graphics/icons/unloader.png"
	loader.icon_size = 32
	
	if isInserter then
		local speedFactor = 0.3
		local widthFactor = 1 --based on collision box
		loader.draw_held_item = false
		loader.energy_per_movement = 5400/speedFactor*900/192 .. "J" --net value 1.8MW averaged and max activity
		loader.energy_per_rotation = 5400/speedFactor*900/192 .. "J"
		loader.energy_source = {
			type = "electric",
			usage_priority = "secondary-input",
			drain = "80kW"
		}
		loader.collision_box = {{-0.35, -2.35}, {0.35, 2.35}}
		loader.selection_box = {{-0.45, -2.45}, {0.45, 2.45}}
		loader.extension_speed = 1*speedFactor*widthFactor--0.7--0.07
		loader.rotation_speed = 0.8*speedFactor*widthFactor--0.4--0.04
		loader.pickup_position = {0, -3}
		loader.insert_position = {0, 3.2}
		loader.fast_replaceable_group = nil
		loader.next_upgrade = nil
		loader.working_sound = {
			match_progress_to_activity = true,
			sound = {
				{
					filename = "__AutoTrainDepot__/sounds/unloader.ogg",
					volume = 0.8
				}
			}
		}
		clearTexture(loader.hand_base_picture)
		clearTexture(loader.hand_closed_picture)
		clearTexture(loader.hand_open_picture)
		clearTexture(loader.hand_base_shadow)
		clearTexture(loader.hand_open_shadow)
		clearTexture(loader.hand_closed_shadow)
		--redirectTexture(loader.platform_picture)

		loader.platform_picture =
		{
		  sheet =
		  {
			filename = "__AutoTrainDepot__/graphics/entity/unloader-inserter-long.png",
			priority = "extra-high",
			width = 256,
			height = 256,
			scale = 0.75,
			shift = {0.0625, 0.03125},
		  }
		}
	else
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
	end

	local item = table.deepcopy(data.raw.item["stack-inserter"])
	item.name = loader.name
	item.place_result = item.name
	item.icon = loader.icon
	item.icon_size = 32
	
	local recipe = {
		type = "recipe",
		name = loader.name,
		enabled = false,
		energy_required = 24,
		ingredients =
		{
		  data.raw.item["express-loader"] and {"express-loader", 4} or {"stack-inserter", 10},
		  {"express-transport-belt", 25},
		  {"processing-unit", 15},
		  {"concrete", 50},
		  {"low-density-structure", 10},
		},
		result = loader.name
	}
		
	log("Adding train unloader '" .. recipe.name .. "'")

	data:extend({
		loader,
		item,
		recipe
	})
end
