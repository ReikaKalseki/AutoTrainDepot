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
				tickFluidDepot(entry. event.tick)
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
		local ecar = {type = car.type}
		if car.type == "locomotive" then
			
		elseif car.type == "fluid-wagon" then
		
		else
			
		end
		table.insert(cars, ecar)
	end
	return {train = train.id, name = tostring(train.id), cars = cars}
end

local function getOrCreateTrainEntry(depot, entity)
	if not depot.trains then depot.trains = {} end
	local get = depot.trains[entity.unit_number]
	if get then return get end
	local train = entity.train
	if entity.type == "locomotive" then
		get = createEntry(train)
	else
		local locos = train.locomotives["front_movers"]
		if locos and #locos > 0 then
			for _,loco in pairs(locos) do
				get = getOrCreateTrainEntry(depot, loco)
			end
		end
		if (not get) then
			locos = train.locomotives["back_movers"]
			if locos and #locos > 0 then
				for _,loco in pairs(locos) do
					get = getOrCreateTrainEntry(depot, loco)
				end
			end
		end
		if (not get) then
			get = createEntry(train)
		end
	end
	depot.trains[entity.unit_number] = get
	return get
end

function setTrainGui(depot, player, entity)
	local entry = entity and getOrCreateTrainEntry(depot, entity) or nil
	for _,elem in pairs(player.gui.top.children) do
		if string.find(elem.name, "traingui", 1, true) then
			--game.print("Removing " .. elem.name)
			elem.destroy()
		end
	end
	
	if entry and entry.guis then
		entry.guis[player.name] = nil
	end
	
	if entry then
		local train = entry.train
		local guis = {}
		local root = player.gui.top.add{type = "flow", name = "traingui-root", direction = "vertical"}
		for _,car in pairs(entry.cars) do
			local gui = nil
			local id = "traingui-" .. (#guis+1)
			--game.print("Adding " .. id)
			if car.type == "fluid-wagon" then
				gui = root.add{type = "textfield", name = id, text = "Any"}
			else
				gui = root.add{type = "frame", name = id, caption = "[" .. car.type .. "]"}
			end
			if gui then
				gui.tooltip = id
				table.insert(guis, gui)
			end
		end
		if not entry.guis then entry.guis = {} end
		entry.guis[player.name] = guis
	end
	--[[
	for _,elem in pairs(player.gui.top.children) do
		game.print("Has " .. elem.name)
	end
	--]]
end

local function isTrainEntity(entity)
	return entity.type == "locomotive" or entity.type == "cargo-wagon" or entity.type == "fluid-wagon" or entity.type == "artillery-wagon"
end

local function handleTrainGUI(event)
	local player = game.players[event.player_index]
	local last = event.last_entity
	local current = player.selected
	if current and isTrainEntity(current) then
		setTrainGui(global.depot, player, current)
	else
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

script.on_event(defines.events.on_selected_entity_changed, handleTrainGUI)