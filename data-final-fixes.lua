local loader = data.raw.loader["train-unloader"]
if loader then

	local belt = data.raw["transport-belt"]["express-transport-belt"]
	
	for _,belt2 in pairs(data.raw["transport-belt"]) do
		if belt2.speed > belt.speed then
			belt = belt2
		end
	end

	loader.speed = belt.speed
	
	loader.belt_horizontal = belt.belt_horizontal
	loader.belt_vertical = belt.belt_vertical
	loader.ending_top = belt.ending_top
	loader.ending_bottom = belt.ending_bottom
	loader.ending_side = belt.ending_side
	loader.starting_top = belt.starting_top
	loader.starting_bottom = belt.starting_bottom
	loader.starting_side = belt.starting_side
end