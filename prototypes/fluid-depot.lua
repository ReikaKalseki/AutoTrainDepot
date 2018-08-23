local function createFluidSignals(i)
	local input = table.deepcopy(data.raw["virtual-signal"]["signal-" .. i])
	input.name = "signal-fluid-in" .. i
	input.icons = {{icon = input.icon, icon_size = input.icon_size}, {icon = "__AutoTrainDepot__/graphics/icons/fluid-signal-overlay.png", icon_size = 32}, {icon = "__AutoTrainDepot__/graphics/icons/fluid-signal-input.png", icon_size = 32}}
	local output = table.deepcopy(input)
	output.name = string.gsub(output.name, "in", "out")
	output.icons[3].icon = string.gsub(output.icons[3].icon, "input", "output")
	data:extend({input, output})
end

for i = 1,6 do
	createFluidSignals(i)
end

data:extend({
  {
	type = "item",
	name = "depot-fluid-controller",
	icon = "__AutoTrainDepot__/graphics/icons/depot-controller.png",
	icon_size = 32,
    flags = {"goes-to-quickbar"},
    subgroup = "storage",
    order = "b[items]-b[depot]",
    place_result = "depot-fluid-controller",
    stack_size = 1
  },
  {
	type = "recipe",
	name = "depot-fluid-controller",
    enabled = false,
	energy_required = 4,
    ingredients =
    {
      {"pump", 6},
      {"steel-plate", 80},
      {"pipe", 20},
      {"advanced-circuit", 10},
      {"green-wire", 40},
    },
    result = "depot-fluid-controller"
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
    name = "depot-fluid-controller",
    icon = "__base__/graphics/icons/constant-combinator.png",
	icon_size = 32,
    flags = {"placeable-neutral", "player-creation"},
    minable = {hardness = 0.2, mining_time = 0.5, result = "depot-fluid-controller"},
    max_health = 100,
    corpse = "small-remnants",

    collision_box = {{-0.85, -0.85}, {0.85, 0.85}},
    selection_box = {{-1, -1}, {1, 1}},

    item_slot_count = 12,

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