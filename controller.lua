require "config"
require "trainhandling"

local balanceRate = 600 --10s

local function getRequiredBeltDirection(belt, entity)
	local dx = belt.position.x-entity.position.x
	local dy = belt.position.y-entity.position.y
	if math.abs(dx) == math.abs(dy) then --diagonal, no possible connection
		return -1
	end
	if math.abs(dx) > math.abs(dy) then --dx is bigger, on east or west side
		if dx > 0 then --east
			return defines.direction.west
		else
			return defines.direction.east
		end
	else
		if dy > 0 then --south
			return defines.direction.north
		else
			return defines.direction.south
		end
	end
end

--[[
local function checkLoaderFeed(belt, entity)
	local dx = math.abs(belt.position.x-entity.position.x)
	local dy = math.abs(belt.position.y-entity.position.y)
	if belt.direction == defines.direction.east then
		return dx == 3+size
	elseif belt.direction == defines.direction.west then
		return dx == 3+size
	elseif belt.direction == defines.direction.south then
		return dy == 3+size
	elseif belt.direction == defines.direction.north then
		return dy == 3+size
	end
end
--]]

local function isOnSide(belt, entity)
	local area = game.entity_prototypes[entity.name].collision_box
	area.left_top.x = area.left_top.x+entity.position.x
	area.right_bottom.x = area.right_bottom.x+entity.position.x
	area.left_top.y = area.left_top.y+entity.position.y
	area.right_bottom.y = area.right_bottom.y+entity.position.y
	--game.print(belt.position.x .. " , " .. belt.position.y .. " in [" .. area.left_top.x .. " , " .. area.left_top.y .. " > " .. area.right_bottom.x .. " , " .. area.right_bottom.y .. "]")
	return (area.left_top.x <= belt.position.x and area.right_bottom.x >= belt.position.x) or (area.left_top.y <= belt.position.y and area.right_bottom.y >= belt.position.y)-- and (not loader or checkLoaderFeed(belt, entity))
end

local function getLoaderFeed(loader)
	local area = {{loader.position.x-0.25, loader.position.y-0.25}, {loader.position.x+0.25, loader.position.y+0.25}}
	if loader.direction == defines.direction.east then
		area[1][1] = area[1][1]-1
		area[2][1] = area[2][1]-1
	elseif loader.direction == defines.direction.west then
		area[1][1] = area[1][1]+1
		area[2][1] = area[2][1]+1
	elseif loader.direction == defines.direction.south then
		area[1][2] = area[1][2]-1
		area[2][2] = area[2][2]-1
	elseif loader.direction == defines.direction.north then
		area[1][2] = area[1][2]+1
		area[2][2] = area[2][2]+1
	end
	local belts = loader.surface.find_entities_filtered({type = "transport-belt", area = area, force = loader.force, limit = 1})
	return #belts > 0 and belts[1] or nil
end

local function getInputThreshold(depot, item)
	return math.floor((depot.slotsPerType-0.1)*game.item_prototypes[item].stack_size) --the slight reduction is to ensure does not spill over due to latency; some still inbound
end

local function getLoopFedStorages(depot, entity)
	if depot.loopFeeds[entity.unit_number] then return nil, nil end
	local from = entity.pickup_target
	local to = entity.drop_target
	if from and not depot.storages[from.unit_number] then from = nil end
	if to and not depot.storages[to.unit_number] then to = nil end
	return from, to
end

