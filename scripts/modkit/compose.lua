if (modkit == nil) then modkit = {}; end
if (modkit.table == nil) then dofilepath("data:scripts/modkit/table_util.lua"); end

if (modkit.compose == nil) then
	local compose = {
		_base = {}, -- base are { proto: table, filter = table } proto is a proto, filter is a table of ship types to apply to (or nil)
		_ship = {},
		_cache = {},
		_lifetime_hooks = {
			-- actual hooks
			"load",
			"create",
			"update",
			"destroy",
			"start",
			"go",
			"destroy",
			-- extras
			"beforeUpdate",
			"afterUpdate",
		}
	};

	--- Adds a 'base' prototype, which will affect all ship types not included in `type_filter`.
	---
	--- All the bases are availble in `_base`; when a ship's final definition is constructed all the recorded
	--- bases will be overlayed to produce the final base. The specific prototypes for individual ship types
	--- are overlayed on top of the final base.
	---
	---@param proto table
	---@param type_filter? string[]
	function compose:addBaseProto(proto, type_filter)
		self._base[modkit.table.length(self._base) + 1] = {
			proto = proto,
			filter = type_filter
		};
	end

	--- Defines a specific ship type's properties & methods.
	---@param type string
	---@param proto table
	function compose:addShipProto(type, proto)
		self._ship[type] = proto;
	end

	--- **Returns a new `Ship` of the given type. This `Ship` object is a rich representation of the actual ship ingame.**
	--- 
	--- ---
	---
	--- The definition of a specific type of `Ship` object is a composition of any base prototypes supplied via `addBaseProto`,
	--- which is finally overlayed with any specific ship type definition for the given `ship_type` via `addShipProto`.
	---
	--- Normal usage of modkit produces `Ship` entities where `sobgroup` and `ship_type` are the same (the group name and the ship type are the same string).
	--- This is because the lifetime hooks `CustomGroup` value is always the ship's type string.
	---
	---@param sobgroup string A SobGroup containing the ship(/squad) to link
	---@param player_index? integer The index of the player this ship belongs to
	---@param id? integer The ID of the ship (availble in the `create`/`update`/`destroy` hooks as linked via `addCustomCode` in the `.ship` file)
	---@param ship_type? string The ship's type (e.g `'kus_scout'`)
	---@return Ship
	function compose:instantiate(sobgroup, player_index, id, ship_type)
		-- print("instantiate run for " .. type_group .. "(pid: " .. player_index .. ")");
		local ship_type = ship_type or sobgroup;

		local base_protos = modkit.table.map(
			modkit.table.filter(
				self._base,
				function (base)
					local tg = %ship_type;
					return base.filter == nil or modkit.table.find(base.filter, function (ship_type)
						return ship_type == %tg;
					end)
				end
			),
			function (base)
				return base.proto;
			end
		);

		-- append custom proto to the base ones:
		local source = modkit.table:merge(
			base_protos,
			{
				[getn(self._base) + 1] = self._ship[ship_type]
			}
		);

		local instance = modkit.table.reduce(
			source,
			function (acc, proto)
				local attribs = proto.attribs;
				local result = {};
				if (attribs) then
					if (type(attribs) == "function") then
						result = attribs(%sobgroup, %player_index, %id);
					end
				end

				return modkit.table:merge(acc, result);
			end,
			{}
		);

		local static = self._cache[ship_type] or modkit.table.reduce(
			source,
			function (acc, proto)
				local hooks = %self._lifetime_hooks;

				return modkit.table:merge(
					acc,
					proto,
					function (a, b, k)
						if (k ~= "attribs") then
							if (type(a) == "table" and type(b) == "table") then
								return modkit.table:merge(a, b);
							else
								if (modkit.table.includesValue(%hooks, k)) then
									if (a == nil) then
										return b;
									else
										-- we want lifetime hooks to stack instead of being overwritten:
										local old_fn = a;
										return function (self)
											%old_fn(self); -- current stack
											%b(self); -- new guy
										end
									end
								else
									return (b or a);
								end
							end
						end
					end
				);
			end
		);
		self._cache[ship_type] = static;

		local out_ship = modkit.table:merge(
			static,
			instance
		);

		-- modkit.table.printTbl(out_ship, "newly instantiated " .. type_group .. ", sid = " .. id);

		return out_ship;
	end


	modkit.compose = compose;

	doscanpath("data:scripts/custom_code", "*.lua");
	doscanpath("data:scripts/custom_code/lib", "*.lua");

	doscanpath("data:scripts/custom_code/hw1", "*.lua");
	doscanpath("data:scripts/custom_code/horde/ship_scripts", "*.lua");
end