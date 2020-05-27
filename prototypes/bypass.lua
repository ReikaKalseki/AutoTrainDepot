local function createCircuitSprite()
	local ret = {
        filename = "__AutoTrainDepot__/graphics/entity/bypass-beacon.png",
        width = 89,
        height = 154,
        frame_count = 1,
		direction_count = 1,
		scale = 0.5,
        shift = {0, -0.66},
    }
	return ret
end

local name = "station-bypass-beacon"
local entity = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
entity.name = name
entity.minable.result = name
entity.icon = "__AutoTrainDepot__/graphics/icons/bypass.png"
entity.icon_size = 32
entity.icon_mipmaps = 0
entity.energy_source = {type = "electric", usage_priority = "secondary-input"}
entity.active_energy_usage = "4KW"
entity.item_slot_count = 0
entity.sprites = {
	north = createCircuitSprite(),
	west = createCircuitSprite(),
	east = createCircuitSprite(),
	south = createCircuitSprite(),
}

local item = table.deepcopy(data.raw.item["constant-combinator"])
item.name = name
item.icon = entity.icon
item.icon_size = 32
item.icon_mipmaps = 0
item.place_result = name
item.localised_name = entity.localised_name

local recipe = table.deepcopy(data.raw.recipe["constant-combinator"])
recipe.name = name
recipe.result = name
recipe.ingredients = {
	{"constant-combinator", 1},
	{"advanced-circuit", 1},
	{"steel-plate", 4},
}

data:extend({entity, item, recipe})