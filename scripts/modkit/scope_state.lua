tbl_util = {};

function tbl_util:merge(tbl_a, tbl_b, merger)
	if (self.merge == nil) then
		print("\n[modkit] Error: table:merge must be called as a method (table:merge vs table.merge)");
	end
	merger = merger or function (a, b)
		if (type(a) == "table" and type(b) == "table") then
			return %self:merge(a, b);
		else
			return (b or a);
		end
	end
	if (tbl_a == nil and tbl_b ~= nil) then
		return tbl_b;
	elseif (tbl_a ~= nil and tbl_b == nil) then
		return tbl_a;
	elseif (tbl_b == nil and tbl_b == nil) then
		return {};
	end
	local out = {};
	-- basic copy
	for k, v in tbl_a do
		out[k] = v;
	end
	for k, v in tbl_b do
		if (out[k] == nil) then
			out[k] = v;
		else
			out[k] = merger(out[k], v);
		end
	end
	return out;
end


function makeStateHandle(screen_name, dropdown_host_el)
	screen_name = screen_name or "DefaultStateScreen";
	dropdown_host_el = dropdown_host_el or "host_dropdown";

	if (UI_GetElementCustomData(screen_name, dropdown_host_el) ~= 1) then
		UI_AddDropDownListboxItem(screen_name, dropdown_host_el, "_", "", 0, "{}");
		UI_SetElementCustomData(screen_name, dropdown_host_el, 1); -- 1 = init
	end

	return function(new_state, overwrite)
		UI_SelectDropDownListboxItemIndex(%screen_name, %dropdown_host_el, 0);
		local current_state = dostring("return " .. (UI_GetDropdownListBoxSelectedCustomDataString(%screen_name, %dropdown_host_el) or "{}"));

		if (new_state) then
			UI_ClearDropDownListbox(%screen_name, %dropdown_host_el);

			if (overwrite) then
				current_state = new_state;
			else
				current_state = tbl_util:merge(current_state, new_state);
			end

			local asStr = function (v, tblParser)
				if (type(v) == "table") then
					local out = "{";
					for k, v in v do
						out = out .. k .. "=" .. tblParser(v, tblParser) .. ",";
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