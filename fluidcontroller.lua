require "config"

local function hasInput(inputs, i)
	return false
end

local function hasOutput(outputs, i)
	return false
end

local function sendControlSignals(inputs, outputs, entry)
	local control = entry.controller.get_control_behavior()
	for i = 1,6 do
		control.set_signal(i, {signal = {type = "virtual", name = "signal-fluid-in" .. i}, count = hasInput(inputs, i) and 1 or 0})
		control.set_signal(i+6, {signal = {type = "virtual", name = "signal-fluid-out" .. i}, count = hasOutput(outputs, i) and 1 or 0})
	end
end

local function checkEntityConnections(depot, ret, check, wire, path)
	if not path then path = {} end
	path[#path+1] = check
	local net = check.circuit_connected_entities
	local clr = wire == defines.wire_type.red and "red" or "green"
	local data = net[clr]
	if data then
		for _,entity in pairs(data) do
			if entity.type == "pump" then
				table.insert(ret, {type = "pump", entity = entity, wire = wire})
			elseif entity.type == "train-stop" then
				table.insert(ret, {type = "station", entity = entity, wire = wire})
			end
		end
		
		for _,entity in pairs(data) do --try recursion along connected wire, except for ones already in our path
			local back = false
			for _,p in pairs(path) do
				if p == entity then
					back = true
					break
				end
			end
			if not back then
				checkEntityConnections(depot, ret, entity, wire, path)
			end
		end
	end
end

local function checkConnections(entry)
	if not entry.pumps then entry.pumps = {} end
	if not entry.stations then entry.stations = {} end
	--if not entry.loopFeeds then entry.loopFeeds = {} end

	local li = {}

	if entry.wire ~= defines.wire_type.green then
		--game.print("Checking red connections")
		checkEntityConnections(entry, li, entry.controller, defines.wire_type.red)
	end
	
	if #li == 0 then
		if entry.wire ~= defines.wire_type.red then
			checkEntityConnections(entry, li, entry.controller, defines.wire_type.green)
		end
	end
	
	for _,found in pairs(li) do
		if found.type == "pump" then
			entry.pumps[found.entity.unit_number] = {entity = found.entity, wire = found.wire}
		elseif found.type == "station" then
			entry.stations[found.entity.unit_number] = {entity = found.entity, wire = found.wire}
		end
	end
end

local function readTrains(depot)
	local inputs = {}
	local outputs = {}
	for _,entry in pairs(depot.stations) do
		for _,train in pairs(entry.entity.get_train_stop_trains()) do
			if train.station == entry.entity then
				local ret = {station = entry.entity, train = train}
				if string.find(entry.entity.backer_name, "output") then
					table.insert(outputs, ret)
				else
					table.insert(inputs, ret)
				end
			end
		end
	end
	return inputs, outputs
end

function tickFluidDepot(depot, tick)
	checkConnections(depot)
	local inputs, outputs = readTrains(depot)
	sendControlSignals(inputs, outputs, depot)
	--checkConnections(depot)
end