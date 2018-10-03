require "config"
require "trainhandling"
require "controller"
require "fluidcontroller"
require "alerts"

tickRate = 60--300--60

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
	local depot = global.depot
	
	for _,entry in pairs(depot.entries) do
		if entry.type == nil then
			entry.type = "item"
		end
	end
	
	if depot.trainAlerts then
		for force,li in pairs(depot.trainAlerts) do
			for id,alert in pairs(li) do
				if alert.validate == nil or type(alert.validate) == "function" then
					li[id] = nil
				end
			end
		end
	end
end)

script.on_init(function()
	initGlobal(true)
end)

script.on_event(defines.events.on_tick, function(event)
	local depot = global.depot
	if event.tick%tickRate == 0 then
		for i, entry in ipairs(depot.entries) do
			--game.print("Ticking depot " .. entry.storage.name)
			if entry.type == "item" then
				tickDepot(depot, entry, event.tick)
			elseif entry.type == "fluid" then
				tickFluidDepot(depot, entry, event.tick)
			end
		end
	end
	for _,force in pairs(game.forces) do
		if event.tick%300 == 0 and force.technologies["train-alarms"].researched then
			local fired = false
			if event.tick%600 == 0 then --10s
				fired = checkTrainAlerts(depot, event.tick, force)
			end
			if depot.trainAlerts and event.tick%300 == 0 then
				tickTrainAlerts(depot, (not fired), force)
			end
		end
		
		if event.tick%150 == 0 and force.technologies["depot-cargo-filters"].researched then --every 2.5s
			for _,train in pairs(force.get_trains(game.surfaces[1])) do
				if train.schedule and #train.schedule.records > 0 then
					local entry = getOrCreateTrainEntryByTrain(depot, train)
					if entry then
						local filters = getTrainItemFilterData(depot, train)
						if filters then--and train.station then
							--local stops = train.schedule.records
							--local stop =
							local stationIndex = train.schedule.current
							for _,car in pairs(entry.cars) do
								if car.type == "cargo-wagon" and filters[car.index] then
									local entity = train.carriages[car.position]
									local filter = filters[car.index][stationIndex]
									local inv = entity.get_inventory(defines.inventory.cargo_wagon)
									if inv and filter ~= "skip" then
										for i = 1,#inv do
											inv.set_filter(i, filter)
										end
										--force.print("Setting filters on train " .. entry.displayName .. " car " .. car.index .. " to " .. (filter and filter or "nil") .. " for station " .. train.schedule.records[stationIndex].station)
									end
								end
							end
						end
					end
				end
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
	if entity.name == "depot-controller" or entity.name == "depot-fluid-controller" then
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

script.on_event(defines.events.on_gui_click, function(event)
	handleTrainGUIClick(event)
end)