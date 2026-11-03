--- Returns a table containing the words of `str`: the text between each match of the `delimeter` pattern.
--- Empty words (from repeated, leading or trailing delimiters) are skipped. If `str` has no words, the whole string is returned in one entry.
---
--- `delimeter` is a Lua pattern, i.e `"%s+"` splits on runs of whitespace, and `"%."` on a literal `.`. It must match at least one character
--- (a pattern which can match nothing, like `"%s*"`, is treated as matching nowhere).
---
---@param str string
---@param delimeter? string Default `"%s"` (any whitespace character)
---@param return_words_only? any If set, the entries are the words; otherwise they're `{ start, finish, str }` tables
---@return table
function strsplit(str, delimeter, return_words_only)
	delimeter = delimeter or "%s";

	local matches = {};
	local len = strlen(str);
	local i = 1; -- the start of the current word
	while (i <= len) do
		local delim_start, delim_end = strfind(str, delimeter, i);
		if (delim_start == nil or delim_end < delim_start) then -- no more delimiters (an empty match counts as none): the rest is the last word
			delim_start = len + 1;
			delim_end = len;
		end

		if (delim_start > i) then -- (no word between back-to-back delimiters)
			local part = strsub(str, i, delim_start - 1);
			local payload;
			if (return_words_only) then
				payload = part;
			else
				payload = {
					start = i,
					finish = delim_start - 1,
					str = part
				};
			end
			modkit.table.push(matches, payload);
		end

		i = delim_end + 1;
	end
	if (modkit.table.length(matches) == 0) then
		if (return_words_only) then
			matches[1] = str;
		else
			matches[1] = {
				start = 1,
				finish = len,
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
--- **Not for anything that's sim state** (sobgroup/volume/rule names etc): `random` is C `rand()`, whose sequence engine code
--- (e.g particle FX) also draws from, so it can differ between clients and cause out-of-sync errors. Use a deterministic counter.
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

--- Returns `str` without leading or trailing whitespace.
---
---@param str string
---@return string
function strtrim(str)
	local trimmed = gsub(str, '^%s*(.-)%s*$', '%1'); -- (a local, so only the string is returned, not `gsub`'s count too)
	return trimmed;
end
