require "config"
require "trainhandling"

local function isWagonFull(wagon)
	local inv = wagon.get_inventory(defines.inventory.cargo_wagon)
	local filter = inv.get_filter(1)
	local item = filter and filter or "blueprint"
	return not inv.can_insert({name=item, count=1})
end

local function isWagonEmpty(wagon)
	return wagon.get_inventory(defines.inventory.cargo_wagon).is_empty()
end
--[[
local function isTrainEmpty(train)
	for _,wagon in pairs(train.carriages) do
		if wagon.type == "cargo-wagon" then
			if not isEmpty(wagon) then
				return false
			end
		end
	end
	return true
end

local function isTrainFull(train)
	for _,wagon in pairs(train.carriages) do
		if wagon.type == "cargo-wagon" then
			if not isFull(wagon) then
				return false
			end
		end
	end
	return true
end
--]]

local function setCircuitSignals(entry, ingredientsFull, ingredientsEmpty, productsFull, productsEmpty)
	--game.print(serpent.block(entry.output))
	if entry.output then
		params = {parameters = {
			{
				index = 1,
				signal = {type = "virtual", name = "train-ingredients-full"},
				count = ingredientsFull and 1 or 0,
			},
			{
				index = 2,
				signal = {type = "virtual", name = "train-ingredients-empty"},
				count = ingredientsEmpty and 1 or 0,
			},
			{
				index = 3,
				signal = {type = "virtual", name = "train-products-full"},
				count = productsFull and 1 or 0,
			},
			{
				index = 4,
				signal = {type = "virtual", name = "train-products-empty"},
				count = productsEmpty and 1 or 0,
			},
		}}
		entry.output.get_control_behavior().parameters = params
	end
end

function tickSmartTrainStop(depot, entry)
	setCircuitSignals(entry, false, false, false, false)
	--game.print(entry.power.energy)
	if entry.power.energy > 0 then
		local trains = entry.entity.get_train_stop_trains()
		for _,train in pairs(trains) do
			if train.station == entry.entity then
				local data = getOrCreateTrainEntryByTrain(depot, train)
				local ingredientsFull = true
				local ingredientsEmpty = true
				local productsFull = true
				local productsEmpty = true
				for __,car in pairs(data.cars) do
					if car.type == "cargo-wagon" then
						local io = getTrainCarIOData(depot, train, car.index)
						local isInput = (not io.autoControl) or (io.autoControl and io.shouldFill)
						local isOutput = (not io.autoControl) or (io.autoControl and ((not io.shouldFill) or io.allowExtraction))
						local wagon = train.carriages[car.position]
						if isInput then
							--game.print("Testing car ".. car.index .. " as input")
							if not isWagonFull(wagon) then
								ingredientsFull = false
							end
							if not isWagonEmpty(wagon) then
								ingredientsEmpty = false
							end
						end
						if isOutput then
							--game.print("Testing car ".. car.index .. " as output")
							if not isWagonFull(wagon) then
								productsFull = false
							end
							if not isWagonEmpty(wagon) then
								productsEmpty = false
							end
						end
					end
				end
				setCircuitSignals(entry, ingredientsFull, ingredientsEmpty, productsFull, productsEmpty)
				break
			end
		end
	end
end