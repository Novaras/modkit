--Table utility functions.

--- Prints the given `table`, recursively if necessary. The output can be any function accepting varargs (i.e `print`, which is default).
---
---@param table table
---@param indent integer
---@param output fun(...: any): nil
---@param no_recurse bool
function _printTbl(table, indent, output, no_recurse)
	output = output or print;
	index = indent or 0;
	local indent_str = "";
	if (indent > 0) then
		local cur_indents = 0;
		while (cur_indents ~= indent) do
			indent_str = indent_str .. "\t";
			cur_indents = cur_indents + 1;
		end
	end
	for k, v in table do
		if type(v) == "table" then
			if (no_recurse) then
				output(indent_str .. tostring(v)); -- just print address
			else
				output(indent_str .. "\"" .. k .. "\": {");
				_printTbl(v, indent + 1, output, no_recurse);
				output(indent_str .. "},");
			end
		else
			if (type(v) ~= "number") then
				v = "\"" .. tostring(v) .. "\"";
			end
			output(indent_str .. "\"" .. k .. "\": " .. v .. ',');
		end
	end
end

if (modkit == nil) then modkit = {}; end

if (modkit.table == nil) then

	-- The functions here are intentionally designed to mimick their JS counterparts for Arrays:
	-- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array
	local table = {
		--- Returns a new table comprised of elements in `table` which pass the given `predicate` function (any non-`nil` return is considered a 'pass').
		---
		---@param table table
		---@param predicate fun(val: any, index: any, tbl: table)
		---@return table
		filter = function (table, predicate)
			local out = {};
			for i, v in table do
				if (predicate(v, i, table)) then
					out[i] = v;
				end
			end
			return out;
		end,
		map = function (table, transform)
			local out = {};
			for i, v in table do
				out[i] = transform(v, i, table);
			end
			return out;
		end,
		reduce = function (table, accumulator, initial_value)
			local out = initial_value;
			for i, v in table do
				out = accumulator(out, v, i, table);
			end
			return out;
		end,
		includesValue = function (table, value)
			for i, v in table do
				if v == value then
					return 1;
				end
			end
		end,
		includesKey = function (table, value)
			for i, v in table do
				if i == value then
					return 1;
				end
			end
		end,
		---@return any
		find = function (table, predicate)
			for i, v in table do
				if (type(predicate) == "function") then
					if (predicate(v, i, table) ~= nil) then
						return v;
					end
				else
					if (v == predicate) then
						return v;
					end
				end
			end
		end,
		length = function (table)
			local n = 0;
			for k, v in table do
				n = n + 1;
			end
			return n;
		end,
		keys = function (table)
			local keys = {};
			local count = 1;
			for k, v in table do
				keys[count] = k;
				count = count + 1;
			end
			return keys;
		end,
		values = function (table)
			local values = {};
			local count = 1;
			for k, v in table do
				values[count] = v;
				count = count + 1;
			end
			return values;
		end,
		push = function (table, value)
			table[modkit.table.length(table) + 1] = value;
			return table;
		end,
		firstKey = function (tbl)
			local lowest_k = modkit.table.length(tbl); -- highest k
			for k, v in tbl do
				if (k < lowest_k) then
					lowest_k = k;
				end
			end
			return lowest_k;
		end,
		any = function (tbl, predicate)
			for k, v in tbl do
				if (predicate(v, k, tbl)) then
					return 1;
				end
			end
			return nil;
		end,
		all = function (tbl, predicate)
			for k, v in tbl do
				if (predicate(v, k, tbl) == nil) then
					return nil;
				end
			end
			return 1;
		end,
		randomEntry = function(tbl)
			local arr = {};
			for k, v in tbl do
				arr[modkit.table.length(arr) + 1] = {
					[1] = k,
					[2] = v
				};
			end
			local index;
			if (modkit.table.length(arr) < 2) then
				index = 1;
			else
				index = random(1, modkit.table.length(arr)); -- they made it so if you call `random(1, 1)`, it counts as an error...
			end
			return arr[index];
		end,
		--- Difference: Any elements in `tbl_a`, which are not found in `tbl_b`.
		---
		---@param tbl_a table
		---@param tbl_b table
		difference = function (tbl_a, tbl_b)
			return modkit.table.filter(tbl_a, function (a_val)
				return modkit.table.find(%tbl_b, a_val) == nil; -- elements in A, but not B
			end);
		end,

		slice = function (tbl, i, j)
			local out = {};
			for index = i, j do
				out[index] = tbl[index];
			end
			return out;
		end
	};

	function table.pack(tbl)
		local out_tbl = {};
		local index = 1;
		for _, v in tbl do
			out_tbl[index] = v;
			index = index + 1;
		end
		return out_tbl;
	end

	function table.firstValue(tbl)
		return tbl[%table.firstKey(tbl)];
	end

	function table.first(tbl)
		return tbl[%table.firstKey(tbl)];
	end

	--- _Clones_ a table, meaning the table is copied by value (a new table is created),
	--- unlike normal copy of a table variable, which merely copies the _reference_ to that table.
	---
	--- Custom behavior can be given for specified keys; they can be either omitted or overridden.
	--- If a key is merked both omitted and overridden, it will be omitted.
	---
	--- Returns a new table which is otherwise a clone of the original.
	---
	---@param tbl table
	---@param custom_key_behaviors? { omit: string[], override: table }
	---@param recurse_stop_depth? number
	---@return table
	function table.clone(tbl, custom_key_behaviors, recurse_stop_depth)
		recurse_stop_depth = recurse_stop_depth or -1;
		custom_key_behaviors = custom_key_behaviors or {};
		local omit = custom_key_behaviors.omit or {};
		local override = custom_key_behaviors.override or {};

		local out = {};
		for k, v in tbl do
			if (modkit.table.includesValue(omit, k) == nil) then -- dont include deletions
				if (modkit.table.includesKey(override, k)) then -- override if given
					out[k] = override[k];
				else
					if (type(v) == "table" and (recurse_stop_depth == -1 or recurse_stop_depth > 0)) then
						out[k] = modkit.table.clone(v, {}, max(-1, recurse_stop_depth - 1));
					else
						out[k] = v;
					end
				end
			end
		end
		return out;
	end

	--- Prints the given `table`, recursively if necessary.
	---
	---@param tbl table
	---@param label? string
	---@param no_recurse? any If non-nil, sub-tables are not printed and their addresses are printed instead
	function table.printTbl(tbl, label, no_recurse)
		if (label == nil) then
			---@type string
			label = tostring(tbl);
		end
		local temp_table = {};
		temp_table[label] = tbl;
		_printTbl(temp_table, 0, print, no_recurse);
	end

	function table:merge(tbl_a, tbl_b, merger)
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

	modkit.table = table;

	print("table_util init");
end
