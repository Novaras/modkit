if (modkit == nil) then modkit = {}; end
if (modkit.table == nil) then dofilepath("data:scripts/modkit/table_util.lua"); end

if (modkit.compose == nil) then
	local compose = {
		_base = {}, -- base are { proto: table, filter = table } proto is a proto, filter is a table of ship types to apply to (or nil)
		_ship = {},
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
	function compose:instantiate(type_group, player_index, id, type_override)
		local out_ship = {
			ship_type = type_override or type_group
		};

		local base_protos = modkit.table.map(
			modkit.table.filter(
				self._base,
				function (base)
					local tg = %out_ship.ship_type;
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
				[getn(self._base) + 1] = self._ship[out_ship.ship_type]
			}
		);

		local lifetime_hooks = {
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
		};

		-- now merge these prototypes together by layering them
		-- the result is the ship object we want
		for _, proto in source do
			for k, prop in proto do
				if (k == "attribs") then -- attribs are special
					local result = {};
					if (type(prop) == "function") then -- resolve attribs if fn
						result = prop(type_group, player_index, id);
					else
						result = prop;
					end
					out_ship = modkit.table:merge(
						out_ship or {},
						result
					);
				elseif (modkit.table.includesValue(lifetime_hooks, k)) then -- if this is a lifetime hook...
					if (out_ship[k] == nil) then
						out_ship[k] = prop;
					else
						-- we want lifetime hooks to stack instead of being overwritten:
						local old_fn = out_ship[k];
						out_ship[k] = function (self)
							%old_fn(self); -- current stack
							%prop(self); -- new guy
						end
					end
				else
					out_ship[k] = prop;
				end
			end
		end

		return out_ship;
	end


	modkit.compose = compose;

	doscanpath("data:scripts/custom_code", "*.lua");
	doscanpath("data:scripts/custom_code/lib", "*.lua");

	doscanpath("data:scripts/custom_code/mpp", "*.lua");
	doscanpath("data:scripts/custom_code/mpp/hw1", "*.lua");
end