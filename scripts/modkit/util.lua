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

--- For a given sobgroup `group`, returns a table containing all the ships in that group, as `Ship` objects.
---
---@param group string
---@return Ship[]
function SobGroup_ToShips(group)
	---@type Ship[]
	local out = {};
	local subgroups = SobGroup_Split(group);

	for index, group in subgroups do
		local type = modkit.table.firstKey(SobGroup_ShipTypes(group));
		-- print("got type " .. tostring(type));
		local player = SobGroup_GetPlayerOwner(group);
		out[index] = modkit.compose:instantiate(group, player, index, type);
	end
	return out;
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

--- Returns a new `Rule`, which resolves when all the ships in the `spawn_group` are found in the global register, resolving with those ships.
---
--- In the case that `timeout` is exceeded, instead rejects.
---
---@param spawn_group string
---@param timeout? integer Default `12`s
function awaitShips(spawn_group, timeout)
	timeout = timeout or 12;

	local subgroups = SobGroup_Split(spawn_group);

	-- modkit.table.printTbl(subgroups, "subgroups");

	if (Rule_AddInterval) then
		-- print("returns a rule")
		return modkit.campaign.rules:make(function (res, rej, state)
			local found_ships = modkit.table.map(%subgroups, function (group)
				return modkit.ships():find(function (ship)
					return SobGroup_GroupsAreEqual(ship.own_group, %group);
				end);
			end);
			-- all are registered if every subgroup was matched to a registered ship (arr lengths are eq.)
			local all_registered = modkit.table.length(found_ships) == modkit.table.length(%subgroups);

			if (all_registered) then
				res(found_ships);
			end

			if (Universe_GameTime() >= state._started_gametime + %timeout) then
				rej("awaitShips timed out (timeout: " .. tostring(%timeout) .. ")");
			end
		end);
	else
		-- print("returns an event")
		return modkit.scheduler:make({
			interval = 5,
			fn = function (res, rej, state)
				-- print("call from awaitShips event");
				local found_ships = modkit.table.map(%subgroups, function (group)
					return modkit.ships():find(function (ship)
						return SobGroup_GroupsAreEqual(ship.own_group, %group);
					end);
				end);
				-- all are registered if every subgroup was matched to a registered ship (arr lengths are eq.)
				local all_registered = modkit.table.length(found_ships) == modkit.table.length(%subgroups);

				-- modkit.table.printTbl(found_ships, "found ships");

				if (all_registered) then
					-- modkit.table.printTbl(found_ships);
					res(found_ships);
				end

				if (Universe_GameTime() >= state._started_gametime + %timeout) then
					rej("awaitShips timed out (timeout: " .. tostring(%timeout) .. ")");
				end
			end
		});
	end
end
