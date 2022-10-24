require "config"
require "constants"
require "trainhandling"
require "belthandling"

require "__DragonIndustries__.items"

local balanceRate = 240 --4s
local balanceRateNoTrain = 600*3 --30s

--filling trains uses red!!

local function isPowerAvailable(force, power)
	--game.print("Checking power " .. power .. ": " .. (force.technologies["depot-" .. power].researched and "has" or "no"))
	local tech = force.technologies["depot-" .. power]
	return tech and tech.researched
end

local function getMaxSlotsAllowed(entry)
	for i = #SLOT_COUNT_TIERS,1,-1 do
		local tech = entry.controller.force.technologies["depot-item-slots-" .. i]
		if not tech then error("No such tech index: depot-item-slots-" .. i) end
		if tech.researched then
			return SLOT_COUNT_TIERS[i]
		end
	end
	return 1
end

local function getSlotsForType(depot, item)
	return depot.slotsPerType and depot.slotsPerType[item] or depot.defaultSlotsPerType
end

local function getControllableItemTypes(force)
	for i = #ITEM_COUNT_TIERS-1,1,-1 do
		local tech = force.technologies["depot-item-count-" .. i]
		if tech.researched then return ITEM_COUNT_TIERS[i] end
	end
	return 2
end

function getInputThreshold(depot, item)
	return math.floor((getSlotsForType(depot, item)-0.1)*game.item_prototypes[item].stack_size) --the slight reduction is to ensure does not spill over due to latency; some still inbound
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
	if not depot.pulls then depot.pulls = {} end
	
	local loops = {}
	
	for _,storage in pairs(depot.storages) do
		local d = 1--loader and 3 or 1
		local area = game.entity_prototypes[storage.name].collision_box
		area.left_top.x = area.left_top.x-d+storage.position.x
		area.right_bottom.x = area.right_bottom.x+d+storage.position.x
		area.left_top.y = area.left_top.y-d+storage.position.y
		area.right_bottom.y = area.right_bottom.y+d+storage.position.y
		
		local feeds = {}
		local pulls = {}
		
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
			--game.print("Found a inserter " .. inserter.name .. " @ " .. inserter.position.x .. " , " .. inserter.position.y .. " , dropping in " .. (inserter.drop_target and inserter.drop_target.name or "none") .. ", from " .. (inserter.pickup_target and inserter.pickup_target.name or "none"))
			local from, to = --[[(loops[inserter.unit_number] ~= nil) and nil,nil or --]]getLoopFedStorages(depot, inserter)
			if from and to then
				--game.print("Found looping inserter  @ " .. inserter.position.x .. ", " .. inserter.position.y)
				loops[inserter.unit_number] = {type = "loop", entity = inserter, from = from, to = to, wire = wire}
			elseif inserter.drop_target and inserter.drop_target == storage and not (inserter.pickup_target and depot.storages[inserter.pickup_target.unit_number]) then
				--game.print("Inserter is feeding.")
				table.insert(feeds, inserter)
			elseif (inserter.name == "train-unloader" or inserter.name == "dynamic-train-unloader") and inserter.direction == (getRequiredBeltDirection(inserter, storage)+4)%8 then --when not active, drop_target is never set
				table.insert(feeds, inserter)
			elseif (inserter.pickup_target and inserter.pickup_target == storage) or (inserter.direction == getRequiredBeltDirection(inserter, storage)) then
				--game.print("Inserter is pulling.")
				table.insert(pulls, inserter)
			else
				--game.print("Inserter is inert.")
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
						loader.active = true
						local src = getLoaderSource(belt, true)
						if src then src.active = true end
						table.insert(feeds, belt)
					end
				end
			end
		end
		
		--local added = false
		--game.print("Depot @ " .. depot.controller.position.x .. ", " .. depot.controller.position.y .. " has " .. table_size(feeds) .. " feeding [" .. serpent.block(depot.hasDropoffTrain) .. "]")
		
		for _,feed in ipairs(feeds) do -- can be belt OR inserter, nothing else
			--game.print("Running " .. feed.name .. " @ " .. feed.position.x .. ", " .. feed.position.y .. " for depot @ " .. depot.controller.position.x .. ", " .. depot.controller.position.y)
			--if --[[(not depot.inputCount or depot.inputCount < depot.typeLimit) and --]] then --2022: duplicates on keyed is not a problem - prevent duplicate or too many entries->[9mo later]...wait..."too many"???
				if depot.hasDropoffTrain then
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
						--added = true
						
						--game.print("Connected " .. feed.name .. " @ " .. feed.position.x .. ", " .. feed.position.y .. " for item " .. item)
					else
						--game.print(feed.name .. " @ " .. feed.position.x .. ", " .. feed.position.y .. " has no item")
					end
				else
					--game.print(feed.name .. " @ " .. feed.position.x .. ", " .. feed.position.y .. " active due to no train")
					feed.active = true
					local control = feed.get_or_create_control_behavior()
					control.circuit_condition = {condition={comparator=">", first_signal={type="virtual", name="signal-anything"}, constant=-9999}}
				end
			--end
			--if (not added) and depot.inputs[feed.unit_number] == nil then game.print("Did not add entity " .. serpent.block(feed.position)) feed.surface.create_entity{name="inserter", position=feed.position} end
		end
		
		for _,pull in pairs(pulls) do -- can be belt OR inserter, nothing else
			if not depot.pulls[pull.unit_number] then --prevent duplicate or too many entries
			
			pull.active = true --turn any disabled entities back on, and enable any reloaders
					
			--storage.connect_neighbour({wire = depot.wire, target_entity = feed})
			
			depot.outputCount = depot.outputCount and depot.outputCount+1 or 1
			
			depot.pulls[pull.unit_number] = {entity = pull, storage = storage}
			
			--game.print("Connected " .. feed.name .. " @ " .. feed.position.x .. ", " .. feed.position.y .. " for item " .. item)
			end
		end
	end
	
	for _,found in pairs(loops) do
		depot.loopFeeds[found.entity.unit_number] = {entity = found.entity, source = found.from, target = found.to}
	end
