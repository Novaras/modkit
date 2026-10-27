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
			matches[1] = str;
		else
			matches[1] = {
				start = 1,
				finish = strlen(str),
				str = str
			};
		end
	end
	return matches;
end

function strcharset(str, index, replacement)
	local pre = strsub(str, 1, index - 1);
	local post = strsub(str, index + 1, strlen(str));

	return pre .. replacement .. post;
end

function strimplode(arr, delimeter)
	delimeter = delimeter or "";

	local str = "";
	for i, word in arr do
		local delim = delimeter;
		if (i == modkit.table.length(arr)) then -- dont append anything on last entry
			delim = '';
		end
		str = str .. word .. delim;
	end

	return str;
end

--- Returns a random id string of `length` characters (default `8`) from `[0-9a-z]`, in the style of nanoid.
---
--- Lowercase only, since names passed to the engine (sobgroups etc.) are often lowercased.
--- 8 chars gives ~2.8e12 possible ids; ids are random, not guaranteed unique, so don't go much shorter for frequently generated names.
---
---@param length? integer
---@return string
function struid(length)
	length = length or 8;
	local alphabet = "0123456789abcdefghijklmnopqrstuvwxyz";
	local alphabet_len = strlen(alphabet);
	local id = "";
	for _ = 1, length do
		local n = random(1, alphabet_len);
		id = id .. strsub(alphabet, n, n);
	end
	return id;
end

function strtrim(str)
	return gsub(str, '^%s*(.-)%s*$', '%1');
end
