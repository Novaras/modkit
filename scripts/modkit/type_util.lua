if (H_TYPE_UTIL == nil) then
	if (modkit == nil) then modkit = {}; end

	local types = {};

	--- Freezes a table, meaning it cannot be altered (except by `rawset`).
	---
	---@param tbl table
	---@return table
	function types:freeze(tbl)
		local t = newtag();
		local hook = function (tbl, key, value)
			print("Cannot modify frozen table `" .. tostring(tbl) .. "`");
			print("\tOccured while setting key " .. tostring(key) .. " to value " .. value);
			print("\tExisting key/value: [" .. tostring(tbl[key]) .. "]: " .. tostring(value));
		end
		settagmethod(t, "settable", hook);
		settag(tbl, t);

		return tbl;
	end

	modkit.types = types;
	H_TYPE_UTIL = 1;
end