require "controller"

require "__DragonIndustries__.arrays"

local function collectFromDepotAndAddToPlayer(entry, player, item)
	local plinv = player.get_inventory(defines.inventory.character_main)
	local amt = 0
	for _,storage in pairs(entry.storages) do
		local inv = storage.get_inventory(defines.inventory.chest)
		if inv and #inv > 0 then
			local has = inv.get_item_count(item)
			if has > 0 then
				local added = plinv.insert{name = item, count = has}
				if added > 0 then
					local taken = inv.remove({name = item, count = added})
					assert(taken == added)
				end
			end
		end
	end
end

local function saveDepotGuiData(depot, player, entry)

end

function setDepotGui(depot, player, entry)
	for _,elem in pairs(player.gui.left.children) do
		if string.find(elem.name, "depotgui-container", 1, true) or elem.name == "depotgui-root" then
			--game.print("Removing " .. elem.name)
			elem.destroy()
			break
		end
	end
	
	if entry and entry.guis then
		entry.guis[player.name] = nil
	end
	
	if entry then		
		local guis = {}
		local container = player.gui.left.add{type = "flow", name = "depotgui-container-" .. entry.controller.unit_number, direction = "horizontal"}
		local root = container.add{type = "frame", name = "depotgui-root", direction = "vertical"}
		--local buttons = container.add{type = "frame", name = "depotgui-buttons", direction = "vertical"}
		
		local title = root.add{type = "frame", name = "depot-title", caption = "Depot Management"}
		title.style.right_padding = 0
		title.style.right_margin = 0
		title.style.width = 180
		title.style.height = 40
		
		local items = getDepotContents(entry)
		
		if getTableSize(items) > 0 then
			local itemlist = root.add{type = "scroll-pane", name = "depotgui-container", direction = "vertical", horizontal_scroll_policy = "never", vertical_scroll_policy = "auto"}
			for item,count in pairs(items) do
				local maxcount = getInputThreshold(entry, item)
				local row = itemlist.add{type = "frame", name = "itemlistbox-" .. item, direction = "horizontal"}
				row.style.left_padding = 0
				row.style.top_padding = 0
				row.style.bottom_padding = 0
				row.style.right_padding = 0
				row.style.height = 32
				row.style.vertical_align = "center"
				local icon = row.add{type = "sprite", tooltip = game.item_prototypes[item].localised_name, sprite = "item/" .. item}
				local spacer = row.add{type = "empty-widget"}
				local amountbox = row.add{type = "flow", direction = "horizontal"}
				local amount = amountbox.add{type = "label", caption = count}
				local amountslash = amountbox.add{type = "label", caption = "/"}
				local maxamount = amountbox.add{type = "label", caption = maxcount}
				amountbox.style.width = 104
				amountbox.style.top_padding = 2
				amountbox.style.vertical_align = "center"
				amount.style = "caption_label"
				amountslash.style = "caption_label"
				maxamount.style = "caption_label"
				amount.style.width = 48
				amountslash.style.width = 8
				maxamount.style.width = 48
				local spacer2 = row.add{type = "empty-widget"}
				local take = row.add{type = "button", name = "depotgui-withdraw-" .. item, tooltip = "Withdraw", caption = ""}
				spacer.style.height = 36
				spacer.style.width = 2
				spacer2.style.width = 2
				local btnico = take.add{type = "sprite", sprite = "depot-withdraw", tooltip = "Withdraw"}
				btnico.ignored_by_interaction = true
				take.style.width = 24
				take.style.height = 24
				take.style.vertical_align = "center"
				take.style.horizontal_align = "center"
				take.style.left_padding = 0
				take.style.top_padding = 0
				take.style.bottom_padding = 0
				btnico.style.width = 24
				btnico.style.height = 24
			end
		else
			local filler = root.add{type = "label", name = "itemlistempty", caption = "Depot is empty"}
		end
		
		if not entry.guis then entry.guis = {} end
		entry.guis[player.name] = guis
	end
end

function handleDepotGUI(event, open)
	local player = game.players[event.player_index]
	local entity = event.entity
	local depot = entity and getDepotFromStorage(entity) or nil
	if open and entity and depot then
		setDepotGui(global.depot, player, depot)
	else
		if entity and depot then
			saveDepotGuiData(global.depot, player, depot)
		end
		setDepotGui(global.depot, player, nil)
	end
end

function handleDepotGUIClick(event)
	if string.find(event.element.name, "depotgui") and event.element.type == "button" then
		local player = game.players[event.player_index]
		local ref = event.element
		while (ref.parent and ref.name ~= "depotgui-root") do
			ref = ref.parent
		end
		local unit = tonumber(string.sub(ref.parent.name, string.len("depotgui-container-")+1))
		--game.print(unit)
		local entry = global.depot.entries[unit]
		assert(entry ~= nil)
		if string.find(event.element.name, "withdraw") then
			local item = string.sub(event.element.name, string.len("depotgui-withdraw-")+1)
			collectFromDepotAndAddToPlayer(entry, player, item)
		end
	end
end

function handleDepotGUIState(event)--[[
	if string.find(event.element.name, "depotgui") and string.find(event.element.name, "button") and string.find(event.element.name, "fluid") then
		local a, b = string.find(event.element.name, "-button-", 1, true)
		local ending = string.sub(event.element.name, b+1)
		local pref = string.sub(event.element.name, string.len("depotgui-fluid-wagon-")+1, a-1)
		local idx = tonumber(ending)
		local car = tonumber(pref)
		--game.print("Setting button " .. idx .. " for car " .. car)
		for _,elem in pairs(event.element.parent.children) do
			if elem ~= event.element then
				elem.state = false
			end
		end
	end
	--]]
end