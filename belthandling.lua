local oppositeDirection = {
    [defines.direction.north] = defines.direction.south,
    [defines.direction.south] = defines.direction.north,
    [defines.direction.east] = defines.direction.west,
    [defines.direction.west] = defines.direction.east,
}
local leftTurn = {
    [defines.direction.north] = defines.direction.west,
    [defines.direction.south] = defines.direction.east,
    [defines.direction.east] = defines.direction.north,
    [defines.direction.west] = defines.direction.south,
}
local rightTurn = {
    [defines.direction.north] = defines.direction.east,
    [defines.direction.south] = defines.direction.west,
    [defines.direction.east] = defines.direction.south,
    [defines.direction.west] = defines.direction.north,
}

function getRequiredBeltDirection(belt, entity)
	local dx = belt.position.x-entity.position.x
	local dy = belt.position.y-entity.position.y
	if math.abs(dx) == math.abs(dy) then --diagonal, no possible connection
		return -1
	end
	if math.abs(dx) > math.abs(dy) then --dx is bigger, on east or west side
		if dx > 0 then --east
			return defines.direction.west
		else
			return defines.direction.east
		end
	else
		if dy > 0 then --south
			return defines.direction.north
		else
			return defines.direction.south
		end
	end
end

--[[
function checkLoaderFeed(belt, entity)
	local dx = math.abs(belt.position.x-entity.position.x)
	local dy = math.abs(belt.position.y-entity.position.y)
	if belt.direction == defines.direction.east then
		return dx == 3+size
	elseif belt.direction == defines.direction.west then
		return dx == 3+size
	elseif belt.direction == defines.direction.south then
		return dy == 3+size
	elseif belt.direction == defines.direction.north then
		return dy == 3+size
	end
end
--]]

function isOnSide(belt, entity)
	local area = game.entity_prototypes[entity.name].collision_box
	area.left_top.x = area.left_top.x+entity.position.x
	area.right_bottom.x = area.right_bottom.x+entity.position.x
	area.left_top.y = area.left_top.y+entity.position.y
	area.right_bottom.y = area.right_bottom.y+entity.position.y
	--game.print(belt.position.x .. " , " .. belt.position.y .. " in [" .. area.left_top.x .. " , " .. area.left_top.y .. " > " .. area.right_bottom.x .. " , " .. area.right_bottom.y .. "]")
	return (area.left_top.x <= belt.position.x and area.right_bottom.x >= belt.position.x) or (area.left_top.y <= belt.position.y and area.right_bottom.y >= belt.position.y)-- and (not loader or checkLoaderFeed(belt, entity))
end

function adjacentPosition(position, direction, distance)
    local distance = distance or 1
    if     direction == defines.direction.north then return { x = position.x,            y = position.y - distance }
    elseif direction == defines.direction.south then return { x = position.x,            y = position.y + distance }
    elseif direction == defines.direction.east  then return { x = position.x + distance, y = position.y            }
    elseif direction == defines.direction.west  then return { x = position.x - distance, y = position.y            }
    end
end

local function getBeltLike(surface, position, type)
    return surface.find_entities_filtered{ position = position, type = type, }[1]
end

local function getUpstreamBeltInDirection(belt, direction, distance)
    local distance = distance or 1
    local upstreamBelt   = getBeltLike(belt.surface, adjacentPosition(belt.position, direction, distance), "transport-belt")
    local upstreamUGBelt = getBeltLike(belt.surface, adjacentPosition(belt.position, direction, distance), "underground-belt")
    local upstreamLoader = getBeltLike(belt.surface, adjacentPosition(belt.position, direction, distance), "loader")
    if upstreamBelt and upstreamBelt.direction == oppositeDirection[direction] then return upstreamBelt end
    if upstreamLoader and upstreamLoader.direction == oppositeDirection[direction] and upstreamLoader.loader_type == "output" then return upstreamLoader end
    if upstreamUGBelt and upstreamUGBelt.direction == oppositeDirection[direction] and upstreamUGBelt.belt_to_ground_type == "output" then return upstreamUGBelt end
    return nil
end

local function getNextBeltUpstream(belt)
    if belt.type == "underground-belt" and belt.belt_to_ground_type == "output" then
        if belt.neighbours then return belt.neighbours else return nil end
    end

    if belt.type == "loader" then
        if belt.loader_type == "input" then
            local linearBelt = getUpstreamBeltInDirection(belt, oppositeDirection[belt.direction], 1.5)
            if linearBelt then return linearBelt end
        end
        return nil
    end

    local linearBelt    = getUpstreamBeltInDirection(belt, oppositeDirection[belt.direction])
    local leftTurnBelt  = getUpstreamBeltInDirection(belt, leftTurn[belt.direction])
    local rightTurnBelt = getUpstreamBeltInDirection(belt, rightTurn[belt.direction])
    if linearBelt then return linearBelt end
    if leftTurnBelt and not rightTurnBelt then
        return leftTurnBelt end
    if rightTurnBelt and not leftTurnBelt then
        return rightTurnBelt end
    return nil
end

function findStartOfBelt(currentBelt, initialBelt)
    local newBelt  = getNextBeltUpstream(currentBelt)
    if not newBelt then return currentBelt end
    if newBelt == initialBelt then
        if newBelt.type == "underground-belt" and newBelt.belt_to_ground_type == "input" then
            return newBelt
        else
            return currentBelt
        end
    end
    return findStartOfBelt(newBelt, initialBelt)
end

function getLoaderSource(belt, recurse)
	if recurse then
		local ret = findStartOfBelt(belt, belt)
		if ret then return ret end
	end
	local area = {{belt.position.x-0.25, belt.position.y-0.25}, {belt.position.x+0.25, belt.position.y+0.25}}
	if belt.direction == defines.direction.east then
		area[1][1] = area[1][1]-1
		area[2][1] = area[2][1]-1
	elseif belt.direction == defines.direction.west then
		area[1][1] = area[1][1]+1
		area[2][1] = area[2][1]+1
	elseif belt.direction == defines.direction.south then
		area[1][2] = area[1][2]-1
		area[2][2] = area[2][2]-1
	elseif belt.direction == defines.direction.north then
		area[1][2] = area[1][2]+1
		area[2][2] = area[2][2]+1
	end
	local loaders = belt.surface.find_entities_filtered({type = "loader", area = area, force = belt.force, limit = 1})
	return #loaders > 0 and loaders[1] or nil
end

function getLoaderFeed(loader, look, d)
	if not d then d = 1 end
	local area = {{loader.position.x-0.25, loader.position.y-0.25}, {loader.position.x+0.25, loader.position.y+0.25}}
	if loader.direction == defines.direction.east then
		area[1][1] = area[1][1]-d
		area[2][1] = area[2][1]-d
	elseif loader.direction == defines.direction.west then
		area[1][1] = area[1][1]+d
		area[2][1] = area[2][1]+d
	elseif loader.direction == defines.direction.south then
		area[1][2] = area[1][2]-d
		area[2][2] = area[2][2]-d
	elseif loader.direction == defines.direction.north then
		area[1][2] = area[1][2]+d
		area[2][2] = area[2][2]+d
	end
	local ret = loader.surface.find_entities_filtered({type = look and look or "transport-belt", area = area, force = loader.force, limit = 1})
	--if look then game.print(serpent.block(ret)) end
	return #ret > 0 and ret[1] or nil
end