require "config"
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
				tickFluidDepot(entry, event.tick)
			end
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

local function createEntry(train)
	local cars = {}
	for _,car in pairs(train.carriages) do
		local ecar = {type = car.type, unit = car.unit_number}
		if car.type == "locomotive" then
			
		elseif car.type == "fluid-wagon" then
		
		else
			
		end
		table.insert(cars, ecar)
	end
	return {train = train.id, name = tostring(train.id), cars = cars, length = #train.carriages}
end

local function getOrCreateTrainEntryByTrain(depot, train)
	if not depot.trains then depot.trains = {} end
	local get = depot.trains[train.id]
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

local function getTrainCarFilterData(depot, train, car)
	local filters = getTrainFilterData(depot, train)
	--game.print("loaded stored filter " .. (filters[car] and filters[car] or "nil") .. " for car " .. car)
	if not filters[car] or type(filters[car]) ~= "number" then filters[car] = 1 end
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

local function handleTrainGUIState(event)
	if string.find(event.element.name, "traingui") and string.find(event.element.name, "button") then
		local a, b = string.find(event.element.name, "-button-", 1, true)
		local ending = string.sub(event.element.name, b+1)
		local pref = string.sub(event.element.name, string.len("traingui-")+1, a-1)
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
		root.tooltip = train
		--root.title_top_padding = 0
		--root.title_bottom_padding = 0
		for idx,car in pairs(entry.cars) do
			local gui = nil
			local id = "traingui-" .. (#guis+1)
			--game.print("Adding " .. id)
			if car.type == "fluid-wagon" then
				--gui = root.add{type = "textfield", name = id, text = "Any"}
				gui = root.add{type = "frame", name = id}
				gui.style.height = 30 --24 for flow, 30 for frame
				local data = getTrainCarFilterData(depot, obj, idx)
				for i = 1,6 do
					gui.add{type = "radiobutton", name = id .. "-button-" .. i, state = i == data}
				end
			else
				gui = root.add{type = "frame", name = id, caption = "[" .. string.gsub(car.type, "-", " ") .. "]"}
				gui.style.height = 34
			end
			if gui then
				gui.style.top_padding = 0
				gui.style.bottom_padding = 0
				gui.tooltip = id
				table.insert(guis, gui)
			end
		end
		if not entry.guis then entry.guis = {} end
		entry.guis[player.name] = guis
	end
end

local function getTrainForGui(player, text)
	return getTrainByID(player.surface, player.force, tonumber(text))
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
					if child.children and #child.children > 0 then
						--game.print("Car " .. i .. ": " .. val)
						setTrainCarFilterData(depot, train, i, child.children)
					end
				end
			end
			break
		end
	end
end

local function isTrainEntity(entity)
	return entity.type == "locomotive" or entity.type == "cargo-wagon" or entity.type == "fluid-wagon" or entity.type == "artillery-wagon"
end

local function handleTrainGUI(event, open)
	local player = game.players[event.player_index]
	local entity = event.entity
	if open and entity and isTrainEntity(entity) then
		setTrainGui(global.depot, player, entity)
	else
		saveGuiData(global.depot, player)
		setTrainGui(global.depot, player, nil)
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