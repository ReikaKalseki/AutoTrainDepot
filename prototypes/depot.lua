data:extend({
  {
	type = "item",
	name = "depot-controller",
	icon = "__AutoTrainDepot__/graphics/icons/depot-controller.png",
	icon_size = 32,
    flags = {"goes-to-quickbar"},
    subgroup = "storage",
    order = "b[items]-b[depot]",
    place_result = "depot-controller",
    stack_size = 1
  },
  {
	type = "recipe",
	name = "depot-controller",
    enabled = false,
	energy_required = 4,
    ingredients =
    {
      {"arithmetic-combinator", 2},
      {"engine-unit", 4},
      {"fast-transport-belt", 20},
      {"electronic-circuit", 50},
      {"red-wire", 20},
    },
    result = "depot-controller"
  }
})

local function createSprite()
return {
        filename = "__AutoTrainDepot__/graphics/entity/depot-controller.png",
        x = 0,
        y = 0,
        width = 179,
        height = 179,
        frame_count = 1,
        shift = {1.33, -1.4},
      }
end

local function createCircuitConnection()
return {
        shadow = {
          red = {0.7725, -3.3125},
          green = {0.7725, -3.3125}
        },
        wire = {
          red = {0.27875, -3.5825},
          green = {0.27875, -3.5825},
        }
      }
end

data:extend({
  {
    type = "constant-combinator",
    name = "depot-controller",
    icon = "__base__/graphics/icons/constant-combinator.png",
	icon_size = 32,
    flags = {"placeable-neutral", "player-creation"},
    minable = {hardness = 0.2, mining_time = 0.5, result = "depot-controller"},
    max_health = 100,
    corpse = "small-remnants",

    collision_box = {{-0.85, -0.85}, {0.85, 0.85}},
    selection_box = {{-1, -1}, {1, 1}},

    item_slot_count = 1,

    sprites =
    {
      north = createSprite(),
      east = createSprite(),
      south = createSprite(),
      west = createSprite(),
    },

    activity_led_sprites = {
      north = {
        filename = "__core__/graphics/empty.png",
        width = 1,
        height = 1,
        frame_count = 1,
      },
      east = {
        filename = "__core__/graphics/empty.png",
        width = 1,
        height = 1,
        frame_count = 1,
      },
      south = {
        filename = "__core__/graphics/empty.png",
        width = 1,
        height = 1,
        frame_count = 1,
      },
      west = {
        filename = "__core__/graphics/empty.png",
        width = 1,
        height = 1,
        frame_count = 1,
      }
    },

    activity_led_light = nil,

    activity_led_light_offsets = {{0, 0}, {0, 0}, {0, 0}, {0, 0}},

    circuit_wire_connection_points = {
      createCircuitConnection(),
	  createCircuitConnection(),
	  createCircuitConnection(),
	  createCircuitConnection(),
    },

    circuit_wire_max_distance = 18
  }
})


data:extend({
  { --for display in the circuit gui
    type = "virtual-signal",
    name = "depot-divisions",
    icon = "__AutoTrainDepot__/graphics/icons/divisions.png",
	icon_size = 32,
    subgroup = "virtual-signal-special",
    order = "depot-divisions",
  }
})
