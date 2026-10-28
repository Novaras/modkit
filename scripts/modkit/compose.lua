if (modkit == nil) then modkit = {}; end
if (modkit.table == nil) then dofilepath("data:scripts/modkit/table_util.lua"); end
if (modkit.custom_code_dirs == nil) then dofilepath("data:scripts/modkit/custom_code_dirs.lua"); end

if (modkit.compose == nil) then
	local compose = {
		_base = {}, -- base are { proto: table, filter = table } proto is a proto, filter is a table of ship types to apply to (or nil)
		_ship = {},
		_ship_order = {}, -- keys of `_ship`, in the order they were registered
		_cache = {},
		_lifetime_hooks = {
			-- actual hooks
			"load",
			"create",
			"update",
			"destroy",
			"start",
			"go",
			"finish",
			-- extras
			"beforeUpdate",
			"afterUpdate",
		}
	};

	--- Adds a 'base' prototype, which will affect all ship types matching `type_filter` (or all ship types, if there's no filter);
	--- with `inverse_filter`, it instead affects all ship types _not_ matching it.
	---
	--- Filter entries are Lua patterns matched anywhere in the ship type, so `"kus_researchship"` also matches `"kus_researchship_1"`;
	--- anchor them (`"kus_researchship$"`, `"^kus_"`) to avoid that.
	---
	--- All the bases are availble in `_base`; when a ship's final definition is constructed all the recorded
	--- bases will be overlayed to produce the final base. The specific prototypes for individual ship types
	--- are overlayed on top of the final base.
	---
	---@param proto table
	---@param type_filter? string[]
	---@param inverse_filter? bool
	function compose:addBaseProto(proto, type_filter, inverse_filter)
		self._base[modkit.table.length(self._base) + 1] = {
			proto = proto,
			filter = type_filter,
			inverse_filter = inverse_filter
		};
	end

	--- Defines a specific ship type's properties & methods.
	---
	--- A ship type gets the proto registered under its exact name, if there is one. Otherwise, `type` is treated as a Lua pattern
	--- matched anywhere in the ship type, like `addBaseProto`'s filters: `"kus_researchship"` would also match `"kus_researchship_1"`
	--- (if that has no proto of its own), so anchor it (`"kus_researchship$"`) if another ship type starts with it.
	--- If several patterns match, the first one registered wins.
	---
	---@param type string
	---@param proto table
	function compose:addShipProto(type, proto)
		if (self._ship[type] == nil) then
			self._ship_order[getn(self._ship_order) + 1] = type;
		end
		self._ship[type] = proto;
	end

	--- Returns the ship proto for `ship_type`: the one registered under its exact name, else the first registered whose pattern matches it.
	---
	---@param ship_type string
	---@return table|nil
	function compose:_findShipProto(ship_type)
		if (self._ship[ship_type]) then
			return self._ship[ship_type];
		end
		-- `_ship_order` rather than `for k, v in self._ship`, since Lua's table iteration order is undefined
		for i = 1, getn(self._ship_order) do
			if (strfind(ship_type, self._ship_order[i])) then
				return self._ship[self._ship_order[i]];
			end
		end
	end

	--- **Returns a new `Ship` of the given type. This `Ship` object is a rich representation of the actual ship ingame.**
	--- 
	--- ---
	--- Example:
	--- ```lua
	--- function update(CustomGroup, playerIndex, shipID)
	--- 	local repair_vette = modkit.compose:instantiate(CustomGroup, playerIndex, shipID);
	--- 
	--- 	repair_vette:HP(0.5);
	--- 	repair_vette:ROE(PassiveROE);
	--- 	if (repair_vette:attacking()) then
	--- 		repair_vette:stop();
	--- 	end
	--- 	-- etc..
	--- end
	--- ```
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
	---@param id? string|integer The ID of the ship (availble in the `create`/`update`/`destroy` hooks as linked via `addCustomCode` in the `.ship` file)
	---@param ship_type? string The ship's type (e.g `'kus_scout'`)
	---@return Ship
	function compose:instantiate(sobgroup, player_index, id, ship_type)
		local ship_type = ship_type or sobgroup;

		-- print("\n\ninstantiate run for " .. ship_type .. "(pid: " .. player_index .. "), group = " .. sobgroup);
		-- print("\tst = " .. ship_type);
		-- print("\tposition = " .. Vec3(SobGroup_GetPosition(sobgroup)));
		-- print("\trules runtime? " .. tostring(Rule_AddInterval));
		-- print("\n\n");

		local base_protos = modkit.table.map(
			modkit.table.filter(
				self._base,
				function (base)
					local tg = %ship_type;
					-- print("COMPOSE: SEES SHIP TYPE " .. tg);
					if (not base.filter) then
						return 1;
					end

					local is_filter_type = modkit.table.findVal(base.filter, function (filter_str)
						return strfind(%tg, filter_str);
					end) ~= nil;

					if (base.inverse_filter) then
						return not is_filter_type;
					end

					return is_filter_type;
				end
			),
			function (base)
				return base.proto;
			end
		);

		-- print("instantiate for " .. sobgroup);
		-- modkit.table.printTbl(base_protos, "base protos to be applied");

		-- append custom proto to the base ones:
		local source = modkit.table:merge(
			base_protos,
			{
				[getn(self._base) + 1] = self:_findShipProto(ship_type)
			}
		);

		local instance = modkit.table.reduce(
			source,
			function (acc, proto)
				local attribs = proto.attribs;
				local result = {};
				if (attribs) then
					if (type(attribs) == "function") then
						result = attribs(%sobgroup, %player_index, %id, %ship_type);
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
		-- modkit.table.printTbl(out_ship, "newly instantiated " .. ship_type .. ", sid = " .. id);

		settag(out_ship, self._ship_tag); -- shared tag (see `_ship_tag` below)

		return out_ship;
	end


	-- one tag shared by every instantiated `Ship` (Lua 4 tags are never freed, so a tag per instance leaked one per instantiation)
	-- the concat hook lets `"..." .. ship` produce the ship's `own_group`
	compose._ship_tag = newtag();
	settagmethod(compose._ship_tag, "concat", function (lhs, rhs)
		local toStr = function (arg)
			if (type(arg) == "table" and arg.own_group) then
				return arg.own_group;
			end

			return tostring(arg);
		end

		return toStr(lhs) .. toStr(rhs);
	end);

	modkit.compose = compose;

	print("== modkit: load ship scripts... ==");

	-- `doscanpath` doesn't recurse, so subdirectories are loaded from a list (see `custom_code_dirs.lua`)
	doscanpath("data:scripts/custom_code", "*.lua");
	for i = 1, getn(modkit.custom_code_dirs) do
		doscanpath("data:scripts/custom_code/" .. modkit.custom_code_dirs[i], "*.lua");
	end

	print("== modkit: ship scripts loaded ==")

	-- modkit.table.printTbl(modkit.table.keys(modkit.compose._ship), "ship protos");
end