require("config")

require("prototypes.depot")
require("prototypes.fluid-depot")
require("prototypes.unloader")
require "prototypes.alerts"
require "prototypes.stop"
require "prototypes.bypass"
--require("prototypes.large-storage")
--require("prototypes.technology")

data:extend({{
	type = "item",
	name = "skip-filter-swap",
	icon = "__core__/graphics/cancel.png",--"__AutoTrainDepot__/graphics/icons/skip-swap.png",
	icon_size = 64,
	order = "z",
	stack_size = 1,
	hidden = true,
	flags = {},
	subgroup = "transport",
}})