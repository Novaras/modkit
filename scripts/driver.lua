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

			return modkit.table.merge(
				{
					create = definition.create,
					update = definition.update,
					destroy = definition.destroy
				},
				attribs
			);
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

		print("\n\n\n");
		modkit.table.printTbl(caller);
		print("\n\n\n");

		print(type(caller.update));
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
