require "config"

if not Config.unloader then return end

local function redirectTextureFile(str)
	return string.gsub(str, "__base__/graphics/entity/stack-filter-inserter/", "__AutoTrainDepot__/graphics/entity/unloader")
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

local unloader = table.deepcopy(data.raw.inserter["stack-filter-inserter"])
unloader.name = "train-unloader"
unloader.icon = "__AutoTrainDepot__/graphics/icons/unloader.png"
unloader.minable.result = "train-unloader"
unloader.max_health = 450
--unloader.collision_box = {{-0.4, -0.9}, {0.4, 0.9}}
--unloader.selection_box = {{-0.5, -1}, {0.5, 1}}
--unloader.pickup_position = {0, -1.5}
--unloader.insert_position = {0, 1.7}

--unloader.collision_box = {{-0.9, -0.9}, {0.9, 0.9}}
--unloader.selection_box = {{-0.5, -0.5}, {0.5, 0.5}}
--unloader.pickup_position = {0, -1.5}
--unloader.insert_position = {0, 1.7}

unloader.energy_per_movement = 5000 --less in raw value, but given the insane rate of operations... ~500kW
unloader.energy_per_rotation = 5000
unloader.energy_source = {
	type = "electric",
	usage_priority = "secondary-input",
	drain = "5kW"
}
unloader.extension_speed = 1--0.7--0.07
unloader.rotation_speed = 0.8--0.4--0.04
unloader.fast_replaceable_group = nil
unloader.working_sound = {
	match_progress_to_activity = true,
	sound = {
		{
			filename = "__AutoTrainDepot__/sounds/unloader.ogg",
			volume = 1
        }
	}
}
clearTexture(unloader.hand_base_picture)
clearTexture(unloader.hand_closed_picture)
clearTexture(unloader.hand_open_picture)
clearTexture(unloader.hand_base_shadow)
clearTexture(unloader.hand_open_shadow)
clearTexture(unloader.hand_closed_shadow)
--redirectTexture(unloader.platform_picture)

unloader.platform_picture =
    {
      sheet =
      {
        filename = "__AutoTrainDepot__/graphics/entity/unloader-3.png",
        priority = "extra-high",
        width = 105,
        height = 79,
		scale = 0.5,
        shift = {0, 0},
      }
    }

local item = table.deepcopy(data.raw.item["stack-filter-inserter"])
item.name = unloader.name
item.place_result = unloader.name
item.icon = unloader.icon

local recipe = {
	type = "recipe",
	name = unloader.name,
    enabled = false,
	energy_required = 8,
    ingredients =
    {
      {"stack-filter-inserter", 4},
      {"express-transport-belt", 8},
      {"steel-chest", 1},
      {"processing-unit", 10},
    },
    result = unloader.name
}

data:extend({unloader, item, recipe})

--table.insert(data.raw.technology.depot.effects, {type = "unlock-recipe", recipe = unloader.name})