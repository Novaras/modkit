if (modkit == nil) then modkit = {}; end

if (modkit.compose == nil) then
	local compose = {
		_base = {},
		_ship = {}
	};

	function compose:addBaseProto(proto)
		self._base[getn(self._base) + 1] = proto;
	end

	function compose:addShipProto(type, proto)
		self._ship[type] = proto;
	end

	-- this function is the one which constructs ships out of prototypes
	-- it runs every time a new ship is created!
	function compose:instantiate(type_group, player_index, id)
		local out_ship = {};

		-- append custom proto to the base ones:
		local source = modkit.table:merge(
			self._base,
			{
				[getn(self._base) + 1] = self._ship[type_group]
			}
		);

		-- now merge these prototypes together by layering them
		-- the result is the ship object we want
		for _, proto in source do
			for k, prop in proto do
				if (k == "attribs") then
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