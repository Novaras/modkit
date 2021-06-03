--Table utility functions.

if (modkit == nil) then modkit = {}; end

if (modkit.table == nil) then
	modkit.table = {}
	modkit.table._printTbl = function (tbl, indent)
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
		for k, v in tbl do
			if type(v) == "table" then
				print(indent_str .. "\"" .. k .. "\": {");
				_printTbl(v, indent + 1, self);
				print(indent_str .. "},");
			else
				if (type(v) ~= "number") then
					v = "\"" .. tostring(v) .. "\"";
				end
				print(indent_str .. "\"" .. k .. "\": " .. v .. ',');
			end
		end
	end



	modkit.table = {
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
		printTbl = function (tbl, label)
			if (label == nil) then
				label = tostring(tbl);
			end
			local temp_tbl = {};
			temp_tbl[label] = tbl;
			_printTbl(temp_tbl);
		end
	}
	print("table_util init");
end