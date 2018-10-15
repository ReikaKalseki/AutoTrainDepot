require "config"
require "trainhandling"
require "controller"
require "fluidcontroller"
require "smartstop"
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
	if depot.stops == nil then
		depot.stops = {}
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
	if event.tick%300 == 0 then
		for _,force in pairs(game.forces) do
			if force.technologies["train-alarms"].researched then
				local fired = false
				if event.tick%600 == 0 then --10s
					fired = checkTrainAlerts(depot, event.tick, force)
				end
				if depot.trainAlerts and event.tick%300 == 0 then
					tickTrainAlerts(depot, (not fired), force)
				end
			end
		end
	end
	if event.tick%60 == 0 then
		for unit,entry in pairs(depot.stops) do
			if entry.entity.valid then
				tickSmartTrainStop(depot, entry)
			else
				depot.stops[unit] = nil
			end
		end
		
		if depot.stopReplacement then
			for pos,entry in pairs(depot.stopReplacement) do
				if event.tick-entry.age > 5 then
					depot.stopReplacement[pos] = nil
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
	if entry.pulls then
		for unit,pull in pairs(entry.pulls) do
			if pull.entity.valid and pull.entity.name == "train-unloader" then
				pull.entity.active = false
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
	elseif entity.name == "smart-train-stop" then
		local depot = global.depot
		local entry = depot.stops[entity.unit_number]
		if entry then
			entry.output.disconnect_neighbour(defines.wire_type.red)
			entry.output.disconnect_neighbour(defines.wire_type.green)
			entry.power.destroy()
			entry.output.destroy()
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
	elseif entity.name == "train-stop" then
		local depot = global.depot
		local key = entity.position.x .. "/" .. entity.position.y
		local val = {}
		for _,train in pairs(entity.get_train_stop_trains()) do
			val[train.id] = true
		end
		if #entity.get_train_stop_trains() > 0 then
			if not depot.stopReplacement then depot.stopReplacement = {} end
			depot.stopReplacement[key] = {old = entity.backer_name, trains = val, age = game.tick}
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
		entity.operable = false
	elseif entity.name == "smart-train-stop" then
		local depot = global.depot
		local conn = entity.surface.create_entity{name = "smart-train-stop-output", position = {entity.position.x-0.05, entity.position.y+0.875}, force = entity.force}
		local e2 = entity.surface.create_entity{name = "smart-train-stop-power", position = {entity.position.x, entity.position.y}, force = entity.force}
		entity.connect_neighbour({target_entity = conn, wire = defines.wire_type.red})
		depot.stops[entity.unit_number] = {entity = entity, power = e2, output = conn}
		local key = entity.position.x .. "/" .. entity.position.y
		local old = depot.stopReplacement and depot.stopReplacement[key] or nil
		if old and game.tick-old.age < 5 then
			for _,train in pairs(entity.force.get_trains(entity.surface)) do
				if old.trains[train.id] then
					local data = train.schedule
					for _,stop in pairs(data.records) do
						if stop.station == old.old then
							stop.station = entity.backer_name
							table.insert(stop.wait_conditions, {type = "circuit", compare_type = "and", condition = {comparator = "=", first_signal = {type = "virtual", name = "train-ingredients-full"}, constant = 0}})
							table.insert(stop.wait_conditions, {type = "circuit", compare_type = "and", condition = {comparator = "=", first_signal = {type = "virtual", name = "train-products-empty"}, constant = 0}})
						end
					end
					train.schedule = data
				end
			end
		end
	end
end

local function onEntityCopyPaste(event)
	local e1 = event.source
	local e2 = event.destination
	local player = game.players[event.player_index]
	if e1.type == e2.type and e1.type == "locomotive" then
		copyTrainSettings(e1, e2)
	end
end

local function handleTrainStateChange(train)
	if #train.carriages == 0 then return end
	local depot = global.depot
	local force = train.carriages[1].force
	local entry = getOrCreateTrainEntryByTrain(depot, train)
	if (train.state == defines.train_state.arrive_station or train.state == defines.train_state.wait_station) and force.technologies["depot-cargo-filters"].researched then
		local filters = getTrainItemFilterData(depot, train)
		if filters then
			local stationIndex = train.schedule.current
			for _,car in pairs(entry.cars) do
				if car.type == "cargo-wagon" and stationIndex and filters[car.index] then
					local entity = train.carriages[car.position]
					local filter = filters[car.index][stationIndex]
					local inv = entity.get_inventory(defines.inventory.cargo_wagon)
					if inv and filter ~= "skip-filter-swap" then
						for i = 1,#inv do
							if filter == nil or filter == "nil" then
								inv.set_filter(i, nil)
							else
								inv.set_filter(i, filter)
							end
						end
						--force.print("Setting filters on train " .. entry.displayName .. " car " .. car.index .. " to " .. (filter and filter or "nil") .. " for station " .. train.schedule.records[stationIndex].station)
					end
				end
			end
		end
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

script.on_event(defines.events.on_train_changed_state, function(event)
	handleTrainStateChange(event.train)
end)

script.on_event(defines.events.on_train_created, function(event)
	handleTrainModification(event.train, event.old_train_id_1, event.old_train_id_2)
end)

script.on_event(defines.events.on_entity_settings_pasted, function(event)
	onEntityCopyPaste(event)
end)