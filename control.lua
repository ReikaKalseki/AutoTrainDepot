require "config"
require "trainhandling"
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

local function playAlert(force, alert, tag, train, from, to, sound)
	for _,player in pairs(force.players) do
		player.add_custom_alert(train.carriages[1], {type = "virtual", name = alert}, {tag, tostring(train.id), from, to}, true)
		if sound then
			player.play_sound{path="train-alert"}
		end
	end
end

local function raiseTrainAlert(depot, force, train, alert)
	local to = train.schedule.records[train.schedule.current].station
	local from = (train.schedule.current == 1 and train.schedule.records[#train.schedule.records] or train.schedule.records[train.schedule.current-1]).station
	--game.print("Train #" .. train.id .. " is " .. alert .. " during route from " .. from.station .. " to " .. to.station)
	local tag = "train-alert." .. alert
	local alert = "train-alert-" .. alert
	playAlert(force, alert, tag, train, from, to, true)
	if not depot.trainAlerts then depot.trainAlerts = {} end
	table.insert(depot.trainAlerts, {alert = alert, tag = tag, force = force, train = train.id, from = from, to = to, validate = train.state})
end

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
	if event.tick%7200 == 0 then --2 min
		if not depot.trainPosCache then depot.trainPosCache = {} end
		for _,force in pairs(game.forces) do
			--game.print(force.name .. " > " .. #force.get_trains(game.surfaces["nauvis"]))
			for _,train in pairs(force.get_trains(game.surfaces["nauvis"])) do
				--game.print(train.id)
				if train.state == defines.train_state.wait_signal then
					local pos = train.carriages[1].position
					if depot.trainPosCache[train.id] then
						if depot.trainPosCache[train.id].x == pos.x and depot.trainPosCache[train.id].y == pos.y then --at signal, has not moved in 2 minutes -> must be deadlocked
							raiseTrainAlert(depot, force, train, "deadlock")
						end
					end
					depot.trainPosCache[train.id] = pos
				elseif train.state == defines.train_state.no_path then
					raiseTrainAlert(depot, force, train, "nopath")
				end
			end
		end
	end
	if depot.trainAlerts and #depot.trainAlerts > 0 and event.tick%300 == 0 then
		for i,alert in ipairs(depot.trainAlerts) do
			local train = getTrainByID(game.surfaces["nauvis"], alert.force, alert.train)
			if train and train.state == alert.validate then
				playAlert(alert.force, alert.alert, alert.tag, train, alert.from, alert.to, i == 1)
			else
				table.remove(depot.trainAlerts, i)
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
end

local function onEntityRemoved(entity)
	if entity.name == "basic-depot-controller" or entity.name == "depot-controller" or entity.name == "depot-fluid-controller" then
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
	end
end

local function onEntityAdded(entity)
	if entity.name == "depot-controller" then
		local depot = global.depot
		local entry = {controller = entity, storages = {}, type = "item"}
		table.insert(depot.entries, entry)
	elseif entity.name == "basic-depot-controller" then
		local depot = global.depot
		local entry = {controller = entity, storages = {}, type = "item", basic = true}
		table.insert(depot.entries, entry)
	elseif entity.name == "depot-fluid-controller" then
		local depot = global.depot
		local entry = {controller = entity, type = "fluid"}
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

script.on_event(defines.events.on_gui_opened, function(event)
	handleTrainGUI(event, true)
end)

script.on_event(defines.events.on_gui_closed, function(event)
	handleTrainGUI(event, false)
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
	handleTrainGUIState(event)
end)