require "config"

local tickRate = 60--300--60

function initGlobal(markDirty)
	if not global.depot then
		global.depot = {}
	end
	local depot = global.depot
	if depot.entries == nil then
		depot.entries = {}
	end
	depot.dirty = markDirty
end

script.on_configuration_changed(function()
	initGlobal(true)
end)

script.on_init(function()
	initGlobal(true)
end)

--[[
local function setInputBelt(depot, item, enable)

end
--]]

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

local function getRequiredInserterDirection(inserter, entity)
	local dx = inserter.position.x-entity.position.x
	local dy = inserter.position.y-entity.position.y
	if math.abs(dx) == math.abs(dy) then --diagonal, no possible connection
		return -1
	end
	if math.abs(dx) > math.abs(dy) then --dx is bigger, on east or west side
		if dx > 0 then --east
			return defines.direction.east
		else
			return defines.direction.west
		end
	else
		if dy > 0 then --south
			return defines.direction.south
		else
			return defines.direction.north
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
	local belts = loader.surface.find_entities_filtered({type = "transport-belt", area = area, force = loader.force})
	return #belts > 0 and belts[1] or nil
end

local function getInputThreshold(depot, item)
	return math.floor((depot.slotsPerType-0.1)*game.item_prototypes[item].stack_size) --the slight reduction is to ensure does not spill over due to latency; some still inbound
end

local function getInputBelts(depot)
	if not depot.inputs then depot.inputs = {} end
	if not depot.indices then depot.indices = {} end
	
	for _,storage in pairs(depot.storages) do
		local d = 1--loader and 3 or 1
		local area = game.entity_prototypes[storage.name].collision_box
		area.left_top.x = area.left_top.x-d+storage.position.x
		area.right_bottom.x = area.right_bottom.x+d+storage.position.x
		area.left_top.y = area.left_top.y-d+storage.position.y
		area.right_bottom.y = area.right_bottom.y+d+storage.position.y
		
		local feed = {}
		
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
			if isOnSide(inserter, storage) then
				local reqdir = getRequiredInserterDirection(inserter, storage)
				--game.print("Found a inserter " .. inserter.name .. " @ " .. inserter.position.x .. " , " .. inserter.position.y .. " , facing " .. inserter.direction .. " compared to req " .. reqdir)
				if reqdir == inserter.direction then
					--game.print("Inserter is feeding.")
					table.insert(feed, inserter)
				end
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
						table.insert(feed, belt)
					end
				end
			end
		end
		
		for _,feed in pairs(feed) do -- can be belt OR inserter, nothing else
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
				
				--game.print("Found " .. (item and item or "nil") .. " for " .. feed.name)
				if item then
					if depot.indices[item] then --do not allow two inputs of same item
						feed.active = false
					else
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
						
						depot.inputs[feed.unit_number] = {item = item, entity = feed, limit = thresh}
						depot.indices[item] = feed.unit_number
					end
				end
			end
		end
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

local function setTypeLimit(depot, cats)
	depot.typeLimit = cats
	depot.slotsPerType = math.max(1, math.floor(depot.slotCount/cats))
	if depot.inputs then
		for unit,input in pairs(depot.inputs) do
			local val = getInputThreshold(depot, input.item)
			if input.limit then
				--game.print("Updating input limit for " .. unit .. " of type " .. input.item .. " from " .. input.limit .. " to " .. val)
			end
			input.limit = val
			local control = input.entity.get_control_behavior()
			control.circuit_condition = {condition={comparator="<", first_signal={type="item", name=input.item}, constant=input.limit}}
		end
	end
	game.print("Set controller (linked to " .. depot.storageCount .. " storages totalling " .. depot.slotCount .. " slots) with " .. cats .. " divisions -> " .. depot.slotsPerType .. " slots per type")
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
	game.print("Linked controller to " .. chest.name .. " (now has " .. entry.storageCount .. "), with " .. cats .. " divisions among a total of " .. entry.slotCount .. " slots")
