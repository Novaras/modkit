--Table utility functions.

function _printTbl(table, indent)
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
			print(indent_str .. "\"" .. k .. "\": {");
			_printTbl(v, indent + 1);
			print(indent_str .. "},");
		else
			if (type(v) ~= "number") then
				v = "\"" .. tostring(v) .. "\"";
			end
			print(indent_str .. "\"" .. k .. "\": " .. v .. ',');
		end
	end
end

if (modkit == nil) then modkit = {}; end

if (modkit.table == nil) then

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
		merge = function (tbl_a, tbl_b, merger)
			merger = merger or function (a, b)
				return (b or a);
			end
			if (tbl_a == nil and tbl_b ~= nil) then
				return tbl_b;
			elseif (tbl_a ~= nil and tbl_b == nil) then
				return tbl_a;
			elseif (tbl_b == nil and tbl_b == nil) then
				return {};
			end
			local out = tbl_a;
			for k, v in tbl_b do
				if (out[k] == nil) then
					out[k] = v;
				else
					out[k] = merger(out[k], tbl_b[k]);
				end
			end
			return out;
		end,
		includesValue = function (table, value)
			for i, v in table do
				if v == value then
					return true;
				end
			end
			return false;
		end,
		includesKey = function (table, value)
			for i, v in table do
				if i == value then
					return true;
				end
			end
			return false;
		end,
		find = function (table, predicate)
			for i, v in table do
				if (predicate(v, i, table) ~= nil) then
					return v;
				end
			end
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

	modkit.table = {};
	for k, v in table do
		modkit.table[k] = v;
	end

	print("table_util init");
end