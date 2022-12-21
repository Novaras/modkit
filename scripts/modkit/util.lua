--- Adds all the ships in `ships` to a new sobgroup `group_name`.
---@param ships Ship[]
---@param group_name? string
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

--- Returns whether or not a 'Special_Splitter' has been spawned by the rule `sobgroups_init`, which is only called during
--- skirmishes (not campaign). May return a flase positive on the very first few game ticks.
---
---@return bool
function Universe_IsCampaign()
	return Player_GetNumberOfSquadronsOfTypeAwakeOrSleeping(-1, "Special_Splitter") == 0;
end

--- Unbinds any previously bound functions, then binds to the supplied function.
---
---@param key number
---@param fn_name? string
function UI_ForceBindKeyEvent(key, fn_name)
	UI_UnBindKeyEvent(key);
	if (fn_name) then
		UI_BindKeyEvent(key, fn_name);
	end
end
