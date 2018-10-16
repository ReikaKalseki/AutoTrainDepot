require "config"
require "trainhandling"

local function isWagonFull(wagon)
	if wagon.type == "cargo-wagon" then
		local inv = wagon.get_inventory(defines.inventory.cargo_wagon)
		local filter = inv.get_filter(1)
		local item = filter and filter or "blueprint"
		return not inv.can_insert({name=item, count=1})
	else
		return wagon.fluidbox[1] and wagon.fluidbox[1].amount >= wagon.fluidbox.get_capacity(1)
	end
end

local function isWagonEmpty(wagon)
	if wagon.type == "cargo-wagon" then
		return wagon.get_inventory(defines.inventory.cargo_wagon).is_empty()
	else
		return wagon.fluidbox[1] == nil
	end
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
							--game.print("Testing car ".. car.position .. " as input")
							if not isWagonFull(wagon) then
								ingredientsFull = false
							end
							if not isWagonEmpty(wagon) then
								ingredientsEmpty = false
							end
						end
						if isOutput then
							--game.print("Testing car ".. car.position .. " as output")
							if not isWagonFull(wagon) then
								productsFull = false
							end
							if not isWagonEmpty(wagon) then
								productsEmpty = false
							end
						end
					elseif car.type == "fluid-wagon" then
						local _,data2 = getTrainCarFilterData(depot, train, car.index)
						if data2 then
							local isInput = data2.fluidIngredient and data2.fluidIngredient or false
							local isOutput = not isInput
							local wagon = train.carriages[car.position]
							if isInput then
								--game.print("Testing car ".. car.position .. " as input")
								if not isWagonFull(wagon) then
									ingredientsFull = false
								end
								if not isWagonEmpty(wagon) then
									ingredientsEmpty = false
								end
							end
							if isOutput then
								--game.print("Testing car ".. car.position .. " as output")
								if not isWagonFull(wagon) then
									productsFull = false
								end
								if not isWagonEmpty(wagon) then
									productsEmpty = false
								end
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

function buildSmartStop(depot, entity)
	local conn = entity.surface.create_entity{name = "smart-train-stop-output", position = {entity.position.x-0.05, entity.position.y+0.875}, force = entity.force}
	local e2 = entity.surface.create_entity{name = "smart-train-stop-power", position = {entity.position.x, entity.position.y}, force = entity.force}
	entity.connect_neighbour({target_entity = conn, wire = defines.wire_type.red})
	depot.stops[entity.unit_number] = {entity = entity, power = e2, output = conn}
	local key = entity.position.x .. "/" .. entity.position.y
	local old = depot.stopReplacement and depot.stopReplacement[key] or nil
	if old and game.tick-old.age < 5 then
		entity.backer_name = old.old
		for _,train in pairs(entity.force.get_trains(entity.surface)) do
			if old.trains[train.id] then
				local data = train.schedule
				for _,stop in pairs(data.records) do
					if stop.station == old.old then
						stop.station = entity.backer_name
						local entry = getOrCreateTrainEntryByTrain(depot, train)
						local isInputTrain = false
						local isOutputTrain = false
						for _,car in pairs(entry.cars) do
							if car.type == "cargo-wagon" then
								local io = getTrainCarIOData(depot, train, car.index)
								local isInput = (not io.autoControl) or (io.autoControl and io.shouldFill)
								local isOutput = (not io.autoControl) or (io.autoControl and ((not io.shouldFill) or io.allowExtraction))
								isInputTrain = isInputTrain or isInput
								isOutputTrain = isOutputTrain or isOutput
							elseif car.type == "fluid-wagon" then
								local _,data2 = getTrainCarFilterData(depot, train, car.index)
								if data2 then
									local isInput = data2.fluidIngredient and data2.fluidIngredient or false
									local isOutput = not isInput
									isInputTrain = isInputTrain or isInput
									isOutputTrain = isOutputTrain or isOutput
								end
							end
						end
						if isInputTrain then
							table.insert(stop.wait_conditions, {type = "circuit", compare_type = "and", condition = {comparator = "=", first_signal = {type = "virtual", name = "train-ingredients-full"}, constant = 0}})
						end
						if isOutputTrain then
							table.insert(stop.wait_conditions, {type = "circuit", compare_type = "and", condition = {comparator = "=", first_signal = {type = "virtual", name = "train-products-empty"}, constant = 0}})
						end
					end
				end
				train.schedule = data
			end
		end
	end
end