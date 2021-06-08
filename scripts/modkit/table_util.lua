--Table utility functions.

function _printTbl(table, indent, output)
	output = output or print;
	if (indent == nil) then
		indent = 0;
	end
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
			output(indent_str .. "\"" .. k .. "\": {");
			_printTbl(v, indent + 1);
			output(indent_str .. "},");
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
		find = function (table, predicate)
			for i, v in table do
				if (predicate(v, i, table) ~= nil) then
					return v;
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
			table[getn(table) + 1] = value;
			return table;
		end
	};

	function table.printTbl(table, label)
		if (label == nil) then
			label = tostring(table);
		end
		local temp_table = {};
		temp_table[label] = table;
		_printTbl(temp_table);
	end

	function table:merge(tbl_a, tbl_b, merger)
		if (self == nil) then
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

	modkit.table = {};
	for k, v in table do
		modkit.table[k] = v;
	end

	print("table_util init");
end