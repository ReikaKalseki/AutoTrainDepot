require "config"
require "trainhandling"

local function playAlert(depot, force, alert, tag, train, from, to, sound)
	local entry = getOrCreateTrainEntryByTrain(depot, train)
	local name = entry.displayName and entry.displayName or tostring(train.id)
	for _,player in pairs(force.players) do
		player.add_custom_alert(train.carriages[1], {type = "virtual", name = alert}, {tag, name, from, to}, true)
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
	playAlert(depot, force, alert, tag, train, from, to, true)
	if not depot.trainAlerts then depot.trainAlerts = {} end
	table.insert(depot.trainAlerts, {alert = alert, tag = tag, force = force, train = train.id, from = from, to = to, validate = train.state})
end

function tickTrainAlerts(depot)
	for i,alert in ipairs(depot.trainAlerts) do
		local train = getTrainByID(game.surfaces["nauvis"], alert.force, alert.train)
		if train and train.state == alert.validate then
			playAlert(depot, alert.force, alert.alert, alert.tag, train, alert.from, alert.to, i == 1)
		else
			table.remove(depot.trainAlerts, i)
		end
	end
end

function checkTrainAlerts(depot)
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