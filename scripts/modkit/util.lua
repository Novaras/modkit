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

---@class AwaitShipsOptions
---@field timeout? integer
---@field interval? integer

--- Returns a new `Rule|Event`, which resolves when all the ships in the `spawn_group` are found in the global register, resolving with those ships.
---
--- In the case that `timeout` is exceeded, instead rejects.
---
---@param spawn_group string
---@param options? AwaitShipsOptions
function awaitShips(spawn_group, options)
	options = options or {};
	local timeout = options.timeout or 12;
	local interval = options.interval or 2;

	local subgroups = SobGroup_Split(spawn_group);

	-- print("awaitShips: spawn group is " .. spawn_group);

	if (Rule_AddInterval) then
		print("returns a rule")
		return modkit.campaign.rules:make({
			interval = interval,
			fn = function (res, rej, state)
				local found_ships = modkit.table.map(%subgroups, function (group)
					return modkit.ships():find(function (ship)
						return SobGroup_GroupsAreEqual(ship.own_group, %group);
					end);
				end);

				-- all are registered if every subgroup was matched to a registered ship (arr lengths are eq.)
				local all_registered = modkit.table.length(found_ships) == modkit.table.length(%subgroups);

				-- print("found ships length was " .. modkit.table.length(found_ships));
				-- print("subgroups length " .. modkit.table.length(%subgroups));

				if (all_registered) then
					print("\n\tresolving awaitShips");
					res(found_ships);
				end

				if (Universe_GameTime() >= state._started_gametime + %timeout) then
					rej("awaitShips timed out (timeout: " .. tostring(%timeout) .. ")");
				end
			end
		});
	else
		-- print("returns an event")
		return modkit.scheduler:make({
			name = "awaitShips_event_" .. modkit.table.length(modkit.scheduler:all()),
			interval = interval,
			fn = function (res, rej, state)
				-- print("hello from awaitShips call");
				-- modkit.table.printTbl(%subgroups, "subgroups from SobGroup_Split(" .. %spawn_group .. ")");
				local found_ships = modkit.table.map(%subgroups, function (group)
					-- print("\n\tcheck group .. " .. group);
					return modkit.ships():find(function (ship)
						-- print("cmp " .. ship.own_group .. "(c: " .. SobGroup_Count(ship.own_group) .. ", t: " .. SobGroup_GetShipType(ship.own_group) .. ") vs " .. %group .. " (c: " .. SobGroup_Count(%group) .. ", t: " .. SobGroup_GetShipType(%group) .. ")");
						local eq = SobGroup_AreEqual(ship.own_group, %group) == 1;
						if (eq) then
							-- print("\tHIT! GROUPS MATCH");
							return eq;
						end

						local subset = SobGroup_GroupInGroup(%group, ship.own_group) == 1;
						if (subset) then
							-- print("\tHIT!? OWN GROUP IS SUBSET OF CHECK GROUP?");
							-- print("SobGroup_GetShipType(ship.own_group) = " .. SobGroup_GetShipType(ship.own_group));
							-- print("SobGroup_GetShipType(%group) = " .. SobGroup_GetShipType(%group));
							return nil;
						end
					end);
				end);
				-- all are registered if every subgroup was matched to a registered ship (arr lengths are eq.)
				local all_registered = modkit.table.length(found_ships) == modkit.table.length(%subgroups);

				-- modkit.table.printTbl(modkit.table.map(found_ships, function (val, idx, tbl)
				-- 	return val.own_group;
				-- end), "found ships");

				if (all_registered) then
					-- modkit.table.printTbl(modkit.table.map(found_ships, function (ship)
					-- 	return { own_group = ship.own_group, player_id = ship.player.id, position = ship:position() };
					-- end), "awaitShips resolve");

					-- modkit.table.printTbl(modkit.scheduler:all(), "\n=== SHEDULER STATE ===");
					res(found_ships);
				end

				if (Universe_GameTime() >= state._started_gametime + %timeout) then
					rej("awaitShips timed out (timeout: " .. tostring(%timeout) .. ")");
				end
			end
		});
	end
end

function weightedRandIndex(src_table)
	local weights = modkit.table.map(src_table, function (item)
		return item.weight or 1;
	end);

	local weight_total = modkit.table.reduce(weights, function (total, weight)
		return total + weight;
	end, 0);

	local distance = random() * weight_total; -- the random distance to walk through the collection before stopping and choosing the item we landed on

	for idx, weight in weights do
		distance = distance - weight;

		if (distance <= 0) then
			return idx;
		end
	end
end

function pow(n, exp)
	if (exp == 0) then
		return 1;
	end

	local original = n;
	local out = n;
	for i = 1, exp - 1 do
		out = out * original;
	end

	return out;
end

--- Converts a decimal number into a binary string.
---
---@param number number
---@return string
function decimalToBinaryStr(number)
	if (number == 0) then
		return "0";
	end

	local bin = {};

	while (number > 0) do
		local bit = mod(number, 2);
		modkit.table.push(bin, bit);
		number = floor(number / 2);
	end

	local as_str = "";
	for i = modkit.table.length(bin), 1, -1 do
		as_str = as_str .. bin[i];
	end

	return as_str;
end

--- Converts a binary string to a decimal number.
---
---@param binary_str string
---@return number
function binaryStrToDecimal(binary_str)
	local l = strlen(binary_str);

	local n = 0;

	for i = 1, l do
		local digit = tonumber(strsub(binary_str, i, i));

		if (digit) then
			n = n + (digit * pow(2, l - i));
		end
	end

	return n;
end

--- Returns whether or not the given `point` is contained within the given `cylinder`.
---
---	Optionally skip culling the top and bottom of the cylinder with `options.skip_slicing_cylinder_ends`.
---
---@param point Vec3Like
---@param cylinder { centerline_start: Vec3Like, centerline_end: Vec3Like, radius: number }
---@param options? { skip_slicing_cylinder_ends?: bool }
---@return bool
function pointWithinCylinder(point, cylinder, options)
	point = Vec3(point);
	cylinder.centerline_end = Vec3(cylinder.centerline_end);
	cylinder.centerline_start = Vec3(cylinder.centerline_start);

	options = options or {};

	local A = cylinder.centerline_start;
	local B = cylinder.centerline_end;

	local AB_diff = B - A;

	if (Vec3:mag(AB_diff) == 0) then
		return nil;
	end

	-- https://lukeplant.me.uk/blog/posts/check-if-a-point-is-in-a-cylinder-geometry-and-code/
	local distance_to_centerline = Vec3:mag(Vec3:cross(AB_diff, (point - A))) / Vec3:mag(AB_diff);

	local point_outside_cylinder_radius = distance_to_centerline > cylinder.radius;
	if (point_outside_cylinder_radius) then
		return nil;
	end

	if (options.skip_slicing_cylinder_ends) then
		return 1;
	end

	local point_above_cylinder = (point - A) * (-1 * AB_diff) > 0;
	if (point_above_cylinder) then
		return nil;
	end

	local point_below_cylinder = (point - B) * AB_diff > 0;
	if (point_below_cylinder) then
		return nil;
	end

	return 1;
end
