require "config"

local function createCircuitSprite()
	local ret = {
        filename = "__AutoTrainDepot__/graphics/entity/circuit.png",
        x = 0,
        y = 0,
        width = 61,
        height = 50,
        frame_count = 1,
        --shift = {0.140625, 0.140625},
    }
	return ret
end

local function createCircuitActivitySprite()
	local ret = {
        filename = "__base__/graphics/entity/combinator/activity-leds/constant-combinator-LED-S.png",
        width = 11,
        height = 11,
        frame_count = 1,
        shift = {-0.296875, -0.078125},
    }
	return ret
end

local function createCircuitConnections()
	local ret = {
        shadow = {
          red = {0.235, 0.5625},
          green = {-0.265, 0.5625}
        },
        wire = {
          red = {0.235, 0.15625},
          green = {-0.265, 0.15625}
        }
    }
	return ret
end

local function createSignal(name)
	return
	{
		type = "virtual-signal",
		name = name,
		icon = "__AutoTrainDepot__/graphics/icons/" .. name .. ".png",
		icon_size = 32,
		subgroup = "virtual-signal-special",
		order = name,
	}
end

local stop = table.deepcopy(data.raw["train-stop"]["train-stop"])
stop.name = "smart-train-stop"
stop.minable.result = stop.name
stop.fast_replaceable_group = "train-stop"
data.raw["train-stop"]["train-stop"].fast_replaceable_group = stop.fast_replaceable_group

local item = table.deepcopy(data.raw.item["train-stop"])
item.name = stop.name
item.place_result = stop.name

data:extend({
	stop,
	item,
	{
		type = "recipe",
		name = stop.name,
		energy_required = 2.5,
		enabled = false,
		--category = "crafting",
		ingredients = {
			{"train-stop", 1},
			{"advanced-circuit", 1},
			{"red-wire", 4}
		},
		result = stop.name
	},
	createSignal("train-ingredients-full"),
	createSignal("train-ingredients-empty"),
	createSignal("train-products-full"),
	createSignal("train-products-empty"),
	{
		type = "constant-combinator",
		name = "smart-train-stop-output",
		icon = "__base__/graphics/icons/constant-combinator.png",
		icon_size = 32,
		flags = {"placeable-neutral", "player-creation", "not-on-map", "placeable-off-grid", "not-blueprintable", "not-deconstructable"},
		order = "z",
		max_health = 100,
		destructible = false,
		--collision_mask = {},

		--collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
		selection_box = {{-0.5, -0.5}, {0.5, 0.5}},

		item_slot_count = 4,

		sprites =
		{
		  north = createCircuitSprite(),
		  west = createCircuitSprite(),
		  east = createCircuitSprite(),
		  south = createCircuitSprite(),
		},

		activity_led_sprites = {
		  north = createCircuitActivitySprite(),
		  west = createCircuitActivitySprite(),
		  east = createCircuitActivitySprite(),
		  south = createCircuitActivitySprite(),
		},

		activity_led_light =
		{
		  intensity = 0.8,
		  size = 1,
		},

		activity_led_light_offsets =
		{
		  {-0.296875, -0.078125},
		  {-0.296875, -0.078125},
		  {-0.296875, -0.078125},
		  {-0.296875, -0.078125},
		},

		circuit_wire_connection_points = {
		  createCircuitConnections(),
		  createCircuitConnections(),
		  createCircuitConnections(),
		  createCircuitConnections(),
		},

		circuit_wire_max_distance = 7.5
	},
	  {
		type = "lamp",
		name = "smart-train-stop-power",
		icon = "__base__/graphics/icons/small-lamp.png",
		icon_size = 32,
		destructible = false,
		flags = {"placeable-neutral", "player-creation", "not-on-map", "placeable-off-grid", "not-blueprintable", "not-deconstructable"},
		minable = nil,
		selectable_in_game = false,
		order = "z",
		max_health = 100,
		corpse = "small-remnants",
		--collision_box = {{-0.15, -0.15}, {0.15, 0.15}},
		--selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
		vehicle_impact_sound =  { filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
		energy_source =
		{
		  type = "electric",
		  usage_priority = "lamp",
		  buffer_capacity = "25kJ",
		  drain = "20kW",
		},
		energy_usage_per_tick = "20kW",
		darkness_for_all_lamps_on = 0.001,
		darkness_for_all_lamps_off = 0.0001,
		light = nil,
		light_when_colored = nil,
		glow_size = 0,
		glow_color_intensity = 0,
		picture_off =
		{
		  layers =
		  {
			{
			  filename = "__core__/graphics/empty.png",
			  priority = "high",
			  width = 1,
			  height = 1,
			  frame_count = 1,
			},
		  }
		},
		picture_on =
		{
		  filename = "__core__/graphics/empty.png",
		  priority = "high",
		  width = 1,
		  height = 1,
		  frame_count = 1,
		},
		signal_to_color_mapping = {},

		circuit_wire_connection_point = nil,
		circuit_connector_sprites = nil,
		circuit_wire_max_distance = nil,
	  },
})