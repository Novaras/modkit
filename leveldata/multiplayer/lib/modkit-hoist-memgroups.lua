-- GLOBAL_SHIPS etc. are not visible in the rules scope, so we need to share key
-- info via hypertable.lua, and try to produce a clone of that data in this scope

if (modkit == nil) then
	dofilepath("data:scripts/modkit.lua");

	if (GLOBAL_SHIPS == nil) then
		---@class ShipCollection : MemGroupInst
		---@diagnostic disable-next-line: duplicate-doc-field
		---@field _entities Ship[]
		---@diagnostic disable-next-line: duplicate-doc-field
		---@field get fun(self: ShipCollection, entity_id: number): Ship
		---@diagnostic disable-next-line: duplicate-doc-field
		---@field set fun(self: ShipCollection, entity_id: number, ship: Ship): Ship
		---@diagnostic disable-next-line: duplicate-doc-field
		---@field all fun(self: ShipCollection): Ship[]
		---@diagnostic disable-next-line: duplicate-doc-field
		---@field find fun(self: ShipCollection, predicate: ShipFilterPredicate): Ship | 'nil'
		---@diagnostic disable-next-line: duplicate-doc-field
		---@field filter fun(self: ShipCollection, predicate: ShipFilterPredicate): Ship[]
		GLOBAL_SHIPS = modkit.MemGroup.Create("mg-ships-global");
	end
end

function getParamVal(str, flag_pattern, value_pattern)
	local s, e = strfind(str, flag_pattern .. value_pattern);
	e = e or strlen(str);
	if (s) then
		local offset = strlen(strsub(str, strfind(str, flag_pattern)));
		return strsub(str, s + offset, e);
	end
	return nil;
end

--- This rule grabs published ships from the ui scope and generates full ship objects (so `GLOBAL_` collections are accessible)
function modkit_hoist_memgroups()
	if (modkit == nil or register == nil) then
		print("load from hoist rule");
		dofilepath("data:scripts/modkit.lua");
	end

	print("[" .. Universe_GameTime() .. "] HOISTING GROUPS...");
	local incoming = hyperTableHandle()().GLOBAL_SHIPS;
	-- modkit.table.printTbl(incoming, "incoming");
	if (incoming and modkit.table.length(incoming) > 0) then
		if (GLOBAL_PLAYERS == nil) then
			dofilepath("data:scripts/modkit/player.lua");
		end

		if (not GLOBAL_SHIPS) then
			GLOBAL_SHIPS = modkit.MemGroup.Create("mg-ships-global");
		end
		
		for ship_id, line in incoming do
			local data_str = strsplit(line, ",", 1);
			local type_group = data_str[1];
			local player_index = tonumber(data_str[2]);
			-- modkit.table.printTbl(words, "words");

			-- consoleLog("trying with " .. line);
			-- consoleLog("tg: \t" .. tostring(type_group));
			-- consoleLog("pi: \t" .. tostring(player_index));
			-- consoleLog("si: \t" .. tostring(ship_id));
			if (type_group and player_index and ship_id) then
				local new_ship = register(type_group, player_index, ship_id);

				new_ship.player = GLOBAL_PLAYERS:get(player_index);
			end
		end
		-- print("gs");
		-- print(GLOBAL_SHIPS);
		modkit.table.printTbl(modkit.table.map(GLOBAL_SHIPS:all(), function (ship)
			---@cast ship Ship
			return {
				id = ship.id,
				type = ship.type_group,
				group = ship.own_group,
				player = ship.player.id,
			};
		end));

		-- clear the stream data, effectively consuming it
		hyperTableHandle()({
			GLOBAL_SHIPS = {}
		}, nil, 1);

		-- modkit.table.printTbl(hyperTableHandle()().GLOBAL_SHIPS, "STREAM BUFFER");
	end

	for id, ship in GLOBAL_SHIPS:all() do
		---@cast ship Ship
		if (type(ship.HP) == "function" and ship:HP() <= 0 or ship:count() <= 0) then
			GLOBAL_SHIPS:delete(id);
		end
	end
	-- consoleLog("in the rules scope, the global ships table now reports " .. modkit.table.length(GLOBAL_SHIPS:all()) .. " ships");
end