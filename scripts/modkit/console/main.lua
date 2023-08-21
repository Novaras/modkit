if (MK_CONSOLE == nil) then
	dofilepath("data:scripts/modkit/scope_state.lua");
	dofilepath("data:scripts/modkit/table_util.lua");

	MK_CONSOLE_SCREEN_NAME = "MK_ConsoleScreen";
	MK_CONSOLE_LINE_LENGTH = 150;
	MK_CONSOLE_MAX_LINES = 24;

	s = makeStateHandle();

	--- Initialises state for the console code to interact with the UI window. If already initialised, does nothing unless `force` is set.
	---
	---@param force? bool
	function consoleInit(force)
		if (force or MK_CONSOLE_INIT == nil) then
			s({
				MK_CONSOLE_SCREEN_NAME = MK_CONSOLE_SCREEN_NAME,
				MK_CONSOLE_LINES = {},
				MK_CONSOLE_LINE_LENGTH = MK_CONSOLE_LINE_LENGTH,
				MK_CONSOLE_MAX_LINES = MK_CONSOLE_MAX_LINES,
			});
			MK_CONSOLE_INIT = 1;
		end
	end

	function strToConsoleLines(str)
		local lines = {};
		-- local timestamp = "<c=22dd44>[" .. strsub(tostring(Universe_GameTime()), 0, 4) .. "]</c>: ";
		local timestamp = '';
		local max_length = MK_CONSOLE_LINE_LENGTH - strlen(timestamp);

		for i = 1, strlen(str), max_length do
			local line = timestamp .. strsub(str, i - 1, i + max_length);
			modkit.table.push(lines, line);
		end

		return lines;
	end

	--- Prints the lines in `lines` to the console window, which hosts a textbox per line.
	---
	---@param lines string[]
	function printConsoleLines(lines)
		lines = lines or {};
		local rev = modkit.table.reverse(lines);
		for k, line in rev do
			local ui_el = "line" .. (MK_CONSOLE_MAX_LINES - k);
			UI_SetTextLabelText(MK_CONSOLE_SCREEN_NAME, ui_el, line);
		end
	end


	--- Similar to `print`, except instead sends output to the console window.
	---
	--- Internally converts all passed args to strings and concatenates them, then performs some cleanup.
	---
	--- Calls `consoleInit`.
	---
	consoleLog = consoleLog or function (...)
		consoleInit();

		local raw = "";
		for k, v in arg do
			if k ~= "n" then
				raw = raw .. tostring(v);
			end
		end
		raw = gsub(raw, "\t", "    ");

		local new_lines = strToConsoleLines(raw);
		local lines = s().MK_CONSOLE_LINES or {}; -- tbl ref
		for _, line in new_lines do
			print(line);
			-- a bit extraneous, should probably only write to the handle once
			s({
				MK_CONSOLE_LINES = modkit.table.push(lines, line)
			});
			if (modkit.table.length(lines) > MK_CONSOLE_MAX_LINES) then
				modkit.table.pop(lines);
			end
		end

		printConsoleLines(s().MK_CONSOLE_LINES);
	end

	consoleError = consoleError or function (...)
		for k, val in arg do
			if (k ~= "n") then
				consoleLog("<c=ff4422>[ERROR]: " .. tostring(val) .. "</c>");
			end
		end
	end

	--- Logs a table's items in `row_length` rows, which are just the items casted to strings and seperated by `delimeter`.
	---
	---@param items table
	---@param row_length integer? Default `3`
	---@param delimeter string? Default `", "`
	consoleLogRows = consoleLogRows or function (items, row_length, delimeter)
		delimeter = delimeter or ", ";
		local items_count = modkit.table.length(items);
		row_length = min(items_count, row_length or 3);
		local word_count = 0;
		local row_str = "";
		for _, item in items do
			word = tostring(item);
			row_str = row_str .. word .. delimeter;

			word_count = word_count + 1;

			if (mod(word_count, row_length) == 0 or strlen(row_str) > 100) then
				consoleLog(row_str);
				word_count = 0;
				row_str = "";
			end
		end
	end

	MK_CONSOLE = 1;
end