end

local function setInputItem(depot, input, item)
	local control = input.entity.get_control_behavior()
	
	if not depot.hasDropoffTrain then
		control.circuit_condition = {condition={comparator="=", first_signal={type="virtual", name="always-on"}, constant=0}}
		return
	end
	
	if control.circuit_condition and control.circuit_condition.first_signal and control.circuit_condition.first_signal.type == "virtual" and control.circuit_condition.first_signal.name == "always-on" then
		control.circuit_condition = {condition={comparator="=", first_signal={type="item", name="always-on"}, constant=0}}
		return
	end
	
	--game.print(item)
	
	if item == nil then
		input.item = nil
		control.circuit_condition = {condition={comparator="=", first_signal={type="item", name="rocket-part"}, constant=-973}}
	else
		if input.item ~= item then
			--game.print("Setting input " .. input.entity.name .. " from " .. (input.item and input.item or "nil") .. " to " .. (item and item or "nil"))
		
			input.item = item
			
			if input.entity.filter_slot_count > 0 then
				--game.print(input.entity.name)
				input.entity.set_filter(1, item)
			end
		end
		
		local val = getInputThreshold(depot, input.item)
		if input.limit then
			--game.print("Updating input limit for " .. unit .. " of type " .. input.item .. " from " .. input.limit .. " to " .. val)
		end
		input.limit = val
		control.circuit_condition = {condition={comparator="<", first_signal={type="item", name=input.item}, constant=input.limit}}
	end
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

local function calculateTypeLimits(entry)
	local maxtypes = entry.typeLimit
	local maxslots = getMaxSlotsAllowed(entry)*entry.storageCount --the tech is per storage
	if isPowerAvailable(entry.controller.force, "category-limits") then
		local cat = getFractionCategoryForItem(item)
		local frac = CATEGORY_FRACTIONS[cat]
		local slots = math.min(maxslots, math.max(1, math.floor(entry.slotCount*frac/maxtypes)))
	else
		return math.min(maxslots, math.max(1, math.floor(entry.slotCount/maxtypes)))
	end