local function getInputBelts(depot)
	if not depot.inputs then depot.inputs = {} end
	if not depot.loopFeeds then depot.loopFeeds = {} end
	
	local loops = {}
	
	for _,storage in pairs(depot.storages) do
		local d = 1--loader and 3 or 1
		local area = game.entity_prototypes[storage.name].collision_box
		area.left_top.x = area.left_top.x-d+storage.position.x
		area.right_bottom.x = area.right_bottom.x+d+storage.position.x
		area.left_top.y = area.left_top.y-d+storage.position.y
		area.right_bottom.y = area.right_bottom.y+d+storage.position.y
		
		local feeds = {}
		
		--[[
		local belts = storage.surface.find_entities_filtered({type = "transport-belt", area = area, force = storage.force})
		for _,belt in pairs(belts) do
			if isOnSide(belt, storage) then
				local reqdir = getRequiredBeltDirection(belt, storage)
				--game.print("Found a belt " .. belt.name .. " @ " .. belt.position.x .. " , " .. belt.position.y .. " , facing " .. belt.direction .. " compared to req " .. reqdir)
				if reqdir == belt.direction then
					--game.print("Belt is feeding.")
					table.insert(feed, belt)
				end
			end
		end
		--]]
		
		local inserters = storage.surface.find_entities_filtered({type = "inserter", area = area, force = storage.force})
		for _,inserter in pairs(inserters) do
			--game.print("Found a inserter " .. inserter.name .. " @ " .. inserter.position.x .. " , " .. inserter.position.y .. " , dropping in " .. (inserter.drop_target and inserter.drop_target.name or "none"))
			local from, to = --[[(loops[inserter.unit_number] ~= nil) and nil,nil or --]]getLoopFedStorages(depot, inserter)
			if from and to then
				--game.print("Found looping inserter  @ " .. inserter.position.x .. ", " .. inserter.position.y)
				loops[inserter.unit_number] = {type = "loop", entity = inserter, from = from, to = to, wire = wire}
			elseif inserter.drop_target and inserter.drop_target == storage and not (inserter.pickup_target and depot.storages[inserter.pickup_target.unit_number]) then
				--game.print("Inserter is feeding.")
				table.insert(feeds, inserter)
			elseif (inserter.name == "train-unloader" or inserter.name == "dynamic-train-unloader") and inserter.direction == (getRequiredBeltDirection(inserter, storage)+4)%8 then --when not active, drop_target is never set
				table.insert(feeds, inserter)
			end
		end
		
		local loaders = storage.surface.find_entities_filtered({type = "loader", area = area, force = storage.force})
		for _,loader in pairs(loaders) do
			if isOnSide(loader, storage) then
				local reqdir = getRequiredBeltDirection(loader, storage)
				--game.print("Found a loader " .. loader.name .. " @ " .. loader.position.x .. " , " .. loader.position.y .. " , facing " .. loader.direction .. " compared to req " .. reqdir)
				if reqdir == loader.direction--[[ and loader_type == "input"--]] then
					--game.print("Loader is feeding.")
					local belt = getLoaderFeed(loader)
					if belt then
						--game.print("Loader has a belt")
						table.insert(feeds, belt)
					end
				end
			end
		end
		
		for _,feed in pairs(feeds) do -- can be belt OR inserter, nothing else
			if (not depot.inputCount or depot.inputCount < depot.typeLimit) and not depot.inputs[feed.unit_number] then --prevent duplicate or too many entries
				local item = nil
				if feed.type == "transport-belt" then
					local line = feed.get_transport_line(1)
					item = line.get_item_count() > 0 and line[1] or item
					if not item then
						line = feed.get_transport_line(2)
						item = line.get_item_count() > 0 and line[1] or item
					end
					item = (item and item.valid_for_read) and item.name or nil
				else
					item = feed.filter_slot_count > 0 and feed.get_filter(1) or nil --use filters first, but override with actual held items
					item = feed.held_stack and feed.held_stack.valid_for_read and feed.held_stack.name or item
				end
				
				--local old = (depot.inputs[feed.unit_number] and depot.inputs[feed.unit_number].item) and depot.inputs[feed.unit_number].item or "nil"
				--game.print("Found " .. (item and item or "nil") .. " (from " .. old .. ")" .. " for " .. feed.name .. " @ " .. feed.position.x .. ", " .. feed.position.y)
				if item then
					feed.active = true --turn any disabled entities back on, and enable any unloaders
					
					storage.connect_neighbour({wire = depot.wire, target_entity = feed})
					
					local control = feed.get_or_create_control_behavior()
					if control.type == defines.control_behavior.type.transport_belt then
						control.enable_disable = true
						control.read_contents = false
					elseif control.type == defines.control_behavior.type.inserter then
						control.circuit_read_hand_contents = false
						control.circuit_set_stack_size = false
						--control.circuit_stack_control_signal = nil
						control.circuit_mode_of_operation = defines.control_behavior.inserter.circuit_mode_of_operation.enable_disable
					end
					control.connect_to_logistic_network = false
					
					depot.inputCount = depot.inputCount and depot.inputCount+1 or 1
					
					local thresh = getInputThreshold(depot, item)
					control.circuit_condition = {condition={comparator="<", first_signal={type="item", name=item}, constant=thresh}}
					
					depot.inputs[feed.unit_number] = {item = item, entity = feed, limit = thresh, storage = storage}
					
					--game.print("Connected " .. feed.name .. " @ " .. feed.position.x .. ", " .. feed.position.y .. " for item " .. item)
				end
			end
		end
	end
	
	for _,found in pairs(loops) do
		depot.loopFeeds[found.entity.unit_number] = {entity = found.entity, source = found.from, target = found.to}
	end
