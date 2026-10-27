-- ship_list.lua: `modkit.ShipList`, a keyed list of `Ship`s which keeps a sobgroup of its members in sync.
--
-- Any `Ship` method can be called on a list (`list:attack(target)`, `list:ROE(PassiveROE)`, ...), without ShipList
-- mirroring the Ship API: an `index` tag method resolves unknown keys to a function which either
-- - calls the method once against the list's synced group, for 'group-safe' methods (one engine call for all ships), or
-- - calls the method on each ship in turn, returning a table of results keyed as the ships are.

if (modkit == nil) then modkit = {}; end
if (modkit.table == nil) then dofilepath("data:scripts/modkit/table_util.lua"); end

if (modkit.ShipList == nil) then
	---@class ShipList
	---@field group_name string The sobgroup kept in sync with this list's ships (use `:group()` to read it)
	---@field _ships table<any, Ship>
	---@field _dirty? bool Set when membership changes, so the group is rebuilt on next use
	---@field __is_ship_list 1
	local proto = {};

	-- === membership ===

	--- Drops ships flagged as destroyed (`_destroyed`, set by the driver's `destroy` hook / the hoist rule).
	--- This is a pure Lua check, so it runs on every read: lists prune themselves without polling the engine.
	function proto:_dropDestroyed()
		for key, ship in self._ships do
			if (ship._destroyed) then
				self._ships[key] = nil;
				self._dirty = 1;
			end
		end
	end

	--- Adds `ship` under `key` (default: the ship's `id`), replacing any ship already under that key.
	---
	---@param ship Ship
	---@param key? any
	---@return Ship
	function proto:add(ship, key)
		self._ships[key or ship.id] = ship;
		self._dirty = 1;
		return ship;
	end

	--- Removes a ship, given either its key or the `Ship` itself (matched by `id`).
	---
	---@param key_or_ship any|Ship
	function proto:remove(key_or_ship)
		local key = key_or_ship;
		if (type(key_or_ship) == "table" and key_or_ship.own_group) then
			key = modkit.table.findIndex(self._ships, function (ship)
				return ship.id == %key_or_ship.id;
			end);
		end

		if (key ~= nil and self._ships[key]) then
			self._ships[key] = nil;
			self._dirty = 1;
		end
	end

	--- Returns the ship under `key`, if any.
	---
	---@param key any
	---@return Ship|nil
	function proto:get(key)
		self:_dropDestroyed();
		return self._ships[key];
	end

	--- Returns the ships in this list, keyed as they were added. Don't modify this table directly; use `:add`/`:remove`.
	---
	---@return table<any, Ship>
	function proto:ships()
		self:_dropDestroyed();
		return self._ships;
	end

	---@return integer
	function proto:length()
		self:_dropDestroyed();
		return modkit.table.length(self._ships);
	end

	--- Removes all ships from the list (does not affect the ships themselves).
	function proto:clear()
		self._ships = {};
		self._dirty = 1;
	end

	--- Removes any ships which are no longer alive, by asking the engine (one call per ship).
	---
	--- Ships tracked by modkit are dropped automatically on death; this is only needed for ships it doesn't track,
	--- and `:group()` calls it itself if the group has drifted from the list.
	function proto:prune()
		for key, ship in self._ships do
			if (ship:alive() == nil) then
				self._ships[key] = nil;
				self._dirty = 1;
			end
		end
	end

	--- Returns the name of a sobgroup containing exactly this list's ships, rebuilding it first if the list has changed
	--- (or the group has drifted from the list, e.g a ship died).
	---
	--- The group is only created here, so constructing a `ShipList` (e.g in ship attribs, which also run in other scopes)
	--- never touches the engine.
	---
	---@return string
	function proto:group()
		self:_dropDestroyed(); -- first, so ships which died normally mark the list dirty rather than looking like drift
		local drifted = (not self._dirty) and SobGroup_Count(self.group_name) ~= self:length();
		if (drifted) then
			self:prune(); -- something the destroy flag didn't catch (e.g a ship modkit doesn't track died)
		end

		if (self._dirty or drifted) then
			SobGroup_Fresh(self.group_name);
			for _, ship in self._ships do
				SobGroup_SobGroupAdd(self.group_name, ship.own_group);
			end
			self._dirty = nil;
		end
		return self.group_name;
	end

	-- === bulk actions: any `Ship` method can be called on the list (see the `index` tag method below) ===

	--- `Ship` methods which only use `self.own_group` (and `self.player`), so calling them once on a stand-in whose `own_group` is
	--- the list's synced group acts on every ship with a single engine call. Any other method is called on each ship in turn.
	---
	--- **Only add a method here if its implementation uses nothing from `self` except `own_group` and `player`.**
	local group_safe_methods = {
		HP = 1,
		ROE = 1,
		stance = 1,
		attack = 1,
		speed = 1,
	};

	--- Returns `method` called with `self_arg` followed by the varargs table `args` (Lua 4 has no unpack; `call` takes an arg table).
	local callWithSelf = function (method, self_arg, args)
		local full_args = { self_arg };
		for i = 1, args.n do
			full_args[i + 1] = args[i];
		end
		full_args.n = args.n + 1;
		return call(method, full_args);
	end

	--- Returns a function which runs the `Ship` method `method_name` for the whole list, or `nil` if there's no such method.
	---
	--- Group-safe methods return the single result of the group call. Others return a table of each ship's result, keyed as the ships are.
	---
	---@param list ShipList
	---@param method_name string
	---@return function|nil
	local bulkMethod = function (list, method_name)
		local any_ship = modkit.table.firstValue(list:ships());
		if (any_ship == nil) then
			-- nothing to act on; but only pretend the method exists if it's a known `Ship` method, so field checks like
			-- `x.own_group` (used to detect a `Ship`) stay `nil` for lists
			if ((modkit_ship and type(modkit_ship[method_name]) == "function") or (modkit_base and type(modkit_base[method_name]) == "function")) then
				return function () return nil; end
			end
			return nil;
		end

		local method = any_ship[method_name];
		if (type(method) ~= "function") then
			return nil;
		end

		local callWithSelf = %callWithSelf; -- re-local it, since the closures below can only upvalue this function's locals

		if (%group_safe_methods[method_name]) then
			return function (self, ...)
				local any = modkit.table.firstValue(self:ships());
				if (any == nil) then
					return nil;
				end
				return %callWithSelf(%method, { own_group = self:group(), player = any.player }, arg);
			end
		end

		return function (self, ...)
			local results = {};
			for key, ship in self:ships() do
				results[key] = %callWithSelf(ship[%method_name], ship, arg);
			end
			return results;
		end
	end

	--- The `index` tag method: runs for any key not present on a list. ShipList's own methods come first, then internal (`_`-prefixed)
	--- keys stay absent, and anything else is treated as a `Ship` method to run across the list.
	local list_tag = newtag();
	settagmethod(list_tag, "index", function (list, key)
		if (%proto[key]) then
			return %proto[key];
		end
		if (type(key) ~= "string" or strsub(key, 1, 1) == "_") then
			return nil;
		end
		return %bulkMethod(list, key);
	end);

	-- === constructor ===

	---@class ShipListLib
	---@overload fun(group_name: string): ShipList
	local lib = {};

	--- Returns `1` if `target` is 'ship-like': a `Ship`, a `ShipList`, or a table of `Ship`s.
	---
	--- Use this to tell ships apart from positions, rather than "not a Vec3 => ship", since positions aren't always
	--- well-formed (e.g the console parses position components as strings).
	---
	---@param target any
	---@return bool
	function lib.isShipLike(target)
		if (type(target) ~= "table") then
			return nil;
		end
		if (target.own_group or target.__is_ship_list) then
			return 1;
		end
		local first = modkit.table.firstValue(target);
		if (type(first) == "table" and first.own_group) then
			return 1;
		end
		return nil;
	end

	--- Resolves anything 'ship-like' into a sobgroup name, so methods can accept any of them:
	--- - `string`: assumed to already be a sobgroup name
	--- - `ShipList`: its synced group
	--- - `Ship`: its `own_group`
	--- - `Ship[]`: a temp group (`temp_group_name`) filled with the ships (rebuilt every call; prefer a `ShipList` for repeated use)
	---
	---@param target string|Ship|Ship[]|ShipList
	---@param temp_group_name? string
	---@return string
	function lib.groupOf(target, temp_group_name)
		if (type(target) == "string") then
			return target;
		elseif (target.__is_ship_list) then
			return target:group();
		elseif (target.own_group) then
			return target.own_group;
		end
		return SobGroup_FromShips(target, temp_group_name);
	end

	--- Returns the position of anything 'ship-like': a `Ship`'s position, or the average position of the ships in a
	--- `ShipList`, `Ship[]` or sobgroup name (see `groupOf` for `temp_group_name`).
	---
	---@param target string|Ship|Ship[]|ShipList
	---@param temp_group_name? string
	---@return Position
	function lib.positionOf(target, temp_group_name)
		if (type(target) == "table" and target.own_group) then
			---@cast target Ship
			return target:position();
		end
		return Vec3(SobGroup_GetPosition(%lib.groupOf(target, temp_group_name)));
	end

	--- Creates a new `ShipList`, whose ships are kept in the sobgroup `group_name`. The name should be unique and deterministic
	--- (e.g based on the owning ship's id), so every scope refers to the same group.
	---
	---@param group_name string
	---@return ShipList
	function lib.new(group_name)
		local list = {
			group_name = group_name,
			_ships = {},
			_dirty = 1,
			__is_ship_list = 1,
		};
		settag(list, %list_tag); -- methods are resolved by the tag method, so nothing is copied per list
		return list;
	end

	-- allow `modkit.ShipList(group_name)` as shorthand for `modkit.ShipList.new(group_name)`
	local callable_tag = newtag();
	settagmethod(callable_tag, "function", function (_, group_name)
		return %lib.new(group_name);
	end);
	settag(lib, callable_tag);

	modkit.ShipList = lib;
end