end

local function setTypeLimit(entry, cats)
	entry.typeLimit = cats
	entry.defaultSlotsPerType = calculateTypeLimits(entry)
	if entry.inputs then
		for unit,input in pairs(entry.inputs) do
			setInputItem(entry, input, input.item)
		end
	end
	--game.print("Set controller (linked to " .. entry.storageCount .. " storages totalling " .. entry.slotCount .. " slots) with " .. cats .. " divisions -> " .. entry.defaultSlotsPerType .. " slots per type")
end

function updateTypeLimit(entry, always)
	local cats = getCombinatorOutput(entry.controller)
	--game.print("Combinator reads " .. cats)
	if always or cats ~= entry.typeLimit or entry.defaultSlotsPerType == nil then
		setTypeLimit(entry, cats)
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
			elseif entity.name == "depot-stop" then
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
	checkEntityConnections(entry, li, entry.controller, defines.wire_type.red)
	checkEntityConnections(entry, li, entry.controller, defines.wire_type.green)
	
	for _,found in pairs(li) do
		if entry.wire == nil or entry.wire == found.wire or found.type == "station" then
			if found.type == "storage" then
				bindController(entry, found.entity, found.wire)
			elseif found.type == "loop" then
				--game.print("Caching loop # " .. found.entity.unit_number)
				--entry.loopFeeds[found.entity.unit_number] = {entity = found.entity, source = found.from, target = found.to}
			elseif found.type == "station" then
				local entry2 = {entity = found.entity, wire = found.wire, input = found.wire == defines.wire_type.red} --so that filling trains uses red
				entry.stations[found.entity.backer_name] = entry2
				--game.print("Adding station " .. found.entity.backer_name .. " to depot " .. entry.controller.unit_number .. " : " .. (entry2.input and "input" or "output"))
			end
		end
	end
	
	--[[
	if #entry.stations > 2 then
		entry.controller.force.print("Depot @ " .. entry.controller.position.x .. ", " ..entry.controller.position.y .. " connected to too many stations.")
		entry.stations = {}
	end
	
	if #entry.stations == 2 and entry.stations[1].input == entry.stations[2].input then
		entry.controller.force.print("Depot @ " .. entry.controller.position.x .. ", " ..entry.controller.position.y .. " connected to multiple stations of the same type.")
		entry.stations = {}
	end
	--]]
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
	
	local limit = getControllableItemTypes(entry.controller.force)
	if control.get_signal(1).count > limit then
		control.set_signal(1, {signal = {type = "virtual", name = "depot-divisions"}, count = limit})
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

local function isFull(storage)
	return not storage.get_inventory(defines.inventory.chest).can_insert({name="blueprint", count=1})
end

local function getUnloaderSource(entity)
	local area = {{entity.position.x-0.25, entity.position.y-0.25}, {entity.position.x+0.25, entity.position.y+0.25}}
	if entity.direction == defines.direction.west then
		area[1][1] = area[1][1]-4
		area[2][1] = area[2][1]-4
	elseif entity.direction == defines.direction.east then
		area[1][1] = area[1][1]+4
		area[2][1] = area[2][1]+4
	elseif entity.direction == defines.direction.north then
		area[1][2] = area[1][2]-4
		area[2][2] = area[2][2]-4
	elseif entity.direction == defines.direction.south then
		area[1][2] = area[1][2]+4
		area[2][2] = area[2][2]+4
	end
	local loaders = entity.surface.find_entities_filtered({type = "cargo-wagon", area = area, force = entity.force, limit = 1})
	--game.print(serpent.block(loaders))
	return #loaders > 0 and loaders[1] or nil
end

