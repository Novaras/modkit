--- Returns a table containing string fragments produced by breaking `str` on every `delimeter`.
--- If the string contains no delimeters, the whole string is returned in one entry.
---@param str string
---@param delimeter string
---@return table
function strsplit(str, delimeter, return_words_only)
	delimeter = delimeter or "%s";

	local i = 1;
	local s, f;
	local matches = {};
	while(i < strlen(str)) do
		s, f = strfind(str, "([^"..delimeter.."]+)", i);
		if (s) then
			local part = strsub(str, s, f);
			local payload;
			if (return_words_only) then
				payload = part;
			else
				payload = {
					start = s,
					finish = f,
					str = part
				};
			end
			modkit.table.push(
				matches,
				payload
			);
			i = f + 1;
		else
			break;
		end
	end
	if (modkit.table.length(matches) == 0) then
		if (return_words_only) then
			matches[0] = str;
		else
			matches[0] = {
				start = 1,
				finish = strlen(str),
				str = str
			};
		end
	end
	return matches;
end

function strrepeat(str, repetitions)
	local out_str = "";
	for i = 0, repetitions do
		out_str = out_str .. str;
	end

	return out_str;
end

function strcharset(str, index, replacement)
	local pre = strsub(str, 1, index - 1);
	local post = strsub(str, index + 1, strlen(str));

	return pre .. replacement .. post;
end