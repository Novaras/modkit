if (MK_CONSOLE == nil) then
	dofilepath("data:scripts/modkit/scope_state.lua");
	dofilepath("data:scripts/modkit/table_util.lua");

	MK_CONSOLE_SCREEN_NAME = "MK_ConsoleScreen";
	MK_CONSOLE_LINE_LENGTH = 128;
	MK_CONSOLE_MAX_LINES = 24;

	s = makeStateHandle();

	function strToConsoleLines(str)
		local lines = {};
		local timestamp = "[" .. strsub(tostring(Universe_GameTime()), 0, 3) .. "] ";
		local max_length = MK_CONSOLE_LINE_LENGTH - strlen(timestamp);

		for i = 1, strlen(str), max_length do
			local line = strsub(str, i - 1, i + MK_CONSOLE_LINE_LENGTH);
			modkit.table.push(lines, line);
		end

		return lines;
	end

	function printConsoleLines(lines)
		local rev = modkit.table.reverse(lines);
		for k, line in rev do
			local ui_el = "line" .. (MK_CONSOLE_MAX_LINES - k);
			UI_SetTextLabelText(MK_CONSOLE_SCREEN_NAME, ui_el, line);
		end
	end

	function consoleLog(...)
		if (MK_CONSOLE_INIT == nil) then
			s({
				MK_CONSOLE_SCREEN_NAME = MK_CONSOLE_SCREEN_NAME,
				MK_CONSOLE_LINES = {},
				MK_CONSOLE_LINE_LENGTH = MK_CONSOLE_LINE_LENGTH,
				MK_CONSOLE_MAX_LINES = MK_CONSOLE_MAX_LINES,
			});
			MK_CONSOLE_INIT = 1;
		end
		local raw = "";
		for k, v in arg do
			if k ~= "n" then
				raw = raw .. tostring(v);
			end
		end
		raw = gsub(raw, "\t", "    ");
		
		local d = UI_GetElementCustomData("MK_ConsoleScreen", "mk_consolescreen_root");
		if (d == 10) then
			UI_SetElementCustomData("MK_ConsoleScreen", "mk_consolescreen_root", 50);
		end

		local new_lines = strToConsoleLines(raw);
		local lines = s().MK_CONSOLE_LINES or {}; -- tbl ref
		for _, line in new_lines do
			print(line);
			s({
				MK_CONSOLE_LINES = modkit.table.push(lines, line)
			});
			if (modkit.table.length(lines) > MK_CONSOLE_MAX_LINES) then
				modkit.table.pop(lines);
			end
		end

		-- MK_CONSOLE_LINES = modkit.table.slice(MK_CONSOLE_LINES, 1, MK_CONSOLE_MAX_LINES);

		printConsoleLines(s().MK_CONSOLE_LINES);
		-- modkit.table.printTbl(s().MK_CONSOLE_LINES, "lines");
	end

	MK_CONSOLE = 1;
end
