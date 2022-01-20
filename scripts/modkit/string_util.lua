--- Returns a table containing string fragments produced by breaking `str` on every `delimeter`.
--- If the string contains no delimeters, the whole string is returned in one entry.
---@param str string
---@param delimeter string
---@return table
function strsplit(str, delimeter)
	delimeter = delimeter or "%s";

	local i = 1;
	local s, f;
	local matches = {};
	while(i < strlen(str)) do
		s, f = strfind(str, "([^"..delimeter.."]+)", i);
		if (s) then
			modkit.table.push(
				matches,
				{
					start = s,
					finish = f,
					str = strsub(str, s, f)
				}
			);
			i = f + 1;
		else
			break;
		end
	end
	if (modkit.table.length(matches) == 0) then
		matches[0] = {
			start = 1,
			finish = strlen(str),
			str = str
		};
	end
	return matches;
end