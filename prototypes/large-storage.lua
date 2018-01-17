require "config"

local storage = table.deepcopy(data.raw.container["wooden-chest"])
storage.name = "large-depot"
storage.icon = "__AutoTrainDepot__/graphics/icons/storage.png"
storage.minable.result = storage.name
storage.max_health = 1200
storage.collision_box = {{-17.5, -4.5}, {17.5, 4.5}}
storage.selection_box = {{-18, -5}, {18, 5}}
storage.picture.filename = "__AutoTrainDepot__/graphics/entity/large-storage-2.png"
storage.picture.width = 1120
storage.picture.height = 287
storage.inventory_size = 1000
storage.corpse = "big-remnants"

local item = table.deepcopy(data.raw.item["wooden-chest"])
item.name = storage.name
item.place_result = storage.name
item.icon = storage.icon

local recipe = {
	type = "recipe",
	name = storage.name,
    enabled = false,
	energy_required = 8,
    ingredients =
    {
      {"concrete", 350},
      {"fast-transport-belt", 20},
      {"transport-belt", 30},
      {"steel-chest", 10},
      {"wooden-chest", 10},
      {"advanced-circuit", 10},
      {"assembling-machine-1", 6},
    },
    result = storage.name
}

data:extend({storage, item, recipe})