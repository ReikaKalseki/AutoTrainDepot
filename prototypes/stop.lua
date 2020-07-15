require "config"

require("__DragonIndustries__.cloning")

local connection = createFixedSignalAnchor("smart-train-stop-output")
connection.item_slot_count = 4

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

data.raw["train-stop"]["train-stop"].fast_replaceable_group = "train-stop"

local stop = copyObject("train-stop", "train-stop", "smart-train-stop")
stop.circuit_wire_max_distance = stop.circuit_wire_max_distance*2
stop.color={r=0.95,  g=0, b=0.95, a=0.5}
stop.fast_replaceable_group = "train-stop"

local item = copyObject("item", "train-stop", "smart-train-stop")
item.icon = "__AutoTrainDepot__/graphics/icons/smartstop.png"
item.icon_size = 32
item.icon_mipmaps = 0

local depotstop = copyObject("train-stop", "train-stop", "depot-stop")
depotstop.circuit_wire_max_distance = stop.circuit_wire_max_distance*2
depotstop.color={r=0,  g=0, b=0.95, a=0.5}
depotstop.fast_replaceable_group = "train-stop"

local depotstopitem = copyObject("item", "train-stop", "depot-stop")
depotstopitem.icon = "__AutoTrainDepot__/graphics/icons/depotstop.png"
depotstopitem.icon_size = 32
depotstopitem.icon_mipmaps = 0

data:extend({
	stop,
	item,
	depotstop,
	depotstopitem,
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
	{
		type = "recipe",
		name = depotstop.name,
		energy_required = 4,
		enabled = false,
		--category = "crafting",
		ingredients = {
			{"train-stop", 1},
			{"electronic-circuit", 60},
			{"red-wire", 30},
			{"rail-signal", 15},
		},
		result = depotstop.name
	},
	createSignal("train-ingredients-full"),
	createSignal("train-ingredients-empty"),
	createSignal("train-products-full"),
	createSignal("train-products-empty"),
	connection,
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