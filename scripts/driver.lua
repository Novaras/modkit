-- driver.lua
-- Ships hook here instead of their own nested scripts
-- Do not edit unless you know what you're doing.

--- Does nothing: no-operation
NOOP = NOOP or function()
	--
end

if (H_DRIVER == nil) then
	---@alias HookFn fun(self: DriverShip, group?: string, player_index?: number, ship_id?: number)

	---@class DriverShip: Ship
	---@field create HookFn
	---@field update HookFn
	---@field destroy HookFn
	---@field start HookFn
	---@field go HookFn
	---@field finish HookFn
	---@field auto_exec table

	if (modkit == nil) then
		dofilepath("data:scripts/modkit.lua");
	end

	---@class ShipCollection : SheduledFilters, MemGroupInst
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

	initPlayers(); -- modkit/player.lua

	--- Returns selected ships.
	---
	---@return Ship[]
	function GLOBAL_SHIPS:selected()
		local selected = {};
		for _, ship in GLOBAL_SHIPS:all() do
			---@cast ship Ship
			if (ship:selected()) then
				modkit.table.push(selected, ship);
			end
		end

		return selected;
	end

	--- Returns all ships which are allied with the `caller`.
	---
	---@param caller Ship|Player
	---@param filter_predicate ShipFilterPredicate
	---@return Ship[]
	function GLOBAL_SHIPS:allied(caller, filter_predicate)
		local allied_ships = {};
		for index, ship in self:all() do
			if (ship:alliedWith(caller) and filter_predicate(ship)) then
				allied_ships[index] = ship;
			end
		end
		return allied_ships;
	end

	--- Returns all ships which are not allied with the `caller`.
	---
	---@param caller Ship
	---@param filter_predicate ShipFilterPredicate
	---@return Ship[]
	function GLOBAL_SHIPS:enemies(caller, filter_predicate)
		local enemy_ships = {};
		for index, ship in self:all() do
			if (ship:alliedWith(caller) == nil and filter_predicate(ship)) then
				enemy_ships[index] = ship;
			end
		end
		return enemy_ships;
	end

	--- Registers the incoming sobgroup, player index, and ship id into a Ship table within the global registry.
	-- The Ship is a rich representation of the actual ingame ship as a proper workable table.
	---@param type_group string
	---@param player_index integer
	---@param ship_id integer
	---@return Ship
	register = register or function (type_group, player_index, ship_id)
		type_group = strlower(type_group); -- immediately make this lowercase
		local caller = GLOBAL_SHIPS:get(ship_id);
		if (caller ~= nil) then -- fast return if already exists
			return caller;
		end

		---@type Ship
		caller = GLOBAL_SHIPS:set(
			ship_id,
			modkit.compose:instantiate(type_group, player_index, ship_id)
		);

		local l = {};
		local f = function (...)
			local line = "";
			for k, v in arg do
				if (k ~= "n") then
					if (type(v) ~= "string") then
						line = line .. tostring(v);
					else
						line = line .. v;
					end
				end
			end
			modkit.table.push(%l, line);
		end
		modkit.table.printTbl({ type_group = type_group, player_index = player_index, ship_id = ship_id }, "caller?", nil, f, 1);
		local stateHnd = makeStateHandle();

		local str_representation = type_group .. "," .. player_index .. "," .. ship_id;

		stateHnd({
			GLOBAL_SHIPS = modkit.table.push(stateHnd().GLOBAL_SHIPS or {}, str_representation);
		});

		-- ensure non-nil when calling these:
		for i, v in {
			"load",
			"create",
			"update",
			"destroy",
			"start",
			"go",
			"finish"
		} do
			if (caller[v] == nil) then
				caller[v] = NOOP;
			end
		end
		caller.auto_exec = {};

		return caller;
	end

	-- === load, create, update, destroy ===

	load = load or function()
		return NOOP;
	end

	GLOBAL_SHIPS.cache = GLOBAL_SHIPS.cache or {};
	GLOBAL_SHIPS.cache.newly_created = GLOBAL_SHIPS.cache.newly_created or {};

	--- The global `create` hook called by all ships correctly linked to modkit.
	---
	--- Called **once**, on spawn (construction, spawned by script, etc.)
	---@param g string The sobgroup containing the callee's squad
	---@param p integer The player index (id)
	---@param i integer The ship's unique id
	---@return DriverShip
	create = create or function(g, p, i)
		local caller = register(g, p, i);

		caller:create(); -- run the caller's custom create hook

		return caller;
	end

	--- The global `update` hook called by all ships correctly linked to modkit.
	---
	--- Called **periodically**, with an interval defined in the `addCustomCode` call.
	---@param g string The sobgroup containing the callee's squad
	---@param p integer The player index (id)
	---@param i integer The ship's unique id
	---@return DriverShip
	update = update or function(g, p, i)
		local caller = GLOBAL_SHIPS:get(i);
		if (caller == nil or caller.own_group == nil) then -- can happen when loading a save etc.
			caller = create(g, p, i);
		end
		---@cast caller DriverShip

		-- if (caller.own_group == nil) then
		-- 	print("og: " .. (caller.own_group or "nil"));
		-- 	modkit.table.printTbl(caller);
		-- end

		local engine_player_index = SobGroup_GetPlayerOwner(caller.own_group);
		if (caller.player.id ~= engine_player_index and engine_player_index >= 0 and engine_player_index < 8) then
			caller.player = GLOBAL_PLAYERS:get(engine_player_index);
		end

		SobGroup_SobGroupAdd(caller.own_group, g); -- ensure own group is filled on update
		caller:tick(caller:tick() + 1);

		caller:update(); -- run the caller's custom update hook

		for k, v in caller.auto_exec do
			v(caller, k);
		end

		if (caller:tick() == 1) then
			-- now the ship is definitely ready
			GLOBAL_SHIPS.cache.newly_created[i] = caller;
		end

		return caller;
	end

	--- The global `destroy` hook called by all ships correctly linked to modkit.
	---
	--- Called **once**, on despawn (death, retirement, etc.)
	---@param g string The sobgroup containing the callee's squad
	---@param p integer The player index (id)
	---@param i integer The ship's unique id
	---@return DriverShip
	destroy = destroy or function(g, p, i)
		local caller = GLOBAL_SHIPS:get(i);
		---@cast caller DriverShip

		caller:destroy(); -- run the caller's custom destroy hook

		GLOBAL_SHIPS:delete(i);
		
		return caller;
	end

	-- === start, go, finish ===

	--- The global `start` function, called by all custom ability ships correctly linked to modkit.
	---
	--- Called **once per ability activation**, at the start of the ability.
	---@param g string The sobgroup containing the callee's squad
	---@param p integer The player index (id)
	---@param i integer The ship's unique id
	---@return DriverShip
	start = start or function(g, p, i)
		local caller = GLOBAL_SHIPS:get(i);
		---@cast caller DriverShip

		caller:start();

		return caller;
	end

	--- The global `go` function, called by all custom ability ships correctly linked to modkit.
	---
	--- Called **periodically** while the custom ability remains active, with an interval set in the `customCommand` call.
	---@param g string The sobgroup containing the callee's squad
	---@param p integer The player index (id)
	---@param i integer The ship's unique id
	---@return DriverShip
	go = go or function(g, p, i)
		local caller = GLOBAL_SHIPS:get(i);
		---@cast caller DriverShip

		caller:go();

		return caller;
	end

	--- The global `finish` function, called by all custom ability ships correctly linked with modkit.
	---
	--- Called **once per ability activation**, at the end of the ability.
	---@param g string The sobgroup containing the callee's squad
	---@param p integer The player index (id)
	---@param i integer The ship's unique id
	---@return DriverShip
	finish = finish or function(g, p, i)
		local caller = GLOBAL_SHIPS:get(i);
		---@cast caller DriverShip

		caller:finish();

		return caller;
	end

	H_DRIVER = 1;
	print("driver init");
end
