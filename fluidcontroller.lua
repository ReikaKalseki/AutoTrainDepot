require "config"
require "trainhandling"

local function getValue(depot, entry2, i)
	if not entry2 then return 0 end
	local entry = getOrCreateTrainEntryByTrain(depot, entry2.train)
	local ret = 0
	if entry then
		for idx,car in pairs(entry.cars) do
			if car.type == "fluid-wagon" then
				--game.print("Checking car #" .. car.index .. ": " .. car.type)
				local data = getTrainCarFilterData(depot, entry2.train, car.index)
				if data and data == i then
					ret = ret+(2^(car.index-1))
					--game.print("Car space " .. idx .. " wagon index " .. car.index .. " of train " .. entry2.train.id .. " filtered to slot " .. data)
				end
			end
		end
	end
	return ret
end

local function sendControlSignals(depot, input, output, entry)
	local control = entry.controller.get_control_behavior()
	for i = 1,6 do
		--game.print("Output Channel " .. i .. ": " .. getValue(depot, output, i))
		control.set_signal(i, {signal = {type = "virtual", name = "signal-fluid-in" .. i}, count = getValue(depot, input, i)})
		control.set_signal(i+6, {signal = {type = "virtual", name = "signal-fluid-out" .. i}, count = getValue(depot, output, i)})
	end
end

local function checkEntityConnections(depot, ret, check, wire, path, step)
	if not path then path = {} end
	path[#path+1] = check
	local net = check.circuit_connected_entities
	local clr = wire == defines.wire_type.red and "red" or "green"
	local data = net[clr]
	if data then
		for _,entity in pairs(data) do
			local entry = {entity = entity, wire = wire, step = step}
			if entity.type == "pump" then
				entry.type = "pump"
			elseif entity.type == "train-stop" then
				entry.type = "station"
			end
			if entry.type then
				table.insert(ret, entry)
			end
		end
		
		for _,entity in pairs(data) do --try recursion along connected wire, except for ones already in our path
			if entity.type == "electric-pole" then
				local back = false
				for _,p in pairs(path) do
					if p == entity then
						back = true
						break
					end
				end
				if not back then
					checkEntityConnections(depot, ret, entity, wire, path, step+1)
				end
			end
		end
	end
end

local function checkConnections(entry)
	if not entry.pumps then entry.pumps = {} end
	entry.stations = {}
	--if not entry.loopFeeds then entry.loopFeeds = {} end

	local li = {}

	if entry.wire ~= defines.wire_type.green then
		--game.print("Checking red connections")
		checkEntityConnections(entry, li, entry.controller, defines.wire_type.red, nil, 0)
	end
	
	if entry.wire ~= defines.wire_type.red then
		checkEntityConnections(entry, li, entry.controller, defines.wire_type.green, nil, 0)
	end
	
	local closestpump = entry.closest_pump
	for _,found in pairs(li) do
		--game.print((found.type and found.type or "nil") .. " from " .. found.entity.type)
		if found.type == "pump" then
			entry.pumps[found.entity.unit_number] = {entity = found.entity, wire = found.wire, index = found.step}
			if not closestpump or found.step < closestpump.distance then
				closestpump = {distance = found.step, entity = found.entity}
			end
		elseif found.type == "station" then
			local entry2 = {entity = found.entity, wire = found.wire, input = found.wire == defines.wire_type.red} --so that filling trains uses red
			table.insert(entry.stations, entry2)
			--game.print("Adding station " .. found.entity.unit_number .. " # " .. (entry2.input and "input" or "output"))
		end
	end
	--game.print(closestpump and closestpump.distance or "nil")
	
	entry.closest_pump = closestpump
	
	if #entry.stations > 2 then
		entry.controller.force.print("Fluid depot @ " .. entry.controller.position.x .. ", " ..entry.controller.position.y .. " connected to too many stations.")
		entry.stations = {}
	end
	
	if #entry.stations == 2 and entry.stations[1].input == entry.stations[2].input then
		entry.controller.force.print("Fluid depot @ " .. entry.controller.position.x .. ", " ..entry.controller.position.y .. " connected to multiple stations of the same type.")
		entry.stations = {}
	end
end

local function readTrains(depot)
	local input = nil
	local output = nil
	--game.print(#depot.stations)
	for _,entry in pairs(depot.stations) do
		for _,train in pairs(entry.entity.get_train_stop_trains()) do
			--game.print(train.id .. " > " .. (train.station and "parked" or "not") .. " @ " .. (entry.input and "input" or "output"))
			if train.station == entry.entity then
				--game.print(train.id)
				local ret = {station = entry.entity, train = train}
				if entry.input then
					input = ret
				else
					output = ret
				end
			end
		end
	end
	--game.print(input and "yes1" or "no1")
	--game.print(output and "yes2" or "no2")
	return input, output
end

local function createCombinators(depot)
	for unit,pump in pairs(depot.pumps) do
		if not pump.redirected then
			local pos = pump.entity.surface.find_non_colliding_position("depot-bitfilter", pump.entity.position, 8, 1)
			if pos then
				local create = pump.entity.surface.create_entity({name = "depot-bitfilter", position = pos, force = pump.entity.force})
				local control = create.get_or_create_control_behavior()
				local control2 = pump.entity.get_control_behavior()
				if control2 and control2.circuit_condition and control2.circuit_condition.condition and control2.circuit_condition.condition.first_signal and string.find(control2.circuit_condition.condition.first_signal.name, "signal-fluid-", 1, true) then
					local signal = control2.circuit_condition.condition.first_signal
					--game.print("Found a pump connected to car " .. pump.index .. " with signal " .. signal.name .. ", creating combinator to bitwise AND signal with " .. (2^pump.index))
					control.parameters = {parameters={first_signal = {type = signal.type, name = signal.name}, second_constant = 2^(pump.index-depot.closest_pump.distance), operation = "AND", output_signal = {type = signal.type, name = signal.name}}}
					local net = pump.entity.circuit_connected_entities
					local clr = pump.wire == defines.wire_type.red and "red" or "green"
					local data = net[clr]
					local pole = data[1]
					pump.entity.disconnect_neighbour(pump.wire)
					pump.entity.connect_neighbour({target_entity = create, wire = pump.wire, target_circuit_id = 2})
					pole.connect_neighbour({target_entity = create, wire = pump.wire, target_circuit_id = 1})
					pump.redirected = true
					pump.combinator = create
					--game.print(create.get_control_behavior().parameters.parameters.operation)
				end
			end
		end
	end
end

function tickFluidDepot(table, depot, tick)
	checkConnections(depot)
	createCombinators(depot)
	local input, output = readTrains(depot)
	sendControlSignals(table, input, output, depot)
	--checkConnections(depot)
end