end

local function setInputItem(depot, input, item)
	if input.item ~= item then
		--game.print("Setting input " .. input.entity.name .. " from " .. (input.item and input.item or "nil") .. " to " .. (item and item or "nil"))
	
		input.item = item
		
		--if input.entity.name == "dynamic-train-unloader" then
			input.entity.set_filter(1, item)
		--end
	end
	
	local val = getInputThreshold(depot, input.item)
	if input.limit then
		--game.print("Updating input limit for " .. unit .. " of type " .. input.item .. " from " .. input.limit .. " to " .. val)
	end
	input.limit = val
	local control = input.entity.get_control_behavior()
	control.circuit_condition = {condition={comparator="<", first_signal={type="item", name=input.item}, constant=input.limit}}
end

local function getCombinatorOutput(entity)
	local control = entity.get_control_behavior()
	local ret = control.get_signal(1)
	--[[
	if ret == nil then
		control.set_signal(1, {type = "virtual", name = "depot-divisions"})
	end
	--]]
	return ret and math.max(1, ret.count) or 1
end

local function setTypeLimit(depot, cats)
	depot.typeLimit = cats
	depot.slotsPerType = math.max(1, math.floor(depot.slotCount/cats))
	if depot.inputs then
		for unit,input in pairs(depot.inputs) do
			setInputItem(depot, input, input.item)
		end
	end
	--game.print("Set controller (linked to " .. depot.storageCount .. " storages totalling " .. depot.slotCount .. " slots) with " .. cats .. " divisions -> " .. depot.slotsPerType .. " slots per type")
end

local function updateTypeLimit(depot)
	local cats = getCombinatorOutput(depot.controller)
	--game.print("Combinator reads " .. cats)
	if cats ~= depot.typeLimit then
		setTypeLimit(depot, cats)
	end
end

local function bindController(entry, chest, wire)
	if entry.storages[chest.unit_number] == chest then return end
	local cats = getCombinatorOutput(entry.controller)--read combinator
	entry.storages[chest.unit_number] = chest
	local has = entry.slotCount and entry.slotCount or 0
	entry.slotCount = has+#chest.get_inventory(defines.inventory.chest)
	entry.storageCount = entry.storageCount and entry.storageCount+1 or 1
	entry.wire = wire
	setTypeLimit(entry, cats)
	--entry.controller.connect_neighbour({wire = defines.wire_type.green, target_entity = chest})
	--game.print("Linked controller to " .. chest.name .. " (now has " .. entry.storageCount .. "), with " .. cats .. " divisions among a total of " .. entry.slotCount .. " slots")
end

