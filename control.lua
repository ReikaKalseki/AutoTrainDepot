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
	if depot.bypassBeacons == nil then
		depot.bypassBeacons = {}
	end
	if depot.pendingBypasses == nil then
		depot.pendingBypasses = {}
	end
	if depot.stationToDepot == nil then
		depot.stationToDepot = {}
	end
	depot.dirty = markDirty
end

script.on_configuration_changed(function()
	initGlobal(true)
	local depot = global.depot
	
	for key,entry in pairs(depot.entries) do
		depot.entries[entry.controller.unit_number] = entry
		if entry.type == nil then
			entry.type = "item"
		end
		if entry.stations then
			for key,station in pairs(entry.stations) do
				entry.stations[station.entity.backer_name] = station
				depot.stationToDepot[station.entity.unit_number] = entry.controller.unit_number
				depot.stationToDepot[station.entity.backer_name] = entry.controller.unit_number
				--game.print("Adding " .. station.entity.backer_name .. " #" .. station.entity.unit_number .. " to depot " .. entry.controller.unit_number)
				--entry.stations[key] = nil
			end
		end
		--depot.entries[key] = nil
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

local function removeTrainStopFromCache(entity)
	local depot = global.depot
	depot.stationToDepot[entity.unit_number] = nil
	depot.stationToDepot[entity.backer_name] = nil
	--game.print("Removing station " .. entity.backer_name)
	for _,entry in pairs(global.depot.entries) do
		--log(serpent.block(entry))
		if entry.stations then
			entry.stations[entity.backer_name] = nil
		end
	end
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

local function checkEntityConnections(entity, wire)
	local net = entity.circuit_connected_entities
	local clr = wire == defines.wire_type.red and "red" or "green"
	local data = net[clr]
	if data then
		for _,val in pairs(data) do
			if val.type == "train-stop" then
				--game.print("Found " .. val.name)
				return val
			end
		end
	end
end

local function findConnection(entity)
	local ret = checkEntityConnections(entity, defines.wire_type.red)
	if not ret then
		ret = checkEntityConnections(entity, defines.wire_type.green)
	end	
	return ret
end

script.on_event(defines.events.on_tick, function(event)
	local depot = global.depot
	if event.tick%tickRate == 0 then
		for unit,entry in pairs(depot.entries) do
			if entry.controller.valid then
				--game.print("Ticking depot " .. entry.storage.name)
				if entry.type == "item" then
					tickDepot(depot, entry, event.tick)
				elseif entry.type == "fluid" then
					tickFluidDepot(depot, entry, event.tick)
				end
				for key,station in pairs(entry.stations) do
					depot.stationToDepot[station.entity.unit_number] = entry.controller.unit_number
					depot.stationToDepot[station.entity.backer_name] = entry.controller.unit_number
					--game.print(station.entity.backer_name .. " > " .. entry.controller.unit_number)
				end
			else
				depot.entries[unit] = nil
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
		
		for unit,entry in pairs(depot.pendingBypasses) do
			local conn = findConnection(entry.entity)
			if conn then
				depot.pendingBypasses[unit] = nil
				depot.bypassBeacons[entry.entity.unit_number] = conn.backer_name
				depot.bypassBeacons[conn.backer_name] = entry.entity
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
				if pole and pole.valid and pump.entity.valid then
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
		local entry = depot.entries[entity.unit_number]
		if entry then
			invalidate(entry)
			--entry.placer.destroy()
			--entry.render.destroy()
			depot.entries[entity.unit_number] = nil
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
	elseif entity.type == "train-stop" then
		removeTrainStopFromCache(entity)
	elseif entity.name == "station-bypass-beacon" then
		local depot = global.depot
		depot.pendingBypasses[entity.unit_number] = nil
		local name = depot.bypassBeacons[entity.unit_number]
		depot.bypassBeacons[entity.unit_number] = nil
		if name then
			depot.bypassBeacons[name] = nil
		end
	end
end

local function onEntityAdded(entity)
	if entity.name == "depot-controller" then
		local depot = global.depot
		local entry = {controller = entity, storages = {}, type = "item"}
		depot.entries[entity.unit_number] = entry
	elseif entity.name == "depot-fluid-controller" then
		local depot = global.depot
		local entry = {controller = entity, type = "fluid"}
		depot.entries[entity.unit_number] = entry
	elseif entity.name == "train-unloader" or entity.name == "train-reloader" then
		entity.active = false
		entity.operable = false
	elseif entity.name == "smart-train-stop" then
		local depot = global.depot
		buildSmartStop(depot, entity)
	elseif entity.name == "station-bypass-beacon" then
		local depot = global.depot
		if not depot.pendingBypasses then depot.pendingBypasses = {} end
		depot.pendingBypasses[entity.unit_number] = {entity = entity}
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
	local stationIndex = train.schedule and train.schedule.current or nil
	local name = stationIndex and train.schedule.records[stationIndex].station or nil
	local controller = name and depot.stationToDepot and depot.stationToDepot[name] or nil
	controller = controller and depot.entries[controller] or nil
	local stationEntry = controller and controller.stations[name] or nil
	if train.state == defines.train_state.arrive_station or train.state == defines.train_state.wait_station then
		if force.technologies["depot-redbar-control"].researched then
			if controller and controller.type == "item" then
				--game.print("Unit " .. controller .. " from " .. name .. " > " .. serpent.block(depot.entries[controller]))
				--game.print("Train " .. entry.displayName .. " is stopping at a depot station " .. name)
				if stationEntry then
					setTrainFiltersForTrain(depot, controller, train, stationEntry)
				else
					log(serpent.block(controller.stations))
					game.print("Station " .. name .. " is mapped to depot " .. controller.controller.unit_number .. " yet that depot has no such station entry?!")
				end
			else
				setTrainFiltersForTrainNonDepot(depot, entry, train)
			end
		end
		if force.technologies["depot-cargo-filters"].researched then
			local filters = getTrainItemFilterData(depot, train)
			if filters then
				for _,car in pairs(entry.cars) do
					if car.type == "cargo-wagon" and filters[car.index] then
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
	elseif train.state == defines.train_state.on_the_path then --just started moving
		local station = train.schedule.current
		local name = train.schedule.records[station].station
		local bypassSelf = getTrainBypassSelfData(depot, train)
		local bypass = getTrainBypassData(depot, train, station)
		local entity = depot.bypassBeacons and depot.bypassBeacons[name] or nil
		
		local flag = false
		
		if bypassSelf and bypassSelf.active and controller and stationEntry and stationEntry.input then
			if controller.type == "item" then
				local flag2 = false
				for item,thresh in pairs(bypassSelf.counts) do
					if train.get_item_count(item) < thresh then
						flag2 = true
						break
					end
				end
				if not flag2 then
					flag = true
				end
			elseif controller.type == "fluid" then
				local flag2 = false
				for _,car in pairs(entry.cars) do
					if car.type == "fluid-wagon" then
						if car.fluidbox == nil or car.fluidbox[1] == nil or (not car.fluidbox[1].valid) or car.fluidbox[1].amount < car.fluidbox.get_capacity(1)*0.75 then
							flag2 = true
						end
					end
				end
				if not flag2 then
					flag = true
				end
			end
		end
		
		if bypass and entity and (not flag) then
			local network = entity.get_circuit_network(defines.wire_type.red)
			if network then
				local signals = network.signals
				if signals and #signals > 0 then
					for _,signal in pairs(signals) do
						if signal.signal.name == bypass.name and signal.signal.type == bypass.type and signal.count > 0 then
							flag = true
							break
						end
					end
				end
			end
			if not flag then
				network = entity.get_circuit_network(defines.wire_type.green)
				if network then
				local signals = network.signals
					if signals and #signals > 0 then
						for _,signal in pairs(signals) do
							if signal.signal.name == bypass.name and signal.signal.type == bypass.type and signal.count > 0 then
								flag = true
								break
							end
						end
					end
				end
			end
		end
		if flag then
			local data = train.schedule
			data.current = data.current+1
			if data.current > #data.records then
				data.current = 1
			end
			train.schedule = data
			handleTrainStateChange(train) --call recursively in case the next station also needs to be skipped
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

local function addCommands()
	commands.add_command("unDepot", {"cmd.un-depot-help"}, function(event)
		local count = 0
		local player = game.players[event.player_index]
		local e = player.selected
		if e and e.type == "train-stop" then
			removeTrainStopFromCache(e)
			game.print("ATD: Removing stop '" .. e.backer_name .. "' from all depots.")
			log(serpent.block(global.depot.entries))
		end
	end)
end

addCommands()