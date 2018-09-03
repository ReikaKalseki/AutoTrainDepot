	require "config"

local ENTRY_VERSION = 8

local function createEntry(train)
	local cars = {}
	local idxs = {}
	local idxs2 = {}
	for i,car in pairs(train.carriages) do
		local idx = idxs[car.type] and idxs[car.type] or 1
		local ecar = {type = car.type, unit = car.unit_number, index = idx, position = i}
		if car.type == "locomotive" then
			ecar.name = car.backer_name
		elseif car.type == "fluid-wagon" then
			ecar.name = "Fluid Wagon " .. idx
		elseif car.type == "cargo-wagon" then
			ecar.name = "Item Wagon " .. idx
		else
			ecar.name = "Car " .. idx
		end
		idxs[car.type] = idx+1
		table.insert(cars, ecar)
		if not idxs2[car.type] then idxs2[car.type] = {} end
		idxs2[car.type][idx] = i
	end
	return {train = train.id, name = tostring(train.id), cars = cars, length = #train.carriages, version = ENTRY_VERSION, indices = idxs2}
end

local function isValid(entry)
	return entry and entry.version and entry.version >= ENTRY_VERSION and entry.train and entry.cars and entry.length and entry.name and #entry.cars > 0 and entry.cars[1].type and entry.cars[1].index and entry.cars[1].name
end

function getOrCreateTrainEntryByTrain(depot, train)
	if not depot.trains then depot.trains = {} end
	local get = depot.trains[train.id]
	if not isValid(get) then get = nil end
	if get then return get end

	get = createEntry(train)
		
	depot.trains[train.id] = get
	return get
end	

local function getOrCreateTrainEntry(depot, entity)
	local train = entity.train
	return train and getOrCreateTrainEntryByTrain(depot, train) or nil
end

local function invalidateTrain(depot, entry)
	--game.print("Invalidating train " .. entry.train)
	for _,car in pairs(entry.cars) do
		if car.unit then
			depot.trains[car.unit] = nil
		end
	end
	depot.trains[entry.train] = nil
end

local function getTrainByID(surface, force, id)
	for _,train in pairs(force.get_trains(surface)) do
		if train.id == id then
			return train
		end
	end
end

local function getTrainFilterData(depot, train)
	assert(train ~= nil)
	local entry = getOrCreateTrainEntryByTrain(depot, train)
	if not entry.filters then entry.filters = {} end
	return entry.filters
end

local function getTrainIOData(depot, train)
	assert(train ~= nil)
	local entry = getOrCreateTrainEntryByTrain(depot, train)
	if not entry.io then entry.io = {} end
	return entry.io
end

function getTrainCarFilterData(depot, train, car)
	local entry = getOrCreateTrainEntryByTrain(depot, train)
	local idx = entry.indices["fluid-wagon"][car]
	if entry.cars[idx] == nil or entry.cars[idx].type ~= "fluid-wagon" then return nil end
	local filters = getTrainFilterData(depot, train)
	--game.print("loaded stored filter " .. (filters[car] and filters[car] or "nil") .. " for car " .. car)
	if not filters[car] or type(filters[car]) ~= "number" then filters[car] = 7 end
	return filters[car]
end

function getTrainCarIOData(depot, train, car)
	local entry = getOrCreateTrainEntryByTrain(depot, train)
	local idx = entry.indices["cargo-wagon"][car]
	if entry.cars[idx] == nil or entry.cars[idx].type ~= "cargo-wagon" then return nil end
	local filters = getTrainIOData(depot, train)
	--game.print("loaded stored filter " .. (filters[car] and filters[car] or "nil") .. " for car " .. car)
	if not filters[car] or type(filters[car]) ~= "boolean" then filters[car] = false end
	return filters[car]
end

local function setTrainCarFilterData(depot, train, car, options)
	local slot = -1
	for i,elem in pairs(options) do
		if elem.state then
			slot = i
			break
		end
	end
	--game.print("Setting filter for car " .. car .. " to " .. slot)
	local filters = getTrainFilterData(depot, train)
	filters[car] = slot
end

local function setTrainCarIOData(depot, train, car, fill)
	--game.print("Setting filter for car " .. car .. " to " .. slot)
	local filters = getTrainIOData(depot, train)
	filters[car] = fill
end

function handleTrainGUIState(event)
	if string.find(event.element.name, "traingui") and string.find(event.element.name, "button") and string.find(event.element.name, "fluid") then
		local a, b = string.find(event.element.name, "-button-", 1, true)
		local ending = string.sub(event.element.name, b+1)
		local pref = string.sub(event.element.name, string.len("traingui-fluid-wagon-")+1, a-1)
		local idx = tonumber(ending)
		local car = tonumber(pref)
		--game.print("Setting button " .. idx .. " for car " .. car)
		for _,elem in pairs(event.element.parent.children) do
			if elem ~= event.element then
				elem.state = false
			end
		end
	end
end

function setTrainGui(depot, player, entity)
	local entry = entity and getOrCreateTrainEntry(depot, entity) or nil
	for _,elem in pairs(player.gui.left.children) do
		if elem.name == "traingui-root" then
			--game.print("Removing " .. elem.name)
			elem.destroy()
			break
		end
	end
	
	if entry and entry.guis then
		entry.guis[player.name] = nil
	end
	
	if entry then		
		local train = entry.train
		assert(train ~= nil)
		--game.print("Trying " .. train .. " from " .. entity.name .. " # " .. entity.unit_number)
		local obj = getTrainByID(player.force, player.surface, train)
		if not obj then
			invalidateTrain(depot, entry)
			entry = getOrCreateTrainEntry(depot, entity)
			train = entry.train
			obj = getTrainByID(player.force, player.surface, train)
			if not obj then game.print("still no train with id " .. train .. "!!") end
		end
		assert(obj ~= nil)
		local guis = {}
		local root = player.gui.left.add{type = "frame", name = "traingui-root", direction = "vertical"}
		root.tooltip = "Train #" .. train
		--root.title_top_padding = 0
		--root.title_bottom_padding = 0
		local header = root.add{type = "flow", name = "traingui-header"}
		header.style.height = 24
		local spacer = header.add{type = "sprite", name = "traingui-header-spacer", "utility/empty"}
		spacer.style.width = 1
		for i = 1,7 do --7, not 6; slot 7 is "inactive"
			--local box = header.add{type = "sprite", name = "traingui-header-" .. i, sprite = i == 7 and "utility/clear" or ("virtual-signal/signal-" .. i)}
			local box = header.add{type = "sprite", name = "traingui-header-" .. i, sprite = i == 7 and "traingui-header-no" or "traingui-header-" .. i}
			box.style.width = 24
			box.tooltip = i == 7 and "No connection" or ("Fluid Type " .. i)
		end
		for _,car in pairs(entry.cars) do
			local gui = nil
			local id = "traingui-" .. car.type .. "-" .. car.index
			--game.print("Adding " .. id)
			if car.type == "fluid-wagon" then
				--gui = root.add{type = "textfield", name = id, text = "Any"}
				gui = root.add{type = "frame", name = id}
				gui.style.height = 30 --24 for flow, 30 for frame
				local data = getTrainCarFilterData(depot, obj, car.index)
				--game.print("Creating GUI for car " .. car.index .. ", data = " .. (data and data or "nil"))
				for i = 1,7 do --7, not 6; slot 7 is "inactive"
					gui.add{type = "radiobutton", name = id .. "-button-" .. i, state = i == data}
				end
			elseif car.type == "cargo-wagon" then
				gui = root.add{type = "frame", name = id}
				gui.style.height = 30 --24 for flow, 30 for frame
				local data = getTrainCarIOData(depot, obj, car.index)
				--game.print("Creating GUI for car " .. car.index .. ", data = " .. (data and data or "nil"))
				gui.add{type = "checkbox", name = id .. "-button", caption = "Fills At Depot", state = data}
			else
				gui = root.add{type = "frame", name = id, caption = "[" .. string.gsub(car.type, "-", " ") .. "]"}
				gui.style.height = 34
			end
			if gui then
				gui.style.top_padding = 0
				gui.style.bottom_padding = 0
				gui.tooltip = car.type == "locomotive" and "'" .. car.name .. "'" or "Car #" .. car.index
				table.insert(guis, gui)
			end
		end
		if not entry.guis then entry.guis = {} end
		entry.guis[player.name] = guis
	end
end

local function getTrainForGui(player, text)
	return getTrainByID(player.surface, player.force, tonumber(string.sub(text, 1+string.len("Train #"))))
end

local function saveGuiData(depot, player)
	for _,elem in pairs(player.gui.left.children) do
		if elem.name == "traingui-root" then
			local train = getTrainForGui(player, elem.tooltip)
			--game.print(train and train.id or "nil")
			local entry = train and getOrCreateTrainEntryByTrain(depot, train) or nil
			--game.print("Has entry? " .. (entry and "yes" or "no"))
			if entry then
				for i,child in pairs(elem.children) do
					if i > 1 and child.children and #child.children > 0 then
						local idx = tonumber(string.sub(child.tooltip, string.len("Car #")+1))
						--game.print("Car " .. i .. " from " .. idx .. " of " .. child.tooltip .. " which has child #1 " .. child.children[1].name)
						if string.find(child.name, "fluid") then
							setTrainCarFilterData(depot, train, idx, child.children)
						elseif string.find(child.name, "cargo") then
							setTrainCarIOData(depot, train, idx, child.children[1].state)
						end
					end
				end
			end
			break
		end
	end
end

function isTrainEntity(entity)
	return entity.type == "locomotive" or entity.type == "cargo-wagon" or entity.type == "fluid-wagon" or entity.type == "artillery-wagon"
end

function handleTrainGUI(event, open)
	local player = game.players[event.player_index]
	local entity = event.entity
	if open and entity and isTrainEntity(entity) then
		setTrainGui(global.depot, player, entity)
	else
		saveGuiData(global.depot, player)
		setTrainGui(global.depot, player, nil)
	end
end