local function checkEntityConnections(depot, ret, check, wire, path)
	if not path then path = {} end
	path[#path+1] = check
	local net = check.circuit_connected_entities
	local clr = wire == defines.wire_type.red and "red" or "green"
	local data = net[clr]
	if data then
		for _,entity in pairs(data) do
			local entry = {entity = entity, wire = wire}
			if entity.type == "container" or entity.type == "logistic-container" then
				entry.type = "storage"
			elseif entity.type == "train-stop" then
				entry.type = "station"
			end
			if entry.type then
				table.insert(ret, entry)
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
	if not entry.storages then entry.storages = {} end
	entry.stations = {}
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
		if found.type == "storage" then
			bindController(entry, found.entity, found.wire)
		elseif found.type == "loop" then
			--game.print("Caching loop # " .. found.entity.unit_number)
			--entry.loopFeeds[found.entity.unit_number] = {entity = found.entity, source = found.from, target = found.to}
		elseif found.type == "station" then
			local entry2 = {entity = found.entity, wire = found.wire, input = found.wire == defines.wire_type.red} --so that filling trains uses red
			table.insert(entry.stations, entry2)
			--game.print("Adding station " .. found.entity.unit_number .. " # " .. (entry2.input and "input" or "output"))
		end
	end
	
	if #entry.stations > 2 then
		entry.controller.force.print("Depot @ " .. entry.controller.position.x .. ", " ..entry.controller.position.y .. " connected to too many stations.")
		entry.stations = {}
	end
	
	if #entry.stations == 2 and entry.stations[1].input == entry.stations[2].input then
		entry.controller.force.print("Depot @ " .. entry.controller.position.x .. ", " ..entry.controller.position.y .. " connected to multiple stations of the same type.")
		entry.stations = {}
	end
end

local function setCrossFeedControlSignal(entry, i)

end

local function verifyControlSignal(entry)
	local control = entry.controller.get_control_behavior()
	local set = control.get_signal(1)
	if not set or not set.signal then
		control.set_signal(1, {signal = {type = "virtual", name = "depot-divisions"}, count = 1})
	elseif set.signal.name ~= "depot-divisions" then
		control.set_signal(1, {signal = {type = "virtual", name = "depot-divisions"}, count = set.signal.count})
	end
	
	if entry.basic and control.get_signal(1).count > 20 then
		control.set_signal(1, {signal = {type = "virtual", name = "depot-divisions"}, count = 20})
	end
	
	--[[
	if entry.storages then
		local i = 2
		for unit,storage in pairs(entry.storages) do
			if storage and storage.valid then
				setCrossFeedControlSignal(entry, i)
			else
				control.set_signal(i, nil)
				control.set_signal(i+1, nil)
			end
			i = i+2
		end
	end
	--]]
end

local function verifyInputsAndStorages(depot)
	if depot.storages then
		for unit,storage in pairs(depot.storages) do
			if not storage or not storage.valid then
				depot.storages[unit] = nil
				depot.storageCount = depot.storageCount-1
			end
		end
	end
	
	if depot.inputs then
		local rem = false
		for key,input in pairs(depot.inputs) do
			--game.print("Checking input " .. input.entity.name .. " @ " .. input.entity.position.x .. " , " .. input.entity.position.y .. " (has item " .. (input.item and input.item or "nil"))
			if not input.entity.valid or not input.storage or not input.storage.valid or not depot.storages[input.storage.unit_number] then
				depot.inputs[key] = nil
				rem = true
				depot.inputCount = depot.inputCount-1
				--game.print("Removing invalid input " .. key .. " to " .. input.entity.name)
			elseif input.entity.type == "inserter" and (not depot.basic) then -- input.entity.name == "dynamic-train-unloader"
				local src = input.entity.pickup_target
				if src and src.type == "cargo-wagon" then
					local inv = src.get_inventory(defines.inventory.cargo_wagon)
					if inv then
						local items = inv.get_contents()
						for item,num in pairs(items) do
							setInputItem(depot, input, item)
							break
						end
					end
				end
			elseif input.entity.type == "loader" and (not depot.basic) then
				local belt = getLoaderFeed(loader)
				local src = input.entity.pickup_target
				if src and src.type == "cargo-wagon" then
					local inv = src.get_inventory(defines.inventory.cargo_wagon)
					if inv then
						local items = inv.get_contents()
						for item,num in pairs(items) do
							setInputItem(depot, input, item)
							break
						end
					end
				end
			end
		end
	end
end

local function balanceStorages(depot)
	local amounts = {}
	local totals = {}
	local div = 0
	for _,storage in pairs(depot.storages) do
		local has = storage.get_inventory(defines.inventory.chest).get_contents()
		for type,amt in pairs(has) do
			local old = amounts[type] and amounts[type] or 0
			amounts[type] = old+amt
			totals[type] = amounts[type]
		end
		div = div+1
	end
	for _,storage in pairs(depot.storages) do
		local inv = storage.get_inventory(defines.inventory.chest)
		inv.clear()
		for type,amt in pairs(amounts) do
			local add = math.floor(amt/div)
			if add > 0 then
				local added = inv.insert({name = type, count = add})
				totals[type] = totals[type]-added
			end
		end
	end
	for type,amt in pairs(totals) do
		if amt > 0 and amounts[type] > 0 then --add leftovers
			for _,storage in pairs(depot.storages) do
				local inv = storage.get_inventory(defines.inventory.chest)
				local added = inv.insert({name = type, count = amt})
				totals[type] = totals[type]-added
				amounts[type] = totals[type]
				if amounts[type] <= 0 then break end
			end
		end
	end
end

local function countFreeSlots(cache, chest)
	if cache[chest.unit_number] then return cache[chest.unit_number] end
	local inv = chest.get_inventory(defines.inventory.chest)
	local free = 0
	for i = 1,#inv do
		if not (inv[i] and inv[i].valid_for_read) then
			free = free+1
		end
	end
	cache[chest.unit_number] = free
	return free
end

local function manageLoopFeeds(depot) --too laggy
	local cache = {}
	for _,loop in pairs(depot.loopFeeds) do
		local free1 = countFreeSlots(cache, loop.source)
		local free2 = countFreeSlots(cache, loop.target)
		loop.entity.active = free2 > free1 and free2 > 1
	end
end

local function setTrainFilters(depot, entry)
	--game.print(#entry.stations)
	for _,station in pairs(entry.stations) do
		for _,train in pairs(station.entity.get_train_stop_trains()) do
			--game.print(train.id .. " > " .. (train.station and "parked" or "not") .. " @ " .. (station.input and "input" or "output"))
			if train.station == station.entity then
				--game.print(train.id)
				local ret = {station = station.entity, train = train}
				if station.input then
					local entry2 = getOrCreateTrainEntryByTrain(depot, train)
					if entry2 then
						for idx,car in pairs(entry2.cars) do
							if car.type == "cargo-wagon" then
								--game.print("Checking car #" .. car.index .. ": " .. car.type)
								local data = getTrainCarIOData(depot, train, car.index)
								local wagon = train.carriages[idx]
								if data.autoControl then
									if data.shouldFill then
										wagon.get_inventory(defines.inventory.cargo_wagon).setbar()
									else
										wagon.get_inventory(defines.inventory.cargo_wagon).setbar(1)
									end
								end
							end
						end
					end
				else
					
				end
			else --clear all filters if parked at a different station
				local entry2 = getOrCreateTrainEntryByTrain(depot, train)
				if entry2 then
					for idx,car in pairs(entry2.cars) do
						if car.type == "cargo-wagon" then
							local data = getTrainCarIOData(depot, train, car.index)
							if data.autoControl then
								if train.station or train.state == defines.train_state.manual_control then
									train.carriages[idx].get_inventory(defines.inventory.cargo_wagon).setbar()
								else
									train.carriages[idx].get_inventory(defines.inventory.cargo_wagon).setbar(1)
								end
							end
						end
					end
				end
			end
		end
	end
end

function tickDepot(depot, entry, tick)	
	verifyControlSignal(entry)
	verifyInputsAndStorages(entry)
	checkConnections(entry)
	
	--game.print(input and input.train.id or "nil")
	setTrainFilters(depot, entry)
	
	if entry.storageCount and entry.storageCount > 0 then
		getInputBelts(entry)
		if (not entry.basic) and tick%balanceRate == entry.controller.unit_number%balanceRate then
			--manageLoopFeeds(entry)
			balanceStorages(entry)
		end
		updateTypeLimit(entry)
	else
		entry.typeLimit = 0
	end
	
	
end