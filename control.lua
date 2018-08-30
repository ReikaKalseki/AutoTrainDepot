require "config"
require "trainhandling"
require "controller"
require "fluidcontroller"

local tickRate = 60--300--60

function initGlobal(markDirty)
	if not global.depot then
		global.depot = {}
	end
	local depot = global.depot
	if depot.entries == nil then
		depot.entries = {}
	end
	if depot.trains == nil then
		depot.trains = {}
	end
	depot.dirty = markDirty
end

script.on_configuration_changed(function()
	initGlobal(true)
	
	for _,entry in pairs(global.depot.entries) do
		if entry.type == nil then
			entry.type = "item"
		end
	end
end)

script.on_init(function()
	initGlobal(true)
end)

script.on_event(defines.events.on_tick, function(event)
	if event.tick%tickRate == 0 then
		local depot = global.depot
		for i, entry in ipairs(depot.entries) do
			--game.print("Ticking depot " .. entry.storage.name)
			if entry.type == "item" then
				tickDepot(entry, event.tick)
			elseif entry.type == "fluid" then
				tickFluidDepot(depot, entry, event.tick)
			end
		end
	end
end)

local function invalidate(entry)
	if entry.pumps then
		for _,pump in pairs(entry.pumps) do
			if pump.combinator then
				local net = pump.combinator.circuit_connected_entities
				local clr = pump.wire == defines.wire_type.red and "red" or "green"
				local data = net[clr]
				for _,e in pairs(data) do
					if e.type == "electric-pole" then
						pole = e
						break
					end
				end
				pump.combinator.destroy()
				if pole then
					pole.connect_neighbour({target_entity = pump.entity, wire = pump.wire})
				end
			end
		end
	end
end

local function onEntityRemoved(entity)
	if entity.name == "basic-depot-controller" or entity.name == "depot-controller" or entity.name == "depot-fluid-controller" then
		local depot = global.depot
		for i, entry in ipairs(depot.entries) do
			if entry.controller.position.x == entity.position.x and entry.controller.position.y == entity.position.y then
				invalidate(entry)
				--entry.placer.destroy()
				--entry.render.destroy()
				table.remove(depot.entries, i)
				break
			end
		end
	elseif entity.type == "pump" and entity.circuit_connected_entities and (#entity.circuit_connected_entities["red"] > 0 or #entity.circuit_connected_entities["green"] > 0) then --remove combinators for pumps that are removed
		for _, entry in pairs(global.depot.entries) do
			if entry.pumps then
				for _,pump in pairs(entry.pumps) do
					if pump.entity == entity and pump.combinator then
						pump.combinator.destroy()
					end
				end
			end
		end
	end
end

local function onEntityAdded(entity)
	if entity.name == "depot-controller" then
		local depot = global.depot
		local entry = {controller = entity, storages = {}, type = "item"}
		table.insert(depot.entries, entry)
	elseif entity.name == "basic-depot-controller" then
		local depot = global.depot
		local entry = {controller = entity, storages = {}, type = "item", basic = true}
		table.insert(depot.entries, entry)
	elseif entity.name == "depot-fluid-controller" then
		local depot = global.depot
		local entry = {controller = entity, type = "fluid"}
		table.insert(depot.entries, entry)
	elseif entity.name == "train-unloader" then
		entity.active = false
	end
end

script.on_event(defines.events.on_entity_died, function(event)
	onEntityRemoved(event.entity)	
end)

script.on_event(defines.events.on_pre_player_mined_item, function(event)
	onEntityRemoved(event.entity)
end)

script.on_event(defines.events.on_robot_pre_mined, function(event)
	onEntityRemoved(event.entity)
end)

script.on_event(defines.events.on_built_entity, function(event)
	onEntityAdded(event.created_entity)
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
	onEntityAdded(event.created_entity)
end)

script.on_event(defines.events.on_gui_opened, function(event)
	handleTrainGUI(event, true)
end)

script.on_event(defines.events.on_gui_closed, function(event)
	handleTrainGUI(event, false)
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
	handleTrainGUIState(event)
end)