end

local function checkEntityConnections(ret, check, wire, path)
	if not path then path = {} end
	path[#path+1] = check
	local net = check.circuit_connected_entities
	local clr = wire == defines.wire_type.red and "red" or "green"
	local data = net[clr]
	if data then
		for _,entity in pairs(data) do
			if entity.type == "container" or entity.type == "logistic-container" then
				table.insert(ret, {entity = entity, wire = wire})
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
				local rec = checkEntityConnections(ret, entity, wire, path)
				if rec then
					table.insert(ret, {entity = rec, wire = wire})
				end
			end
		end
	end
end

local function checkConnections(entry)
	if not entry.storages then entry.storages = {} end

	for unit,storage in pairs(entry.storages) do
		if not storage or not storage.valid then
			entry.storages[unit] = nil
		end
	end

	local li = {}

	if entry.wire ~= defines.wire_type.green then
		checkEntityConnections(li, entry.controller, defines.wire_type.red)
	end
	
	if #li == 0 then
		if entry.wire ~= defines.wire_type.red then
			checkEntityConnections(li, entry.controller, defines.wire_type.green)
		end
	end
	
	for _,found in pairs(li) do
		bindController(entry, found.entity, found.wire)
	end
end

local function tickDepot(depot)
	checkConnections(depot)
	
	if depot.storageCount and depot.storageCount > 0 then
		getInputBelts(depot)
		updateTypeLimit(depot)
	else
		depot.typeLimit = 0
	end
	
	if depot.inputs then
		for i,input in ipairs(depot.inputs) do
			if not input.entity.valid then
				table.remove(depot.inputs, i)
				depot.indices = {}
				for _,entry in pairs(depot.inputs) do
					depot.indices[entry.item] = entry.entity.unit_number
				end
				break
			end
		end
	end
end

script.on_event(defines.events.on_tick, function(event)
	if event.tick%tickRate == 0 then
		local depot = global.depot
		for i, entry in ipairs(depot.entries) do
		
			local control = entry.controller.get_control_behavior()
			local set = control.get_signal(1)
			if not set or not set.signal then
				control.set_signal(1, {signal = {type = "virtual", name = "depot-divisions"}, count = 1})
			elseif set.signal.name ~= "depot-divisions" then
				control.set_signal(1, {signal = {type = "virtual", name = "depot-divisions"}, count = set.signal.count})
			end
			
			--game.print("Ticking depot " .. entry.storage.name)
			tickDepot(entry)
		end
	end
end)

local function onEntityRemoved(entity)
	if entity.name == "depot-controller" then
		local depot = global.depot
		for i, entry in ipairs(depot.entries) do
			if entry.controller.position.x == entity.position.x and entry.controller.position.y == entity.position.y then
				--entry.placer.destroy()
				--entry.render.destroy()
				table.remove(depot.entries, i)
				break
			end
		end
	end
end

--[[
local function findAdjacentInventory(entity)
	local area = game.entity_prototypes[entity.name].collision_box
	local d = 1
	area.left_top.x = area.left_top.x-d+entity.position.x
	area.right_bottom.x = area.right_bottom.x+d+entity.position.x
	area.left_top.y = area.left_top.y-d+entity.position.y
	area.right_bottom.y = area.right_bottom.y+d+entity.position.y
	local chests = entity.surface.find_entities_filtered{type = "container", area = area, force = entity.force}
	local biggest = -1
	local size = 0
	for i,chest in pairs(chests) do
		local inv = chest.get_inventory(defines.inventory.chest)
		if inv then
			local csize = #inv
			if csize > size then
				size = csize
				biggest = i
			end
		end
	end
	return biggest ~= -1 and chests[biggest] or nil
end
--]]

local function onEntityAdded(entity)
	if entity.name == "depot-controller" then
		local depot = global.depot
		local entry = {controller = entity, storages = {}}
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