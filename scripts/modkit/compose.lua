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

	function compose:addBaseProto(proto, type_filter)
		self._base[modkit.table.length(self._base) + 1] = {
			proto = proto,
			filter = type_filter
		};
	end

	function compose:addShipProto(type, proto)
		self._ship[type] = proto;
	end

	-- this function is the one which constructs ships out of prototypes
	-- it runs every time a new ship is created!
	---@param type_group string
	---@param player_index? integer
	---@param id? integer
	---@param type_override? string
	---@return Ship
	function compose:instantiate(type_group, player_index, id, type_override)
		-- print("instantiate run for " .. type_group .. "(pid: " .. player_index .. ")");
		local ship_type = type_override or type_group;

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
					result = attribs;
					if (type(attribs) == "function") then
						result = attribs(%type_group, %player_index, %id);
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
				proto.attribs = nil;

				return modkit.table:merge(
					acc,
					proto,
					function (a, b, k)
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