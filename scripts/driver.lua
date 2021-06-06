-- driver.lua
-- Ships hook here instead of their own nested scripts
-- Do not edit unless you know what you're doing.

function NOOP() end

if (H_DRIVER == nil) then

	if (modkit == nil) then
		dofilepath("data:scripts/modkit.lua");
	end

	if (CUSTOM_CODE == nil) then
		dofilepath("data:scripts/custom_code/custom_code.lua");
	end

	if (GLOBAL_PROTOTYPE == nil or GLOBAL_PROTO_KEY == nil) then
		dofilepath("data:scripts/custom_code/global_attribs.lua");
	end

	function GetCustomAttribs(type_group, player, id)
		
		local as_lower = strlower(type_group);
		if (CUSTOM_CODE[as_lower]) then
			local definition = CUSTOM_CODE[as_lower];
			
			local attribs;
			if (type(definition.attribs) == "table") then
				attribs = definition.attribs;
			else
				attribs = definition.attribs(type_group, player, id);
			end

			-- ensure typed
			if (attribs.type_group == nil) then
				attribs.type_group = type_group;
			end

			if (attribs.own_group == nil) then
				attribs.own_group = SobGroup_Fresh(type_group .. "-" .. id)
			end

			local result = modkit.table.merge(
				definition,
				attribs
			);
			result.attribs = nil; -- remove constructor from output
			return result;
		end
		return {};
	end
	GLOBAL_REGISTER = modkit.MemGroup.Create("mg-global");
	
	function create(type_group, player, id)
		local caller = GLOBAL_REGISTER:set(
			id,
			modkit.table.merge(
				GetCustomAttribs(GLOBAL_PROTO_KEY, player, id),		-- stuff set in global_attribs
				GetCustomAttribs(type_group, player, id)			-- attribs and create/update/destroy custom fns,
			)
		);
		-- ensure non-nil when calling these
		for i, v in {"create", "update", "destroy"} do
			if (caller[v] == nil) then
				caller[v] = NOOP;
			end
		end
		caller:create();
	end

	function update(c, p, s)
		local caller = GLOBAL_REGISTER:get(s);
		SobGroup_SobGroupAdd(caller.own_group, c); -- ensure own group is filled on update

		caller:update();

		local past_self = {};
		for k, v in caller do
			if (k ~= 'past_self') then -- very important to prevent memory pileup!
				if type(v) == 'function' then
					past_self[k] = caller[k](caller); -- collapse getters into values
				else
					past_self[k] = v;
				end
			end
		end
		caller.past_self = past_self; -- for next run comparisons
	end

	function destroy(c, p, s)
		local caller = GLOBAL_REGISTER:get(s);
		caller:destroy();

		GLOBAL_REGISTER:delete(s);
	end

	H_DRIVER = 1;
	print("driver init");
end
