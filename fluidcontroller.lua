require "config"

local function hasInput(i)
	return false
end

local function hasOutput(i)
	return false
end

local function sendControlSignals(entry)
	local control = entry.controller.get_control_behavior()
	for i = 1,6 do
		control.set_signal(i, {signal = {type = "virtual", name = "signal-fluid-in" .. i}, count = hasInput(i) and 1 or 0})
		control.set_signal(i+6, {signal = {type = "virtual", name = "signal-fluid-out" .. i}, count = hasOutput(i) and 1 or 0})
	end
end

function tickFluidDepot(depot, tick)	
	sendControlSignals(depot)
	--checkConnections(depot)
	
	if depot.pumps then
		
	end	
end