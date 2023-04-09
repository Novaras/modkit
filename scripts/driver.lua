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

	if (modkit == nil or initPlayers == nil) then
		print("driver loading modkit...");
		dofilepath("data:scripts/modkit.lua");
		dofilepath("data:scripts/modkit/player.lua");

		initPlayers();
		initShips();
	end

	--- Registers the incoming sobgroup, player index, and ship id into a Ship table within the global registry.
	-- The Ship is a rich representation of the actual ingame ship as a proper workable table.
	---@param type_group string
	---@param player_index integer
	---@param ship_id integer
	---@return Ship
	register = register or function (type_group, player_index, ship_id)
		-- print("register a " .. type_group .. " for player " .. player_index);

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
		-- print("calling create for " .. tostring(g .. "-" .. i));
		---@type DriverShip
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
		-- print("update for " .. caller.own_group);
		if (caller == nil or caller.own_group == nil) then -- can happen when loading a save etc.
			---@type DriverShip
			caller = create(g, p, i);
		end

		-- if (caller.player == nil) then
		-- 	print("pl?: " .. tostring(modkit.table.filter(caller.player, function (val, index, tbl)
		-- 		return type(val) ~= "function";
		-- 	end)));
		-- 	modkit.table.printTbl(modkit.table.filter(caller, function (val, index, tbl)
		-- 		return type(val) ~= "function";
		-- 	end));
		-- 	modkit.table.printTbl(GLOBAL_PLAYERS, "GP");
		-- end

		local engine_player_index = SobGroup_GetPlayerOwner(caller.own_group);
		if (caller.player.id ~= engine_player_index and engine_player_index >= 0 and engine_player_index < 8) then
			caller.player = GLOBAL_PLAYERS:get(engine_player_index);
		end

		local stateHnd = makeStateHandle();
		local superglobal_ships = stateHnd().GLOBAL_SHIPS or {};
		if (superglobal_ships[caller.id] == nil and Universe_GameTime and Universe_GameTime() > 0) then -- intentionally ignore ships set by the .level; we let the mission handle these cases
			print("now adding " .. g .. "-" .. i .. " to the superglobal state");

			superglobal_ships[caller.id] = caller.own_group;
			stateHnd({
				GLOBAL_SHIPS = superglobal_ships,
			});
			modkit.table.printTbl(stateHnd().GLOBAL_SHIPS, "SUPERGLOBAL SHIPS");
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
		---@type DriverShip
		local caller = GLOBAL_SHIPS:get(i);

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
		---@type DriverShip
		local caller = GLOBAL_SHIPS:get(i);

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
		---@type DriverShip
		local caller = GLOBAL_SHIPS:get(i);

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
		---@type DriverShip
		local caller = GLOBAL_SHIPS:get(i);

		caller:finish();

		return caller;
	end

	H_DRIVER = 1;
	print("driver init");
end
