require "config"

local speedFactor = 0.2
local powerConsumption = 900 --in kW

if not Config.reloader then return end

local function redirectTextureFile(str)
	return string.gsub(str, "__base__/graphics/entity/stack-inserter/", "__AutoTrainDepot__/graphics/entity/reloader")
end

local function redirectTexture(entry)
	if entry.sheet then redirectTexture(entry.sheet) return end
	entry.filename = redirectTextureFile(entry.filename)
	if entry.hr_version then
		entry.hr_version.filename = redirectTextureFile(entry.hr_version.filename)
	end
end

local function clearTexture(entry)
	if entry.sheet then clearTexture(entry.sheet) return end
	entry.filename = "__core__/graphics/empty.png"
	entry.width = 1
	entry.height = 1
	entry.shift = nil
	entry.hr_version = nil
end

local reloader = table.deepcopy(data.raw.inserter["stack-inserter"])
reloader.name = "train-reloader"
reloader.icon = "__AutoTrainDepot__/graphics/icons/reloader.png"
reloader.minable.result = "train-reloader"
reloader.max_health = 450
reloader.draw_held_item = false
--reloader.allow_custom_vectors = false

--reloader.collision_box = {{-0.4, -0.9}, {0.4, 0.9}}
--reloader.selection_box = {{-0.5, -1}, {0.5, 1}}
--reloader.pickup_position = {0, -1.5}
--reloader.insert_position = {0, 1.7}

--reloader.collision_box = {{-0.9, -0.9}, {0.9, 0.9}}
--reloader.selection_box = {{-0.5, -0.5}, {0.5, 0.5}}
--reloader.pickup_position = {0, -1.5}
--reloader.insert_position = {0, 1.7}

reloader.energy_per_movement = 7500/speedFactor*powerConsumption/810 .. "kJ" --less in raw value, but given the insane rate of operations... 5000 -> 7500 yields 540kW -> 810kW
reloader.energy_per_rotation = 7500/speedFactor*powerConsumption/810 .. "kJ"
reloader.energy_source = {
	type = "electric",
	usage_priority = "secondary-input",
	drain = "50kW"
}
reloader.extension_speed = 1*speedFactor--0.7--0.07
reloader.rotation_speed = 0.8*speedFactor--0.4--0.04

--[[
reloader.stack = false --to avoid being bad until stack size researches are completed?
reloader.rotation_speed = reloader.rotation_speed*12
reloader.extension_speed = reloader.extension_speed*12
reloader.energy_per_rotation = reloader.energy_per_rotation/12
reloader.energy_per_movement = reloader.energy_per_movement/12
--]]

reloader.fast_replaceable_group = nil
reloader.working_sound = {
	match_progress_to_activity = true,
	sound = {
		{
			filename = "__AutoTrainDepot__/sounds/reloader.ogg",
			volume = 1
        }
	}
}
clearTexture(reloader.hand_base_picture)
clearTexture(reloader.hand_closed_picture)
clearTexture(reloader.hand_open_picture)
clearTexture(reloader.hand_base_shadow)
clearTexture(reloader.hand_open_shadow)
clearTexture(reloader.hand_closed_shadow)
--redirectTexture(reloader.platform_picture)

reloader.platform_picture =
    {
      sheet =
      {
        filename = "__AutoTrainDepot__/graphics/entity/reloader-3.png",
        priority = "extra-high",
        width = 120,
        height = 96,
		scale = 0.5,
        shift = {0, 0},
      }
    }

local item = table.deepcopy(data.raw.item["stack-inserter"])
item.name = reloader.name
item.place_result = reloader.name
item.icon = reloader.icon

local recipe = {
	type = "recipe",
	name = reloader.name,
    enabled = false,
	energy_required = 6,
    ingredients =
    {
      {"stack-inserter", 3},
      {"express-transport-belt", 6},
      {"steel-chest", 1},
      {"processing-unit", 2},
    },
    result = reloader.name
}

if data.raw.recipe["express-loader"] then
	if mods["FTweaks"] and data.raw.item["cobalt-steel-alloy"] then
		recipe.ingredients = {
			{"express-loader", 1},
			{"express-transport-belt", 12},
			{"steel-chest", 6},
			{"processing-unit", 9},
			{"brass-gear-wheel", 18},
		}
		recipe.result_count = 6
	else
		recipe.ingredients = {
			{"express-loader", 1},
			{"express-transport-belt", 3},
			{"steel-chest", 2},
			{"processing-unit", 2},
		}
		recipe.result_count = 2
	end
elseif data.raw.item["cobalt-steel-alloy"] then
	table.insert(recipe.ingredients, {"cobalt-steel-gear-wheel", 3})
	table.insert(recipe.ingredients, {"aluminium-plate", 6})
end

data:extend({reloader, item, recipe})

--table.insert(data.raw.technology.depot.effects, {type = "unlock-recipe", recipe = reloader.name})