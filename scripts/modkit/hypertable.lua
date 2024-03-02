if (modkit == nil) then
	dofilepath("data:scripts/modkit/table_util.lua");
end


---@type fun(screen_name?: string, dropdown_host_el?: string)

if (not MK_hypertable) then

	--- A getter/setter for the 'hypertable' table, which is just a table written as a string into a hidden UI screen. This string must be parsed
	--- by a script back into a table, so some character limitations exist, and subtables are currently not supported.
	---
	--- `new_state` will be merged into the existing state, unless `overwrite` is `1`, in which case it is overwritten.
	---
	--- `custom_key_behaviors` is the same as the parameter of the same name for the `modkit.table.clone` method, i,e `omit` and `overwrite` for specific keys.
	---
	---	The table returned is just a parsed clone of the hypertable, so modifying the returned table won't have an effect on the hypertable; you should call this handle
	--- and pass in `new_state` etc.
	---
	---@alias HyperTableHandle fun(new_state?: table, custom_key_behaviors?: any, overwrite?: bool): table

	--- Sets up a 'hypertable' table, which is just a table written as a string into a hidden UI screen.
	--- 
	---@param screen_name? string
	---@param dropdown_host_el? string
	---@return HyperTableHandle
	hyperTableHandle = function (screen_name, dropdown_host_el)
		screen_name = screen_name or "DefaultStateScreen";
		dropdown_host_el = dropdown_host_el or "host_dropdown";

		if (UI_GetElementCustomData and UI_GetElementCustomData(screen_name, dropdown_host_el) ~= 1) then
			UI_AddDropDownListboxItem(screen_name, dropdown_host_el, "_", "", 0, "{}");
			UI_SetElementCustomData(screen_name, dropdown_host_el, 1); -- 1 = init
		end

		return function(new_state, custom_key_behaviors, overwrite)
			UI_SelectDropDownListboxItemIndex(%screen_name, %dropdown_host_el, 0);
			local ui_str = UI_GetDropdownListBoxSelectedCustomDataString(%screen_name, %dropdown_host_el);

			local current_state = dostring("return " .. (ui_str or "{}"));

			if (new_state) then
				UI_ClearDropDownListbox(%screen_name, %dropdown_host_el);

				if (overwrite) then -- if overwrite flag set, we just overwrite the whole state
					current_state = new_state;
				else -- otherwise, we do a regular table merge onto it
					current_state = modkit.table.clone(
						modkit.table:merge(current_state, new_state),
						custom_key_behaviors
					);
				end

				-- to store the table, we need to turn into into a string representation first, then we can write that string to the UI
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

	MK_hypertable = 1;
end