local function verifyInputsAndStorages(glbl, depot)
	if depot.storages then
		for unit,storage in pairs(depot.storages) do
			if not storage or not storage.valid then
				depot.storages[unit] = nil
				depot.storageCount = depot.storageCount-1
			end
		end
	end
	
	depot.wasFull = depot.isFull
	depot.isFull = false
	
	if depot.inputs then
		local rem = false
		for key,input in pairs(depot.inputs) do
			--game.print("Checking input " .. input.entity.name .. " @ " .. input.entity.position.x .. " , " .. input.entity.position.y .. " (has item " .. (input.item and input.item or "nil"))
			if not input.entity.valid or not input.storage or not input.storage.valid or not depot.storages[input.storage.unit_number] then
				depot.inputs[key] = nil
				rem = true
				depot.inputCount = depot.inputCount-1
				--game.print("Removing invalid input " .. key .. " to " .. input.entity.name)
			elseif isFull(input.storage) then
				--game.print("Storage is full!")
				setInputItem(depot, input, nil)
				depot.isFull = true
			elseif input.entity.type == "inserter" and (depot.wasFull or isPowerAvailable(depot.controller.force, "dynamic-filters")) then -- input.entity.name == "dynamic-train-unloader"
				local src = input.entity.pickup_target
				if src == nil and input.entity.name == "train-unloader" then
					src = getUnloaderSource(input.entity)
				end
				--game.print(serpent.block(src) .. " @ " .. serpent.block(input.entity.position))
				if src and src.type == "cargo-wagon" then
					local data = getTrainCarIOData(glbl, src.train, getIndexedCarByWagon(glbl, src).index)
					if data and data.autoControl and data.shouldFill and (not data.allowExtraction) then
						setInputItem(depot, input, nil)
					else
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
			elseif input.entity.type == "transport-belt" and (depot.wasFull or isPowerAvailable(depot.controller.force, "dynamic-filters")) then
				local loader = getLoaderSource(input.entity, true)
				local src = loader and getLoaderFeed(loader, "cargo-wagon", 2) or nil
				if src then
					local data = getTrainCarIOData(glbl, src.train, getIndexedCarByWagon(glbl, src).index)
					if data and data.autoControl and data.shouldFill and (not data.allowExtraction) then
						setInputItem(depot, input, nil)
					else
						--game.print(serpent.block(src.get_inventory(defines.inventory.cargo_wagon).get_contents()))
						local inv = src.get_inventory(defines.inventory.cargo_wagon)
						if inv then
							local items = inv.get_contents()
							for item,num in pairs(items) do
								--game.print("Setting " .. item)
								setInputItem(depot, input, item)
								break
							end
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
	local counts = {}
	local div = 0
	local empty = 0
	local totalSlots = 0
	for _,storage in pairs(depot.storages) do
		local inv = storage.get_inventory(defines.inventory.chest)
		empty = empty+inv.count_empty_stacks(false)
		totalSlots = totalSlots+#inv
		local has = inv.get_contents()
		for type,amt in pairs(has) do
			local old = amounts[type] and amounts[type] or 0
			amounts[type] = old+amt
			totals[type] = amounts[type]
		end
		div = div+1
	end
	if empty < div*2 then
		return
	end
	--log(serpent.block(amounts))
	for _,storage in pairs(depot.storages) do
		local inv = storage.get_inventory(defines.inventory.chest)
		inv.clear()
		for type,amt in pairs(amounts) do
			local add = math.floor(amt/div)
			if add > 0 then
				local added = inv.insert({name = type, count = add})
				totals[type] = totals[type]-added
				--amounts[type] = totals[type]
				counts[type] = totals[type]
			end
		end
	end
	for type,amt in pairs(totals) do
		if amt > 0 and amounts[type] > 0 then --add leftovers
			for _,storage in pairs(depot.storages) do
				local inv = storage.get_inventory(defines.inventory.chest)
				local added = inv.insert({name = type, count = amt})
				totals[type] = totals[type]-added
				counts[type] = totals[type]
				if counts[type] <= 0 then break end
			end
		end
	end
	
	for type,amt in pairs(counts) do --leftover
		if amt > 0 then
			depot.controller.force.print("Depot had excesss of " .. amt .. " " .. type .. ", which it had to spill to avoid voiding!")
			depot.controller.surface.spill_item_stack(depot.controller.position, {name=type, count=amt}, true, depot.controller.force)
			depot.isFull = true
		end
	end
	--[[
	amounts = {}
	for _,storage in pairs(depot.storages) do
		local has = storage.get_inventory(defines.inventory.chest).get_contents()
		for type,amt in pairs(has) do
			local old = amounts[type] and amounts[type] or 0
			amounts[type] = old+amt
		end
	end
	log(serpent.block(amounts))
	--]]
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

