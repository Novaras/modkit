--- Adds all the ships in `ships` to a new sobgroup `group_name`.
---@param ships Ship[]
---@param group_name string
---@return string
function SobGroup_FromShips(ships, group_name)
	local new_group = SobGroup_Fresh(group_name);
	for _, ship in ships do
		SobGroup_SobGroupAdd(new_group, ship.own_group);
	end
	return new_group;
end

--- Returns a collection of all ships _not_ belonging to `player`.
---
---@param player table
---@return table
function Universe_GetOtherPlayerShips(player)
	local others = GLOBAL_SHIPS:filter(function (ship)
		return ship.player.id ~= %player.id;
	end);
	return others;
end

--- Returns a collection of all ships belonging to `player`.
---
---@param player table
---@return table
function Universe_GetPlayerShips(player)
	local ships = GLOBAL_SHIPS:filter(function (ship)
		return ship.player.id == %player.id;
	end);
	return ships;
end