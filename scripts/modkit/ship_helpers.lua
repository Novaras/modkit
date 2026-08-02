if (modkit == nil) then
	modkit = {};
end

---@alias ShipFilterPredicate fun(ship: Ship): bool
---@alias FilterFn fun(predicate: ShipFilterPredicate): Ship[]

if (modkit.shipGroup == nil) then
	---@class ShipCollectionExt : ShipCollection
	local lib = modkit.table.clone(GLOBAL_SHIPS);

	--- Returns the avg position of `ships` or `GLOBAL_SHIPS`.
	---
	---@param ships? Ship[]
	---@return Position
	function lib:avgPosition(ships)
		-- we could use the ship:position, but the game provides group position averaging already so we'll just use that
		-- print(self._entities);
		-- print(modkit.table.length(self._entities));
		-- print("so..");
		local group = SobGroup_FromShips(ships or self._entities, DEFAULT_SOBGROUP);
		return Vec3(SobGroup_GetPosition(group));
	end

	--- Finds a ship and returns it.
	---
	--- The argument may be a `Ship` or a filter predicate. If given a `Ship`, matches by `id`.
	---
	---@param predicate_or_ship Ship|ShipFilterPredicate
	---@return Ship?
	function lib:find(predicate_or_ship)
		if (predicate_or_ship == nil) then
			return nil;
		end

		local predicate = NOOP;
		if (type(predicate_or_ship) == "table") then
			predicate = function (other)
				return other.id == ship.id;
			end
		else
			---@cast predicate_or_ship ShipFilterPredicate
			predicate = predicate_or_ship;
		end
		return modkit.table.findVal(self._entities, predicate);
	end

	function lib:findType(type)
		return self:find(function (ship)
			return ship.type_group == %type;
		end);
	end

	function lib:filterType(type)
		return self:filter(function (ship)
			return ship.type_group == %type;
		end)
	end

	--- Spawns new ships, as specified by `spawn_args`.
	---
	--- Returns a `RuleChain|EventChain` which resolves with the newly spawned ships.
	---
	--- @class SpawnArgs
	--- @field ship_type ShipType
	--- @field count? integer
	--- @field where? Position|string
	--- @field player_index? integer
	--- @field spawn_group? string
	---
	--- @param spawn_args (SpawnArgs|string)|(SpawnArgs|string)[]
	function lib:spawnShips(spawn_args)
		if (type(spawn_args) == "table" and type(spawn_args[1]) == "table") then -- an array of `SpawnArgs`, like `{ [1] = { type = "hgn_scout", ... } }`
			local promises = modkit.table.map(spawn_args, function (args)
				return %self:spawnShips(args);
			end)
		end

		local default_args = {
			count = 1,
			where = Vec3(0),
			player_index = -1,
			spawn_group = SobGroup_Fresh()
		};

		if (type(spawn_args) == "string") then -- if the user only gave us a string, we assume it is the `ship_type`
			spawn_args = {
				ship_type = spawn_args,
			};
		end

		---@type SpawnArgs
		spawn_args = modkit.table:merge(default_args, spawn_args);

		local where = spawn_args.where;
		if (type(where) == "table") then
			where = Volume_Fresh("_spawn-vol-ship-" .. self:length() .. "-" .. tostring(floor(Universe_GameTime())), where);
		end
		---@cast where string
		local player_index = spawn_args.player_index;
		---@cast player_index integer
		local count = spawn_args.count;
		---@cast count integer
		local ship_type = spawn_args.ship_type;
		---@cast ship_type ShipType
		local spawn_group = spawn_args.spawn_group;
		---@cast spawn_group string

		for _ = 1, count do
			-- consoleLog("pid: " .. player_index .. ", t: " .. ship_type .. ", g: " .. spawn_group);
			-- consoleLog("where: " .. spawn_args.where);
			SobGroup_SpawnNewShipInSobGroup(player_index, ship_type, "-", spawn_group, where);
		end

		Volume_Delete(where);

		local promise = awaitShips(spawn_group):begin();
		---@cast promise EventChain

		return promise;
	end

	local _ships = function (ships)
		ships = ships or GLOBAL_SHIPS._entities;
		return %lib:shallowCopy(ships);
	end;

	---@type fun(ships?: Ship[]): ShipCollectionExt
	modkit.ships = _ships;
end
