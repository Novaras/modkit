if (modkit == nil) then
	dofilepath("data:scripts/modkit/table_util.lua");
end

---@type fun(screen_name?: string, dropdown_host_el?: string)
makeStateHandle = makeStateHandle or function (screen_name, dropdown_host_el)
	screen_name = screen_name or "DefaultStateScreen";
	dropdown_host_el = dropdown_host_el or "host_dropdown";

	if (UI_GetElementCustomData and UI_GetElementCustomData(screen_name, dropdown_host_el) ~= 1) then
		UI_AddDropDownListboxItem(screen_name, dropdown_host_el, "_", "", 0, "{}");
		UI_SetElementCustomData(screen_name, dropdown_host_el, 1); -- 1 = init
	end

	return function(new_state, custom_key_behaviors, overwrite)
		UI_SelectDropDownListboxItemIndex(%screen_name, %dropdown_host_el, 0);
		-- print("CURRENT UI_STR STATE:");
		-- print(UI_GetDropdownListBoxSelectedCustomDataString(%screen_name, %dropdown_host_el) or "{}");

		local current_state = dostring("return " .. (UI_GetDropdownListBoxSelectedCustomDataString(%screen_name, %dropdown_host_el) or "{}"));

		if (new_state) then
			UI_ClearDropDownListbox(%screen_name, %dropdown_host_el);

			if (overwrite) then
				current_state = new_state;
			else
				current_state = modkit.table.clone(
					modkit.table:merge(current_state, new_state),
					custom_key_behaviors
				);
			end

			local asStr = function (v, tblParser)
				if (type(v) == "table") then
					local out = "{";
					for k, v in v do
						local i = tostring(k);
						if (type(k) == "number") then
							i = "[" .. k .. "]";
						end
						out = out .. i .. "=" .. tblParser(v, tblParser) .. ",";
					end
					out = out .. "}";
					return out;
				elseif (type(v) == "string") then
					return "\"" .. v .. "\"";
				else
					return tostring(v);
				end
			end

			local state_str = asStr(current_state, asStr);
			UI_AddDropDownListboxItem(%screen_name, %dropdown_host_el, "_", "", 0, state_str);
		end

		return current_state;
	end
end