local function getMaxSlotsForWagon(depot, entry, train, station, wagon)
	local force = nil
	if entry.controller then
		--error(serpent.block(entry))
		force = entry.controller.force
	else
		force = wagon.force
	end
	if not force then error("No force for train/depot!") end
	for i = #WAGON_SLOT_TIERS,1,-1 do
		local tech = force.technologies["depot-wagon-slot-" .. i]
		if not tech then error("No such tech index: depot-wagon-slot-" .. i) end
		if tech.researched then
			return WAGON_SLOT_TIERS[i]
		end
	end
	return 1
end

local function manageLoopFeeds(depot) --too laggy
	local cache = {}
	for _,loop in pairs(depot.loopFeeds) do
		local free1 = countFreeSlots(cache, loop.source)
		local free2 = countFreeSlots(cache, loop.target)
		loop.entity.active = free2 > free1 and free2 > 1
	end
end

function setTrainFiltersForTrain(depot, entry, train, station)
	if station.input then
		local entry2 = getOrCreateTrainEntryByTrain(depot, train)
		if entry2 then
			for idx,car in pairs(entry2.cars) do
				if car.type == "cargo-wagon" then
					--game.print("Checking car #" .. car.index .. ": " .. car.type)
					local data = getTrainCarIOData(depot, train, car.index)
					local wagon = train.carriages[idx]
					local inv = wagon.get_inventory(defines.inventory.cargo_wagon)
					if data.autoControl then
						if data.shouldFill then
							inv.set_bar(1+getMaxSlotsForWagon(depot, entry, train, station, wagon))
						else
							inv.set_bar(1)
						end
					else --this is necessary to not allow not-marking-for-auto the wagon to bypass limits
						inv.set_bar(1+getMaxSlotsForWagon(depot, entry, train, station, wagon))
					end
				end
			end
		end
	else
		
	end
end

function setTrainFiltersForTrainNonDepot(depot, entry, train)
	for idx,car in pairs(entry.cars) do
		if car.type == "cargo-wagon" then
			local data = getTrainCarIOData(depot, train, car.index)
			if data.autoControl then
				--game.print(serpent.block(train.station))
				if train.station or train.state == defines.train_state.manual_control then
					train.carriages[idx].get_inventory(defines.inventory.cargo_wagon).set_bar()
				else
					train.carriages[idx].get_inventory(defines.inventory.cargo_wagon).set_bar(1)
				end
			end
		end
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
				setTrainFiltersForTrain(depot, entry, train, station)
			elseif not (train.station and depot.depotStations and depot.depotStations[train.station.unit_number]) then --clear all filters if parked at a different non-depot station
				local entry2 = getOrCreateTrainEntryByTrain(depot, train)
				setTrainFiltersForTrainNonDepot(depot, entry2, train)
			end
		end
	end
end

local function clearInserter(pull)
	local added = pull.storage.insert(pull.entity.held_stack)
	if added >= pull.entity.held_stack.count then
		pull.entity.held_stack.clear()
	else
		pull.entity.held_stack.count = pull.entity.held_stack.count-added
	end
end

