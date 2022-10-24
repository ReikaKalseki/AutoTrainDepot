require "config"
require "trainhandling"

local function locomotiveHasNoFuel(loco)
	return loco.energy == 0 or (loco.burner and loco.burner.remaining_burning_fuel <= 0)
end

local function isTrainUnfueled(train)
	if train.speed ~= 0 or train.manual_mode or not train.locomotives then return false end
	if train.locomotives["front_movers"] then
		for _,loco in pairs(train.locomotives["front_movers"]) do
			if locomotiveHasNoFuel(loco) then return true end
		end
	end
	if train.locomotives["back_movers"] then
		for _,loco in pairs(train.locomotives["back_movers"]) do
			if locomotiveHasNoFuel(loco) then return true end
		end
	end
	return false
end

local functionIDs = {
	--["nofuel"] = isTrainUnfueled,
	["nopath"] = function(train) return train.state == defines.train_state.no_path end,
	["deadlock"] = function(train) return train.state == defines.train_state.wait_signal end,
}

local function shouldPlaySound(alert)
	if alert == "nopath" then
		return Config.noPathSound
	elseif alert == "deadlock" then
		return Config.deadlockSound
	end
end

local function getFunction(alert)
	--if alert == "nofuel" then
	--	return isTrainUnfueled
	if alert == "nopath" then
		return function(train) return train.state == defines.train_state.no_path end
	elseif alert == "deadlock" then
		return function(train) return train.state == defines.train_state.wait_signal end
	end
end

local function playAlert(depot, force, alert, tag, train, from, to, sound)
	local entry = getOrCreateTrainEntryByTrain(depot, train)
	local name = entry.displayName and entry.displayName or tostring(train.id)
	for _,player in pairs(force.players) do
		player.add_custom_alert(train.carriages[1], {type = "virtual", name = alert}, {tag, name, from, to}, true)
		if sound and shouldPlaySound(alert) then
			player.play_sound{path="train-alert"}
		end
	end
end

local function raiseTrainAlert(depot, force, train, alert, sound)
	local to = train.schedule.records[train.schedule.current].station
	local from = (train.schedule.current == 1 and train.schedule.records[#train.schedule.records] or train.schedule.records[train.schedule.current-1]).station
	--game.print("Train #" .. train.id .. " is " .. alert .. " during route from " .. from.station .. " to " .. to.station)
	local func = alert
	local tag = "train-alert." .. alert
	local alert = "train-alert-" .. alert
	playAlert(depot, force, alert, tag, train, from, to, sound)
	if not depot.trainAlerts then depot.trainAlerts = {} end
	if not depot.trainAlerts[force.name] then depot.trainAlerts[force.name] = {} end
	depot.trainAlerts[force.name][train.id] = {alert = alert, tag = tag, force = force, train = train.id, from = from, to = to, validate = func}
end

function tickTrainAlerts(depot, sound, force)
	if not depot.trainAlerts[force.name] then return end
	for id,alert in pairs(depot.trainAlerts[force.name]) do
		local train = getTrainByID(game.surfaces["nauvis"], alert.force, alert.train)
		--game.print(id .. " > " .. type(alert.validate))
		if train and alert.validate and type(alert.validate) == "string" and functionIDs[alert.validate](train) then
			playAlert(depot, alert.force, alert.alert, alert.tag, train, alert.from, alert.to, sound)
			sound = false
		else
			depot.trainAlerts[force.name][id] = nil
			depot.trainPosCache[alert.train] = nil
		end
	end
end

function checkTrainAlerts(depot, tick, force)
	if not depot.trainPosCache then depot.trainPosCache = {} end
	local fired = false
	--game.print(force.name .. " > " .. #force.get_trains(game.surfaces["nauvis"]))
	for _,train in pairs(force.get_trains(game.surfaces["nauvis"])) do
		--game.print(train.id)
		--if isTrainUnfueled(train) then
		--	raiseTrainAlert(depot, force, train, "nofuel", (not fired))
		--	fired = true
		if train.state == defines.train_state.no_path then
			raiseTrainAlert(depot, force, train, "nopath", (not fired))
			fired = true
		elseif train.state == defines.train_state.wait_signal then
			local pos = train.carriages[1].position
			if depot.trainPosCache[train.id] and depot.trainPosCache[train.id].since then
				if depot.trainPosCache[train.id].x == pos.x and depot.trainPosCache[train.id].y == pos.y then
					--game.print("Train " .. train.id .. " has not moved in " .. (tick-depot.trainPosCache[train.id].since))
					if tick-depot.trainPosCache[train.id].since > 7200*5 then --at signal, has not moved in 2 minutes -> must be deadlocked -> very bad assumption
						raiseTrainAlert(depot, force, train, "deadlock", (not fired))
						fired = true
					end
				end
			end
			if not depot.trainPosCache[train.id] or depot.trainPosCache[train.id].x ~= pos.x or depot.trainPosCache[train.id].y ~= pos.y then
				depot.trainPosCache[train.id] = {x = pos.x, y = pos.y, since = tick}
			end
		else
			depot.trainPosCache[train.id] = nil
		end
	end
	return fired
end