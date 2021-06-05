-- Ships hook here instead of their own nested scripts

function NOOP() end

if (H_DRIVER == nil) then
	print("go driver");
	if (modkit == nil) then
		dofilepath("data:scripts/modkit.lua");
	end

	if (CUSTOM_CODE == nil) then
		dofilepath("data:scripts/custom_code/custom_code.lua");
	end

	function GetCustomAttribs(type_group)
		local as_lower = strlower(type_group);
		if (CUSTOM_CODE[as_lower]) then
			return CUSTOM_CODE[as_lower];
		end
		return {};
	end
	GLOBAL_REGISTER = modkit.MemGroup.Create("mg-global");
	
	function create(type_group, player, id)
		local caller = GLOBAL_REGISTER:set(
			id,
			modkit.table.merge(
				{
					type_group = type_group,
					own_group = SobGroup_Clone(type_group, type_group .. "-" .. id),
					player = player
				},
				GetCustomAttribs(type_group) -- attribs and create/update/destroy custom fns
			)
		);
		-- ensure non-nil when calling these
		for i, v in {"create", "update", "destroy"} do
			if (caller[v] == nil) then
				caller[v] = NOOP;
			end
		end

		caller.create(caller);
	end

	function update(c, p, s)
		local caller = GLOBAL_REGISTER:get(s);
		SobGroup_SobGroupAdd(caller.own_group, c);

		caller.update(caller);
	end

	function destroy(c, p, s)
		local caller = GLOBAL_REGISTER:get(s);
		
		caller.destroy(caller);

		GLOBAL_REGISTER:delete(s);
	end

	H_DRIVER = 1;
	print("driver init");
end