local function clearOutputInserters(entry)
	if entry.pulls then
		for unit,pull in pairs(entry.pulls) do
			if pull.entity.valid and pull.storage.valid then
				if pull.entity.held_stack and pull.entity.held_stack.valid_for_read then
					--[[
					local empty = pull.entity.drop_position
					local area = {{empty.x-1, empty.y-1}, {empty.x+1, empty.y+1}}
					local rail = pull.entity.surface.find_entities_filtered{type = "straight-rail", limit = 1, area = area}
					if rail and #rail > 0 then
						local wagons = pull.entity.surface.find_entities_filtered{type = "cargo-wagon", limit = 1, area = area}
						if wagons and #wagons > 0 then
						
						else
							--game.print("Adding " .. pull.entity.held_stack.name .. " x" .. pull.entity.held_stack.count)
							clearInserter(pull)
						end
					end
					--]]
					
					if pull.entity.held_stack_position.x == pull.entity.drop_position.x and pull.entity.held_stack_position.y == pull.entity.drop_position.y then --is "waiting" to drop
						if pull.wasStuck then
							clearInserter(pull)
							pull.wasStuck = false
						else
							pull.wasStuck = true
						end
					end
				end
			else
				entry.pulls[unit] = nil
			end
		end--[[
		for unit,feed in pairs(entry.inputs) do
			if feed.entity.valid and feed.storage.valid and feed.entity.type == "inserter" then
				if feed.entity.held_stack and feed.entity.held_stack.valid_for_read then					
					if feed.entity.name == "train-unloader" or (feed.entity.held_stack_position.x == feed.entity.drop_position.x and feed.entity.held_stack_position.y == feed.entity.drop_position.y) then --is "waiting" to drop
						--game.print(feed.entity.name .. " @ " .. serpent.block(feed.entity.position))
						if feed.wasStuck then
							clearInserter(feed)
							feed.wasStuck = false
						else
							feed.wasStuck = true
						end
					end
				end
			else
				entry.inputs[unit] = nil
			end
		end--]]
	end
end

function tickDepot(depot, entry, tick)	
	verifyControlSignal(entry)
	verifyInputsAndStorages(depot, entry)
	checkConnections(entry)
	
	if entry.stations and #entry.stations > 0 then
		if not depot.depotStations then depot.depotStations = {} end
		for _,station in pairs(entry.stations) do
			depot.depotStations[station.entity.unit_number] = entry.controller.unit_number
		end
	end
	
	--game.print(serpent.block(entry.pulls))
	
	if entry.primaryStorage == nil and entry.storageCount and entry.storageCount > 0 then
		local dist = 999999
		for unit,storage in pairs(entry.storages) do
			local dd = storage.position.x-entry.controller.position.x+storage.position.y-entry.controller.position.y
			if dd < dist then
				entry.primaryStorage = unit
				dist = dd
			end
		end
	end
	
	--game.print(input and input.train.id or "nil")
	
	--if isPowerAvailable(entry.controller.force, "redbar-control") then
	--	setTrainFilters(depot, entry)
	--end
	if isPowerAvailable(entry.controller.force, "inserter-cleaning") then
		clearOutputInserters(entry)
	end
	
	if entry.storageCount and entry.storageCount > 0 then
		entry.hasPickupTrain = false
		entry.hasDropoffTrain = false
		for _,station in pairs(entry.stations) do
			for _,train in pairs(station.entity.get_train_stop_trains()) do
				--game.print(train.id .. " > " .. (train.station and "parked" or "not") .. " @ " .. (station.input and "input" or "output"))
				if train.station == station.entity then
					if station.input then
						entry.hasPickupTrain = true
					else
						entry.hasDropoffTrain = true
					end
				end
				if entry.hasPickupTrain and entry.hasDropoffTrain then break end
			end
			if entry.hasPickupTrain and entry.hasDropoffTrain then break end
		end
		--game.print(tostring(entry.hasPickupTrain) .. " and " .. tostring(entry.hasDropoffTrain))
		getInputBelts(entry)
		
		local rate = entry.hasPickupTrain and balanceRate or balanceRateNoTrain
		--game.print("Comparing " .. tick .. " = " .. tick%rate .. " vs " .. (entry.controller.unit_number-entry.controller.unit_number%tickRate) .. " to " .. (entry.controller.unit_number-entry.controller.unit_number%tickRate)%rate)
		if (not entry.isFull) and tick%rate == (entry.controller.unit_number-entry.controller.unit_number%tickRate)%rate and isPowerAvailable(entry.controller.force, "balancing") then
			--manageLoopFeeds(entry)
			balanceStorages(entry)
		end
		updateTypeLimit(entry)
	else
		entry.typeLimit = 0
	end
end