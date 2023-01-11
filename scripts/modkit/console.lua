if (MODKIT_CONSOLE == nil) then
	print("Console init...");

	if (modkit == nil) then
		modkit = {};
	end
	dofilepath("data:scripts/modkit/scope_state.lua");
	doscanpath("data:scripts/modkit/console", "*.lua");

	if (consoleLog) then
		consoleLog("Type 'help' for help, or 'help [command]' for details on a command.");
	end

	local CONSOLE = {
		log = consoleLog,
		error = consoleError,
		rows = consoleLogRows
	};
	modkit.console = CONSOLE;

	MODKIT_CONSOLE = 1;
end